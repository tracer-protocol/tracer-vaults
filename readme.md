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
The vault withdraw process is a critical piece of the vault itself. Due to the relationship between vaults and strategies, a vault is not expected to have access to liquid capital at all times. As such a withdraw process is used to ensure that users are able to withdraw their funds.

The process is as follows
- the vault attempts to pay out a withdraw from its capital on hand.
- If this isn't possible, the vault iterates through all its strategies and requests a withdraw of the outstanding capital (using `strategy.withdraw(amount)`). Each strategy will return as much capital as it can.
- If the vault still does not have enough capital after iterating through all strategies, it will simply pay out what it can at that point and only burn a portion of the users shares.

During this withdraw process, a strategy may choose to attempt to liquidate some of its positions in order to get this capital. This will mean that the next time the vault calls on a strategy, it should have more capital on hand to provide the vault.

## Strategies
Todo.