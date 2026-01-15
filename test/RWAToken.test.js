const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RWAToken", function () {
  let rwaToken;
  let owner;
  let minter;
  let compliance;
  let pauser;
  let user1;
  let user2;
  let user3;

  const TOKEN_NAME = "Real Estate Token";
  const TOKEN_SYMBOL = "RET";
  const ASSET_TYPE = "Real Estate";
  const ASSET_ID = "RE-001";
  const DESCRIPTION = "Commercial property in downtown";
  const VALUATION = ethers.parseEther("1000000"); // $1,000,000

  beforeEach(async function () {
    [owner, minter, compliance, pauser, user1, user2, user3] = await ethers.getSigners();

    const RWAToken = await ethers.getContractFactory("RWAToken");
    rwaToken = await RWAToken.deploy(
      TOKEN_NAME,
      TOKEN_SYMBOL,
      owner.address,
      ASSET_TYPE,
      ASSET_ID,
      DESCRIPTION,
      VALUATION
    );
    await rwaToken.waitForDeployment();

    // Grant roles to different addresses for testing
    await rwaToken.grantRole(await rwaToken.MINTER_ROLE(), minter.address);
    await rwaToken.grantRole(await rwaToken.COMPLIANCE_ROLE(), compliance.address);
    await rwaToken.grantRole(await rwaToken.PAUSER_ROLE(), pauser.address);
  });

  describe("Deployment", function () {
    it("Should set the right name and symbol", async function () {
      expect(await rwaToken.name()).to.equal(TOKEN_NAME);
      expect(await rwaToken.symbol()).to.equal(TOKEN_SYMBOL);
    });

    it("Should set the correct asset information", async function () {
      const assetInfo = await rwaToken.getAssetInfo();
      expect(assetInfo.assetType).to.equal(ASSET_TYPE);
      expect(assetInfo.assetId).to.equal(ASSET_ID);
      expect(assetInfo.description).to.equal(DESCRIPTION);
      expect(assetInfo.valuation).to.equal(VALUATION);
      expect(assetInfo.isActive).to.equal(true);
    });

    it("Should grant DEFAULT_ADMIN_ROLE to owner", async function () {
      expect(await rwaToken.hasRole(await rwaToken.DEFAULT_ADMIN_ROLE(), owner.address)).to.be.true;
    });

    it("Should revert if owner is zero address", async function () {
      const RWAToken = await ethers.getContractFactory("RWAToken");
      await expect(
        RWAToken.deploy(
          TOKEN_NAME,
          TOKEN_SYMBOL,
          ethers.ZeroAddress,
          ASSET_TYPE,
          ASSET_ID,
          DESCRIPTION,
          VALUATION
        )
      ).to.be.revertedWith("RWAToken: owner cannot be zero address");
    });

    it("Should revert if valuation is zero", async function () {
      const RWAToken = await ethers.getContractFactory("RWAToken");
      await expect(
        RWAToken.deploy(
          TOKEN_NAME,
          TOKEN_SYMBOL,
          owner.address,
          ASSET_TYPE,
          ASSET_ID,
          DESCRIPTION,
          0
        )
      ).to.be.revertedWith("RWAToken: valuation must be greater than zero");
    });
  });

  describe("Minting", function () {
    it("Should allow minter to mint tokens", async function () {
      const amount = ethers.parseEther("1000");
      await rwaToken.connect(minter).mint(user1.address, amount);
      expect(await rwaToken.balanceOf(user1.address)).to.equal(amount);
      expect(await rwaToken.totalSupply()).to.equal(amount);
    });

    it("Should not allow non-minter to mint", async function () {
      const amount = ethers.parseEther("1000");
      await expect(
        rwaToken.connect(user1).mint(user2.address, amount)
      ).to.be.revertedWithCustomError(rwaToken, "AccessControlUnauthorizedAccount");
    });

    it("Should not allow minting to zero address", async function () {
      const amount = ethers.parseEther("1000");
      await expect(
        rwaToken.connect(minter).mint(ethers.ZeroAddress, amount)
      ).to.be.revertedWith("RWAToken: cannot mint to zero address");
    });

    it("Should not allow minting when asset is inactive", async function () {
      await rwaToken.deactivateAsset();
      const amount = ethers.parseEther("1000");
      await expect(
        rwaToken.connect(minter).mint(user1.address, amount)
      ).to.be.revertedWith("RWAToken: asset is not active");
    });
  });

  describe("Burning", function () {
    beforeEach(async function () {
      await rwaToken.connect(minter).mint(user1.address, ethers.parseEther("1000"));
    });

    it("Should allow users to burn their own tokens", async function () {
      const burnAmount = ethers.parseEther("100");
      await rwaToken.connect(user1).burn(burnAmount);
      expect(await rwaToken.balanceOf(user1.address)).to.equal(ethers.parseEther("900"));
      expect(await rwaToken.totalSupply()).to.equal(ethers.parseEther("900"));
    });

    it("Should allow minter to burn from other addresses", async function () {
      const burnAmount = ethers.parseEther("100");
      await rwaToken.connect(user1).approve(minter.address, burnAmount);
      await rwaToken.connect(minter).burnFrom(user1.address, burnAmount);
      expect(await rwaToken.balanceOf(user1.address)).to.equal(ethers.parseEther("900"));
    });
  });

  describe("Transfers", function () {
    beforeEach(async function () {
      await rwaToken.connect(minter).mint(user1.address, ethers.parseEther("1000"));
    });

    it("Should allow normal transfers when restrictions are disabled", async function () {
      const transferAmount = ethers.parseEther("100");
      await rwaToken.connect(user1).transfer(user2.address, transferAmount);
      expect(await rwaToken.balanceOf(user2.address)).to.equal(transferAmount);
    });

    it("Should prevent transfers when paused", async function () {
      await rwaToken.connect(pauser).pause();
      const transferAmount = ethers.parseEther("100");
      await expect(
        rwaToken.connect(user1).transfer(user2.address, transferAmount)
      ).to.be.revertedWithCustomError(rwaToken, "EnforcedPause");
    });

    it("Should prevent transfers when asset is inactive", async function () {
      await rwaToken.deactivateAsset();
      const transferAmount = ethers.parseEther("100");
      await expect(
        rwaToken.connect(user1).transfer(user2.address, transferAmount)
      ).to.be.revertedWith("RWAToken: asset is not active");
    });
  });

  describe("Whitelist", function () {
    beforeEach(async function () {
      await rwaToken.connect(minter).mint(user1.address, ethers.parseEther("1000"));
      await rwaToken.connect(minter).mint(user2.address, ethers.parseEther("1000"));
    });

    it("Should allow compliance officer to add to whitelist", async function () {
      await rwaToken.connect(compliance).addToWhitelist(user1.address);
      expect(await rwaToken.whitelist(user1.address)).to.be.true;
    });

    it("Should allow compliance officer to remove from whitelist", async function () {
      await rwaToken.connect(compliance).addToWhitelist(user1.address);
      await rwaToken.connect(compliance).removeFromWhitelist(user1.address);
      expect(await rwaToken.whitelist(user1.address)).to.be.false;
    });

    it("Should prevent non-compliance officer from modifying whitelist", async function () {
      await expect(
        rwaToken.connect(user1).addToWhitelist(user2.address)
      ).to.be.revertedWithCustomError(rwaToken, "AccessControlUnauthorizedAccount");
    });

    it("Should prevent transfers when whitelist is enabled and user is not whitelisted", async function () {
      await rwaToken.connect(compliance).addToWhitelist(user1.address);
      await rwaToken.connect(compliance).toggleWhitelist();
      
      // user1 is whitelisted, should work
      await rwaToken.connect(user1).transfer(user2.address, ethers.parseEther("100"));
      
      // user2 is not whitelisted, should fail
      await expect(
        rwaToken.connect(user2).transfer(user1.address, ethers.parseEther("100"))
      ).to.be.revertedWith("RWAToken: sender not whitelisted");
    });
  });

  describe("Blacklist", function () {
    beforeEach(async function () {
      await rwaToken.connect(minter).mint(user1.address, ethers.parseEther("1000"));
      await rwaToken.connect(minter).mint(user2.address, ethers.parseEther("1000"));
    });

    it("Should allow compliance officer to add to blacklist", async function () {
      await rwaToken.connect(compliance).addToBlacklist(user1.address);
      expect(await rwaToken.blacklist(user1.address)).to.be.true;
    });

    it("Should prevent transfers from blacklisted addresses", async function () {
      await rwaToken.connect(compliance).addToBlacklist(user1.address);
      await rwaToken.connect(compliance).toggleTransferRestrictions();
      
      await expect(
        rwaToken.connect(user1).transfer(user2.address, ethers.parseEther("100"))
      ).to.be.revertedWith("RWAToken: sender is blacklisted");
    });

    it("Should prevent transfers to blacklisted addresses", async function () {
      await rwaToken.connect(compliance).addToBlacklist(user2.address);
      await rwaToken.connect(compliance).toggleTransferRestrictions();
      
      await expect(
        rwaToken.connect(user1).transfer(user2.address, ethers.parseEther("100"))
      ).to.be.revertedWith("RWAToken: recipient is blacklisted");
    });
  });

  describe("Transfer Restrictions", function () {
    beforeEach(async function () {
      await rwaToken.connect(minter).mint(user1.address, ethers.parseEther("1000"));
      await rwaToken.connect(minter).mint(user2.address, ethers.parseEther("1000"));
    });

    it("Should allow toggling transfer restrictions", async function () {
      await rwaToken.connect(compliance).toggleTransferRestrictions();
      expect(await rwaToken.transferRestrictionsEnabled()).to.be.true;
      
      await rwaToken.connect(compliance).toggleTransferRestrictions();
      expect(await rwaToken.transferRestrictionsEnabled()).to.be.false;
    });

    it("Should allow transfers when restrictions are disabled", async function () {
      await rwaToken.connect(compliance).addToBlacklist(user3.address);
      await rwaToken.connect(compliance).toggleTransferRestrictions();
      
      // Should still work because restrictions are enabled but user3 is not involved
      await rwaToken.connect(user1).transfer(user2.address, ethers.parseEther("100"));
    });
  });

  describe("Pausable", function () {
    beforeEach(async function () {
      await rwaToken.connect(minter).mint(user1.address, ethers.parseEther("1000"));
    });

    it("Should allow pauser to pause", async function () {
      await rwaToken.connect(pauser).pause();
      expect(await rwaToken.paused()).to.be.true;
    });

    it("Should allow pauser to unpause", async function () {
      await rwaToken.connect(pauser).pause();
      await rwaToken.connect(pauser).unpause();
      expect(await rwaToken.paused()).to.be.false;
    });

    it("Should prevent non-pauser from pausing", async function () {
      await expect(
        rwaToken.connect(user1).pause()
      ).to.be.revertedWithCustomError(rwaToken, "AccessControlUnauthorizedAccount");
    });
  });

  describe("Asset Management", function () {
    it("Should allow admin to update valuation", async function () {
      const newValuation = ethers.parseEther("2000000");
      await rwaToken.updateValuation(newValuation);
      const assetInfo = await rwaToken.getAssetInfo();
      expect(assetInfo.valuation).to.equal(newValuation);
    });

    it("Should prevent non-admin from updating valuation", async function () {
      const newValuation = ethers.parseEther("2000000");
      await expect(
        rwaToken.connect(user1).updateValuation(newValuation)
      ).to.be.revertedWithCustomError(rwaToken, "AccessControlUnauthorizedAccount");
    });

    it("Should allow admin to update description", async function () {
      const newDescription = "Updated description";
      await rwaToken.updateDescription(newDescription);
      const assetInfo = await rwaToken.getAssetInfo();
      expect(assetInfo.description).to.equal(newDescription);
    });

    it("Should allow admin to deactivate asset", async function () {
      await rwaToken.deactivateAsset();
      const assetInfo = await rwaToken.getAssetInfo();
      expect(assetInfo.isActive).to.be.false;
    });

    it("Should allow admin to activate asset", async function () {
      await rwaToken.deactivateAsset();
      await rwaToken.activateAsset();
      const assetInfo = await rwaToken.getAssetInfo();
      expect(assetInfo.isActive).to.be.true;
    });
  });

  describe("Token Price Calculation", function () {
    it("Should return zero price when no tokens are minted", async function () {
      expect(await rwaToken.getTokenPrice()).to.equal(0);
    });

    it("Should calculate correct token price", async function () {
      const mintAmount = ethers.parseEther("1000000"); // 1M tokens
      await rwaToken.connect(minter).mint(user1.address, mintAmount);
      
      // Price = valuation / totalSupply = 1,000,000 / 1,000,000 = 1 USD per token
      const expectedPrice = ethers.parseEther("1");
      expect(await rwaToken.getTokenPrice()).to.equal(expectedPrice);
    });
  });

  describe("Can Transfer Check", function () {
    beforeEach(async function () {
      await rwaToken.connect(minter).mint(user1.address, ethers.parseEther("1000"));
    });

    it("Should return false when asset is inactive", async function () {
      await rwaToken.deactivateAsset();
      expect(await rwaToken.canTransfer(user1.address, user2.address)).to.be.false;
    });

    it("Should return false when paused", async function () {
      await rwaToken.connect(pauser).pause();
      expect(await rwaToken.canTransfer(user1.address, user2.address)).to.be.false;
    });

    it("Should return false when sender is blacklisted", async function () {
      await rwaToken.connect(compliance).addToBlacklist(user1.address);
      await rwaToken.connect(compliance).toggleTransferRestrictions();
      expect(await rwaToken.canTransfer(user1.address, user2.address)).to.be.false;
    });

    it("Should return true for normal transfers", async function () {
      expect(await rwaToken.canTransfer(user1.address, user2.address)).to.be.true;
    });
  });
});
