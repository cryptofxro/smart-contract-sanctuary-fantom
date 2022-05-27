/**
 *Submitted for verification at FtmScan.com on 2022-05-27
*/

// File contracts/OpenZeppelin/introspection/IERC165.sol

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

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

// File contracts/OpenZeppelin/token/ERC721/IERC721.sol

pragma solidity >=0.6.2 <0.8.0;

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

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
    function getApproved(uint256 tokenId)
        external
        view
        returns (address operator);

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
    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);

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

// File contracts/OpenZeppelin/token/ERC721/IERC721Receiver.sol

pragma solidity >=0.6.0 <0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// File contracts/OpenZeppelin/token/ERC721/ERC721Holder.sol

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721Holder is IERC721Receiver {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

// File contracts/OpenZeppelin/token/ERC20/IERC20.sol

pragma solidity >=0.4.0;

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the token name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the ERC token owner.
     */
    function getOwner() external view returns (address);

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
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address _owner, address spender)
        external
        view
        returns (uint256);

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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

// File contracts/OpenZeppelin/math/SafeMath.sol

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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
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
     *
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
     *
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
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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
     *
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
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// File contracts/OpenZeppelin/utils/Address.sol

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
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
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
    function functionCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
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
        return
            functionCallWithValue(
                target,
                data,
                value,
                "Address: low-level call with value failed"
            );
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
        require(
            address(this).balance >= value,
            "Address: insufficient balance for call"
        );
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{value: value}(
            data
        );
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data)
        internal
        view
        returns (bytes memory)
    {
        return
            functionStaticCall(
                target,
                data,
                "Address: low-level static call failed"
            );
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

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
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

// File contracts/OpenZeppelin/token/ERC20/SafeERC20.sol

pragma solidity ^0.6.0;

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

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
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
        // solhint-disable-next-line max-line-length
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(
            value
        );
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(
            value,
            "SafeERC20: decreased allowance below zero"
        );
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
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

        bytes memory returndata = address(token).functionCall(
            data,
            "SafeERC20: low-level call failed"
        );
        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(
                abi.decode(returndata, (bool)),
                "SafeERC20: ERC20 operation did not succeed"
            );
        }
    }
}

// File contracts/OpenZeppelin/GSN/Context.sol

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

// File contracts/OpenZeppelin/utils/EnumerableSet.sol

