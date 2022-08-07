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

  let gaave = await deploy("GAAVE", {
    from: deployer,
    args: [ETH_GATEWAY, POOL_PROXY],
  });

  gasLogger.addDeployment(gaave);
};

module.exports.tags = ["GAAVE"];
