// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "./interfaces/IBalanceCalculator.sol";
import "./Gauge.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface Vault {
	function pricePerShare() external view returns(uint256);
	function decimals() external view returns(uint256);
}

contract EarnMore is Gauge, Ownable {
    mapping(address => bool) public earnMore;
    mapping(address => uint) public baseTokenBalance;

    uint256 public specialExcludePercent;
    uint256 public specialEarnMorePercent;
    bool public specialDeal;

    address public balanceCalculator;
    address internal factory;

    bool public earnMoreEnabledFlag;

    uint256 constant public DIVISOR = 100;
    uint256 constant EM_PRECISION = 10000;

    event EarnMoreStatus(bool indexed _status);
    event SpecialDealStatus(bool indexed _status);
    event BalanceCalculatorAddress(address indexed _balanceCalculatorAddress);
    event SpecialDealParams(uint256 indexed _specialExcludePercent, uint256 indexed _specialEarnMorePercent);
    event FromEarnToGauge(address indexed _sender);
    event FromGaugeToEarn(address indexed _sender);

    constructor(address _stake, 
                address  __ve, 
                address _voter,
                address _balanceCalculator,
                address _owner,
                bool _earnMoreEnabledFlag) Gauge(_stake, __ve, _voter) Ownable() {

        balanceCalculator = _balanceCalculator;
        earnMoreEnabledFlag = _earnMoreEnabledFlag;
        factory = msg.sender;
        _transferOwnership(_owner);
    }

    modifier earnMoreEnabled() {
        require(earnMoreEnabledFlag, "This is not an earn more gauge");
        _;
    }

    function getExcludePercent() public view returns(uint256) {
        if (specialDeal) {
            return specialExcludePercent;
        } else {
            return BaseV1EMGaugeFactory(factory).globalExcludePercent();
        }
    }

    function getEarnMorePercent() public view returns(uint256) {
        if (specialDeal) {
            return specialEarnMorePercent;
        } else {
            return BaseV1EMGaugeFactory(factory).globalEarnMorePercent();
        }
    }
    function getTreasury() public view returns(address) {
        return BaseV1EMGaugeFactory(factory).treasury();
    }
    function setSpecialDeal(uint256 _specialExcludePercent, uint256 _specialEarnMorePercent) public onlyOwner {
        specialDeal = true;
        specialExcludePercent = _specialExcludePercent;
        specialEarnMorePercent = _specialEarnMorePercent;

        emit SpecialDealParams(_specialExcludePercent, _specialEarnMorePercent);
        emit SpecialDealStatus(specialDeal);
    }

    function unsetSpecialDeal() public onlyOwner {
        specialDeal = false;

        emit SpecialDealStatus(specialDeal);
    }

    function derivedBalance(address account) public override view returns(uint) {
    	uint256 derived = super.derivedBalance(account);
    	if (earnMore[account]) {
        	derived = derived * (getEarnMorePercent() + DIVISOR) / DIVISOR;
        }

        return derived;
    }

    /// @dev calculates deposited token price
    /// @param lpValue - amount of tokens
    function calculateTokenBalance(uint256 lpValue) internal view returns(uint) {
        return IBalanceCalculator(balanceCalculator).calculateTokenBalance(stake, lpValue);
    }

    function earnMoreDeposit(uint amount, uint tokenId) external earnMoreEnabled {
    	require(earnMore[msg.sender] || balanceOf[msg.sender] == 0, "You already have non-EarnMore deposit");

        earnMore[msg.sender] = true;
    	baseTokenBalance[msg.sender] += calculateTokenBalance(amount);
    	_deposit(amount, tokenId);
    }

    /// @dev exclude % of income at the exit from earnMore
    /// @param account - user who exits
    /// @param amount - amount of tokens to be withdrawn
    function _excludeProfit(address account, uint256 amount) internal returns(uint) {
    	uint256 curTokenBalance = calculateTokenBalance(amount);
        uint256 prevTokenBalance = (baseTokenBalance[account] * amount)/ balanceOf[account];
        uint256 profit = 0;
        if (curTokenBalance > prevTokenBalance) {
            profit = curTokenBalance - prevTokenBalance;
        }
    	uint256 baseValueToExclude = (profit * getExcludePercent()) / DIVISOR;
    	uint256 excludedPortion = (EM_PRECISION * baseValueToExclude) / curTokenBalance;
    	uint256 valueToExclude = (excludedPortion * amount) / EM_PRECISION;

        totalSupply -= valueToExclude;
        balanceOf[account] -= valueToExclude;
    	_safeTransfer(stake, getTreasury(), valueToExclude);

    	return valueToExclude;
    }

    function earnMoreWithdrawAll() external {
    	earnMoreWithdraw(balanceOf[msg.sender]);
    }

    function earnMoreWithdraw(uint256 amount) public {
        require(earnMore[msg.sender], "You don't have EarnMore deposit");

        uint256 portion = EM_PRECISION * amount / balanceOf[msg.sender];
        uint256 excludedValue = _excludeProfit(msg.sender, amount);

        baseTokenBalance[msg.sender] -= baseTokenBalance[msg.sender] * portion / EM_PRECISION;
        if (baseTokenBalance[msg.sender] == 0) {
            earnMore[msg.sender] = false;
        }

        _withdrawToken(amount - excludedValue, tokenIds[msg.sender]);
    }

    function deposit(uint amount, uint tokenId) public override {
        require(!earnMore[msg.sender], "You already have EarnMore deposit");
        _deposit(amount, tokenId);
    }

    /// @dev withdraw tokens from Earn More
    /// @param amount - amount of tokens to withdraw
    /// @param tokenId - NFT token id
    function withdrawToken(uint amount, uint tokenId) public override {
        require(!earnMore[msg.sender], "You should withdraw through earnMoreWithdraw");
        _withdrawToken(amount, tokenId);
    }

    /// @dev recalculate derived balance of msg sender and save checkpoints
    function recalculateBalance() internal {
        uint256 _derivedBalance = derivedBalances[msg.sender];
        derivedSupply -= _derivedBalance;
        _derivedBalance = derivedBalance(msg.sender);
        derivedBalances[msg.sender] = _derivedBalance;
        derivedSupply += _derivedBalance;

        _writeCheckpoint(msg.sender, derivedBalances[msg.sender]);
        _writeSupplyCheckpoint();
    }

    /// @dev switch from earn more to "normal" gauge
    ///      exclude profit and recalculate derived balance
    function fromEarnToGauge() external {
        require(earnMore[msg.sender], "You don't have EarnMore deposit");
        _excludeProfit(msg.sender, balanceOf[msg.sender]);
        earnMore[msg.sender] = false;
    	baseTokenBalance[msg.sender] = 0;
        recalculateBalance();

        emit FromEarnToGauge(msg.sender);
    }

    /// @dev switch from gauge to earn more
    ///      calculate new derived balance
    function fromGaugeToEarn() external earnMoreEnabled {
        require(!earnMore[msg.sender], "You already have EarnMore deposit");
        earnMore[msg.sender] = true;
    	baseTokenBalance[msg.sender] = calculateTokenBalance(balanceOf[msg.sender]);
        recalculateBalance();

        emit FromGaugeToEarn(msg.sender);
    }

    function switchGaugeToEMGauge(address _balanceCalculator) external onlyOwner {
        require(earnMoreEnabledFlag == false, "Already EMGauge");
        require(_balanceCalculator != address(0), "Wrong address");
        _changeBalanceCalculator(_balanceCalculator);
        earnMoreEnabledFlag = true; 

        emit EarnMoreStatus(earnMoreEnabledFlag);
    }

    function switchEMGaugeToGauge() external onlyOwner {
        require(earnMoreEnabledFlag == true, "Already Gauge");
        earnMoreEnabledFlag = false;

        emit EarnMoreStatus(earnMoreEnabledFlag);
    }

    function changeBalanceCalculator(address _balanceCalculator) external onlyOwner {
        _changeBalanceCalculator(_balanceCalculator);
    }

    function _changeBalanceCalculator(address _balanceCalculator) internal {
        balanceCalculator = _balanceCalculator;

        emit BalanceCalculatorAddress(_balanceCalculator);
    }
}

