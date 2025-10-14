require("@nomicfoundation/hardhat-toolbox");
const dotenv = require("dotenv");

dotenv.config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  networks: {
    sepolia: {
      url: process.env.REACT_APP_SEPOLIA_API_URL,
      accounts: [process.env.REACT_APP_PRIVATE_KEY],
      // Add explicit gas configuration
      gasPrice: 3000000000, // 3 gwei
      gas: 2100000, 
      },
  },
  etherscan: {
    apiKey: process.env.REACT_APP_ETHERSCAN_API_KEY,
  },
};
