/**
 *Submitted for verification at FtmScan.com on 2022-03-28
*/

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

// Sources flattened with hardhat v2.8.4 https://hardhat.org

// File contracts/Oracle/AggregatorV3Interface.sol


interface AggregatorV3Interface {

  function decimals() external view returns (uint8);
  function description() external view returns (string memory);
  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

}


// File contracts/Oracle/IPricePerShareOptions.sol


interface IPricePerShareOptions {
    // Compound-style [Comp, Cream, Rari, Scream]
    // Multiplied by 1e18
    function exchangeRateStored() external view returns (uint256);

    // Curve-style [Curve, Convex, NOT StakeDAO]
    // In 1e18
    function get_virtual_price() external view returns (uint256);

    // SaddleD4Pool (SwapFlashLoan)
    function getVirtualPrice() external view returns (uint256);

    // StakeDAO
    function getPricePerFullShare() external view returns (uint256);

    // Yearn Vault
    function pricePerShare() external view returns (uint256);
}


// File contracts/Common/Context.sol


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
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


// File contracts/Math/SafeMath.sol


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
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
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
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}


// File contracts/ERC20/IERC20.sol



/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
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


// File contracts/Utils/Address.sol


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


// File contracts/ERC20/ERC20.sol





/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20Mintable}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
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
 
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    
    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory __name, string memory __symbol) public {
        _name = __name;
        _symbol = __symbol;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
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
     * - `spender` cannot be the zero address.approve(address spender, uint256 amount)
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
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
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for `accounts`'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        uint256 decreasedAllowance = allowance(account, _msgSender()).sub(amount, "ERC20: burn amount exceeds allowance");

        _approve(account, _msgSender(), decreasedAllowance);
        _burn(account, amount);
    }


    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     *
     * See {_burn} and {_approve}.
     */
    function _burnFrom(address account, uint256 amount) internal virtual {
        _burn(account, amount);
        _approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "ERC20: burn amount exceeds allowance"));
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of `from`'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of `from`'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:using-hooks.adoc[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}


// File contracts/Staking/Owned.sol


// https://docs.synthetix.io/contracts/Owned
contract Owned {
    address public owner;
    address public nominatedOwner;

    constructor (address _owner) public {
        require(_owner != address(0), "Owner address cannot be 0");
        owner = _owner;
        emit OwnerChanged(address(0), _owner);
    }

    function nominateNewOwner(address _owner) external onlyOwner {
        nominatedOwner = _owner;
        emit OwnerNominated(_owner);
    }

    function acceptOwnership() external {
        require(msg.sender == nominatedOwner, "You must be nominated before you can accept ownership");
        emit OwnerChanged(owner, nominatedOwner);
        owner = nominatedOwner;
        nominatedOwner = address(0);
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only the contract owner may perform this action");
        _;
    }

    event OwnerNominated(address newOwner);
    event OwnerChanged(address oldOwner, address newOwner);
}


// File contracts/Math/HomoraMath.sol



library HomoraMath {
  using SafeMath for uint;

  function divCeil(uint lhs, uint rhs) internal pure returns (uint) {
    return lhs.add(rhs).sub(1) / rhs;
  }

  function fmul(uint lhs, uint rhs) internal pure returns (uint) {
    return lhs.mul(rhs) / (2**112);
  }

  function fdiv(uint lhs, uint rhs) internal pure returns (uint) {
    return lhs.mul(2**112) / rhs;
  }

  // implementation from https://github.com/Uniswap/uniswap-lib/commit/99f3f28770640ba1bb1ff460ac7c5292fb8291a0
  // original implementation: https://github.com/abdk-consulting/abdk-libraries-solidity/blob/master/ABDKMath64x64.sol#L687
  function sqrt(uint x) internal pure returns (uint) {
    if (x == 0) return 0;
    uint xx = x;
    uint r = 1;

    if (xx >= 0x100000000000000000000000000000000) {
      xx >>= 128;
      r <<= 64;
    }

    if (xx >= 0x10000000000000000) {
      xx >>= 64;
      r <<= 32;
    }
    if (xx >= 0x100000000) {
      xx >>= 32;
      r <<= 16;
    }
    if (xx >= 0x10000) {
      xx >>= 16;
      r <<= 8;
    }
    if (xx >= 0x100) {
      xx >>= 8;
      r <<= 4;
    }
    if (xx >= 0x10) {
      xx >>= 4;
      r <<= 2;
    }
    if (xx >= 0x8) {
      r <<= 1;
    }

    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1; // Seven iterations should be enough
    uint r1 = x / r;
    return (r < r1 ? r : r1);
  }
}


