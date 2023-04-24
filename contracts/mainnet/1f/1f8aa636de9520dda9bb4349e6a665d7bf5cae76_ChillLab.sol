/**
 *Submitted for verification at FtmScan.com on 2023-04-24
*/

// File: @openzeppelin/contracts/security/ReentrancyGuard.sol


// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

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
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// File: @openzeppelin/contracts/utils/structs/EnumerableSet.sol


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
// File: @openzeppelin/contracts/utils/introspection/IERC165.sol


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

// File: @openzeppelin/contracts/token/ERC721/IERC721.sol


// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;


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
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
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

// File: @openzeppelin/contracts/utils/Address.sol


// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
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
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
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
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
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

// File: @openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol


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

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


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

// File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol


// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

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
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// File: contracts/ChillPillRarity.sol


pragma solidity 0.8.19;

abstract contract ChillAuth {
    // set of addresses that can perform certain functions
    mapping(address => bool) public isAuth;
    address[] public authorized;
    address public admin;

    modifier onlyAuth() {
        require(isAuth[msg.sender] || msg.sender == admin, "ChillPill: FORBIDDEN (auth)");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "ChillPill: FORBIDDEN (admin)");
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
contract ChillPillRarity is ChillAuth {
    mapping (uint => uint) public rarityOf;

    bool maySetRarities = true;

    function setRarities(uint[] memory rarities, uint256 offset) public onlyAdmin {
        require(maySetRarities);
        uint len = rarities.length;
        for(uint i = 0; i < len; i++)
            rarityOf[i + offset] = rarities[i];
    }

    function relinquishSetRarity() public onlyAdmin {
        maySetRarities = false;
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
// File: contracts/ChillLab.sol


pragma solidity 0.8.19;







interface IERC20Ext is IERC20 {
    function decimals() external returns (uint);
}

interface IERC20WithFees is IERC20{
    function takeFeesExternal(uint256 _amount, address userAddress) external;
}
// The goal of this farm is to allow a stake sChill earn anything model
// In a flip of a traditional farm, this contract only accepts sChill as the staking token
// Each new pool added is a new reward token, each with its own start times
// end times, and rewards per second.
contract ChillLab is ChillPillRarity, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    // Info of each user.
    struct UserInfo {
        uint amount;     // How many tokens the user has provided.
        uint rewardDebt; // Reward debt. See explanation below.
        uint pillDebt;    // Pill debt. See explanation below.
        uint mp;         // Total staked pill power, sum of all pill rarities staked by this user in this pool [uint64 enough]
        uint depositTimestamp;  //
    }

    // Info of each pool.
    struct PoolInfo { //full slot = 32B
        IERC20 RewardToken;           //20B Address of reward token contract.
        uint32 userLimitEndTime;      //4B
        uint8 TokenPrecision;         //1B The precision factor used for calculations, equals the tokens decimals
                                      //7B [free space available here]

        uint256 sChillStakedAmount;        //32B # of schill allocated to this pool
        uint mpStakedAmount;          //32B # of mp allocated to this pool

        uint RewardPerSecond;         //32B reward token per second for this pool in wei
        uint accRewardPerShare;       //32B Accumulated reward per share, times the pools token precision. See below.
        uint accRewardPerShareChillPill;//32B Accumulated reward per share, times the pools token precision. See below.

        address protocolOwnerAddress; //20B this address is the owner of the protocol corresponding to the reward token, used for emergency withdraw to them only
        uint32 lastRewardTime;        //4B Last block time that reward distribution occurs.
        uint32 endTime;               //4B end time of pool
        uint32 startTime;             //4B start time of pool

    }

    //remember that this should be *1000 of the apparent value since onchain rarities are multiplied by 1000, also remember that this is per 1e18 wei of schill.
    uint mpPerSchill = 300 * 1000;

    IERC20 public immutable schill;
    uint32 public baseUserLimitTime = 2 days;
    uint public baseUserLimit;
    uint256 StakeMaxTVL;             //32B pool TVL cap

    IERC721 public immutable pill;
    uint32 public pillBoost14days = 4000;
    uint32 public pillBoost7days  = 2000;
    uint32 public basePillBoost = 1000;

    bool public emergencyPillWithdrawable = false;

    // Info of each pool.
    mapping (uint => PoolInfo) public poolInfo;
    // Number of pools
    uint public poolAmount;
    // Info of each user that stakes tokens.
    mapping (uint => mapping (address => UserInfo)) public userInfo;
    // Info of each users set of staked pills per pool (pool => (user => pills))
    mapping (uint => mapping (address => EnumerableSet.UintSet)) _stakedChillPills; //this data type cant be public, use getter getStakedChillPills()
    // Total staked amount of schill in all pools by user
    mapping (address => uint) public balanceOf;
    // Sum of all rarities of all staked pills
    uint public stakedChillPillPower;
    // Max total pill power
    uint public constant MAX_CHILLPILL_POWER = 10000000000;
    uint public MAX_CHILLPILL_STAKE = 2; // Max amount of pills you can stake
 
    uint256 public stakingFeePercent=0; // percentage of staking fees to be collected
    uint256 public stakingFeesAdmin=0; // total amount of staking fees collected

    uint256 BASIS_POINT_DIVISOR = 1e4;

    // precisionOf[i] = 10**(30 - i)
    mapping (uint8 => uint) public precisionOf;
    mapping (address => bool) public isRewardToken;

    event AdminTokenRecovery(address tokenRecovered, uint amount);
    event Deposit(address indexed user, uint indexed pid, uint amount);
    event Withdraw(address indexed user, uint indexed pid, uint amount);
    event EmergencyWithdraw(address indexed user, uint indexed pid, uint amount);
    event SetRewardPerSecond(uint _pid, uint _gemsPerSecond);
    event StakeChillPill(address indexed user, uint indexed pid, uint indexed tokenID);
    event UnstakeChillPill(address indexed user, uint indexed pid, uint indexed tokenID);


    constructor() {
        schill = IERC20(0x7d74f80EB6D919B1FCD09f58c84d3303Cc566b0A);
        pill = IERC721(0x5Ff7758Ab5202061538dd38E4D3f02bb9f55d26d);
        isRewardToken[address(schill)] = true;
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

    // View function to see pending reward on frontend.
    function pendingReward(uint _pid, address _user) external view returns (uint) {
        (uint schillReward, uint pillReward) = pendingRewards(_pid, _user);
        return schillReward + pillReward;
    }

    function pendingRewards(uint _pid, address _user) public view returns (uint schillReward, uint pillReward) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint accRewardPerShare = pool.accRewardPerShare;
        uint accRewardPerShareChillPill = pool.accRewardPerShareChillPill;

        if (block.timestamp > pool.lastRewardTime) {
            uint reward = pool.RewardPerSecond * getMultiplier(pool.lastRewardTime, block.timestamp, pool.startTime, pool.endTime);
            if(pool.sChillStakedAmount != 0) accRewardPerShare += reward * (10000 - pillBoost(user.depositTimestamp)) / 10000 * precisionOf[pool.TokenPrecision] / pool.sChillStakedAmount;
            if(pool.mpStakedAmount != 0) accRewardPerShareChillPill += reward * pillBoost(user.depositTimestamp) / 10000 * precisionOf[pool.TokenPrecision] / pool.mpStakedAmount;
        }
        schillReward = (user.amount * accRewardPerShare / precisionOf[pool.TokenPrecision]) - user.rewardDebt;
        pillReward = (effectiveMP(user.amount, user.mp) * accRewardPerShareChillPill / precisionOf[pool.TokenPrecision]) - user.pillDebt;
    }
    
    function pillBoost(
        uint depositTimestamp
    ) internal view returns (uint256) {
        uint256 stakingDuration = block.timestamp - depositTimestamp;
        if (stakingDuration >= 14 days) {
            return pillBoost14days;
        } else if (stakingDuration >= 7 days) {
            return pillBoost7days;
        } else {
            return basePillBoost; // Default boost
        }
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint length = poolAmount;
        for (uint pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }

        uint reward = pool.RewardPerSecond * getMultiplier(pool.lastRewardTime, block.timestamp, pool.startTime, pool.endTime);

        if(pool.sChillStakedAmount != 0) pool.accRewardPerShare += reward * (10000 - pillBoost(pool.startTime)) / 10000 * precisionOf[pool.TokenPrecision] / pool.sChillStakedAmount;
        if(pool.mpStakedAmount != 0) pool.accRewardPerShareChillPill += reward * pillBoost(pool.startTime) / 10000 * precisionOf[pool.TokenPrecision] / pool.mpStakedAmount;
        pool.lastRewardTime = uint32(block.timestamp);
    }

    function userCurrentStakeableMP(uint _pid, address _user) public view returns (int) {
        return int(_stakeableMP(userInfo[_pid][_user].amount)) - int(userInfo[_pid][_user].mp);
    }

    function stakeableMP(uint _schill) public view returns (uint) {
        return _stakeableMP(_schill);
    }

    function stakeableMP(uint _pid, address _user) public view returns (uint) {
        return _stakeableMP(userInfo[_pid][_user].amount);
    }

    function effectiveMP(uint _amount, uint _mp) public view returns (uint) {
        _amount = _stakeableMP(_amount);
        return _mp < _amount ? _mp : _amount;
    }

    function _stakeableMP(uint _schill) internal view returns (uint) {
        return mpPerSchill * _schill / 1 ether;
    }

    function stake(uint _pid, uint _amount) external nonReentrant {
        _deposit(_pid, _amount, msg.sender, new uint[](0));
    }

    function stakeTo(uint _pid, uint _amount, address to) external nonReentrant {
        _deposit(_pid, _amount, to, new uint[](0));
    }

    function boostedStake(uint _pid, uint _amount, uint[] memory tokenIDs) external nonReentrant {
        require(tokenIDs.length>0,"ChillLab: Need to stake pills for boosted stake");
        _deposit(_pid, _amount, msg.sender, tokenIDs);
    }

    function boostedStakeTo(uint _pid, uint _amount, address to, uint[] memory tokenIDs) external nonReentrant {
        _deposit(_pid, _amount, to, tokenIDs);
    }
    function claimReward(uint _pid) external nonReentrant {
        _deposit(_pid, 0, msg.sender, new uint[](0));
    }


    // Deposit tokens.
    function _deposit(uint _pid, uint _amount, address to, uint[] memory tokenIDs) internal {

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][to];

        if(baseUserLimit > 0 && block.timestamp < pool.userLimitEndTime) {
            require(user.amount + _amount <= baseUserLimit, "deposit: user has hit deposit cap");
        }


        updatePool(_pid);



        uint256 stakingFees = (_amount * stakingFeePercent) /
            BASIS_POINT_DIVISOR;



        stakingFeesAdmin += stakingFees;

        uint256 stakingAmountAfterFees = _amount - stakingFees;

        if(StakeMaxTVL < pool.sChillStakedAmount+stakingAmountAfterFees) {
            require(user.amount + _amount <= baseUserLimit, "deposit: pool has hit deposit cap");
        }



        IERC20WithFees(address(schill)).takeFeesExternal(stakingFees, msg.sender); //take fees in Chill from user's stake


        uint precision = precisionOf[pool.TokenPrecision];//precision

        uint pending = (user.amount * pool.accRewardPerShare / precision) - user.rewardDebt;
        uint pendingPill = effectiveMP(user.amount, user.mp) * pool.accRewardPerShareChillPill / precision - user.pillDebt;

        user.amount += stakingAmountAfterFees;
        pool.sChillStakedAmount += stakingAmountAfterFees;
        balanceOf[to] += stakingAmountAfterFees;

        user.rewardDebt = (stakingAmountAfterFees+user.amount) * pool.accRewardPerShare / precision;

        if(pending > 0)
            safeTransfer(pool.RewardToken, to, pending + pendingPill);
        if(stakingAmountAfterFees > 0)
            schill.safeTransferFrom(msg.sender, address(this), stakingAmountAfterFees);


        emit Deposit(msg.sender, _pid, stakingAmountAfterFees);

        uint len = tokenIDs.length;
        if(len == 0) {
            user.pillDebt = effectiveMP(stakingAmountAfterFees+user.amount, user.mp) * pool.accRewardPerShareChillPill / precision;
            return;
        }
        require(len + _stakedChillPills[_pid][to].length() <= MAX_CHILLPILL_STAKE, string(abi.encodePacked("deposit: Boosting with too many chill pills")));

        pending = sumOfRarities(tokenIDs);
        stakedChillPillPower += pending;

        user.mp += pending;
        user.pillDebt = effectiveMP(stakingAmountAfterFees+user.amount, user.mp) * pool.accRewardPerShareChillPill / precision;
        pool.mpStakedAmount += pending;

        do {
            unchecked {--len;}
            pending = tokenIDs[len];
            pill.transferFrom(msg.sender, address(this), pending);
            _stakedChillPills[_pid][to].add(pending);
            emit StakeChillPill(to, _pid, pending);
        } while (len != 0);
    }


    // Withdraw tokens.
    function withdraw(uint _pid, uint _amount) external nonReentrant {
        _withdraw(_pid, _amount, msg.sender, new uint[](0));
    }

    function withdrawTo(uint _pid, uint _amount, address to) external nonReentrant {
        _withdraw(_pid, _amount, to, new uint[](0));
    }

    function withdrawBoosted(uint _pid, uint _amount, uint[] memory tokenIDs) external nonReentrant {
        _withdraw(_pid, _amount, msg.sender, tokenIDs);
    }

    function withdrawBoostedTo(uint _pid, uint _amount, address to, uint[] memory tokenIDs) external nonReentrant {
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
        uint pendingPill = (effectiveMP(amount, user.mp) * pool.accRewardPerShareChillPill / precision) - user.pillDebt;

        user.amount -= _amount;
        amount -= _amount;
        pool.sChillStakedAmount -= _amount;
        balanceOf[msg.sender] -= _amount;

        user.rewardDebt = amount * pool.accRewardPerShare / precision;

        if(pending > 0)
            safeTransfer(pool.RewardToken, to, pending + pendingPill);
        if(_amount > 0)
            safeTransfer(schill, to, _amount);

        emit Withdraw(to, _pid, _amount);

        uint len = tokenIDs.length;
        if(len == 0) {
            user.pillDebt = effectiveMP(amount, user.mp) * pool.accRewardPerShareChillPill / precision;
            return;
        }

        pending = sumOfRarities(tokenIDs);
        stakedChillPillPower -= pending;

        user.mp -= pending;
        user.pillDebt = effectiveMP(amount, user.mp) * pool.accRewardPerShareChillPill / precision;
        pool.mpStakedAmount -= pending;

        do {
            unchecked {--len;}
            pending = tokenIDs[len];
            require(_stakedChillPills[_pid][msg.sender].contains(pending), "ChillPill not staked by this user in this pool!");
            _stakedChillPills[_pid][msg.sender].remove(pending);
            pill.transferFrom(address(this), to, pending);
            emit UnstakeChillPill(msg.sender, _pid, pending);
        } while (len != 0);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint oldUserAmount = user.amount;
        pool.sChillStakedAmount -= user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        balanceOf[msg.sender] -= oldUserAmount;

        schill.safeTransfer(address(msg.sender), oldUserAmount);
        emit EmergencyWithdraw(msg.sender, _pid, oldUserAmount);

    }

    // !! DO NOT CALL THIS UNLESS YOU KNOW EXACTLY WHAT YOU ARE DOING !!
    // Withdraw pills without caring about rewards. EMERGENCY ONLY.
    // !! DO NOT CALL THIS UNLESS YOU KNOW EXACTLY WHAT YOU ARE DOING !!
    // This will set your mp and pillDebt to 0 even if you dont withdraw all pills. Make sure to emergency withdraw all your pills if you ever call this.
    // !! DO NOT CALL THIS UNLESS YOU KNOW EXACTLY WHAT YOU ARE DOING !!
    function emergencyPillWithdraw(uint _pid, uint[] calldata tokenIDs) external {
        require(emergencyPillWithdrawable);
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint userMPs = sumOfRarities(tokenIDs);
        user.mp = 0;
        user.pillDebt = 0;
        pool.mpStakedAmount -= userMPs;
        stakedChillPillPower -= userMPs;
        uint len = tokenIDs.length;
        do {
            unchecked {--len;}
            userMPs = tokenIDs[len];
            require(_stakedChillPills[_pid][msg.sender].contains(userMPs), "ChillPill not staked by this user in this pool!");
            _stakedChillPills[_pid][msg.sender].remove(userMPs);
            pill.transferFrom(address(this), msg.sender, userMPs);
            emit UnstakeChillPill(msg.sender, _pid, userMPs);
        } while (len != 0);
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

    function stakeAndUnstakeChillPills(uint _pid, uint[] memory stakeTokenIDs, uint[] memory unstakeTokenIDs) external nonReentrant {
        _withdraw(_pid, 0, msg.sender, unstakeTokenIDs);
        _deposit(_pid, 0, msg.sender, stakeTokenIDs);
    }

    function onERC721Received(address operator, address /*from*/, uint /*tokenId*/, bytes calldata /*data*/) external view returns (bytes4) {
        if(operator == address(this))
            return this.onERC721Received.selector;
        return 0;
    }

    // Admin functions

    function setEmergencyPillWithdrawable(bool allowed) external onlyAuth {
        emergencyPillWithdrawable = allowed;
    }

    function setPillMultiplier(uint mul) external onlyAdmin {
        mpPerSchill = mul;
    }

    function setChillPillBoost(uint32 _baseBoost,uint32 _pillBoost7days,uint32 _pillBoost14days) external onlyAdmin {
        require(_baseBoost < 5000); //5000 = 50%
        require(_pillBoost7days < 5000); //5000 = 50%
        require(_pillBoost14days < 5000); //5000 = 50%
        basePillBoost = _baseBoost;
        pillBoost7days= _pillBoost7days;
        pillBoost14days = _pillBoost14days;
    }
    function setStakingFee(uint256 _stakingFee) external onlyAdmin {
        stakingFeePercent = _stakingFee;
    }

    function setMaxChillPillsStaked(uint32 max) external onlyAdmin {
        MAX_CHILLPILL_STAKE=max;
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
        require(!isRewardToken[address(_Token)], "checkForToken: reward token or schill provided");
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
        require(_rewardPerSecond > 9, "ChillLab _add: _rewardPerSecond needs to be at least 10 wei");

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
        //poolinfo.sChillStakedAmount = 0;
        poolinfo.startTime = _startTime;
        poolinfo.endTime = _endTime;
        poolinfo.lastRewardTime = lastRewardTime;
        //poolinfo.accRewardPerShare = 0;
        poolinfo.protocolOwnerAddress = _protocolOwner;
        poolinfo.userLimitEndTime = lastRewardTime + baseUserLimitTime;
        poolAmount += 1;
    }

    // Update the global pool TVL Limit.
    function setStakeMaxTVL(uint256 _StakeMaxTVL) external onlyAdmin {
        StakeMaxTVL=_StakeMaxTVL;
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
    function getStakedChillPills(uint _pid, address _user) external view returns (uint[] memory) {
        return _stakedChillPills[_pid][_user].values();
    }

}