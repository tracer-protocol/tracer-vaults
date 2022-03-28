const { inputToConfig } = require("@ethereum-waffle/compiler")
const { expect, assert } = require("chai")
const { network, ethers } = require("hardhat")

describe.only("VaultV1", async () => {
    let tokeVault

    beforeEach(async () => {
        accounts = await ethers.getSigners()
        let vaultFactory = await ethers.getContractFactory("TokeVault")
        let ERC20Factory = await ethers.getContractFactory("TestERC20")
        let tokeRewardsFactory = await ethers.getContractFactory("MockTokeRewards");

        // underlying token accepted by the vault
        underlying = await ERC20Factory.deploy("Test tAsset", "TAT")
        for (var i = 0; i < 10; i++) {
            await underlying.mint(
                ethers.utils.parseEther("10"),
                accounts[i].address
            )
        }

        // reward token
        let sampleRewards = await ERC20Factory.deploy("Test Reward Token", "TOKE")
        for (var i = 0; i < 10; i++) {
            await sampleRewards.mint(
                ethers.utils.parseEther("10"),
                accounts[i].address
            )
        }

        // deploy a mock toke rewards contract and give them some rewards
        let tokeRewards = await tokeRewardsFactory.deploy(sampleRewards.address)
        await sampleRewards.mint(
            ethers.utils.parseEther("100"),
            tokeRewards.address
        )

        // impersonate address to get mainnet tTCR
        await network.provider.request({
          method: 'hardhat_impersonateAccount',
          params: [""],
        });
        let impersonatedAccount = await ethers.provider.getSigner(address);
        impersonatedAccount.address = impersonatedAccount._address;

        // note: This test suite will only pass in mainnet forked mode.
        let sampleRouter = "0xE592427A0AEce92De3Edee1F18E0157C05861564"

        tokeVault = await vaultFactory.deploy(
            underlying.address,
            tokeRewards.address,
            sampleRouter,
            accounts[0].address,
            sampleRewards.address,
            "Test tAsset Vault",
            "tAVT"
        )

        await mockStrategy.init(vault.address, underlying.address)
        await vault.setStrategy(mockStrategy.address)
    })

    describe("claim", async() => {
        it("recieves assets from tokemak", async() => {
            // todo: fork mainnet, test real claim at some known point in the past where
            // an account had outstanding assets
        })
    })

    describe("compound", async() => {
        // todo: fork mainnet. Get real assets. Test swap
    })
})
