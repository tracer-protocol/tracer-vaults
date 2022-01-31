const { expect } = require("chai");

describe("Vault", async () => {

    let vault;
    let owner;
    let underlying;
    let baseUnit = ethers.utils.parseEther("1") //18 decimals default

    beforeEach(async() => {
        let vaultFactory = await ethers.getContractFactory("Vault")
        let ERC20Factory = await ethers.getContractFactory("TestERC20")
        underlying = await ERC20Factory.deploy("Test Token", "TST")
        let randomAddress =  ethers.utils.getAddress(
            ethers.utils.hexlify(ethers.utils.randomBytes(20))
        )
        vault = await vaultFactory.deploy(
            underlying.address,
            baseUnit,
            [randomAddress],
            [ethers.utils.parseEther("1")]
        )
    });
    
    describe("constructor", async () => {
        it("records correct state variables", async() => {

        })

        it("reverts if the percent allocated to strategies is > 100", async() => {

        })

        it("reverts if strategies is not the same length as percentages", async() => {
            
        })
    })
})
