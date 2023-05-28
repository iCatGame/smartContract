const hre = require("hardhat");

const main = async () => {
    const Upgradable = await hre.ethers.getContractFactory("TransparentUpgradeableProxy");
    const upgradable = await Upgradable.deploy(`0x1efb3f88bc88f03fd1804a5c53b7141bbef5ded8`, `0xd570ace65c43af47101fc6250fd6fc63d1c22a86`, `0x`);
    await upgradable.deployed();
    console.log('successful');

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