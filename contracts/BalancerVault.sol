pragma solidity ^0.8.0;

import {ERC20, ERC4626} from "../lib/solmate/src/mixins/ERC4626.sol";
import {SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "../lib/solmate/src/utils/FixedPointMathLib.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/balancer/vault/IVault.sol";
import "./interfaces/balancer/pool-utils/IRateProvider.sol";
import "./interfaces/balancer/liquidity-mining/ILiquidityGaugeFactory.sol";
import "./interfaces/balancer/liquidity-mining/IGaugeAdder.sol";
import "./interfaces/balancer/liquidity-mining/IStakingLiquidityGauge.sol";
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
    IERC20 public boostedPool;
    IVault public balancerVault = IVault(address(0xBA12222222228d8Ba445958a75a0704d566BF2C8));
    address public gaugeFactory;
    ERC20 public bal;

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
    uint256 lastSwapTime;

    // RBAC
    bytes32 public constant SAFETY_ROLE = keccak256("SAFETY_ADMIN");
    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ADMIN");

    /**
     */
    constructor(
        address _balancerLP,
        bytes32 _targetPoolId,
        address _gaugeFactory,
        address _balToken,
        address _superAdmin,
        string memory name,
        string memory symbol
    ) ERC4626(ERC20(_balancerLP), name, symbol) {
        // setup default admin
        _setupRole(DEFAULT_ADMIN_ROLE, _superAdmin);

        // setup the balancer LP token to be accepted
        // balancerLP = ERC20(_balancerLP);
        poolId = _targetPoolId;
        (address _boostedPool, ) = balancerVault.getPool(poolId);
        boostedPool = IERC20(_boostedPool);
        gaugeFactory = _gaugeFactory;
        bal = ERC20(_balToken);

        // approve the pool gauge to spend the balancer LP token
        ILiquidityGauge poolGauge = ILiquidityGauge(IGaugeAdder(gaugeFactory).getPoolGauge(boostedPool));
        // max approval
        ERC20(_balancerLP).approve(address(poolGauge), 2**256 - 1);
    }

    function beforeWithdraw(uint256 underlyingAmount, uint256) internal override {
        // withdraw from the gauge
        ILiquidityGauge poolGauge = ILiquidityGauge(IGaugeAdder(gaugeFactory).getPoolGauge(boostedPool));
        // todo: only claim rewards if there are rewards to claim
        IStakingLiquidityGauge(address(poolGauge)).withdraw(underlyingAmount);
    }

    function afterDeposit(uint256 underlyingAmount, uint256) internal override {
        // stake into the gauge
        ILiquidityGauge poolGauge = ILiquidityGauge(IGaugeAdder(gaugeFactory).getPoolGauge(boostedPool));
        // todo: only claim rewards if there are rewards to claim
        // todo: rather than deposit into bal gauges -> could earn more by depositing into a system such as StakeDAO or Aura
         IStakingLiquidityGauge(address(poolGauge)).deposit(underlyingAmount, address(this));
    }

    /// @notice Total amount of the underlying asset that
    /// is "managed" by Vault.
    function totalAssets() public view override returns (uint256) {
        console.log("Total assets");
        // Read the balance of the vault by converting LP shares into total stables.
        //(address[] memory tokens, uint256[] memory balances, ) = balancerVault.getPoolTokens(poolId);

        // get gauge address
        ILiquidityGauge poolGauge = ILiquidityGauge(IGaugeAdder(gaugeFactory).getPoolGauge(boostedPool));
        uint256 rawAssets = boostedPool.balanceOf(address(this));
        uint256 stakedAssets = IERC20(address(poolGauge)).balanceOf(address(this));

        // total assets = bb-a-usd lp tokens + staked bb-a-usd lp tokens
        uint256 assets = rawAssets + stakedAssets;
        
        // todo optimise below
        // uint256 assets = 0;
        // for (uint8 i = 0; i < tokens.length; i++) {
        //     address linearPool = tokens[i];
        //     // the following uses the rate provider for each linear pool within the boosted pool
        //     // the rate returned is the conversion between linear pool LP tokens and the underlying (eg DAI).
        //     // (https://dev.balancer.fi/resources/pool-interfacing/metastable-pool)

        //     // ignore if this is the bb-a-usd pool.
        //     if (linearPool != boostedPool) {
        //         IRateProvider rateProvider = IRateProvider(linearPool);
        //         uint256 rate = rateProvider.getRate();
        //         console.log(linearPool);
        //         console.log(rate);
        //         console.log(balances[i]);
        //         assets += balances[i].mulWadDown(rate);
        //     }
        // }
        console.log(assets);
        return assets;
    }

    /**
     * @notice Claims rewards from Balancer
     * @dev see https://dev.balancer.fi/resources/vebal-and-gauges/gauges#how-to-claim-pending-tokens-for-a-given-pool
     */
    function claim() public {
        // todo: alter for arbitrum support. For now testing on mainnet
        // get gauge address
        IRewardTokenDistributor poolGauge = IRewardTokenDistributor(address(IGaugeAdder(gaugeFactory).getPoolGauge(boostedPool)));
        // claim and receive BAL as rewards
        poolGauge.claim_rewards(address(this));
    }

    /**
     * @notice harvests on hand rewards for the underlying assets and reinvests
     * @dev limits the amount of slippage that it is willing to accept. Permissioned as the token to purchase is computed
     * offchain. Purchases are executed in order.
     * @param assetsToAcquire ordered list of asset addresses to acquire using rewards
     * @param amounts ordered list of amounts of each asset to acquire using rewards
     */
    function compound(
        address[] memory assetsToAcquire,
        uint256[] memory amounts
    ) public {
        // todo:
        // - figure out optimal stable to collect for this compound (based on pool composition - eg swap BAL for one of the stables) -> this should be done offchain
        // - perform swap

        // - distribute fee's and restake into Bal pool.
        require(canCompound(), "not ready to compound");


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
        // todo: get bal balance
        bool hasSellableBalance = bal.balanceOf(address(this)) != 0;
        bool hasTimePassed = block.timestamp > lastSwapTime + swapCooldown;
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
