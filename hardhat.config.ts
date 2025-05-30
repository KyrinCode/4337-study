import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "@typechain/hardhat";
import dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-contract-sizer";
import "hardhat-abi-exporter";
import "solidity-docgen";
import "@solarity/hardhat-gobind";

dotenv.config();

const accounts = process.env.PRIVATE_KEY
  ? [process.env.PRIVATE_KEY]
  : [];

const config: HardhatUserConfig = {
  gasReporter: {
    enabled: process.env.ENABLE_GAS_REPORT === "true" || false,
    excludeContracts: ["contracts/test"],
  },

  // abiExporter: {
  //   path: "./abi",
  //   clear: true,
  //   flat: true,
  // },

  contractSizer: {
    alphaSort: false,
    runOnCompile: false,
    disambiguatePaths: false,
  },

  solidity: {
    compilers: [
      {
        version: "0.8.25",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          // evmVersion: "cancun",
          viaIR: true,
        },
      },
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          viaIR: true,
        },
      },
      {
        version: "0.8.13",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          viaIR: true,
        },
      },
      {
        version: "0.5.1",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          viaIR: true,
        },
      },
    ],
  },
  typechain: {
    outDir: "typechain",
  },
  networks: {
    sepolia: {
      url: "https://1rpc.io/sepolia",
      accounts,
    },
    xlayer: {
      url: "https://rpc.xlayer.tech",
      accounts,
    },
    local: {
      url: process.env.LOCAL_RPC_URL || "http://localhost:8545",
      accounts,
      gasPrice: process.env.GAS_PRICE ? parseInt(process.env.GAS_PRICE) : undefined,
    },

    hardhat: {
      enableRip7212: true,
      forking: {
        enabled: process.env.NODE_ENV == "dev" ? true : false,
        // blockNumber: 54000000,
        // url: "https://rpc.ankr.com/eth", //ETH
        // url: "https://1rpc.io/avax/c", //AVAX
        // url: "https://1rpc.io/linea" //Linea
        url: "https://mainnet.optimism.io", //OP
        // url: "https://arb1.arbitrum.io/rpc", //ARB
        // url: "https://1rpc.io/matic", //Polygon
        // url: "https://bsc-dataseed4.binance.org", //BNB
        // url: `https://polygon-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
        // url: "https://rpc.xlayer.tech",
        // url: "https://rpc.xlayer.tech",
        // url: "https://mainnet.optimism.io",
        // url: "https://nova.arbitrum.io/rpc",
      },
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: ""
  },
  sourcify: {
    // Disabled by default
    // Doesn't need an API key
    enabled: true
  },
  gobind: {
    deployable: true,
  }
};

export default config;
