const hre = require("hardhat");

async function main() {
    const Sphera = await hre.ethers.getContractFactory("Sphera");
    const sphera = await Sphera.deploy();
    
    await sphera.waitForDeployment();
    
    console.log("Sphera deployed to:", await sphera.getAddress());
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
