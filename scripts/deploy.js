const { ethers } = require("hardhat");

const main = async () => {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const icat = await ethers.deployContract("iCat");

  console.log("icat address:", icat.address);

  const egg = await ethers.deployContract("iCatEgg", [icat.address]);

  console.log("egg address:", egg.address);

  // 设置蛋的合约进猫的合约中
  await icat.setEggContract(egg.address);
  console.log("set successfully");
  
  // 赋予权限
  await icat.grantHatch(egg.address);
  console.log("grant successful");
}

const runMain = async () => {
  try {
    await main();
    process.exit(0);
  } catch (error) {
    console.log(error);
    process.exit(1);
  }
}

runMain();