// File contracts/Oracle/ComboOracle.sol


// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// =========================== ComboOracle ============================
// ====================================================================
// Aggregates prices for various tokens
// Also has improvements from https://github.com/AlphaFinanceLab/alpha-homora-v2-contract/blob/master/contracts/oracle/ChainlinkAdapterOracle.sol

// Frax Finance: https://github.com/FraxFinance

// Primary Author(s)
// Travis Moore: https://github.com/FortisFortuna

// Reviewer(s) / Contributor(s)
// Jason Huan: https://github.com/jasonhuan
// Sam Kazemian: https://github.com/samkazemian




contract ComboOracle is Owned {

    /* ========== STATE VARIABLES ========== */
    
    address timelock_address;
    address address_to_consult;
    AggregatorV3Interface private priceFeedETHUSD;
    ERC20 private WETH;
    string public native_token_symbol;

    uint256 public PRECISE_PRICE_PRECISION = 1e18;
    uint256 public PRICE_PRECISION = 1e6;
    uint256 public PRICE_MISSING_MULTIPLIER = 1e12;

    address[] public all_token_addresses;
    mapping(address => TokenInfo) public token_info; // token address => info
    mapping(address => bool) public has_info; // token address => has info

    // Price mappings
    uint public maxDelayTime = 90000; // 25 hrs. Mapping for max delay time

    /* ========== STRUCTS ========== */

    struct TokenInfoConstructorArgs {
        address token_address;
        address agg_addr_for_underlying; 
        uint256 agg_other_side; // 0: USD, 1: ETH
        address underlying_tkn_address; // Will be address(0) for simple tokens. Otherwise, the aUSDC, yvUSDC address, etc
        address pps_override_address;
        bytes4 pps_call_selector; // eg bytes4(keccak256("pricePerShare()"));
        uint256 pps_decimals;
    }

    struct TokenInfo {
        address token_address;
        string symbol;
        address agg_addr_for_underlying; 
        uint256 agg_other_side; // 0: USD, 1: ETH
        uint256 agg_decimals;
        address underlying_tkn_address; // Will be address(0) for simple tokens. Otherwise, the aUSDC, yvUSDC address, etc
        address pps_override_address;
        bytes4 pps_call_selector; // eg bytes4(keccak256("pricePerShare()"));
        uint256 pps_decimals;
        int256 ctkn_undrly_missing_decs;
    }

    /* ========== CONSTRUCTOR ========== */

    constructor (
        address _owner_address,
        address _eth_usd_chainlink_address,
        address _weth_address,
        string memory _native_token_symbol,
        string memory _weth_token_symbol
    ) Owned(_owner_address) {

        // Instantiate the instances
        priceFeedETHUSD = AggregatorV3Interface(_eth_usd_chainlink_address);
        WETH = ERC20(_weth_address);

        // Handle native ETH
        all_token_addresses.push(address(0));
        native_token_symbol = _native_token_symbol;
        token_info[address(0)] = TokenInfo(
            address(0),
            _native_token_symbol,
            address(_eth_usd_chainlink_address),
            0,
            8,
            address(0),
            address(0),
            bytes4(0),
            0,
            0
        );
        has_info[address(0)] = true;

        // Handle WETH/USD
        all_token_addresses.push(_weth_address);
        token_info[_weth_address] = TokenInfo(
            _weth_address,
            _weth_token_symbol,
            address(_eth_usd_chainlink_address),
            0,
            8,
            address(0),
            address(0),
            bytes4(0),
            0,
            0
        );
        has_info[_weth_address] = true;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyByOwnGov() {
        require(msg.sender == owner || msg.sender == timelock_address, "You are not an owner or the governance timelock");
        _;
    }

    /* ========== VIEWS ========== */

    function allTokenAddresses() public view returns (address[] memory) {
        return all_token_addresses;
    }

    function allTokenInfos() public view returns (TokenInfo[] memory) {
        TokenInfo[] memory return_data = new TokenInfo[](all_token_addresses.length);
        for (uint i = 0; i < all_token_addresses.length; i++){ 
            return_data[i] = token_info[all_token_addresses[i]];
        }
        return return_data;
    }

    // E6
    function getETHPrice() public view returns (uint256) {
        (uint80 roundID, int price, , uint256 updatedAt, uint80 answeredInRound) = priceFeedETHUSD.latestRoundData();
        require(price >= 0 && (updatedAt >= block.timestamp - maxDelayTime) && answeredInRound >= roundID, "Invalid chainlink price");

        return (uint256(price) * (PRICE_PRECISION)) / (1e8); // ETH/USD is 8 decimals on Chainlink
    }

    // E18
    function getETHPricePrecise() public view returns (uint256) {
        (uint80 roundID, int price, , uint256 updatedAt, uint80 answeredInRound) = priceFeedETHUSD.latestRoundData();
        require(price >= 0 && (updatedAt >= block.timestamp - maxDelayTime) && answeredInRound >= roundID, "Invalid chainlink price");

        return (uint256(price) * (PRECISE_PRICE_PRECISION)) / (1e8); // ETH/USD is 8 decimals on Chainlink
    }

    function getTokenPrice(address token_address) public view returns (uint256 precise_price, uint256 short_price, uint256 eth_price) {
        // Get the token info
        TokenInfo memory thisTokenInfo = token_info[token_address];

        // Get the price for the underlying token
        (uint80 roundID, int price, , uint256 updatedAt, uint80 answeredInRound) = AggregatorV3Interface(thisTokenInfo.agg_addr_for_underlying).latestRoundData();
        require(price >= 0 && (updatedAt >= block.timestamp - maxDelayTime) && answeredInRound >= roundID, "Invalid chainlink price");
        
        uint256 agg_price = uint256(price);

        // Convert to USD, if not already
        if (thisTokenInfo.agg_other_side == 1) agg_price = (agg_price * getETHPricePrecise()) / PRECISE_PRICE_PRECISION;

        // cToken balance * pps = amt of underlying in native decimals
        uint256 price_per_share = 1;
        if (thisTokenInfo.underlying_tkn_address != address(0)){
            address pps_address_to_use = thisTokenInfo.token_address;
            if (thisTokenInfo.pps_override_address != address(0)) pps_address_to_use = thisTokenInfo.pps_override_address;
            (bool success, bytes memory data) = (pps_address_to_use).staticcall(abi.encodeWithSelector(thisTokenInfo.pps_call_selector));
            require(success, 'Oracle Failed');

            price_per_share = abi.decode(data, (uint256));
        }

        // E18
        uint256 pps_multiplier = (uint256(10) ** (thisTokenInfo.pps_decimals));

        // Handle difference in decimals()
        if (thisTokenInfo.ctkn_undrly_missing_decs < 0){
            uint256 ctkn_undr_miss_dec_mult = (10 ** uint256(-1 * thisTokenInfo.ctkn_undrly_missing_decs));
            precise_price = (agg_price * PRECISE_PRICE_PRECISION * price_per_share) / (ctkn_undr_miss_dec_mult * pps_multiplier * (uint256(10) ** (thisTokenInfo.agg_decimals)));
        }
        else {
            uint256 ctkn_undr_miss_dec_mult = (10 ** uint256(thisTokenInfo.ctkn_undrly_missing_decs));
            precise_price = (agg_price * PRECISE_PRICE_PRECISION * price_per_share * ctkn_undr_miss_dec_mult) / (pps_multiplier * (uint256(10) ** (thisTokenInfo.agg_decimals)));
        }
        
        // E6
        short_price = precise_price / PRICE_MISSING_MULTIPLIER;

        // ETH Price
        eth_price = (precise_price * PRECISE_PRICE_PRECISION) / getETHPricePrecise();
    }

    // Return token price in ETH, multiplied by 2**112
    function getETHPx112(address token_address) external view returns (uint256) {
        if (token_address == address(WETH) || token_address == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) return uint(2 ** 112);
        require(maxDelayTime != 0, 'Max delay time not set');

        // Get the ETH Price PRECISE_PRICE_PRECISION
        ( , , uint256 eth_price) = getTokenPrice(token_address);
        
        // Get the decimals
        uint decimals = uint(ERC20(token_address).decimals());

        // Scale to 2*112
        // Also divide by the token decimals (needed for the math. Nothing to do with missing decimals or anything)
        return (eth_price * (2 ** 112)) / (10 ** decimals);
    }

    /* ========== RESTRICTED GOVERNANCE FUNCTIONS ========== */

    function setTimelock(address _timelock_address) external onlyByOwnGov {
        timelock_address = _timelock_address;
    }

    function setMaxDelayTime(uint _maxDelayTime) external onlyByOwnGov {
        maxDelayTime = _maxDelayTime;
    }

    function batchSetOracleInfoDirect(TokenInfoConstructorArgs[] memory _initial_token_infos) external onlyByOwnGov {
        // Batch set token info
        for (uint256 i = 0; i < _initial_token_infos.length; i++){ 
            TokenInfoConstructorArgs memory this_token_info = _initial_token_infos[i];
            _setTokenInfo(
                this_token_info.token_address, 
                this_token_info.agg_addr_for_underlying, 
                this_token_info.agg_other_side, 
                this_token_info.underlying_tkn_address, 
                this_token_info.pps_override_address,
                this_token_info.pps_call_selector, 
                this_token_info.pps_decimals
            );
        }
    }

    // Sets oracle info for a token 
    // Chainlink Addresses
    // https://docs.chain.link/docs/ethereum-addresses/

    // exchangeRateStored: 0x182df0f5
    // getPricePerFullShare: 0x77c7b8fc
    // get_virtual_price: 0xbb7b8b80
    // getVirtualPrice: 0xe25aa5fa
    // pricePerShare: 0x99530b06

    // Function signature encoder
    //     web3_data.eth.abi.encodeFunctionSignature({
    //     name: 'getVirtualPrice',
    //     type: 'function',
    //     inputs: []
    // })
    //     web3_data.eth.abi.encodeFunctionSignature({
    //     name: 'myMethod',
    //     type: 'function',
    //     inputs: [{
    //         type: 'uint256',
    //         name: 'myNumber'
    //     }]
    // })

    // To burn something, for example, type this on app.frax.finance's JS console
    // https://web3js.readthedocs.io/en/v1.2.11/web3-eth-abi.html#encodefunctioncall
    // web3_data.eth.abi.encodeFunctionCall({
    //     name: 'burn',
    //     type: 'function',
    //     inputs: [{
    //         type: 'uint256',
    //         name: 'myNumber'
    //     }]
    // }, ['100940878321208298244715']);

    function _setTokenInfo(
        address token_address, 
        address agg_addr_for_underlying, 
        uint256 agg_other_side, // 0: USD, 1: ETH
        address underlying_tkn_address,
        address pps_override_address,
        bytes4 pps_call_selector,
        uint256 pps_decimals
    ) internal {
        // require(token_address != address(0), "Cannot add zero address");

        // See if there are any missing decimals between a cToken and the underlying
        int256 ctkn_undrly_missing_decs = 0;
        if (underlying_tkn_address != address(0)){
            uint256 cToken_decs = ERC20(token_address).decimals();
            uint256 underlying_decs = ERC20(underlying_tkn_address).decimals();

            ctkn_undrly_missing_decs = int256(cToken_decs) - int256(underlying_decs);
        }

        // Add the token address to the array if it doesn't already exist
        bool token_exists = false;
        for (uint i = 0; i < all_token_addresses.length; i++){ 
            if (all_token_addresses[i] == token_address) {
                token_exists = true;
                break;
            }
        }
        if (!token_exists) all_token_addresses.push(token_address);

        uint256 agg_decs = uint256(AggregatorV3Interface(agg_addr_for_underlying).decimals());

        string memory name_to_use;
        if (token_address == address(0)) {
            name_to_use = native_token_symbol;
        }
        else {
            name_to_use = ERC20(token_address).name();
        }

        // Add the token to the mapping
        token_info[token_address] = TokenInfo(
            token_address,
            ERC20(token_address).name(),
            agg_addr_for_underlying,
            agg_other_side,
            agg_decs,
            underlying_tkn_address,
            pps_override_address,
            pps_call_selector,
            pps_decimals,
            ctkn_undrly_missing_decs
        );
        has_info[token_address] = true;
    }

    function setTokenInfo(
        address token_address, 
        address agg_addr_for_underlying, 
        uint256 agg_other_side,
        address underlying_tkn_address,
        address pps_override_address,
        bytes4 pps_call_selector,
        uint256 pps_decimals
    ) public onlyByOwnGov {
        _setTokenInfo(token_address, agg_addr_for_underlying, agg_other_side, underlying_tkn_address, pps_override_address, pps_call_selector, pps_decimals);
    }

}


// File contracts/Misc_AMOs/solidly/IBaseV1Pair.sol


interface IBaseV1Pair {

  // Structure to capture time period obervations every 30 minutes, used for local oracles
  struct Observation {
      uint timestamp;
      uint reserve0Cumulative;
      uint reserve1Cumulative;
  }

  function allowance(address, address) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function balanceOf(address) external view returns (uint256);
  function blockTimestampLast() external view returns (uint256);
  function burn(address to) external returns (uint256 amount0, uint256 amount1);
  function claimFees() external returns (uint256 claimed0, uint256 claimed1);
  function claimable0(address) external view returns (uint256);
  function claimable1(address) external view returns (uint256);
  function current(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut);
  function currentCumulativePrices() external view returns (uint256 reserve0Cumulative, uint256 reserve1Cumulative, uint256 blockTimestamp);
  function decimals() external view returns (uint8);
  function fees() external view returns (address);
  function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
  function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast);
  function index0() external view returns (uint256);
  function index1() external view returns (uint256);
  function lastObservation() external view returns (Observation memory);
  function metadata() external view returns (uint256 dec0, uint256 dec1, uint256 r0, uint256 r1, bool st, address t0, address t1);
  function mint(address to) external returns (uint256 liquidity);
  function name() external view returns (string memory);
  function nonces(address) external view returns (uint256);
  function observationLength() external view returns (uint256);
  function observations(uint256) external view returns (uint256 timestamp, uint256 reserve0Cumulative, uint256 reserve1Cumulative);
  function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
  function prices(address tokenIn, uint256 amountIn, uint256 points) external view returns (uint256[] memory);
  function quote(address tokenIn, uint256 amountIn, uint256 granularity) external view returns (uint256 amountOut);
  function reserve0() external view returns (uint256);
  function reserve0CumulativeLast() external view returns (uint256);
  function reserve1() external view returns (uint256);
  function reserve1CumulativeLast() external view returns (uint256);
  function sample(address tokenIn, uint256 amountIn, uint256 points, uint256 window) external view returns (uint256[] memory);
  function skim(address to) external;
  function stable() external view returns (bool);
  function supplyIndex0(address) external view returns (uint256);
  function supplyIndex1(address) external view returns (uint256);
  function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data) external;
  function symbol() external view returns (string memory);
  function sync() external;
  function token0() external view returns (address);
  function token1() external view returns (address);
  function tokens() external view returns (address, address);
  function totalSupply() external view returns (uint256);
  function transfer(address dst, uint256 amount) external returns (bool);
  function transferFrom(address src, address dst, uint256 amount) external returns (bool);
}


