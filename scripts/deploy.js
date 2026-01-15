const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await hre.ethers.provider.getBalance(deployer.address)).toString());

  // Configuration - Update these values for your deployment
  const tokenName = process.env.TOKEN_NAME || "Real Estate Token";
  const tokenSymbol = process.env.TOKEN_SYMBOL || "RET";
  const assetType = process.env.ASSET_TYPE || "Real Estate";
  const assetId = process.env.ASSET_ID || "RE-001";
  const description = process.env.DESCRIPTION || "Commercial property in downtown";
  const valuation = process.env.VALUATION 
    ? hre.ethers.parseEther(process.env.VALUATION) 
    : hre.ethers.parseEther("1000000"); // $1,000,000 default

  console.log("\nDeployment Configuration:");
  console.log("Token Name:", tokenName);
  console.log("Token Symbol:", tokenSymbol);
  console.log("Asset Type:", assetType);
  console.log("Asset ID:", assetId);
  console.log("Description:", description);
  console.log("Valuation:", hre.ethers.formatEther(valuation), "USD");

  // Deploy the contract
  const RWAToken = await hre.ethers.getContractFactory("RWAToken");
  const rwaToken = await RWAToken.deploy(
    tokenName,
    tokenSymbol,
    deployer.address,
    assetType,
    assetId,
    description,
    valuation
  );

  await rwaToken.waitForDeployment();
  const contractAddress = await rwaToken.getAddress();

  console.log("\n✅ RWAToken deployed to:", contractAddress);

  // Wait for a few block confirmations before verification
  console.log("\nWaiting for block confirmations...");
  await rwaToken.deploymentTransaction().wait(5);

  // Verify contract on Etherscan (if on a supported network)
  if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    try {
      console.log("\nVerifying contract on Etherscan...");
      await hre.run("verify:verify", {
        address: contractAddress,
        constructorArguments: [
          tokenName,
          tokenSymbol,
          deployer.address,
          assetType,
          assetId,
          description,
          valuation,
        ],
      });
      console.log("✅ Contract verified on Etherscan");
    } catch (error) {
      if (error.message.toLowerCase().includes("already verified")) {
        console.log("✅ Contract already verified");
      } else {
        console.log("⚠️  Verification failed:", error.message);
      }
    }
  }

  // Display contract information
  console.log("\n📋 Contract Information:");
  console.log("Network:", hre.network.name);
  console.log("Contract Address:", contractAddress);
  console.log("Deployer:", deployer.address);
  
  const assetInfo = await rwaToken.getAssetInfo();
  console.log("\nAsset Information:");
  console.log("  Type:", assetInfo.assetType);
  console.log("  ID:", assetInfo.assetId);
  console.log("  Description:", assetInfo.description);
  console.log("  Valuation:", hre.ethers.formatEther(assetInfo.valuation), "USD");
  console.log("  Tokenization Date:", new Date(Number(assetInfo.tokenizationDate) * 1000).toISOString());
  console.log("  Active:", assetInfo.isActive);

  console.log("\n🎉 Deployment completed successfully!");
  console.log("\nNext steps:");
  console.log("1. Grant roles to appropriate addresses using grantRole()");
  console.log("2. Mint initial tokens using mint()");
  console.log("3. Configure compliance settings (whitelist, blacklist)");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
