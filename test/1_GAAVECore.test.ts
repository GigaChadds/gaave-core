import { BigNumber, Wallet } from "ethers";
import { deployments, ethers } from "hardhat";

import { GAAVECore } from "./../typechain/contracts/GAAVECore";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";

const helpers = require("@nomicfoundation/hardhat-network-helpers");

const daiABI = require("./ERC20ABI.json");

let count = 500;

describe("GAAVECore", function () {
  let owner: SignerWithAddress;
  let gaave: GAAVECore;
  let dai;

  before(async function () {
    // Impersonate Account
    const address = "0x294a5A863749c8419fB3462a402685f895253b52";
    // owner = await ethers.getImpersonatedSigner(address);

    await helpers.impersonateAccount(address);
    owner = await ethers.getSigner(address);
    console.log(owner);

    // Setup Test
    await deployments.fixture(["GAAVE"]);
    gaave = await ethers.getContract("GAAVECore", owner);

    dai = await ethers.getContractAt(
      daiABI,
      "0x9A753f0F7886C9fbF63cF59D0D4423C5eFaCE95B",
      owner
    );
  });

  it("should have a balance of 0", async function () {
    let balance = await owner.getBalance();
    console.log(balance.toString());
  });

  it("Should Deposit ETH/MATIC", async function () {
    let depositAmount = ethers.utils.parseEther("1");
    await gaave.depositETH({ value: depositAmount });
  });

  it("Should Deposit DAI", async function () {
    let balance = await owner.getBalance();
    console.log(balance.toString());
  });
});
