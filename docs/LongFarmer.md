### LongFarmer Docs
The longFarmer contract contains all logic relevant to tracking skew, adjusting skew defined positions, enabling skew defined swaps, and offloading assets when not skewed. 

## Spec
`initialize`: Params passed to initialize set the state variables for the contract, including the vault address. This function should be called from within the Vault.sol Constructor.

`value`: Returns the current value of the LongFarmer, in usdc. Accounts for aggregate balance in `poolCommitter`. 

`poke`: This function is called at regular intervals (predefined by `window`) to check for a skew, and act accordingly. Currently, the logic simply sets the vault state, `Active` if a skew exists, which turns on the contingent parameters that facilitate long skew farming.

`window`: Public variable which sets the next poke period. 

`nextSkew`: Calculates the anticipated next skew, based on rate of change. 

`target`: Calculates the target amount of longtTokens to acquire, to bring skew back to 1. 

`acquire`: Acquires longPool Tokens. Vault must be active, not unwinding, not stopping and have a valid skew > threshold at next skew. Currently, this function relies on end users forecasting the skew at next commit, based off SMA of previous ~8 samples of price. This function may only be called by whitelisted EOA's. 

`dispose`: Much like Acquire, dispose handles the logic for offloading long tokens in the abscence of a skew. This function also relies on EOA's performing the predicted upcoming forecasted state, prior to acting on this function. Again, only whitelisted EOA's may call this function. 

`agBal`: A helper function to discern wether funds come from poolCommitter aggregate balance, or from the longFarmer internal balance. 

`_swap`: A swap function allowing EOA's to swap `longTokens` for `USDC` at the current price. Can only be called when a skew exists, and the vault is set to active. 

`longTokenPrice`: Returns the current price of long tokens, in USDC. 

`setActive`: **important** setActive is a helper function for testing purposes, and should not be pushed to prod. 

