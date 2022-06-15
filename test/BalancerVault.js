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
            "0x4E7bBd911cf1EFa442BC1b2e9Ea01ffE785412EC", //Mainnet gauge factory (https://etherscan.io/address/0x4E7bBd911cf1EFa442BC1b2e9Ea01ffE785412EC)
            "0xba100000625a3754423978a60c9317c58a424e3D", //Mainnet Bal (https://etherscan.io/token/0xba100000625a3754423978a60c9317c58a424e3d)
            accounts[0].address,
            ["0xdAC17F958D2ee523a2206206994597C13D831ec7", "0x6B175474E89094C44Da98b954EedeAC495271d0F", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"], // assets that can be depositd into this vault (USDT, DAI, USDC)
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
