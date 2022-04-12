# Tracer Skew Farming Vault
WIP

## Goal
To farm the skew between long and short positions on chain.
Users deposit USDC into the longVault, an ERC4626 complaint tokenised vault. 
Stakers can stake longTokens into the PPStaker contract to earn TCR rewards where staked longTokens are placed into a queue.
If a skew exists && nextPrice > prevPrice, the vault will allow swaps of USDC for LongTokens, users can instantly sell for USDC as opposed to waiting. 
If the above condition holds during a `poke()`, the vault will pull longTokens from the staker queue, replacing their psoiton with the 
equivelant in USDC at the price on execution. 

Stakers will either withdraw: 
a) The long tokens they staked + TCR rewards
b) The USDC made from selling the longToken at a profit

Vault now holds longTokens while a skew exists, making a return on the difference. When the skew is no longer > threshold, vault will burn
all longTokens on Tracer, this should increase its positoin of USDC relative to USDC spent on acquiring lontTokens. 


## Getting Started
you will need foundry installed to compile and test contracts in ./forge/src
```
curl -L https://foundry.paradigm.xyz | bash
```
then install foundry using 
```
foundryup
```
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

## TO-DO
- long vault
- short vault
- tests