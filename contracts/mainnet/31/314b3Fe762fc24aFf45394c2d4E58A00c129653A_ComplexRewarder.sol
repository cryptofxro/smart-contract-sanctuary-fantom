// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./interfaces/IRewarder.sol";
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

contract ChildRewarder is IRewarder, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public rewardToken;

    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of REWARD entitled to the user.
    struct UserInfo {
        uint amount;
        uint rewardDebt;
    }

    /// @notice Info of each MCV2 pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of REWARD to distribute per block.
    struct PoolInfo {
        uint128 accRewardPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
    }

    /// @notice Info of each pool.
    mapping (uint => PoolInfo) public poolInfo;

    uint[] public poolIds;

    /// @notice Info of each user that stakes LP tokens.
    mapping (uint => mapping (address => UserInfo)) public userInfo;
    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint public totalAllocPoint;

    uint public rewardPerSecond;
    uint public ACC_TOKEN_PRECISION;

    address public MASTERCHEF_V2;

    address public PARENT;

    bool notinit = true;

    event LogOnReward(address indexed user, uint indexed pid, uint amount, address indexed to);
    event LogPoolAddition(uint indexed pid, uint allocPoint);
    event LogSetPool(uint indexed pid, uint allocPoint);
    event LogUpdatePool(uint indexed pid, uint lastRewardTime, uint lpSupply, uint accRewardPerShare);
    event LogRewardPerSecond(uint rewardPerSecond);
    event AdminTokenRecovery(address _tokenAddress, uint _amt, address _adr);
    event LogInit();

    modifier onlyParent {
        require(msg.sender == PARENT, "Only PARENT can call this function.");
        _;
    }

    constructor () {} //use init()

    function init(IERC20Ext _rewardToken, uint _rewardPerSecond, address _MASTERCHEF_V2) external {
        require(notinit);

        uint decimalsRewardToken = _rewardToken.decimals();
        require(decimalsRewardToken < 30, "Token has way too many decimals");
        ACC_TOKEN_PRECISION = 10**(30 - decimalsRewardToken);
        rewardToken = _rewardToken;
        rewardPerSecond = _rewardPerSecond;
        MASTERCHEF_V2 = _MASTERCHEF_V2;
        PARENT = msg.sender;

        notinit = false;
    }


    function onReward (uint _pid, address _user, address _to, uint, uint _amt) onlyParent nonReentrant override external {
        PoolInfo memory pool = updatePool(_pid);
        if(pool.lastRewardTime == 0)
            return;
        UserInfo storage user = userInfo[_pid][_user];
        uint pending;
        if (user.amount > 0) {
            pending = (user.amount * pool.accRewardPerShare / ACC_TOKEN_PRECISION) - user.rewardDebt;
            rewardToken.safeTransfer(_to, pending);
        }
        user.amount = _amt;
        user.rewardDebt = _amt * pool.accRewardPerShare / ACC_TOKEN_PRECISION;
        emit LogOnReward(_user, _pid, pending, _to);
    }

    function pendingTokens(uint pid, address user, uint) override external view returns (IERC20[] memory rewardTokens, uint[] memory rewardAmounts) {
        IERC20[] memory _rewardTokens = new IERC20[](1);
        _rewardTokens[0] = (rewardToken);
        uint[] memory _rewardAmounts = new uint[](1);
        _rewardAmounts[0] = pendingToken(pid, user);
        return (_rewardTokens, _rewardAmounts);
    }

    /// @notice Sets the reward per second to be distributed. Can only be called by the owner.
    /// @param _rewardPerSecond The amount of token to be distributed per second.
    function setRewardPerSecond(uint _rewardPerSecond) public onlyOwner {
        rewardPerSecond = _rewardPerSecond;
        emit LogRewardPerSecond(_rewardPerSecond);
    }


    /// @notice Returns the number of MCV2 pools.
    function poolLength() public view returns (uint pools) {
        pools = poolIds.length;
    }

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param allocPoint AP of the new pool.
    /// @param _pid Pid on MCV2
    function add(uint64 allocPoint, uint _pid, bool _update) public onlyOwner {
        require(poolInfo[_pid].lastRewardTime == 0, "Pool already exists");
        if (_update) {
            massUpdatePools();
        }
        uint64 lastRewardTime = uint64(block.timestamp);
        totalAllocPoint = totalAllocPoint + allocPoint;

        PoolInfo storage poolinfo = poolInfo[_pid];
        poolinfo.allocPoint = allocPoint;
        poolinfo.lastRewardTime = lastRewardTime;
        poolinfo.accRewardPerShare = 0;
        poolIds.push(_pid);
        emit LogPoolAddition(_pid, allocPoint);
    }

    /// @notice Update the given pool's REWARD allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    function set(uint _pid, uint64 _allocPoint, bool _update) public onlyOwner {
        require(poolInfo[_pid].lastRewardTime != 0, "Add pool first");
        if (_update) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        emit LogSetPool(_pid, _allocPoint);
    }

    /// @notice View function to see pending Token
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending REWARD reward for a given user.
    function pendingToken(uint _pid, address _user) public view returns (uint pending) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint accRewardPerShare = pool.accRewardPerShare;
        uint lpSupply = IMasterChefV2(MASTERCHEF_V2).lpSupplies(_pid);

        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint time = block.timestamp - pool.lastRewardTime;
            uint reward = totalAllocPoint == 0 ? 0 : (time * rewardPerSecond * pool.allocPoint / totalAllocPoint);
            accRewardPerShare = accRewardPerShare + (reward * ACC_TOKEN_PRECISION / lpSupply);
        }
        pending = (user.amount * accRewardPerShare / ACC_TOKEN_PRECISION) - user.rewardDebt;
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint len = poolIds.length;
        for (uint i = 0; i < len; ++i) {
            updatePool(poolIds[i]);
        }
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint pid) public returns (PoolInfo memory pool) {
        pool = poolInfo[pid];
        if(pool.lastRewardTime == 0)
            return pool;
        if (block.timestamp > pool.lastRewardTime) {
            uint lpSupply = IMasterChefV2(MASTERCHEF_V2).lpSupplies(pid);

            if (lpSupply > 0) {
                uint time = block.timestamp - pool.lastRewardTime;
                uint reward = totalAllocPoint == 0 ? 0 : (time * rewardPerSecond * pool.allocPoint / totalAllocPoint);
                pool.accRewardPerShare = pool.accRewardPerShare + uint128(reward * ACC_TOKEN_PRECISION / lpSupply);
            }
            pool.lastRewardTime = uint64(block.timestamp);
            poolInfo[pid] = pool;
            emit LogUpdatePool(pid, pool.lastRewardTime, lpSupply, pool.accRewardPerShare);
        }
    }

    function recoverTokens(address _tokenAddress, uint _amt, address _adr) external onlyOwner {
        IERC20(_tokenAddress).safeTransfer(_adr, _amt);

        emit AdminTokenRecovery(_tokenAddress, _amt, _adr);
    }

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IRewarder {
    function onReward(uint256 pid, address user, address recipient, uint256 Booamount, uint256 newLpAmount) external;
    function pendingTokens(uint256 pid, address user, uint256 rewardAmount) external view returns (IERC20[] memory, uint256[] memory);
}

