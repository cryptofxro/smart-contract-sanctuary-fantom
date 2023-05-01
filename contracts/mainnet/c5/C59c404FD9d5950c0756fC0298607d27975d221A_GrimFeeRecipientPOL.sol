/**
 *Submitted for verification at FtmScan.com on 2023-04-27
*/

// File contracts/interfaces/IGrimVaultV2.sol


pragma solidity 0.8.17;

interface IGrimVaultV2 {
    function deposit(uint256 amount) external;
    function depositAll() external;
    function withdraw(uint256 amount) external;
    function withdrawAll() external;
    function balanceOf(address user) external view returns (uint256);
}


// File contracts/interfaces/IUniRouter.sol


pragma solidity 0.8.17;

interface IUniRouter {

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}


// File contracts/interfaces/ISolidlyRouter.sol


pragma solidity 0.8.17;

interface ISolidlyRouter {

    // Routes
    struct Routes {
        address from;
        address to;
        bool stable;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

     function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        bool stable,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    function swapExactTokensForTokensSimple(
        uint amountIn,
        uint amountOutMin,
        address tokenFrom,
        address tokenTo,
        bool stable,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

     function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        Routes[] memory route,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        Routes[] calldata routes,
        address to,
        uint deadline
    ) external;

    function getAmountOut(uint amountIn, address tokenIn, address tokenOut) external view returns (uint amount, bool stable);
    function getAmountsOut(uint amountIn, Routes[] memory routes) external view returns (uint[] memory amounts);
    function pairFor(address tokenA, address tokenB, bool stable) external view returns (address pair);

}


// File contracts/interfaces/IVeToken.sol

pragma solidity 0.8.17;

interface IVeToken {
    function ownerOf(uint) external view returns (address);
    function create_lock(uint _value, uint _lock_duration) external returns (uint);
    function withdraw(uint _tokenId) external;
    function increase_amount(uint _tokenId, uint _value) external;
    function increase_unlock_time(uint _tokenId, uint _lock_duration) external;
    function merge(uint _from, uint _to) external;
    function locked(uint) external view returns (uint256, uint256);
    function reset() external;
}


// File contracts/interfaces/IWETH.sol

pragma solidity 0.8.17;

interface IWETH {
    function deposit(uint256 amount) external payable;
}


// File contracts/interfaces/IVoter.sol

pragma solidity 0.8.17;

interface IVoter {
    function vote(uint tokenId, address[] calldata _poolVote, int256[] calldata _weights) external;
    function claimable(address _account) external view returns(uint256);
    function claimBribes(address[] calldata bribes, address[][] calldata _tokens, uint256 _tokenId) external;
    function claimRewards(address[] calldata _gauges, address[][] calldata _tokens) external;
}


// File contracts/interfaces/IBribe.sol

pragma solidity 0.8.17;

interface IBribe {
    function _deposit(uint amount, uint tokenId) external;
    function _withdraw(uint amount, uint tokenId) external;
    function getRewardForOwner(uint tokenId, address[] memory tokens) external;
    function notifyRewardAmount(address token, uint amount) external;
    function earned(address token, uint tokenId) external view returns (uint);
}


// File contracts/interfaces/IRecipient.sol

pragma solidity 0.8.17;

interface IRecipient {
    function oldRecipient() external view returns(address);
}


// File @openzeppelin/contracts/token/ERC721/[email protected]

// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity >=0.8.0 <=0.9.0;

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
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}


// File @openzeppelin/contracts/utils/[email protected]

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity >=0.8.0 <=0.9.0;

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


// File @openzeppelin/contracts/access/[email protected]

// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity >=0.8.0 <=0.9.0;

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


// File @openzeppelin/contracts/token/ERC20/[email protected]

// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity >=0.8.0 <=0.9.0;

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


// File @openzeppelin/contracts/utils/[email protected]

// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity >=0.8.0 <=0.9.0;

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


// File @openzeppelin/contracts/utils/[email protected]

// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity >=0.8.0 <=0.9.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}


// File @openzeppelin/contracts/utils/introspection/[email protected]

// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity >=0.8.0 <=0.9.0;

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


// File @openzeppelin/contracts/token/ERC721/[email protected]

// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

pragma solidity >=0.8.0 <=0.9.0;

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

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}


