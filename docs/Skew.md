### Skew: Explained
Perpetual Pools is a derivative contract that swaps collateral between the long and short sides of one pool – when the collateral is unequal between these sides, the pool is 'skewed' which results in the swap agreement creating polarised leverage.
This skew can be "farmed" to extract value such that the tokens aquired bring skew back to the threshold target value (1).

## Example
Consider the following example: 

3X-Long-BTC pool currently has 2,000,000 usdc in the long pool, and 4,200,000 in the short pool. At the next rebalance, price appreciates, and therefore, short token balance will be paying the long sided pool at a rate higher than 3X, such is the effect of skew. In this example, a skew of 2.1 exists, a skew farmer would find the optimal consumption rate of long tokens to acquire **while a skew exists** that brings this value back to 1.

On disposal, the long sided tokens can be redeemed for an amount higher than the expected amount of usdc, due to the effects of skew. 