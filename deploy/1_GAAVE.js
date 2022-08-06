const { ethers } = require("hardhat");
const { GasLogger } = require("../utils/helper.js");

require("dotenv").config();
const gasLogger = new GasLogger();

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer, real_owner } = await getNamedAccounts();
  const chainId = await getChainId();

  // Config
  console.log(`Deploying GAAVE... from ${deployer}`);

  let erc721AMock = await deploy("GAAVE", {
    from: deployer,
    args: [],
  });

  gasLogger.addDeployment(erc721AMock);
};

module.exports.tags = ["GAAVE"];
