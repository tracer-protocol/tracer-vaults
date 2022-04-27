// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import {ILeveragedPool} from "./interfaces/tracer/ILeveragedPool.sol";
import {L2Encoder} from "./utils/L2Encoder.sol";
import {IPoolCommitter} from "./interfaces/tracer/IPoolCommitter.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {SafeMath} from "../lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "./SkewVault.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/**
 * @notice A vault for farming long sided skew against tracer perpetual pools
 * @dev if skew exists and the vault is active, tradingStats gets updated to reflect wants, enable swaps
 * @dev if skew ceases to exist, tradingStats gets updated to reflect unwinding and block swaps
 * @dev Aquiring and disposing must be called mannually for now, and will require role permissions before prod
 * @dev EC4626 compatible vault must be deployed prior to initialize of this contract
 */
contract LongFarmer is Ownable {
    using SafeMath for uint256;
    enum State {
        // The vault is not active
        Inactive,
        // The vault is active
        Active
    }
    //in its active state, the vault stores the following data for managing positions
    struct TradingStats {
        uint256 startTime;
        uint256 startSkew;
        uint256 previousPrice;
        uint256 targetAmt;
        bool swapping;
        bool unWinding;
        bool stopping;
        uint256 amtLong;
        uint256 want;
        bool testing;
    }
    State state;
    TradingStats tradingStats; // only used in Active state
    ERC20 USDC;
    ERC20 longToken;
    IPoolCommitter poolCommitter;
    ERC20 vault;
    SkewVault skewVault;
    address poolAddress;
    bool public tradeLive;
    uint256 public threshold;
    uint256 window;
    uint256 public depUSDC; //deposited USDC
    uint256 public balances; //net user balances
    ILeveragedPool public pool;
    L2Encoder encoder;
    event unwind(uint256 _amt);
    event Log(string _msg);
    event acquired(uint256 _amt);

    function initialize(
        address _poolAddress,
        uint256 _threshold,
        address _committer,
        address _encoder,
        ERC20 _vault
    ) public {
        poolAddress = _poolAddress;
        threshold = _threshold;
        pool = ILeveragedPool(poolAddress);
        poolCommitter = IPoolCommitter(_committer);
        encoder = L2Encoder(_encoder);
        tradeLive = false;
        _vault = vault;
        _vault = skewVault;
        USDC = ERC20(0x9e062eee2c0Ab96e1E1c8cE38bF14bA3fa0a35F6);
        longToken = ERC20(0x4AaDc48087b569dD3E65dBe65B0dD036891767e3);
        longToken.approve(address(poolCommitter), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        ERC20(0x9e062eee2c0Ab96e1E1c8cE38bF14bA3fa0a35F6).approve(
            address(poolCommitter),
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        ERC20(0x9e062eee2c0Ab96e1E1c8cE38bF14bA3fa0a35F6).allowance(
            address(0xC3d2052479dBC010480Ae16204777C1469CEffC9),
            address(this)
        );
        ERC20(0x9e062eee2c0Ab96e1E1c8cE38bF14bA3fa0a35F6).approve(
            address(0xC3d2052479dBC010480Ae16204777C1469CEffC9),
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        longToken.approve(address(this), 1e18);
    }

    /**
     * @notice Returns the value of the vault, in USDC and LongTokens
     * @dev Utility function for skewVault
     */
    function value() public view returns (uint256) {
        uint256 usdcBal = ERC20(0x9e062eee2c0Ab96e1E1c8cE38bF14bA3fa0a35F6).balanceOf(address(this));
        if (state == State.Active) {
            uint256 _adj = tradingStats.amtLong.mul(longTokenPrice());
            usdcBal += _adj;
        }
        return usdcBal;
    }

    /**
     * @notice Pokes the vault to conduct skew checks and update wants
     * @dev if skew exists and the vault is active, tradingStats gets updated to reflect wants, enable swaps
     * @dev if skew ceases to exist, tradingStats gets updated to reflect unwinding and block swaps
     */
    function poke() public returns (bool) {
        require(window < block.timestamp, "poke can only be called hourly");
        uint256 rate = tradingStats.previousPrice.div(longTokenPrice());
        uint256 _skew = skew();
        bool _bool = false;
        if (_skew > threshold && state != State.Active) {
            state = State.Active;
            tradingStats.startSkew = _skew;
            tradingStats.startTime = block.timestamp;
            uint256 _target = target(rate);
            tradingStats.targetAmt = _target;
            tradingStats.swapping = true;
            tradingStats.unWinding = false;
            tradingStats.stopping = false;
            _bool = true;
        }
        if (state == State.Active && _skew > threshold && tradingStats.amtLong > 0) {
            uint256 _amtLong = tradingStats.amtLong;
            uint256 _target = target(rate);
            uint256 _want = _target.sub(_amtLong);
            tradingStats.want = _want;
            tradingStats.swapping = true;
            tradingStats.unWinding = false;
            tradingStats.stopping = false;
            _bool = true;
        }
        if (threshold > _skew) {
            uint256 balance = longToken.balanceOf(address(this)).add(
                poolCommitter.getAggregateBalance(address(this)).longTokens
            );
            bytes32 args = encoder.encodeCommitParams(balance, IPoolCommitter.CommitType.LongBurn, false, true);
            poolCommitter.commit(args);
            emit unwind(balance);
            tradingStats.unWinding = true;
            tradingStats.swapping = false;
            _bool = false;
        }
        if (nextSkew(rate) < threshold) {
            tradingStats.swapping = false;
            tradingStats.stopping = true;
            emit Log("no more skew");
            _bool = false;
        }
        emit Log("pokey pokey");
        window = block.timestamp + 3600;
        tradingStats.amtLong = longToken.balanceOf(address(this)).add(
            poolCommitter.getAggregateBalance(address(this)).longTokens
        );
        tradingStats.previousPrice = longTokenPrice();
        return _bool;
    }

    /**
     * @notice Gets the current pool skew
     * @dev returns skew
     */
    function skew() public view returns (uint256) {
        if (tradingStats.testing == true) {
            return 10000;
        } else {
            uint256 _s = pool.shortBalance() / pool.longBalance();
            return _s;
        }
    }

    /**
     * @notice Returns the predicted next skew
     * @param _rate the current rate of change
     */
    function nextSkew(uint256 _rate) public view returns (uint256) {
        uint256 sBal = pool.shortBalance().mul(1 - _rate);
        uint256 lBal = pool.longBalance().mul(_rate);
        uint256 _s = sBal / lBal;
        uint256 _nS = _s.mul(_rate);
        return _nS;
    }

    /**
     * @notice Gets the target value of wants for the vault to bring skew back to 1
     * @param _rate rate of change of long token from previous price
     */
    function target(uint256 _rate) public view returns (uint256) {
        uint256 _shortBal = pool.shortBalance().mul(1 - _rate);
        uint256 _LongBal = pool.longBalance().mul(_rate);
        uint256 _s = _shortBal / _LongBal;
        uint256 _t = _shortBal / _s;
        uint256 _target = _t - _LongBal;
        return _target;
    }

    /**
     * @notice Aquires long tokens for the vault from the poolCommitter
     * @dev only call when swaps cant fulfil wants
     * @param _amount amount of long tokens to be aquired
     */
    function acquire(uint256 _amount) public {
        require(state == State.Active, "vault must be active to acquire");
        require(tradingStats.unWinding == false, "vault must be aquiring not unwinding");
        require(skew() > threshold, "pools must be skewed to acquire");
        require(tradingStats.stopping != true, "next skew under threshold");
        USDC.approve(
            address(0xccC0350C209F6F01D071c3cdc20eEb5EE4A73d80),
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        tradingStats.swapping = false;
        bytes32 args = encoder.encodeCommitParams(_amount, IPoolCommitter.CommitType.LongMint, false, true);
        poolCommitter.commit(args);
        emit acquired(_amount);
        tradingStats.amtLong = tradingStats.amtLong.add(_amount);
        tradingStats.want = tradingStats.want.sub(_amount);
        tradingStats.want > 0 ? tradingStats.swapping = true : tradingStats.swapping = false;
    }

    /**
     * @notice Checks committer aggregate balance, returns bool
     * @dev if long tokens in aggregate balance are greater than amt, returns true
     * @param _amt amount of long tokens to be released
     */
    function agBal(uint256 _amt) public view returns (bool) {
        uint256 lTokens = poolCommitter.getAggregateBalance(address(this)).longTokens;
        bool _bool = false;
        lTokens > _amt ? _bool = true : _bool = false;
        return _bool;
    }

    /**
     * @notice Releases long tokens to the poolCommitter
     * @dev only call when forcing disposal of long tokens
     * @param _amount amount of long tokens to be released
     * @dev must be set as role based access when in production
     */
    function dispose(uint256 _amount) public onlyPlayer {
        require(state == State.Active, "vault must be active to dispose");
        bytes32 args = encoder.encodeCommitParams(_amount, IPoolCommitter.CommitType.LongBurn, false, false);
        poolCommitter.commit(args);
        tradingStats.want = tradingStats.want.sub(_amount);
        tradingStats.amtLong = tradingStats.amtLong.sub(_amount);
        tradingStats.want > 1000 ? tradingStats.swapping = true : tradingStats.swapping = false;
    }

    /**
     * @notice swap function allowing users to swap longTokens for USDC
     * @dev MUST revert when not skewed
     * @param _amtLong long tokens to be swapped
     * @param _minAmtUSDC minimum amount of USDC to recieve
     */
    function _swap(uint256 _amtLong, uint256 _minAmtUSDC) public onlyWhenSkewed returns (uint256) {
        require(state == State.Active, "Vault is not active");
        require(tradingStats.unWinding == false, "Vault is unwinding");
        require(tradingStats.swapping == true, "Vault is not swapping");
        longToken.transferFrom(address(msg.sender), address(this), _amtLong);
        uint256 _out = longTokenPrice().mul(_amtLong);
        ERC20(0x9e062eee2c0Ab96e1E1c8cE38bF14bA3fa0a35F6).transfer(address(msg.sender), _out);
        require(_out > _minAmtUSDC, "Not enough USDC");
        return _out;
    }

    /**
     * @notice getter for long token price
     * @notice remove when not testing
     *
     */
    function longTokenPrice() public view returns (uint256) {
        uint256 bal = pool.longBalance();
        uint256 price = bal.div(longToken.totalSupply());
        if (price == 0) {
            return 10000;
        } else {
            return price;
        }
    }

    /**
     * @notice Setter for Testing purposes only
     *
     */
    function setActive() public onlyOwner {
        state = State.Active;
        tradingStats.swapping = true;
        tradingStats.testing = true;
    }

    function setSkewVault(address _vault) public {
        skewVault = SkewVault(_vault);
        vault = ERC20(_vault);
        USDC.approve(address(skewVault), 1e18);
    }

    function rxFunds(uint256 _amt) public {
        USDC.transferFrom(address(skewVault), address(this), _amt);
        depUSDC += _amt;
        balances += _amt;
    }

    function returnFunds(uint256 amount) public {
        USDC.transfer(address(skewVault), amount);
        balances -= amount;
    }

    modifier onlyPlayer() {
        require(vault.balanceOf(address(msg.sender)) > 1, "Only player can execute");
        _;
    }

    modifier onlyWhenSkewed() {
        require(skew() > threshold, "only swap when skewed");
        _;
    }
    modifier onlyWhitelist() {
        require(skewVault.whiteList(msg.sender) == true, "Only whitelisted accounts can execute");
        _;
    }
}
