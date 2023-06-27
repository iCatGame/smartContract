// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract iCat is ERC721, AccessControl {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    enum Stage {
        TEEN,  // 幼生期
        GROWING,  // 成长期
        ADULT  // 成熟
    }

    struct catDetail {
        string characterName;
        uint256 healthy;
        uint256 intimacy;  // 亲密度
        Stage stage;  // 成长时期
        uint256 hungry;  // 饥饿度
        uint256 feces;  // 排泄物
    }

    mapping ( uint256 => catDetail ) getDetail;  // 查看 NFT 详情
    mapping ( uint256 => uint256 ) growingProgress;  // 成长进度

    constructor() ERC721("iCat", "iCat") {
        growingProgress[uint256(Stage.TEEN)] = 100;  // 幼生期长到成长期需要100点
        growingProgress[uint256(Stage.GROWING)] = 1000;  // 成长期长到成熟需要1000点
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function getcatDetail(uint256 tokenId) public view returns (catDetail memory) {
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