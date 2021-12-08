require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require('hardhat-deploy');
require("hardhat-deploy-ethers");
require("./secrets.json");

const { devAccount, reaperAccount, testAccount, ftmScan } = require('./secrets.json');

module.exports = {
  networks: {
    hardhat: {
      forking: {
        url: "https://rpc.ftm.tools/",
        blockNumber: 11238828,
        accounts: [reaperAccount]
      }
    },
    test: {
      url: "https://rpc.testnet.fantom.network/",
      accounts: [testAccount]
    },
    opera: {
      url: "https://rpc.ftm.tools/",
      accounts: [testAccount]
    }
  },
  etherscan: {
    apiKey: ftmScan
  },
  solidity: {
    compilers: [
      {
        version: "0.6.12"
      },
      {
        version: "0.7.5"
      },
      {
        version: "0.8.0"
      },
      {
        version: "0.8.2"
      }
    ],
    settings: {
      optimizer: {
        enabled: false,
        runs:200
      }
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 200000
  }
};