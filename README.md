Smart Contract Lottery with Chainlink VRF

# Requirements

Install [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

Install [foundry](https://getfoundry.sh/)

# Quickstart

```
git clone https://github.com/caglacelik/lottery.git
cd lottery
make build
```

# Usage

### Start a local node

```
make anvil
```

### Build

```shell
make build
```

### Format

```shell
make format
```

### Test

```shell
make test
```

or

```shell
forge test
```

for testnet

```shell
forge test --fork-url $SEPOLIA_RPC_URL
```

### Test Coverage

```
forge coverage
```

### Gas Snapshots

```shell
make snapshot
```

### Anvil

```shell
anvil
```

### Deploy

```shell
make deploy
```

To deploy testnet/mainnet PLEASE MAKE SURE;

1. Set up the environment variables
   `SEPOLIA_RPC_URL`, `PRIVATE_KEY` and `ETHERSCAN_API_KEY` to verify your contract on [Etherscan](https://etherscan.io/).

2. Get test ETH from the [Faucets](https://faucets.chain.link/).

### Help

```shell
forge --help
anvil --help
cast --help
```

# Contributing

Contributions to this project are welcome.
