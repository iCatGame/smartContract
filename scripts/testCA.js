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

    // // 有蛋的用户和没蛋的用户分别签到
    // await catContract.checkIn();
    // console.log("Check successfully");
    // await catContract.connect(randomGuy).checkIn();
    // console.log("Check successfully, there must be something wrong in ca")

    // 查看默认情况下猫的属性
    const defaultCat = await catContract.getDetail(0);
    console.log(defaultCat);

    // 更改猫的名字并重新查看
    await catContract.changeNickname(0, "小黑子");
    const newCat = await catContract.getDetail(0);
    console.log(newCat);
    // 其他账号也想改，测试访问控制
    await catContract.connect(randomGuy).changeNickname(0, "ikun");
    const newCat2 = await catContract.getDetail(0);
    console.log(newCat2);
    
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