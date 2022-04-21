// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import {ILeveragedPool} from "./interfaces/tracer/ILeveragedPool.sol";
import {L2Encoder} from "./utils/L2Encoder.sol";
import {IPoolCommitter} from "./interfaces/tracer/IPoolCommitter.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {SafeMath} from "../lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

// import {PoolCommitter} from "../lib/perpetual-pools-contracts/contracts/implementation/PoolCommitter.sol";

contract LongSkewVault {
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
        uint256 amtLong;
        uint256 want;
    }
    State state;
    TradingStats tradingStats; // only used in Active state
    ERC20 USDC;
    ERC20 longToken;
    ERC20 THREELBTC;
    IPoolCommitter poolCommitter;
    ERC20 vault;
    address poolAddress;
    bool public tradeLive;
    uint256 public threshold;
    uint256 window;
    ILeveragedPool public pool;
    L2Encoder encoder;
    event holding(uint256 _amt);
    event unwind(uint256 _amt);
    event releasing(uint256 _amt);
    event noAction(uint256 _skew);
    event Log(string _msg);
    event acquired(uint256 _amt);

    constructor(
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
    }

    /**
     * @notice Pokes the vault to conduct skew checks and update wants
     * @dev if skew exists and the vault is active, tradingStats gets updated to reflect wants, enable swaps
     * @dev if skew ceases to exist, tradingStats gets updated to reflect unwinding and block swaps
     */
    function poke() public returns (bool) {
        require(window < block.timestamp, "poke can only be called hourly");
        uint256 rate = tradingStats.previousPrice.div(longTokenPrice());
        uint256 _nextPrice = tradingStats.previousPrice.mul(rate);
        uint256 _previousPrice = tradingStats.previousPrice;
        uint256 _skew = skew();
        if (_skew > threshold && state != State.Active) {
            state = State.Active;
            tradingStats.startSkew = _skew;
            tradingStats.startTime = block.timestamp;
            uint256 _target = target(rate);
            tradingStats.targetAmt = _target;
            tradingStats.swapping = true;
            return true;
        }
        if (state == State.Active && _skew > threshold && tradingStats.amtLong > 0) {
            uint256 _amtLong = tradingStats.amtLong;
            uint256 _target = target(rate);
            uint256 _want = _target.sub(_amtLong);
            tradingStats.want = _want;
            tradingStats.swapping = true;
            return true;
        }
        if (threshold < _skew) {
            uint256 balance = longToken.balanceOf(address(this)).add(
                poolCommitter.getAggregateBalance(address(this)).longTokens
            );
            bytes32 args = encoder.encodeCommitParams(balance, IPoolCommitter.CommitType.LongBurn, false, true);
            poolCommitter.commit(args);
            emit unwind(balance);
            tradingStats.unWinding = true;
            tradingStats.swapping = false;
            return false;
        }
        emit Log("pokey pokey");
        window = block.timestamp + 3600;
        tradingStats.amtLong = longToken.balanceOf(address(this)).add(
            poolCommitter.getAggregateBalance(address(this)).longTokens
        );
        tradingStats.previousPrice = longTokenPrice();
    }

    /**
     * @notice Gets the current pool skew
     * @dev returns skew
     */
    function skew() public view returns (uint256) {
        uint256 _skew = pool.shortBalance() / pool.longBalance();
        return _skew;
    }

    /**
     * @notice Gets the target value of wants for the vault to bring skew back to 1
     * @param _rate rate of change of long token from previous price
     */
    function target(uint256 _rate) public view returns (uint256) {
        uint256 _shortBal = pool.shortBalance().mul(1 - _rate);
        uint256 _LongBal = pool.longBalance().mul(_rate);
        uint256 _skew = _shortBal / _LongBal;
        uint256 _t = _shortBal / _skew;
        uint256 _target = _t - _LongBal;
        return _target;
    }

    /**
     * @notice Aquires long tokens for the vault from the poolCommitter
     * @dev only call when swaps cant fulfil wants
     * @param _amount amount of long tokens to be aquired
     */
    function acquire(uint256 _amount) public onlyPlayer {
        require(state == State.Active, "vault must be active to acquire");
        require(tradingStats.unWinding == false, "vault must be aquiring not unwinding");
        tradingStats.swapping = false;
        tradeLive = true;
        bytes32 args = encoder.encodeCommitParams(_amount, IPoolCommitter.CommitType.LongMint, agBal(_amount), true);
        poolCommitter.commit(args);
        emit acquired(_amount);
        tradingStats.amtLong = tradingStats.amtLong.add(_amount);
        tradingStats.want = tradingStats.want.sub(_amount);
    }

    function agBal(uint256 _amt) public view returns (bool) {
        uint256 lTokens = poolCommitter.getAggregateBalance(address(this)).longTokens;
        lTokens > _amt ? true : false;
    }

    /**
     * @notice Releases long tokens to the poolCommitter
     * @dev only call when forcing disposal of long tokens
     * @param _amount amount of long tokens to be released
     * @dev must be set as role based access when in production
     */
    function dispose(uint256 _amount) public onlyPlayer {
        require(state == State.Active, "vault must be active to acquire");
        bytes32 args = encoder.encodeCommitParams(_amount, IPoolCommitter.CommitType.LongBurn, agBal(_amount), true);
        poolCommitter.commit(args);
        tradeLive = false;
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
        longToken.transfer(address(this), _amtLong);
        uint256 _out = longTokenPrice().mul(_amtLong);
        USDC.transfer(msg.sender, _out);
        require(_out > _minAmtUSDC, "Not enough USDC");
        return _out;
    }

    /**
     * @notice getter for long token price
     */
    function longTokenPrice() public view returns (uint256) {
        uint256 bal = pool.longBalance();
        uint256 price = bal.div(longToken.totalSupply());
        return price;
    }

    modifier onlyPlayer() {
        require(vault.balanceOf(address(msg.sender)) > 1, "Only player can execute");
        _;
    }

    modifier onlyWhenSkewed() {
        require(skew() > threshold, "only swap when skewed");
        _;
    }
}
