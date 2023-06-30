// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface egg {
    // 方便签到的时候查看蛋的余额
    function balanceOf(address account) external view returns (uint256);
}

contract iCat is ERC721, AccessControl {

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant HATCH_ROLE = keccak256("HATCH_ROLE");

    uint256 ornamentPrice = 10;
    address eggContract;

    using Counters for Counters.Counter;
    using SafeMath for uint256;

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
        uint256 progress;  // 成长进度
        uint256 hungry;  // 饥饿度
        uint256 feces;  // 排泄物
        bool hat;
        bool scarf;
        bool clothes;
    }

    mapping ( uint256 => catDetail ) public detail;  // 查看 NFT 详情(tokenId => detail)
    mapping ( uint256 => uint256 ) public growingProgress;  // 成长进度(Stage => 点数)
    mapping ( address => uint256 ) public credit;  // 用户的分数(userAddress => credit)
    mapping ( address => mapping ( uint256 => uint256 )) public foodBalance;  // 用户食物余额(userAddress => (Food => price))
    mapping ( uint256 => uint256 ) public foodPrice;  // 食品价格(Food => price)
    mapping ( uint256 => uint256 ) public foodEnergy;  // 食品的能量(用于消除饥饿度)(Food => energy)
    mapping ( address => uint256 ) public lastCheckin;  // 记录上次签到时间
    mapping ( address => uint256 ) public lastFeed;  // 记录上次喂食时间

    // 使用error减少gas消耗
    error notOwner(uint256 tokenId, address _user );
    error notYet();
    error creditNotEnough();
    error foodNotEnough();
    error notRegistered();
    error notExist();
    error alreadyAdult(uint256 tokenId);

    // 定义事件用于检测小猫是否成熟
    event StageAfter(Stage indexed _stage);

    constructor() ERC721("iCat", "iCat") {
        growingProgress[uint256(Stage.TEEN)] = 100;  // 幼生期长到成长期需要100点
        growingProgress[uint256(Stage.GROWING)] = 1000;  // 成长期长到成熟需要1000点
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(HATCH_ROLE, msg.sender);
        _initialFoodPrice(0, 5, 10);
        _initialFoodEnergy(1, 5, 10);  // 剩饭能量1防止没积分之后游戏陷入死锁
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
            progress: 0,  // 初始成长进度为0
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
        if (block.timestamp < lastCheckin[msg.sender] + 1 days) {
            revert notYet();
        }
        // 没有猫也没有蛋才算未注册
        if (balanceOf(msg.sender) == 0 && egg(eggContract).balanceOf(msg.sender) == 0) {
            revert notRegistered();
        }
        credit[msg.sender] += 5;
        lastCheckin[msg.sender] = block.timestamp;
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

    function buyFood(Food _food, uint256 _amount) public {
        if (credit[msg.sender] < SafeMath.mul(foodPrice[uint256(_food)], _amount)) {
            revert creditNotEnough();
        }
        foodBalance[msg.sender][uint256(_food)] += _amount;
    }

    // 撸猫加积分和亲密度
    function pet(uint256 tokenId) public onlyOwner(tokenId) returns (uint256) { 
        credit[msg.sender] += 5;
        detail[tokenId].intimacy += 5;
        return credit[msg.sender];
    }

    // 给小猫喂食
    function feedCat(uint256 tokenId, Food _food, uint256 _amount) public onlyOwner(tokenId) onlyNotAdult(tokenId) returns (bool) {
        if (foodBalance[msg.sender][uint256(_food)] < _amount) {
            revert foodNotEnough();
        }
        foodBalance[msg.sender][uint256(_food)] -= _amount;
        /**
        * 更新成长进度
         */
        //  成长进度加上亲密度权重
        uint256 weightEnergy = SafeMath.mul((detail[tokenId].intimacy + 1), foodEnergy[uint256(_food)]);
        uint256 simulateProgress = SafeMath.add(detail[tokenId].progress, SafeMath.mul(_amount, weightEnergy));
        // 如果加上食物的能量之后小猫能够突破下一阶段
        if (growingProgress[uint256(detail[tokenId].stage)] <= simulateProgress) {
            // 设置新的小猫progress
            detail[tokenId].progress = SafeMath.sub(simulateProgress, growingProgress[uint256(detail[tokenId].stage)]);
            // 小猫进阶到下一阶段
            detail[tokenId].stage = Stage(uint256(detail[tokenId].stage) + 1);
        }
        // 如果不能突破
        else {
            detail[tokenId].progress = SafeMath.add(detail[tokenId].progress, SafeMath.mul(_amount, weightEnergy));
        }

        /**
        * 减少饥饿度
         */
        if (detail[tokenId].hungry < SafeMath.mul(_amount, foodEnergy[uint256(_food)])) {
            detail[tokenId].hungry = 0;
        }
        else {
            detail[tokenId].hungry = SafeMath.sub(detail[tokenId].hungry, SafeMath.mul(_amount, foodEnergy[uint256(_food)]));
        }
        // 无论如何都能增加亲密度
        detail[tokenId].intimacy += 1;

        // 返回值用于证明小猫是否成熟
        emit StageAfter(detail[tokenId].stage);
        if (detail[tokenId].stage == Stage.ADULT) {
            return true;
        }
        return false;
    }

    // 计算猫的排泄物
    function calculateFeces(uint256 tokenId) public view returns (uint256) {

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

    function setEggContract(address _eggCA) public onlyRole(ADMIN_ROLE) {
        eggContract = _eggCA;
    }

    function setFoodPrice(uint256 _leftover, uint256 _fishChip, uint256 _tin) public onlyRole(ADMIN_ROLE) {
        foodPrice[uint256(Food.leftover)] = _leftover;
        foodPrice[uint256(Food.fishChip)] = _fishChip;
        foodPrice[uint256(Food.tin)] = _tin;
    }

    function setFoodEnergy(uint256 _leftover, uint256 _fishChip, uint256 _tin) public onlyRole(ADMIN_ROLE) {
        foodEnergy[uint256(Food.leftover)] = _leftover;
        foodEnergy[uint256(Food.fishChip)] = _fishChip;
        foodEnergy[uint256(Food.tin)] = _tin;
    }

    /**
    * @dev This is internal function
    */
    function _initialFoodPrice(uint256 _leftover, uint256 _fishChip, uint256 _tin) internal onlyRole(ADMIN_ROLE) {
        setFoodPrice(_leftover, _fishChip, _tin);
    }

    function _initialFoodEnergy(uint256 _leftover, uint256 _fishChip, uint256 _tin) internal onlyRole(ADMIN_ROLE) {
        setFoodEnergy(_leftover, _fishChip, _tin);
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

    function _checkStageAdultOrNot(uint256 tokenId) internal view {
        if (detail[tokenId].stage == Stage.ADULT) {
            revert alreadyAdult(tokenId);
        }
    }

    // 对单独的NFT操作需要单独的访问控制
    modifier onlyOwner(uint256 tokenId) {
        _checkOwner(tokenId);
        _;
    }

    // 小猫成熟之后就不需要操作了
    modifier onlyNotAdult(uint256 tokenId) {
        _checkStageAdultOrNot(tokenId);
        _;
    }
}