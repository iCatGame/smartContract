require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    networks: {
      arbitrumGoerli: {
        url: "https://goerli-rollup.arbitrum.io/rpc",
        accounts: []
      },
    },
    etherscan: {
      apiKey: "I1PKX2ATV2VK4QW2US6FEEEVDF1XWW2AM6",
  },
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 400,
      },
    },
  },
};