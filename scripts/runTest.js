const hre = require("hardhat");

const main = async () => {

    const nftFactory = await hre.ethers.getContractFactory("gameWithAIGC");
    const nftContract = await nftFactory.deploy();
    await nftContract.deployed();
    console.log('NFT contract deployed to:', nftContract.address);

    const upgradableFactory = await hre.ethers.getContractFactory("TransparentUpgradeableProxy");
    const upgradableContract = await upgradableFactory.deploy(nftContract.address, `0xd570ace65c43af47101fc6250fd6fc63d1c22a86`, `0x`);
    await upgradableContract.deployed();
    console.log('Upgradable contract deployed to:', upgradableContract.address);

    const mint = await upgradableContract.mint();
    await mint.wait();

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