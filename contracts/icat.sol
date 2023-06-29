// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract iCat is ERC721, AccessControl {

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant HATCH_ROLE = keccak256("HATCH_ROLE");

    // 用于记录上次签到时间
    uint256 lastCheckin;
    uint256 ornamentPrice = 10;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    enum Stage {
        TEEN,  // 幼生期
        GROWING,  // 成长期
        ADULT  // 成熟
    }

    enum Food {
        leftover,  // 剩饭
        fishChip,  // 小鱼干
        tin  // 罐头
    }

    enum Ornament {
        hat,
        scarf,
        clothes
    }

    struct catDetail {
        string characterName;
        uint256 healthy;
        uint256 intimacy;  // 亲密度
        Stage stage;  // 成长时期
        uint256 hungry;  // 饥饿度
        uint256 feces;  // 排泄物
        bool hat;
        bool scarf;
        bool clothes;
    }

    mapping ( uint256 => catDetail ) public detail;  // 查看 NFT 详情(tokenId => detail)
    mapping ( uint256 => uint256 ) public growingProgress;  // 成长进度(tokenId => Stage)
    mapping ( address => uint256 ) public credit;  // 用户的分数(userAddress => credit)

    // 使用error减少gas消耗
    error notOwner(uint256 tokenId, address _user );
    error notYet();
    error creditNotEnough();
    error notRegistered();
    error notExist();

    constructor() ERC721("iCat", "iCat") {
        growingProgress[uint256(Stage.TEEN)] = 100;  // 幼生期长到成长期需要100点
        growingProgress[uint256(Stage.GROWING)] = 1000;  // 成长期长到成熟需要1000点
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(HATCH_ROLE, msg.sender);
    }

    function getDetail(uint256 tokenId) public view returns (catDetail memory) {
        return detail[tokenId];
    }

    function getTotalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function mint() public onlyRole(HATCH_ROLE) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        // 这里使用tx.origin是因为孵蛋是由egg合约调用的
        _safeMint(tx.origin, tokenId);

        // mint完猫之后给猫初始化Detail数据
        catDetail memory defaultDetail = catDetail({
            characterName: "iCat",  // 默认名字为iCat
            healthy: 100,  // 初始健康值100
            intimacy: 0,  // 初始亲密度为0
            stage: Stage.TEEN,  // 默认为幼生期
            hungry: 0,  // 初始饥饿度为0
            feces: 0,  // 初始排泄物为0
            hat: false,
            scarf: false,
            clothes: false
        });
        detail[tokenId] = defaultDetail;
    }

    // 初始化用户积分，用于外部调用
    function initCredit(address _user, uint256 _credit) public onlyRole(HATCH_ROLE) {
        credit[_user] = _credit;
    }

    // 更改用户积分，用于孵蛋扣除积分
    function updateCredit(address _user, uint256 _credit) public onlyRole(HATCH_ROLE) {
        credit[_user] -= _credit;
    }

    // 每日签到
    function checkIn() public {
        if (block.timestamp < lastCheckin + 1 days) {
            revert notYet();
        }
        if (balanceOf(msg.sender) == 0) {
            revert notRegistered();
        }
        credit[msg.sender] += 5;
    }

    // 添加iCat昵称
    function changeNickname(uint256 tokenId, string memory newName) public onlyOwner(tokenId) {
        detail[tokenId].characterName = newName;
    }

    // 为自己的猫买装饰品
    function buyOrnament(uint256 tokenId, Ornament ornament) public onlyOwner(tokenId) {
        if (credit[msg.sender] < ornamentPrice) {
            revert creditNotEnough();
        }
        if (ornament == Ornament.hat) {
            detail[tokenId].hat = true;
        }
        else if (ornament == Ornament.scarf) {
            detail[tokenId].scarf = true;
        }
        else if (ornament == Ornament.clothes) {
            detail[tokenId].clothes = true;
        }
        else {
            revert notExist();
        }
        credit[msg.sender] -= ornamentPrice;
    }

    // 为其他人的猫买饰品
    function buyOrnamentFor(uint256 tokenId, Ornament ornament) public {
        if (credit[msg.sender] < ornamentPrice) {
            revert creditNotEnough();
        }
        if (ornament == Ornament.hat) {
            detail[tokenId].hat = true;
        }
        else if (ornament == Ornament.scarf) {
            detail[tokenId].scarf = true;
        }
        else if (ornament == Ornament.clothes) {
            detail[tokenId].clothes = true;
        }
        else {
            revert notExist();
        }
        credit[msg.sender] -= ornamentPrice;
    }

    /** 
    * @dev This is the admin function
    */
    function grantAdmin(address account) public onlyRole(ADMIN_ROLE) {
        _grantRole(ADMIN_ROLE, account);
    }

    function grantHatch(address account) public onlyRole(ADMIN_ROLE) {
        _grantRole(HATCH_ROLE, account);
    }

    function setOrnamentPrice(uint256 _price) public onlyRole(ADMIN_ROLE) {
        ornamentPrice = _price;
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

    function _checkOwner(uint256 tokenId) internal view {
        if (ownerOf(tokenId) != msg.sender) {
            revert notOwner(tokenId, msg.sender);
        }
    }

    // 对单独的NFT操作需要单独的访问控制
    modifier onlyOwner(uint256 tokenId) {
        _checkOwner(tokenId);
        _;
    }
}