const { expect, assert } = require("chai")
const { network, ethers } = require("hardhat")

describe.only("VaultV1", async () => {
    let tokeVault, toke, tcr, tTCR, tokeRewards, impersonatedAccount
    const mainnetTOKE = "0x2e9d63788249371f1DFC918a52f8d799F4a38C94"
    const mainnetTCR = "0x9C4A4204B79dd291D6b6571C5BE8BbcD0622F050"
    const mainnettTCR = "0x15A629f0665A3Eb97D7aE9A7ce7ABF73AeB79415"
    const sushiRouter = "0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F"
    const mainnetWETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    let samplePayload = {
        payload: {
            wallet: "0x95e8c5a56acc8064311d79946c7be87a1e90d17f",
            cycle: 204,
            amount: "100000000000000000000",
            chainId: 1,
        },
        signature: {
            v: 27,
            r: "0x01c3102cfeea13bab0c91186c045ce56be2512b05fd9136ef7f5819bbdd11a84",
            s: "0x77784a9280e55f1636fdf605d6e62dafba0e348a4a1dabc493dbae7526dc0916",
            msg: "0x01c3102cfeea13bab0c91186c045ce56be2512b05fd9136ef7f5819bbdd11a8477784a9280e55f1636fdf605d6e62dafba0e348a4a1dabc493dbae7526dc09161b",
        },
    }

    // toke -> weth -> tcr
    const swapPath = [mainnetTOKE, mainnetWETH, mainnetTCR]

    beforeEach(async () => {
        accounts = await ethers.getSigners()
        let vaultFactory = await ethers.getContractFactory("TokeVault")
        let tokeRewardsFactory = await ethers.getContractFactory(
            "MockTokeRewards"
        )
        tcr = await ethers.getContractAt("TestERC20", mainnetTCR)
        toke = await ethers.getContractAt("TestERC20", mainnetTOKE)
        tTCR = await ethers.getContractAt("TestERC20", mainnettTCR)

        // get sample mainnet TCR
        // impersonate TCR treasury management account for testing purposes
        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: ["0x95E8C5a56ACc8064311d79946c7Be87a1e90d17f"],
        })
        impersonatedAccount = await ethers.provider.getSigner(
            "0x95E8C5a56ACc8064311d79946c7Be87a1e90d17f"
        )
        impersonatedAccount.address = impersonatedAccount._address

        // get forked mainnet eth to our accounts
        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: ["0x0000000000000000000000000000000000000000"],
        })
        let zeroAddress = await ethers.provider.getSigner(
            "0x0000000000000000000000000000000000000000"
        )
        zeroAddress.address = zeroAddress._address

        await zeroAddress.sendTransaction({
            value: ethers.utils.parseEther("100"),
            to: "0x95E8C5a56ACc8064311d79946c7Be87a1e90d17f",
        })
        for (var i = 0; i < 3; i++) {
            await zeroAddress.sendTransaction({
                value: ethers.utils.parseEther("100"),
                to: accounts[i].address,
            })
        }

        // underlying token accepted by the vault
        for (var i = 0; i < 2; i++) {
            // send 10k tTCR to accounts 1 and 2
            await tTCR
                .connect(impersonatedAccount)
                .transfer(accounts[i].address, ethers.utils.parseEther("10000"))
        }

        // deploy a mock toke rewards contract and give them some rewards
        tokeRewards = await tokeRewardsFactory.deploy(toke.address)

        tokeVault = await vaultFactory.deploy(
            tTCR.address,
            tokeRewards.address,
            sushiRouter,
            accounts[0].address,
            toke.address,
            swapPath,
            "Test tAsset Vault",
            "tAVT"
        )

        // set the sample payload to ensure that the vault recieves rewards
        samplePayload.payload.wallet = tokeVault.address
    })

    describe("claim", async () => {
        beforeEach(async () => {
            // deposit 1000 toke into the sample rewards contract
            await toke
                .connect(impersonatedAccount)
                .transfer(tokeRewards.address, ethers.utils.parseEther("100"))
        })
        it("recieves assets from tokemak", async () => {
            let tokeBalanceBefore = await toke.balanceOf(tokeVault.address)
            let callerTokeBefore = await toke.balanceOf(accounts[0].address)
            // claim from the vault
            await tokeVault.claim(
                samplePayload.payload,
                samplePayload.signature.v,
                samplePayload.signature.r,
                samplePayload.signature.s
            )

            let tokeBalanceAfter = await toke.balanceOf(tokeVault.address)
            let callerTokeAfter = await toke.balanceOf(accounts[0].address)

            // the entire payload should have been claimed and a fee paid to the msg sender
            let payloadAmount = ethers.utils.parseUnits(
                samplePayload.payload.amount,
                "wei"
            )
            let fee = ethers.utils.parseEther("1.5")
            let expectedAmount = payloadAmount.sub(fee) // 1.5 toke fee
            expect(tokeBalanceAfter.sub(tokeBalanceBefore).toString()).to.equal(
                expectedAmount.toString()
            )
            expect(callerTokeAfter.sub(callerTokeBefore).toString()).to.equal(
                fee.toString()
            )
        })
    })

    describe("compound", async () => {
        it("performs a swap from toke to TCR and deposits", async () => {
            await toke
                .connect(impersonatedAccount)
                .transfer(tokeVault.address, ethers.utils.parseEther("100"))
            let tokeBalanceBefore = await toke.balanceOf(tokeVault.address)
            let tTCRBalanaceBefore = await tTCR.balanceOf(tokeVault.address)
            let tcrBalanceBefore = await tcr.balanceOf(tokeVault.address)

            // compound will sell a max of 100 toke into TCR then put the TCR back into toke.
            await tokeVault.compound()

            let tokeBalanceAfter = await toke.balanceOf(tokeVault.address)
            let tTCRBalanaceAfter = await tTCR.balanceOf(tokeVault.address)
            let tcrBalanceAfter = await tcr.balanceOf(tokeVault.address)

            // toke before > toke after
            expect(parseInt(tokeBalanceBefore.toString())).to.be.greaterThan(
                parseInt(tokeBalanceAfter.toString())
            )
            // tTCR before < tTCR after
            expect(parseInt(tTCRBalanaceBefore.toString())).to.be.lessThan(
                parseInt(tTCRBalanaceAfter.toString())
            )
            // // tcr balance does not change before and after swap
            expect(parseInt(tcrBalanceBefore.toString())).to.be.eq(
                parseInt(tcrBalanceAfter.toString())
            )
        })

        it("limits the swap to maxSwapTokens TOKE", async () => {
            await toke
                .connect(impersonatedAccount)
                .transfer(tokeVault.address, ethers.utils.parseEther("150"))

            let tokeBalanceBefore = await toke.balanceOf(tokeVault.address)
            let maxSwapTokens = await tokeVault.maxSwapTokens()
            // compound will sell a max of 100 toke into TCR then put the TCR back into toke.
            await tokeVault.compound()

            let tokeBalanceAfter = await toke.balanceOf(tokeVault.address)

            // only 100 toke swapped
            await expect(
                tokeBalanceBefore.sub(tokeBalanceAfter).toString()
            ).to.eq(maxSwapTokens.toString())
        })

        it("reverts if being called to frequently", async () => {
            await toke
                .connect(impersonatedAccount)
                .transfer(tokeVault.address, ethers.utils.parseEther("100"))
            await tokeVault.compound()
            let canCompound = await tokeVault.canCompound()
            expect(canCompound).to.be.false

            await expect(tokeVault.compound()).to.be.revertedWith(
                "not ready to compound"
            )
        })
    })

    describe("safety functions", async () => {
        it("only the owner can withdraw tokens", async () => {
            await expect(
                tokeVault
                    .connect(accounts[3])
                    .withdrawAssets(tTCR.address, ethers.utils.parseEther("1"))
            ).to.be.revertedWith("Ownable: caller is not the owner")
        })

        it("the owner is able to withdraw any tokens", async () => {
            // deposit
            await tTCR.approve(tokeVault.address, ethers.utils.parseEther("1"))
            await tokeVault.deposit(
                ethers.utils.parseEther("1"),
                accounts[0].address
            )

            // withdraw assets back to owner bypassing system
            let ownerBaltTCR = await tTCR.balanceOf(accounts[0].address)
            await tokeVault
                .connect(accounts[0])
                .withdrawAssets(tTCR.address, ethers.utils.parseEther("1"))
            let ownerBaltTCRAfter = await tTCR.balanceOf(accounts[0].address)
            expect(ownerBaltTCRAfter.sub(ownerBaltTCR).toString()).to.equal(
                ethers.utils.parseEther("1").toString()
            )
        })
    })

    describe("setKeeperReward", async () => {
        it("reverts if not called by owner", async () => {
            await expect(
                tokeVault
                    .connect(accounts[3])
                    .setKeeperReward(ethers.utils.parseEther("1"))
            ).to.be.revertedWith("Ownable: caller is not the owner")
        })

        it("sets", async () => {
            await tokeVault
                .connect(accounts[0])
                .setKeeperReward(ethers.utils.parseEther("1"))
            let keeperRewards = await tokeVault.keeperRewardAmount()
            expect(keeperRewards.toString()).to.eq(
                ethers.utils.parseEther("1").toString()
            )
        })
    })

    describe("setMaxSwapTokens", async () => {
        it("reverts if not called by owner", async () => {
            await expect(
                tokeVault
                    .connect(accounts[3])
                    .setMaxSwapTokens(ethers.utils.parseEther("1"))
            ).to.be.revertedWith("Ownable: caller is not the owner")
        })

        it("sets", async () => {
            await tokeVault
                .connect(accounts[0])
                .setMaxSwapTokens(ethers.utils.parseEther("1"))
            let maxSwapTokens = await tokeVault.maxSwapTokens()
            expect(maxSwapTokens.toString()).to.eq(
                ethers.utils.parseEther("1").toString()
            )
        })
    })

    describe("setSwapCooldown", async () => {
        it("reverts if not called by owner", async () => {
            await expect(
                tokeVault
                    .connect(accounts[3])
                    .setSwapCooldown(ethers.utils.parseEther("1"))
            ).to.be.revertedWith("Ownable: caller is not the owner")
        })

        it("sets", async () => {
            // set swap cooldown to 2 hours
            await tokeVault.connect(accounts[0]).setSwapCooldown(2)
            let swapCooldown = await tokeVault.swapCooldown()
            expect(swapCooldown.toString()).to.eq(
                parseInt(2 * 60 * 60).toString()
            )
        })
    })

    describe("setFeeReciever", async () => {
        it("reverts if not called by owner", async () => {
            await expect(
                tokeVault
                    .connect(accounts[3])
                    .setFeeReciever(accounts[5].address)
            ).to.be.revertedWith("Ownable: caller is not the owner")
        })

        it("sets", async () => {
            await tokeVault
                .connect(accounts[0])
                .setFeeReciever(accounts[5].address)
            let feeReceiver = await tokeVault.feeReciever()
            expect(feeReceiver).to.eq(accounts[5].address)
        })
    })
})
