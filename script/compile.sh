# Compile each repository using its original compiler settings and OpenZeppelin contracts version.
# It's necessary to explicitly specify the OpenZeppelin contracts version because the
# `@mean-finance` repositories use a few different versions of this package. Using the same
# OpenZeppelin contracts package for all of them would result in compilation errors.

forge build --contracts node_modules/@mean-finance/deterministic-factory/solidity/ \
  --use 0.8.7 --optimizer-runs 200 \
  --remappings @openzeppelin/contracts/=node_modules/@mean-finance/deterministic-factory/node_modules/@openzeppelin/contracts/ \
  --skip test --skip scripts

forge build --contracts node_modules/@mean-finance/nft-descriptors/solidity/ \
  --use 0.8.16 --optimizer-runs 200 \
  --remappings @openzeppelin/contracts/=node_modules/@mean-finance/nft-descriptors/node_modules/@openzeppelin/contracts/ \
  --skip test --skip scripts

forge build --contracts node_modules/@mean-finance/chainlink-registry/contracts \
  --use 0.8.16 --optimizer-runs 9999 \
  --remappings @openzeppelin/contracts/=node_modules/@mean-finance/chainlink-registry/node_modules/@openzeppelin/contracts/ \
  --skip test --skip scripts

forge build --contracts node_modules/@mean-finance/transformers/solidity \
  --use 0.8.22 --optimizer-runs 9999 \
  --remappings @openzeppelin/contracts/=node_modules/@mean-finance/transformers/node_modules/@openzeppelin/contracts/ \
  --skip test --skip scripts

forge build --contracts node_modules/@mean-finance/oracles/solidity \
  --use 0.8.16 --optimizer-runs 9999 \
  --remappings @openzeppelin/contracts/=node_modules/@mean-finance/oracles/node_modules/@openzeppelin/contracts/ \
  --skip test --skip scripts

forge build --contracts node_modules/@mean-finance/dca-v2-core/contracts \
  --use 0.8.16 --optimizer-runs 9999 \
  --remappings @openzeppelin/contracts/=node_modules/@mean-finance/dca-v2-core/node_modules/@openzeppelin/contracts/ \
  --skip test --skip scripts

forge build --contracts node_modules/@mean-finance/dca-v2-core/contracts/DCAHub/DCAHub.sol \
  --use 0.8.16 --optimizer-runs 300 \
  --remappings @openzeppelin/contracts/=node_modules/@mean-finance/dca-v2-core/node_modules/@openzeppelin/contracts/ \
  --skip test --skip scripts --via-ir

forge build --contracts node_modules/@mean-finance/swappers/solidity/ \
  --use 0.8.16 --optimizer-runs 9999 \
  --remappings @openzeppelin/contracts/=node_modules/@mean-finance/swappers/node_modules/@openzeppelin/contracts/ \
  --skip test --skip scripts

forge build --contracts node_modules/@mean-finance/dca-v2-periphery/contracts/ \
  --use 0.8.22 --optimizer-runs 9999 \
  --remappings @openzeppelin/contracts/=node_modules/@mean-finance/dca-v2-periphery/node_modules/@openzeppelin/contracts/ \
  --skip test --skip scripts

forge build --contracts node_modules/@mean-finance/dca-v2-periphery/contracts/ \
  --use 0.8.22 --optimizer-runs 9999 \
  --remappings @openzeppelin/contracts/=node_modules/@mean-finance/dca-v2-periphery/node_modules/@openzeppelin/contracts/ \
  --skip test --skip scripts

# Compile OpenZeppelin's TimelockController. This is necessary for its artifact to be included in
# Foundry's artifact file, which lets Sphinx verify the contract on Etherscan.
forge build --contracts node_modules/@mean-finance/dca-v2-core/node_modules/@openzeppelin/contracts/governance/TimelockController.sol \
  --use 0.8.9 --optimizer-runs 200 \
  --remappings @openzeppelin/contracts/=node_modules/@mean-finance/dca-v2-core/node_modules/@openzeppelin/contracts/ \
  --skip test --skip scripts

forge build