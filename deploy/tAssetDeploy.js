module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, execute } = deployments
    const { deployer } = await getNamedAccounts()

    // config
    const mainnetTOKE = "0x2e9d63788249371f1DFC918a52f8d799F4a38C94"
    const mainnetTCR = "0x9C4A4204B79dd291D6b6571C5BE8BbcD0622F050"
    const mainnettTCR = "0x15A629f0665A3Eb97D7aE9A7ce7ABF73AeB79415"
    const mainnetSushiRouter = "0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F"
    const mainnetWETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    const mainnetTokeRewards = "0x79dD22579112d8a5F7347c5ED7E609e60da713C5"
    const DAO = "0xA84918F3280d488EB3369Cb713Ec53cE386b6cBa"
    const owner = "0x131ddFd1DC9133077C72800C60072374cF6C87Fb"

    // toke -> weth -> tcr
    const swapPath = [mainnetTOKE, mainnetWETH, mainnetTCR]

    // deploy vaults
    let vault = await deploy("TokeVault", {
        from: deployer,
        args: [
            mainnettTCR,
            mainnetTokeRewards,
            mainnetSushiRouter,
            DAO,
            mainnetTOKE,
            swapPath,
            "tTCR-Tokemak-Vault",
            "TTV",
        ],
        log: true,
    })

    // transfer ownership to hardware wallet
    await execute(
        "TokeVault",
        {
            from: deployer,
            log: true,
        },
        "transferOwnership",
        owner
    )

    // verify on etherscan
    await run("verify:verify", {
        address: vault.address,
        constructorArguments: [
            mainnettTCR,
            mainnetTokeRewards,
            mainnetSushiRouter,
            DAO,
            mainnetTOKE,
            swapPath,
            "tTCR-Tokemak-Vault",
            "TTV",
        ],
    })
}
module.exports.tags = ["tAsset-TCR-Vault"]
