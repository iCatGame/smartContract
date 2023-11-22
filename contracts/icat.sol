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

    uint256 public ornamentPrice = 10;
    address public eggContract;
    uint256 public priceOfMedicine = 30;

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
    mapping ( address => uint256[] ) public ownedTokenId;  // 查看拥有的所有tokenId
    mapping ( uint256 => uint256 ) public growingProgress;  // 成长进度(Stage => 点数)
    mapping ( address => uint256 ) public credit;  // 用户的分数(userAddress => credit)
    mapping ( address => mapping ( uint256 => uint256 )) public foodBalance;  // 用户食物余额(userAddress => (Food => balance))
    mapping ( address => mapping ( uint256 => uint256 )) public ornamentBalance;  // 用户饰品余额(userAddress => (Ornament => balance))
    mapping ( address => uint256 ) public medicine;  // 药物余额
    mapping ( uint256 => uint256 ) public foodPrice;  // 食品价格(Food => price)
    mapping ( uint256 => uint256 ) public foodEnergy;  // 食品的能量(用于消除饥饿度)(Food => energy)
    mapping ( address => uint256 ) public lastCheckin;  // 记录上次签到时间(userAddress => lastCheckinTimestamp)
    mapping ( uint256 => uint256 ) public lastFeed;  // 记录上次喂食时间(tokenId => lastFeedTimestamp)
    mapping ( uint256 => uint256 ) public lastClear;  // 记录上次清理排泄物时间(tokenId => lastClearTimestamp)

    // 使用error减少gas消耗
    error notOwner(uint256 tokenId, address _user );
    error notYet();
    error creditNotEnough();
    error foodNotEnough();
    error medicineNotEnough();
    error notRegistered();
    error notExist();
    error alreadyAdult(uint256 tokenId);
    error alreadyDead(uint256 tokenId);
    error notDead(uint256 tokenId);

    // 定义事件用于检测小猫是否成熟
    event StageAfter(Stage indexed _stage);
    event BuryCat(uint256 indexed tokenId);
    event DataUpdated(uint256 tokenId, uint256 indexed healthy, uint256 indexed hungry, uint256 indexed feces, uint256 intimacy);

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

    function getOwnedTokenId(address owner) public view returns (uint256[] memory, uint256) {
        return (ownedTokenId[owner], ownedTokenId[owner].length);
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function mint() public onlyRole(HATCH_ROLE) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        // 这里使用tx.origin是因为孵蛋是由egg合约调用的
        _safeMint(tx.origin, tokenId);
        ownedTokenId[tx.origin].push(tokenId);

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
        lastFeed[tokenId] = block.timestamp;
        lastClear[tokenId] = block.timestamp;
    }

    // 初始化用户积分，用于外部调用
    function initCredit(address _user, uint256 _credit) public onlyRole(HATCH_ROLE) {
        if (balanceOf(_user) == 0) {
            credit[_user] = _credit;
        }
    }

    // 更改用户积分，用于孵蛋扣除积分
    function updateCredit(address _user, uint256 _credit) public onlyRole(HATCH_ROLE) {
        credit[_user] -= _credit;
    }

    function canCheckIn(address _user) public view returns (bool) {
        // 没有猫也没有蛋才算未注册
        if (balanceOf(_user) == 0 && egg(eggContract).balanceOf(_user) == 0) {
            return false;
        }
        else if (lastCheckin[_user] == 0) {
            return true;
        }
        else if (block.timestamp < lastCheckin[_user] + 1 days) {
            return false;
        }
        return true;
    }

    // 每日签到
    function checkIn() public {
        if (!canCheckIn(msg.sender)) {
            revert notYet();
        }
        credit[msg.sender] += 5;
        lastCheckin[msg.sender] = block.timestamp;
    }

    // 添加iCat昵称
    function changeNickname(uint256 tokenId, string memory newName) public onlyOwner(tokenId) {
        detail[tokenId].characterName = newName;
    }

    // 购买装饰品
    function buyOrnament(Ornament _ornament, uint256 _amount) public {
        if (credit[msg.sender] < SafeMath.mul(ornamentPrice, _amount)) {
            revert creditNotEnough();
        }
        ornamentBalance[msg.sender][uint256(_ornament)] += _amount;
        credit[msg.sender] -= SafeMath.mul(ornamentPrice, _amount);
    }

    // 添加装饰品
    function addOrnament(uint256 tokenId, Ornament ornament) public onlyOwner(tokenId) onlyNotDead(tokenId) {
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
        ornamentBalance[msg.sender][uint256(ornament)] -= 1;

        // 悄悄加上上链函数
        examCat(tokenId);
    }

    // 取下饰品
    function removeOrnament(uint256 tokenId, Ornament ornament) public onlyOwner(tokenId) onlyNotDead(tokenId) {
        if (credit[msg.sender] < ornamentPrice) {
            revert creditNotEnough();
        }
        if (ornament == Ornament.hat) {
            detail[tokenId].hat = false;
        }
        else if (ornament == Ornament.scarf) {
            detail[tokenId].scarf = false;
        }
        else if (ornament == Ornament.clothes) {
            detail[tokenId].clothes = false;
        }
        else {
            revert notExist();
        }
        ornamentBalance[msg.sender][uint256(ornament)] += 1;

        // 悄悄加上上链函数
        examCat(tokenId);
    }

    function buyFood(Food _food, uint256 _amount) public {
        if (credit[msg.sender] < SafeMath.mul(foodPrice[uint256(_food)], _amount)) {
            revert creditNotEnough();
        }
        foodBalance[msg.sender][uint256(_food)] += _amount;
    }

    // 撸猫加积分和亲密度
    function pet(uint256 tokenId) public onlyOwner(tokenId) onlyNotDead(tokenId) returns (uint256) { 
        credit[msg.sender] += 5;
        detail[tokenId].intimacy += 5;
        return credit[msg.sender];
    }

    // 给小猫喂食
    function feedCat(uint256 tokenId, Food _food, uint256 _amount) public onlyOwner(tokenId) onlyNotAdult(tokenId) onlyNotDead(tokenId) returns (bool) {
        if (foodBalance[msg.sender][uint256(_food)] < _amount) {
            revert foodNotEnough();
        }
        foodBalance[msg.sender][uint256(_food)] -= _amount;
        /**
        * 更新成长进度
         */
        //  成长进度加上亲密度权重
        uint256 weightEnergy = SafeMath.mul((calculateIntimacy(tokenId) + 1), foodEnergy[uint256(_food)]);
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
        if (calculateHunger(tokenId) < SafeMath.mul(_amount, foodEnergy[uint256(_food)])) {
            detail[tokenId].hungry = 0;
        }
        else {
            detail[tokenId].hungry = SafeMath.sub(calculateHunger(tokenId), SafeMath.mul(_amount, foodEnergy[uint256(_food)]));
        }
        // 无论如何都能增加亲密度
        detail[tokenId].intimacy = calculateIntimacy(tokenId) + 1;

        lastFeed[tokenId] = block.timestamp;

        // 返回值用于证明小猫是否成熟
        emit StageAfter(detail[tokenId].stage);
        if (detail[tokenId].stage == Stage.ADULT) {
            return true;
        }
        return false;
    }

    // 清理排泄物
    function clearFeces(uint256 tokenId) public onlyOwner(tokenId) onlyNotDead(tokenId) {
        // 排泄物清除
        detail[tokenId].feces = 0;
        // 好感度+1
        detail[tokenId].intimacy += 1;
        lastClear[tokenId] = block.timestamp;
    }

    // 计算猫的排泄物
    function calculateFeces(uint256 tokenId) public view returns (uint256) {
        return (block.timestamp - lastClear[tokenId]) / 3600;
    }

    // 计算饥饿度
    function calculateHunger(uint256 tokenId) public view returns (uint256) {
        uint256 startTime;
        if (detail[tokenId].hungry == 0) {
            startTime = SafeMath.add(lastFeed[tokenId], 8 hours);
        }
        else {
            startTime = lastFeed[tokenId];
        }
        if (startTime > block.timestamp) {
            return detail[tokenId].hungry;
        }
        return SafeMath.sub(block.timestamp, startTime) / 3600 + detail[tokenId].hungry;
    }

    // 计算实时健康度
    function calculateHealth(uint256 tokenId) public view returns (uint256) {
        uint256 fecesDamage;
        uint256 hungryDamage;
        if (calculateFeces(tokenId) < 10) {
            fecesDamage = 0;
        }
        else {
            fecesDamage = calculateFeces(tokenId) - 10;
        }
        if (calculateHunger(tokenId) < 10) {
            hungryDamage = 0;
        }
        else {
            hungryDamage = calculateHunger(tokenId) - 10;
        }
        if (detail[tokenId].healthy < fecesDamage + hungryDamage) {
            return 0;
        }
        return SafeMath.sub(detail[tokenId].healthy, SafeMath.add(fecesDamage, hungryDamage));
    }

    // 计算上述因素导致的亲密度变化
    function calculateIntimacy(uint256 tokenId) public view returns (uint256) {
        uint256 fecesDamage;
        uint256 hungryDamage;
        if (calculateFeces(tokenId) < 10) {
            fecesDamage = 0;
        }
        else {
            fecesDamage = calculateFeces(tokenId) - 10;
        }
        if (calculateHunger(tokenId) < 10) {
            hungryDamage = 0;
        }
        else {
            hungryDamage = calculateHunger(tokenId) - 10;
        }
        if (detail[tokenId].intimacy < (hungryDamage) + (hungryDamage)) {
            return 0;
        }
        return detail[tokenId].intimacy - (hungryDamage) - (hungryDamage);
    }

    // 买药
    function buyMedicine(uint256 _amount) public {
        if (credit[msg.sender] < SafeMath.mul(_amount, priceOfMedicine)) {
            revert creditNotEnough();
        }
        credit[msg.sender] = SafeMath.sub(credit[msg.sender], SafeMath.mul(_amount, priceOfMedicine));
        medicine[msg.sender] += _amount;
    }

    // 恢复健康度
    function cure(uint256 tokenId) public onlyOwner(tokenId) onlyNotDead(tokenId) {
        if (medicine[msg.sender] == 0) {
            revert medicineNotEnough();
        }
        detail[tokenId].healthy = 100;
        medicine[msg.sender] -= 1;
    }

    // 将猫的健康值、排泄物、饥饿值上链
    function examCat(uint256 tokenId) public {
        uint256 healthy = calculateHealth(tokenId);
        uint256 hungry = calculateHunger(tokenId);
        uint256 feces = calculateFeces(tokenId);
        uint256 intimacy = calculateIntimacy(tokenId);
        detail[tokenId].healthy = healthy;
        detail[tokenId].hungry = hungry;
        detail[tokenId].feces = feces;
        detail[tokenId].intimacy = intimacy;
        emit DataUpdated(tokenId, healthy, hungry, feces, intimacy);
    }

    // 二分查找特定值的索引
    function binarySearch(uint256[] storage arr, uint256 value) internal view returns (int256) {
        int256 left = 0;
        int256 right = int256(arr.length) - 1;

        while (left <= right) {
            int256 mid = left + (right - left) / 2;
            if (arr[uint256(mid)] == value) {
                return mid;
            }
            if (arr[uint256(mid)] < value) {
                left = mid + 1;
            } else {
                right = mid - 1;
            }
        }

        return -1;
    }

    // 将去世的猫埋葬
    function buryCat(uint256 tokenId) public onlyOwner(tokenId) {
        if (calculateHealth(tokenId) != 0) {
            revert notDead(tokenId);
        }
        _burn(tokenId);
        int256 index = binarySearch(ownedTokenId[msg.sender], tokenId);
        if (index >= 0) {
            for (uint256 i = uint256(index); i < ownedTokenId[msg.sender].length - 1; i++) {
                ownedTokenId[msg.sender][i] = ownedTokenId[msg.sender][i + 1];
            }
            ownedTokenId[msg.sender].pop();
        }
        emit BuryCat(tokenId);
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

    function setMedicinePrice(uint256 _price) public onlyRole(ADMIN_ROLE) {
        priceOfMedicine = _price;
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

    function _checkDeadOrNot(uint256 tokenId) internal view {
        if (calculateHealth(tokenId) == 0) {
            revert alreadyDead(tokenId);
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

    // 小猫死亡之后就不能进行操作了
    modifier onlyNotDead(uint256 tokenId) {
        _checkDeadOrNot(tokenId);
        _;
    }
}