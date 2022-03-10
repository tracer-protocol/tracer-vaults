const { expect, assert } = require("chai")
const { network, ethers } = require("hardhat")

describe.only("VaultV1 + Strategy", async () => {
    let vault
    let vaultFactory
    let owner
    let underlying
    let baseUnit = ethers.utils.parseEther("1") //18 decimals default
    let accounts
    let strategy
    let mockShortToken
    let mockBlacklistToken

    beforeEach(async () => {
        accounts = await ethers.getSigners()
        vaultFactory = await ethers.getContractFactory("VaultV1")
        let strategyFactory = await ethers.getContractFactory(
            "PermissionedStrategy"
        )
        let ERC20Factory = await ethers.getContractFactory("TestERC20")
        underlying = await ERC20Factory.deploy("Test Token", "TST")
        mockShortToken = await ERC20Factory.deploy(
            "Mock Short Token",
            "3S-ETH/USD"
        )
        mockBlacklistToken = await ERC20Factory.deploy("NOT WHITELISTED", "NWL")
        for (var i = 0; i < 10; i++) {
            await underlying.mint(
                ethers.utils.parseEther("10"),
                accounts[i].address
            )
            await mockShortToken.mint(
                ethers.utils.parseEther("10"),
                accounts[i].address
            )
            await mockBlacklistToken.mint(
                ethers.utils.parseEther("10"),
                accounts[i].address
            )
        }

        vault = await vaultFactory.deploy(underlying.address)

        strategy = await strategyFactory.deploy(
            accounts[0].address, // mock pool as accounts 0
            mockShortToken.address,
            underlying.address,
            vault.address // mock vault as accounts 0
        )

        // whitelist account 1 to push and pull funds
        strategy.setWhitelist(accounts[1].address, true)
        //set initial strategy
        await vault.setStrategy(strategy.address)
    })

    describe("deposit", async () => {
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
            let strategyBalance = await underlying.balanceOf(strategy.address)

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
            // approve and deposit into vault
            await underlying.approve(
                vault.address,
                ethers.utils.parseEther("10")
            )
            await vault.deposit(
                ethers.utils.parseEther("10"),
                accounts[0].address
            )
        })

        it("reverts if the caller is not the vault", async () => {
            await expect(
                strategy
                    .connect(accounts[3])
                    .withdraw(ethers.utils.parseEther("2"))
            ).to.be.revertedWith("only vault can withdraw")
        })

        it("caps the amount at the current balance", async () => {
            // request withdraw first
            await strategy.requestWithdraw(ethers.utils.parseEther("15"))

            let vaultBalanceBefore = await underlying.balanceOf(
                accounts[0].address
            )

            await strategy.withdraw(ethers.utils.parseEther("15"))

            let vaultBalanceAfter = await underlying.balanceOf(
                accounts[0].address
            )

            // only withdraws 10 as that is the balance of the strategy
            expect(
                vaultBalanceAfter.sub(vaultBalanceBefore).toString()
            ).to.equal(ethers.utils.parseEther("10").toString())
        })

        it("transfers funds back to the vault", async () => {
            // request withdraw first
            await strategy.requestWithdraw(ethers.utils.parseEther("1"))

            let vaultBalanceBefore = await underlying.balanceOf(
                accounts[0].address
            )

            await strategy.withdraw(ethers.utils.parseEther("1"))

            let vaultBalanceAfter = await underlying.balanceOf(
                accounts[0].address
            )

            // only withdraws 10 as that is the balance of the strategy
            expect(
                vaultBalanceAfter.sub(vaultBalanceBefore).toString()
            ).to.equal(ethers.utils.parseEther("1").toString())
        })

        it("reduces the requested withdraw amount", async () => {
            await strategy.requestWithdraw(ethers.utils.parseEther("5"))
            let requestedWithdrawBefore =
                await strategy.totalRequestedWithdraws()

            await strategy.withdraw(ethers.utils.parseEther("2"))

            let requestedWithdrawAfter =
                await strategy.totalRequestedWithdraws()

            expect(
                requestedWithdrawBefore.sub(requestedWithdrawAfter).toString()
            ).to.equal(ethers.utils.parseEther("2").toString())
        })

        it("reverts if amount is greater than the total requested withdraw amount", async () => {
            await expect(
                strategy.withdraw(ethers.utils.parseEther("1"))
            ).to.be.revertedWith("withdrawing more than requested")
        })

        it("reverts if the request window time has not passed", async () => {
            await vault.requestWithdraw(ethers.utils.parseEther("5"))

            await expect(
                vault.withdraw(
                    ethers.utils.parseEther("2"),
                    accounts[0].address,
                    accounts[0].address
                )
            ).to.be.revertedWith("withdraw locked")
        })
    })
})
