const Evault = require("../artifacts/contracts/EVault.sol/EVault.json");
const erc20Abi = require("../artifacts/contracts/utils/TestERC20.sol/TestERC20.json");
const {ethers} = require("ethers");
//used this contract to interact with vault on testnet 


const main = async () => { 
    const provider = "alchemy";
    const Provider = ethers.getDefaultProvider(provider);
    const signer = new ethers.Wallet("key", Provider);
    const contractInstance = new ethers.Contract("0x52b4C7aBe657D3ECE1a0a3287E2d0a7E766b8E2b", Evault.abi, signer);
    // const erc20ContractInstance = new ethers.Contract("0x3ebDcefA6a4721a61c7BB6047fe9ca0214985798", erc20Abi.abi, signer);
    // erc20ContractInstance.connect(signer);
    // await erc20ContractInstance.approve(contractInstance.address, ethers.utils.parseEther("10000000000"));
    await contractInstance.deposit(ethers.utils.parseEther("1000"), signer.address);
    // await contractInstance.setStrategy("0xDC539c8F693da965C5AaAFEf36E4eA233BF2E567");
    
    // contractInstance.connect(signer);

    // contractInstance.deposit()

    // 0x52b4C7aBe657D3ECE1a0a3287E2d0a7E766b8E2b




    // let VaultContract = await hre.ethers.getContractFactory("EVault").deploy("0x3ebDcefA6a4721a61c7BB6047fe9ca0214985798");
    // const evault = await VaultContract.deployed();
    // let txn = await evault.deposit(hre.ethers.utils.parseEther("0.1"));

    // await txn.wait();
    // console.log(txn.hash); 

    // const EVault = "0xee3124dabdd6bfb2806b764012b3396dcb24e08c";
    // const TUSD = "0x3ebDcefA6a4721a61c7BB6047fe9ca0214985798";
    // await EVault.deposit(TUSD, 100);
}
const runMain = async () => {
    try {
      await main();
      process.exit(0);
    } catch (error) {
      console.log(error);
      process.exit(1);
    }
  };
  runMain();