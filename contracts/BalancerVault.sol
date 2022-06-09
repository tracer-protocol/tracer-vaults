pragma solidity ^0.8.0;

import {ERC20, ERC4626} from "../lib/solmate/src/mixins/ERC4626.sol";
import {SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "../lib/solmate/src/utils/FixedPointMathLib.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/balancer/IVault.sol";
import "./interfaces/balancer/IRateProvider.sol";
import "./interfaces/balancer/IMetastablePool.sol";
import "hardhat/console.sol";

/**
 * Aggregated Liquidity Vault
 * The aggregated liquidity vault wraps a Balancer Pool, allowing Tracer Perpetual Pool markets to be
 * settled in Balancer LP tokens.
 */
contract BalancerVault is ERC4626, AccessControl {
    // WIP
    // contracts needed
    // - `PoolBalances`: Pool joins and exits.
    // - `PoolTokens`: Pool token registration and registration, and balance queries.
    // - `Swaps`: Pool swaps.
    // (maybe?) - `UserBalance`: manage user balances (Internal Balance operations and external balance transfers)
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    // required assets
    // mapping asset => is accepted by balancer pool?
    mapping(address => bool) public supportedAssets;

    // Balancer contracts
    // todo: Get correct interface
    ERC20 public balancerLP;
    // balancer identifies pools by a pool ID
    // eg https://app.balancer.fi/#/pool/0x7b50775383d3d6f0215a8f290f2c9e2eebbeceb20000000000000000000000fe
    bytes32 public poolId;
    IVault public balancerVault = IVault(address(0xBA12222222228d8Ba445958a75a0704d566BF2C8));

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

    // Balancer swap contracts (for swapping rewards into stables)
    // todo: what contract do I need here?

    // RBAC
    bytes32 public constant SAFETY_ROLE = keccak256("SAFETY_ADMIN");
    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ADMIN");

    /**
     */
    constructor(
        address _balancerLP,
        bytes32 _targetPoolId,
        address _superAdmin,
        string memory name,
        string memory symbol
    ) ERC4626(ERC20(_balancerLP), name, symbol) {
        // setup default admin
        _setupRole(DEFAULT_ADMIN_ROLE, _superAdmin);

        // setup the balancer LP token to be accepted
        // balancerLP = ERC20(_balancerLP);
        poolId = _targetPoolId;
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
        console.log("Total assets");
        // Read the balance of the vault by converting LP shares into total stables.
        (address[] memory tokens, uint256[] memory balances, ) = balancerVault.getPoolTokens(poolId);
        (address boostedPool, ) = balancerVault.getPool(poolId);
        // todo optimise below
        uint256 assets = 0;
        for (uint8 i = 0; i < tokens.length; i++) {
            address linearPool = tokens[i];
            // the following uses the rate provider for each linear pool within the boosted pool
            // the rate returned is the conversion between linear pool LP tokens and the underlying (eg DAI).
            // (https://dev.balancer.fi/resources/pool-interfacing/metastable-pool)

            // ignore if this is the bb-a-usd pool.
            if (linearPool != boostedPool) {
                IRateProvider rateProvider = IRateProvider(linearPool);
                uint256 rate = rateProvider.getRate();
                console.log(linearPool);
                console.log(rate);
                console.log(balances[i]);
                assets += balances[i].mulWadDown(rate);
            }
        }
        console.log(assets);
        return assets;
    }

    /**
     * @notice Claims rewards from Balancer
     * @dev the payload for claiming (recipient, v, r, s) must be formed off chain
     */
    function claim() public {
        // todo
    }

    /**
     * @notice harvests on hand rewards for the underlying assets and reinvests
     * @dev limits the amount of slippage that it is willing to accept.
     */
    function compound() public {
        // todo:
        // - figure out optimal stable to collect for this compound (based on pool composition - eg swap BAL for one of the stables)
        // - perform swap
        // - distribute fee's and restake into Bal pool.
        // validate we can compound
        //     require(canCompound(), "not ready to compound");
        //     // find the asset the tokemak pool is settled in
        //     ERC20 underlying = ERC20(underlyingPool.underlyer());
        //     uint256 rewardsBalance = toke.balanceOf(address(this));
        //     // compute amount of rewards to sell, and amount to keep
        //     // cap at max toke swap amount
        //     uint256 swapAmount = rewardsBalance >= maxSwapTokens ? maxSwapTokens : rewardsBalance;
        //     // approve the router
        //     UniswapV2Router02 router = UniswapV2Router02(swapRouter);
        //     toke.safeApprove(swapRouter, swapAmount);
        //     // swap from toke to underlying asset to deposit back into toke
        //     uint256 underlyingBal = underlying.balanceOf(address(this));
        //     router.swapExactTokensForTokens(swapAmount, 1, tradePath, address(this), block.timestamp + 30 minutes);
        //     uint256 underlyingReceived = underlying.balanceOf(address(this)) - underlyingBal;
        //     // mark this as swap time
        //     lastSwapTime = block.timestamp;
        //     // compute keeper fee and deposit amount
        //     uint256 keeperFee = underlyingReceived / 100;
        //     uint256 depositAmount = underlyingReceived - keeperFee;
        //     // deposit underlying back into tokemak
        //     underlying.safeApprove(address(underlyingPool), depositAmount);
        //     underlyingPool.deposit(depositAmount);
        //     // transfer keeper fee
        //     underlying.safeTransfer(msg.sender, keeperFee);
    }

    /**
     * @notice checks if the compound function can be called
     * @return can compound be called
     */
    function canCompound() public view returns (bool) {
        // has enough time passed?
        // bool hasTimePassed = block.timestamp > lastSwapTime + swapCooldown;
        // bool hasSellableBalance = toke.balanceOf(address(this)) != 0;
        // return hasTimePassed && hasSellableBalance;
        return true;
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
