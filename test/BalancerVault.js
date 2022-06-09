const { expect, assert } = require("chai")
const { network, ethers } = require("hardhat")

describe("BalancerVaultV1", async () => {
    let balancerVault
    // rbac
    const SAFETY_ROLE = ethers.utils.id("SAFETY_ADMIN")
    const CONFIG_ROLE = ethers.utils.id("CONFIG_ADMIN")

    beforeEach(async () => {
        accounts = await ethers.getSigners()
        let vaultFactory = await ethers.getContractFactory("BalancerVault")

        balancerVault = await vaultFactory.deploy(
            "0x7B50775383d3D6f0215A8F290f2C9e2eEBBEceb2", //BB-A-USD LP token (https://etherscan.io/address/0x7b50775383d3d6f0215a8f290f2c9e2eebbeceb2)
            "0x7b50775383d3d6f0215a8f290f2c9e2eebbeceb20000000000000000000000fe", //BB-A-USD pool ID (https://app.balancer.fi/#/pool/0x7b50775383d3d6f0215a8f290f2c9e2eebbeceb20000000000000000000000fe)
            accounts[0].address,
            "Balancer Vault",
            "BVT"
        )

        // setup RBAC
        // await tokeVault.grantRole(SAFETY_ROLE, accounts[1].address)
        // await tokeVault.grantRole(CONFIG_ROLE, accounts[3].address)
    })

    describe("test", async () => {
        beforeEach(async () => {
    
        })
        it("logs assets held by pool", async () => {
           await balancerVault.totalAssets()
        })
        
    })
})
