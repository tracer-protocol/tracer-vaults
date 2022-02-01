const { expect, assert } = require("chai")

describe("Vault", async () => {
    let vault
    let vaultFactory
    let owner
    let underlying
    let baseUnit = ethers.utils.parseEther("1") //18 decimals default
    let accounts
    let defaultRandomStrategy

    beforeEach(async () => {
        accounts = await ethers.getSigners()
        vaultFactory = await ethers.getContractFactory("Vault")
        let ERC20Factory = await ethers.getContractFactory("TestERC20")
        underlying = await ERC20Factory.deploy("Test Token", "TST")
        for (var i = 0; i < 10; i++) {
            await underlying.mint(
                ethers.utils.parseEther("10"),
                accounts[i].address
            )
        }
        defaultRandomStrategy = ethers.utils.getAddress(
            ethers.utils.hexlify(ethers.utils.randomBytes(20))
        )
        vault = await vaultFactory.deploy(
            underlying.address,
            baseUnit,
            [defaultRandomStrategy],
            [ethers.utils.parseEther("0.95")]
        )
    })

    describe("constructor", async () => {
        it("records correct state variables", async () => {
            let _underlying = await vault.underlying()
            let _baseUnit = await vault.BASE_UNIT()
            let _owner = await vault.owner()
            let _strategies = await vault.strategies(0)
            let _percentAllocations = await vault.percentAllocations(0)

            assert.equal(_underlying, underlying.address)
            assert.equal(_baseUnit.toString(), baseUnit.toString())
            assert.equal(_owner, accounts[0].address)
            assert.equal(_strategies, defaultRandomStrategy)
            assert.equal(
                _percentAllocations.toString(),
                ethers.utils.parseEther("0.95").toString()
            )
        })

        it("reverts if the percent allocated to strategies is > 100", async () => {
            await expect(
                (vault = vaultFactory.deploy(
                    underlying.address,
                    baseUnit,
                    [defaultRandomStrategy],
                    [ethers.utils.parseEther("1.01")]
                ))
            ).to.be.revertedWith("PERC_SUM_MAX")
        })

        it("reverts if strategies is not the same length as percentages", async () => {
            await expect(
                (vault = vaultFactory.deploy(
                    underlying.address,
                    baseUnit,
                    [defaultRandomStrategy],
                    [
                        ethers.utils.parseEther("0.5"),
                        ethers.utils.parseEther("0.5"),
                    ]
                ))
            ).to.be.revertedWith("LEN_MISMATCH")
        })

        it("reverts if there are duplicate strategies", async () => {
            await expect(
                (vault = vaultFactory.deploy(
                    underlying.address,
                    baseUnit,
                    [defaultRandomStrategy, defaultRandomStrategy],
                    [
                        ethers.utils.parseEther("0.5"),
                        ethers.utils.parseEther("0.5"),
                    ]
                ))
            ).to.be.revertedWith("DUP_STRAT")
        })
    })

    describe("deposit", async () => {
        beforeEach(async () => {
            await underlying.approve(
                vault.address,
                ethers.utils.parseEther("1")
            )
            await vault.deposit(
                accounts[0].address,
                ethers.utils.parseEther("1")
            )
        })
        it("distributes funds to the strategies", async () => {
            // 95% of funds go to strategy 0
            let strategyBalance = await underlying.balanceOf(
                defaultRandomStrategy
            )
            assert.equal(
                strategyBalance.toString(),
                ethers.utils.parseEther("0.95").toString()
            )
            // 5% stay with the vault
            let vaultBalance = await underlying.balanceOf(vault.address)
            assert.equal(
                vaultBalance.toString(),
                ethers.utils.parseEther("0.05").toString()
            )
        })

        it("issues correct vault shares", async () => {
            let vaultBalance = await vault.balanceOf(accounts[0].address)
            assert.equal(vaultBalance.toString(), ethers.utils.parseEther("1"))
        })

        it("reverts on insufficient approval", async () => {
            await expect(
                vault
                    .connect(accounts[1])
                    .deposit(accounts[1].address, ethers.utils.parseEther("1"))
            ).to.be.revertedWith("ERC20: transfer amount exceeds allowance")
        })
    })

    describe("updatePercentAllocations", async () => {
        it("reverts if the new percentages do not match the number of strategies", async () => {
            // default vault only has one strategy, cannot set two percentages
            await expect(
                vault.updatePercentAllocations([
                    ethers.utils.parseEther("0.5"),
                    ethers.utils.parseEther("0.5"),
                ])
            ).to.be.revertedWith("LEN_MISMATCH")
        })

        it("reverts if sum exceeds 100%", async () => {
            await expect(
                vault.updatePercentAllocations([
                    ethers.utils.parseEther("1.1")
                ])
            ).to.be.revertedWith("PERC_SUM_MAX")
        })

        it("reverts if the caller is not the owner", async () => {
            await expect(
                vault
                    .connect(accounts[1])
                    .updatePercentAllocations([ethers.utils.parseEther("1")])
            ).to.be.revertedWith("Ownable: caller is not the owner")
        })

        it("replaces the percent allocations in the contract", async () => {
            let oldPercentAllocations = await vault.percentAllocations(0)
            assert.equal(oldPercentAllocations.toString(), ethers.utils.parseEther("0.95"))
            await vault.updatePercentAllocations([ethers.utils.parseEther("0.5")])
            let newPercentAllocations = await vault.percentAllocations(0)
            assert.equal(newPercentAllocations.toString(), ethers.utils.parseEther("0.5"))
        })
    })
})
