// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract gameWithAIGC is ERC721, AccessControl {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    struct nftDetail {
        string characterName;
        uint256 age;
        uint256 property;
    }

    mapping ( uint256 => nftDetail) getDetail;

    constructor() ERC721("Game NFT", "GN") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function getNFTDetail(uint256 tokenId) public view returns (nftDetail memory) {
        return getDetail[tokenId];
    }

    function getTotalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function mint() public {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
    }


    /** 
    * @dev This is the admin function
    */
    // function checkOwner() public view returns (address) {
    //     return owner();
    // }


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