interface IRewarderExt is IRewarder {
    function pendingToken(uint _pid, address _user) external view returns (uint pending);
    function rewardToken() external view returns (IERC20);
}

interface IERC20Ext is IERC20 {
    function decimals() external returns (uint);
}

interface IMasterChefV2 {
    function lpSupplies(uint) external view returns (uint);
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
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
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

pragma solidity 0.8.10;

import "../interfaces/IRewarder.sol";
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../ChildRewarder.sol";

contract ComplexRewarderMock is IRewarder, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    IERC20 public rewardToken;

    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of REWARD entitled to the user.
    struct UserInfo {
        uint amount;
        uint rewardDebt;
    }

    /// @notice Info of each MCV2 pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of REWARD to distribute per block.
    struct PoolInfo {
        uint128 accRewardPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
    }

    /// @notice Info of each pool.
    mapping (uint => PoolInfo) public poolInfo;

    uint[] public poolIds;

    /// @notice Info of each user that stakes LP tokens.
    mapping (uint => mapping (address => UserInfo)) public userInfo;
    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint public totalAllocPoint;

    uint public rewardPerSecond;
    uint public ACC_TOKEN_PRECISION;

    address public immutable MASTERCHEF_V2;

    EnumerableSet.AddressSet private childrenRewarders;

    event LogOnReward(address indexed user, uint indexed pid, uint amount, address indexed to);
    event LogPoolAddition(uint indexed pid, uint allocPoint);
    event LogSetPool(uint indexed pid, uint allocPoint);
    event LogUpdatePool(uint indexed pid, uint lastRewardTime, uint lpSupply, uint accRewardPerShare);
    event LogRewardPerSecond(uint rewardPerSecond);
    event AdminTokenRecovery(address _tokenAddress, uint _amt, address _adr);
    event LogInit();
    event ChildCreated(address indexed child, address indexed token);
    event ChildRemoved(address indexed child);

    modifier onlyMCV2 {
        require(
            msg.sender == MASTERCHEF_V2,
            "Only MCV2 can call this function."
        );
        _;
    }

    constructor(IERC20Ext _rewardToken, uint _rewardPerSecond, address _MASTERCHEF_V2) {
        uint decimalsRewardToken = _rewardToken.decimals();
        require(decimalsRewardToken < 30, "Token has way too many decimals");
        ACC_TOKEN_PRECISION = 10**(30 - decimalsRewardToken);
        rewardToken = _rewardToken;
        MASTERCHEF_V2 = _MASTERCHEF_V2;
        rewardPerSecond = _rewardPerSecond;
    }

    function createChild(IERC20Ext _rewardToken, uint _rewardPerSecond) external onlyOwner {
        ChildRewarder child = new ChildRewarder();
        child.init(_rewardToken, _rewardPerSecond, MASTERCHEF_V2);
        Ownable(address(child)).transferOwnership(msg.sender);
        childrenRewarders.add(address(child));
        emit ChildCreated(address(child), address(_rewardToken));
    }

    function removeChild(address childRewarder) external onlyOwner {
        if(!childrenRewarders.remove(childRewarder))
            revert("That is not my child rewarder!");
        emit ChildRemoved(childRewarder);
    }

    //* WARNING: This operation will copy the entire childrenRewarders storage to memory, which can be quite expensive. This is designed
    //* to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
    //* this function has an unbounded cost, and using it as part of a state-changing function may render the function
    //* uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
    function getChildrenRewarders() external view returns (address[] memory) {
        return childrenRewarders.values();
    }


    function onReward(uint _pid, address _user, address _to, uint, uint _amt) onlyMCV2 nonReentrant override external {
        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = userInfo[_pid][_user];
        uint pending;
        if (user.amount > 0) {
            pending = (user.amount * pool.accRewardPerShare / ACC_TOKEN_PRECISION) - user.rewardDebt;
            rewardToken.safeTransfer(_to, pending);
        }
        user.amount = _amt;
        user.rewardDebt = _amt * pool.accRewardPerShare / ACC_TOKEN_PRECISION;
        emit LogOnReward(_user, _pid, pending, _to);
        uint len = childrenRewarders.length();
        for(uint i = 0; i < len;) {
            IRewarder(childrenRewarders.at(i)).onReward(_pid, _user, _to, 0, _amt);
        unchecked {++i;}
        }
    }

    function pendingTokens(uint pid, address user, uint) override external view returns (IERC20[] memory rewardTokens, uint[] memory rewardAmounts) {
        uint len = childrenRewarders.length() + 1;
        rewardTokens = new IERC20[](len);
        rewardTokens[0] = rewardToken;
        rewardAmounts = new uint[](len);
        rewardAmounts[0] = pendingToken(pid, user);
        for(uint i = 1; i < len;) {
            IRewarderExt rew = IRewarderExt(childrenRewarders.at(i - 1));
            rewardAmounts[i] = rew.pendingToken(pid, user);
            rewardTokens[i] = rew.rewardToken();
        unchecked {++i;}
        }
    }

    /// @notice Sets the reward per second to be distributed. Can only be called by the owner.
    /// @param _rewardPerSecond The amount of token to be distributed per second.
    function setRewardPerSecond(uint _rewardPerSecond) public onlyOwner {
        rewardPerSecond = _rewardPerSecond;
        emit LogRewardPerSecond(_rewardPerSecond);
    }


