# Compile each repository using its original compiler settings and OpenZeppelin contracts version.
# It's necessary to explicitly specify the OpenZeppelin contracts version because the
# `@mean-finance` repositories use a few different versions of this package. Using the same
# OpenZeppelin contracts package for all of them would result in compilation errors.

forge build --contracts node_modules/@mean-finance/deterministic-factory/solidity/ \
  --use 0.8.7 --optimizer-runs 200 \
  --remappings @openzeppelin/contracts/=node_modules/@mean-finance/deterministic-factory/node_modules/@openzeppelin/contracts/ \
  --skip test --skip scripts

forge build