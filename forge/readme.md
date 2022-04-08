# vUSDC Vault
Vault that accepts underlying (USDC) and deposits into stargate to collect and compound STG rewards into more underlying.
Swaps are conducted through Blancer on Arbitrum. This vault is configured for arbitrum, but tested working on ETH Mainnet. 
Too launch on another network supporting stargate, simply change the `underyling` `router` `POOLTOKEN` and `staker` addresses. 
Rewards are compounded with an independent function by the vault owner, but can be configured to compound on deposit through a nested if statement. 
To add a `fee` call the `setFee` function, fees are collected on every compound and sent to the `feeCollector`. 

## Install foundry
you will need foundry installed to compile and test contracts in ./forge/src
```
curl -L https://foundry.paradigm.xyz | bash
```
then install foundry using 
```
foundryup
```
## Getting started
update lib's using
```
forge update
```
build contracts using
```
forge build
```
lint using 
```
yarn run lint
```
## Testing
To test vUSDC, run the following command:
```
forge t  -vvvv  --fork-url https://arb-mainnet.g.alchemy.com/v2/vkR4jribNoIWslgAymd5F8zQ1Ny8y9xL --fork-block-number 8623683 
```
The above test forks the Arbitrum network at block `8623683` and interaacts with stargate through the vault by replicating user deposits, withdrawals and compounds

To test reward reciept, `testRewards()` will need to be uncommented and the test run on ETH Mainnet. 
<img src="./gas-report"/>