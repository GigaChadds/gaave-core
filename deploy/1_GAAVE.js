const { ethers } = require("hardhat");
const { GasLogger } = require("../utils/helper.js");

require("dotenv").config();
const gasLogger = new GasLogger();

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer, real_owner, ETH_GATEWAY, POOL_PROXY } =
    await getNamedAccounts();
  const chainId = await getChainId();

  // Config
  console.log(`Deploying GAAVE... from ${deployer}`);

  // Token Addresses
  let TOKEN_ADDRESSES = [
    "0x9A753f0F7886C9fbF63cF59D0D4423C5eFaCE95B", // DAI
    "0xb685400156cF3CBE8725958DeAA61436727A30c3", // MATIC
  ];

  // Chainlink Addresses
  let CHAINLINK_ADDRESSES = [
    "0x0FCAa9c899EC5A91eBc3D5Dd869De833b06fB046", //DAI
    "0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada", //MATIC
  ];

  // Mapping

  let gaave = await deploy("GAAVECore", {
    from: deployer,
    args: [
      ETH_GATEWAY,
      POOL_PROXY,
      TOKEN_ADDRESSES[1],
      TOKEN_ADDRESSES,
      CHAINLINK_ADDRESSES,
    ],
  });

  gasLogger.addDeployment(gaave);
};

module.exports.tags = ["GAAVE"];
