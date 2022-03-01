const main = async () => {
    const EvaultContract = await hre.ethers.getContractFactory("EVault")
    const evault = await EvaultContract.deploy(
        "0x3ebDcefA6a4721a61c7BB6047fe9ca0214985798"
    )
    await evault.deployed()
}
const runMain = async () => {
    try {
        await main()
        process.exit(0)
    } catch (error) {
        console.log(error)
        process.exit(1)
    }
}
runMain()
