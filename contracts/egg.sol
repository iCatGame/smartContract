// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./icat.sol";

contract iCatEgg is ERC721, AccessControl {
    iCat public icat;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    enum Color {
        WHITE,
        GREEN,
        BLUE,
        PURPLE,
        RED
    }

    mapping ( uint256 => Color ) colorOfEgg;

    // 使用error处理错误更加省gas
    error notOwner(uint256 tokenId, address account);

    constructor(address iCatAddress) ERC721("iCat Egg", "EGG") {
        icat = iCat(iCatAddress);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function getColor(uint256 tokenId) public view returns (Color) {
        return colorOfEgg[tokenId];
    }

    function getTotalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://";
    }

    // 铸造蛋
    function mint() public {
        // 随机赋予蛋颜色
        uint256 randomNumber = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender))
        );
        uint256 enumLength = uint256(Color.RED) + 1;
        uint256 selectedIndex = randomNumber % enumLength;
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        colorOfEgg[tokenId] = Color(selectedIndex);

        // 铸造蛋NFT
        _safeMint(msg.sender, tokenId);  

        // 初始积分100
        icat.initCredit(msg.sender, 100);
    }

    // 孵化蛋
    function hatchOut(uint256 tokenId) public {
        // 只有蛋的拥有者才能孵化
        if (ownerOf(tokenId) != msg.sender) {
            revert notOwner(tokenId, msg.sender);
        }
        // 孵化扣除积分10
        icat.updateCredit(msg.sender, 10);

        // 燃烧掉蛋，铸造iCat
        _burn(tokenId);
        icat.mint();
    }


    /** 
    * @dev This is the admin function
    */
    function grantAdmin(address account) public onlyRole(ADMIN_ROLE) {
        _grantRole(ADMIN_ROLE, account);
    }


    /**
    * @dev The following functions are overrides required by Solidity.
    */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}