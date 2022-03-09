const { expect, assert } = require("chai")
const { network } = require("hardhat")

describe('UserFlow', function () {
    let vault
    let vaultFactory
    let owner
    let underlying
    let baseUnit = ethers.utils.parseEther("1") //18 decimals default
    let accounts
    let permissionedStrategy
    let strategy
    

    beforeEach(async () => {
        accounts = await ethers.getSigners()
        vaultFactory = await ethers.getContractFactory("VaultV1")
        strategyFactory = await ethers.getContractFactory("PermissionedStrategy")
        let ERC20Factory = await ethers.getContractFactory("TestERC20")
        underlying = await ERC20Factory.deploy("Test Token", "TST")
        let shortTokenFactory = await ethers.getContractFactory("ShortToken")
        shortToken = await shortTokenFactory.deploy("Short Token", "SHRT")
        let owner = accounts[0]

        for (var i = 0; i < 10; i++) {
            await underlying.mint(
                ethers.utils.parseEther("10"),
                accounts[i].address
            )
        }
        for (var i = 0; i < 10; i++) {
            await shortToken.mint(
                ethers.utils.parseEther("10"),
                accounts[i].address
            )
        }

        vault = await vaultFactory.deploy(
            underlying.address,
            0x0000000000000000000000000000000000000000,
        )

        permissionedStrategy = await strategyFactory.deploy(0x0000000000000000000000000000000000000000, shortToken.address, underlying.address, vault.address)
        await vault.setStrategy(permissionedStrategy.address)
        // describe("set strategy", async () => {
        //     it("should set strategy", async () => {
        //         await vault.setStrategy(PermissionedStrategy.address)
        // })})
    })

    describe("constructor", async () => {
        it("records correct state variables", async () => {
            let asset = await vault.asset()
            let strategy = await vault.strategy()
            assert.equal(asset, underlying.address)
            assert.equal(strategy, PermissionedStrategy.address)
        })
    })



    describe.only("deposit", async () => {
        beforeEach(async () => {
            await underlying.approve(
                vault.address,
                ethers.utils.parseEther("1")
            )
            await vault.deposit(
                ethers.utils.parseEther("1"),
                accounts[0].address
            )
        })

        it("distributes funds to the strategies", async () => {
            // 100% of funds go to the strategy
            let strategyBalance = await underlying.balanceOf(
                permissionedStrategy.address
            )

            assert.equal(
                strategyBalance.toString(),
                ethers.utils.parseEther("1").toString()
            )

            // 0% stay with the vault
            let vaultBalance = await underlying.balanceOf(vault.address)
            assert.equal(
                vaultBalance.toString(),
                ethers.utils.parseEther("0").toString()
            )
            expect(strategyBalance == ethers.utils.parseEther("1").toString()).to.be.true
        })

        it("issues correct vault shares", async () => {
            let vaultBalance = await vault.balanceOf(accounts[0].address)
            assert.equal(vaultBalance.toString(), ethers.utils.parseEther("1"))
        })

        // todo: This should have a reversion string. Investigate why it does not
        it("reverts on insufficient approval", async () => {
            await expect(
                vault
                    .connect(accounts[1])
                    .deposit(ethers.utils.parseEther("1"), accounts[1].address)
            ).to.be.reverted
        })
    })

    

    describe("withdraw", async () => {
        beforeEach(async () => {
            await underlying.approve(
                vault.address,
                ethers.utils.parseEther("2")
            )
            await vault.deposit(
                ethers.utils.parseEther("1"),
                accounts[0].address
            )
        })
        it("request withdrawal from strategy", async () => {
            await vault.requestWithdraw(
                ethers.utils.parseEther("1")
            )
            
        })

        it("withdraws funds from the strategies after 24hrs", async () => {
            await hre.network.provider.send("hardhat_mine", ["0x3e8", "0x78"]);
            await vault.withdraw(ethers.utils.parseEther("1"), accounts[0].address)

            let vaultBalance = await underlying.balanceOf(vault.address)
            assert.equal(
                vaultBalance.toString(),
                ethers.utils.parseEther("0").toString()
            )

            let strategyBalance = await underlying.balanceOf(
                PermissionedStrategy.address
            )
            assert.equal(
                strategyBalance.toString(),
                ethers.utils.parseEther("0").toString()
            )
        })

        it("reverts on insufficient funds", async () => {
            await expect(
                vault.withdraw(ethers.utils.parseEther("2"))
            ).to.be.reverted
        })
    }



)});