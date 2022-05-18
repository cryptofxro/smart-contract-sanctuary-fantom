/**
 *Submitted for verification at FtmScan.com on 2022-05-18
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}




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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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


/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}


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
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
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
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}


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

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
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


interface IStrategy {
    // Total want tokens managed by strategy
    function wantLockedTotal() external view returns (uint256);

    // Sum of all shares of users to wantLockedTotal
    function sharesTotal() external view returns (uint256);

    function wantAddress() external view returns (address);

    function token0Address() external view returns (address);

    function token1Address() external view returns (address);

    function earnedAddress() external view returns (address);

    function getPricePerFullShare() external view returns (uint256);

    // Main want token compounding function
    function earn() external;

    // Transfer want tokens autoFarm -> strategy
    function deposit(address _userAddress, uint256 _wantAmt) external returns (uint256);

    // Transfer want tokens strategy -> autoFarm
    function withdraw(address _userAddress, uint256 _wantAmt) external returns (uint256);

    function inCaseTokensGetStuck(address _token, uint256 _amount) external;

    function inFarmBalance() external view returns (uint256);

    function totalBalance() external view returns (uint256);
}


contract DarkBank is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // governance
    address public operator; // should be an at least 6h timelock

    // flags
    bool public initialized = false;

    // Info of each user.
    struct UserInfo {
        uint256 shares; // How many LP tokens the user has provided.
        mapping(uint256 => uint256) rewardDebt; // Reward debt. See explanation below.
        uint256 lastStakeTime;
        uint256 recentBalance;
        uint256 totalDeposit;
        uint256 totalWithdraw;
    }

    struct PoolInfo {
        IERC20 want; // Address of the want token.
        uint256 allocPoint; // How many allocation points assigned to this pool.
        uint256 lastRewardTime; // Last block number that reward distribution occurs.
        mapping(uint256 => uint256) accRewardPerShare; // Accumulated rewardPool per share, times 1e18.
        address strategy; // Strategy address that will auto compound want tokens
        uint256 earlyWithdrawFee; // 10000
        uint256 earlyWithdrawTime; // 10000
    }

    // Info of each rewardPool funding.
    struct RewardPoolInfo {
        address rewardToken; // Address of rewardPool token contract.
        uint256 rewardPerSecond; // Reward token amount to distribute per block.
        uint256 totalPaidRewards;
    }

    uint256 public startTime = 1635417737;

    PoolInfo[] public poolInfo; // Info of each pool.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo; // Info of each user that stakes LP tokens.
    RewardPoolInfo[] public rewardPoolInfo;
    uint256 public totalAllocPoint = 0; // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public unstakingFrozenTime = 72 hours;
    uint256 public earlyWithdrawFee = 50; // 0.5%

    address public timelock = address(0x0000000000000000000000000000000000000000); // 6h timelock

    /* =================== Added variables (need to keep orders for proxy to work) =================== */
    mapping(address => bool) public whitelistedContract;
    mapping(address => bool) public whitelisted;
    mapping(uint256 => bool) public stopRewardPool;
    mapping(uint256 => bool) public pausePool;

    /* ========== EVENTS ========== */

    event Initialized(address indexed executor, uint256 at);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event RewardPaid(uint256 indexed rewardPid, address indexed token, address indexed user, uint256 amount);

    function initialize() public notInitialized {
        initialized = true;
        operator = msg.sender;
        emit Initialized(msg.sender, block.timestamp);
    }

    modifier onlyOperator() {
        require(operator == msg.sender, "DarkBank: caller is not the operator");
        _;
    }

    modifier onlyTimelock() {
        require(timelock == msg.sender, "DarkBank: caller is not timelock");
        _;
    }

    modifier notInitialized() {
        require(!initialized, "DarkBank: already initialized");
        _;
    }

    modifier notContract() {
        if (!whitelistedContract[msg.sender]) {
            uint256 size;
            address addr = msg.sender;
            assembly {
                size := extcodesize(addr)
            }
            require(size == 0, "contract not allowed");
            require(tx.origin == msg.sender, "contract not allowed");
        }
        _;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function addVault(uint256 _allocPoint, IERC20 _want, bool _withUpdate, address _strategy, uint256 _earlyWithdrawFee, uint256 _earlyWithdrawTime) public onlyOperator {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 _lastRewardTime = block.timestamp > startTime ? block.timestamp : startTime;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
        want: _want,
        allocPoint: _allocPoint,
        lastRewardTime: _lastRewardTime,
        strategy : _strategy,
        earlyWithdrawFee: _earlyWithdrawFee,
        earlyWithdrawTime: _earlyWithdrawTime
        }));
    }

    // Update the given pool's reward allocation point. Can only be called by the owner.
    function setAllocPoint(uint256 _pid, uint256 _allocPoint) public onlyOperator {
        massUpdatePools();
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function setEarlyWithdrawFee(uint256 _pid, uint256 _earlyWithdrawFee) public onlyOperator {
        poolInfo[_pid].earlyWithdrawFee = _earlyWithdrawFee;
    }

    function setEarlyWithdrawTime(uint256 _pid, uint256 _earlyWithdrawTime) public onlyOperator {
        poolInfo[_pid].earlyWithdrawTime = _earlyWithdrawTime;
    }

    function rewardPoolLength() external view returns (uint256) {
        return rewardPoolInfo.length;
    }

    function addRewardPool(address _rewardToken, uint256 _rewardPerSecond) public nonReentrant onlyOperator {
        require(rewardPoolInfo.length <= 16, "DarkBank: Reward pool length > 16");
        massUpdatePools();
        rewardPoolInfo.push(RewardPoolInfo({
        rewardToken : _rewardToken,
        rewardPerSecond : _rewardPerSecond,
        totalPaidRewards : 0
        }));
    }

    function updateRewardToken(uint256 _rewardPid, address _rewardToken, uint256 _rewardPerSecond) external nonReentrant onlyOperator {
        RewardPoolInfo storage rewardPool = rewardPoolInfo[_rewardPid];
        require(rewardPool.rewardPerSecond == 0, "old pool still running");
        massUpdatePools();
        rewardPool.rewardToken = _rewardToken;
        rewardPool.rewardPerSecond = _rewardPerSecond;
        rewardPool.totalPaidRewards = 0;
    }

    function updateRewardPerSecond(uint256 _rewardPid, uint256 _rewardPerSecond) external nonReentrant onlyOperator {
        massUpdatePools();
        RewardPoolInfo storage rewardPool = rewardPoolInfo[_rewardPid];
        rewardPool.rewardPerSecond = _rewardPerSecond;
    }

    function setUnstakingFrozenTime(uint256 _unstakingFrozenTime) external nonReentrant onlyOperator {
        require(_unstakingFrozenTime <= 7 days, "DarkBank: !safe - dont lock for too long");
        unstakingFrozenTime = _unstakingFrozenTime;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from);
    }

    // View function to see pending reward on frontend.
    function pendingReward(uint256 _pid, uint256 _rewardPid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 _accRewardPerShare = pool.accRewardPerShare[_rewardPid];
        uint256 sharesTotal = IStrategy(pool.strategy).sharesTotal();
        if (block.timestamp > pool.lastRewardTime && sharesTotal != 0) {
            uint256 _multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
            uint256 _rewardPerSecond = rewardPoolInfo[_rewardPid].rewardPerSecond;
            uint256 _reward = _multiplier.mul(_rewardPerSecond).mul(pool.allocPoint).div(totalAllocPoint);
            _accRewardPerShare = _accRewardPerShare.add(_reward.mul(1e18).div(sharesTotal));
        }
        return user.shares.mul(_accRewardPerShare).div(1e18).sub(user.rewardDebt[_rewardPid]);
    }

    // View function to see staked Want tokens on frontend.
    function stakedWantTokens(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 sharesTotal = IStrategy(pool.strategy).sharesTotal();
        uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strategy).wantLockedTotal();
        if (sharesTotal == 0) {
            return 0;
        }
        return user.shares.mul(wantLockedTotal).div(sharesTotal);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (address(pool.want) == address(0)) {
            return;
        }
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        uint256 sharesTotal = IStrategy(pool.strategy).sharesTotal();
        if (sharesTotal == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
        if (multiplier <= 0) {
            return;
        }
        uint256 _rewardPoolLength = rewardPoolInfo.length;
        for (uint256 _rewardPid = 0; _rewardPid < _rewardPoolLength; ++_rewardPid) {
            uint256 _rewardPerSecond = rewardPoolInfo[_rewardPid].rewardPerSecond;
            uint256 _reward = multiplier.mul(_rewardPerSecond).mul(pool.allocPoint).div(totalAllocPoint);
            pool.accRewardPerShare[_rewardPid] = pool.accRewardPerShare[_rewardPid].add(_reward.mul(1e18).div(sharesTotal));
            pool.lastRewardTime = block.timestamp;
        }
    }

    function _getReward(uint256 _pid) internal {
        PoolInfo storage _pool = poolInfo[_pid];
        UserInfo storage _user = userInfo[_pid][msg.sender];
        uint256 _rewardPoolLength = rewardPoolInfo.length;
        for (uint256 _rewardPid = 0; _rewardPid < _rewardPoolLength; ++_rewardPid) {
            if (!stopRewardPool[_rewardPid]) {
                uint256 _pending = _user.shares.mul(_pool.accRewardPerShare[_rewardPid]).div(1e18).sub(_user.rewardDebt[_rewardPid]);
                if (_pending > 0) {
                    RewardPoolInfo storage rewardPool = rewardPoolInfo[_rewardPid];
                    address _rewardToken = rewardPool.rewardToken;
                    safeRewardTransfer(_rewardToken, msg.sender, _pending);
                    rewardPool.totalPaidRewards = rewardPool.totalPaidRewards.add(_pending);
                    emit RewardPaid(_rewardPid, _rewardToken, msg.sender, _pending);
                }
            }
        }
    }

    function _checkStrategyBalanceAfterDeposit(address _strategy, uint256 _depositAmount, uint256 _oldInFarmBalance, uint256 _oldTotalBalance) internal view {
        require(_oldInFarmBalance + _depositAmount <= IStrategy(_strategy).inFarmBalance(), "Short of strategy infarm balance: need audit!");
        require(_oldTotalBalance + _depositAmount <= IStrategy(_strategy).totalBalance(), "Short of strategy total balance: need audit!");
    }

    function _checkStrategyBalanceAfterWithdraw(address _strategy, uint256 _withdrawAmount, uint256 _oldInFarmBalance, uint256 _oldTotalBalance) internal view {
        require(_oldInFarmBalance <= _withdrawAmount + IStrategy(_strategy).inFarmBalance(), "Short of strategy infarm balance: need audit!");
        require(_oldTotalBalance <= _withdrawAmount + IStrategy(_strategy).totalBalance(), "Short of strategy total balance: need audit!");
    }

    function deposit(uint256 _pid, uint256 _wantAmt) public nonReentrant notContract {
        require(!pausePool[_pid], "paused");
        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if (user.shares > 0) {
            _getReward(_pid);
        }
        if (_wantAmt > 0) {
            IERC20 _want = pool.want;
            address _strategy = pool.strategy;
            uint256 _before = _want.balanceOf(address(this));
            _want.safeTransferFrom(address(msg.sender), address(this), _wantAmt);
            uint256 _after = _want.balanceOf(address(this));
            _wantAmt = _after - _before; // fix issue of deflation token
            _want.safeIncreaseAllowance(_strategy, _wantAmt);

            uint256 sharesAdded;
            {
                uint256 _oldInFarmBalance = IStrategy(_strategy).inFarmBalance();
                uint256 _oldTotalBalance = IStrategy(_strategy).totalBalance();
                sharesAdded = IStrategy(_strategy).deposit(msg.sender, _wantAmt);
                _checkStrategyBalanceAfterDeposit(_strategy, _wantAmt, _oldInFarmBalance, _oldTotalBalance);
            }

            user.shares = user.shares.add(sharesAdded);
            user.totalDeposit = user.totalDeposit.add(_wantAmt);
            uint256 wantLockedTotal = IStrategy(_strategy).wantLockedTotal();
            uint256 sharesTotal = IStrategy(_strategy).sharesTotal();
            user.recentBalance = user.shares.mul(wantLockedTotal).div(sharesTotal);
            user.lastStakeTime = block.timestamp;
        }
        uint256 _rewardPoolLength = rewardPoolInfo.length;
        for (uint256 _rewardPid = 0; _rewardPid < _rewardPoolLength; ++_rewardPid) {
            user.rewardDebt[_rewardPid] = user.shares.mul(pool.accRewardPerShare[_rewardPid]).div(1e18);
        }
        emit Deposit(msg.sender, _pid, _wantAmt);
    }

    function unfrozenStakeTime(uint256 _pid, address _account) public view returns (uint256) {
        return (whitelisted[_account]) ? userInfo[_pid][_account].lastStakeTime : userInfo[_pid][_account].lastStakeTime + unstakingFrozenTime;
    }

    function earlyWithdrawTimeEnd(uint256 _pid, address _account) public view returns (uint256) {
        return (whitelisted[_account]) ? userInfo[_pid][_account].lastStakeTime : userInfo[_pid][_account].lastStakeTime + poolInfo[_pid].earlyWithdrawTime;
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _wantAmt) public nonReentrant notContract {
        require(!pausePool[_pid], "paused");
        updatePool(_pid);

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strategy).wantLockedTotal();
        uint256 sharesTotal = IStrategy(poolInfo[_pid].strategy).sharesTotal();
        address _strategy = pool.strategy;

        require(user.shares > 0, "DarkBank: user.shares is 0");
        require(sharesTotal > 0, "DarkBank: sharesTotal is 0");

        _getReward(_pid);

        // Withdraw want tokens
        uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);
        if (_wantAmt > amount) {
            _wantAmt = amount;
        }
        if (_wantAmt > 0) {
            uint256 sharesRemoved;
            {
                uint256 _oldInFarmBalance = IStrategy(_strategy).inFarmBalance();
                uint256 _oldTotalBalance = IStrategy(_strategy).totalBalance();
                sharesRemoved = IStrategy(_strategy).withdraw(msg.sender, _wantAmt);
                _checkStrategyBalanceAfterWithdraw(_strategy, _wantAmt, _oldInFarmBalance, _oldTotalBalance);
            }

            if (sharesRemoved > user.shares) {
                user.shares = 0;
            } else {
                user.shares = user.shares.sub(sharesRemoved);
            }

            uint256 wantBal = IERC20(pool.want).balanceOf(address(this));
            if (wantBal < _wantAmt) {
                _wantAmt = wantBal;
            }

            if (_wantAmt > 0) {
                require(whitelisted[msg.sender] || block.timestamp >= unfrozenStakeTime(_pid, msg.sender), "DarkBank: frozen");
                    if (block.timestamp >= earlyWithdrawTimeEnd(_pid, msg.sender)) {
                        pool.want.safeTransfer(address(msg.sender), _wantAmt);
                    } else {
                        uint256 fee = _wantAmt.mul(poolInfo[_pid].earlyWithdrawFee.div(10000));
                        uint256 userReceivedAmount = _wantAmt.sub(fee);
                        pool.want.safeTransfer(operator, fee);
                        pool.want.safeTransfer(address(msg.sender), userReceivedAmount);
                    }
                user.totalWithdraw = user.totalWithdraw.add(_wantAmt);
            }
            uint256 wantLockedTotal = IStrategy(_strategy).wantLockedTotal();
            uint256 sharesTotal = IStrategy(_strategy).sharesTotal();
            user.recentBalance = user.shares.mul(wantLockedTotal).div(sharesTotal);
        }
        uint256 _rewardPoolLength = rewardPoolInfo.length;
        for (uint256 _rewardPid = 0; _rewardPid < _rewardPoolLength; ++_rewardPid) {
            user.rewardDebt[_rewardPid] = user.shares.mul(pool.accRewardPerShare[_rewardPid]).div(1e18);
        }
        emit Withdraw(msg.sender, _pid, _wantAmt);
    }

    function withdrawAll(uint256 _pid)  external notContract {
        withdraw(_pid, uint256(-1));
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public notContract nonReentrant {
        require(!pausePool[_pid], "paused");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strategy).wantLockedTotal();
        uint256 sharesTotal = IStrategy(poolInfo[_pid].strategy).sharesTotal();
        uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);

        IStrategy(poolInfo[_pid].strategy).withdraw(msg.sender, amount);
        if (amount > 0) {
            require(whitelisted[msg.sender] || block.timestamp >= unfrozenStakeTime(_pid, msg.sender), "DarkBank: frozen");
            if (block.timestamp >= earlyWithdrawTimeEnd(_pid, msg.sender)) {
                pool.want.safeTransfer(address(msg.sender), amount);
            } else if (poolInfo[_pid].earlyWithdrawFee > 0) {
                uint256 fee = amount.mul(poolInfo[_pid].earlyWithdrawFee.div(10000));
                uint256 userReceivedAmount = amount.sub(fee);
                pool.want.safeTransfer(operator, fee);
                pool.want.safeTransfer(address(msg.sender), userReceivedAmount);
            }
            user.totalWithdraw = user.totalWithdraw.add(amount);
        }

        emit EmergencyWithdraw(msg.sender, _pid, amount);
        user.shares = 0;
        uint256 _rewardPoolLength = rewardPoolInfo.length;
        for (uint256 _rewardPid = 0; _rewardPid < _rewardPoolLength; ++_rewardPid) {
            user.rewardDebt[_rewardPid] = 0;
        }
    }

    // Safe reward token transfer function, just in case if rounding error causes pool to not have enough
    function safeRewardTransfer(address _rewardToken, address _to, uint256 _amount) internal {
        uint256 _bal = IERC20(_rewardToken).balanceOf(address(this));
        if (_amount > _bal) {
            IERC20(_rewardToken).transfer(_to, _bal);
        } else {
            IERC20(_rewardToken).transfer(_to, _amount);
        }
    }

    function setWhitelisted(address _account, bool _whitelisted) external nonReentrant onlyOperator {
        whitelisted[_account] = _whitelisted;
    }

    function setWhitelistedContract(address _contract, bool _whitelisted) external onlyOperator {
        whitelistedContract[_contract] = _whitelisted;
    }

    function setStopRewardPool(uint256 _pid, bool _stopRewardPool) external nonReentrant onlyOperator {
        stopRewardPool[_pid] = _stopRewardPool;
    }

    function setPausePool(uint256 _pid, bool _pausePool) external nonReentrant onlyOperator {
        pausePool[_pid] = _pausePool;
    }

    /* ========== EMERGENCY ========== */

    function setTimelock(address _timelock) external {
        require(msg.sender == timelock || (timelock == address(0) && msg.sender == operator), "DarkBank: !authorised");
        timelock = _timelock;
    }

    function inCaseTokensGetStuck(address _token, uint256 _amount, address _to) external onlyTimelock {
        IERC20(_token).safeTransfer(_to, _amount);
    }

    event ExecuteTransaction(address indexed target, uint256 value, string signature, bytes data);

    /**
     * @dev This is from Timelock contract.
     */
    function executeTransaction(address target, uint256 value, string memory signature, bytes memory data) external onlyTimelock returns (bytes memory) {
        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value : value}(callData);
        require(success, "DarkBank::executeTransaction: Transaction execution reverted.");

        emit ExecuteTransaction(target, value, signature, data);

        return returnData;
    }
}