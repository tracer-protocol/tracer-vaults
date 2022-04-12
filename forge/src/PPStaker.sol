// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.1;
import "solmate/mixins/ERC4626.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {ILeveragedPool} from "./interfaces/ILeveragedPool.sol";
import {SafeMath} from "openzeppelin/utils/math/SafeMath.sol";

/// @title Staking contract for perpetual pool longTokens
/// @notice Users stake longtokens to earn  tcr rewards
/// @notice Long tokens are added to a queue, for use by the skew farm vault
/// @notice Stakers who lose long tokens for USDC will be in profit
/// @dev Gas optimisation is not implemented
contract PPStaker is Ownable {
    using SafeMath for uint256;
    ERC20 usdc;
    ERC20 LongToken;
    address vault;
    uint256 queueBalance;
    ILeveragedPool public pool;

    event vaultPulled(uint256 _amt);

    struct UserInfo {
        uint256 longTokens;
        uint256 longEntryPrice;
        uint256 USDC;
    }

    mapping(address => UserInfo) userInfo;
    mapping(uint256 => address) userQueue;
    uint256 first = 2**255;
    uint256 last = first - 1;

    // address[] public queue; //using deque now

    constructor(
        address _vault,
        address _usdc,
        address _LongToken,
        address _pool
    ) public {
        vault = _vault;
        usdc = ERC20(_usdc);
        LongToken = ERC20(_LongToken);
        queueBalance = 0;
        pool = ILeveragedPool(_pool);
    }

    modifier onlyVault() {
        require(msg.sender == vault, "only vault can pull");
        _;
    }

    function longTokenPrice() public view returns (uint256) {
        uint256 bal = pool.longBalance();
        uint256 price = bal.div(LongToken.totalSupply());
        return price;
    }

    //balance of long tokens in queue
    function balanceOfQueue() public view returns (uint256) {
        return queueBalance;
    }

    //delete a user from the queue
    function _delete(address _user) private {
        delete userInfo[_user];
        // queue[_user] = _queue[_queue.length.sub(1)];
        // queue.length-- ;
    }

    // stake a users' long tokens, update userInfo
    function stake(uint256 LongTokens) public {
        LongTokens += userInfo[msg.sender].longTokens;
        userInfo[msg.sender].longEntryPrice = longTokenPrice();

        first -= 1;
        userQueue[first] = msg.sender;
        // userInfo[msg.sender].queue = true;
        queueBalance += LongTokens;
    }

    // allows vault to pull longTokens from users, if they are in profit
    function vaultPull(uint256 amount, uint256 rate) public onlyVault {
        uint256 outstanding = amount;
        uint256 _first = first;
        address user = userQueue[_first];
        uint256 _longTokens = 0;
        uint256 usdcOut = 0;
        while (outstanding > 0) {
            uint256 bal = userInfo[user].longTokens;
            if (userInfo[user].longEntryPrice > longTokenPrice()) {
                outstanding -= userInfo[user].longTokens;
                // uint256 usdcUser =userInfo[user].usdc;
                uint256 usdcUser = userInfo[user].longTokens * rate;
                userInfo[user].longTokens = 0;
                _delete(user);
                userInfo[user].USDC = usdcUser;
                queueBalance -= bal;
                _first--;
                _longTokens += bal;
                usdcOut += usdcUser;
            } else _first--;
        }
        emit vaultPulled(amount);
    }

    // Unstake long tokens, gain long tokens, gain usdc
    function unStake() public returns (uint256, uint256) {
        uint256 _bal0 = userInfo[msg.sender].longTokens;
        uint256 _bal1 = userInfo[msg.sender].USDC;
        address user = msg.sender;
        if (_bal0 > 0) {
            LongToken.transfer(msg.sender, _bal0);
            _delete(user);
        }
        if (_bal1 > 0) {
            usdc.transfer(msg.sender, _bal1);
        }
        return (_bal0, _bal1);
    }
}
