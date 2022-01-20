pragma solidity ^0.8.0;

import "../interfaces/IStrategy.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

contract BasicStrategy is IStrategy {

    // target perpetual pool and cached params
    address public constant POOL;
    address public POOL_SHORT_TOKEN;

    // target hedge asset and cached params
    address public constant HEDGE_ASSET; //eg ETH in a ETH/USD+DAI pool

    // vault collateral asset
    address public constant VAULT_ASSET; //eg DAI in a ETH/USD+DAI pool

    // strategy current state
    // number of pending commits for minting short pool tokens
    uint256 public pendingMints;
    // number of pending commits for burning short pool tokens
    uint256 public pendingBurns;

    // uniswap params
    ISwapRouter public immutable swapRouter;
    uint24 public constant poolFee = 3000;


    constructor(address _swapRouter) {
        swapRouter = ISwapRouter(_swapRouter);

        // approve maximum amount to avoid approvals later on for swaps
        // this will save a large amount of gas
        // IERC20(HEDGE_ASSET).approve(address(swapRouter), MAX_UINT);
        // IERC20(VAULT_ASSET).approve(address(swapRouter), MAX_UINT);
    }

    function value() external view returns(uint256) {
        // todo value our assets
        // 1. value of hedge = query hedge liquidity pool and get price
        // in terms of VAULT_ASSET
        // 2. value of pool tokens = query perpetual pool to get current exchange rate
        // note that this may not be the price you get at the next mint or burn and
        // should be considered an estimate.
        // 3. value of any spare VAULT_ASSET can be priced 1:1.
        return 0;
    }

    /**
    * @notice triggers a rebalance on the strategy.
    */
    function rebalance() external {
        //TODO This is the bulk of the strategy

        // HIGH LEVEL STEPS
        // 1: update state based on currently held short tokens, hedge asset
        // and the skew of the perpetual pool
        // 2: based on current state either unwind positions (burn and sell hedge), 
        // take more positions (mint and buy hedge) or do nothing.
        // 3: 
    }

    /**
    * @notice returns the maximum amount of underlying that can be safely withdrawn
    * from this strategy instantly.
    */
    function withdrawable() external view returns(uint256) {
        //TODO: Risk params here will define how much HEDGE asset we can sell to
        // instantly get some liquid assets to return.
        // there may be spare VAULT_ASSETS on hand already that can be accounted for
        // here too.
        return 0;
    }

    /**
    * @notice withdraws a maximum of amount underlying from the strategy. Only callable
    * by the vault.
    * @param amount the amount of underlying tokens request to be withdrawn.
    */
    function withdraw(uint256 amount) external {
        //TODO: Withdraw as much liquid assets up to amount
        // 1. Send to vault any spare VAULT_ASSETS on hand
        // 2. Sell as much HEDGE_ASSET as possible with minimal slippage and within
        // our risk params.
        // 3. unwind enough positions to cover this debt in the next rebalance.
    }

    /*///////////////////////////////////////////////////////////////
                            Helper Functions
    //////////////////////////////////////////////////////////////*/
    
    /**
    * @notice purchases hedge assets using the provided amountIn 
    * of VAULT_ASSET
    * @param
    */
    function purchaseHedge(uint256 amountIn) internal {
        ISwapRouter.ExactInputSingleParams memory params =
        ISwapRouter.ExactInputSingleParams({
            tokenIn: VAULT_ASSET,
            tokenOut: HEDGE_ASSET,
            fee: poolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            // todo make the following safe for production
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactInputSingle(params);

        // todo validate amountOut is reasonable
    }

    /**
    * @notice sells hedge assets using the provided amountIn of hedge
    */
    function sellHedge(uint256 amountIn) internal {
        ISwapRouter.ExactInputSingleParams memory params =
        ISwapRouter.ExactInputSingleParams({
            tokenIn: HEDGE_ASSET,
            tokenOut: VAULT_ASSET,
            fee: poolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            // todo make the following safe for production
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactInputSingle(params);

        // todo validate amountOut is reasonable
    }
}