pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IXShareLocker.sol";
import "../Operator.sol";
import "../interfaces/IYShare.sol";

contract XShareLocker is Operator, IXShareLocker {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public xShare;
    address public yShare;

    uint256 public MIN_LOCK_DURATION = 1 minutes; //Min 1 week lock
    uint256 public MAX_LOCK_DURATION = 208 minutes; //Max 288 weeks (~ 4 years) lock
    uint256 public LOCK_DURATION_STEP = 1 minutes; //Lock duration must be like 1, 2, 5, 10 weeks
    uint256 public MAX_YSHARE_MINTED_PER_XSHARE = 4 ether;
    uint256 public EXTRA_YSHARE_PER_WEEK = (MAX_YSHARE_MINTED_PER_XSHARE.sub(1 ether)).div(MAX_LOCK_DURATION).mul(MIN_LOCK_DURATION); //Extra yShare for every 1 week longer lock

    uint256 public totalXShareLocked;
    uint256 public totalYShareMinted;
    uint256 public averageLockDuration;

    struct UserInfo {
        uint256 lockedAmount;
        uint256 yShareMinted;
        uint256 lockDuration;
        uint256 lockStartTime;
        uint256 lockEndTime;
    }

    bool public initialized = false;
    bool public isUnlockAll = false; //Allow to unlock all without waiting lock end, use in emergency cases

    mapping(address => UserInfo) public userInfo;

    /* ========== MODIFIER ========== */

    modifier notInitialized() {
        require(!initialized, "Already Initialized");
        _;
    }

    modifier isInitialized() {
        require(initialized, "Not Initialized");
        _;
    }

    modifier validDuration(uint256 _duration) {
        require((_duration % MIN_LOCK_DURATION) == 0, "Invalid duration");
        require(_duration >= MIN_LOCK_DURATION && _duration <= MAX_LOCK_DURATION, "Min Lock 1 week and max lock 208 week");
        _;
    }

    modifier isAllowedUnlockAll() {
        require(isUnlockAll, "Not unlock all");
        _;
    }

    function isLocked(address user) public view returns (bool) {
        return userInfo[user].lockEndTime > block.timestamp;
    }

    /* ========== IMMUTABLE FUNCTIONS ========== */

    function initialize(address _xShare, address _yShare) public notInitialized onlyOperator {
        require(_xShare != address(0), "Invalid address");
        require(_yShare != address(0), "Invalid address");
        xShare = _xShare;
        yShare = _yShare;
        initialized = true;
    }

    /* ========== MUTABLE FUNCTIONS ========== */

    function lockXShare(uint256 amount, uint256 lockDuration) public override validDuration(lockDuration) {
        address _sender = msg.sender;
        UserInfo storage user = userInfo[_sender];
        require(amount > 0, "Invalid amount");
//        require((lockDuration % MIN_LOCK_DURATION) == 0, "Invalid duration");
//        require(lockDuration >= MIN_LOCK_DURATION && lockDuration <= MAX_LOCK_DURATION, "Min Lock 1 week and max lock 208 week");
        require(!isLocked(_sender), "Please use add more function");
        uint256 yShare_minting_amount = calculateYShareMintAmount(amount, lockDuration);

        IYShare(yShare).lockerMintFrom(msg.sender, yShare_minting_amount);
        IERC20(xShare).safeTransferFrom(msg.sender, address(this), amount);

        user.lockStartTime = block.timestamp;
        user.lockEndTime = block.timestamp.add(lockDuration);
        user.lockDuration = lockDuration;
        user.lockedAmount = user.lockedAmount.add(amount);
        user.yShareMinted = user.yShareMinted.add(yShare_minting_amount);

        totalXShareLocked = totalXShareLocked.add(amount);
        totalYShareMinted = totalYShareMinted.add(yShare_minting_amount);
        updateAverageLockDuration();

        emit LockXShare(_sender, amount);
    }

    //TODO Fix AddMore, Extend, Unlock function
    //Update 1: Fixed Addmore, extend. Unlock function worked before split into 2 step with unlockOperation!

    //If use has locked some XShare before, user can use this function to add more xShare but still have the same lock duration and receive more yShare
    function addMoreXShare(uint256 amount) public override {
        address _sender = msg.sender;
        require(amount > 0, "Invalid Amount");
        require(isLocked(_sender), "Lock ended");

        UserInfo storage user = userInfo[_sender];
        uint256 yShare_minting_amount = calculateYShareMintAmount(amount, user.lockDuration);
        IERC20(xShare).safeTransferFrom(msg.sender, address(this), amount);
        IYShare(yShare).lockerMintFrom(msg.sender, yShare_minting_amount);

        user.lockedAmount = user.lockedAmount.add(amount);
        user.yShareMinted = user.yShareMinted.add(yShare_minting_amount);
        totalXShareLocked = totalXShareLocked.add(amount);
        totalYShareMinted = totalYShareMinted.add(yShare_minting_amount);
        updateAverageLockDuration();

        emit AddMoreXShare(_sender, amount);
    }

    //If User has locked XShare before, user can extend their lock duration to receive more yShare
    function extendLockDuration(uint256 extendLockDuration) public override validDuration(extendLockDuration) {
        address _sender = msg.sender;
        UserInfo storage user = userInfo[_sender];
//        require((extendLockDuration % MIN_LOCK_DURATION) == 0, "Invalid duration");
//        require(extendLockDuration >= MIN_LOCK_DURATION && extendLockDuration <= MAX_LOCK_DURATION, "Min Lock 1 week and max lock 208 week");
        require(isLocked(_sender), "Lock ended");
        require(user.lockDuration.add(extendLockDuration) <= MAX_LOCK_DURATION, "Exceed max lock duration");

        uint256 currentLockedAmount = user.lockedAmount;
        uint256 totalYShareSupposedToMint = calculateYShareMintAmount(user.lockedAmount, user.lockDuration.add(extendLockDuration));
        uint256 extraYShareAmount = totalYShareSupposedToMint.sub(user.yShareMinted);

        IYShare(yShare).lockerMintFrom(msg.sender, extraYShareAmount);

        user.lockEndTime = user.lockEndTime.add(extendLockDuration);
        user.yShareMinted = user.yShareMinted.add(extraYShareAmount);
        user.lockDuration = user.lockDuration.add(extendLockDuration);
        totalYShareMinted = totalYShareMinted.add(extraYShareAmount);
        updateAverageLockDuration();

        emit ExtendLockDuration(_sender, extendLockDuration);
    }

    function unlockXShare(uint256 amount) public override {
        address _sender = msg.sender;
        require(amount > 0, "Invalid Amount");
        require(!isLocked(_sender), "Still in lock");
        unlockOperation(amount, _sender);
        emit UnlockXShare(_sender, amount);
    }

    function unlockAll() public {
        address _sender = msg.sender;
        require(!isLocked(_sender), "Still in lock");
        unlockOperation(userInfo[_sender].lockedAmount, _sender);
        emit UnlockAll(_sender);
    }

    function unlockOperation(uint256 _amount, address _user) internal {
        UserInfo storage user = userInfo[_user];
        require(user.lockedAmount >= _amount);
        uint256 require_yShare_balance = calculateYShareMintAmount(_amount, user.lockDuration);
        require(IERC20(yShare).balanceOf(msg.sender) >= require_yShare_balance, "Not enough yShare balance to unlock");

        IYShare(yShare).lockerBurnFrom(msg.sender, require_yShare_balance);
        IERC20(xShare).safeTransfer(msg.sender, _amount);

        totalXShareLocked = totalXShareLocked.sub(_amount);
        totalYShareMinted = totalYShareMinted.sub(require_yShare_balance);
        user.lockedAmount = user.lockedAmount.sub(_amount);
        user.yShareMinted = user.yShareMinted.sub(require_yShare_balance);
        if (user.lockedAmount == 0) {

            user.lockDuration = 0;
            user.lockStartTime = 0;
            user.lockEndTime = 0;
        }

        updateAverageLockDuration();
    }


    //In emergency cases, admin will allow user to unlock their xShare immediately
    function emergencyUnlockAll() public override isAllowedUnlockAll {
        address _sender = msg.sender;
        UserInfo storage user = userInfo[_sender];
        if (user.lockedAmount <= 0) revert("Not locked any xShare");

        IYShare(yShare).lockerBurnFrom(msg.sender, user.yShareMinted);
        IERC20(xShare).safeTransfer(msg.sender, user.lockedAmount);

        totalXShareLocked = totalXShareLocked.sub(user.lockedAmount);
        totalYShareMinted = totalYShareMinted.sub(user.yShareMinted);

        user.lockedAmount = 0;
        user.yShareMinted = 0;
        user.lockDuration = 0;
        user.lockStartTime = 0;
        user.lockEndTime = 0;

        updateAverageLockDuration();

        emit EmergencyUnlockAll(_sender);
    }

    function toggleUnlockAll() public onlyOperator {
        isUnlockAll = !isUnlockAll;
    }

    function updateAverageLockDuration() internal {
        if (totalXShareLocked == 0) {
            averageLockDuration = 0;
        } else {
            uint256 ySharePerXShareFactor = totalYShareMinted.mul(1e18).div(totalXShareLocked);
            averageLockDuration = (ySharePerXShareFactor.sub(1e18)).div(EXTRA_YSHARE_PER_WEEK).mul(MIN_LOCK_DURATION);
        }
    }

    function calculateYShareMintAmount(uint256 amount, uint256 lockDuration) internal returns (uint256){
        uint256 boost_amount_factor = lockDuration.div(MIN_LOCK_DURATION);
        uint256 extra_yShare_per_xShare = EXTRA_YSHARE_PER_WEEK.mul(boost_amount_factor);
        uint256 actual_extra_yShare = amount.mul(extra_yShare_per_xShare).div(1e18);
        //To calculate factor for minting yShare
        uint256 yShare_minting_amount = amount.add(actual_extra_yShare);
        //To be mint yShare amount
        return yShare_minting_amount;
    }

    /* ========== EVENT ========== */

    event LockXShare(address indexed user, uint256 amount);
    event AddMoreXShare(address indexed user, uint256 amount);
    event ExtendLockDuration(address indexed user, uint256 extendDuration);
    event UnlockXShare(address indexed user, uint256 amount);
    event UnlockAll(address indexed user);
    event EmergencyUnlockAll(address indexed user);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

pragma solidity ^0.6.12;

interface IXShareLocker {
    function lockXShare(uint256 _amount, uint256 duration) external;

    function unlockXShare(uint256 _amount) external;

    function addMoreXShare(uint256 _amount) external;

    function extendLockDuration(uint256 _extendDuration) external;

    function emergencyUnlockAll() external;

}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Operator is Context, Ownable {
    address private _operator;

    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);

    constructor() internal {
        _operator = _msgSender();
        emit OperatorTransferred(address(0), _operator);
    }

    function operator() public view returns (address) {
        return _operator;
    }

    modifier onlyOperator() {
        require(_operator == msg.sender, "operator: caller is not the operator");
        _;
    }

    function isOperator() public view returns (bool) {
        return _msgSender() == _operator;
    }

    function transferOperator(address newOperator_) public onlyOwner {
        _transferOperator(newOperator_);
    }

    function _transferOperator(address newOperator_) internal {
        require(newOperator_ != address(0), "operator: zero address given for new operator");
        emit OperatorTransferred(address(0), newOperator_);
        _operator = newOperator_;
    }
}

pragma solidity ^0.6.12;

interface IYShare {
    function lockerBurnFrom(address _address, uint256 _amount) external;

    function lockerMintFrom(address _address, uint256 _amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../utils/Context.sol";

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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