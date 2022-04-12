// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.1;
import {ERC4626, ERC20} from "solmate/mixins/ERC4626.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import "./PPStaker.sol";
import {ILeveragedPool} from "./interfaces/ILeveragedPool.sol";
import {L2Encoder} from "./utils/L2Encoder.sol";
import {IPoolCommitter} from "./interfaces/IPoolCommitter.sol";
import {ILeveragedPool} from "./interfaces/ILeveragedPool.sol";
import {SafeMath} from "openzeppelin/utils/math/SafeMath.sol";

/// @title Vault contract for farming the skew on long tokens
/// @notice Users deposit underlying (usdc) tokens to earn interest from farming the skew
/// @notice Long tokens are pulled from PPStakers, or from swaps
/// @notice Swaps are only activated if price > prevPrice && skew > threshold
/// @dev Gas optimisation is not implemented
contract sVault is ERC4626, Ownable {
    using SafeMath for uint256;

    IPoolCommitter poolCommitter;
    ERC20 usdc;
    ERC20 longToken;
    uint256 LongTokensOwned;
    uint256 window;
    uint256 previousPrice; // hourly ?
    address public vault;
    address public poolAddress;
    bool public tradeLive;
    uint256 public threshold;
    ILeveragedPool public pool;
    L2Encoder encoder;
    PPStaker staker;
    ERC20 vaultToken;

    event holding(uint256 _amt);
    event unwind(uint256 _amt);
    event releasing(uint256 _amt);
    event noAction(uint256 _skew);
    event Log(string _msg);
    event acquired(uint256 _amt);

    constructor(
        ERC20 _usdc,
        address _poolAddress,
        address _longToken,
        uint256 _threshold,
        address _encoder,
        address _vault,
        address _staker
    ) public ERC4626(_usdc, "skew Vault", "sVault") {
        usdc = _usdc;
        longToken = ERC20(_longToken);
        poolAddress = _poolAddress;
        threshold = _threshold;
        pool = ILeveragedPool(poolAddress);
        encoder = L2Encoder(_encoder);
        tradeLive = false;
        _vault = vault;
        staker = PPStaker(_staker);
        usdc.approve(address(staker), usdc.balanceOf(msg.sender));
    }

    function totalAssets() public view override returns (uint256) {
        return usdc.balanceOf(address(this)) + lTValue();
    }

    function lTValue() public view returns (uint256) {
        LongTokensOwned.mul(staker.longTokenPrice());
    }

    function skew() public view returns (uint256) {
        uint256 _skew = pool.shortBalance() / pool.longBalance();
        return _skew;
    }

    // Allows longToken holders to swap for USDC without slippage
    function _swap(uint256 _amtLong, uint256 _minAmtUSDC) public onlyWhenSkewed returns (uint256) {
        require(staker.longTokenPrice() > previousPrice, "not accepting swaps");
        longToken.transfer(address(this), _amtLong);
        uint256 _out = staker.longTokenPrice().mul(_amtLong);
        usdc.transfer(msg.sender, _out);
        return _out;
    }

    // Target balance of long tokens to acquire to farm the skew
    function target(uint256 _rate) public view returns (uint256) {
        uint256 _shortBal = pool.shortBalance().mul(1 - _rate);
        uint256 _LongBal = pool.longBalance().mul(_rate);
        uint256 skew = _shortBal / _LongBal;
        uint256 _t = _shortBal.div(skew);
        uint256 target = _t - _LongBal;
        return target;
    }

    // Regularly checks skew conditions, and pulls or burns if conditions are met
    function poke() public returns (bool) {
        require(window < block.timestamp, "poke can only be called hourly");
        uint256 rate = previousPrice.div(staker.longTokenPrice());
        uint256 _nextPrice = previousPrice.mul(rate);
        uint256 _previousPrice = previousPrice;
        uint256 _skew = skew();
        tradeLive = true;
        if (_skew > threshold) {
            tradeLive = true;
        }
        if (tradeLive) {
            uint256 _target = target(rate);
            uint256 available = staker.balanceOfQueue();
            if (available < _target) {
                staker.vaultPull(available, rate);
            }
            if (available > _target) {
                staker.vaultPull(_target, rate);
            }
            return true;
        }
        if (threshold < _skew) {
            uint256 balance = longToken.balanceOf(address(this));
            bytes32 args = encoder.encodeCommitParams(balance, IPoolCommitter.CommitType.LongBurn, false, true);
            poolCommitter.commit(args);
            emit unwind(balance);
            return false;
        }
        emit Log("pokey pokey");
        window = block.timestamp + 3600;
    }

    modifier onlyWhenSkewed() {
        require(skew() > threshold, "only swap when skewed");
        _;
    }
}
//  function vaultPull(uint256 amount, uint256 rate) public onlyVault {
// uint256 outstanding = amount;
// uint256 usdcvalue = longTokens * rate;
// uint256 _longTokens = 0;
// uint256 usdcOut = 0;
// while(outstanding > 0) {
// 	address user = queue[0];
// 	uint256 bal = userinfo[user].longTokens;
// 	outstanding -= longBalance;
// 	userInfo[user].longTokens = 0;
// 	longtoken * rate = usdcUser;
// 	_delete(user);
// 	userInfo[user].usdc = usdcUser;
//     _longTokens += bal;
//     usdcOut += usdcUser;
// }
// LongToken.transferFrom(address(PPStaker), address(this), longTokens);
// usdc.transfer(address(this), usdcOut);
// LongTokensOwned += longTokens;
// emit Log("Vault Pulled"); //kek
// emit acquired(longTokens);
// }

//     function checkSkew() public onlyPlayer {
//     uint256 _skew = skew();
//     uint256 _bal = usdc.balanceOf(address(this));
//     if (_skew > threshold) {
//         uint256 _r = previousPrice.div(LongToken.price());
//         uint256 _nextPrice;
//         _r > 0 ? _nextPrice = _r.mul(previousPrice) : _r = 1;
//         if(_nextPrice > previousPrice) {
//             uint256 _target = target(_r);
//             uint256 available = PPStaker.balance();
//             if(available < _target) {
//                 vaultPull(available, _r);
//             } if(available > _target) {
//                 vaultPull(_target, _r);
//             }

//         }
// } emit Log("No Skew reeeee!");
// }