    /// @notice Returns the number of MCV2 pools.
    function poolLength() public view returns (uint pools) {
        pools = poolIds.length;
    }

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param allocPoint AP of the new pool.
    /// @param _pid Pid on MCV2
    function add(uint64 allocPoint, uint _pid, bool _update) public onlyOwner {
        require(poolInfo[_pid].lastRewardTime == 0, "Pool already exists");
        if (_update) {
            massUpdatePools();
        }
        uint64 lastRewardTime = uint64(block.timestamp);
        totalAllocPoint = totalAllocPoint + allocPoint;

        PoolInfo storage poolinfo = poolInfo[_pid];
        poolinfo.allocPoint = allocPoint;
        poolinfo.lastRewardTime = lastRewardTime;
        poolinfo.accRewardPerShare = 0;
        poolIds.push(_pid);
        emit LogPoolAddition(_pid, allocPoint);
    }

    /// @notice Update the given pool's REWARD allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    function set(uint _pid, uint64 _allocPoint, bool _update) public onlyOwner {
        if (_update) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        emit LogSetPool(_pid, _allocPoint);
    }

    /// @notice View function to see pending Token
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending REWARD reward for a given user.
    function pendingToken(uint _pid, address _user) public view returns (uint pending) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint accRewardPerShare = pool.accRewardPerShare;
        uint lpSupply = IMasterChefV2(MASTERCHEF_V2).lpSupplies(_pid);

        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint time = block.timestamp - pool.lastRewardTime;
            uint reward = totalAllocPoint == 0 ? 0 : (time * rewardPerSecond * pool.allocPoint / totalAllocPoint);
            accRewardPerShare = accRewardPerShare + (reward * ACC_TOKEN_PRECISION / lpSupply);
        }
        pending = (user.amount * accRewardPerShare / ACC_TOKEN_PRECISION) - user.rewardDebt;
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint len = poolIds.length;
        for (uint i = 0; i < len; ++i) {
            updatePool(poolIds[i]);
        }
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint pid) public returns (PoolInfo memory pool) {
        pool = poolInfo[pid];
        if (block.timestamp > pool.lastRewardTime) {
            uint lpSupply = IMasterChefV2(MASTERCHEF_V2).lpSupplies(pid);

            if (lpSupply > 0) {
                uint time = block.timestamp - pool.lastRewardTime;
                uint reward = totalAllocPoint == 0 ? 0 : (time * rewardPerSecond * pool.allocPoint / totalAllocPoint);
                pool.accRewardPerShare = pool.accRewardPerShare + uint128(reward * ACC_TOKEN_PRECISION / lpSupply);
            }
            pool.lastRewardTime = uint64(block.timestamp);
            poolInfo[pid] = pool;
            emit LogUpdatePool(pid, pool.lastRewardTime, lpSupply, pool.accRewardPerShare);
        }
    }

    function recoverTokens(address _tokenAddress, uint _amt, address _adr) external onlyOwner {
        IERC20(_tokenAddress).safeTransfer(_adr, _amt);

        emit AdminTokenRecovery(_tokenAddress, _amt, _adr);
    }

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

// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./interfaces/IRewarder.sol";
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./ChildRewarder.sol";

