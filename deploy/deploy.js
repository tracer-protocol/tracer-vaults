// deploy/00_deploy_my_contract.js
module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    // config
    let pool = "0x7B6b4B7AeDcd0853052522BA2dc51346CA57dD07"
    let poolShortToken = "0x7B6b4B7AeDcd0853052522BA2dc51346CA57dD07"
    let vaultAsset = "0x7B6b4B7AeDcd0853052522BA2dc51346CA57dD07"

    // deploy vaults
    let vault = await deploy("VaultV1", {
        from: deployer,
        args: [vaultAsset],
        log: true,
    })

    // deploy permissioned strategy
    let strategy = await deploy("PermissionedStrategy", {
        from: deployer,
        args: [pool, poolShortToken, vaultAsset, vault.address],
        log: true,
    })

    // add strategy to vault
    await vault.setStrategy(strategy.address)
}
module.exports.tags = ["VaultV1", "PermissionedStrategy"]
