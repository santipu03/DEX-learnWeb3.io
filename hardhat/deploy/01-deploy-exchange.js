const { network, ethers } = require("hardhat")
const { verify } = require("../utils/verify")
const { CRYPTO_DEV_TOKEN_CONTRACT_ADDRESS } = require("../constants")

const developmentChains = ["hardhat", "localhost"]

module.exports = async ({ deployments, getNamedAccounts }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()

    const args = [CRYPTO_DEV_TOKEN_CONTRACT_ADDRESS]

    const exchangeContract = await deploy("Exchange", {
        from: deployer,
        log: true,
        args: args,
    })

    log("----------------------")

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        await verify(exchangeContract.address, args)
    }
}
