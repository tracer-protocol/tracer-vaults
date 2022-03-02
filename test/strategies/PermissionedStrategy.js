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

    describe("withdraw", async () => {})

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
            ).to.be.revertedWith("ERC20: transfer amount exceeds balance")
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

    describe("setWhistlist", async () => {})

    describe("setAssetWhitelist", async () => {})
})
