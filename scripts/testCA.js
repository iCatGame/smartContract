const { ethers, upgrades } = require("hardhat");

const main = async () => {

    const [guy, randomGuy] = await ethers.getSigners();

    // 部署cat合约
    const catFactory = await ethers.getContractFactory("iCat");
    const catContract = await catFactory.deploy();
    await catContract.deployed();
    console.log("Cat NFT deployed to:", catContract.address);

    // 部署蛋的合约
    const eggFactory = await ethers.getContractFactory("iCatEgg");
    const eggContract = await eggFactory.deploy(catContract.address);
    await eggContract.deployed();
    console.log('NFT contract deployed to:', eggContract.address);

    // 给予蛋的合约以孵化的权限
    await catContract.grantHatch(eggContract.address);
    console.log("grant successful");

    // 铸造一个蛋
    const mintEgg = await eggContract.mint();
    console.log("Mint succesful");

    // // 查看蛋的颜色
    // const getColor = await eggContract.getColor(1);
    // console.log("The color of egg #1 is", getColor);

    // 授予第二个admin以admin权限
    const grantAdmin = await eggContract.grantAdmin(randomGuy.address);
    console.log("grant successful")

    // 孵化蛋
    const hatch = await eggContract.hatchOut(0);
    console.log("Hatched out successfully");

    // 查看孵化完有多少分
    const creditAfterHatch = await catContract.credit(guy.address);
    console.log("Credit after hatching out is", creditAfterHatch);
    
}

const runMain = async () => {
    try {
        await main();
        process.exit(0);
    }
    catch (error) {
        console.log(error);
        process.exit(1);
    }
}

runMain();