// File contracts/Oracle/SolidlySingleLPOracle.sol


// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// =================== SolidlySingleLPOracle ===================
// ====================================================================
// Used to price a single Solidly LP Deposit Token

// Frax Finance: https://github.com/FraxFinance

// Primary Author(s)
// Travis Moore: https://github.com/FortisFortuna

// Reviewer(s) / Contributor(s)
// Jason Huan: https://github.com/jasonhuan
// Sam Kazemian: https://github.com/samkazemian





// ComboOracle

// Solidly

contract SolidlySingleLPOracle is Owned {
    using SafeMath for uint256;
    using HomoraMath for uint256;

    // Core
    address public timelock_address;
    address public bot_address;

    // LP related
    address private lp_token_address;
    IBaseV1Pair public pool;

    // Oracle info
    ComboOracle public combo_oracle;
    
    // Prices
    uint256 public price; // Always stored in E6
    uint256 public last_updated_time;

    // AggregatorV3Interface stuff
    uint8 public decimals; // For Chainlink mocking
    uint8 public padding_decs; // For Chainlink mocking
    string public description;
    uint256 public version = 1;

    // Precision
    uint256 public PRECISE_PRICE_PRECISION = 1e18;
    uint256 public PRICE_PRECISION = 1e6;
    uint256 public PRICE_MISSING_MULTIPLIER = 1e12;

    /* ========== MODIFIERS ========== */

    modifier onlyByOwnGov() {
        require(msg.sender == owner || msg.sender == timelock_address, "Not owner or timelock");
        _;
    }

    modifier onlyByOwnGovBot() {
        require(msg.sender == owner || msg.sender == timelock_address || msg.sender == bot_address, "Not owner, tlck, or bot");
        _;
    }

    /* ========== STRUCTS ========== */

    // ------------ UniV2 ------------

    struct UniV2LPBasicInfo {
        address lp_address;
        string token_name;
        string token_symbol;
        address token0;
        address token1;
        uint256 token0_decimals;
        uint256 token1_decimals;
        uint256 token0_reserves;
        uint256 token1_reserves;
        uint256 lp_total_supply;
    }

    struct UniV2PriceInfo {
        uint256 precise_price; 
        uint256 short_price; 
        string token_symbol;
        string token_name;
        string token0_symbol;
        string token1_symbol;
    }

    /* ========== CONSTRUCTOR ========== */

    constructor (
        address _creator_address,
        address _lp_token_address,
        address _oracle_address,
        address _timelock_address,
        uint8 _decimals,
        string memory _description
    ) Owned(_creator_address) {
        // Core
        timelock_address = _timelock_address;
        combo_oracle = ComboOracle(_oracle_address);

        // LP related
        lp_token_address = _lp_token_address;
        pool = IBaseV1Pair(_lp_token_address);

        // Chainlink mocking related
        decimals = _decimals;
        padding_decs = _decimals - uint8(6);

        description = _description;

        last_updated_time = block.timestamp;
    }

    /* ========== VIEWS ========== */

    // UniV2 / SLP Info
    function uniV2LPBasicInfo() public view returns (UniV2LPBasicInfo memory) {
        // Get the reserves
        (uint256 _reserve0, uint256 _reserve1, ) = (pool.getReserves());

        // Get the token1 address
        address token0 = pool.token0();
        address token1 = pool.token1();

        // Return
        return UniV2LPBasicInfo(
            lp_token_address, // [0]
            pool.name(), // [1]
            pool.symbol(), // [2]
            token0, // [3]
            token1, // [4]
            ERC20(token0).decimals(), // [5]
            ERC20(token1).decimals(), // [6]
            _reserve0, // [7]
            _reserve1, // [8]
            pool.totalSupply() // [9]
        );
    }

    // UniV2 / SLP LP Token Price
    // Alpha Homora Fair LP Pricing Method (flash loan resistant)
    // https://cmichel.io/pricing-lp-tokens/
    // https://blog.alphafinance.io/fair-lp-token-pricing/
    // https://github.com/AlphaFinanceLab/alpha-homora-v2-contract/blob/master/contracts/oracle/UniswapV2Oracle.sol
    function uniV2LPPriceInfo() public view returns (UniV2PriceInfo memory) {
        // Get info about the LP token
        UniV2LPBasicInfo memory lp_basic_info = uniV2LPBasicInfo();

        // Get the price of ETH in USD
        uint256 eth_price = combo_oracle.getETHPricePrecise();

        // Alpha Homora method
        uint256 precise_price;
        {
            uint sqrtK = HomoraMath.sqrt(lp_basic_info.token0_reserves * lp_basic_info.token1_reserves).fdiv(lp_basic_info.lp_total_supply); // in 2**112
            uint px0 = combo_oracle.getETHPx112(lp_basic_info.token0); // in 2**112
            uint px1 = combo_oracle.getETHPx112(lp_basic_info.token1); // in 2**112
            // fair token0 amt: sqrtK * sqrt(px1/px0)
            // fair token1 amt: sqrtK * sqrt(px0/px1)
            // fair lp price = 2 * sqrt(px0 * px1)
            // split into 2 sqrts multiplication to prevent uint overflow (note the 2**112)

            // In ETH per unit of LP, multiplied by 2**112.
            uint256 precise_price_eth112 = (((sqrtK * 2 * HomoraMath.sqrt(px0)) / (2 ** 56)) * HomoraMath.sqrt(px1)) / (2 ** 56);

            // In USD
            // Split into 2 parts to avoid overflows
            uint256 precise_price56 = precise_price_eth112 / (2 ** 56); 
            precise_price = (precise_price56 * eth_price) / (2 ** 56);
        }

        return UniV2PriceInfo(
            precise_price, // [0]
            precise_price / PRICE_MISSING_MULTIPLIER, // [1]
            lp_basic_info.token_symbol, // [2]
            lp_basic_info.token_name, // [3]
            ERC20(lp_basic_info.token0).symbol(), // [4]
            ERC20(lp_basic_info.token1).symbol() // [5]
        );
    }

    // In E18
    function getPrecisePrice() public view returns (uint256) {
        // Get the price info
        UniV2PriceInfo memory the_info = uniV2LPPriceInfo();

        return the_info.precise_price;
    }

    // In E6
    function getPrice() public view returns (uint256) {
        // Get the price info
        UniV2PriceInfo memory the_info = uniV2LPPriceInfo();

        return the_info.short_price;
    }

    // AggregatorV3Interface / Chainlink compatibility
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (0, int256(getPrecisePrice()), 0, block.timestamp, 0);
    }


    /* ========== RESTRICTED FUNCTIONS ========== */

    function setTimelock(address _new_timelock_address) external onlyByOwnGov {
        timelock_address = _new_timelock_address;
    }

    function setComboOracle(address _combo_oracle) external onlyByOwnGov {
        combo_oracle = ComboOracle(_combo_oracle);
    }
}