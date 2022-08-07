const { ethers } = require("hardhat");
const { GasLogger } = require("../utils/helper.js");

require("dotenv").config();
const gasLogger = new GasLogger();

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer, real_owner } = await getNamedAccounts();
  const chainId = await getChainId();

  // Config
  console.log(`Deploying GAAVEBadge... from ${deployer}`);

  let baseURI = "";
  let gaaveBadge = await deploy("GAAVEBadge", {
    from: deployer,
    args: ["GAAVE Badges", "GAAVEB", baseURI],
  });

  gasLogger.addDeployment(gaaveBadge);
};

module.exports.tags = ["GAAVEBadge"];