// File @openzeppelin/contracts/utils/introspection/[email protected]

// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}


// File @openzeppelin/contracts/token/ERC721/extensions/[email protected]

// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity >=0.8.0 <=0.9.0;

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}


// File @openzeppelin/contracts/token/ERC721/[email protected]

// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/ERC721.sol)

pragma solidity >=0.8.0 <=0.9.0;







/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Reverts if the `tokenId` has not been minted yet.
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}


// File @openzeppelin/contracts/token/ERC20/extensions/[email protected]

// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity >=0.8.0 <=0.9.0;

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


// File @openzeppelin/contracts/token/ERC20/utils/[email protected]

// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity >=0.8.0 <=0.9.0;



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


// File contracts/GrimFeeRecipientPOL.sol

/**
Grim Finance POL feeRecipient. Comptroller for veNFT, Bribing, Voting & POL management.
Version 1.0

@author Nikar0 - https://www.github.com/nikar0 - https://twitter.com/Nikar0_

https://app.grim.finance - https://twitter.com/FinanceGrim
**/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;
contract GrimFeeRecipientPOL is Ownable {
    using SafeERC20 for IERC20;

    /** EVENTS **/
    event Buyback(uint256 indexed evoBuyBack);
    event AddPOL(uint256 indexed amount);
    event SubPOL(uint256 indexed amount);
    event PolRebalance(address indexed from, uint256 indexed amount);
    event EvoBribe(uint256 indexed amount);
    event MixedBribe(address[] indexed tokens, uint256[] indexed amounts);
    event Vote(address[] indexed poolsVoted, int256[] indexed weights);
    event CreateLock(uint256 indexed amount);
    event AddLockAmount(uint256 indexed amount);
    event AddLockTime(uint256 indexed lockTimeAdded);
    event NftIDInUse(uint256 indexed id);
    event SetUniCustomPathAndRouter(address[] indexed custompath, address indexed newRouter);
    event SetSolidlyCustomPathAndRouter(ISolidlyRouter.Routes[] indexed customPath, address indexed newRouter);
    event StuckToken(address indexed stuckToken);
    event SetTreasury(address indexed newTreasury);
    event SetStrategist(address indexed newStrategist);
    event SetBribeContract(address indexed newBribeContract);
    event SetGrimVault(address indexed newVault);
    event ExitFromContract(uint256 indexed nftId, address indexed newFeeRecipient);

    /** TOKENS **/
    address public constant wftm = address(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    address public constant grimEvo = address(0x0a77866C01429941BFC7854c0c0675dB1015218b);
    address public constant equal = address(0x3Fd3A0c85B70754eFc07aC9Ac0cbBDCe664865A6);
    address public constant veToken = address(0x8313f3551C4D3984FfbaDFb42f780D0c8763Ce94);
    address public constant evoLP = address(0x5462F8c029ab3461d1784cE8B6F6004f6F6E2Fd4);
    address public stableToken = address(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75);


    /**PROTOCOL ADDRESSES **/
    address public evoVault = address(0xb2cf157bA7B44922B30732ba0E98B95913c266A4);
    address public treasury = address(0xfAE236b4E261278C2B84e74b4631cf7BCAFca06d);
    address private strategist;

    /** 3RD PARTY ADDRESSES **/
    address public bribeContract = address(0x18EB9dAdbA5EAB20b16cfC0DD90a92AF303477B1);
    address public voter = address(0x4bebEB8188aEF8287f9a7d1E4f01d76cBE060d5b);
    address public solidlyRouter = address(0x2aa07920E4ecb4ea8C801D9DFEce63875623B285);
    address public unirouter;

    /** PATHS **/
    address[] public ftmToGrimEvoUniPath;
    address[] public customUniPath;
    ISolidlyRouter.Routes[] public wftmToGrimEvoPath;
    ISolidlyRouter.Routes[] public equalToGrimEvoPath;
    ISolidlyRouter.Routes[] public customSolidlyPath;

    //* RECORD KEEPING **/
    uint256 public nftID;
    uint256 public lastVote;
    address[] public lastBribes;

    constructor (
        ISolidlyRouter.Routes[] memory _wftmToGrimEvoPath,
        ISolidlyRouter.Routes[] memory _equalToGrimEvoPath
    )  {

        for (uint i; i < _equalToGrimEvoPath.length; ++i) {
            equalToGrimEvoPath.push(_equalToGrimEvoPath[i]);
        }

        for (uint i; i < _wftmToGrimEvoPath.length; ++i) {
            wftmToGrimEvoPath.push(_wftmToGrimEvoPath[i]);
        }

        ftmToGrimEvoUniPath = [wftm, grimEvo];
        strategist = msg.sender;
    }

    /** SETTERS **/
    function setBribeContract(address _bribeContract) external onlyOwner {
        require(_bribeContract != bribeContract && _bribeContract != address(0), "Invalid Address");
        bribeContract = _bribeContract;
        emit SetBribeContract(_bribeContract);
    }

    function setGrimVault(address _evoVault) external onlyOwner {
        require(_evoVault != evoVault && _evoVault != address(0), "Invalid Address");
        evoVault = _evoVault;
        emit SetGrimVault(_evoVault);
    }

    function setStrategist(address _strategist) external {
        require(msg.sender == strategist, "!auth");
        strategist = _strategist;
        emit SetStrategist(_strategist);
    }

    function setTreasury(address _treasury) external onlyOwner{
        require(_treasury != treasury && _treasury != address(0), "Invalid Address");
        treasury = _treasury;
        emit SetTreasury(_treasury);
    }

    function setStableToken(address _token) external onlyAdmin{
        require(_token != stableToken && _token != address(0), "Invalid Address");
        stableToken = _token;
    }

    function setNftId(uint256 _id) external onlyAdmin {
        require(IVeToken(veToken).ownerOf(_id) == address(this), "!NFT owner");
        nftID = _id;
        emit NftIDInUse(nftID);
    }

    function setUniCustomPathsAndRouter(address[] calldata _custompath, address _router) external onlyAdmin {
        require(_router != address(0), "Invalid Address");
        if(_custompath.length > 0){
        customUniPath = _custompath;
        }

        if(_router != unirouter){
        unirouter = _router;
        }
        emit SetUniCustomPathAndRouter(customUniPath, unirouter);
    }

    function setSolidlyPathsAndRouter(ISolidlyRouter.Routes[] calldata _customPath, address _router) external onlyAdmin {
        require(_router != address(0), "Invalid Address");
        if (_customPath.length > 0) {
            delete customSolidlyPath;
            for (uint i; i < _customPath.length; ++i) {
                customSolidlyPath.push(_customPath[i]);}
        }
        if (_router != solidlyRouter) {
            solidlyRouter = _router;
        }
        emit SetSolidlyCustomPathAndRouter(customSolidlyPath, solidlyRouter);
    }


    /** UTILS **/
    function incaseTokensGetStuck(address _token, uint256 _amount) external onlyAdmin {
        require(_token != wftm, "Invalid token");
        require(_token != equal, "Invalid token");
        require(_token != grimEvo, "Invalid token");
        require(_token != stableToken, "Invalid token");
        require(_token != evoLP, "Invalid token");
        uint256 bal;

        if(_amount ==0){
        bal = IERC20(_token).balanceOf(address(this));
        } else { bal = _amount;}
        IERC20(_token).transfer(msg.sender, bal);
        emit StuckToken(_token);
    }

    function approvalCheck(address _spender, address _token, uint256 _amount) internal {
        if (IERC20(_token).allowance(_spender, address(this)) < _amount) {
            IERC20(_token).approve(_spender, 0);
            IERC20(_token).approve(_spender, _amount);
        }
    }

    function solidlyEvoFullBuyback() external onlyAdmin {
        uint256 wftmBal = IERC20(wftm).balanceOf(address(this));
        uint256 ftmBB;

        if(wftmBal > 0){
           (ftmBB,) = ISolidlyRouter(solidlyRouter).getAmountOut(wftmBal, wftm, grimEvo);
           approvalCheck(solidlyRouter, wftm, wftmBal);
           ISolidlyRouter(solidlyRouter).swapExactTokensForTokensSupportingFeeOnTransferTokens(wftmBal, 1, wftmToGrimEvoPath, address(this), block.timestamp);
        }

        uint256 equalBal = IERC20(equal).balanceOf(address(this));
        uint256 equalBB;
        if(equalBal > 0){
           (equalBB,) = ISolidlyRouter(solidlyRouter).getAmountOut(equalBal, equal, grimEvo);
           approvalCheck(solidlyRouter, equal, equalBal);
           ISolidlyRouter(solidlyRouter).swapExactTokensForTokensSupportingFeeOnTransferTokens(equalBal, 1, equalToGrimEvoPath, address(this), block.timestamp);
        }
        emit Buyback((equalBB + ftmBB));
    }


    function uniFtmToEvoBuyback() external onlyAdmin {
        uint256 wftmBal = IERC20(wftm).balanceOf(address(this));
        approvalCheck(unirouter, wftm, wftmBal);
        uint256 ftmBB = IUniRouter(unirouter).getAmountsOut(wftmBal, ftmToGrimEvoUniPath)[1];
        IUniRouter(unirouter).swapExactTokensForTokensSupportingFeeOnTransferTokens(wftmBal, 1, ftmToGrimEvoUniPath, address(this), block.timestamp);        
        emit Buyback(ftmBB);
    }


    /** POL **/
    function polRebalance(address _tokenFrom, ISolidlyRouter.Routes[] calldata _path, uint256 _amount) external onlyAdmin{
        uint256 tokenBal;
        if(_amount == 0){
            tokenBal = IERC20(_tokenFrom).balanceOf(address(this)); } else {tokenBal = _amount;}
        approvalCheck(solidlyRouter, _tokenFrom, tokenBal);
        ISolidlyRouter(solidlyRouter).swapExactTokensForTokensSupportingFeeOnTransferTokens(tokenBal, 1, _path, address(this), block.timestamp);
        emit PolRebalance(_tokenFrom, tokenBal);
    }

    function addEvoPOL(uint256 _wftmAmount) external onlyAdmin {
        uint256 evoBal;
        uint256 wftmBal;
        uint256 lpBal;

        if(_wftmAmount == 0){
            wftmBal = IERC20(wftm).balanceOf(address(this)) / 2; } else {wftmBal = _wftmAmount / 2;}

        approvalCheck(solidlyRouter, wftm, wftmBal * 2);
        evoBal = ISolidlyRouter(solidlyRouter).swapExactTokensForTokensSimple(wftmBal, 1, wftm, grimEvo, false, address(this), block.timestamp)[4];

        approvalCheck(solidlyRouter, grimEvo, evoBal);
        ISolidlyRouter(solidlyRouter).addLiquidity(grimEvo, wftm, false, evoBal, wftmBal, 1, 1, address(this), block.timestamp);

        lpBal = IERC20(evoLP).balanceOf(address(this));
        approvalCheck(evoVault, evoLP, lpBal);
        IGrimVaultV2(evoVault).depositAll();
        emit AddPOL(lpBal);
    }

    function subEvoPOL(uint256 _receipt) public onlyAdmin {
        uint256 receiptBal;
        uint256 liquidity;
        if(_receipt == 0){
            receiptBal = IGrimVaultV2(evoVault).balanceOf(address(this)) ;} else { receiptBal = _receipt;}

        IGrimVaultV2(evoVault).withdraw(receiptBal);
        liquidity = IERC20(evoLP).balanceOf(address(this));

        approvalCheck(solidlyRouter, evoLP, liquidity);
        ISolidlyRouter(solidlyRouter).removeLiquidity(grimEvo, wftm, false, liquidity, 1, 1, address(this), block.timestamp);
        ISolidlyRouter(solidlyRouter).removeLiquidityETHSupportingFeeOnTransferTokens(grimEvo, false, liquidity, 1, 1, address(this), block.timestamp);      
        IWETH(wftm).deposit(address(this).balance);
        emit SubPOL(liquidity);
    }

    function addOrRemoveCustomPOL(address[2] calldata _tokens, ISolidlyRouter.Routes[] calldata _path, address _vault, bool _stable, bool addOrRemove) external onlyAdmin{
        uint256 t1Bal = IERC20(_tokens[0]).balanceOf(address(this)) / 2;
        uint256 t2Bal;
        uint256 lpBal;
        address lp = ISolidlyRouter(solidlyRouter).pairFor(_tokens[0], _tokens[1], _stable);
        uint256 receiptBal;
        if(addOrRemove){
            approvalCheck(solidlyRouter, _tokens[0], t1Bal * 2);
            ISolidlyRouter(solidlyRouter).swapExactTokensForTokensSupportingFeeOnTransferTokens(t1Bal, 1, _path, address(this), block.timestamp);
            t2Bal = IERC20(_tokens[1]).balanceOf(address(this));

            approvalCheck(solidlyRouter, _tokens[1], t2Bal);
            ISolidlyRouter(solidlyRouter).addLiquidity(_tokens[0], _tokens[1], _stable, t1Bal, t2Bal, 1, 1, address(this), block.timestamp);
            lpBal = IERC20(lp).balanceOf(address(this));

            approvalCheck(_vault, lp, lpBal);
            IGrimVaultV2(_vault).depositAll();
        } else{
           receiptBal = IGrimVaultV2(_vault).balanceOf(address(this));
           IGrimVaultV2(_vault).withdrawAll();
           lpBal = IERC20(lp).balanceOf(address(this));

           approvalCheck(solidlyRouter, lp, lpBal);
           ISolidlyRouter(solidlyRouter).removeLiquidity(_tokens[0], _tokens[1], _stable, lpBal, 1, 1, address(this), block.timestamp);
        }

    }

    /** veNFT **/
    function createLock(uint256 _amount, uint256 _duration) external onlyAdmin {
        uint256 lockBal;
        if(_amount == 0){
            lockBal = IERC20(equal).balanceOf(address(this)); } else { lockBal = _amount;}

        approvalCheck(veToken, equal, lockBal);
        nftID = IVeToken(veToken).create_lock(lockBal, _duration);
        emit CreateLock(lockBal);
    }

    function addLockAmount(uint256 _amount) external onlyAdmin {
        uint256 lockBal;
        if(_amount == 0){
            lockBal = IERC20(equal).balanceOf(address(this)); } else { lockBal = _amount;

        approvalCheck(veToken, equal, lockBal);
        IVeToken(veToken).increase_amount(nftID, lockBal);
        emit AddLockAmount(lockBal);}
    }

    function addLockDuration(uint256 _timeAdded) external onlyAdmin {
        IVeToken(veToken).increase_unlock_time(nftID, _timeAdded);
        emit AddLockTime(_timeAdded);
    }

    function vote(address[] calldata _pools, int256[] calldata _weights) external onlyAdmin {
        lastBribes = _pools;
        IVoter(voter).vote(nftID, _pools, _weights);
        lastVote = block.timestamp;
        emit Vote(_pools, _weights);
    }

    function unlockNFT() external onlyOwner {
        IVeToken(veToken).withdraw(nftID);
    }

    function claimRewards(address[][] calldata _tokens) external onlyAdmin {
        IVoter(voter).claimBribes(lastBribes, _tokens, nftID);
    }


    /** BRIBING **/
    function evoBribe(uint256 _amount) external onlyAdmin{
        uint256 evoBal;
        if(_amount == 0){
           evoBal = IERC20(grimEvo).balanceOf(address(this));} else {evoBal = _amount;}

        approvalCheck(bribeContract, grimEvo, evoBal);
        IBribe(bribeContract).notifyRewardAmount(grimEvo, evoBal);
        emit EvoBribe(evoBal);
    }

    function mixedBribe(address[] calldata _tokens, uint256[] calldata _tokenAmounts) external onlyAdmin{
        require(_tokens.length <= 3, "over bounds");
        require(_tokenAmounts[0] <= IERC20(_tokens[0]).balanceOf(address(this)), "t0 invalid amount");
        require(_tokenAmounts[1] <= IERC20(_tokens[1]).balanceOf(address(this)), "t1 invalid amount");
        require(_tokenAmounts[2] <= IERC20(_tokens[2]).balanceOf(address(this)), "t2 invalid amount");
        uint256 t0Bal;
        uint256 t1Bal;
        uint256 t2Bal;

        if(_tokenAmounts[0] == 0){
        t0Bal = IERC20(_tokens[0]).balanceOf(address(this));} else {t0Bal = _tokenAmounts[0];}
        if(_tokenAmounts[1] == 0){
        t1Bal = IERC20(_tokens[1]).balanceOf(address(this));} else {t1Bal = _tokenAmounts[1];}

        if(_tokens[2] != address(0)){
            if(_tokenAmounts[2] == 0){
            t2Bal = IERC20(_tokens[2]).balanceOf(address(this));} else {t2Bal = _tokenAmounts[2];}
        }

        approvalCheck(bribeContract, _tokens[0], t0Bal);
        approvalCheck(bribeContract, _tokens[1], t1Bal);

        IBribe(bribeContract).notifyRewardAmount(_tokens[0], t0Bal);
        IBribe(bribeContract).notifyRewardAmount(_tokens[1], t1Bal);
        if(t2Bal > 0){
            approvalCheck(bribeContract, _tokens[2], t2Bal);
            IBribe(bribeContract).notifyRewardAmount(_tokens[2], t2Bal);
        }
        emit MixedBribe(_tokens, _tokenAmounts);
    }


    /** MIGRATION **/
    function exitFromContract(address _receiver) external onlyOwner {
        require(_receiver != address(0), "Invalid toAddress");
        require(_receiver == treasury || IRecipient(_receiver).oldRecipient() == address(this), "Invalid toAddress");
        IVeToken(veToken).reset();
        uint256 equalBal = IERC20(equal).balanceOf(address(this));
        uint256 wftmBal = IERC20(wftm).balanceOf(address(this));
        uint256 evoBal = IERC20(grimEvo).balanceOf(address(this));
        uint256 stableBal = IERC20(stableToken).balanceOf(address(this));
        uint256 receiptBal = IGrimVaultV2(evoVault).balanceOf(address(this));
        uint256 lpBal = IERC20(evoLP).balanceOf(address(this));

        IERC721(veToken).approve(msg.sender, nftID);
        IERC721(veToken).approve(_receiver, nftID);
        IERC721(veToken).safeTransferFrom(address(this), _receiver, nftID);

        if(receiptBal > 0){
            subEvoPOL(receiptBal);
            lpBal = IERC20(evoLP).balanceOf(address(this));
            IERC20(evoLP).safeTransfer(_receiver, lpBal);
        }
        if(equalBal > 0){
        IERC20(equal).safeTransfer(_receiver, equalBal);
        }
        if(wftmBal > 0){
        IERC20(wftm).safeTransfer(_receiver, wftmBal);
        }
        if(evoBal > 0){
        IERC20(grimEvo).safeTransfer(_receiver, evoBal);
        }
        if(stableBal > 0){
        IERC20(stableToken).safeTransfer(_receiver, stableBal);
        }
        if(lpBal > 0){
        IERC20(evoLP).safeTransfer(_receiver, lpBal);
        }
        emit ExitFromContract(nftID, _receiver);
    }


    /** VIEWS **/
    function tokenBalances() external view returns(uint256 _grimEvo, uint256 _wftm, uint256 _equal, uint256 _stableToken, uint256 _receipt, uint256 _evoLP){ 
        uint256 receiptBal = IGrimVaultV2(evoVault).balanceOf(address(this));
        uint256 lpBal = IERC20(evoLP).balanceOf(address(this));
        uint256 evoBal = IERC20(grimEvo).balanceOf(address(this));
        uint256 wftmBal = IERC20(wftm).balanceOf(address(this));
        uint256 equalBal = IERC20(equal).balanceOf(address(this));
        uint256 stableBal = IERC20(stableToken).balanceOf(address(this));
        return (evoBal, wftmBal, equalBal, stableBal, receiptBal, lpBal);
    }

    function claimableRewards(address[] calldata _tokens) external view returns (address[] memory, uint256[] memory) {
       address[] memory tokenAddresses = new address[](_tokens.length);
       uint256[] memory tokenRewards = new uint256[](_tokens.length);
       uint256 earned;

        for (uint i = 0; i < _tokens.length; i++) {
            earned = IBribe(bribeContract).earned(_tokens[i], nftID);
            tokenAddresses[i] = _tokens[i];
            tokenRewards[i] = earned;
        }
        return (tokenAddresses, tokenRewards);
    }


   /** ACCESS CONTROL **/
    modifier onlyAdmin() {
        require(msg.sender == owner() || msg.sender == strategist);
        _;
    }

    // Receive native from tax supported remove liquidity
    receive() external payable{
        require(msg.sender == solidlyRouter || msg.sender == strategist || msg.sender == owner(), "Invalid Sender");
    }

}