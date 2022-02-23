/**
 *Submitted for verification at FtmScan.com on 2022-02-23
*/

// File: @openzeppelin/contracts/utils/Address.sol


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

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


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

// File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;



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

// File: @openzeppelin/contracts/utils/math/SafeMath.sol


// OpenZeppelin Contracts v4.4.1 (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
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
        return a + b;
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
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
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
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
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
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
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
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// File: @openzeppelin/contracts/utils/Context.sol


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

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;


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

// File: Staking.sol



pragma solidity ^0.8.7;





contract FFSStaking is Ownable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct User {
        //Referral Info
        address userAddress;
        uint256 referrals;
        uint256 total_ref_bonus;

        //Deposit Accounting
        uint256 compounds;
        uint256 deposits;
        uint256 deposit_time;

        //Payout and Roll Accounting
        uint256 referral_payouts;
        uint256 payouts;
        uint256 payout_time;
    }

    address public manager;
    address public frensVaultAddress;
    IERC20 private FFSToken;
    IERC20 private FPADToken;
    
    mapping(address => User) public users;

    uint256 public payoutRate = 5;
    uint256 public min_ref_deposit = 0; // Minimum staking to be eligible for referral claim.
    uint256 public ref_depth = 0; // How many levels of referrals are allowed.
    uint256 public ref_bonus = 8; // How much tokens are given to each referral in FPAD

    uint256 public minimumInitial = 0; // Minimum Initial Amount Required to participate in the staking
    uint256 public minimumAmount = 1000; // Minimum Amount Required to deposit
    uint256 public minStakeTime = 0 days; // Minimum Time Required to Stake
    

    uint256 public total_users;
    uint256 public total_deposited;
    uint256 public total_compounded;
    uint256 public total_withdraw;
    uint256 public total_referrals;
    uint256 public total_txs;

    event NewUser(address indexed addr);
    event NewDeposit(address indexed addr, uint256 amount);
    event NewCompound(address indexed addr, uint256 amount);
    event ReferralPayout(address indexed addr,  uint256 amount);
    event ClaimPayout(address indexed addr, uint256 amount);
    event Withdraw(address indexed addr, uint256 amount);

    constructor(address _manager, address _frensVaultAddress, address _FFSTokenAddress, address _FPADTokenAddress) {
        manager = _manager;
        frensVaultAddress = _frensVaultAddress;
        FFSToken = IERC20(_FFSTokenAddress);
        FPADToken = IERC20(_FPADTokenAddress);
    }

    /****** Administrative Functions *******/
    function updatePayoutRate(uint256 _newPayoutRate) external onlyOwner {
        payoutRate = _newPayoutRate;
    }

    function updateRefDepth(uint256 _newRefDepth) external onlyOwner {
        ref_depth = _newRefDepth;
    }

    function updateRefBonus(uint256 _newRefBonus) external onlyOwner {
        ref_bonus = _newRefBonus;
    }

    function updateInitialDeposit(uint256 _newInitialDeposit) external onlyOwner {
        minimumInitial = _newInitialDeposit;
    }

    function updateFFSToken(address _address) external onlyOwner {
        FFSToken = IERC20(_address);
    }

    function updateFPADToken(address _address) external onlyOwner {
        FPADToken = IERC20(_address);
    }

    function updateVaultAddress(address _address) external onlyOwner {
        frensVaultAddress = _address;
    }

    function updateManager(address _address) external onlyOwner {
        manager = _address;
    }

    function updateMinStakeTime(uint256 _newMinStakeTime) external onlyOwner {
        minStakeTime = _newMinStakeTime;
    }

    function updateMinStakeAmount(uint256 _newMinStakeAmount) external onlyOwner {
        minimumAmount = _newMinStakeAmount;
    }

    function updateMinRefDeposit(uint256 _newMinRefDeposit) external onlyOwner {
        min_ref_deposit = _newMinRefDeposit*1e18;
    }

    function withdrawETH() external onlyOwner {
        bool success;
        (success,) = address(msg.sender).call{value: address(this).balance}("");
    }

    /********** User Fuctions **************************************************/
    
    //@dev Deposit specified FFS amount l
    function deposit(address refAddress, uint256 _amount) external {

        address _userAddress = msg.sender;
        require(_amount >= minimumAmount, "Minimum deposit");

        //If fresh account require a minimal amount of FFS
        if (users[_userAddress].deposits == 0){
            require(_amount >= minimumInitial, "Initial deposit too low");
        }

        // Compound all the claim amounts on new deposits
        if (claimsAvailable(_userAddress) > 0){
            _compound(_userAddress);
        }

        //Transfer FFS to the vault
        require(
            FFSToken.transferFrom(
                _userAddress,
                address(this),
                _amount
            ),
            "FFS token transfer failed"
        );

        if(users[refAddress].deposits >= min_ref_deposit && users[msg.sender].userAddress == address(0) && msg.sender != refAddress ){
            _refPayout(_userAddress, refAddress, _amount);
        }

        _deposit(_userAddress, _amount);

        
        total_txs++;

    }

    //@dev Claim, transfer, withdraw from vault
    function claim(address userAddress, uint conversionRate) external {
        require(msg.sender == manager || msg.sender == owner(), "Only manager or owner can invoke");
        _claim_out(userAddress, conversionRate);
    }

    //@dev Claim, transfer, withdraw from vault
    function claimReferral(address userAddress, uint conversionRate) external {
        require(msg.sender == manager || msg.sender == owner(), "Only manager or owner can invoke");
        _claim_referral(userAddress, conversionRate);
    }

    //@dev Claim, transfer, withdraw from vault
    function withdrawPrincipal(address userAddress, uint conversionRate) external {
        require(msg.sender == manager || msg.sender == owner(), "Only manager or owner can invoke");
        _withdraw_principal(userAddress, conversionRate);
    }

    //@dev Claim and deposit;
    function compound() public {
        
        address _addr = msg.sender;

        _compound(_addr);
    }

    /********** Internal Fuctions **************************************************/


    //@dev Deposit
    function _deposit(address _addr, uint256 _amount) internal {
        
        if(users[_addr].userAddress == address(0)){
            users[_addr].userAddress = _addr;
            total_users++;
        }

        //stats
        users[_addr].deposits += _amount;
        users[_addr].deposit_time = block.timestamp;

        total_deposited += _amount;

        //events
        emit NewDeposit(_addr, _amount);
    }

    
    function _refPayout(address _addr, address refAddress, uint256 _amount) internal {
        //for deposit _addr is the sender/depositor

        bool checkUser = users[_addr].userAddress == address(0) ? false : true;

        if(checkUser == false){

            if(ref_depth > 0 && users[_addr].referrals < ref_depth){
                
                uint bonus = _amount.mul(ref_bonus).div(100); 
                
                users[refAddress].referrals++;
                users[refAddress].total_ref_bonus += bonus;

                total_referrals++;

            }
            else if(ref_depth == 0){
                uint bonus = _amount.mul(ref_bonus).div(100); 
                
                users[refAddress].referrals++;
                users[refAddress].total_ref_bonus += bonus;

                total_referrals++;
            }

        }
    }

    

    //@dev Claim and deposit;
    function _compound(address _addr) internal {

        (uint256 _payout) = payoutOf(_addr);

        if(_payout > 0){

            if(users[_addr].userAddress == address(0)){
                users[_addr].userAddress = _addr;
            }

            //stats
            users[_addr].compounds += _payout;
            users[_addr].deposit_time = block.timestamp;

            total_compounded += _payout;

            //events
            emit NewCompound(_addr, _payout);

            total_txs++;

        }
    }


    //@dev Claim
    function _claim_out(address _addr, uint conversionRate) internal {
        
        (uint256 _payout) = payoutOf(_addr);
        
        // Pay Compounds & Interest
        uint _amt = users[_addr].compounds.add(_payout).mul(conversionRate).div(10000);

        require(
            FPADToken.transferFrom(
                address(frensVaultAddress),
                _addr,
                _amt
            ),
            "Failed to transfer FPAD tokens"
        );

        users[_addr].payouts += _amt;
        users[_addr].compounds = 0;
        users[_addr].deposit_time = block.timestamp;

        total_txs++;
        total_withdraw++;

        emit ClaimPayout(_addr, _amt);
    }
    
    function _claim_referral(address _addr, uint conversionRate) internal {

        uint ref_amount = users[_addr].total_ref_bonus;

        // Convert
        uint _amt = ref_amount.mul(conversionRate).div(10000);

        require(
            FPADToken.transferFrom(
                address(frensVaultAddress),
                _addr,
                _amt
            ),
            "Failed to transfer FPAD tokens"
        );


        users[_addr].referral_payouts += _amt;
        users[_addr].total_ref_bonus = 0;
        users[_addr].payout_time = block.timestamp;

        total_txs++;

        emit ReferralPayout(_addr, _amt);

    }

    // This is complete settlement
    function _withdraw_principal(address _addr, uint conversionRate) internal {

        require(canUserClaim(_addr), "User cannot claim - Minumum stake Time not met");

        _claim_out(_addr, conversionRate);
        
        require(users[_addr].deposits > 0 , "User has no deposits");
        uint _withdraw_amt = users[_addr].deposits;

        require(
            FFSToken.transfer(
                _addr,
                _withdraw_amt
            ),
            "Failed to transfer FFS tokens"
        );
 
        users[_addr].deposits = 0;

        emit Withdraw(_addr, _withdraw_amt);

    }

    /********* Views ***************************************/

    //@dev Returns true if the address is net positive
    function isNetPositive(address _addr) public view returns (bool) {

        (uint256 _credits, uint256 _debits) = creditsAndDebits(_addr);

        return _credits > _debits;

    }

    //@dev Returns the total credits and debits for a given address
    function creditsAndDebits(address _addr) public view returns (uint256 _credits, uint256 _debits) {
        User memory _user = users[_addr];

        _credits = _user.deposits;
        _debits = _user.payouts;
    }

    //@dev Returns amount of claims available for sender
    function claimsAvailable(address _addr) public view returns (uint256) {
        (uint256 _payout) = payoutOf(_addr);
        return _payout;
    }

    function canUserClaim(address _addr) public view returns (bool) {
       return (block.timestamp - users[_addr].deposit_time) >= minStakeTime; 
    }

    //@dev Calculate the current payout of a given address
    function payoutOf(address _addr) public view returns(uint256 payout) {
        
        
        uint userBalance = users[_addr].compounds.add(users[_addr].deposits);

        uint share = userBalance.mul(payoutRate * 1e18).div(1000e18).div(24 hours); //divide the profit by payout rate and seconds in the day

        payout = share.mul(block.timestamp.sub(users[_addr].deposit_time));
    
    }

    //@dev Get current user snapshot
    function userInfo(address _addr) external view returns(uint256 deposit_time, uint256 deposits, uint256 payouts, uint256 total_ref_bonus, uint256 compounds, uint256 ref_payouts, uint total_payout) {
        (uint256 _payout) = payoutOf(_addr);
        return (users[_addr].deposit_time, users[_addr].deposits, users[_addr].payouts, users[_addr].total_ref_bonus, users[_addr].compounds, users[_addr].referral_payouts, _payout );
    }

    //@dev Get totals
    function InfoTotals() external view returns(uint256 total_users, uint256 total_deposited, uint256 total_compounded, uint256 total_referrals,  uint256 total_txs ) {
        return (total_users, total_deposited, total_withdraw, total_referrals, total_txs);
    }

      //@dev Get Contract Stake info
    function stakeInfo() external view returns(uint256 payoutRate, uint256 ref_depth, uint256 ref_bonus, uint256 minimumInitial, uint256 minimumAmount, uint minStakeTime) {
        return (payoutRate, ref_depth, ref_bonus, minimumInitial, minimumAmount, minStakeTime);
    }
    

}