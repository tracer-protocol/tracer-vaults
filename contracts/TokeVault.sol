pragma solidity ^0.8.0;

import {ERC20, ERC4626} from "../lib/solmate/src/mixins/ERC4626.sol";
import {SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "../lib/solmate/src/utils/FixedPointMathLib.sol";
import "./interfaces/tokemak/ILiquidityPool.sol";
import "./interfaces/tokemak/IRewards.sol";
import "./interfaces/uniswap/UniswapV2Router02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * A Tokemak compatible ERC4626 vault that takes in a tAsset and auto compounds toke rewards
 * received from staking that tAsset in toke.
 */
contract TokeVault is ERC4626, AccessControl {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    // required assets
    ERC20 public immutable toke;
    ERC20 public immutable tAsset;

    // tokemak contracts
    ILiquidityPool public immutable underlyingPool;
    IRewards public immutable rewards;

    // CONFIGURABLE PARAMS
    // keeper rewards: default of 1.5 Toke
    uint256 public keeperRewardAmount = 1500000000000000000;
    // max swap amount for uniswap trade. This amount can be swapped every swapCooldown hours
    uint256 public maxSwapTokens = 100000000000000000000;
    uint256 public swapCooldown = 12 hours;
    // address that gets a percent of generated yield
    address public feeReciever;
    // performance fee that goes to fee reciever. Default = 10% = 0.1
    uint256 public performanceFee = 100000000000000000;

    // uniswap
    address public immutable swapRouter;
    address[] public tradePath;
    uint24 public swapPoolFee = 3000; // default 0.3%
    uint256 public lastSwapTime = 0;

    // RBAC
    bytes32 public constant SAFETY_ROLE = keccak256("SAFETY_ADMIN");
    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ADMIN");

    /**
     * @param _tAsset the tAsset that this vault handles
     */
    constructor(
        address _tAsset,
        address _rewards,
        address _swapRouter,
        address _feeReciever,
        address _toke,
        address[] memory _tradePath,
        address _superAdmin,
        string memory name,
        string memory symbol
    ) ERC4626(ERC20(_tAsset), name, symbol) {
        // erc20 representation of toke pool
        tAsset = ERC20(_tAsset);
        // pool representation of toke pool
        underlyingPool = ILiquidityPool(_tAsset);
        rewards = IRewards(_rewards);
        swapRouter = _swapRouter;
        feeReciever = _feeReciever;
        toke = ERC20(_toke);
        tradePath = _tradePath;

        // setup default admin
        _setupRole(DEFAULT_ADMIN_ROLE, _superAdmin);
    }

    function beforeWithdraw(uint256 underlyingAmount, uint256) internal override {
        // no after withdraw
    }

    function afterDeposit(uint256 underlyingAmount, uint256) internal override {
        // no after deposit actions
    }

    /// @notice Total amount of the underlying asset that
    /// is "managed" by Vault.
    function totalAssets() public view override returns (uint256) {
        // Simply read tAsset balance. Ignore outstanding rewards
        return tAsset.balanceOf(address(this));
    }

    /**
     * @notice Claims rewards from toke
     * @dev the payload for claiming (recipient, v, r, s) must be formed off chain
     */
    function claim(
        IRewards.Recipient memory recipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        // claim toke rewards
        uint256 rewardsBefore = toke.balanceOf(address(this));
        rewards.claim(recipient, v, r, s);
        // take the keeper reward out of these rewards before pre computing
        // todo may underflow if claim amount < keeperRewardAmount
        uint256 rewardsReceived = toke.balanceOf(address(this)) - rewardsBefore - keeperRewardAmount;

        // take performance fee
        uint256 fee = rewardsReceived.mulWadUp(performanceFee);
        rewardsReceived = rewardsReceived - fee;

        // transfers and deposits
        toke.safeTransfer(feeReciever, fee);
        toke.safeTransfer(msg.sender, keeperRewardAmount);
    }

    /**
     * @notice harvests on hand rewards for the underlying asset and reinvests
     * @dev limits the amount of slippage that it is willing to accept.
     */
    function compound() public {
        // validate we can compound
        require(canCompound(), "not ready to compound");

        // find the asset the tokemak pool is settled in
        ERC20 underlying = ERC20(underlyingPool.underlyer());

        uint256 rewardsBalance = toke.balanceOf(address(this));

        // compute amount of rewards to sell, and amount to keep
        // cap at max toke swap amount
        uint256 swapAmount = rewardsBalance >= maxSwapTokens ? maxSwapTokens : rewardsBalance;

        // approve the router
        UniswapV2Router02 router = UniswapV2Router02(swapRouter);
        toke.safeApprove(swapRouter, swapAmount);

        // swap from toke to underlying asset to deposit back into toke
        uint256 underlyingBal = underlying.balanceOf(address(this));
        router.swapExactTokensForTokens(swapAmount, 1, tradePath, address(this), block.timestamp + 30 minutes);
        uint256 underlyingReceived = underlying.balanceOf(address(this)) - underlyingBal;

        // mark this as swap time
        lastSwapTime = block.timestamp;

        // compute keeper fee and deposit amount
        uint256 keeperFee = underlyingReceived / 100;
        uint256 depositAmount = underlyingReceived - keeperFee;

        // deposit underlying back into tokemak
        underlying.safeApprove(address(underlyingPool), depositAmount);
        underlyingPool.deposit(depositAmount);

        // transfer keeper fee
        underlying.safeTransfer(msg.sender, keeperFee);
    }

    /**
     * @notice checks if the compound function can be called
     * @return can compound be called
     */
    function canCompound() public view returns (bool) {
        // has enough time passed?
        bool hasTimePassed = block.timestamp > lastSwapTime + swapCooldown;
        bool hasSellableBalance = toke.balanceOf(address(this)) != 0;
        return hasTimePassed && hasSellableBalance;
    }

    /**
     * @notice THIS SAFETY FUNCTION IS ONLY FOR TESTING IN PROD
     * @dev remove once contract is audited and verified. This allows the owner to
     * withdraw any asset to themself. USE WITH CAUTION
     */
    function withdrawAssets(address asset, uint256 amount) external onlyRole(SAFETY_ROLE) {
        ERC20(asset).safeTransfer(msg.sender, amount);
    }

    /**
     * @notice allows the keeper reward to be modified
     */
    function setKeeperReward(uint256 newKeeperReward) external onlyRole(CONFIG_ROLE) {
        keeperRewardAmount = newKeeperReward;
    }

    /**
     * @notice allows the max swap tokens to be modified
     */
    function setMaxSwapTokens(uint256 newMaxSwapTokens) external onlyRole(CONFIG_ROLE) {
        maxSwapTokens = newMaxSwapTokens;
    }

    /**
     * @notice allows the max swap tokens to be modified
     */
    function setSwapCooldown(uint256 newSwapCooldown) external onlyRole(CONFIG_ROLE) {
        swapCooldown = newSwapCooldown * 1 hours;
    }

    /**
     * @notice Sets the account that receives profit fees
     */
    function setFeeReciever(address newFeeReciever) external onlyRole(CONFIG_ROLE) {
        feeReciever = newFeeReciever;
    }
}