contract BaseV1EMGaugeFactory is Ownable {
    address public last_gauge;

    uint256 public globalExcludePercent;
    uint256 public globalEarnMorePercent;
    address public treasury;

    event GlobalParamsChanged(uint256 excludePercent, uint256 earnMorePercent);
    event TreasuryChanged(address treasury);
    
    constructor(uint256 _globalExcludePercent, uint256 _gEarnMorePercent, address _treasury) Ownable() {
        _setGlobalParams(_globalExcludePercent, _gEarnMorePercent);
        _changeTreasury(_treasury);
    }

    function setGlobalParams(uint256 _newGlobalExcludePercent, uint256 _newGlobalEarnMorePercent) external onlyOwner {
        _setGlobalParams(_newGlobalExcludePercent, _newGlobalEarnMorePercent);
    }

    function _setGlobalParams(uint256 _newGlobalExcludePercent, uint256 _newGlobalEarnMorePercent) internal {
        globalExcludePercent = _newGlobalExcludePercent;
        globalEarnMorePercent = _newGlobalEarnMorePercent;

        emit GlobalParamsChanged(_newGlobalExcludePercent, _newGlobalEarnMorePercent);
    }

    function changeTreasury(address _newTreasury) external onlyOwner {
        _changeTreasury(_newTreasury);
    }

    function _changeTreasury(address _newTreasury) internal {
        treasury = _newTreasury;

        emit TreasuryChanged(_newTreasury);
    }

    function createEMGauge(
        address _stake, 
        address _ve, 
        address _balanceCalculator,
        address _owner, 
        bool _earnMoreEnabled
    ) 
        external 
        returns (address) 
    {
        last_gauge = address(new EarnMore(
            _stake, 
            _ve, 
            msg.sender,    // voter
            _balanceCalculator,
            _owner,
            _earnMoreEnabled));
        return last_gauge;
    }

    function createEMGaugeSingle(
        address _stake, 
        address _ve, 
        address _voter, 
        address _balanceCalculator,
        address _owner,
        bool _earnMoreEnabled
    ) 
        external 
        returns (address) 
    {
        last_gauge = address(new EarnMore(
            _stake, 
            _ve, 
            _voter, 
            _balanceCalculator,
            _owner,
            _earnMoreEnabled));
        return last_gauge;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "./utility/Math.sol";

interface erc20 {
    function totalSupply() external view returns (uint256);
    function transfer(address recipient, uint amount) external returns (bool);
    function balanceOf(address) external view returns (uint);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    function approve(address spender, uint value) external returns (bool);
}

interface ve {
    function token() external view returns (address);
    function balanceOfNFT(uint) external view returns (uint);
    function isApprovedOrOwner(address, uint) external view returns (bool);
    function ownerOf(uint) external view returns (address);
    function transferFrom(address, address, uint) external;
}

interface Voter {
    function attachTokenToGauge(uint _tokenId, address account) external;
    function detachTokenFromGauge(uint _tokenId, address account) external;
    function emitDeposit(uint _tokenId, address account, uint amount) external;
    function emitWithdraw(uint _tokenId, address account, uint amount) external;
    function distribute(address _gauge) external;
}

// Gauges are used to incentivize pools, they emit reward tokens over 7 days for staked LP tokens
// Difference from solidly: removed claim fees
contract Gauge {

    address public immutable stake; // the LP token that needs to be staked for rewards
    address public immutable _ve; // the ve token used for gauges
    address public immutable voter;

    uint public derivedSupply;
    mapping(address => uint) public derivedBalances;

    uint internal constant DURATION = 7 days; // rewards are released over 7 days
    uint internal constant PRECISION = 10 ** 18;

    // default snx staking contract implementation
    mapping(address => uint) public rewardRate;
    mapping(address => uint) public periodFinish;
    mapping(address => uint) public lastUpdateTime;
    mapping(address => uint) public rewardPerTokenStored;

    mapping(address => mapping(address => uint)) public lastEarn;
    mapping(address => mapping(address => uint)) public userRewardPerTokenStored;

    mapping(address => uint) public tokenIds;

    uint public totalSupply;
    mapping(address => uint) public balanceOf;

    address[] public rewards;
    mapping(address => bool) public isReward;

    /// @notice A checkpoint for marking balance
    struct Checkpoint {
        uint timestamp;
        uint balanceOf;
    }

    /// @notice A checkpoint for marking reward rate
    struct RewardPerTokenCheckpoint {
        uint timestamp;
        uint rewardPerToken;
    }

    /// @notice A checkpoint for marking supply
    struct SupplyCheckpoint {
        uint timestamp;
        uint supply;
    }

    /// @notice A record of balance checkpoints for each account, by index
    mapping (address => mapping (uint => Checkpoint)) public checkpoints;
    /// @notice The number of checkpoints for each account
    mapping (address => uint) public numCheckpoints;
    /// @notice A record of balance checkpoints for each token, by index
    mapping (uint => SupplyCheckpoint) public supplyCheckpoints;
    /// @notice The number of checkpoints
    uint public supplyNumCheckpoints;
    /// @notice A record of balance checkpoints for each token, by index
    mapping (address => mapping (uint => RewardPerTokenCheckpoint)) public rewardPerTokenCheckpoints;
    /// @notice The number of checkpoints for each token
    mapping (address => uint) public rewardPerTokenNumCheckpoints;

    event Deposit(address indexed from, uint tokenId, uint amount);
    event Withdraw(address indexed from, uint tokenId, uint amount);
    event NotifyReward(address indexed from, address indexed reward, uint amount);
    event ClaimRewards(address indexed from, address indexed reward, uint amount);

    constructor(address _stake, address  __ve, address _voter) {
        stake = _stake;
        _ve = __ve;
        voter = _voter;
    }

    // simple re-entrancy check
    uint internal _unlocked = 1;
    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    /**
    * @notice Determine the prior balance for an account as of a block number
    * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
    * @param account The address of the account to check
    * @param timestamp The timestamp to get the balance at
    * @return The balance the account had as of the given block
    */
    function getPriorBalanceIndex(address account, uint timestamp) public view returns (uint) {
        uint nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].timestamp <= timestamp) {
            return (nCheckpoints - 1);
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].timestamp > timestamp) {
            return 0;
        }

        uint lower = 0;
        uint upper = nCheckpoints - 1;
        while (upper > lower) {
            uint center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.timestamp == timestamp) {
                return center;
            } else if (cp.timestamp < timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return lower;
    }

    function getPriorSupplyIndex(uint timestamp) public view returns (uint) {
        uint nCheckpoints = supplyNumCheckpoints;
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (supplyCheckpoints[nCheckpoints - 1].timestamp <= timestamp) {
            return (nCheckpoints - 1);
        }

        // Next check implicit zero balance
        if (supplyCheckpoints[0].timestamp > timestamp) {
            return 0;
        }

        uint lower = 0;
        uint upper = nCheckpoints - 1;
        while (upper > lower) {
            uint center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            SupplyCheckpoint memory cp = supplyCheckpoints[center];
            if (cp.timestamp == timestamp) {
                return center;
            } else if (cp.timestamp < timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return lower;
    }

    function getPriorRewardPerToken(address token, uint timestamp) public view returns (uint, uint) {
        uint nCheckpoints = rewardPerTokenNumCheckpoints[token];
        if (nCheckpoints == 0) {
            return (0,0);
        }

        // First check most recent balance
        if (rewardPerTokenCheckpoints[token][nCheckpoints - 1].timestamp <= timestamp) {
            return (rewardPerTokenCheckpoints[token][nCheckpoints - 1].rewardPerToken, rewardPerTokenCheckpoints[token][nCheckpoints - 1].timestamp);
        }

        // Next check implicit zero balance
        if (rewardPerTokenCheckpoints[token][0].timestamp > timestamp) {
            return (0,0);
        }

        uint lower = 0;
        uint upper = nCheckpoints - 1;
        while (upper > lower) {
            uint center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            RewardPerTokenCheckpoint memory cp = rewardPerTokenCheckpoints[token][center];
            if (cp.timestamp == timestamp) {
                return (cp.rewardPerToken, cp.timestamp);
            } else if (cp.timestamp < timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return (rewardPerTokenCheckpoints[token][lower].rewardPerToken, rewardPerTokenCheckpoints[token][lower].timestamp);
    }

    function _writeCheckpoint(address account, uint balance) internal {
        uint _timestamp = block.timestamp;
        uint _nCheckPoints = numCheckpoints[account];

        if (_nCheckPoints > 0 && checkpoints[account][_nCheckPoints - 1].timestamp == _timestamp) {
            checkpoints[account][_nCheckPoints - 1].balanceOf = balance;
        } else {
            checkpoints[account][_nCheckPoints] = Checkpoint(_timestamp, balance);
            numCheckpoints[account] = _nCheckPoints + 1;
        }
    }

    function _writeRewardPerTokenCheckpoint(address token, uint reward, uint timestamp) internal {
        uint _nCheckPoints = rewardPerTokenNumCheckpoints[token];

        if (_nCheckPoints > 0 && rewardPerTokenCheckpoints[token][_nCheckPoints - 1].timestamp == timestamp) {
            rewardPerTokenCheckpoints[token][_nCheckPoints - 1].rewardPerToken = reward;
        } else {
            rewardPerTokenCheckpoints[token][_nCheckPoints] = RewardPerTokenCheckpoint(timestamp, reward);
            rewardPerTokenNumCheckpoints[token] = _nCheckPoints + 1;
        }
    }

    function _writeSupplyCheckpoint() internal {
        uint _nCheckPoints = supplyNumCheckpoints;
        uint _timestamp = block.timestamp;

        if (_nCheckPoints > 0 && supplyCheckpoints[_nCheckPoints - 1].timestamp == _timestamp) {
            supplyCheckpoints[_nCheckPoints - 1].supply = derivedSupply;
        } else {
            supplyCheckpoints[_nCheckPoints] = SupplyCheckpoint(_timestamp, derivedSupply);
            supplyNumCheckpoints = _nCheckPoints + 1;
        }
    }

    function rewardsListLength() external view returns (uint) {
        return rewards.length;
    }

    // returns the last time the reward was modified or periodFinish if the reward has ended
    function lastTimeRewardApplicable(address token) public view returns (uint) {
        return Math.min(block.timestamp, periodFinish[token]);
    }

    function getReward(address account, address[] memory tokens) external lock {
        require(msg.sender == account || msg.sender == voter);
        _unlocked = 1;
        Voter(voter).distribute(address(this));
        _unlocked = 2;

        for (uint i = 0; i < tokens.length; i++) {
            (rewardPerTokenStored[tokens[i]], lastUpdateTime[tokens[i]]) = _updateRewardPerToken(tokens[i]);

            uint _reward = earned(tokens[i], account);
            lastEarn[tokens[i]][account] = block.timestamp;
            userRewardPerTokenStored[tokens[i]][account] = rewardPerTokenStored[tokens[i]];
            if (_reward > 0) _safeTransfer(tokens[i], account, _reward);

            emit ClaimRewards(msg.sender, tokens[i], _reward);
        }

        uint _derivedBalance = derivedBalances[account];
        derivedSupply -= _derivedBalance;
        _derivedBalance = derivedBalance(account);
        derivedBalances[account] = _derivedBalance;
        derivedSupply += _derivedBalance;

        _writeCheckpoint(account, derivedBalances[account]);
        _writeSupplyCheckpoint();
    }


    function rewardPerToken(address token) public view returns (uint) {
        if (derivedSupply == 0) {
            return rewardPerTokenStored[token];
        }
        return rewardPerTokenStored[token] + ((lastTimeRewardApplicable(token) - Math.min(lastUpdateTime[token], periodFinish[token])) * rewardRate[token] * PRECISION / derivedSupply);
    }

    function derivedBalance(address account) public virtual view returns (uint) {
        uint _tokenId = tokenIds[account];
        uint _balance = balanceOf[account];
        uint _derived = _balance * 40 / 100;
        uint _adjusted = 0;
        uint _supply = erc20(_ve).totalSupply();
        if (account == ve(_ve).ownerOf(_tokenId) && _supply > 0) {
            _adjusted = ve(_ve).balanceOfNFT(_tokenId);
            _adjusted = (totalSupply * _adjusted / _supply) * 60 / 100;
        }

        return Math.min((_derived + _adjusted), _balance);
    }

    function batchRewardPerToken(address token, uint maxRuns) external {
        (rewardPerTokenStored[token], lastUpdateTime[token])  = _batchRewardPerToken(token, maxRuns);
    }

    function _batchRewardPerToken(address token, uint maxRuns) internal returns (uint, uint) {
        uint _startTimestamp = lastUpdateTime[token];
        uint reward = rewardPerTokenStored[token];

        if (supplyNumCheckpoints == 0) {
            return (reward, _startTimestamp);
        }

        if (rewardRate[token] == 0) {
            return (reward, block.timestamp);
        }

        uint _startIndex = getPriorSupplyIndex(_startTimestamp);
        uint _endIndex = Math.min(supplyNumCheckpoints-1, maxRuns);

        for (uint i = _startIndex; i < _endIndex; i++) {
            SupplyCheckpoint memory sp0 = supplyCheckpoints[i];
            if (sp0.supply > 0) {
                SupplyCheckpoint memory sp1 = supplyCheckpoints[i+1];
                (uint _reward, uint _endTime) = _calcRewardPerToken(token, sp1.timestamp, sp0.timestamp, sp0.supply, _startTimestamp);
                reward += _reward;
                _writeRewardPerTokenCheckpoint(token, reward, _endTime);
                _startTimestamp = _endTime;
            }
        }

        return (reward, _startTimestamp);
    }

    function _calcRewardPerToken(address token, uint timestamp1, uint timestamp0, uint supply, uint startTimestamp) internal view returns (uint, uint) {
        uint endTime = Math.max(timestamp1, startTimestamp);
        return (((Math.min(endTime, periodFinish[token]) - Math.min(Math.max(timestamp0, startTimestamp), periodFinish[token])) * rewardRate[token] * PRECISION / supply), endTime);
    }

    function _updateRewardPerToken(address token) internal returns (uint, uint) {
        uint _startTimestamp = lastUpdateTime[token];
        uint reward = rewardPerTokenStored[token];

        if (supplyNumCheckpoints == 0) {
            return (reward, _startTimestamp);
        }

        if (rewardRate[token] == 0) {
            return (reward, block.timestamp);
        }

        uint _startIndex = getPriorSupplyIndex(_startTimestamp);
        uint _endIndex = supplyNumCheckpoints-1;

        if (_endIndex - _startIndex > 1) {
            for (uint i = _startIndex; i < _endIndex-1; i++) {
                SupplyCheckpoint memory sp0 = supplyCheckpoints[i];
                if (sp0.supply > 0) {
                    SupplyCheckpoint memory sp1 = supplyCheckpoints[i+1];
                    (uint _reward, uint _endTime) = _calcRewardPerToken(token, sp1.timestamp, sp0.timestamp, sp0.supply, _startTimestamp);
                    reward += _reward;
                    _writeRewardPerTokenCheckpoint(token, reward, _endTime);
                    _startTimestamp = _endTime;
                }
            }
        }

        SupplyCheckpoint memory sp = supplyCheckpoints[_endIndex];
        if (sp.supply > 0) {
            (uint _reward,) = _calcRewardPerToken(token, lastTimeRewardApplicable(token), Math.max(sp.timestamp, _startTimestamp), sp.supply, _startTimestamp);
            reward += _reward;
            _writeRewardPerTokenCheckpoint(token, reward, block.timestamp);
            _startTimestamp = block.timestamp;
        }

        return (reward, _startTimestamp);
    }

    // earned is an estimation, it won't be exact till the supply > rewardPerToken calculations have run
    function earned(address token, address account) public view returns (uint) {
        uint _startTimestamp = Math.max(lastEarn[token][account], rewardPerTokenCheckpoints[token][0].timestamp);
        if (numCheckpoints[account] == 0) {
            return 0;
        }

        uint _startIndex = getPriorBalanceIndex(account, _startTimestamp);
        uint _endIndex = numCheckpoints[account]-1;

        uint reward = 0;

        if (_endIndex - _startIndex > 1) {
            for (uint i = _startIndex; i < _endIndex-1; i++) {
                Checkpoint memory cp0 = checkpoints[account][i];
                Checkpoint memory cp1 = checkpoints[account][i+1];
                (uint _rewardPerTokenStored0,) = getPriorRewardPerToken(token, cp0.timestamp);
                (uint _rewardPerTokenStored1,) = getPriorRewardPerToken(token, cp1.timestamp);
                reward += cp0.balanceOf * (_rewardPerTokenStored1 - _rewardPerTokenStored0) / PRECISION;
            }
        }

        Checkpoint memory cp = checkpoints[account][_endIndex];
        (uint _rewardPerTokenStored,) = getPriorRewardPerToken(token, cp.timestamp);
        reward += cp.balanceOf * (rewardPerToken(token) - Math.max(_rewardPerTokenStored, userRewardPerTokenStored[token][account])) / PRECISION;

        return reward;
    }

    function depositAll(uint tokenId) external {
        deposit(erc20(stake).balanceOf(msg.sender), tokenId);
    }

    function deposit(uint amount, uint tokenId) public virtual {
        _deposit(amount, tokenId);
    }

    function _deposit(uint amount, uint tokenId) internal lock {
        require(amount > 0);

        _safeTransferFrom(stake, msg.sender, address(this), amount);
        totalSupply += amount;
        balanceOf[msg.sender] += amount;

        if (tokenId > 0) {
            require(ve(_ve).ownerOf(tokenId) == msg.sender);
            if (tokenIds[msg.sender] == 0) {
                tokenIds[msg.sender] = tokenId;
                Voter(voter).attachTokenToGauge(tokenId, msg.sender);
            }
            require(tokenIds[msg.sender] == tokenId);
        } else {
            tokenId = tokenIds[msg.sender];
        }

        uint _derivedBalance = derivedBalances[msg.sender];
        derivedSupply -= _derivedBalance;
        _derivedBalance = derivedBalance(msg.sender);
        derivedBalances[msg.sender] = _derivedBalance;
        derivedSupply += _derivedBalance;

        _writeCheckpoint(msg.sender, _derivedBalance);
        _writeSupplyCheckpoint();

        Voter(voter).emitDeposit(tokenId, msg.sender, amount);
        emit Deposit(msg.sender, tokenId, amount);
    }

    function withdrawAll() external {
        withdraw(balanceOf[msg.sender]);
    }

    function withdraw(uint amount) public {
        uint tokenId = 0;
        if (amount == balanceOf[msg.sender]) {
            tokenId = tokenIds[msg.sender];
        }
        withdrawToken(amount, tokenId);
    }

    function withdrawToken(uint amount, uint tokenId) public virtual {
         _withdrawToken(amount, tokenId);
    }

    function _withdrawToken(uint amount, uint tokenId) internal lock {
        totalSupply -= amount;
        balanceOf[msg.sender] -= amount;
        _safeTransfer(stake, msg.sender, amount);

        if (tokenId > 0) {
            require(tokenId == tokenIds[msg.sender]);
            tokenIds[msg.sender] = 0;
            Voter(voter).detachTokenFromGauge(tokenId, msg.sender);
        } else {
            tokenId = tokenIds[msg.sender];
        }

        uint _derivedBalance = derivedBalances[msg.sender];
        derivedSupply -= _derivedBalance;
        _derivedBalance = derivedBalance(msg.sender);
        derivedBalances[msg.sender] = _derivedBalance;
        derivedSupply += _derivedBalance;

        _writeCheckpoint(msg.sender, derivedBalances[msg.sender]);
        _writeSupplyCheckpoint();

        Voter(voter).emitWithdraw(tokenId, msg.sender, amount);
        emit Withdraw(msg.sender, tokenId, amount);
    }

    function left(address token) external view returns (uint) {
        if (block.timestamp >= periodFinish[token]) return 0;
        uint _remaining = periodFinish[token] - block.timestamp;
        return _remaining * rewardRate[token];
    }

    function notifyRewardAmount(address token, uint amount) external lock {
        require(token != stake);
        require(amount > 0);
        if (rewardRate[token] == 0) _writeRewardPerTokenCheckpoint(token, 0, block.timestamp);
        (rewardPerTokenStored[token], lastUpdateTime[token]) = _updateRewardPerToken(token);

        if (block.timestamp >= periodFinish[token]) {
            _safeTransferFrom(token, msg.sender, address(this), amount);
            rewardRate[token] = amount / DURATION;
        } else {
            uint _remaining = periodFinish[token] - block.timestamp;
            uint _left = _remaining * rewardRate[token];
            require(amount > _left);
            _safeTransferFrom(token, msg.sender, address(this), amount);
            rewardRate[token] = (amount + _left) / DURATION;
        }
        require(rewardRate[token] > 0);
        uint balance = erc20(token).balanceOf(address(this));
        require(rewardRate[token] <= balance / DURATION, "Provided reward too high");
        periodFinish[token] = block.timestamp + DURATION;
        if (!isReward[token]) {
            isReward[token] = true;
            rewards.push(token);
        }

        emit NotifyReward(msg.sender, token, amount);
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(erc20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(erc20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    function _safeApprove(address token, address spender, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(erc20.approve.selector, spender, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }
}

contract BaseV1GaugeFactory {
    address public last_gauge;

    function createGauge(address _stake, address _ve) external returns (address) {
        last_gauge = address(new Gauge(_stake, _ve, msg.sender));
        return last_gauge;
    }

    function createGaugeSingle(address _stake, address _ve, address _voter) external returns (address) {
        last_gauge = address(new Gauge(_stake, _ve, _voter));
        return last_gauge;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IBalanceCalculator {
	function calculateTokenBalance(address baseToken, uint256 lpValue) external view returns(uint);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

library Math {
    function max(uint a, uint b) internal pure returns (uint) {
        return a >= b ? a : b;
    }
    function min(uint a, uint b) internal pure returns (uint) {
        return a < b ? a : b;
    }
}