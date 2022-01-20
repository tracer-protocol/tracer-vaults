pragma solidity ^0.8.0;

import "../interfaces/IStrategy.sol";

contract BasicStrategy is IStrategy {

    // target perpetual pool and cached params
    address public POOL;
    address public POOL_SHORT_TOKEN;

    // target hedge asset and cached params
    address public HEDGE_ASSET;
    address public HEDGE_SWAP; //uniwap pool to swap HEDGE_ASSET for VAULT_ASSET

    // vault collateral asset
    address public VAULT_ASSET;

    // strategy current state
    // number of pending commits for minting short pool tokens
    uint256 public pendingMints;
    // number of pending commits for burning short pool tokens
    uint256 public pendingBurns;


    constructor() {

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
}