contract ComplexRewarderParent is IRewarder, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    IERC20 public rewardToken;

    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of REWARD entitled to the user.
    struct UserInfo {
        uint amount;
        uint rewardDebt;
    }

    /// @notice Info of each MCV2 pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of REWARD to distribute per block.
    struct PoolInfo {
        uint128 accRewardPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
    }

    /// @notice Info of each pool.
    mapping (uint => PoolInfo) public poolInfo;

    uint[] public poolIds;

    /// @notice Info of each user that stakes LP tokens.
    mapping (uint => mapping (address => UserInfo)) public userInfo;
    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint public totalAllocPoint;

    uint public rewardPerSecond;
    uint public ACC_TOKEN_PRECISION;

    address public immutable MASTERCHEF_V2 = 0x9C9C920E51778c4ABF727b8Bb223e78132F00aA4;

    EnumerableSet.AddressSet private childrenRewarders;

    event LogOnReward(address indexed user, uint indexed pid, uint amount, address indexed to);
    event LogPoolAddition(uint indexed pid, uint allocPoint);
    event LogSetPool(uint indexed pid, uint allocPoint);
    event LogUpdatePool(uint indexed pid, uint lastRewardTime, uint lpSupply, uint accRewardPerShare);
    event LogRewardPerSecond(uint rewardPerSecond);
    event AdminTokenRecovery(address _tokenAddress, uint _amt, address _adr);
    event LogInit();
    event ChildCreated(address indexed child, address indexed token);
    event ChildRemoved(address indexed child);

    modifier onlyMCV2 {
        require(
            msg.sender == MASTERCHEF_V2,
            "Only MCV2 can call this function."
        );
        _;
    }

    constructor() {}

    function init(IERC20Ext _rewardToken, uint _rewardPerSecond) external onlyOwner {
        require(address(rewardToken) == address(0), "Rewarder already initialised...");
        uint decimalsRewardToken = _rewardToken.decimals();
        require(decimalsRewardToken < 30, "Token has way too many decimals");
        ACC_TOKEN_PRECISION = 10**(30 - decimalsRewardToken);
        rewardToken = _rewardToken;
        rewardPerSecond = _rewardPerSecond;
    }

    function createChild(IERC20Ext _rewardToken, uint _rewardPerSecond) external onlyOwner {
        ChildRewarder child = new ChildRewarder();
        child.init(_rewardToken, _rewardPerSecond, MASTERCHEF_V2);
        Ownable(address(child)).transferOwnership(msg.sender);
        childrenRewarders.add(address(child));
        emit ChildCreated(address(child), address(_rewardToken));
    }

    function removeChild(address childRewarder) external onlyOwner {
        if(!childrenRewarders.remove(childRewarder))
            revert("That is not my child rewarder!");
        emit ChildRemoved(childRewarder);
    }

    //* WARNING: This operation will copy the entire childrenRewarders storage to memory, which can be quite expensive. This is designed
    //* to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
    //* this function has an unbounded cost, and using it as part of a state-changing function may render the function
    //* uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
    function getChildrenRewarders() external view returns (address[] memory) {
        return childrenRewarders.values();
    }


    function onReward(uint _pid, address _user, address _to, uint, uint _amt) onlyMCV2 nonReentrant override external {
        PoolInfo memory pool = updatePool(_pid);
        if(pool.lastRewardTime == 0)
            return;
        UserInfo storage user = userInfo[_pid][_user];
        uint pending;
        if (user.amount > 0) {
            pending = (user.amount * pool.accRewardPerShare / ACC_TOKEN_PRECISION) - user.rewardDebt;
            rewardToken.safeTransfer(_to, pending);
        }
        user.amount = _amt;
        user.rewardDebt = _amt * pool.accRewardPerShare / ACC_TOKEN_PRECISION;
        emit LogOnReward(_user, _pid, pending, _to);
        uint len = childrenRewarders.length();
        for(uint i = 0; i < len;) {
            IRewarder(childrenRewarders.at(i)).onReward(_pid, _user, _to, 0, _amt);
            unchecked {++i;}
        }
    }

    function pendingTokens(uint pid, address user, uint) override external view returns (IERC20[] memory rewardTokens, uint[] memory rewardAmounts) {
        uint len = childrenRewarders.length() + 1;
        rewardTokens = new IERC20[](len);
        rewardTokens[0] = rewardToken;
        rewardAmounts = new uint[](len);
        rewardAmounts[0] = pendingToken(pid, user);
        for(uint i = 1; i < len;) {
            IRewarderExt rew = IRewarderExt(childrenRewarders.at(i - 1));
            rewardAmounts[i] = rew.pendingToken(pid, user);
            rewardTokens[i] = rew.rewardToken();
            unchecked {++i;}
        }
    }

    /// @notice Sets the reward per second to be distributed. Can only be called by the owner.
    /// @param _rewardPerSecond The amount of token to be distributed per second.
    function setRewardPerSecond(uint _rewardPerSecond) public onlyOwner {
        rewardPerSecond = _rewardPerSecond;
        emit LogRewardPerSecond(_rewardPerSecond);
    }


    /// @notice Returns the number of MCV2 pools.
    function poolLength() public view returns (uint pools) {
        pools = poolIds.length;
    }

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param allocPoint AP of the new pool.
    /// @param _pid Pid on MCV2
    function add(uint64 allocPoint, uint _pid, bool _update) public onlyOwner {
        require(poolInfo[_pid].lastRewardTime == 0, "Pool already exists");
        if (_update) {
            massUpdatePools();
        }
        uint64 lastRewardTime = uint64(block.timestamp);
        totalAllocPoint = totalAllocPoint + allocPoint;

        PoolInfo storage poolinfo = poolInfo[_pid];
        poolinfo.allocPoint = allocPoint;
        poolinfo.lastRewardTime = lastRewardTime;
        poolinfo.accRewardPerShare = 0;
        poolIds.push(_pid);
        emit LogPoolAddition(_pid, allocPoint);
    }

    /// @notice Update the given pool's REWARD allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    function set(uint _pid, uint64 _allocPoint, bool _update) public onlyOwner {
        require(poolInfo[_pid].lastRewardTime != 0, "Add pool first");
        if (_update) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        emit LogSetPool(_pid, _allocPoint);
    }

    /// @notice View function to see pending Token
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending REWARD reward for a given user.
    function pendingToken(uint _pid, address _user) public view returns (uint pending) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint accRewardPerShare = pool.accRewardPerShare;
        uint lpSupply = IMasterChefV2(MASTERCHEF_V2).lpSupplies(_pid);

        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint time = block.timestamp - pool.lastRewardTime;
            uint reward = totalAllocPoint == 0 ? 0 : (time * rewardPerSecond * pool.allocPoint / totalAllocPoint);
            accRewardPerShare = accRewardPerShare + (reward * ACC_TOKEN_PRECISION / lpSupply);
        }
        pending = (user.amount * accRewardPerShare / ACC_TOKEN_PRECISION) - user.rewardDebt;
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint len = poolIds.length;
        for (uint i = 0; i < len; ++i) {
            updatePool(poolIds[i]);
        }
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint pid) public returns (PoolInfo memory pool) {
        pool = poolInfo[pid];
        if(pool.lastRewardTime == 0)
            return pool;
        if (block.timestamp > pool.lastRewardTime) {
            uint lpSupply = IMasterChefV2(MASTERCHEF_V2).lpSupplies(pid);

            if (lpSupply > 0) {
                uint time = block.timestamp - pool.lastRewardTime;
                uint reward = totalAllocPoint == 0 ? 0 : (time * rewardPerSecond * pool.allocPoint / totalAllocPoint);
                pool.accRewardPerShare = pool.accRewardPerShare + uint128(reward * ACC_TOKEN_PRECISION / lpSupply);
            }
            pool.lastRewardTime = uint64(block.timestamp);
            poolInfo[pid] = pool;
            emit LogUpdatePool(pid, pool.lastRewardTime, lpSupply, pool.accRewardPerShare);
        }
    }

    function recoverTokens(address _tokenAddress, uint _amt, address _adr) external onlyOwner {
        IERC20(_tokenAddress).safeTransfer(_adr, _amt);

        emit AdminTokenRecovery(_tokenAddress, _amt, _adr);
    }

}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IRewarder.sol";
import "./interfaces/IMasterChef.sol";
import "./utils/SpookyAuth.sol";
import "./utils/Multicall.sol";
import "./utils/SelfPermit.sol";


