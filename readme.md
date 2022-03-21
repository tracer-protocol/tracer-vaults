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
 ┣ interfaces
 ┃ ┣ IERC4626.sol
 ┃ ┣ IERC4626Router.sol
 ┃ ┣ IStrategy.sol
 ┃ ┗ ITracerVault.sol
 ┣ strategies
 ┃ ┗ PermissionedStrategy.sol
 ┣ utils
 ┃ ┣ ERC4626.sol
 ┃ ┣ FixedPointMathLib.sol
 ┃ ┣ MockStrategy.sol
 ┃ ┗ TestERC20.sol
 ┣ VaultV1.sol
 ┗ VaultV2.sol

```

## Vaults
`VaultV1.sol` is the core contract in charge of managing strategies involved in generating yield for the Tracer protocol.

The Vault sends funds to a Strategy which must be set using `setStrategy` after deploying a vault.
To interact with the Vault, the caller must be whitelisted. Only governance can add addresses to the `whitelist` mapping.
Vault Deposits and withdrawals must come from an address in this `whitelist` mapping.
On successful deposit, funds are sent to the `strategy` in the same transaction, users recieve `shares` in return.
### Withdraw Process
#### V1 Withdraw Process
The V1 withdraw process has been reduced to its simplest form.

The following are the steps
- A user requests a withdraw with the vault. This increases their pending withdraw limit as well as the `totalRequestedWithdraws`. This user is unable to withdraw for 24 hours.
- the strategy has 24 hours in which these funds should be liquidated. This will increase the `withdrawable` amount of the strategy.
- The user is then able to withdraw 24 hours later. If funds are not available on hand this withdraw will revert.
                                    no(throw)
         requestWithdraw            ▲
┌───────┬─────────────►┌─────────┐  │
│ USER  │              │VAULT    ├──┴───────────┐
│       │              │         │ call > 24hrs?│
└─────▲─┴──withdraw?──►└─────────┴─┬────────────┘
      │                            │
      └────Withdraw◄──────────────YES

## Strategies
Strategy contract recieves funds from the Vault after a successful deposit.
Returning funds to the vault must be conducted using the `returnAsset` function, ensuring correct accounting in the vault.

## Diagram
                   ┌──────────┐
                   │          │
                   │  USER    │
                   └┬────────┬┘
                    │        │
                    │        │
              DEPOSIT        WITHDRAW
                    │        │
                    │        │
                    │        │
┌───────────────────┴────────┴─────────────────────────┐
│                                                      │
│                   VAULT  ERC4626                     │
│                                                      │
└─────────────────────┬────────────────────────────────┘
                      │           ▲
                      ▼           │
                      │           │
                     ┌┴───────────┴┐
                     │             ├────────►┌──────────────┐
                     │  STRATEGY   │         │              │
                     │             │         │   SKEWFARM   │
                     │             │◄────────┤              │
                     └─────────────┘         └──────────────┘