const hre = require("hardhat");

async function main() {
    // Address of deployed Sphera NFT contract
    const spheraNFTAddress = '0x95c2DE1BBF9f7A08d9208f13d3966042ff08FA7e'; // Replace with actual NFT contract address

    const SpheraMarket = await hre.ethers.getContractFactory("SpheraMarket");
    const spheraMarket = await SpheraMarket.deploy(spheraNFTAddress);
    
    await spheraMarket.waitForDeployment();
    
    const marketplaceAddress = await spheraMarket.getAddress();
    console.log("Sphera Marketplace deployed to:", marketplaceAddress);
    console.log("Using NFT contract:", spheraNFTAddress);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });