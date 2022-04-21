require("@nomiclabs/hardhat-waffle")
require("@nomiclabs/hardhat-solhint")
require("@nomiclabs/hardhat-etherscan")
require("hardhat-deploy")
require("@nomiclabs/hardhat-ethers")
require("solidity-coverage")
require("hardhat-gas-reporter")
require("dotenv").config()

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: "0.8.5",
    namedAccounts: {
        deployer: 0,
    },
    networks: {
        hardhat: {
            forking: {
                url: process.env.RPC_URL,
                blockNumber: 14448270,
            },
        },
        deploy: {
            url: process.env.RPC_URL,
            accounts: [process.env.PK],
        },
    },
    etherscan: {
        // Your API key for Etherscan
        // Obtain one at https://etherscan.io/
        apiKey: process.env.ETHERSCAN_API,
    },
    gasReporter: {
        currency: "AUD",
        gasPrice: 38,
    },
}