pragma solidity >=0.6.0 <0.8.0;

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

            // When the value to delete is the last one, the swap operation is unnecessary. However, since this occurs
            // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

            bytes32 lastvalue = set._values[lastIndex];

            // Move the last value to the index where the value to delete is
            set._values[toDeleteIndex] = lastvalue;
            // Update the index for the moved value
            set._indexes[lastvalue] = toDeleteIndex + 1; // All indexes are 1-based

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
    function _contains(Set storage set, bytes32 value)
        private
        view
        returns (bool)
    {
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
    function _at(Set storage set, uint256 index)
        private
        view
        returns (bytes32)
    {
        require(
            set._values.length > index,
            "EnumerableSet: index out of bounds"
        );
        return set._values[index];
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
    function add(Bytes32Set storage set, bytes32 value)
        internal
        returns (bool)
    {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value)
        internal
        returns (bool)
    {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value)
        internal
        view
        returns (bool)
    {
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
    function at(Bytes32Set storage set, uint256 index)
        internal
        view
        returns (bytes32)
    {
        return _at(set._inner, index);
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
    function add(AddressSet storage set, address value)
        internal
        returns (bool)
    {
        return _add(set._inner, bytes32(uint256(value)));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value)
        internal
        returns (bool)
    {
        return _remove(set._inner, bytes32(uint256(value)));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value)
        internal
        view
        returns (bool)
    {
        return _contains(set._inner, bytes32(uint256(value)));
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
    function at(AddressSet storage set, uint256 index)
        internal
        view
        returns (address)
    {
        return address(uint256(_at(set._inner, index)));
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
    function remove(UintSet storage set, uint256 value)
        internal
        returns (bool)
    {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value)
        internal
        view
        returns (bool)
    {
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
    function at(UintSet storage set, uint256 index)
        internal
        view
        returns (uint256)
    {
        return uint256(_at(set._inner, index));
    }
}

// File contracts/OpenZeppelin/access/AccessControl.sol

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControl is Context {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Address for address;

    struct RoleData {
        EnumerableSet.AddressSet members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(
        bytes32 indexed role,
        bytes32 indexed previousAdminRole,
        bytes32 indexed newAdminRole
    );

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {_setupRole}.
     */
    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].members.contains(account);
    }

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) public view returns (uint256) {
        return _roles[role].members.length();
    }

    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index)
        public
        view
        returns (address)
    {
        return _roles[role].members.at(index);
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public virtual {
        require(
            hasRole(_roles[role].adminRole, _msgSender()),
            "AccessControl: sender must be an admin to grant"
        );

        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual {
        require(
            hasRole(_roles[role].adminRole, _msgSender()),
            "AccessControl: sender must be an admin to revoke"
        );

        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual {
        require(
            account == _msgSender(),
            "AccessControl: can only renounce roles for self"
        );

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        emit RoleAdminChanged(role, _roles[role].adminRole, adminRole);
        _roles[role].adminRole = adminRole;
    }

    function _grantRole(bytes32 role, address account) private {
        if (_roles[role].members.add(account)) {
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function _revokeRole(bytes32 role, address account) private {
        if (_roles[role].members.remove(account)) {
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

// File contracts/OpenZeppelin/utils/Counters.sol

pragma solidity >=0.6.0 <0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented or decremented by one. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 * Since it is not possible to overflow a 256 bit integer with increments of one, `increment` can skip the {SafeMath}
 * overflow check, thereby saving gas. This does assume however correct usage, in that the underlying `_value` is never
 * directly accessed.
 */
library Counters {
    using SafeMath for uint256;

    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        // The {SafeMath} overflow check can be skipped here, see the comment at the top
        counter._value += 1;
    }

    function decrement(Counter storage counter) internal {
        counter._value = counter._value.sub(1);
    }
}

// File contracts/interfaces/IMasterFarmer.sol

pragma solidity 0.6.12;

interface IMasterFarmer {
    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function enterStaking(uint256 _amount) external;

    function leaveStaking(uint256 _amount) external;

    function pendingWigo(uint256 _pid, address _user)
        external
        view
        returns (uint256);

    function userInfo(uint256 _pid, address _user)
        external
        view
        returns (uint256, uint256);

    function wigoBurn(uint256 _amount) external;

    function emergencyWithdraw(uint256 _pid) external;
}

// File contracts/WigoGalaxy.sol

pragma solidity 0.6.12;

contract WigoGalaxy is AccessControl, ERC721Holder {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC20 public wigoToken;
    IMasterFarmer public masterFarmer;

    bytes32 public constant NFT_ROLE = keccak256("NFT_ROLE");
    bytes32 public constant POINT_ROLE = keccak256("POINT_ROLE");
    bytes32 public constant SPECIAL_ROLE = keccak256("SPECIAL_ROLE");
    uint256 public constant MAX_REFERRAL_SHARE = 80; // 80%

    uint256 public numberActiveProfiles;
    uint256 public numberWigoToReactivate;
    uint256 public numberWigoToRegister;
    uint256 public numberWigoToUpdate;
    uint256 public numberPlanets;
    uint256 public referralFeeShare = 40; // 40%
    uint256 public referralPointShare = 10; // 10%

    mapping(address => bool) public hasRegistered;

    mapping(uint256 => Planet) private planets;
    mapping(address => Resident) private residents;
    mapping(uint256 => Referral) private referrals;

    // Used for generating the planetId
    Counters.Counter private _countPlanets;

    // Used for generating the residentId
    Counters.Counter private _countResidents;

    // Event to notify a new planet is created
    event PlanetAdd(uint256 planetId, string planetName);

    // Event to notify that planet power is increased
    event PlanetPowerIncrease(
        uint256 indexed planetId,
        uint256 power,
        uint256 indexed campaignId
    );

    event ResidentChangePlanet(
        address indexed residentAddress,
        uint256 oldPlanetId,
        uint256 newPlanetId
    );

    // Event to notify that a resident is registered
    event ResidentNew(
        address indexed residentAddress,
        uint256 planetId,
        address nftAddress,
        uint256 tokenId
    );

    // Event to notify a resident pausing her profile
    event ResidentPause(address indexed residentAddress, uint256 planetId);

    // Event to notify that resident points are increased
    event ResidentPointIncrease(
        address indexed residentAddress,
        uint256 numberPoints,
        uint256 indexed campaignId
    );

    // Event to notify that a list of residents have an increase in points
    event ResidentPointIncreaseMultiple(
        address[] residentAddresses,
        uint256 numberPoints,
        uint256 indexed campaignId
    );

    // Event to notify that a resident is reactivating her profile
    event ResidentReactivate(
        address indexed residentAddress,
        uint256 planetId,
        address nftAddress,
        uint256 tokenId
    );

    // Event to notify that a resident is pausing her profile
    event ResidentUpdate(
        address indexed residentAddress,
        address nftAddress,
        uint256 tokenId
    );

    // Event to notify new referral share
    event SetReferralShare(
        address indexed sender,
        uint256 indexed newReferralFeeShare,
        uint256 indexed newReferralPointShare
    );

    // Modifier for admin roles
    modifier onlyOwner() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Not the main admin"
        );
        _;
    }

    // Modifier for point roles
    modifier onlyPoint() {
        require(hasRole(POINT_ROLE, _msgSender()), "Not a point admin");
        _;
    }

    // Modifier for special roles
    modifier onlySpecial() {
        require(hasRole(SPECIAL_ROLE, _msgSender()), "Not a special admin");
        _;
    }

    struct Planet {
        string planetName;
        string planetDescription;
        uint256 numberResidents;
        uint256 power;
        bool isJoinable;
    }

    struct Resident {
        uint256 residentId;
        uint256 numberPoints;
        uint256 planetId;
        address nftAddress;
        uint256 tokenId;
        uint256 referral;
        bool isActive;
    }

    struct Referral {
        address residentAddress;
        uint256 totalReferred;
        uint256 totalEarn;
    }

    constructor(
        IERC20 _wigoToken,
        IMasterFarmer _masterFarmer,
        uint256 _numberWigoToReactivate,
        uint256 _numberWigoToRegister,
        uint256 _numberWigoToUpdate
    ) public {
        wigoToken = _wigoToken;
        masterFarmer = _masterFarmer;
        numberWigoToReactivate = _numberWigoToReactivate;
        numberWigoToRegister = _numberWigoToRegister;
        numberWigoToUpdate = _numberWigoToUpdate;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @dev To create a resident profile. It sends the NFT to the contract
     * and sends WIGO to wigoBurn function on MasterFarmer.
     */
    function createProfile(
        uint256 _planetId,
        address _nftAddress,
        uint256 _tokenId,
        uint256 _referralId
    ) external {
        require(!hasRegistered[_msgSender()], "Already registered");
        require(
            (_planetId <= numberPlanets) && (_planetId > 0),
            "Invalid planetId"
        );
        require(planets[_planetId].isJoinable, "Planet not joinable");
        require(hasRole(NFT_ROLE, _nftAddress), "NFT address invalid");
        if (_referralId != 0) {
            address referralAddress = referrals[_referralId].residentAddress;
            require(hasRegistered[referralAddress], "Referral doesn't exist");
        }

        // Loads the interface to deposit the NFT contract
        IERC721 nftToken = IERC721(_nftAddress);

        require(
            _msgSender() == nftToken.ownerOf(_tokenId),
            "Only NFT owner can register"
        );

        // Transfer NFT to this contract
        nftToken.safeTransferFrom(_msgSender(), address(this), _tokenId);

        // Transfer WIGO tokens to this contract
        wigoToken.safeTransferFrom(
            _msgSender(),
            address(this),
            numberWigoToRegister
        );
        if (_referralId != 0) {
            address referralAddress = referrals[_referralId].residentAddress;
            // Send rewards to referral
            wigoToken.safeTransfer(
                referralAddress,
                (referralFeeShare.mul(numberWigoToRegister)).div(100)
            );

            // Burn WIGO tokens from this contract
            IMasterFarmer(masterFarmer).wigoBurn(
                ((100 - referralFeeShare).mul(numberWigoToRegister)).div(100)
            );

            referrals[_referralId].totalReferred = referrals[_referralId]
                .totalReferred
                .add(1);

            referrals[_referralId].totalEarn = referrals[_referralId]
                .totalEarn
                .add((referralFeeShare.mul(numberWigoToRegister)).div(100));
        } else {
            // Burn WIGO tokens from this contract
            IMasterFarmer(masterFarmer).wigoBurn(numberWigoToRegister);
        }

        // Increment the _countResidents counter and get residentId
        _countResidents.increment();
        uint256 newResidentId = _countResidents.current();

        // Add data to the struct for newResidentId
        residents[_msgSender()] = Resident({
            residentId: newResidentId,
            numberPoints: 0,
            planetId: _planetId,
            nftAddress: _nftAddress,
            tokenId: _tokenId,
            referral: _referralId,
            isActive: true
        });

        // Add data to the struct for newResidentId
        referrals[newResidentId] = Referral({
            residentAddress: _msgSender(),
            totalReferred: 0,
            totalEarn: 0
        });

        // Update registration status
        hasRegistered[_msgSender()] = true;

        // Update number of active profiles
        numberActiveProfiles = numberActiveProfiles.add(1);

        // Increase the number of residents for the planet
        planets[_planetId].numberResidents = planets[_planetId]
            .numberResidents
            .add(1);

        // Emit an event
        emit ResidentNew(_msgSender(), _planetId, _nftAddress, _tokenId);
    }

    /**
     * @dev To pause resident profile. It releases the NFT.
     * Callable only by registered residents.
     */
    function pauseProfile() external {
        require(hasRegistered[_msgSender()], "Has not registered");

        // Checks whether resident has already paused
        require(residents[_msgSender()].isActive, "Resident not active");

        // Change status of resident to make it inactive
        residents[_msgSender()].isActive = false;

        // Retrieve the planetId of the resident calling
        uint256 residentPlanetId = residents[_msgSender()].planetId;

        // Reduce number of active residents and planet residents
        planets[residentPlanetId].numberResidents = planets[residentPlanetId]
            .numberResidents
            .sub(1);
        numberActiveProfiles = numberActiveProfiles.sub(1);

        // Interface to deposit the NFT contract
        IERC721 nftToken = IERC721(residents[_msgSender()].nftAddress);

        // tokenId of NFT redeemed
        uint256 redeemedTokenId = residents[_msgSender()].tokenId;

        // Change internal statuses as extra safety
        residents[_msgSender()].nftAddress = address(
            0x0000000000000000000000000000000000000000
        );

        residents[_msgSender()].tokenId = 0;

        // Transfer the NFT back to the resident
        nftToken.safeTransferFrom(address(this), _msgSender(), redeemedTokenId);

        // Emit event
        emit ResidentPause(_msgSender(), residentPlanetId);
    }

    /**
     * @dev To update resident profile.
     * Callable only by registered residents.
     */
    function updateProfile(address _nftAddress, uint256 _tokenId) external {
        require(hasRegistered[_msgSender()], "Has not registered");
        require(hasRole(NFT_ROLE, _nftAddress), "NFT address invalid");
        require(residents[_msgSender()].isActive, "Resident not active");

        address currentAddress = residents[_msgSender()].nftAddress;
        uint256 currentTokenId = residents[_msgSender()].tokenId;

        // Interface to deposit the NFT contract
        IERC721 nftNewToken = IERC721(_nftAddress);

        require(
            _msgSender() == nftNewToken.ownerOf(_tokenId),
            "Only NFT owner can update"
        );

        // Transfer token to new address
        nftNewToken.safeTransferFrom(_msgSender(), address(this), _tokenId);

        // Transfer WIGO token to this address
        wigoToken.safeTransferFrom(
            _msgSender(),
            address(this),
            numberWigoToUpdate
        );

        // Burn WIGO tokens from this contract
        IMasterFarmer(masterFarmer).wigoBurn(numberWigoToUpdate);

        // Interface to deposit the NFT contract
        IERC721 nftCurrentToken = IERC721(currentAddress);

        // Transfer old token back to the owner
        nftCurrentToken.safeTransferFrom(
            address(this),
            _msgSender(),
            currentTokenId
        );

        // Update mapping in storage
        residents[_msgSender()].nftAddress = _nftAddress;
        residents[_msgSender()].tokenId = _tokenId;

        emit ResidentUpdate(_msgSender(), _nftAddress, _tokenId);
    }

    /**
     * @dev To reactivate resident profile.
     * Callable only by registered residents.
     */
    function reactivateProfile(address _nftAddress, uint256 _tokenId) external {
        require(hasRegistered[_msgSender()], "Has not registered");
        require(hasRole(NFT_ROLE, _nftAddress), "NFT address invalid");
        require(!residents[_msgSender()].isActive, "Resident is active");

        // Interface to deposit the NFT contract
        IERC721 nftToken = IERC721(_nftAddress);
        require(
            _msgSender() == nftToken.ownerOf(_tokenId),
            "Only NFT owner can update"
        );

        // Transfer to this address
        wigoToken.safeTransferFrom(
            _msgSender(),
            address(this),
            numberWigoToReactivate
        );

        // Burn WIGO tokens from this contract
        IMasterFarmer(masterFarmer).wigoBurn(numberWigoToReactivate);

        // Transfer NFT to contract
        nftToken.safeTransferFrom(_msgSender(), address(this), _tokenId);

        // Retrieve planetId of the resident
        uint256 residentPlanetId = residents[_msgSender()].planetId;

        // Update number of residents for the planet and number of active profiles
        planets[residentPlanetId].numberResidents = planets[residentPlanetId]
            .numberResidents
            .add(1);
        numberActiveProfiles = numberActiveProfiles.add(1);

        // Update resident statuses
        residents[_msgSender()].isActive = true;
        residents[_msgSender()].nftAddress = _nftAddress;
        residents[_msgSender()].tokenId = _tokenId;

        // Emit event
        emit ResidentReactivate(
            _msgSender(),
            residentPlanetId,
            _nftAddress,
            _tokenId
        );
    }

    /**
     * @dev To increase the number of points for a resident.
     * Callable only by point admins
     */
    function increaseResidentPoints(
        address _residentAddress,
        uint256 _numberPoints,
        uint256 _campaignId,
        bool _withReferral
    ) external onlyPoint {
        if (_withReferral && residents[_residentAddress].referral != 0) {
            address referralAddress = referrals[
                residents[_residentAddress].referral
            ].residentAddress;
            // Increase the number of points for the referral
            residents[referralAddress].numberPoints = residents[referralAddress]
                .numberPoints
                .add((referralPointShare.mul(_numberPoints)).div(100));
        }
        // Increase the number of points for the resident
        residents[_residentAddress].numberPoints = residents[_residentAddress]
            .numberPoints
            .add(_numberPoints);

        emit ResidentPointIncrease(
            _residentAddress,
            _numberPoints,
            _campaignId
        );
    }

    /**
     * @dev To increase the number of points for a set of residents.
     * Callable only by point admins
     */
    function increaseResidentPointsMultiple(
        address[] calldata _residentAddresses,
        uint256 _numberPoints,
        uint256 _campaignId,
        bool _withReferral
    ) external onlyPoint {
        require(_residentAddresses.length < 1001, "Length must be < 1001");
        for (uint256 i = 0; i < _residentAddresses.length; i++) {
            if (
                _withReferral && residents[_residentAddresses[i]].referral != 0
            ) {
                address referralAddress = referrals[
                    residents[_residentAddresses[i]].referral
                ].residentAddress;
                // Increase the number of points for the referral
                residents[referralAddress].numberPoints = residents[
                    referralAddress
                ].numberPoints.add(
                        (referralPointShare.mul(_numberPoints)).div(100)
                    );
            }

            residents[_residentAddresses[i]].numberPoints = residents[
                _residentAddresses[i]
            ].numberPoints.add(_numberPoints);
        }
        emit ResidentPointIncreaseMultiple(
            _residentAddresses,
            _numberPoints,
            _campaignId
        );
    }

    /**
     * @dev To increase power for a planet.
     * Callable only by point admins
     */

    function increasePlanetPower(
        uint256 _planetId,
        uint256 _power,
        uint256 _campaignId
    ) external onlyPoint {
        // Increase power for the planet
        planets[_planetId].power = planets[_planetId].power.add(_power);

        emit PlanetPowerIncrease(_planetId, _power, _campaignId);
    }

    /**
     * @dev To remove the number of points for a resident.
     * Callable only by point admins
     */
    function removeResidentPoints(
        address _residentAddress,
        uint256 _numberPoints
    ) external onlyPoint {
        // Increase the number of points for the resident
        residents[_residentAddress].numberPoints = residents[_residentAddress]
            .numberPoints
            .sub(_numberPoints);
    }

    /**
     * @dev To remove a set number of points for a set of residents.
     */
    function removeResidentPointsMultiple(
        address[] calldata _residentAddresses,
        uint256 _numberPoints
    ) external onlyPoint {
        require(_residentAddresses.length < 1001, "Length must be < 1001");
        for (uint256 i = 0; i < _residentAddresses.length; i++) {
            residents[_residentAddresses[i]].numberPoints = residents[
                _residentAddresses[i]
            ].numberPoints.sub(_numberPoints);
        }
    }

    /**
     * @dev To decrease power for a planet.
     * Callable only by point admins
     */

    function decreasePlanetPower(uint256 _planetId, uint256 _power)
        external
        onlyPoint
    {
        // Decrease power for the planet
        planets[_planetId].power = planets[_planetId].power.sub(_power);
    }

    /**
     * @dev To add a NFT contract address for residents to set their profile.
     * Callable only by owner admins.
     */
    function addNftAddress(address _nftAddress) external onlyOwner {
        require(
            IERC721(_nftAddress).supportsInterface(0x80ac58cd),
            "Not ERC721"
        );
        grantRole(NFT_ROLE, _nftAddress);
    }

    /**
     * @dev Add a new planetId
     * Callable only by owner admins.
     */
    function addPlanet(
        string calldata _planetName,
        string calldata _planetDescription
    ) external onlyOwner {
        // Verify length is between 3 and 16
        bytes memory strBytes = bytes(_planetName);
        require(strBytes.length < 20, "Must be < 20");
        require(strBytes.length > 3, "Must be > 3");

        // Increment the _countPlanets counter and get planetId
        _countPlanets.increment();
        uint256 newPlanetId = _countPlanets.current();

        // Add new planet data to the struct
        planets[newPlanetId] = Planet({
            planetName: _planetName,
            planetDescription: _planetDescription,
            numberResidents: 0,
            power: 0,
            isJoinable: true
        });

        numberPlanets = newPlanetId;
        emit PlanetAdd(newPlanetId, _planetName);
    }

    /**
     * @dev Function to change planet.
     * Callable only by special admins.
     */
    function changePlanet(address _residentAddress, uint256 _newPlanetId)
        external
        onlySpecial
    {
        require(hasRegistered[_residentAddress], "Resident doesn't exist");
        require(
            (_newPlanetId <= numberPlanets) && (_newPlanetId > 0),
            "planetId doesn't exist"
        );
        require(planets[_newPlanetId].isJoinable, "Planet not joinable");
        require(
            residents[_residentAddress].planetId != _newPlanetId,
            "Already in the planet"
        );

        // Get old planetId
        uint256 oldPlanetId = residents[_residentAddress].planetId;

        // Change number of residents in old planet
        planets[oldPlanetId].numberResidents = planets[oldPlanetId]
            .numberResidents
            .sub(1);

        // Change planetId in resident mapping
        residents[_residentAddress].planetId = _newPlanetId;

        // Change number of residents in new planet
        planets[_newPlanetId].numberResidents = planets[_newPlanetId]
            .numberResidents
            .add(1);

        emit ResidentChangePlanet(_residentAddress, oldPlanetId, _newPlanetId);
    }

    /**
     * @dev to burn fee manually.
     * Callable only by owner admins.
     */
    function burnFee(uint256 _amount) external onlyOwner {
        IMasterFarmer(masterFarmer).wigoBurn(_amount);
    }

    /**
     * @dev Make a planet joinable again.
     * Callable only by owner admins.
     */
    function makePlanetJoinable(uint256 _planetId) external onlyOwner {
        require(
            (_planetId <= numberPlanets) && (_planetId > 0),
            "planetId invalid"
        );
        planets[_planetId].isJoinable = true;
    }

    /**
     * @dev Make a planet not joinable.
     * Callable only by owner admins.
     */
    function makePlanetNotJoinable(uint256 _planetId) external onlyOwner {
        require(
            (_planetId <= numberPlanets) && (_planetId > 0),
            "planetId invalid"
        );
        planets[_planetId].isJoinable = false;
    }

    /**
     * @dev Rename a planet
     * Callable only by owner admins.
     */
    function renamePlanet(
        uint256 _planetId,
        string calldata _planetName,
        string calldata _planetDescription
    ) external onlyOwner {
        require(
            (_planetId <= numberPlanets) && (_planetId > 0),
            "planetId invalid"
        );

        // Verify length is between 3 and 16
        bytes memory strBytes = bytes(_planetName);
        require(strBytes.length < 20, "Must be < 20");
        require(strBytes.length > 3, "Must be > 3");

        planets[_planetId].planetName = _planetName;
        planets[_planetId].planetDescription = _planetDescription;
    }

    /**
     * @dev Update the number of WIGO to register
     * Callable only by owner admins.
     */
    function updateNumberWigo(
        uint256 _newNumberWigoToReactivate,
        uint256 _newNumberWigoToRegister,
        uint256 _newNumberWigoToUpdate
    ) external onlyOwner {
        numberWigoToReactivate = _newNumberWigoToReactivate;
        numberWigoToRegister = _newNumberWigoToRegister;
        numberWigoToUpdate = _newNumberWigoToUpdate;
    }

    /**
     * @notice Sets referral share
     * @dev Callable only by owner admins.
     */
    function setReferralShare(
        uint256 _referralFeeShare,
        uint256 _referralPointShare
    ) external onlyOwner {
        require(
            _referralFeeShare <= MAX_REFERRAL_SHARE,
            "referralFeeShare cannot be more than MAX_REFERRAL_SHARE"
        );
        require(
            _referralPointShare <= MAX_REFERRAL_SHARE,
            "referralPointShare cannot be more than MAX_REFERRAL_SHARE"
        );
        referralFeeShare = _referralFeeShare;
        referralPointShare = _referralPointShare;
        emit SetReferralShare(
            msg.sender,
            _referralFeeShare,
            _referralPointShare
        );
    }

    /**
     * @dev Check the resident's profile for a given address
     */
    function getResidentProfile(address _residentAddress)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            address,
            uint256,
            uint256,
            bool
        )
    {
        require(hasRegistered[_residentAddress], "Not registered");
        return (
            residents[_residentAddress].residentId,
            residents[_residentAddress].numberPoints,
            residents[_residentAddress].planetId,
            residents[_residentAddress].nftAddress,
            residents[_residentAddress].tokenId,
            residents[_residentAddress].referral,
            residents[_residentAddress].isActive
        );
    }

    /**
     * @dev Check the resident's status for a given address
     */
    function getResidentStatus(address _residentAddress)
        external
        view
        returns (bool)
    {
        return (residents[_residentAddress].isActive);
    }

    /**
     * @dev Check a planet's profile
     */
    function getPlanetProfile(uint256 _planetId)
        external
        view
        returns (
            string memory,
            string memory,
            uint256,
            uint256,
            bool
        )
    {
        require(
            (_planetId <= numberPlanets) && (_planetId > 0),
            "planetId invalid"
        );
        return (
            planets[_planetId].planetName,
            planets[_planetId].planetDescription,
            planets[_planetId].numberResidents,
            planets[_planetId].power,
            planets[_planetId].isJoinable
        );
    }

    /**
     * @dev Check a referral data
     */
    function getReferralData(uint256 _referralId)
        external
        view
        returns (uint256, uint256)
    {
        require(_referralId != 0, "Referral doesn't exist");

        address referralAddress = referrals[_referralId].residentAddress;
        require(hasRegistered[referralAddress], "Referral doesn't exist");
        return (
            referrals[_referralId].totalReferred,
            referrals[_referralId].totalEarn
        );
    }
}