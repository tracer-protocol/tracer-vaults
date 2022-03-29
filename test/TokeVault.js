const { expect, assert } = require("chai")
const { network, ethers } = require("hardhat")

describe.only("VaultV1", async () => {
    let tokeVault, toke, tcr, tTCR, tokeRewards, impersonatedAccount
    const mainnetTOKE = "0x2e9d63788249371f1DFC918a52f8d799F4a38C94"
    const mainnetTCR = "0x9C4A4204B79dd291D6b6571C5BE8BbcD0622F050"
    const mainnettTCR = "0x15A629f0665A3Eb97D7aE9A7ce7ABF73AeB79415"
    const uniRouter = "0xE592427A0AEce92De3Edee1F18E0157C05861564"
    let samplePayload = {
        payload: {
            wallet: '0x95e8c5a56acc8064311d79946c7be87a1e90d17f',
            cycle: 204,
            amount: '1000000000000000000000',
            chainId: 1
        },
        signature: {
            v: 27,
            r: '0x01c3102cfeea13bab0c91186c045ce56be2512b05fd9136ef7f5819bbdd11a84',
            s: '0x77784a9280e55f1636fdf605d6e62dafba0e348a4a1dabc493dbae7526dc0916',
            msg: '0x01c3102cfeea13bab0c91186c045ce56be2512b05fd9136ef7f5819bbdd11a8477784a9280e55f1636fdf605d6e62dafba0e348a4a1dabc493dbae7526dc09161b'
        },
    }

    beforeEach(async () => {
        accounts = await ethers.getSigners()
        let vaultFactory = await ethers.getContractFactory("TokeVault")
        let tokeRewardsFactory = await ethers.getContractFactory("MockTokeRewards")
        tcr = await ethers.getContractAt("TestERC20", mainnetTCR)
        toke = await ethers.getContractAt("TestERC20", mainnetTOKE)
        tTCR = await ethers.getContractAt("TestERC20", mainnettTCR)

        // get sample mainnet TCR
        // impersonate TCR treasury management account for testing purposes
        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: ["0x95E8C5a56ACc8064311d79946c7Be87a1e90d17f"],
        })
        impersonatedAccount = await ethers.provider.getSigner("0x95E8C5a56ACc8064311d79946c7Be87a1e90d17f")
        impersonatedAccount.address = impersonatedAccount._address

        // get forked mainnet eth to our accounts
        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: ["0x0000000000000000000000000000000000000000"],
        })
        let zeroAddress = await ethers.provider.getSigner("0x0000000000000000000000000000000000000000")
        zeroAddress.address = zeroAddress._address

        await zeroAddress.sendTransaction({ value: ethers.utils.parseEther("100"), to: "0x95E8C5a56ACc8064311d79946c7Be87a1e90d17f" })
        for (var i = 0; i < 3; i++) {
            await zeroAddress.sendTransaction({ value: ethers.utils.parseEther("100"), to: accounts[i].address })
        }

        // underlying token accepted by the vault
        for (var i = 0; i < 2; i++) {
            // send 10k tTCR to accounts 1 and 2
            await tTCR.connect(impersonatedAccount).transfer(accounts[i].address, ethers.utils.parseEther("10000"))
        }

        // deploy a mock toke rewards contract and give them some rewards
        tokeRewards = await tokeRewardsFactory.deploy(toke.address)

        tokeVault = await vaultFactory.deploy(
            tTCR.address,
            tokeRewards.address,
            uniRouter,
            accounts[0].address,
            toke.address,
            "Test tAsset Vault",
            "tAVT"
        )

        // set the sample payload to ensure that the vault recieves rewards
        samplePayload.payload.wallet = tokeVault.address
    })

    describe("claim", async () => {
        beforeEach(async () => {
            // deposit 1000 toke into the sample rewards contract
            await toke.connect(impersonatedAccount).transfer(tokeRewards.address, ethers.utils.parseEther("1000"))
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
            let payloadAmount = ethers.utils.parseUnits(samplePayload.payload.amount, "wei")
            let fee = ethers.utils.parseEther("1.5")
            let expectedAmount = payloadAmount.sub(fee) // 1.5 toke fee
            expect((tokeBalanceAfter.sub(tokeBalanceBefore)).toString()).to.equal(expectedAmount.toString())
            expect((callerTokeAfter.sub(callerTokeBefore)).toString()).to.equal(fee.toString())
        })
    })

    describe("compound", async () => {
        beforeEach(async () => {
            // simulate the vault having 500 toke on hand
            await toke.connect(impersonatedAccount).transfer(tokeVault.address, ethers.utils.parseEther("500"))
        })
        it.only("performs a swap from toke to TCR and deposits", async () => {
            let tokeBalanceBefore = await toke.balanceOf(tokeVault.address)
            let tTCRBalanaceBefore = await tTCR.balanceOf(tokeVault.address)

            await tokeVault.compound()

            let tokeBalanceAfter = await toke.balanceOf(tokeVault.address)
            let tTCRBalanaceAfter = await tTCR.balanceOf(tokeVault.address)

            console.log(tokeBalanceAfter)
            console.log(tTCRBalanaceAfter)

        })

        it("limits the swap to 1000 TOKE", async () => {

        })

        it("reverts if being called to frequently", async () => {

        })

        it("reverts if the balance to swap is 0")
    })
})
