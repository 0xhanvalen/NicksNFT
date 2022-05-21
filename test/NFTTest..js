const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFT", async function () {
  let Contract, Token, owner, minter;

  beforeEach(async function () {
    Contract = await ethers.getContractFactory("NickNFT");
    [owner, minter] = await ethers.getSigners();
    Token = await Contract.deploy();
    await Token.deployed();
    console.log("token deployed to: ", Token.address);
  });

  it("Should be named", async () => {
    expect(await Token.name()).to.exist;
  });

  it("Should not allow mints unless minting", async () => {
    await expect(Token.publicMint(1)).to.be.revertedWith("Not Minting");
  });

  it("Should allow the deployer to enable minting", async () => {
    await Token.setPublicSale(true);
    await expect(Token.publicMint(1)).to.be.revertedWith("Not Enough ETH");
  });

  it("Should block non-owners from enabling minting", async () => {
    await expect(Token.connect(minter).setPublicSale(true)).to.be.revertedWith(
      "Not Owner"
    );
  });

  it("Should allow up to 3 mints at once for public sale", async () => {
    await Token.setPublicSale(true);
    await expect(Token.publicMint(3, {value: ethers.utils.parseEther("0.375")})).to.not.be.reverted;
  });

  it("Should only allow up to 3 mints at once for public sale", async () => {
    await Token.setPublicSale(true);
    await expect(Token.publicMint(4, {value: ethers.utils.parseEther("0.5")})).to.be.revertedWith("Too Many Mints");
  });
});
