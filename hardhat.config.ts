import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";
import "dotenv/config";

import { task } from "hardhat/config";

let ethers = require("ethers");
// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

task("new:wallet", "Generate New Wallet", async (taskArgs, hre) => {
  const wallet = ethers.Wallet.createRandom();
  console.log("PK: ", wallet._signingKey().privateKey);
  console.log("Address: ", wallet.address);
});

// Setup Default Values
let PRIVATE_KEY, PRIVATE_KEY_MAINNET;
if (process.env.PRIVATE_KEY) {
  PRIVATE_KEY = process.env.PRIVATE_KEY;
} else {
  console.log("⚠️ Please set PRIVATE_KEY in the .env file");
  PRIVATE_KEY = ethers.Wallet.createRandom()._signingKey().privateKey;
  console.log("🚀 | PRIVATE_KEY", PRIVATE_KEY);
}

if (process.env.PRIVATE_KEY_MAINNET) {
  PRIVATE_KEY_MAINNET = process.env.PRIVATE_KEY_MAINNET;
} else {
  console.log("⚠️ Please set PRIVATE_KEY in the .env file");
}

if (!process.env.INFURA_API_KEY) {
  console.log("⚠️ Please set INFURA_API_KEY in the .env file");
}

if (!process.env.ETHERSCAN_API_KEY) {
  console.log("⚠️ Please set ETHERSCAN_API_KEY in the .env file");
}

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      saveDeployments: true,
      accounts: [PRIVATE_KEY],
    },
    hardhat: {
      // TODO: Add snapshot block
      forking: {
        url: "https://polygon-mumbai.g.alchemy.com/v2/o1dKBt7FcYQrRUNfgHX-DUUXHNvPKA1v",
        block: 27524000,
      },
      mining: {
        auto: true,
      },
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      chainId: 1,
      accounts: [PRIVATE_KEY],
      saveDeployments: true,
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
      chainId: 4,
      accounts: [PRIVATE_KEY],
      saveDeployments: true,
    },
    matic: {
      url: "https://polygon-rpc.com/",
      chainId: 137,
      accounts: [PRIVATE_KEY],
    },
    mumbai: {
      url: "https://rpc-mumbai.matic.today",
      chainId: 80001,
      accounts: [PRIVATE_KEY],
      saveDeployments: true,
    },
    optimism_mainnet: {
      url: "https://mainnet.optimism.io",
      chainId: 10,
      accounts: [PRIVATE_KEY],
      saveDeployments: true,
    },
    optimism_testnet: {
      url: "https://kovan.optimism.io",
      chainId: 69,
      accounts: [PRIVATE_KEY],
      saveDeployments: true,
    },
    arbitrum_mainnet: {
      url: "https://arb1.arbitrum.io/rpc",
      chainId: 42161,
      accounts: [PRIVATE_KEY],
      saveDeployments: true,
    },
    arbitrum_testnet: {
      url: "https://rinkeby.arbitrum.io/rpc",
      chainId: 421611,
      accounts: [PRIVATE_KEY],
      saveDeployments: true,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.10",
        settings: {
          optimizer: {
            enabled: true,
          },
        },
      },
      {
        version: "0.7.6",
        settings: {
          optimizer: {
            enabled: true,
          },
        },
      },
    ],
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
    },
    real_owner: {
      default: "0x0E99472F530d4fcb39EF643744Df8Fb300078a42", // MAN Owner dennis
    },
    DAI: {
      default: "0x9A753f0F7886C9fbF63cF59D0D4423C5eFaCE95B",
      80001: "0x9A753f0F7886C9fbF63cF59D0D4423C5eFaCE95B",
    },
    POOL_PROXY: {
      default: "0x6C9fB0D5bD9429eb9Cd96B85B81d872281771E6B",
      80001: "0x6C9fB0D5bD9429eb9Cd96B85B81d872281771E6B",
    },
    ETH_GATEWAY: {
      default: "0x2a58E9bbb5434FdA7FF78051a4B82cb0EF669C17",
      80001: "0x2a58E9bbb5434FdA7FF78051a4B82cb0EF669C17",
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },

  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
    deploy: "./deploy",
  },
  mocha: {
    timeout: 2000000000,
  },
  typechain: {
    outDir: "typechain",
    target: "ethers-v5",
  },
  gasReporter: {
    enabled: true,
    gasPrice: 100,
  },
};
