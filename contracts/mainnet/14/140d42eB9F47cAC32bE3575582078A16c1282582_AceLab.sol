// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./MagicatRarity.sol";
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IERC20Ext is IERC20 {
    function decimals() external returns (uint);
}

// The goal of this farm is to allow a stake xBoo earn anything model
// In a flip of a traditional farm, this contract only accepts xBOO as the staking token
// Each new pool added is a new reward token, each with its own start times
// end times, and rewards per second.
contract AceLab is MagicatRarity {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    // Info of each user.
    struct UserInfo {
        uint amount;     // How many tokens the user has provided.
        uint rewardDebt; // Reward debt. See explanation below.
        uint catDebt;    // Cat debt. See explanation below.
        uint mp;         // Total staked magicat power, sum of all magicat rarities staked by this user in this pool [uint64 enough]
    }

    // Info of each pool.
    struct PoolInfo { //full slot = 32B
        IERC20 RewardToken;           //20B Address of reward token contract.
        uint32 userLimitEndTime;      //4B
        uint8 TokenPrecision;         //1B The precision factor used for calculations, equals the tokens decimals
                                      //7B [free space available here]

        uint xBooStakedAmount;        //32B # of xboo allocated to this pool
        uint mpStakedAmount;          //32B # of mp allocated to this pool

        uint RewardPerSecond;         //32B reward token per second for this pool in wei
        uint accRewardPerShare;       //32B Accumulated reward per share, times the pools token precision. See below.
        uint accRewardPerShareMagicat;//32B Accumulated reward per share, times the pools token precision. See below.

        address protocolOwnerAddress; //20B this address is the owner of the protocol corresponding to the reward token, used for emergency withdraw to them only
        uint32 lastRewardTime;        //4B Last block time that reward distribution occurs.
        uint32 endTime;               //4B end time of pool
        uint32 startTime;             //4B start time of pool
    }

    //remember that this should be *1000 of the apparent value since onchain rarities are multiplied by 1000, also remember that this is per 1e18 wei of xboo.
    uint mpPerXboo = 300 * 1000;

    IERC20 public immutable xboo;
    uint32 public baseUserLimitTime = 2 days;
    uint public baseUserLimit;

    IERC721 public immutable magicat;
    uint32 public magicatBoost = 1000;

    // Info of each pool.
    mapping (uint => PoolInfo) public poolInfo;
    // Number of pools
    uint public poolAmount;
    // Info of each user that stakes tokens.
    mapping (uint => mapping (address => UserInfo)) public userInfo;
    // Info of each users set of staked magicats per pool (pool => (user => magicats))
    mapping (uint => mapping (address => EnumerableSet.UintSet)) _stakedMagicats; //this data type cant be public, use getter getStakedMagicats()
    // Total staked amount of xboo in all pools by user
    mapping (address => uint) public balanceOf;
    // Sum of all rarities of all staked magicats
    uint public stakedMagicatPower;
    // Max total magicat power
    uint public constant MAX_MAGICAT_POWER = 10627876002;
    // precisionOf[i] = 10**(30 - i)
    mapping (uint8 => uint) public precisionOf;
    mapping (address => bool) public isRewardToken;

    event AdminTokenRecovery(address tokenRecovered, uint amount);
    event Deposit(address indexed user, uint indexed pid, uint amount);
    event Withdraw(address indexed user, uint indexed pid, uint amount);
    event EmergencyWithdraw(address indexed user, uint indexed pid, uint amount);
    event SetRewardPerSecond(uint _pid, uint _gemsPerSecond);
    event StakeMagicat(address indexed user, uint indexed pid, uint indexed tokenID);
    event UnstakeMagicat(address indexed user, uint indexed pid, uint indexed tokenID);

    constructor(IERC20 _xboo, IERC721 _magicat) {
        xboo = _xboo;
        magicat = _magicat;
        isRewardToken[address(_xboo)] = true;
    }


    function poolLength() external view returns (uint) {
        return poolAmount;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint _from, uint _to, uint startTime, uint endTime) internal pure returns (uint) {
        _from = _from > startTime ? _from : startTime;
        if (_from > endTime || _to < startTime) {
            return 0;
        }
        if (_to > endTime) {
            return endTime - _from;
        }
        return _to - _from;
    }

    // View function to see pending BOOs on frontend.
    function pendingReward(uint _pid, address _user) external view returns (uint) {
        (uint xbooReward, uint magicatReward) = pendingRewards(_pid, _user);
        return xbooReward + magicatReward;
    }

    function pendingRewards(uint _pid, address _user) public view returns (uint xbooReward, uint magicatReward) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint accRewardPerShare = pool.accRewardPerShare;
        uint accRewardPerShareMagicat = pool.accRewardPerShareMagicat;

        if (block.timestamp > pool.lastRewardTime) {
            uint reward = pool.RewardPerSecond * getMultiplier(pool.lastRewardTime, block.timestamp, pool.startTime, pool.endTime);
            if(pool.xBooStakedAmount != 0) accRewardPerShare += reward * (10000 - magicatBoost) / 10000 * precisionOf[pool.TokenPrecision] / pool.xBooStakedAmount;
            if(pool.mpStakedAmount != 0) accRewardPerShareMagicat += reward * magicatBoost / 10000 * precisionOf[pool.TokenPrecision] / pool.mpStakedAmount;
        }
        xbooReward = (user.amount * accRewardPerShare / precisionOf[pool.TokenPrecision]) - user.rewardDebt;
        magicatReward = (effectiveMP(user.amount, user.mp) * accRewardPerShareMagicat / precisionOf[pool.TokenPrecision]) - user.catDebt;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint length = poolAmount;
        for (uint pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }

        uint reward = pool.RewardPerSecond * getMultiplier(pool.lastRewardTime, block.timestamp, pool.startTime, pool.endTime);

        if(pool.xBooStakedAmount != 0) pool.accRewardPerShare += reward * (10000 - magicatBoost) / 10000 * precisionOf[pool.TokenPrecision] / pool.xBooStakedAmount;
        if(pool.mpStakedAmount != 0) pool.accRewardPerShareMagicat += reward * magicatBoost / 10000 * precisionOf[pool.TokenPrecision] / pool.mpStakedAmount;
        pool.lastRewardTime = uint32(block.timestamp);
    }

    function userCurrentStakeableMP(uint _pid, address _user) public view returns (int) {
        return int(_stakeableMP(userInfo[_pid][_user].amount)) - int(userInfo[_pid][_user].mp);
    }

    function stakeableMP(uint _xboo) public view returns (uint) {
        return _stakeableMP(_xboo);
    }

    function stakeableMP(uint _pid, address _user) public view returns (uint) {
        return _stakeableMP(userInfo[_pid][_user].amount);
    }

    function effectiveMP(uint _amount, uint _mp) public view returns (uint) {
        _amount = _stakeableMP(_amount);
        return _mp < _amount ? _mp : _amount;
    }

    function _stakeableMP(uint _xboo) internal view returns (uint) {
        return mpPerXboo * _xboo / 1 ether;
    }

    function deposit(uint _pid, uint _amount) external {
        _deposit(_pid, _amount, msg.sender, new uint[](0));
    }

    function deposit(uint _pid, uint _amount, address to) external {
        _deposit(_pid, _amount, to, new uint[](0));
    }

    function deposit(uint _pid, uint _amount, uint[] memory tokenIDs) external {
        _deposit(_pid, _amount, msg.sender, tokenIDs);
    }

    function deposit(uint _pid, uint _amount, address to, uint[] memory tokenIDs) external {
        _deposit(_pid, _amount, to, tokenIDs);
    }

    // Deposit tokens.
    function _deposit(uint _pid, uint _amount, address to, uint[] memory tokenIDs) internal {

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][to];

        if(baseUserLimit > 0 && block.timestamp < pool.userLimitEndTime) {
            require(user.amount + _amount <= baseUserLimit, "deposit: user has hit deposit cap");
        }

        updatePool(_pid);

        uint precision = precisionOf[pool.TokenPrecision];//precision
        uint amount = user.amount;

        uint pending = (amount * pool.accRewardPerShare / precision) - user.rewardDebt;
        uint pendingCat = effectiveMP(amount, user.mp) * pool.accRewardPerShareMagicat / precision - user.catDebt;

        user.amount += _amount;
        amount += _amount;
        pool.xBooStakedAmount += _amount;
        balanceOf[to] += _amount;

        user.rewardDebt = amount * pool.accRewardPerShare / precision;

        if(pending > 0)
            safeTransfer(pool.RewardToken, to, pending + pendingCat);
        if(_amount > 0)
            xboo.safeTransferFrom(msg.sender, address(this), _amount);


        emit Deposit(msg.sender, _pid, _amount);

        uint len = tokenIDs.length;
        if(len == 0) {
            user.catDebt = effectiveMP(amount, user.mp) * pool.accRewardPerShareMagicat / precision;
            return;
        }

        do {
            unchecked {--len;}
            pending = tokenIDs[len];
            magicat.safeTransferFrom(msg.sender, address(this), pending);
            _stakedMagicats[_pid][to].add(pending);
            emit StakeMagicat(to, _pid, pending);
        } while (len != 0);

        pending = sumOfRarities(tokenIDs);
        stakedMagicatPower += pending;

        user.mp += pending;
        user.catDebt = effectiveMP(amount, user.mp) * pool.accRewardPerShareMagicat / precision;
        pool.mpStakedAmount += pending;
    }

    // Withdraw tokens.
    function withdraw(uint _pid, uint _amount) external {
        _withdraw(_pid, _amount, msg.sender, new uint[](0));
    }

    function withdraw(uint _pid, uint _amount, address to) external {
        _withdraw(_pid, _amount, to, new uint[](0));
    }

    function withdraw(uint _pid, uint _amount, uint[] memory tokenIDs) external {
        _withdraw(_pid, _amount, msg.sender, tokenIDs);
    }

    function withdraw(uint _pid, uint _amount, address to, uint[] memory tokenIDs) external {
        _withdraw(_pid, _amount, to, tokenIDs);
    }

    function _withdraw(uint _pid, uint _amount, address to, uint[] memory tokenIDs) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);

        uint precision = precisionOf[pool.TokenPrecision];
        uint amount = user.amount;

        uint pending = (amount * pool.accRewardPerShare / precision) - user.rewardDebt;
        uint pendingCat = (effectiveMP(amount, user.mp) * pool.accRewardPerShareMagicat / precision) - user.catDebt;

        user.amount -= _amount;
        amount -= _amount;
        pool.xBooStakedAmount -= _amount;
        balanceOf[msg.sender] -= _amount;

        user.rewardDebt = amount * pool.accRewardPerShare / precision;

        if(pending > 0)
            safeTransfer(pool.RewardToken, to, pending + pendingCat);
        if(_amount > 0)
            safeTransfer(xboo, to, _amount);

        emit Withdraw(to, _pid, _amount);

        uint len = tokenIDs.length;
        if(len == 0) {
            user.catDebt = effectiveMP(amount, user.mp) * pool.accRewardPerShareMagicat / precision;
            return;
        }

        do {
            unchecked {--len;}
            pending = tokenIDs[len];
            require(_stakedMagicats[_pid][msg.sender].contains(pending), "Magicat not staked by this user in this pool!");
            _stakedMagicats[_pid][msg.sender].remove(pending);
            magicat.safeTransferFrom(address(this), to, pending);
            emit UnstakeMagicat(msg.sender, _pid, pending);
        } while (len != 0);

        pending = sumOfRarities(tokenIDs);
        stakedMagicatPower -= pending;

        user.mp -= pending;
        user.catDebt = effectiveMP(amount, user.mp) * pool.accRewardPerShareMagicat / precision;
        pool.mpStakedAmount -= pending;
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint oldUserAmount = user.amount;
        pool.xBooStakedAmount -= user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        balanceOf[msg.sender] -= oldUserAmount;

        xboo.safeTransfer(address(msg.sender), oldUserAmount);
        emit EmergencyWithdraw(msg.sender, _pid, oldUserAmount);

    }

    // Safe erc20 transfer function, just in case if rounding error causes pool to not have enough reward tokens.
    function safeTransfer(IERC20 token, address _to, uint _amount) internal {
        uint bal = token.balanceOf(address(this));
        if (_amount > bal) {
            token.safeTransfer(_to, bal);
        } else {
            token.safeTransfer(_to, _amount);
        }
    }

    function stakeAndUnstakeMagicats(uint _pid, uint[] memory stakeTokenIDs, uint[] memory unstakeTokenIDs) external {
        _withdraw(_pid, 0, msg.sender, unstakeTokenIDs);
        _deposit(_pid, 0, msg.sender, stakeTokenIDs);
    }

    function onERC721Received(address operator, address /*from*/, uint /*tokenId*/, bytes calldata /*data*/) external view returns (bytes4) {
        if(operator == address(this))
            return this.onERC721Received.selector;
        return 0;
    }

    // Admin functions

    function setCatMultiplier(uint mul) external onlyAdmin {
        mpPerXboo = mul;
    }

    function setMagicatBoost(uint32 boost) external onlyAdmin {
        require(boost < 5000); //5000 = 50%
        magicatBoost = boost;
    }

    function changeEndTime(uint _pid, uint32 addSeconds) external onlyAuth {
        poolInfo[_pid].endTime += addSeconds;
    }

    function stopReward(uint _pid) external onlyAuth {
        poolInfo[_pid].endTime = uint32(block.timestamp);
    }

    function changePoolUserLimitEndTime(uint _pid, uint32 _time) external onlyAdmin {
        poolInfo[_pid].userLimitEndTime = _time;
    }

    function changeUserLimit(uint _limit) external onlyAdmin {
        baseUserLimit = _limit;
    }

    function changeBaseUserLimitTime(uint32 _time) external onlyAdmin {
        baseUserLimitTime = _time;
    }

    function checkForToken(IERC20 _Token) private view {
        require(!isRewardToken[address(_Token)], "checkForToken: reward token or xboo provided");
    }

    function recoverWrongTokens(address _tokenAddress) external onlyAdmin {
        checkForToken(IERC20(_tokenAddress));

        uint bal = IERC20(_tokenAddress).balanceOf(address(this));
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), bal);

        emit AdminTokenRecovery(_tokenAddress, bal);
    }

    function emergencyRewardWithdraw(uint _pid, uint _amount) external onlyAdmin {
        poolInfo[_pid].RewardToken.safeTransfer(poolInfo[_pid].protocolOwnerAddress, _amount);
    }

    // Add a new token to the pool. Can only be called by the owner.
    function add(uint _rewardPerSecond, IERC20Ext _Token, uint32 _startTime, uint32 _endTime, address _protocolOwner) external onlyAuth {
        _add(_rewardPerSecond, _Token, _startTime, _endTime, _protocolOwner);
    }

    // Add a new token to the pool (internal).
    function _add(uint _rewardPerSecond, IERC20Ext _Token, uint32 _startTime, uint32 _endTime, address _protocolOwner) internal {
        require(_rewardPerSecond > 9, "AceLab _add: _rewardPerSecond needs to be at least 10 wei");

        checkForToken(_Token); // ensure you cant add duplicate pools
        isRewardToken[address(_Token)] = true;

        uint32 lastRewardTime = uint32(block.timestamp > _startTime ? block.timestamp : _startTime);
        uint8 decimalsRewardToken = uint8(_Token.decimals());
        require(decimalsRewardToken < 30, "Token has way too many decimals");
        if(precisionOf[decimalsRewardToken] == 0)
            precisionOf[decimalsRewardToken] = 10**(30 - decimalsRewardToken);

        PoolInfo storage poolinfo = poolInfo[poolAmount];
        poolinfo.RewardToken = _Token;
        poolinfo.RewardPerSecond = _rewardPerSecond;
        poolinfo.TokenPrecision = decimalsRewardToken;
        //poolinfo.xBooStakedAmount = 0;
        poolinfo.startTime = _startTime;
        poolinfo.endTime = _endTime;
        poolinfo.lastRewardTime = lastRewardTime;
        //poolinfo.accRewardPerShare = 0;
        poolinfo.protocolOwnerAddress = _protocolOwner;
        poolinfo.userLimitEndTime = lastRewardTime + baseUserLimitTime;
        poolAmount += 1;
    }

    // Update the given pool's reward per second. Can only be called by the owner.
    function setRewardPerSecond(uint _pid, uint _rewardPerSecond) external onlyAdmin {

        updatePool(_pid);

        poolInfo[_pid].RewardPerSecond = _rewardPerSecond;

        emit SetRewardPerSecond(_pid, _rewardPerSecond);
    }

    /**
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function getStakedMagicats(uint _pid, address _user) external view returns (uint[] memory) {
        return _stakedMagicats[_pid][_user].values();
    }

}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "./SpookyAuth.sol";

contract MagicatRarity is SpookyAuth {
    mapping (uint => uint) public rarityOf;

    function setRarities(uint[] memory rarities, uint256 offset) public onlyAuth {
        uint len = rarities.length;
        for(uint i = 0; i < len; i++)
            rarityOf[i + offset] = rarities[i];
    }

    function rarityOfBatch(uint[] memory tokenIDs) public view returns (uint[] memory rarities) {
        uint len = tokenIDs.length;
        rarities = new uint[](len);
        for(uint i = 0; i < len; i++)
            rarities[i] = rarityOf[tokenIDs[i]];
    }

    function sumOfRarities(uint[] memory tokenIDs) public view returns (uint sum) {
        uint len = tokenIDs.length;
        sum = 0;
        for(uint i = 0; i < len; i++)
            sum += rarityOf[tokenIDs[i]];
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/structs/EnumerableSet.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastvalue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastvalue;
                // Update the index for the moved value
                set._indexes[lastvalue] = valueIndex; // Replace lastvalue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

abstract contract SpookyAuth {
    // set of addresses that can perform certain functions
    mapping(address => bool) public isAuth;
    address[] public authorized;
    address public admin;

    modifier onlyAuth() {
        require(isAuth[msg.sender] || msg.sender == admin, "SpookySwap: FORBIDDEN (auth)");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "SpookySwap: FORBIDDEN (admin)");
        _;
    }

    event AddAuth(address indexed by, address indexed to);
    event RevokeAuth(address indexed by, address indexed to);
    event SetAdmin(address indexed by, address indexed to);

    constructor() {
        admin = msg.sender;
        emit SetAdmin(address(this), msg.sender);
        isAuth[msg.sender] = true;
        authorized.push(msg.sender);
        emit AddAuth(address(this), msg.sender);
    }

    function setAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
        emit SetAdmin(msg.sender, newAdmin);
    }

    function addAuth(address _auth) external onlyAuth {
        isAuth[_auth] = true;
        authorized.push(_auth);
        emit AddAuth(msg.sender, _auth);
    }

    function revokeAuth(address _auth) external onlyAuth {
        require(_auth != admin);
        isAuth[_auth] = false;
        emit RevokeAuth(msg.sender, _auth);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}