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
