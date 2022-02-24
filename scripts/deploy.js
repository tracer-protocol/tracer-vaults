const main = async () => { 
    const EvaultContract = await hre.ethers.getContractFactory("EVault");
    const evault = await EvaultContract.deploy("0xDB746f27362bC496bBb440D92d804eb74e91e0a2");
    await evault.deployed();
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