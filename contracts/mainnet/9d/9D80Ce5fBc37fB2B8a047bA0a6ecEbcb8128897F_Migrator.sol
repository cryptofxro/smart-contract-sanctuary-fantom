// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "IERC721Receiver.sol";
import "IERC721.sol";

contract Migrator is IERC721Receiver {
    mapping (uint256 => uint256) public oldToNewId;
    IERC721 petZoo;
    IERC721 nftees;
    address public _minter;
    address public _oldContract;
    address public _newContract;


    constructor (address minter, address oldContract, address newContract) {
        oldToNewId[829] = 0;
        oldToNewId[831] = 1;
        oldToNewId[835] = 2;
        oldToNewId[836] = 3;
        oldToNewId[980] = 4;
        oldToNewId[981] = 5;
        oldToNewId[983] = 6;
        oldToNewId[986] = 7;
        oldToNewId[987] = 8;
        oldToNewId[988] = 9;
        oldToNewId[1359] = 10;
        oldToNewId[1405] = 11;
        oldToNewId[1436] = 12;
        oldToNewId[1864] = 13;
        oldToNewId[2354] = 16;
        oldToNewId[1247] = 20;
        oldToNewId[1422] = 21;
        oldToNewId[1426] = 22;
        oldToNewId[1428] = 23;
        oldToNewId[3086] = 24;
        oldToNewId[1276] = 25;
        oldToNewId[1431] = 26;
        oldToNewId[1433] = 27;
        oldToNewId[1360] = 28;
        oldToNewId[1361] = 29;
        oldToNewId[1715] = 31;
        oldToNewId[1640] = 32;
        oldToNewId[1642] = 33;
        oldToNewId[1643] = 34;
        oldToNewId[1644] = 35;
        oldToNewId[1645] = 36;
        oldToNewId[1269] = 37;
        oldToNewId[1274] = 38;
        oldToNewId[1355] = 39;
        oldToNewId[1266] = 40;
        oldToNewId[1351] = 41;
        oldToNewId[2654] = 42;
        oldToNewId[1270] = 43;
        oldToNewId[1352] = 45;
        oldToNewId[1353] = 46;
        oldToNewId[1354] = 47;
        oldToNewId[2047] = 48;
        oldToNewId[2048] = 49;
        oldToNewId[2045] = 50;

        _oldContract = oldContract;
        _newContract = newContract;
        petZoo = IERC721(_oldContract);
        nftees = IERC721(_newContract);
        _minter = minter;
    }

    function migrate(uint256 tokenId) external {
        require(oldToNewId[tokenId] > 0, "Migrator: This token is not on the list"); // make sure mapping exists
        nftees.safeTransferFrom(_minter, msg.sender, oldToNewId[tokenId]);
        petZoo.safeTransferFrom(msg.sender, address(this), tokenId);
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC165.sol";

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
    function getApproved(uint256 tokenId) external view returns (address operator);

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
    function isApprovedForAll(address owner, address operator) external view returns (bool);

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

// SPDX-License-Identifier: MIT

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