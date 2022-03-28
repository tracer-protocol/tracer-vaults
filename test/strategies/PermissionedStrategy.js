const { expect, assert } = require("chai")

describe("PermissionedStrategy", async () => {
    let strategy
    let baseUnit = ethers.utils.parseEther("1") //18 decimals default
    let accounts
    let vaultAsset
    let mockShortToken
    let mockBlacklistToken

    beforeEach(async () => {
        accounts = await ethers.getSigners()
        let strategyFactory = await ethers.getContractFactory(
            "PermissionedStrategy"
        )
        let ERC20Factory = await ethers.getContractFactory("TestERC20")
        vaultAsset = await ERC20Factory.deploy("Test Token", "TST")
        mockShortToken = await ERC20Factory.deploy(
            "Mock Short Token",
            "3S-ETH/USD"
        )
        mockBlacklistToken = await ERC20Factory.deploy("NOT WHITELISTED", "NWL")
        for (var i = 0; i < 10; i++) {
            await vaultAsset.mint(
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
        strategy = await strategyFactory.deploy(
            accounts[0].address, // mock pool as accounts 0
            mockShortToken.address,
            vaultAsset.address,
            accounts[0].address // mock vault as accounts 0
        )

        // whitelist account 1 to push and pull funds
        strategy.setWhitelist(accounts[1].address, true)
    })

    describe("constructor", async () => {
        it("sets appropriate initial whitelist", async () => {
            let poolShortTokenWhitelisted = await strategy.assetWhitelist(
                mockShortToken.address
            )
            let vaultAssetWhitelisted = await strategy.assetWhitelist(
                vaultAsset.address
            )
            expect(poolShortTokenWhitelisted).to.be.true
            expect(vaultAssetWhitelisted).to.be.true
        })

        // todo: why is the default admin role check failing
        it("sets initial permissions", async () => {
            let defaultAdminRole = ethers.constants.HashZero // default admin role is 0x00
            let whitelisterRole = ethers.utils.id("WHITELISTER_ROLE")
            let senderIsDefault = await strategy.hasRole(
                defaultAdminRole,
                accounts[0].address
            )
            let senderIsWhitelister = await strategy.hasRole(
                whitelisterRole,
                accounts[0].address
            )
            expect(senderIsDefault).to.be.true
            expect(senderIsWhitelister).to.be.true
        })
    })

    describe("value", async () => {
        it("returns the sum of the vault asset on hand plus outstanding debt", async () => {
            // send 2 vaultAsset to the strategy
            await vaultAsset.transfer(
                strategy.address,
                ethers.utils.parseEther("2")
            )

            // get an account to claim 1 vaultAsset worth of debt
            await strategy
                .connect(accounts[1])
                .pullAsset(ethers.utils.parseEther("1"), vaultAsset.address)

            let value = await strategy.value()
            expect(value).to.equal(ethers.utils.parseEther("2"))
        })
    })

    describe("withdrawable", async () => {
        it("returns the vault assets held in the contract", async () => {
            // send 2 vaultAsset to the strategy
            await vaultAsset.transfer(
                strategy.address,
                ethers.utils.parseEther("2")
            )

            // get an account to claim 1 vaultAsset worth of debt
            await strategy
                .connect(accounts[1])
                .pullAsset(ethers.utils.parseEther("1"), vaultAsset.address)

            // withdrawable should only be 1 now
            let withdrawable = await strategy.withdrawable()
            expect(withdrawable).to.equal(ethers.utils.parseEther("1"))
        })
    })

    describe("withdraw", async () => {
        beforeEach(async () => {
            vaultAsset.transfer(strategy.address, ethers.utils.parseEther("10"))
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

            let vaultBalanceBefore = await vaultAsset.balanceOf(
                accounts[0].address
            )

            await strategy.withdraw(ethers.utils.parseEther("15"))

            let vaultBalanceAfter = await vaultAsset.balanceOf(
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

            let vaultBalanceBefore = await vaultAsset.balanceOf(
                accounts[0].address
            )

            await strategy.withdraw(ethers.utils.parseEther("1"))

            let vaultBalanceAfter = await vaultAsset.balanceOf(
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
    })

    describe("pullAsset", async () => {
        beforeEach(async () => {
            await mockBlacklistToken.transfer(
                strategy.address,
                ethers.utils.parseEther("5")
            )
            await vaultAsset.transfer(
                strategy.address,
                ethers.utils.parseEther("5")
            )
        })

        it("only allows the pulling of whitelisted assets", async () => {
            await expect(
                strategy
                    .connect(accounts[1])
                    .pullAsset(
                        ethers.utils.parseEther("1"),
                        mockBlacklistToken.address
                    )
            ).to.be.revertedWith("ASSET_NOT_WL")
        })

        it("only allows whitelisted addresses to pull assets", async () => {
            await expect(
                strategy
                    .connect(accounts[3])
                    .pullAsset(ethers.utils.parseEther("1"), vaultAsset.address)
            ).to.be.revertedWith("SENDER_NOT_WL")
        })

        it("updates each pullers debt and the total debt", async () => {
            let totalDebtBefore = await strategy.totalDebt(vaultAsset.address)
            let pullerDebtBefore = await strategy.debts(
                accounts[1].address,
                vaultAsset.address
            )

            await strategy
                .connect(accounts[1])
                .pullAsset(ethers.utils.parseEther("2"), vaultAsset.address)

            let totalDebtAfter = await strategy.totalDebt(vaultAsset.address)
            let pullerDebtAfter = await strategy.debts(
                accounts[1].address,
                vaultAsset.address
            )

            expect(totalDebtAfter.sub(totalDebtBefore).toString()).to.equal(
                ethers.utils.parseEther("2").toString()
            )
            expect(pullerDebtAfter.sub(pullerDebtBefore).toString()).to.equal(
                ethers.utils.parseEther("2").toString()
            )
        })

        it("reverts if not enough assets are held", async () => {
            await expect(
                strategy
                    .connect(accounts[1])
                    .pullAsset(
                        ethers.utils.parseEther("50"),
                        vaultAsset.address
                    )
            ).to.be.revertedWith("INSUFFICIENT FUNDS")
        })

        it("reverts if the requested withdraw amount is above the amount held", async () => {
            await strategy.requestWithdraw(ethers.utils.parseEther("10"))
            await expect(
                strategy
                    .connect(accounts[1])
                    .pullAsset(ethers.utils.parseEther("5"), vaultAsset.address)
            ).to.be.revertedWith("asset needed for withdraws")
        })
    })

    describe("returnAsset", async () => {
        beforeEach(async () => {
            await vaultAsset.transfer(
                strategy.address,
                ethers.utils.parseEther("5")
            )

            await vaultAsset
                .connect(accounts[1])
                .approve(strategy.address, ethers.utils.parseEther("100"))

            // create debt for account 1
            await strategy
                .connect(accounts[1])
                .pullAsset(ethers.utils.parseEther("2"), vaultAsset.address)
        })

        it("updates returners debt and total debt", async () => {
            let totalDebtBefore = await strategy.totalDebt(vaultAsset.address)
            let pullerDebtBefore = await strategy.debts(
                accounts[1].address,
                vaultAsset.address
            )

            await strategy
                .connect(accounts[1])
                .returnAsset(ethers.utils.parseEther("1"), vaultAsset.address)

            let totalDebtAfter = await strategy.totalDebt(vaultAsset.address)
            let pullerDebtAfter = await strategy.debts(
                accounts[1].address,
                vaultAsset.address
            )

            expect(totalDebtBefore.sub(totalDebtAfter).toString()).to.equal(
                ethers.utils.parseEther("1").toString()
            )
            expect(pullerDebtBefore.sub(pullerDebtAfter).toString()).to.equal(
                ethers.utils.parseEther("1").toString()
            )
        })

        it("reverts if the returner has insufficient assets", async () => {
            await expect(
                strategy
                    .connect(accounts[1])
                    .returnAsset(
                        ethers.utils.parseEther("50"),
                        vaultAsset.address
                    )
            ).to.be.revertedWith("TRANSFER_FROM_FAILED")
        })

        it("caps debt amounts at 0", async () => {
            // return 10 tokens when the outstanding debt is only 2
            await strategy
                .connect(accounts[1])
                .returnAsset(ethers.utils.parseEther("10"), vaultAsset.address)

            let totalDebtAfter = await strategy.totalDebt(vaultAsset.address)
            let pullerDebtAfter = await strategy.debts(
                accounts[1].address,
                vaultAsset.address
            )

            expect(totalDebtAfter.toString()).to.equal(
                ethers.utils.parseEther("0").toString()
            )
            expect(pullerDebtAfter.toString()).to.equal(
                ethers.utils.parseEther("0").toString()
            )
        })
    })

    describe("setWhistlist", async () => {
        it("reverts if not called by admin", async () => {
            await expect(
                strategy
                    .connect(accounts[5])
                    .setWhitelist(accounts[1].address, true)
            ).to.be.revertedWith(
                "AccessControl: account 0x9965507d1a55bcc2695c58ba16fb37d819b0a4dc is missing role 0x8619cecd8b9e095ab43867f5b69d492180450fe862e6b50bfbfb24b75dd84c8a"
            )
        })

        it("adds an address to the whiteslist", async () => {
            await strategy.setWhitelist(accounts[5].address, true)

            let isWhitelisted = await strategy.whitelist(accounts[5].address)
            expect(isWhitelisted).to.be.true
        })
    })

    describe("setAssetWhitelist", async () => {
        it("reverts if not called by admin", async () => {
            await expect(
                strategy
                    .connect(accounts[5])
                    .setAssetWhitelist(accounts[1].address, true)
            ).to.be.revertedWith(
                "AccessControl: account 0x9965507d1a55bcc2695c58ba16fb37d819b0a4dc is missing role 0x8619cecd8b9e095ab43867f5b69d492180450fe862e6b50bfbfb24b75dd84c8a"
            )
        })

        it("adds an asset to the whitelist", async () => {
            await strategy.setAssetWhitelist(accounts[5].address, true)

            let isWhitelisted = await strategy.assetWhitelist(
                accounts[5].address
            )
            expect(isWhitelisted).to.be.true
        })
    })

    describe("requestWithdraw", async () => {
        it("increments the requested withdraw amount", async () => {
            let requestedWithdrawsBefore =
                await strategy.totalRequestedWithdraws()
            await strategy.requestWithdraw(ethers.utils.parseEther("10"))
            let requestedWithdrawAfter =
                await strategy.totalRequestedWithdraws()
            expect(requestedWithdrawsBefore.toString()).to.equal(
                ethers.utils.parseEther("0").toString()
            )
            expect(requestedWithdrawAfter.toString()).to.equal(
                ethers.utils.parseEther("10").toString()
            )
        })
    })
})
