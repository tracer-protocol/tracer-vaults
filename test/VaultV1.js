const { expect, assert } = require("chai")
const { network } = require("hardhat")

describe("VaultV1", async () => {
    let vault
    let vaultFactory
    let owner
    let underlying
    let baseUnit = ethers.utils.parseEther("1") //18 decimals default
    let accounts
    let mockStrategy

    beforeEach(async () => {
        accounts = await ethers.getSigners()
        vaultFactory = await ethers.getContractFactory("VaultV1")
        let strategyFactory = await ethers.getContractFactory("MockStrategy")
        let ERC20Factory = await ethers.getContractFactory("TestERC20")
        underlying = await ERC20Factory.deploy("Test Token", "TST")
        for (var i = 0; i < 10; i++) {
            await underlying.mint(
                ethers.utils.parseEther("10"),
                accounts[i].address
            )
        }

        mockStrategy = await strategyFactory.deploy()
        vault = await vaultFactory.deploy(
            underlying.address,
            mockStrategy.address
        )

        await mockStrategy.init(vault.address, underlying.address)
    })

    describe("constructor", async () => {
        it("records correct state variables", async () => {
            // todo check all state variables are saved on constructor
            let asset = await vault.asset()
            assert.equal(asset, underlying.address)
        })
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
            // 100% of funds go to strategy 0
            let strategyBalance = await underlying.balanceOf(
                mockStrategy.address
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
        })

        it("issues correct vault shares", async () => {
            let vaultBalance = await vault.balanceOf(accounts[0].address)
            assert.equal(vaultBalance.toString(), ethers.utils.parseEther("1"))
        })

        // todo: Get proper reversion strings
        it("reverts on insufficient approval", async () => {
            await expect(
                vault
                    .connect(accounts[1])
                    .deposit(ethers.utils.parseEther("1"), accounts[1].address)
            ).to.be.reverted
        })
    })

    describe("mint", async () => {
        beforeEach(async () => {
            await underlying.approve(
                vault.address,
                ethers.utils.parseEther("1")
            )
            await vault.mint(ethers.utils.parseEther("1"), accounts[0].address)
            await mockStrategy.setValue(ethers.utils.parseEther("1"))
        })

        it("distributes funds to the strategies", async () => {
            // 100% of funds go to strategy 0
            let strategyBalance = await underlying.balanceOf(
                mockStrategy.address
            )
            assert.equal(
                strategyBalance.toString(),
                ethers.utils.parseEther("1").toString()
            )
            // 5% stay with the vault
            let vaultBalance = await underlying.balanceOf(vault.address)
            assert.equal(
                vaultBalance.toString(),
                ethers.utils.parseEther("0").toString()
            )
        })

        it("issues correct vault shares", async () => {
            // alter the exchange rate. 1 share = 2 units of collateral
            await mockStrategy.setValue(ethers.utils.parseEther("2"))

            // vault state: 2 units of underlying and 1 outstanding share

            // approve from account 1
            await underlying
                .connect(accounts[1])
                .approve(vault.address, ethers.utils.parseEther("2"))

            // mint 1 share, this takes 2 units of collateral at the current ratio
            let underlyingBalanceBefore = await underlying.balanceOf(
                accounts[1].address
            )

            // mint should mint 1 share for 2 units of collateral
            await vault
                .connect(accounts[1])
                .mint(ethers.utils.parseEther("1"), accounts[1].address)

            let underlyingBalanceAfter = await underlying.balanceOf(
                accounts[1].address
            )

            // should issue 1 shares to account 1
            // should cost account 2 units of collateral
            let vaultBalance = await vault.balanceOf(accounts[1].address)
            assert.equal(
                vaultBalance.toString(),
                ethers.utils.parseEther("1").toString()
            )
            assert.equal(
                underlyingBalanceBefore.sub(underlyingBalanceAfter).toString(),
                ethers.utils.parseEther("2").toString()
            )
        })

        it("reverts on insufficient approval", async () => {
            await expect(
                vault
                    .connect(accounts[5])
                    .mint(ethers.utils.parseEther("1"), accounts[1].address)
            ).to.be.revertedWith("ERC20: transfer amount exceeds allowance")
        })
    })

    describe("withdraw", async () => {
        beforeEach(async () => {
            await underlying.approve(
                vault.address,
                ethers.utils.parseEther("1")
            )
            await vault.deposit(
                ethers.utils.parseEther("1"),
                accounts[0].address
            )

            // mocking: the current setup indicates 0.95 of funds are allocated to the mock
            // strategy. We need to tell the mock strategy to return this as its value for
            // tests to work. 0.95 * 1 ETH = 0.95 ETH in the mock strategy
            await mockStrategy.setValue(ethers.utils.parseEther("1"))
        })

        it("reverts if the user does not have enough shares", async () => {
            await expect(
                vault.withdraw(
                    ethers.utils.parseEther("2"),
                    accounts[0].address,
                    accounts[0].address
                )
            ).to.be.reverted
        })
    })

    describe("redeem", async () => {
        beforeEach(async () => {
            await underlying.approve(
                vault.address,
                ethers.utils.parseEther("1")
            )
            await vault.deposit(
                ethers.utils.parseEther("1"),
                accounts[0].address
            )

            // mocking: the current setup indicates 0.95 of funds are allocated to the mock
            // strategy. We need to tell the mock strategy to return this as its value for
            // tests to work. 0.95 * 1 ETH = 0.95 ETH in the mock strategy
            await mockStrategy.setValue(ethers.utils.parseEther("1"))
        })

        it("reverts if the user has insufficient shares", async () => {
            await expect(
                vault.redeem(
                    ethers.utils.parseEther("2"),
                    accounts[0].address,
                    accounts[0].address
                )
            ).to.be.reverted
        })

        it("withdraws the correct amount of underlying given the users shares", async () => {
            // note this test functions identically to withdraw since the ratio of shares: assets is 1:1
            let startBalance = await underlying.balanceOf(accounts[0].address)

            await vault.requestWithdraw(ethers.utils.parseEther("1"))

            // fast forward time 25 hours
            await ethers.provider.send("evm_increaseTime", [25 * 60 * 60])
            await ethers.provider.send("evm_mine")

            // withdraw all funds in the vault
            await vault.redeem(
                ethers.utils.parseEther("0.05"),
                accounts[0].address,
                accounts[0].address
            )
            let endBalance = await underlying.balanceOf(accounts[0].address)
            assert.equal(
                endBalance.sub(startBalance).toString(),
                ethers.utils.parseEther("0.05").toString()
            )
        })
    })

    describe("request withdraw", async () => {
        beforeEach(async () => {
            await underlying.approve(
                vault.address,
                ethers.utils.parseEther("1")
            )
            await vault.deposit(
                ethers.utils.parseEther("1"),
                accounts[0].address
            )

            // set the deposit to the mock strategy
            await mockStrategy.setValue(ethers.utils.parseEther("1"))
        })

        it("reverts if the user does not have enough shares to withdraw", async () => {
            // attempt to request to withdraw 2 shares when they only have 1
            await expect(
                vault.requestWithdraw(ethers.utils.parseEther("2"))
            ).to.be.revertedWith("insufficient shares")
        })

        it("reverts if the user withdraws multiple times within the withdraw period", async () => {
            await vault.requestWithdraw(ethers.utils.parseEther("0.5"))
            await expect(
                vault.requestWithdraw(ethers.utils.parseEther("2"))
            ).to.be.revertedWith("Already requested withdraw")
        })

        it("sets the users withdraw amount and withdraw time", async () => {
            const blockNumBefore = await ethers.provider.getBlockNumber()
            const blockBefore = await ethers.provider.getBlock(blockNumBefore)
            const timestampBefore = blockBefore.timestamp

            await vault.requestWithdraw(ethers.utils.parseEther("0.5"))
            let requestedWithdraw = await vault.requestedWithdraws(
                accounts[0].address
            )
            let unlockTime = await vault.unlockTime(accounts[0].address)

            expect(requestedWithdraw.toString()).to.be.equal(
                ethers.utils.parseEther("0.5")
            )
            // unlock time is > 23.9 hours from now
            expect(parseInt(unlockTime.toString())).to.be.greaterThan(
                parseInt(timestampBefore.toString()) + 86040
            )
            // unlock time is ~ < 24 hours from now
            expect(parseInt(unlockTime.toString())).to.be.lessThan(
                parseInt(timestampBefore.toString()) + 86500
            )
        })

        it("updates the total withdraw amount", async () => {
            // deposit from a second account
            await underlying
                .connect(accounts[1])
                .approve(vault.address, ethers.utils.parseEther("1"))
            await vault
                .connect(accounts[1])
                .deposit(ethers.utils.parseEther("1"), accounts[1].address)

            // mock strategy should have a value of 2 as there is a 1 ETH deposit in the beforeEach
            // and a 1 ETH deposit above
            await mockStrategy.setValue(ethers.utils.parseEther("2"))

            await vault.requestWithdraw(ethers.utils.parseEther("0.5"))
            await vault
                .connect(accounts[1])
                .requestWithdraw(ethers.utils.parseEther("0.2"))
            let totalWithdrawAmount = await vault.totalRequestedWithdraws()
            expect(totalWithdrawAmount).to.be.equal(
                ethers.utils.parseEther("0.7")
            )
        })
    })
})
