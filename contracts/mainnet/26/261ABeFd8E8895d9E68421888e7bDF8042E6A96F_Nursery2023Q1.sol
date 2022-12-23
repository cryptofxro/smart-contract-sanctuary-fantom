// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./owner/Operator.sol";

// Note that this pool has no minter key of LIFE (rewards).
// Instead, rewards will be sent to this pool at the beginning.
contract Nursery2023Q1 is Operator {
    using SafeERC20 for IERC20;


    /// User-specific information.
    struct UserInfo {
        /// How many tokens the user provided.
        uint256 amount;
        /// How many unclaimed rewards does the user have pending.
        uint256 rewardDebt;
    }

    /// Pool-specific information.
    struct PoolInfo {
        /// Address of the token staked in the pool.
        IERC20 token;
        /// Allocation points assigned to the pool.
        /// @dev Rewards are distributed in the pool according to formula: (allocPoint / totalAllocPoint) * lifePerSecond
        uint256 allocPoint;
        /// Last time the rewards distribution was calculated.
        uint256 lastRewardTime;
        /// Accumulated LIFE per share.
        uint256 accLifePerShare;
        /// Deposit fee in %, where 100 == 1%.
        uint16 depositFee;
        /// Is the pool rewards emission started.
        bool isStarted;
    }

    /// Reward token.
    IERC20 public life;

    /// Address where the deposit fees are transferred.
    address public feeCollector;

    /// Information about each pool.
    PoolInfo[] public poolInfo;

    /// Information about each user in each pool.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    /// Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    /// The time when LIFE emissions start.
    uint256 public poolStartTime;

    /// The time when LIFE emissions end.
    uint256 public poolEndTime;

    /// Amount of LIFE emitted each second.
    uint256 public lifePerSecond;
    /// Running time of emissions (in seconds).
    uint256 public runningTime;
    /// Total amount of tokens to be emitted.
    uint256 public totalRewards;

    /* Events */

    event AddPool(address indexed user, uint256 indexed pid, uint256 allocPoint, uint256 totalAllocPoint, uint16 depositFee);
    event ModifyPool(address indexed user, uint256 indexed pid, uint256 allocPoint, uint256 totalAllocPoint, uint16 depositFee);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount, uint256 depositFee);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event RewardPaid(address indexed user, uint256 amount);
    event UpdateFeeCollector(address indexed user, address feeCollector);
    event RecoverUnsupported(address indexed user, address token, uint256 amount, address targetAddress);


    /// Default constructor.
    /// @param _lifeAddress Address of LIFE token.
    /// @param _poolStartTime Emissions start time.
    /// @param _runningTime Running time of emissions (in seconds).
    /// @param _totalRewards Total amount of tokens to be emitted.
    /// @param _feeCollector Address where the deposit fees are transferred.
    constructor(
        address _lifeAddress,
        uint256 _poolStartTime,
        uint256 _runningTime,
        uint256 _totalRewards,
        address _feeCollector
    ) {
        require(block.timestamp < _poolStartTime, "late");
        require(_feeCollector != address(0), "Address cannot be 0");
        require(_runningTime >= 1 days, "Running time has to be at least 1 day");

        if (_lifeAddress != address(0)) life = IERC20(_lifeAddress);

        poolStartTime = _poolStartTime;
        runningTime = _runningTime;
        poolEndTime = poolStartTime + runningTime;

        totalRewards = _totalRewards;
        lifePerSecond = totalRewards / runningTime;

        feeCollector = _feeCollector;
    }

    /// Check if a pool already exists for specified token.
    /// @param _token Address of token to check for existing pools
    function checkPoolDuplicate(IERC20 _token) internal view {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            require(poolInfo[pid].token != _token, "LifeGenesisRewardPool: existing pool?");
        }
    }

    /// Add a new pool.
    /// @param _allocPoint Allocations points assigned to the pool
    /// @param _token Address of token to be staked in the pool
    /// @param _depositFee Deposit fee in % (where 100 == 1%)
    /// @param _withUpdate Whether to trigger update of all existing pools
    /// @param _lastRewardTime Start time of the emissions from the pool
    /// @dev Can only be called by the Operator.
    function add(
        uint256 _allocPoint,
        IERC20 _token,
        uint16 _depositFee,
        bool _withUpdate,
        uint256 _lastRewardTime
    ) public onlyOperator {
        _token.balanceOf(address(this));    // guard to revert calls that try to add non-IERC20 addresses
        require(_depositFee <= 4000, "Deposit fee cannot be higher than 40%");
        checkPoolDuplicate(_token);
        if (_withUpdate) {
            massUpdatePools();
        }
        if (block.timestamp < poolStartTime) {
            // chef is sleeping
            if (_lastRewardTime == 0) {
                _lastRewardTime = poolStartTime;
            } else {
                if (_lastRewardTime < poolStartTime) {
                    _lastRewardTime = poolStartTime;
                }
            }
        } else {
            // chef is cooking
            if (_lastRewardTime == 0 || _lastRewardTime < block.timestamp) {
                _lastRewardTime = block.timestamp;
            }
        }
        bool _isStarted =
        (_lastRewardTime <= poolStartTime) ||
        (_lastRewardTime <= block.timestamp);
        poolInfo.push(PoolInfo({
            token : _token,
            allocPoint : _allocPoint,
            lastRewardTime : _lastRewardTime,
            accLifePerShare : 0,
            depositFee: _depositFee,
            isStarted : _isStarted
            }));
        if (_isStarted) {
            totalAllocPoint = totalAllocPoint + _allocPoint;
        }

        emit AddPool(msg.sender, poolInfo.length - 1, _allocPoint, totalAllocPoint, _depositFee);
    }

    /// Update the given pool's parameters.
    /// @param _pid Id of an existing pool
    /// @param _allocPoint New allocations points assigned to the pool
    /// @param _depositFee New deposit fee assigned to the pool
    /// @dev Can only be called by the Operator.
    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFee) public onlyOperator {
        require(_depositFee <= 4000, "Deposit fee cannot be higher than 40%");
        massUpdatePools();
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.isStarted) {
            totalAllocPoint = (totalAllocPoint - pool.allocPoint) + _allocPoint;
        }
        pool.allocPoint = _allocPoint;
        pool.depositFee = _depositFee;

        emit ModifyPool(msg.sender, _pid, _allocPoint, totalAllocPoint, _depositFee);
    }

    /// Return amount of accumulated rewards over the given time, according to the life per second emission.
    /// @param _fromTime Time from which the generated rewards should be calculated
    /// @param _toTime Time to which the generated rewards should be calculated
    function getGeneratedReward(uint256 _fromTime, uint256 _toTime) public view returns (uint256) {
        if (_fromTime >= _toTime) return 0;
        if (_toTime >= poolEndTime) {
            if (_fromTime >= poolEndTime) return 0;
            if (_fromTime <= poolStartTime) return (poolEndTime - poolStartTime) * lifePerSecond;
            return (poolEndTime - _fromTime) * lifePerSecond;
        } else {
            if (_toTime <= poolStartTime) return 0;
            if (_fromTime <= poolStartTime) return (_toTime - poolStartTime) * lifePerSecond;
            return (_toTime - _fromTime) * lifePerSecond;
        }
    }

    /// Estimate pending rewards for specific user.
    /// @param _pid Id of an existing pool
    /// @param _user Address of a user for which the pending rewards should be calculated
    /// @return Amount of pending rewards for specific user
    /// @dev To be used in UI
    function pendingShare(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accLifePerShare = pool.accLifePerShare;
        uint256 tokenSupply = pool.token.balanceOf(address(this));
        if (block.timestamp > pool.lastRewardTime && tokenSupply != 0) {
            uint256 _generatedReward = getGeneratedReward(pool.lastRewardTime, block.timestamp);
            uint256 _lifeReward = (_generatedReward * pool.allocPoint) / totalAllocPoint;
            accLifePerShare = accLifePerShare + ((_lifeReward * 1e18) / tokenSupply);
        }
        return ((user.amount * accLifePerShare) / 1e18) - user.rewardDebt;
    }

    /// Update reward variables for all pools.
    /// @dev Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    /// Update reward variables of the given pool to be up-to-date.
    /// @param _pid Id of the pool to be updated
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        uint256 tokenSupply = pool.token.balanceOf(address(this));
        if (tokenSupply == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        if (!pool.isStarted) {
            pool.isStarted = true;
            totalAllocPoint = totalAllocPoint + pool.allocPoint;
        }
        if (totalAllocPoint > 0) {
            uint256 _generatedReward = getGeneratedReward(pool.lastRewardTime, block.timestamp);
            uint256 _lifeReward = (_generatedReward * pool.allocPoint) / totalAllocPoint;
            pool.accLifePerShare = pool.accLifePerShare + ((_lifeReward * 1e18) / tokenSupply);
        }
        pool.lastRewardTime = block.timestamp;
    }

    /// Deposit tokens in a pool.
    /// @param _pid Id of the chosen pool
    /// @param _amount Amount of tokens to be staked in the pool
    function deposit(uint256 _pid, uint256 _amount) public {
        address _sender = msg.sender;
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 _pending = ((user.amount * pool.accLifePerShare) / 1e18) - user.rewardDebt;
            if (_pending > 0) {
                safeLifeTransfer(_sender, _pending);
                emit RewardPaid(_sender, _pending);
            }
        }
        if (_amount > 0) {
            if(pool.depositFee > 0) {
                uint256 depositFeeAmount = (_amount * pool.depositFee) / 10000;
                pool.token.safeTransferFrom(_sender, feeCollector, depositFeeAmount);
                pool.token.safeTransferFrom(_sender, address(this), _amount - depositFeeAmount);
                user.amount = user.amount + (_amount - depositFeeAmount);
            } else {
                pool.token.safeTransferFrom(_sender, address(this), _amount);
                user.amount = user.amount + _amount;
            }
        }
        user.rewardDebt = (user.amount * pool.accLifePerShare) / 1e18;
        emit Deposit(_sender, _pid, _amount, pool.depositFee);
    }

    /// Withdraw tokens from a pool.
    /// @param _pid Id of the chosen pool
    /// @param _amount Amount of tokens to be withdrawn from the pool
    function withdraw(uint256 _pid, uint256 _amount) public {
        address _sender = msg.sender;
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 _pending = ((user.amount * pool.accLifePerShare) / 1e18) - user.rewardDebt;
        if (_pending > 0) {
            safeLifeTransfer(_sender, _pending);
            emit RewardPaid(_sender, _pending);
        }
        if (_amount > 0) {
            user.amount = user.amount - _amount;
            pool.token.safeTransfer(_sender, _amount);
        }
        user.rewardDebt = (user.amount * pool.accLifePerShare) / 1e18;
        emit Withdraw(_sender, _pid, _amount);
    }

    /// Withdraw tokens from a pool without rewards. ONLY IN CASE OF EMERGENCY.
    /// @param _pid Id of the chosen pool
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 _amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.token.safeTransfer(msg.sender, _amount);
        emit EmergencyWithdraw(msg.sender, _pid, _amount);
    }

    /// Safe LIFE transfer function.
    /// @param _to Recipient address of the transfer
    /// @param _amount Amount of tokens to be transferred
    /// @dev Used just in case if rounding error causes pool to not have enough LIFE.
    function safeLifeTransfer(address _to, uint256 _amount) internal {
        uint256 _lifeBal = life.balanceOf(address(this));
        if (_lifeBal > 0) {
            if (_amount > _lifeBal) {
                life.safeTransfer(_to, _lifeBal);
            } else {
                life.safeTransfer(_to, _amount);
            }
        }
    }

    /// Set a new deposit fees collector address.
    /// @param _feeCollector A new deposit fee collector address
    /// @dev Can only be called by the Operator
    function setFeeCollector(address _feeCollector) external onlyOperator {
        require(_feeCollector != address(0), "Address cannot be 0");
        feeCollector = _feeCollector;
        emit UpdateFeeCollector(msg.sender, address(_feeCollector));
    }

    /// Transferred tokens sent to the contract by mistake.
    /// @param _token Address of token to be transferred (cannot be staking nor the reward token)
    /// @param _amount Amount of tokens to be transferred
    /// @param _to Recipient address of the transfer
    /// @dev Can only be called by the Operator
    function governanceRecoverUnsupported(IERC20 _token, uint256 _amount, address _to) external onlyOperator {
        if (block.timestamp < poolEndTime + 1 days) {
            // do not allow to drain core token (LIFE or lps) if less than 1 day after pool ends
            require(_token != life, "LIFE");
            uint256 length = poolInfo.length;
            for (uint256 pid = 0; pid < length; ++pid) {
                PoolInfo storage pool = poolInfo[pid];
                require(_token != pool.token, "pool.token");
            }
        }
        _token.safeTransfer(_to, _amount);
        emit RecoverUnsupported(msg.sender, address(_token), _amount, _to);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/draft-IERC20Permit.sol";
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

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
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

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// Additional access control mechanism on top of {Ownable}.
/// @dev Introduces a new - Operator role, in addition to already existing Owner role.
abstract contract Operator is Context, Ownable {
    /// Address of the Operator
    address private _operator;

    /* EVENTS */
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);

    /// Default constructor.
    constructor() {
        _operator = _msgSender();
        emit OperatorTransferred(address(0), _operator);
    }

    /// Returns the current Operator address.
    function operator() public view returns (address) {
        return _operator;
    }

    /// Access control modifier, which only allows Operator to call the annotated function.
    modifier onlyOperator() {
        require(_operator == msg.sender, "operator: caller is not the operator");
        _;
    }

    /// Access control modifier, which only allows Operator or Owner to call the annotated function.
    modifier onlyOwnerOrOperator() {
        require((owner() == msg.sender) || (_operator == msg.sender), "operator: caller is not the owner or the operator");
        _;
    }

    /// Checks if caller is an Operator.
    function isOperator() public view returns (bool) {
        return _msgSender() == _operator;
    }

    /// Checks if called is an Owner or an Operator.
    function isOwnerOrOperator() public view returns (bool) {
        return (_msgSender() == _operator) || (_msgSender() == owner());
    }

    /// Transfers Operator role to a new address.
    /// @param newOperator_ Address to which the Operator role should be transferred.
    function transferOperator(address newOperator_) public onlyOwnerOrOperator {
        _transferOperator(newOperator_);
    }

    /// Transfers Operator role to a new address.
    /// @param newOperator_ Address to which the Operator role should be transferred.
    function _transferOperator(address newOperator_) internal {
        require(newOperator_ != address(0), "operator: zero address given for new operator");
        emit OperatorTransferred(address(0), newOperator_);
        _operator = newOperator_;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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
                /// @solidity memory-safe-assembly
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
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

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
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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