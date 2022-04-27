### Vault
This outlines the specification for the ERC4626 compliant vault. Further information regarding ERC4626 vaults can be found in [EIP-4626](https://eips.ethereum.org/EIPS/eip-4626).

## Spec
`underlying` The underlying ERC20 principle asset

`longFarmer` The contract responsible for tracking skew state

`Threshold` The threshold skew value

`longFarmer.swap()` Allows swaps from EOA's when skew > Threshold. Users can swap Longtokens for USDC at current price, without slippage or commitment windows. 

## User Flow
Users deposit USDC `underlying` into the Vault. 

Users recieve vAsset tokens, a tokenised representation of their vault position, ie. `shares`.

Vault hands off skew watch conditions to longFarmer, who puts the vault into an `Active` state when a skew exists. 

Users can withdraw USDC from the vault by calling `Withdraw`