/// @notice The (older) MasterChef contract gives out a constant number of BOO tokens per second.
/// It is the only address with minting rights for BOO.
/// The idea for this MasterChef V2 (MCV2) contract is therefore to be the owner of a dummy token
/// that is deposited into the MasterChef V1 (MCV1) contract.
/// The allocation point for this pool on MCV1 is the total allocation point for all pools that receive double incentives.
contract MasterChefV2 is SpookyAuth, SelfPermit, Multicall, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeCast for uint;

    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt`
    struct UserInfo {
        uint amount;
        uint rewardDebt;
    }

    /// @notice Info of each MCV2 pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of BOO to distribute per second.
    struct PoolInfo {
        uint128 accBooPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
    }

    /// @notice Address of MCV1 contract.
    IMasterChef public immutable MASTER_CHEF;
    /// @notice Address of BOO contract.
    IERC20 public immutable BOO;
    /// @notice The index of MCV2 master pool in MCV1.
    uint public immutable MASTER_PID;

    /// @notice Info of each MCV2 pool.
    mapping (uint => PoolInfo) public poolInfo;
    /// @notice Address of the LP token for each MCV2 pool.
    mapping (uint => IERC20) public lpToken;
    /// @notice Amount of pool infos and their respective lpToken entries I.E stores last ID + 1, for above two mappings
    uint public poolInfoAmount;
    /// @notice Is an address contained in the above `lpToken` array
    mapping(IERC20 => bool) public isLpToken;
    /// @notice Address of each `IRewarder` contract in MCV2.
    mapping(uint => IRewarder) public rewarder;
    mapping(uint => uint) public lpSupplies;

    /// @notice Info of each user that stakes LP tokens.
    mapping (uint => mapping (address => UserInfo)) public userInfo;
    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint public totalAllocPoint;

    uint private constant ACC_BOO_PRECISION = 1e12;

    /// @dev Last MCV1 harvest timestamp.
    uint public lastV1HarvestTimestamp;
    /// @dev How often v1 harvest should be called by the query function
    uint public V1_HARVEST_QUERY_TIME = 1 days;

    event Deposit(address indexed user, uint indexed pid, uint amount, address indexed to);
    event Withdraw(address indexed user, uint indexed pid, uint amount, address indexed to);
    event EmergencyWithdraw(address indexed user, uint indexed pid, uint amount, address indexed to);
    event Harvest(address indexed user, uint indexed pid, uint amount);
    event LogPoolAddition(uint indexed pid, uint allocPoint, IERC20 indexed lpToken, IRewarder rewarder, bool update);
    event LogSetPool(uint indexed pid, uint allocPoint, IRewarder rewarder, bool overwrite, bool update);
    event LogUpdatePool(uint indexed pid, uint lastRewardTime, uint lpSupply, uint accBooPerShare);
    event LogInit();

    /// @param _MASTER_CHEF The SpookySwap MCV1 contract address.
    /// @param _boo The BOO token contract address.
    /// @param _MASTER_PID The pool ID of the dummy token on the base MCV1 contract.
    constructor(IMasterChef _MASTER_CHEF, IERC20 _boo, uint _MASTER_PID) {
        MASTER_CHEF = _MASTER_CHEF;
        BOO = _boo;
        MASTER_PID = _MASTER_PID;
    }

    /// @notice Deposits a dummy token to `MASTER_CHEF` MCV1. This is required because MCV1 holds the minting rights for BOO.
    /// Any balance of transaction sender in `dummyToken` is transferred.
    /// The allocation point for the pool on MCV1 can be the total allocation point for all pools on mcv2
    /// @param dummyToken The address of the ERC-20 token to deposit into MCV1.
    function init(IERC20 dummyToken) external {
        uint balance = dummyToken.balanceOf(msg.sender);
        require(balance != 0, "MasterChefV2: Balance must exceed 0");
        dummyToken.safeTransferFrom(msg.sender, address(this), balance);
        dummyToken.approve(address(MASTER_CHEF), balance);
        MASTER_CHEF.deposit(MASTER_PID, balance);
        emit LogInit();
    }

    /// @notice Returns the number of MCV2 pools.
    function poolLength() external view returns (uint pools) {
        pools = poolInfoAmount;
    }

    function checkForDuplicate(IERC20 _lpToken) internal view {
        require(!isLpToken[_lpToken], "add: pool already exists!!!!");
    }

    function getFarmData(uint pid) external view returns (PoolInfo memory, uint, IRewarder) {
        return (poolInfo[pid], totalAllocPoint, rewarder[pid]);
    }

    modifier validatePid(uint256 pid) {
        require(pid < poolInfoAmount, "pid doesn't exist...");
        _;
    }

    

    /// @notice View function to see pending BOO on frontend.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending BOO reward for a given user.
    function pendingBOO(uint _pid, address _user) external view validatePid(_pid) returns (uint pending) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint accBooPerShare = pool.accBooPerShare;
        uint lpSupply = lpSupplies[_pid];
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint multiplier = block.timestamp - pool.lastRewardTime;
            uint booReward = totalAllocPoint == 0 ? 0 : ((multiplier * booPerSecond() * pool.allocPoint) / totalAllocPoint);
            accBooPerShare = accBooPerShare + (booReward * ACC_BOO_PRECISION / lpSupply);
        }
        pending = (user.amount * accBooPerShare / ACC_BOO_PRECISION) - user.rewardDebt;
    }

    /// @notice Update reward variables for an array of pools. Be careful of gas spending!
    /// @param pids Pool IDs of all to be updated. Make sure to update all active pools.
    function massUpdatePools(uint256[] calldata pids) external {
        harvestFromMasterChef();
        uint256 len = pids.length;
        for (uint256 i = 0; i < len; ++i) {
            _updatePool(pids[i]);
        }
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    /// @dev This function should never be called from a smart contract as it has an unbounded gas cost.
    function massUpdateAllPools() public {
        harvestFromMasterChef();
        uint len = poolInfoAmount;
        for (uint pid = 0; pid < len; ++pid) {
            _updatePool(pid);
        }
    }

    /// @notice Calculates and returns the `amount` of BOO per second allocated to this contract
    function booPerSecond() public view returns (uint amount) {
        uint totalAlloc = MASTER_CHEF.totalAllocPoint();
        if(totalAlloc > 0)
            amount = MASTER_CHEF.booPerSecond() * MASTER_CHEF.poolInfo(MASTER_PID).allocPoint / totalAlloc;
        else
            amount = 0;
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function _updatePool(uint pid) internal validatePid(pid) returns (PoolInfo memory pool) {
        pool = poolInfo[pid];
        if (block.timestamp > pool.lastRewardTime) {
            uint lpSupply = lpSupplies[pid];
            if (lpSupply > 0) {
                uint multiplier = block.timestamp - pool.lastRewardTime;
                uint booReward = totalAllocPoint == 0 ? 0 : ((multiplier * booPerSecond() * pool.allocPoint) / totalAllocPoint);
                queryHarvestFromMasterChef();
                pool.accBooPerShare = (pool.accBooPerShare + ((booReward * ACC_BOO_PRECISION) / lpSupply)).toUint128();
            }
            pool.lastRewardTime = uint64(block.timestamp);
            poolInfo[pid] = pool;
            emit LogUpdatePool(pid, pool.lastRewardTime, lpSupply, pool.accBooPerShare);
        }
    }

    function updatePool(uint pid) external returns (PoolInfo memory pool) {
        return _updatePool(pid);
    }

    function deposit(uint pid, uint amount, address to) external nonReentrant validatePid(pid) {
        _deposit(pid, amount, to);
    }

    function deposit(uint pid, uint amount) external nonReentrant validatePid(pid) {
        _deposit(pid, amount, msg.sender);
    }


    /// @notice Deposit LP tokens to MCV2 for BOO allocation.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to deposit.
    /// @param to The receiver of `amount` deposit benefit.
    function _deposit(uint pid, uint amount, address to) internal {
        _updatePool(pid);
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][to];

        // Effects
        uint256 _pendingBoo = (user.amount * pool.accBooPerShare / ACC_BOO_PRECISION) - user.rewardDebt;

        user.amount += amount;
        user.rewardDebt = user.amount * pool.accBooPerShare / ACC_BOO_PRECISION;

        // Interactions
        if (_pendingBoo != 0) {
            BOO.safeTransfer(to, _pendingBoo);
        }

        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onReward(pid, to, to, _pendingBoo, user.amount);
        }

        if(amount > 0) {
            lpToken[pid].safeTransferFrom(msg.sender, address(this), amount);
            lpSupplies[pid] += amount;
        }

        emit Deposit(msg.sender, pid, amount, to);
        emit Harvest(msg.sender, pid, _pendingBoo);
    }

    function withdraw(uint pid, uint amount, address to) external nonReentrant validatePid(pid) {
        _withdraw(pid, amount, to);
    }

    function withdraw(uint pid, uint amount) external nonReentrant validatePid(pid) {
        _withdraw(pid, amount, msg.sender);
    }

    /// @notice Withdraw LP tokens from MCV2 and harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param to Receiver of the LP tokens and BOO rewards.
    function _withdraw(uint pid, uint amount, address to) internal {
        _updatePool(pid);
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];

        require(user.amount >= amount, "withdraw: not good");

        // Effects
        uint256 _pendingBoo = (user.amount * pool.accBooPerShare / ACC_BOO_PRECISION) - user.rewardDebt;

        user.amount -= amount;
        user.rewardDebt = user.amount * pool.accBooPerShare / ACC_BOO_PRECISION;

        // Interactions
        if (_pendingBoo != 0) {
            BOO.safeTransfer(to, _pendingBoo);
        }

        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onReward(pid, msg.sender, to, _pendingBoo, user.amount);
        }

        if(amount > 0) {
            lpToken[pid].safeTransfer(to, amount);
            lpSupplies[pid] -= amount;
        }

        emit Withdraw(msg.sender, pid, amount, to);
        emit Harvest(msg.sender, pid, _pendingBoo);
    }

    /// @notice Batch harvest all rewards from all staked pools
    /// @dev This function has an unbounded gas cost. Take care not to call it from other smart contracts if you don't know what you're doing.
    function harvestAll() external nonReentrant {
        uint256 length = poolInfoAmount;
        uint calc;
        uint pending;
        UserInfo storage user;
        PoolInfo memory pool;
        uint totalPending;
        for (uint256 pid = 0; pid < length; ++pid) {
            user = userInfo[pid][msg.sender];
            if (user.amount > 0) {
                pool = _updatePool(pid);

                calc = user.amount * pool.accBooPerShare / ACC_BOO_PRECISION;
                pending = calc - user.rewardDebt;
                user.rewardDebt = calc;

                if(pending > 0) {
                    totalPending+=pending;
                }

                IRewarder _rewarder = rewarder[pid];
                if (address(_rewarder) != address(0)) {
                    _rewarder.onReward(pid, msg.sender, msg.sender, pending, user.amount);
                }
            }
        }
        if (totalPending > 0) {
            BOO.safeTransfer(msg.sender, totalPending);
        }
    }

    /// @notice Batch harvest rewards from specified staked pools
    /// @param pids[] The array of pids of the pools you wish to harvest. See `poolInfo`.
    function harvestMultiple(uint[] calldata pids) external nonReentrant {
        uint256 length = pids.length;
        uint calc;
        uint pending;
        UserInfo storage user;
        PoolInfo memory pool;
        uint totalPending;
        uint pid;
        for (uint256 i = 0; i < length; ++i) {
            pid = pids[i];
            user = userInfo[pid][msg.sender];
            if (user.amount > 0) {
                pool = _updatePool(pid);

                calc = user.amount * pool.accBooPerShare / ACC_BOO_PRECISION;
                pending = calc - user.rewardDebt;
                user.rewardDebt = calc;

                if(pending > 0) {
                    totalPending+=pending;
                }

                IRewarder _rewarder = rewarder[pid];
                if (address(_rewarder) != address(0)) {
                    _rewarder.onReward(pid, msg.sender, msg.sender, pending, user.amount);
                }
            }

        }
        if (totalPending > 0) {
            BOO.safeTransfer(msg.sender, totalPending);
        }
    }

    /// @notice Harvests BOO from `MASTER_CHEF` MCV1 and pool `MASTER_PID` to this MCV2 contract.
    function harvestFromMasterChef() public {
        lastV1HarvestTimestamp = block.timestamp;
        MASTER_CHEF.deposit(MASTER_PID, 0);
    }

    /// @notice calls harvestFromMasterChef() if its been more than `V1_HARVEST_QUERY_TIME` since last v1 harvest
    function queryHarvestFromMasterChef() public {
        if(block.timestamp - lastV1HarvestTimestamp > V1_HARVEST_QUERY_TIME)
            harvestFromMasterChef();
    }

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of the LP tokens.
    function _emergencyWithdraw(uint pid, address to) internal validatePid(pid) {
        UserInfo storage user = userInfo[pid][msg.sender];
        uint amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onReward(pid, msg.sender, to, 0, 0);
        }

        // Note: transfer can fail or succeed if `amount` is zero.
        lpToken[pid].safeTransfer(to, amount);
        lpSupplies[pid] -= amount;
        emit EmergencyWithdraw(msg.sender, pid, amount, to);
    }

    function emergencyWithdraw(uint pid, address to) external nonReentrant {
        _emergencyWithdraw(pid, to);
    }

    function emergencyWithdraw(uint pid) external nonReentrant {
        _emergencyWithdraw(pid, msg.sender);
    }


    // ADMIN FUNCTIONS

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// @param allocPoint AP of the new pool.
    /// @param _lpToken Address of the LP ERC-20 token.
    /// @param _rewarder Addresses of the rewarder delegate(s).
    function add(uint64 allocPoint, IERC20 _lpToken, IRewarder _rewarder, bool update) external onlyAuth {
        checkForDuplicate(_lpToken);
        
        if (update) {
            massUpdateAllPools();
        }

        uint pid = poolInfoAmount;
        uint64 lastRewardTime = uint64(block.timestamp);
        totalAllocPoint = totalAllocPoint + allocPoint;
        lpToken[pid] = _lpToken;
        isLpToken[_lpToken] = true;
        rewarder[pid] = _rewarder;

        PoolInfo storage poolinfo = poolInfo[pid];
        poolinfo.allocPoint = allocPoint;
        poolinfo.lastRewardTime = lastRewardTime;
        poolinfo.accBooPerShare = 0;

        poolInfoAmount = poolInfoAmount + 1;

        emit LogPoolAddition(pid, allocPoint, _lpToken, _rewarder, update);
    }

    /// @notice Update the given pool's BOO allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    /// @param _rewarder Addresses of the rewarder delegates.
    /// @param overwrite True if _rewarders should be `set`. Otherwise `_rewarders` is ignored.
    function set(uint _pid, uint64 _allocPoint, IRewarder _rewarder, bool overwrite, bool update) external onlyAuth {
        _set(_pid, _allocPoint, _rewarder, overwrite, update);
    }

    /// @notice Batch update the given pool's BOO allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    /// @param _rewarders Addresses of the rewarder delegates.
    /// @param overwrite True if _rewarders should be `set`. Otherwise `_rewarders` is ignored.
    function setBatch(uint[] calldata _pid, uint64[] calldata _allocPoint, IRewarder[] calldata _rewarders, bool[] calldata overwrite, bool update) external onlyAuth {
        require(_pid.length == _allocPoint.length && _allocPoint.length == _rewarders.length && _rewarders.length == overwrite.length, "MCV2: all arrays need to be the same length");

        if(update)
            massUpdateAllPools();

        uint len = _pid.length;
        for(uint i = 0; i < len; i++)
            _set(_pid[i], _allocPoint[i], _rewarders[i], overwrite[i], false);
    }

    function setBatchSlim(uint[] calldata _pid, uint64[] calldata _allocPoint, bool update) external onlyAuth {
        if(update)
            massUpdateAllPools();

        uint len = _pid.length;
        for(uint i = 0; i < len; i++)
            _set(_pid[i], _allocPoint[i], IRewarder(address(0)), false, false);
    }



    function _set(uint _pid, uint64 _allocPoint, IRewarder _rewarder, bool overwrite, bool update) internal validatePid(_pid) {
        if (update) {
            massUpdateAllPools();
        }

        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (overwrite) rewarder[_pid] = _rewarder;

        emit LogSetPool(_pid, _allocPoint, overwrite ? _rewarder : rewarder[_pid], overwrite, update);
    }

    function setV1HarvestQueryTime(uint256 newTime, bool inDays) external onlyAuth {
        V1_HARVEST_QUERY_TIME = newTime * (inDays ? 1 days : 1);
    }


}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/math/SafeCast.sol)

pragma solidity ^0.8.0;

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCast {
    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(value <= type(uint224).max, "SafeCast: value doesn't fit in 224 bits");
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value <= type(uint96).max, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value <= type(uint64).max, "SafeCast: value doesn't fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value <= type(uint16).max, "SafeCast: value doesn't fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "SafeCast: value doesn't fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128) {
        require(value >= type(int128).min && value <= type(int128).max, "SafeCast: value doesn't fit in 128 bits");
        return int128(value);
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64) {
        require(value >= type(int64).min && value <= type(int64).max, "SafeCast: value doesn't fit in 64 bits");
        return int64(value);
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32) {
        require(value >= type(int32).min && value <= type(int32).max, "SafeCast: value doesn't fit in 32 bits");
        return int32(value);
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16) {
        require(value >= type(int16).min && value <= type(int16).max, "SafeCast: value doesn't fit in 16 bits");
        return int16(value);
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8) {
        require(value >= type(int8).min && value <= type(int8).max, "SafeCast: value doesn't fit in 8 bits");
        return int8(value);
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IMasterChef {
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. BOO to distribute per second.
        uint256 lastRewardBlock;  // Last block number that SUSHI distribution occurs.
        uint256 accBooPerShare; // Accumulated BOO per share, times 1e12. See below.
    }

    function poolInfo(uint256 pid) external view returns (IMasterChef.PoolInfo memory);
    function totalAllocPoint() external view returns (uint256);
    function booPerSecond() external view returns (uint256);
    function deposit(uint256 _pid, uint256 _amount) external;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

interface IOwnable {
    function transferOwnership(address newOwner) external;
}

abstract contract SpookyAuth {
    // set of addresses that can perform certain functions
    mapping(address => bool) public isAuth;
    address[] public authorized;
    address public admin;

    modifier onlyAuth() {
        require(isAuth[msg.sender] || msg.sender == admin, "SpookySwap: FORBIDDEN (auth)");
        _;
    }

    modifier onlyOwner() { //Ownable compatibility
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

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.0;

/// @notice Helper utility that enables calling multiple local methods in a single call.
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/Multicall.sol)
/// License-Identifier: GPL-2.0-or-later
abstract contract Multicall {
    function multicall(bytes[] calldata data) public payable returns (bytes[] memory results) {
        results = new bytes[](data.length);

        for (uint256 i; i < data.length;) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }

            results[i] = result;

            // cannot realistically overflow on human timescales
        unchecked {
            ++i;
        }
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

interface IERC20PermitAllowed {
    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

abstract contract SelfPermit {
    function selfPermit(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable {
        IERC20Permit(token).permit(msg.sender, address(this), value, deadline, v, r, s);
    }

    function selfPermitIfNecessary(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        if (IERC20(token).allowance(msg.sender, address(this)) < value) selfPermit(token, value, deadline, v, r, s);
    }

    function selfPermitAllowed(

        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable {
        IERC20PermitAllowed(token).permit(msg.sender, address(this), nonce, expiry, true, v, r, s);
    }

    function selfPermitAllowedIfNecessary(
        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        if (IERC20(token).allowance(msg.sender, address(this)) < type(uint256).max)
            selfPermitAllowed(token, nonce, expiry, v, r, s);
    }

    function supportsPermits(address token) external view returns (bytes32 domainSeparator) {
        try IERC20Permit(token).DOMAIN_SEPARATOR() returns (bytes32 separator) {
            return separator;
        } catch {
            return bytes32(0);
        }
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

pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) ERC20(name, symbol) {
        _mint(msg.sender, supply);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./interfaces/IRewarder.sol";
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

contract ComplexRewarder is IRewarder, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable rewardToken;

    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of REWARD entitled to the user.
    struct UserInfo {
        uint amount;
        uint rewardDebt;
    }

    /// @notice Info of each MCV2 pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of REWARD to distribute per block.
    struct PoolInfo {
        uint128 accRewardPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
    }

    /// @notice Info of each pool.
    mapping (uint => PoolInfo) public poolInfo;

    uint[] public poolIds;

    /// @notice Info of each user that stakes LP tokens.
    mapping (uint => mapping (address => UserInfo)) public userInfo;
    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint public totalAllocPoint;

    uint public rewardPerSecond;
    uint public immutable ACC_TOKEN_PRECISION;

    address public immutable MASTERCHEF_V2;

    event LogOnReward(address indexed user, uint indexed pid, uint amount, address indexed to);
    event LogPoolAddition(uint indexed pid, uint allocPoint);
    event LogSetPool(uint indexed pid, uint allocPoint);
    event LogUpdatePool(uint indexed pid, uint lastRewardTime, uint lpSupply, uint accRewardPerShare);
    event LogRewardPerSecond(uint rewardPerSecond);
    event AdminTokenRecovery(address _tokenAddress, uint _amt, address _adr);
    event LogInit();

    modifier onlyMCV2 {
        require(
            msg.sender == MASTERCHEF_V2,
            "Only MCV2 can call this function."
        );
        _;
    }

    constructor (IERC20Ext _rewardToken, address _MASTERCHEF_V2) {
        uint decimalsRewardToken = _rewardToken.decimals();
        require(decimalsRewardToken < 30, "Token has way too many decimals");
        ACC_TOKEN_PRECISION = 10**(30 - decimalsRewardToken);
        rewardToken = _rewardToken;
        MASTERCHEF_V2 = _MASTERCHEF_V2;
    }


    function onReward(uint _pid, address _user, address _to, uint, uint _amt) onlyMCV2 nonReentrant override external {
        PoolInfo memory pool = updatePool(_pid);
        if(pool.lastRewardTime == 0)
            return;
        UserInfo storage user = userInfo[_pid][_user];
        uint pending;
        if (user.amount > 0) {
            pending = (user.amount * pool.accRewardPerShare / ACC_TOKEN_PRECISION) - user.rewardDebt;
            rewardToken.safeTransfer(_to, pending);
        }
        user.amount = _amt;
        user.rewardDebt = _amt * pool.accRewardPerShare / ACC_TOKEN_PRECISION;
        emit LogOnReward(_user, _pid, pending, _to);
    }

    function pendingTokens(uint pid, address user, uint) override external view returns (IERC20[] memory rewardTokens, uint[] memory rewardAmounts) {
        IERC20[] memory _rewardTokens = new IERC20[](1);
        _rewardTokens[0] = (rewardToken);
        uint[] memory _rewardAmounts = new uint[](1);
        _rewardAmounts[0] = pendingToken(pid, user);
        return (_rewardTokens, _rewardAmounts);
    }

    /// @notice Sets the reward per second to be distributed. Can only be called by the owner.
    /// @param _rewardPerSecond The amount of token to be distributed per second.
    function setRewardPerSecond(uint _rewardPerSecond) public onlyOwner {
        rewardPerSecond = _rewardPerSecond;
        emit LogRewardPerSecond(_rewardPerSecond);
    }


    /// @notice Returns the number of MCV2 pools.
    function poolLength() public view returns (uint pools) {
        pools = poolIds.length;
    }

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param allocPoint AP of the new pool.
    /// @param _pid Pid on MCV2
    function add(uint64 allocPoint, uint _pid, bool _update) public onlyOwner {
        require(poolInfo[_pid].lastRewardTime == 0, "Pool already exists");
        if (_update) {
            massUpdatePools();
        }
        uint64 lastRewardTime = uint64(block.timestamp);
        totalAllocPoint = totalAllocPoint + allocPoint;

        PoolInfo storage poolinfo = poolInfo[_pid];
        poolinfo.allocPoint = allocPoint;
        poolinfo.lastRewardTime = lastRewardTime;
        poolinfo.accRewardPerShare = 0;
        poolIds.push(_pid);
        emit LogPoolAddition(_pid, allocPoint);
    }

    /// @notice Update the given pool's REWARD allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    function set(uint _pid, uint64 _allocPoint, bool _update) public onlyOwner {
        require(poolInfo[_pid].lastRewardTime != 0, "Add pool first");
        if (_update) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        emit LogSetPool(_pid, _allocPoint);
    }

    /// @notice View function to see pending Token
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending REWARD reward for a given user.
    function pendingToken(uint _pid, address _user) public view returns (uint pending) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint accRewardPerShare = pool.accRewardPerShare;
        uint lpSupply = IMasterChefV2(MASTERCHEF_V2).lpSupplies(_pid);

        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint time = block.timestamp - pool.lastRewardTime;
            uint reward = totalAllocPoint == 0 ? 0 : (time * rewardPerSecond * pool.allocPoint / totalAllocPoint);
            accRewardPerShare = accRewardPerShare + (reward * ACC_TOKEN_PRECISION / lpSupply);
        }
        pending = (user.amount * accRewardPerShare / ACC_TOKEN_PRECISION) - user.rewardDebt;
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint len = poolIds.length;
        for (uint i = 0; i < len; ++i) {
            updatePool(poolIds[i]);
        }
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint pid) public returns (PoolInfo memory pool) {
        pool = poolInfo[pid];
        if(pool.lastRewardTime == 0)
            return pool;
        if (block.timestamp > pool.lastRewardTime) {
            uint lpSupply = IMasterChefV2(MASTERCHEF_V2).lpSupplies(pid);

            if (lpSupply > 0) {
                uint time = block.timestamp - pool.lastRewardTime;
                uint reward = totalAllocPoint == 0 ? 0 : (time * rewardPerSecond * pool.allocPoint / totalAllocPoint);
                pool.accRewardPerShare = pool.accRewardPerShare + uint128(reward * ACC_TOKEN_PRECISION / lpSupply);
            }
            pool.lastRewardTime = uint64(block.timestamp);
            poolInfo[pid] = pool;
            emit LogUpdatePool(pid, pool.lastRewardTime, lpSupply, pool.accRewardPerShare);
        }
    }

    function recoverTokens(address _tokenAddress, uint _amt, address _adr) external onlyOwner {
        IERC20(_tokenAddress).safeTransfer(_adr, _amt);

        emit AdminTokenRecovery(_tokenAddress, _amt, _adr);
    }

}