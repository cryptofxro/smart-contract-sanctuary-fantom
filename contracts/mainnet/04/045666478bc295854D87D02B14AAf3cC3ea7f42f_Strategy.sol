/**
 *Submitted for verification at FtmScan.com on 2022-05-18
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

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
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

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
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure returns (bytes memory) {
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


// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.
/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is no longer needed starting with Solidity 0.8. The compiler
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


/*
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
        _setOwner(_msgSender());
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
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
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

    function migrateFrom(address _oldStrategy, uint256 _oldWantLockedTotal, uint256 _oldSharesTotal) external;

    function inCaseTokensGetStuck(address _token, uint256 _amount) external;

    function inFarmBalance() external view returns (uint256);

    function totalBalance() external view returns (uint256);
}


interface IFarmingPool {
    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function pendingReward(uint256 _pid, address _user) external view returns (uint256);

    function pendingShare(uint256 _pid, address _user) external view returns (uint256);

    function pendingCyborg(uint256 _pid, address _user) external view returns (uint256);

    function pendingVVS(uint256 _pid, address _user) external view returns (uint256);

    function pendingAnnex(uint256 _pid, address _user) external view returns (uint256);

    function userInfo(uint256 _pid, address _user) external view returns (uint256 amount, uint256 rewardDebt);
}


interface IValueLiquidFormula {
    function getAmountsOut(
        address tokenIn,
        address tokenOut,
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}


interface IValueLiquidRouter {
    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function addLiquidity(
        address pair,
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}


interface IPancakeRouter01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
    external
    returns (
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
    external
    payable
    returns (
        uint256 amountToken,
        uint256 amountETH,
        uint256 liquidity
    );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path, uint fee) external view returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path, uint fee) external view returns (uint256[] memory amounts);
}


interface IPancakeRouter02 is IPancakeRouter01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}


contract Strategy is IStrategy, Ownable, ReentrancyGuard, Pausable {
    // Maximises yields in quickswap

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public farmContractAddress;
    uint256 public pid; // pid of pool in farmContractAddress
    address public override wantAddress;
    address public tokenTargetAddress;
    address public override token0Address;
    address public override token1Address;
    address public override earnedAddress;
    address public dexRouterAddress;
    address public oneRouterAddress = address(0x411aed870F2F3027F20717886cb617fF3c0D7CF7); // router
    address public formulaAddress = address(0xc1683FA5E5b47141ca193671950eD5a043Dc8D46); // formula
    mapping(address => mapping(address => address[])) public paths;

    address public constant usdcAddress = address(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75);

    address public controller;
    address public strategist;
    address public timelock;
    bool public notPublic = false; // allow public to call earn() function

    uint256 public lastEarnTime = 0;
    uint256 public autoEarnLimit = 100000000; // 100 USDC
    uint256 public autoEarnDelaySeconds = 6 hours;
    bool public autoEarnEnabled = false;

    uint256 public override wantLockedTotal = 0;
    uint256 public override sharesTotal = 0;
    uint256 public totalEarned = 0;
    uint256 public totalFundBuyBack = 0;

    uint256 public controllerFee = 100; //1%
    uint256 public constant controllerFeeMax = 10000; // 100 = 1%
    uint256 public constant controllerFeeUL = 300;

    uint256 public constant buyBackRateMax = 10000; // 100 = 1%
    uint256 public constant buyBackRateUL = 800; // 8%

    uint256 public buyBackRate = 400; // 4%
    address public buyBackAddress = address(0x475f09F12E069818C9b05d4ea3b92236F1DF0687); // insurance
    address public buyBackTokenAddress = address(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83); // dark to insurance

    uint256 public entranceFeeFactor = 10000; // 0% entrance fee (goes to pool + prevents front-running)
    uint256 public constant entranceFeeFactorMax = 10000; // 100 = 1%
    uint256 public constant entranceFeeFactorLL = 9950; // 0.5% is the max entrance fee settable. LL = lowerlimit

    event Deposit(uint256 amount);
    event Withdraw(uint256 amount);
    event Farm(uint256 amount);
    event Compound(address token0Address, uint256 token0Amt, address token1Address, uint256 token1Amt);
    event Earned(address earnedAddress, uint256 earnedAmt);
    event BuyBack(address earnedAddress, uint earnedAmt, uint256 buyBackAmt, address receiver);
    event DistributeFee(address earnedAddress, uint256 fee, address receiver);
    event InCaseTokensGetStuck(address tokenAddress, uint256 tokenAmt, address receiver);
    event ExecuteTransaction(address indexed target, uint256 value, string signature, bytes data);

    // _controller:  VaultBank
    constructor(
        address _controller,
        address _farmContractAddress,
        uint256 _pid,
        address _wantAddress,
        address _earnedAddress,
        address _dexRouterAddress,
        address _tokenTargetAddress,
        address _token0,
        address _token1
    ) {
        controller = _controller;
        farmContractAddress = _farmContractAddress;
        dexRouterAddress = _dexRouterAddress;
        strategist = msg.sender;
        // to call earn if public not allowed

        wantAddress = _wantAddress;
        tokenTargetAddress = _tokenTargetAddress;
        token0Address = _token0;
        token1Address = _token1;

        pid = _pid;
        earnedAddress = _earnedAddress;
    }

    modifier onlyController() {
        require(controller == msg.sender, "caller is not the controller");
        _;
    }

    modifier onlyStrategist() {
        require(strategist == msg.sender || owner() == msg.sender, "VaultStrategy: caller is not the strategist");
        _;
    }

    modifier onlyTimelock() {
        require(timelock == msg.sender, "VaultStrategy: caller is not timelock");
        _;
    }

    function isAuthorised(address _account) public view returns (bool) {
        return (_account == owner()) || (msg.sender == strategist) || (msg.sender == timelock);
    }

    function _checkAutoEarn() internal {
        if (!paused() && !notPublic && autoEarnEnabled) {
            uint256 _pendingHarvestDollarValue = pendingHarvestDollarValue();
            if (_pendingHarvestDollarValue >= autoEarnLimit) {
                earn();
            }
        }
    }

    function inFarmBalance() public override view returns (uint256) {
        (uint256 amount,) = IFarmingPool(farmContractAddress).userInfo(pid, address(this));
        return amount;
    }

    function totalBalance() external override view returns (uint256) {
        return IERC20(wantAddress).balanceOf(address(this)) + inFarmBalance();
    }

    function getPricePerFullShare() external override view returns (uint256) {
        return (sharesTotal == 0) ? 1e18 : wantLockedTotal.mul(1e18).div(sharesTotal);
    }

    // Receives new deposits from user
    function deposit(address, uint256 _wantAmt) external override onlyController nonReentrant whenNotPaused returns (uint256) {
        _checkAutoEarn();
        IERC20(wantAddress).safeTransferFrom(address(msg.sender), address(this), _wantAmt);

        uint256 sharesAdded = _wantAmt;
        if (wantLockedTotal > 0 && sharesTotal > 0) {
            sharesAdded = _wantAmt.mul(sharesTotal).mul(entranceFeeFactor).div(wantLockedTotal).div(entranceFeeFactorMax);
        }
        sharesTotal = sharesTotal.add(sharesAdded);

        _farm();

        emit Deposit(_wantAmt);

        return sharesAdded;
    }

    function farm() public nonReentrant {
        _farm();
    }

    function _farm() internal {
        IERC20 _want = IERC20(wantAddress);
        uint256 wantAmt = _want.balanceOf(address(this));
        wantLockedTotal = wantLockedTotal.add(wantAmt);

        _want.safeIncreaseAllowance(farmContractAddress, wantAmt);
        IFarmingPool(farmContractAddress).deposit(pid, wantAmt);

        emit Farm(wantAmt);
    }

    function withdraw(address, uint256 _wantAmt) external override onlyController nonReentrant returns (uint256) {
        require(_wantAmt > 0, "VaultStrategy: !_wantAmt");

        IFarmingPool(farmContractAddress).withdraw(pid, _wantAmt);

        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));
        if (_wantAmt > wantAmt) {
            _wantAmt = wantAmt;
        }

        if (wantLockedTotal < _wantAmt) {
            _wantAmt = wantLockedTotal;
        }

        uint256 sharesRemoved = _wantAmt.mul(sharesTotal).div(wantLockedTotal);
        if (sharesRemoved > sharesTotal) {
            sharesRemoved = sharesTotal;
        }
        sharesTotal = sharesTotal.sub(sharesRemoved);
        wantLockedTotal = wantLockedTotal.sub(_wantAmt);

        IERC20(wantAddress).safeTransfer(address(msg.sender), _wantAmt);

        _checkAutoEarn();

        emit Withdraw(_wantAmt);

        return sharesRemoved;
    }

    // 1. Harvest farm tokens
    // 2. Converts farm tokens into want tokens
    // 3. Deposits want tokens
    function earn() public override whenNotPaused {
        require(!notPublic || isAuthorised(msg.sender), "VaultStrategy: !authorised");

        // Harvest farm tokens
        IFarmingPool(farmContractAddress).withdraw(pid, 0);

        // Converts farm tokens into want tokens
        uint256 earnedAmt = IERC20(earnedAddress).balanceOf(address(this));

        emit Earned(earnedAddress, earnedAmt);
        // convert all earnToken to target token (reduce fee for buyback)
        _swapToken(earnedAddress, tokenTargetAddress, earnedAmt, address(this));
        uint256 targetAmount = IERC20(tokenTargetAddress).balanceOf(address (this));

        distributeFees(targetAmount);
        buyBack(targetAmount);

        uint256 remainAmt = IERC20(tokenTargetAddress).balanceOf(address(this));

        // track totalEarned in dollar
        totalEarned = totalEarned.add(exchangeRate(tokenTargetAddress, usdcAddress, remainAmt));

        _swapToken(tokenTargetAddress, token0Address, remainAmt.div(2), address(this));

        _swapToken(tokenTargetAddress, token1Address, remainAmt.div(2), address(this));

        // Get want tokens, ie. add liquidity
        uint256 token0Amt = IERC20(token0Address).balanceOf(address(this));
        uint256 token1Amt = IERC20(token1Address).balanceOf(address(this));
        if (token0Amt > 0 && token1Amt > 0) {
            _addLiquidity(token0Address, token1Address, token0Amt, token1Amt);
            emit Compound(token0Address, token0Amt, token1Address, token1Amt);
        }

        lastEarnTime = block.timestamp;

        _farm();
    }

    function buyBack(uint256 _tokenTargetAmount) internal returns (uint256) {
        if (_tokenTargetAmount <= 0 || buyBackRate <= 0 || buyBackAddress == address(0)) {
            return 0;
        }
        uint256 _buyBackAmt = _tokenTargetAmount.mul(buyBackRate).div(buyBackRateMax);
        uint256 _before = IERC20(buyBackTokenAddress).balanceOf(buyBackAddress);
        if (tokenTargetAddress != buyBackTokenAddress) {
            _swapToken(tokenTargetAddress, buyBackTokenAddress, _buyBackAmt, buyBackAddress);
        } else {
            IERC20(buyBackTokenAddress).safeTransfer(buyBackAddress, _buyBackAmt);
        }
        uint256 _after = IERC20(buyBackTokenAddress).balanceOf(buyBackAddress);
        uint256 _newReward = _after.sub(_before);
        totalFundBuyBack += _newReward;
        emit BuyBack(tokenTargetAddress, _buyBackAmt, _newReward, buyBackAddress);
        return _buyBackAmt;
    }

    function distributeFees(uint256 _tokenTargetAmount) internal returns (uint256 _fee) {
        if (_tokenTargetAmount > 0) {
            // Performance fee
            if (controllerFee > 0) {
                _fee = _tokenTargetAmount.mul(controllerFee).div(controllerFeeMax);
                IERC20(tokenTargetAddress).safeTransfer(owner(), _fee);
                emit DistributeFee(tokenTargetAddress, _fee, owner());
            }
        }
    }

    function exchangeRate(address _inputToken, address _outputToken, uint256 _tokenAmount) public view returns (uint256) {
        uint256[] memory amounts = IValueLiquidFormula(formulaAddress).getAmountsOut(_inputToken, _outputToken, _tokenAmount, paths[_inputToken][_outputToken]);
        return amounts[amounts.length - 1];
    }

    function pendingHarvest() public view returns (uint256) {
        uint256 _earnedBal = IERC20(earnedAddress).balanceOf(address(this));
        return IFarmingPool(farmContractAddress).pendingReward(pid, address(this)).add(_earnedBal);
    }

    function pendingHarvestDollarValue() public view returns (uint256) {
        uint256 _pending = pendingHarvest();
        return (_pending == 0) ? 0 : exchangeRate(earnedAddress, usdcAddress, _pending);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setStrategist(address _strategist) external onlyOwner {
        strategist = _strategist;
    }

    function setEntranceFeeFactor(uint256 _entranceFeeFactor) external onlyOwner {
        require(_entranceFeeFactor > entranceFeeFactorLL, "VaultStrategy: !safe - too low");
        require(_entranceFeeFactor <= entranceFeeFactorMax, "VaultStrategy: !safe - too high");
        entranceFeeFactor = _entranceFeeFactor;
    }

    function setControllerFee(uint256 _controllerFee) external onlyOwner {
        require(_controllerFee <= controllerFeeUL, "VaultStrategy: too high");
        controllerFee = _controllerFee;
    }

    function setBuyBackRate(uint256 _buyBackRate) external onlyOwner {
        require(buyBackRate <= buyBackRateUL, "VaultStrategy: too high");
        buyBackRate = _buyBackRate;
    }

    function setBuyBackAddress(address _buyBackAddress) external onlyOwner {
        require(buyBackAddress != address(0), "zero");
        buyBackAddress = _buyBackAddress;
    }

    function setBuyBackTokenAddress(address _buyBackTokenAddress) external onlyOwner {
        require(_buyBackTokenAddress != address(0), "zero");
        buyBackTokenAddress = _buyBackTokenAddress;
    }

    function setDexRouterAddress(address _routerAddress) external onlyOwner {
        require(_routerAddress != address(0), "zero");
        dexRouterAddress = _routerAddress;
    }

    function setOneDexRouterAddress(address _routerAddress) external onlyOwner {
        require(_routerAddress != address(0), "zero");
        oneRouterAddress = _routerAddress;
    }

    function setFormulaAddress(address _formulaAddress) external onlyOwner {
        require(_formulaAddress != address(0), "zero");
        formulaAddress = _formulaAddress;
    }

    function setNotPublic(bool _notPublic) external onlyOwner {
        notPublic = _notPublic;
    }

    function setAutoEarnLimit(uint256 _autoEarnLimit) external onlyOwner {
        autoEarnLimit = _autoEarnLimit;
    }

    function setAutoEarnStatus(bool _status) external onlyOwner {
        autoEarnEnabled = _status;
    }

    function setAutoEarnDelaySeconds(uint256 _autoEarnDelaySeconds) external onlyOwner {
        autoEarnDelaySeconds = _autoEarnDelaySeconds;
    }

    function setMainPaths(
        address[] memory _earnedToTokenTargetPath,
        address[] memory _targetToToken0Path,
        address[] memory _targetToToken1Path,
        address[] memory _targetToBuybackPath,
        address[] memory _targetToUsdcPath,
        address[] memory _earnedToUsdcPath
    ) external onlyOwner {
        paths[earnedAddress][tokenTargetAddress] = _earnedToTokenTargetPath;
        paths[tokenTargetAddress][token0Address] = _targetToToken0Path;
        paths[tokenTargetAddress][token1Address] = _targetToToken1Path;
        paths[tokenTargetAddress][buyBackTokenAddress] = _targetToBuybackPath;
        paths[tokenTargetAddress][usdcAddress] = _targetToUsdcPath;
        paths[earnedAddress][usdcAddress] = _earnedToUsdcPath;
    }

    function setPaths(address _inputToken, address _outputToken, address[] memory _path) external onlyOwner {
        paths[_inputToken][_outputToken] = _path;
    }

    function swapToken(address _inputToken, address _outputToken) external onlyOwner {
        uint256 _amount = IERC20(_inputToken).balanceOf(address(this));
        IERC20(_inputToken).safeIncreaseAllowance(oneRouterAddress, _amount);
        IValueLiquidRouter(oneRouterAddress).swapExactTokensForTokens(_inputToken, _outputToken, _amount, 1, paths[_inputToken][_outputToken], address(this), block.timestamp.add(1800));
    }

    function _swapToken(address _inputToken, address _outputToken, uint256 _amount, address to) internal {
        if (_inputToken != _outputToken) {
            IERC20(_inputToken).safeIncreaseAllowance(oneRouterAddress, _amount);
            IValueLiquidRouter(oneRouterAddress).swapExactTokensForTokens(_inputToken, _outputToken, _amount, 1, paths[_inputToken][_outputToken], to, block.timestamp.add(1800));
        }
    }

    function _addLiquidity(address _tokenA, address _tokenB, uint256 _amountADesired, uint256 _amountBDesired) internal {
        IERC20(_tokenA).safeIncreaseAllowance(dexRouterAddress, _amountADesired);
        IERC20(_tokenB).safeIncreaseAllowance(dexRouterAddress, _amountBDesired);
        IPancakeRouter02(dexRouterAddress).addLiquidity(_tokenA, _tokenB, _amountADesired, _amountBDesired, 0, 0, address(this), block.timestamp.add(1800));
    }

    function inCaseTokensGetStuck(address _token, uint256 _amount) external override onlyOwner {
        require(_token != earnedAddress, "!safe");
        require(_token != wantAddress, "!safe");
        address _controller = controller;
        IERC20(_token).safeTransfer(_controller, _amount);
        emit InCaseTokensGetStuck(_token, _amount, _controller);
    }

    function togglePause() external onlyOwner {
        if (paused()) _unpause();
        else _pause();
    }

    function migrateFrom(address, uint256, uint256) external override onlyController {
    }

    /* ========== EMERGENCY ========== */

    function setController(address _controller) external {
        require(_controller != address(0), "invalidAddress");
        require(controller == msg.sender || timelock == msg.sender, "caller is not the controller nor timelock");
        controller = _controller;
    }

    function setTimelock(address _timelock) external {
        require(timelock == msg.sender || (timelock == address(0) && owner() == msg.sender), "!timelock");
        timelock = _timelock;
    }

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
        require(success, "VaultStrategy::executeTransaction: Transaction execution reverted.");

        emit ExecuteTransaction(target, value, signature, data);

        return returnData;
    }
}