require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");

module.exports = {
  solidity: "0.8.2",
  gasReporter: {
    currency: 'USD',
    gasPrice: 38
  },
  networks: {
	  hardhat: {
	    chainId: 1337
	  }
	}
};
