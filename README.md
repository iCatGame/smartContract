# Hardhat合约测试

## 测试合约

```shell
# REPORT_GAS=true npx hardhat test
npx hardhat run scripts/testCA.js
```

## 部署合约

<!-- 使用[Remix](http://remix.ethereum.org/) -->
```shell
npx hardhat run scripts/deploy.js --network arbitrumGoerli
```

## 开源合约

```shell
npx hardhat verify --network arbitrumGoerli <ICAT_CONTRACT_ADDRESS> 
npx hardhat verify --network arbitrumGoerli <EGG_CONTRACT_ADDRESS> <ICAT_CONTRACT_ADDRESS>
```