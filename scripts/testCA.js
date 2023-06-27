const { ethers, upgrades } = require("hardhat");

const main = async () => {

    const [guy, randomGuy] = await ethers.getSigners();

    const catFactory = await ethers.getContractFactory("iCat");
    const catContract = await catFactory.deploy();
    await catContract.deployed();
    console.log("Cat NFT deployed to:", catContract.address);

    const eggFactory = await ethers.getContractFactory("iCatEgg");
    const eggContract = await eggFactory.deploy(catContract.address);
    await eggContract.deployed();
    console.log('NFT contract deployed to:', eggContract.address);

    const mintEgg = await eggContract.mint();
    console.log("Mint succesful");

    const getColor = await eggContract.getColor(1);
    console.log("The color of egg #1 is", getColor);

    const grantAdmin = await eggContract.grantAdmin(randomGuy.address);
    console.log("grant successful")
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