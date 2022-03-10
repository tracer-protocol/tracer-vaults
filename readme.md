# Tracer Vaults
WIP Tracer vaults

## Getting Started
Install dependencies using
```
yarn install
```

Check linting and fix linting issues using
```
yarn run lint
yarn run lint:fix
```

Run tests using
```
yarn run test
```

Test coverage using
```
yarn run coverage
```

## Blueprint

```ml
contracts
├─ test
│  └─ Greeter.t — "Greeter Tests"
├─ interfaces
│  └─ IERC4626.sol — "ERC4626 Interface"
|  └─ IERC4626TRACER.sol — "ERC4626TRACER Interface"
└─ Vault — "A modified ERC4626 Vault"

```

## Vaults
`Vault.sol` is the core contract in charge of managing strategies involved in generating yield for the Tracer protocol.

Each vault may have many strategies associated with it, and may allocate capital to strategies via admin controls. 
### Withdraw Process
#### V1 Withdraw Process
The V1 withdraw process has been reduced to its simplest form.

The following are the steps
- A user requests a withdraw with the vault. This increases their pending withdraw limit as well as the `totalRequestedWithdraws`. This user is unable to withdraw for 24 hours.
- the strategy has 24 hours in which these funds should be liquidated. This will increase the `withdrawable` amount of the strategy.
- The user is then able to withdraw 24 hours later. If funds are not available on hand this withdraw will revert.

## Strategies
Todo.