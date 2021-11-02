require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-etherscan");
require('dotenv').config()

const ALCHEMY_ROPSTEN_API_KEY = process.env.ALCHEMY_ROPSTEN_API_KEY
const ROPSTEN_PRIVATE_KEY = process.env.ROPSTEN_PRIVATE_KEY
const ALCHEMY_RINKEBY_API_KEY = process.env.ALCHEMY_RINKEBY_API_KEY
const RINKEBY_PRIVATE_KEY = process.env.RINKEBY_PRIVATE_KEY
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY

module.exports = {
  solidity: "0.8.6",
  gasReporter: {
    currency: 'USD',
    gasPrice: 38
  },
  networks: {
	  hardhat: {
	    chainId: 1337
	  },
    rinkeby: {
      url: process.env.JSON_RPC_PROVIDER,
      accounts: [`0x${RINKEBY_PRIVATE_KEY}`],
    }
 }
};

