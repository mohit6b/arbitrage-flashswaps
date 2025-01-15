import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    hardhat: {
      forking: {
        url: `http://127.0.0.1`
      },
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/YOUR_INFURA_API_KEY`,  // Replace with your Infura (or Alchemy) URL
      accounts: [`0x${process.env.PRIVATE_KEY}`],  // Private key for your mainnet wallet (use .env for security)
      gasPrice: 10000000000, // Optional: Adjust gas price if needed
      chainId: 1, // Ethereum Mainnet ID
    },
  },
};

export default config;
