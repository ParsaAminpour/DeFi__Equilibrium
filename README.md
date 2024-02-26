# EquilibriumCore Smart Contract

This repository contains the source code for the EquilibriumCore smart contract, which is a key component of the Equilibrium project. The EquilibriumCore smart contract is a Solidity-based implementation of an algorithmic stablecoin, similar to DAI or MakerDAO. It maintains a stable value by being pegged to a reserve currency or a basket of assets.

## Overview
The EquilibriumCore smart contract is designed to be the core functionality of the Equilibrium algorithmic stablecoin. It is built using Solidity and incorporates features from the OpenZeppelin library, including SafeERC20, ReentrancyGuard, and Ownable. The smart contract is loosely based on the DAI and MakerDAO stablecoins.

The EquilibriumCore smart contract has a key invariant: the Health Factor (Hf) should always be above the HEALTH_FACTOR_THRESHOLD. If the Hf falls below this threshold, the contract will become useless and the invariant will be broken.

## Features
- Implementation of an algorithmic stablecoin, similar to DAI or MakerDAO
- Uses Chainlink price feeds for collateral assets
- Incorporates features from OpenZeppelin library, including SafeERC20, ReentrancyGuard, and Ownable
- Health Factor (Hf) invariant to maintain stability

<br />

## EquilibriumCore Architecture (Just Significant Functions)
![EquilibriumCoreArchitecture](/EquilibriumCoreUpgradeableArchitecture.jpg 'Equilibrium Core Architecture Diagram')

<br />

## Gas-SnapShot
| src/EquilibriumCore.sol:EquilibriumCore contract |                 |       |        |        |         |
|--------------------------------------------------|-----------------|-------|--------|--------|---------|
| Deployment Cost                                  | Deployment Size |       |        |        |         |
| 1715103                                          | 8768            |       |        |        |         |
| Function Name                                    | min             | avg   | median | max    | # calls |
| depositCollateral                                | 64498           | 64498 | 64498  | 64498  | 1       |
| depositCollateralAndMintEquilibrium              | 7678            | 73529 | 62853  | 153153 | 77      |
| getCollateralTokenSupportedPriceFeedAddresses    | 911             | 4911  | 4911   | 8911   | 2       |
| getEquilibriumTokenAddress                       | 225             | 225   | 225    | 225    | 4       |
| getSupportedTokenAddress                         | 495             | 2495  | 2495   | 4495   | 2       |
| getUsdValue                                      | 14972           | 14972 | 14972  | 14972  | 256     |
| getUserCollateralDepositedAmount                 | 782             | 782   | 782    | 782    | 5       |
| get_health_factor                                | 3532            | 3532  | 3532   | 3532   | 3       |
| liquidation                                      | 5913            | 7154  | 7017   | 7913   | 5       |
| owner                                            | 2398            | 2398  | 2398   | 2398   | 1       |
| withdrawCollateral                               | 4043            | 11689 | 12605  | 17506  | 4       |
| withdrawCollateralWithBurnEquilibrium            | 51951           | 51951 | 51951  | 51951  | 1       |

<br />

## Usage

### Build

```shell
$ forge build
```

## Test

```shell
$ forge test -vv
```

## Format

```shell
$ forge fmt
```

## Test Coverages

```shell
$ forge coverage
```

## Anvil

```shell
$ anvil
```

## Deploy After you setUp your own key

```shell
$ forge script script/EquilibriumCoreScript.sol:EquilibriumCoreScript --rpc-url <YOU-RPC-ENDPOINT> --broadcast --verify
```
## To Deploy Project on Scroll ZK network
```shell
$ forge create EquilibriumCore --rpc-url=https://sepolia-rpc.scroll.io
```

## Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```