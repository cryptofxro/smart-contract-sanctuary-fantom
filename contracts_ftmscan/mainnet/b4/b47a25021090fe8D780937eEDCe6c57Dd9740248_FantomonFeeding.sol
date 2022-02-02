/**
 *Submitted for verification at FtmScan.com on 2022-02-02
*/

/*
██╗░░░░░░█████╗░██████╗░██╗░░██╗██╗███╗░░██╗
██║░░░░░██╔══██╗██╔══██╗██║░██╔╝██║████╗░██║
██║░░░░░███████║██████╔╝█████═╝░██║██╔██╗██║
██║░░░░░██╔══██║██╔══██╗██╔═██╗░██║██║╚████║
███████╗██║░░██║██║░░██║██║░╚██╗██║██║░╚███║
╚══════╝╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚═╝╚═╝╚═╝░░╚══╝
*/
// Sources flattened with hardhat v2.7.0 https://hardhat.org

// File @openzeppelin/contracts/utils/[email protected]

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Context.sol)

pragma solidity ^0.8.9;

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


// OpenZeppelin Contracts v4.4.0 (access/Ownable.sol)



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


// File @openzeppelin/contracts/utils/introspection/[email protected]


// OpenZeppelin Contracts v4.4.0 (utils/introspection/IERC165.sol)



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


// OpenZeppelin Contracts v4.4.0 (token/ERC721/IERC721.sol)



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


// File @openzeppelin/contracts/token/ERC20/[email protected]


// OpenZeppelin Contracts v4.4.0 (token/ERC20/IERC20.sol)



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


// File @openzeppelin/contracts/token/ERC20/extensions/[email protected]


// OpenZeppelin Contracts v4.4.0 (token/ERC20/extensions/IERC20Metadata.sol)



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


// File @openzeppelin/contracts/token/ERC20/[email protected]


// OpenZeppelin Contracts v4.4.0 (token/ERC20/ERC20.sol)





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


// File @openzeppelin/contracts/token/ERC20/extensions/[email protected]


// OpenZeppelin Contracts v4.4.0 (token/ERC20/extensions/ERC20Burnable.sol)




/**
 * @dev Extension of {ERC20} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
abstract contract ERC20Burnable is Context, ERC20 {
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
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        unchecked {
            _approve(account, _msgSender(), currentAllowance - amount);
        }
        _burn(account, amount);
    }
}


// File @openzeppelin/contracts/token/ERC721/[email protected]


// OpenZeppelin Contracts v4.4.0 (token/ERC721/IERC721Receiver.sol)



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


// File @openzeppelin/contracts/token/ERC721/extensions/[email protected]


// OpenZeppelin Contracts v4.4.0 (token/ERC721/extensions/IERC721Metadata.sol)



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


// File @openzeppelin/contracts/utils/[email protected]


// OpenZeppelin Contracts v4.4.0 (utils/Address.sol)



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


// File @openzeppelin/contracts/utils/[email protected]


// OpenZeppelin Contracts v4.4.0 (utils/Strings.sol)



/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

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
}


// File @openzeppelin/contracts/utils/introspection/[email protected]


// OpenZeppelin Contracts v4.4.0 (utils/introspection/ERC165.sol)



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


// File @openzeppelin/contracts/token/ERC721/[email protected]


// OpenZeppelin Contracts v4.4.0 (token/ERC721/ERC721.sol)









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
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
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
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
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
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

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
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
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
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
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
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
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
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
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
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
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
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
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
}


// File @openzeppelin/contracts/token/ERC721/extensions/[email protected]


// OpenZeppelin Contracts v4.4.0 (token/ERC721/extensions/IERC721Enumerable.sol)



/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}


// File contracts/IFantomonTrainerInteractive.sol






interface IFantomonTrainerInteractive is IERC721Enumerable, IERC721Metadata {

    /**************************************************************************
     * Stats and attributes for all trainers
     **************************************************************************/
    function getKinship(uint256 _tokenId) external view returns (uint256);
    function getFlare(uint256 _tokenId) external view returns (uint256);
    function getCourage(uint256 _tokenId) external view returns (uint256);
    function getWins(uint256 _tokenId) external view returns (uint256);
    function getLosses(uint256 _tokenId) external view returns (uint256);
    /* Stats and attributes for all trainers
     **************************************************************************/

    /**************************************************************************
     * Getters
     **************************************************************************/
    function location_(uint256 _tokenId) external view returns (address);
    function getStatus(uint256 _tokenId) external view returns (uint8);
    function getRarity(uint256 _tokenId) external view returns (uint8);
    function getClass(uint256 _tokenId) external view returns (uint8);
    function getFace(uint256 _tokenId) external view returns (uint8);
    function getHomeworld(uint256 _tokenId) external view returns (uint8);
    function getTrainerName(uint256 _tokenId) external view returns (string memory);
    function getHealing(uint256 _tokenId) external view returns (uint256);

    function fantomonsEnabled_(address _fantomon) external view returns (bool);
    function arenasEnabled_(address _arena) external view returns (bool);
    /* End getters
     **************************************************************************/

    /**************************************************************************
     * Interactions callable by location contracts
     **************************************************************************/
    function _enterBattle(uint256 _tokenId) external;
    function _leaveArena(uint256 _tokenId, bool _won) external;
    function _leaveHealingRift(uint256 _tokenId) external;
    function _leaveJourney(uint256 _tokenId) external;
    function _leave(uint256 _tokenId) external;
    /* End interactions callable by location contracts
     **************************************************************************/
}


// File contracts/FantomonLib.sol

/*
██╗░░░░░░█████╗░██████╗░██╗░░██╗██╗███╗░░██╗
██║░░░░░██╔══██╗██╔══██╗██║░██╔╝██║████╗░██║
██║░░░░░███████║██████╔╝█████═╝░██║██╔██╗██║
██║░░░░░██╔══██║██╔══██╗██╔═██╗░██║██║╚████║
███████╗██║░░██║██║░░██║██║░╚██╗██║██║░╚███║
╚══════╝╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚═╝╚═╝╚═╝░░╚══╝
*/





/**************************************************************************
 * Library of core Fantomon functions
 **************************************************************************/
library FantomonLib {

    /**************************************************************************
     * Some common constants
     **************************************************************************/
    uint48 constant private ONE_MIL =         1000000;  // constant to avoid mistyping 1mil's #zeros
    uint48 constant private MAX_XP  =   1069420000000;  // XP at max level:         1069420 * 1E6
    uint48 constant private MAX_NUTRIENTS = 300000000;  // Max combined stat nutrients: 300 * 1E6
    uint48 constant private MAX_MASTERY   = 300000000;  // Max combined stat nutrients: 300 * 1E6

    /**************************************************************************
     * Core structs for storing Fantomon info
     **************************************************************************/
    struct Stats {
        uint48 hp;
        uint48 attack;
        uint48 defense;
        uint48 spAttack;
        uint48 spDefense;
    }
    struct Attributes {
        uint8 class;
        uint8 typ;
        uint8 species;
        uint8 mood;
        uint8 essence; // essence index
    }
    struct Modifiers {
        uint24 essence; // essence stat for scaling
        uint8 hpVariance;
        uint8 attackVariance;
        uint8 defenseVariance;
        uint8 spAttackVariance;
        uint8 spDefenseVariance;
    }
    struct Attacks {
        uint8 attack0;
        uint8 attack1;
        uint8 attack2;
        uint8 attack3;
    }

    struct Fmon {
        uint8  lvl;
        uint8  morph;
        uint48 xp;
        uint48 dmg;
        Stats      nutrients;
        Stats      mastery;
        Stats      base;
        Attributes attrs;
        Modifiers  modifiers;
        Attacks    attacks;
    }

    struct StatBoost {
        uint48 xp;
        uint48 hp;
        uint48 attack;
        uint48 defense;
        uint48 spAttack;
        uint48 spDefense;
    }

    /**************************************************************************
     * Getters - probe some information about an Fmon
     **************************************************************************/
    /* Did an Fmon faint? Is it's damage equal to its scaled HP
     */
    function fainted(Fmon memory _fmon) external pure returns (bool) {
        return _scaleHp(_fmon.base.hp, _fmon.nutrients.hp, _fmon.mastery.hp, _fmon.modifiers.hpVariance, _fmon.lvl) <= _fmon.dmg;
    }

    /* Serialize all attributes and stats of an Fmon into a single array
     */
    function serialize(Fmon calldata _fmon) external pure returns (uint256[36] memory _attrs) {
        Stats memory scaled = scale(_fmon);
        _attrs[ 0] = _fmon.lvl                           ;
        _attrs[ 1] = _fmon.morph                         ;
        _attrs[ 2] = _fmon.xp                  / ONE_MIL ;
        _attrs[ 3] = _fmon.base.hp             / ONE_MIL ;
        _attrs[ 4] = _fmon.base.attack         / ONE_MIL ;
        _attrs[ 5] = _fmon.base.defense        / ONE_MIL ;
        _attrs[ 6] = _fmon.base.spAttack       / ONE_MIL ;
        _attrs[ 7] = _fmon.base.spDefense      / ONE_MIL ;
        _attrs[ 8] = scaled.hp                 / ONE_MIL ;
        _attrs[ 9] = scaled.attack             / ONE_MIL ;
        _attrs[10] = scaled.defense            / ONE_MIL ;
        _attrs[11] = scaled.spAttack           / ONE_MIL ;
        _attrs[12] = scaled.spDefense          / ONE_MIL ;
        _attrs[13] = _fmon.nutrients.hp        / ONE_MIL ;
        _attrs[14] = _fmon.nutrients.attack    / ONE_MIL ;
        _attrs[15] = _fmon.nutrients.defense   / ONE_MIL ;
        _attrs[16] = _fmon.nutrients.spAttack  / ONE_MIL ;
        _attrs[17] = _fmon.nutrients.spDefense / ONE_MIL ;
        _attrs[18] = _fmon.mastery.hp          / ONE_MIL ;
        _attrs[19] = _fmon.mastery.attack      / ONE_MIL ;
        _attrs[20] = _fmon.mastery.defense     / ONE_MIL ;
        _attrs[21] = _fmon.mastery.spAttack    / ONE_MIL ;
        _attrs[22] = _fmon.mastery.spDefense   / ONE_MIL ;
        _attrs[23] = _fmon.modifiers.hpVariance          ;
        _attrs[24] = _fmon.modifiers.attackVariance      ;
        _attrs[25] = _fmon.modifiers.defenseVariance     ;
        _attrs[26] = _fmon.modifiers.defenseVariance     ;
        _attrs[27] = _fmon.modifiers.spAttackVariance    ;
        _attrs[28] = _fmon.modifiers.spDefenseVariance   ;
        _attrs[29] = _fmon.attrs.species                 ;
        _attrs[30] = _fmon.attrs.typ                     ;
        _attrs[31] = _fmon.attrs.class                   ;
        _attrs[32] = _fmon.attrs.mood                    ;
        _attrs[33] = _fmon.attrs.essence                 ;
        _attrs[34] = _fmon.attacks.attack0               ;
        _attrs[35] = _fmon.attacks.attack1               ;
    }

    /**************************************************************************
     * Math, Transform, and Memory Functions to check values of
     * Stats and Boosts after applying some transform
     * - All performed in memory
     **************************************************************************/
    /* Return an Fmon with its stats scaled */
    function scale(Fmon calldata _fmon) public pure returns (Stats memory _stats) {
        _stats.hp        =   _scaleHp(_fmon.base.hp,        _fmon.nutrients.hp,        _fmon.mastery.hp,        _fmon.modifiers.hpVariance,        _fmon.lvl);
        _stats.attack    = _scaleStat(_fmon.base.attack,    _fmon.nutrients.attack,    _fmon.mastery.attack,    _fmon.modifiers.attackVariance,    _fmon.lvl, _fmon.modifiers.essence);
        _stats.defense   = _scaleStat(_fmon.base.defense,   _fmon.nutrients.defense,   _fmon.mastery.defense,   _fmon.modifiers.defenseVariance,   _fmon.lvl, _fmon.modifiers.essence);
        _stats.spAttack  = _scaleStat(_fmon.base.spAttack,  _fmon.nutrients.spAttack,  _fmon.mastery.spAttack,  _fmon.modifiers.spAttackVariance,  _fmon.lvl, _fmon.modifiers.essence);
        _stats.spDefense = _scaleStat(_fmon.base.spDefense, _fmon.nutrients.spDefense, _fmon.mastery.spDefense, _fmon.modifiers.spDefenseVariance, _fmon.lvl, _fmon.modifiers.essence);
    }

    /* Functions to scale stats of an Fmon */
    function scaleHp(Fmon memory _fmon) internal pure returns (uint48) {
        return _scaleHp(_fmon.base.hp, _fmon.nutrients.hp, _fmon.mastery.hp, _fmon.modifiers.hpVariance, _fmon.lvl);
    }
    function scaleAttack(Fmon memory _fmon) internal pure returns (uint48) {
        return _scaleStat(_fmon.base.attack,    _fmon.nutrients.attack,    _fmon.mastery.attack,    _fmon.modifiers.attackVariance,    _fmon.lvl, _fmon.modifiers.essence);
    }
    function scaleDefense(Fmon memory _fmon) internal pure returns (uint48) {
        return _scaleStat(_fmon.base.defense,   _fmon.nutrients.defense,   _fmon.mastery.defense,   _fmon.modifiers.defenseVariance,   _fmon.lvl, _fmon.modifiers.essence);
    }
    function scaleSpAttack(Fmon memory _fmon) internal pure returns (uint48) {
        return _scaleStat(_fmon.base.spAttack,  _fmon.nutrients.spAttack,  _fmon.mastery.spAttack,  _fmon.modifiers.spAttackVariance,  _fmon.lvl, _fmon.modifiers.essence);
    }
    function scaleSpDefense(Fmon memory _fmon) internal pure returns (uint48) {
        return _scaleStat(_fmon.base.spDefense, _fmon.nutrients.spDefense, _fmon.mastery.spDefense, _fmon.modifiers.spDefenseVariance, _fmon.lvl, _fmon.modifiers.essence);
    }

    /* Mathematical formula to scale an Fmon's HP
       Returns scaled HP x 1E6
     */
    function _scaleHp(uint256 _baseHpX1M, uint256 _statNutrientsX1M, uint256 _statMasteryX1M, uint256 _variance, uint256 _level) internal pure returns (uint48) {
        return uint48((((2 * _baseHpX1M +  (_variance * 1000000) + (_statNutrientsX1M + _statMasteryX1M / 4)) * _level) / 100) + _level + 10000000);
    }

    /* Mathematical formula to scale an Fmon's other stats
       Returns scaled stat x 1E6
     */
    function _scaleStat(uint256 _baseStatX1M, uint256 _statNutrientsX1M, uint256 _statMasteryX1M, uint256 _variance, uint256 _level, uint256 _essenceX1M) internal pure returns (uint48) {
        // div by 1E6 because both stat and essence are scaled by 1E6,
        // so numerator here is 1E12 and we want return result to be 1E6
        return uint48((((((2 * _baseStatX1M + (_variance * 1000000) + (_statNutrientsX1M + _statMasteryX1M / 4)) * _level) / 100) + 5000000) * _essenceX1M) / 1000000);
    }
    /* Given a some stats, return those stats after applying a boost
     */
    function boost(Stats memory _stats, StatBoost memory _boost) external pure returns (Stats memory) {
        _stats.hp        += _boost.hp;
        _stats.attack    += _boost.attack;
        _stats.defense   += _boost.defense;
        _stats.spAttack  += _boost.spAttack;
        _stats.spDefense += _boost.spDefense;
        return _stats;
    }

    /* Given a Stat Boost, return that boost after multplying it by the provided ration (_numerator / _denominator).
       Useful when you fed too much, and can only apply a fraction of each stat boost.
     */
    function applyRatio(StatBoost memory _boost, uint256 _numerator, uint256 _denominator) external pure returns (StatBoost memory) {
        _boost.hp        = uint48((_numerator * _boost.hp)        / _denominator);
        _boost.attack    = uint48((_numerator * _boost.attack)    / _denominator);
        _boost.defense   = uint48((_numerator * _boost.defense)   / _denominator);
        _boost.spAttack  = uint48((_numerator * _boost.spAttack)  / _denominator);
        _boost.spDefense = uint48((_numerator * _boost.spDefense) / _denominator);
        return _boost;
    }
    /* Given a Stat Boost, return that boost after multplying all of its members by _amount.
       Useful when feeding an "amount" of food
     */
    function mul(StatBoost memory _boost, uint48 _amount) external pure returns (StatBoost memory) {
        _boost.xp        *= _amount;
        _boost.hp        *= _amount;
        _boost.attack    *= _amount;
        _boost.defense   *= _amount;
        _boost.spAttack  *= _amount;
        _boost.spDefense *= _amount;
        return _boost;
    }
    /* Given a Stat Boost, return that boost after multplying all of its members by _amount.
     */
    function div(StatBoost memory _boost, uint48 _amount) external pure returns (StatBoost memory) {
        _boost.xp        /= _amount;
        _boost.hp        /= _amount;
        _boost.attack    /= _amount;
        _boost.defense   /= _amount;
        _boost.spAttack  /= _amount;
        _boost.spDefense /= _amount;
        return _boost;
    }

    /* Sum all member Stats and return
     */
    function sum(Stats memory _stats) public pure returns (uint48) {
        return _stats.hp + _stats.attack + _stats.defense + _stats.spAttack + _stats.spDefense;
    }

    /* Sum all members of a Stat Boost, except XP, return
     */
    function sum(StatBoost memory _boost) external pure returns (uint48) {
        return _boost.hp + _boost.attack + _boost.defense + _boost.spAttack + _boost.spDefense;
    }
    /* Sum all members of a Stat Boost, return
     */
    function sumWithXp(StatBoost memory _boost) external pure returns (uint48) {
        return _boost.xp + _boost.hp + _boost.attack + _boost.defense + _boost.spAttack + _boost.spDefense;
    }

    /**************************************************************************
     * Storage Functions to update Fmons in Storage
     **************************************************************************/
    /* Given an Fmon in storage, boost its XP and Nutrients
       Applying the boost to storage
     */
    function commitXpNutrientBoost(Fmon storage _fmon, StatBoost memory _boost) external {
        _fmon.xp                  += _boost.xp;
        _fmon.nutrients.hp        += _boost.hp;
        _fmon.nutrients.attack    += _boost.attack;
        _fmon.nutrients.defense   += _boost.defense;
        _fmon.nutrients.spAttack  += _boost.spAttack;
        _fmon.nutrients.spDefense += _boost.spDefense;
        uint48 xp = _fmon.xp;
        require(xp <= MAX_XP && sum(_fmon.nutrients) <= MAX_NUTRIENTS, "Boost overflow");
        _fmon.lvl = xp2Lvl(xp);
    }
    /* Given an Fmon in storage, boost its XP and Mastery
       Applying the boost to storage
     */
    function commitXpMasteryBoost(Fmon storage _fmon, StatBoost memory _boost) external {
        _fmon.xp                += _boost.xp;
        _fmon.mastery.hp        += _boost.hp;
        _fmon.mastery.attack    += _boost.attack;
        _fmon.mastery.defense   += _boost.defense;
        _fmon.mastery.spAttack  += _boost.spAttack;
        _fmon.mastery.spDefense += _boost.spDefense;
        uint48 xp = _fmon.xp;
        require(xp <= MAX_XP && sum(_fmon.mastery) <= MAX_MASTERY, "Boost overflow");
        _fmon.lvl = xp2Lvl(xp);
    }
    /* Mock versions of the previous two functions that do not update storage,
       just return the updated Fmon. Useful for checking
       "how would this boost (feed/fight) affect my Fmon?"
     */
    function mockXpNutrientBoost(Fmon memory _fmon, StatBoost memory _boost) external pure returns (Fmon memory) {
        _fmon.xp                  += _boost.xp;
        _fmon.nutrients.hp        += _boost.hp;
        _fmon.nutrients.attack    += _boost.attack;
        _fmon.nutrients.defense   += _boost.defense;
        _fmon.nutrients.spAttack  += _boost.spAttack;
        _fmon.nutrients.spDefense += _boost.spDefense;
        require(_fmon.xp <= MAX_XP && sum(_fmon.nutrients) <= MAX_NUTRIENTS, "Boost overflow");
        _fmon.lvl = xp2Lvl(_fmon.xp);
        return _fmon;
    }
    function mockXpMasteryBoost(Fmon memory _fmon, StatBoost memory _boost) external pure returns (Fmon memory) {
        _fmon.xp                += _boost.xp;
        _fmon.mastery.hp        += _boost.hp;
        _fmon.mastery.attack    += _boost.attack;
        _fmon.mastery.defense   += _boost.defense;
        _fmon.mastery.spAttack  += _boost.spAttack;
        _fmon.mastery.spDefense += _boost.spDefense;
        require(_fmon.xp <= MAX_XP && sum(_fmon.mastery) <= MAX_MASTERY, "Boost overflow");
        _fmon.lvl = xp2Lvl(_fmon.xp);
        return _fmon;
    }
    /* Calculate Lvl given XP
     */
    function xp2Lvl(uint48 _xp) public pure returns (uint8) {
        uint48[100] memory XP_PER_LEVEL = [
                       0,
                 8000000,
                27000000,
                64000000,
               125000000,
               216000000,
               343000000,
               512000000,
               729000000,
              1000000000,
              1331000000,
              1728000000,
              2197000000,
              2744000000,
              3375000000,
              4096000000,
              4913000000,
              5832000000,
              6859000000,
              8000000000,
              9261000000,
             10648000000,
             12167000000,
             13824000000,
             15625000000,
             17576000000,
             19683000000,
             21952000000,
             24389000000,
             27000000000,
             29791000000,
             32768000000,
             35937000000,
             39304000000,
             42875000000,
             46656000000,
             50653000000,
             54872000000,
             59319000000,
             64000000000,
             68921000000,
             74088000000,
             79507000000,
             85184000000,
             91125000000,
             97336000000,
            103823000000,
            110592000000,
            117649000000,
            125000000000,
            132651000000,
            140608000000,
            148877000000,
            157464000000,
            166375000000,
            175616000000,
            185193000000,
            195112000000,
            205379000000,
            216000000000,
            226981000000,
            238328000000,
            250047000000,
            262144000000,
            274625000000,
            287496000000,
            300763000000,
            314432000000,
            328509000000,
            343000000000,
            357911000000,
            373248000000,
            389017000000,
            405224000000,
            421875000000,
            438976000000,
            456533000000,
            474552000000,
            493039000000,
            512000000000,
            531441000000,
            551368000000,
            571787000000,
            592704000000,
            614125000000,
            636056000000,
            658503000000,
            681472000000,
            704969000000,
            729000000000,
            753571000000,
            778688000000,
            804357000000,
            830584000000,
            857375000000,
            884736000000,
            912673000000,
            941192000000,
            970299000000,
                  MAX_XP
        ];
        for (uint8 lvl = 1; lvl <= 100; lvl++) {
            if (XP_PER_LEVEL[lvl-1] <= _xp && (lvl == 100 || XP_PER_LEVEL[lvl] > _xp)) {
                 return lvl;
            }
        }
        revert("Invalid XP");
    }
    /* What is the XP it takes to get to the given Lvl
     */
    function lvl2Xp(uint8 _lvl) public pure returns (uint48) {
        uint48[100] memory XP_PER_LEVEL = [
                       0,
                 8000000,
                27000000,
                64000000,
               125000000,
               216000000,
               343000000,
               512000000,
               729000000,
              1000000000,
              1331000000,
              1728000000,
              2197000000,
              2744000000,
              3375000000,
              4096000000,
              4913000000,
              5832000000,
              6859000000,
              8000000000,
              9261000000,
             10648000000,
             12167000000,
             13824000000,
             15625000000,
             17576000000,
             19683000000,
             21952000000,
             24389000000,
             27000000000,
             29791000000,
             32768000000,
             35937000000,
             39304000000,
             42875000000,
             46656000000,
             50653000000,
             54872000000,
             59319000000,
             64000000000,
             68921000000,
             74088000000,
             79507000000,
             85184000000,
             91125000000,
             97336000000,
            103823000000,
            110592000000,
            117649000000,
            125000000000,
            132651000000,
            140608000000,
            148877000000,
            157464000000,
            166375000000,
            175616000000,
            185193000000,
            195112000000,
            205379000000,
            216000000000,
            226981000000,
            238328000000,
            250047000000,
            262144000000,
            274625000000,
            287496000000,
            300763000000,
            314432000000,
            328509000000,
            343000000000,
            357911000000,
            373248000000,
            389017000000,
            405224000000,
            421875000000,
            438976000000,
            456533000000,
            474552000000,
            493039000000,
            512000000000,
            531441000000,
            551368000000,
            571787000000,
            592704000000,
            614125000000,
            636056000000,
            658503000000,
            681472000000,
            704969000000,
            729000000000,
            753571000000,
            778688000000,
            804357000000,
            830584000000,
            857375000000,
            884736000000,
            912673000000,
            941192000000,
            970299000000,
                  MAX_XP
        ];
        return XP_PER_LEVEL[_lvl];
    }
}


// File contracts/IFantomonStore.sol





interface IFantomonStore {
    function initStarterFmon(uint256 _tokenId, address _sender,
                             uint256 _courage, uint256 _healing, uint8 _choice) external;
    function initFmon(uint256 _tokenId, address _sender,
                      uint8 _class,  uint8 _homeworld,
                      uint8 _rarity, uint256 _courage, uint256 _healing) external;

    function names_(uint256) external view returns (string calldata);
    function fmon(uint256 _tokenId) external view returns (FantomonLib.Fmon memory);
    function fainted(uint256 _tokenId) external returns (bool);
    function getLvl(uint256 _tokenId) external view returns (uint8);
    function getMorph(uint256 _tokenId) external view returns (uint8);
    function getXp(uint256 _tokenId) external view returns (uint48);
    function getDmg(uint256 _tokenId) external view returns (uint48);
    function getNutrients(uint256 _tokenId) external view returns (FantomonLib.Stats memory);
    function getMastery(uint256 _tokenId) external view returns (FantomonLib.Stats memory);
    function getXpNutrients(uint256 _tokenId) external view returns (uint48, FantomonLib.Stats memory);
    function getXpMastery  (uint256 _tokenId) external view returns (uint48, FantomonLib.Stats memory);
    function getScaledStats(uint256 _tokenId) external view returns (FantomonLib.Stats memory);
    function getAttributes(uint256 _tokenId) external view returns (FantomonLib.Attributes memory);
    function getSpecies(uint256 _tokenId) external view returns (uint8);
    function getModifiers(uint256 _tokenId) external view returns (FantomonLib.Modifiers memory);
    function getAttacks(uint256 _tokenId) external view returns (FantomonLib.Attacks memory);

    function _heal(uint256 _tokenId, uint48 _amount, bool _force) external returns (bool);
    function _takeDamage(uint256 _tokenId, uint48 _dmg) external returns (bool);

    function _boostXpNutrients(uint256 _tokenId, FantomonLib.StatBoost memory _boost) external;
    function _boostXpMastery  (uint256 _tokenId, FantomonLib.StatBoost memory _boost) external;
    function _changeAttack(uint256 _tokenId, uint8 _slotIdx, uint8 _atkIdx) external;
    function _morph(uint256 _tokenId) external;
}


// File contracts/IFantomonRoyalties.sol





interface IFantomonRoyalties {
    function larkin_() external returns (address payable);
    function water_() external returns (address payable);
    function royaltyShares_() external returns (uint256 _shares);
    function  set25Receiver(uint256 _tokenId, address _receiver) external;
    function  set50Receiver(uint256 _tokenId, address _receiver) external;
    function  set75Receiver(uint256 _tokenId, address _receiver) external;
    function set100Receiver(uint256 _tokenId, address _receiver) external;
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address _receiver, uint256 _royaltyAmount);
    receive() external payable;
}


// File contracts/IFantomonGraphics.sol





interface IFantomonGraphics {
    function imageURI(uint256 _tokenId) external view returns (string memory);
    function tokenURI(uint256 _tokenId) external view returns (string memory);
}


// File contracts/IFantomonWhitelist.sol

interface IFantomonWhitelist {
    function whitelist_(uint256) external view returns (address);
    function isOnWhitelist_(address) external view returns (bool);
}


// File contracts/IFantomonRegistry.sol

interface IFantomonRegistry {
    function ftNFT_() external view returns (IFantomonTrainerInteractive);
    function ftstore_() external view returns (address);
    function fmonNFT_() external view returns (ERC721);
    function fstore_() external view returns (IFantomonStore);

    function royalties_() external view returns (IFantomonRoyalties);
    function feeding_() external view returns (address);
    function fighting_() external view returns (address);
    function dojo_() external view returns (address);
    function morphing_() external view returns (address);
    function ftgraphics_() external view returns (IFantomonGraphics);
    function fgraphics_() external view returns (IFantomonGraphics);

    function others_(string memory) external view returns (address);
}


// File contracts/FantomonFunctions.sol

/*
██╗░░░░░░█████╗░██████╗░██╗░░██╗██╗███╗░░██╗
██║░░░░░██╔══██╗██╔══██╗██║░██╔╝██║████╗░██║
██║░░░░░███████║██████╔╝█████═╝░██║██╔██╗██║
██║░░░░░██╔══██║██╔══██╗██╔═██╗░██║██║╚████║
███████╗██║░░██║██║░░██║██║░╚██╗██║██║░╚███║
╚══════╝╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚═╝╚═╝╚═╝░░╚══╝
*/




/**************************************************************************
 * Library of core Fantomon functions
 **************************************************************************/
library FantomonFunctions {
    /**************************************************************************
     * Some common constants
     **************************************************************************/
    uint48 constant private ONE_MIL =         1000000;  // constant to avoid mistyping 1mil's #zeros
    uint48 constant private MAX_XP  =   1069420000000;  // XP at max level:         1069420 * 1E6
    uint48 constant private MAX_NUTRIENTS = 300000000;  // Max combined stat nutrients: 300 * 1E6
    uint48 constant private MAX_MASTERY   = 300000000;  // Max combined stat nutrients: 300 * 1E6

    /**************************************************************************
     * Getters - probe some information about an FantomonLib.Fmon
     **************************************************************************/
    /* Did an FantomonLib.Fmon faint? Is it's damage equal to its scaled HP
     */
    function fainted(FantomonLib.Fmon memory _fmon) external pure returns (bool) {
        return _scaleHp(_fmon.base.hp, _fmon.nutrients.hp, _fmon.mastery.hp, _fmon.modifiers.hpVariance, _fmon.lvl) <= _fmon.dmg;
    }

    /* Serialize all attributes and stats of an FantomonLib.Fmon into a single array
     */
    function serialize(FantomonLib.Fmon calldata _fmon) external pure returns (uint256[36] memory _attrs) {
        FantomonLib.Stats memory scaled = scale(_fmon);
        _attrs[ 0] = _fmon.lvl                           ;
        _attrs[ 1] = _fmon.morph                         ;
        _attrs[ 2] = _fmon.xp                  / ONE_MIL ;
        _attrs[ 3] = _fmon.base.hp             / ONE_MIL ;
        _attrs[ 4] = _fmon.base.attack         / ONE_MIL ;
        _attrs[ 5] = _fmon.base.defense        / ONE_MIL ;
        _attrs[ 6] = _fmon.base.spAttack       / ONE_MIL ;
        _attrs[ 7] = _fmon.base.spDefense      / ONE_MIL ;
        _attrs[ 8] = scaled.hp                 / ONE_MIL ;
        _attrs[ 9] = scaled.attack             / ONE_MIL ;
        _attrs[10] = scaled.defense            / ONE_MIL ;
        _attrs[11] = scaled.spAttack           / ONE_MIL ;
        _attrs[12] = scaled.spDefense          / ONE_MIL ;
        _attrs[13] = _fmon.nutrients.hp        / ONE_MIL ;
        _attrs[14] = _fmon.nutrients.attack    / ONE_MIL ;
        _attrs[15] = _fmon.nutrients.defense   / ONE_MIL ;
        _attrs[16] = _fmon.nutrients.spAttack  / ONE_MIL ;
        _attrs[17] = _fmon.nutrients.spDefense / ONE_MIL ;
        _attrs[18] = _fmon.mastery.hp          / ONE_MIL ;
        _attrs[19] = _fmon.mastery.attack      / ONE_MIL ;
        _attrs[20] = _fmon.mastery.defense     / ONE_MIL ;
        _attrs[21] = _fmon.mastery.spAttack    / ONE_MIL ;
        _attrs[22] = _fmon.mastery.spDefense   / ONE_MIL ;
        _attrs[23] = _fmon.modifiers.hpVariance          ;
        _attrs[24] = _fmon.modifiers.attackVariance      ;
        _attrs[25] = _fmon.modifiers.defenseVariance     ;
        _attrs[26] = _fmon.modifiers.defenseVariance     ;
        _attrs[27] = _fmon.modifiers.spAttackVariance    ;
        _attrs[28] = _fmon.modifiers.spDefenseVariance   ;
        _attrs[29] = _fmon.attrs.species                 ;
        _attrs[30] = _fmon.attrs.typ                     ;
        _attrs[31] = _fmon.attrs.class                   ;
        _attrs[32] = _fmon.attrs.mood                    ;
        _attrs[33] = _fmon.attrs.essence                 ;
        _attrs[34] = _fmon.attacks.attack0               ;
        _attrs[35] = _fmon.attacks.attack1               ;
    }

    /**************************************************************************
     * Math, Transform, and Memory Functions to check values of
     * Stats and Boosts after applying some transform
     * - All performed in memory
     **************************************************************************/
    /* Return an FantomonLib.Fmon with its stats scaled */
    function scale(FantomonLib.Fmon calldata _fmon) public pure returns (FantomonLib.Stats memory _stats) {
        _stats.hp        =   _scaleHp(_fmon.base.hp,        _fmon.nutrients.hp,        _fmon.mastery.hp,        _fmon.modifiers.hpVariance,        _fmon.lvl);
        _stats.attack    = _scaleStat(_fmon.base.attack,    _fmon.nutrients.attack,    _fmon.mastery.attack,    _fmon.modifiers.attackVariance,    _fmon.lvl, _fmon.modifiers.essence);
        _stats.defense   = _scaleStat(_fmon.base.defense,   _fmon.nutrients.defense,   _fmon.mastery.defense,   _fmon.modifiers.defenseVariance,   _fmon.lvl, _fmon.modifiers.essence);
        _stats.spAttack  = _scaleStat(_fmon.base.spAttack,  _fmon.nutrients.spAttack,  _fmon.mastery.spAttack,  _fmon.modifiers.spAttackVariance,  _fmon.lvl, _fmon.modifiers.essence);
        _stats.spDefense = _scaleStat(_fmon.base.spDefense, _fmon.nutrients.spDefense, _fmon.mastery.spDefense, _fmon.modifiers.spDefenseVariance, _fmon.lvl, _fmon.modifiers.essence);
    }

    /* Functions to scale stats of an FantomonLib.Fmon */
    function scaleHp(FantomonLib.Fmon memory _fmon) internal pure returns (uint48) {
        return _scaleHp(_fmon.base.hp, _fmon.nutrients.hp, _fmon.mastery.hp, _fmon.modifiers.hpVariance, _fmon.lvl);
    }
    function scaleAttack(FantomonLib.Fmon memory _fmon) internal pure returns (uint48) {
        return _scaleStat(_fmon.base.attack,    _fmon.nutrients.attack,    _fmon.mastery.attack,    _fmon.modifiers.attackVariance,    _fmon.lvl, _fmon.modifiers.essence);
    }
    function scaleDefense(FantomonLib.Fmon memory _fmon) internal pure returns (uint48) {
        return _scaleStat(_fmon.base.defense,   _fmon.nutrients.defense,   _fmon.mastery.defense,   _fmon.modifiers.defenseVariance,   _fmon.lvl, _fmon.modifiers.essence);
    }
    function scaleSpAttack(FantomonLib.Fmon memory _fmon) internal pure returns (uint48) {
        return _scaleStat(_fmon.base.spAttack,  _fmon.nutrients.spAttack,  _fmon.mastery.spAttack,  _fmon.modifiers.spAttackVariance,  _fmon.lvl, _fmon.modifiers.essence);
    }
    function scaleSpDefense(FantomonLib.Fmon memory _fmon) internal pure returns (uint48) {
        return _scaleStat(_fmon.base.spDefense, _fmon.nutrients.spDefense, _fmon.mastery.spDefense, _fmon.modifiers.spDefenseVariance, _fmon.lvl, _fmon.modifiers.essence);
    }

    /* Mathematical formula to scale an FantomonLib.Fmon's HP
       Returns scaled HP x 1E6
     */
    function _scaleHp(uint256 _baseHpX1M, uint256 _statNutrientsX1M, uint256 _statMasteryX1M, uint256 _variance, uint256 _level) internal pure returns (uint48) {
        return uint48((((2 * _baseHpX1M +  (_variance * 1000000) + ((_statNutrientsX1M + _statMasteryX1M) / 4)) * _level) / 100) + (_level * 1000000) + 10000000);
    }

    /* Mathematical formula to scale an FantomonLib.Fmon's other stats
       Returns scaled stat x 1E6
     */
    function _scaleStat(uint256 _baseStatX1M, uint256 _statNutrientsX1M, uint256 _statMasteryX1M, uint256 _variance, uint256 _level, uint256 _essenceX1M) internal pure returns (uint48) {
        // div by 1E6 because both stat and essence are scaled by 1E6,
        // so numerator here is 1E12 and we want return result to be 1E6
        return uint48((((((2 * _baseStatX1M + (_variance * 1000000) + ((_statNutrientsX1M + _statMasteryX1M) / 4)) * _level) / 100) + 5000000) * _essenceX1M) / 1000000);
    }
    /* Given a some stats, return those stats after applying a boost
     */
    function boost(FantomonLib.Stats memory _stats, FantomonLib.StatBoost memory _boost) external pure returns (FantomonLib.Stats memory) {
        _stats.hp        += _boost.hp;
        _stats.attack    += _boost.attack;
        _stats.defense   += _boost.defense;
        _stats.spAttack  += _boost.spAttack;
        _stats.spDefense += _boost.spDefense;
        return _stats;
    }

    /* Given a Stat Boost, return that boost after multplying it by the provided ration (_numerator / _denominator).
       Useful when you fed too much, and can only apply a fraction of each stat boost.
     */
    function applyRatio(FantomonLib.StatBoost memory _boost, uint256 _numerator, uint256 _denominator) external pure returns (FantomonLib.StatBoost memory) {
        _boost.hp        = uint48((_numerator * _boost.hp)        / _denominator);
        _boost.attack    = uint48((_numerator * _boost.attack)    / _denominator);
        _boost.defense   = uint48((_numerator * _boost.defense)   / _denominator);
        _boost.spAttack  = uint48((_numerator * _boost.spAttack)  / _denominator);
        _boost.spDefense = uint48((_numerator * _boost.spDefense) / _denominator);
        return _boost;
    }
    /* Given a Stat Boost, return that boost after multplying all of its members by _amount.
       Useful when feeding an "amount" of food
     */
    function mul(FantomonLib.StatBoost memory _boost, uint48 _amount) external pure returns (FantomonLib.StatBoost memory) {
        _boost.xp        *= _amount;
        _boost.hp        *= _amount;
        _boost.attack    *= _amount;
        _boost.defense   *= _amount;
        _boost.spAttack  *= _amount;
        _boost.spDefense *= _amount;
        return _boost;
    }
    /* Given a Stat Boost, return that boost after multplying all of its members by _amount.
     */
    function div(FantomonLib.StatBoost memory _boost, uint48 _amount) external pure returns (FantomonLib.StatBoost memory) {
        _boost.xp        /= _amount;
        _boost.hp        /= _amount;
        _boost.attack    /= _amount;
        _boost.defense   /= _amount;
        _boost.spAttack  /= _amount;
        _boost.spDefense /= _amount;
        return _boost;
    }

    /* Sum all member FantomonLib.Stats and return
     */
    function sum(FantomonLib.Stats memory _stats) public pure returns (uint48) {
        return _stats.hp + _stats.attack + _stats.defense + _stats.spAttack + _stats.spDefense;
    }

    /* Sum all members of a Stat Boost, except XP, return
     */
    function sum(FantomonLib.StatBoost memory _boost) external pure returns (uint48) {
        return _boost.hp + _boost.attack + _boost.defense + _boost.spAttack + _boost.spDefense;
    }
    /* Sum all members of a Stat Boost, return
     */
    function sumWithXp(FantomonLib.StatBoost memory _boost) external pure returns (uint48) {
        return _boost.xp + _boost.hp + _boost.attack + _boost.defense + _boost.spAttack + _boost.spDefense;
    }

    /**************************************************************************
     * Storage Functions to update FantomonLib.Fmons in Storage
     **************************************************************************/
    /* Given an FantomonLib.Fmon in storage, boost its XP and Nutrients
       Applying the boost to storage
     */
    function commitXpNutrientBoost(FantomonLib.Fmon storage _fmon, FantomonLib.StatBoost memory _boost) external {
        _fmon.xp                  += _boost.xp;
        _fmon.nutrients.hp        += _boost.hp;
        _fmon.nutrients.attack    += _boost.attack;
        _fmon.nutrients.defense   += _boost.defense;
        _fmon.nutrients.spAttack  += _boost.spAttack;
        _fmon.nutrients.spDefense += _boost.spDefense;
        uint48 xp = _fmon.xp;
        require(xp <= MAX_XP && sum(_fmon.nutrients) <= MAX_NUTRIENTS, "Boost overflow");
        _fmon.lvl = xp2Lvl(xp);
    }
    /* Given an FantomonLib.Fmon in storage, boost its XP and Mastery
       Applying the boost to storage
     */
    function commitXpMasteryBoost(FantomonLib.Fmon storage _fmon, FantomonLib.StatBoost memory _boost) external {
        _fmon.xp                += _boost.xp;
        _fmon.mastery.hp        += _boost.hp;
        _fmon.mastery.attack    += _boost.attack;
        _fmon.mastery.defense   += _boost.defense;
        _fmon.mastery.spAttack  += _boost.spAttack;
        _fmon.mastery.spDefense += _boost.spDefense;
        uint48 xp = _fmon.xp;
        require(xp <= MAX_XP && sum(_fmon.mastery) <= MAX_MASTERY, "Boost overflow");
        _fmon.lvl = xp2Lvl(xp);
    }
    /* Mock versions of the previous two functions that do not update storage,
       just return the updated FantomonLib.Fmon. Useful for checking
       "how would this boost (feed/fight) affect my FantomonLib.Fmon?"
     */
    function mockXpNutrientBoost(FantomonLib.Fmon memory _fmon, FantomonLib.StatBoost memory _boost) external pure returns (FantomonLib.Fmon memory) {
        _fmon.xp                  += _boost.xp;
        _fmon.nutrients.hp        += _boost.hp;
        _fmon.nutrients.attack    += _boost.attack;
        _fmon.nutrients.defense   += _boost.defense;
        _fmon.nutrients.spAttack  += _boost.spAttack;
        _fmon.nutrients.spDefense += _boost.spDefense;
        require(_fmon.xp <= MAX_XP && sum(_fmon.nutrients) <= MAX_NUTRIENTS, "Boost overflow");
        _fmon.lvl = xp2Lvl(_fmon.xp);
        return _fmon;
    }
    function mockXpMasteryBoost(FantomonLib.Fmon memory _fmon, FantomonLib.StatBoost memory _boost) external pure returns (FantomonLib.Fmon memory) {
        _fmon.xp                += _boost.xp;
        _fmon.mastery.hp        += _boost.hp;
        _fmon.mastery.attack    += _boost.attack;
        _fmon.mastery.defense   += _boost.defense;
        _fmon.mastery.spAttack  += _boost.spAttack;
        _fmon.mastery.spDefense += _boost.spDefense;
        require(_fmon.xp <= MAX_XP && sum(_fmon.mastery) <= MAX_MASTERY, "Boost overflow");
        _fmon.lvl = xp2Lvl(_fmon.xp);
        return _fmon;
    }
    /* Calculate Lvl given XP
     */
    function xp2Lvl(uint48 _xp) public pure returns (uint8) {
        uint48[100] memory XP_PER_LEVEL = [
                       0,
                 8000000,
                27000000,
                64000000,
               125000000,
               216000000,
               343000000,
               512000000,
               729000000,
              1000000000,
              1331000000,
              1728000000,
              2197000000,
              2744000000,
              3375000000,
              4096000000,
              4913000000,
              5832000000,
              6859000000,
              8000000000,
              9261000000,
             10648000000,
             12167000000,
             13824000000,
             15625000000,
             17576000000,
             19683000000,
             21952000000,
             24389000000,
             27000000000,
             29791000000,
             32768000000,
             35937000000,
             39304000000,
             42875000000,
             46656000000,
             50653000000,
             54872000000,
             59319000000,
             64000000000,
             68921000000,
             74088000000,
             79507000000,
             85184000000,
             91125000000,
             97336000000,
            103823000000,
            110592000000,
            117649000000,
            125000000000,
            132651000000,
            140608000000,
            148877000000,
            157464000000,
            166375000000,
            175616000000,
            185193000000,
            195112000000,
            205379000000,
            216000000000,
            226981000000,
            238328000000,
            250047000000,
            262144000000,
            274625000000,
            287496000000,
            300763000000,
            314432000000,
            328509000000,
            343000000000,
            357911000000,
            373248000000,
            389017000000,
            405224000000,
            421875000000,
            438976000000,
            456533000000,
            474552000000,
            493039000000,
            512000000000,
            531441000000,
            551368000000,
            571787000000,
            592704000000,
            614125000000,
            636056000000,
            658503000000,
            681472000000,
            704969000000,
            729000000000,
            753571000000,
            778688000000,
            804357000000,
            830584000000,
            857375000000,
            884736000000,
            912673000000,
            941192000000,
            970299000000,
                  MAX_XP
        ];
        for (uint8 lvl = 1; lvl <= 100; lvl++) {
            if (XP_PER_LEVEL[lvl-1] <= _xp && (lvl == 100 || XP_PER_LEVEL[lvl] > _xp)) {
                 return lvl;
            }
        }
        revert("Invalid XP");
    }
    /* What is the XP it takes to get to the given Lvl
     */
    function lvl2Xp(uint8 _lvl) public pure returns (uint48) {
        uint48[100] memory XP_PER_LEVEL = [
                       0,
                 8000000,
                27000000,
                64000000,
               125000000,
               216000000,
               343000000,
               512000000,
               729000000,
              1000000000,
              1331000000,
              1728000000,
              2197000000,
              2744000000,
              3375000000,
              4096000000,
              4913000000,
              5832000000,
              6859000000,
              8000000000,
              9261000000,
             10648000000,
             12167000000,
             13824000000,
             15625000000,
             17576000000,
             19683000000,
             21952000000,
             24389000000,
             27000000000,
             29791000000,
             32768000000,
             35937000000,
             39304000000,
             42875000000,
             46656000000,
             50653000000,
             54872000000,
             59319000000,
             64000000000,
             68921000000,
             74088000000,
             79507000000,
             85184000000,
             91125000000,
             97336000000,
            103823000000,
            110592000000,
            117649000000,
            125000000000,
            132651000000,
            140608000000,
            148877000000,
            157464000000,
            166375000000,
            175616000000,
            185193000000,
            195112000000,
            205379000000,
            216000000000,
            226981000000,
            238328000000,
            250047000000,
            262144000000,
            274625000000,
            287496000000,
            300763000000,
            314432000000,
            328509000000,
            343000000000,
            357911000000,
            373248000000,
            389017000000,
            405224000000,
            421875000000,
            438976000000,
            456533000000,
            474552000000,
            493039000000,
            512000000000,
            531441000000,
            551368000000,
            571787000000,
            592704000000,
            614125000000,
            636056000000,
            658503000000,
            681472000000,
            704969000000,
            729000000000,
            753571000000,
            778688000000,
            804357000000,
            830584000000,
            857375000000,
            884736000000,
            912673000000,
            941192000000,
            970299000000,
                  MAX_XP
        ];
        return XP_PER_LEVEL[_lvl];
    }
}


// File contracts/FantomonFeeding.sol

/*
██╗░░░░░░█████╗░██████╗░██╗░░██╗██╗███╗░░██╗
██║░░░░░██╔══██╗██╔══██╗██║░██╔╝██║████╗░██║
██║░░░░░███████║██████╔╝█████═╝░██║██╔██╗██║
██║░░░░░██╔══██║██╔══██╗██╔═██╗░██║██║╚████║
███████╗██║░░██║██║░░██║██║░╚██╗██║██║░╚███║
╚══════╝╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚═╝╚═╝╚═╝░░╚══╝
*/





/**************************************************************************
 * Contract to expose Fantomon Feeding funtionality to the player
 * Owner sets the menu, player feeds, contract makes calls to FantomonStore
 * to commit Nutrient + XP + Lvl updates to Fmon storage.
 **************************************************************************/
contract FantomonFeeding is Ownable {

    using FantomonFunctions for FantomonLib.Fmon;
    using FantomonFunctions for FantomonLib.StatBoost;
    using FantomonFunctions for FantomonLib.Stats;

    uint48 constant public MAX_XP        = 1069420000000;  // XP at max level:         1069420 * 1E6
    uint48 constant public LVL25_XP      =   15625000000;  // XP to get to LVL25
    uint48 constant public LVL50_XP      =  125000000000;  // XP to get to LVL50
    uint48 constant public LVL75_XP      =  421875000000;  // XP to get to LVL75
    uint48 constant public MAX_NUTRIENTS =     300000000;  // Max combined stat nutrients: 300 * 1E6

    uint256 constant private ONE_MIL = 1000000; // constant to avoid typos (like extra 0s)

    IFantomonRegistry public registry_;

    ERC20[] public foods_;
    mapping(ERC20 => bool) public foodEnabled_; // is a food enabled?
    mapping(ERC20 => bool) public foodBurnable_; // is a food burnable via burnFrom()
    mapping(ERC20 => FantomonLib.StatBoost[2]) public foodBoosts_;

    constructor(IFantomonRegistry _registry) {
        registry_ = _registry;
    }


    /**************************************************************************
     * Add/Change/Remove functions for owner to set the menu
     * (food contracts and their associated boosts).
     * Each food has 2 boost options that are selected via an arg to feed().
     **************************************************************************/
    function addFood(ERC20 _food, bool _burnable,
                     uint48[2] memory _xpBoosts,       uint48[2] memory _hpBoosts,
                     uint48[2] memory _attackBoosts,   uint48[2] memory _defenseBoosts,
                     uint48[2] memory _spAttackBoosts, uint48[2] memory _spDefenseBoosts) external onlyOwner {


        require(address(_food) != address(0), "Food addr cant be 0");
        require(!foodEnabled_[_food], "Food already on menu");

        foods_.push(_food);
        foodEnabled_[_food] = true;
        foodBurnable_[_food] = _burnable;

        FantomonLib.StatBoost memory boost0;
        boost0.xp        = _xpBoosts[0];
        boost0.hp        = _hpBoosts[0];
        boost0.attack    = _attackBoosts[0];
        boost0.defense   = _defenseBoosts[0];
        boost0.spAttack  = _spAttackBoosts[0];
        boost0.spDefense = _spDefenseBoosts[0];
        foodBoosts_[_food][0] = boost0;

        FantomonLib.StatBoost memory boost1;
        boost1.xp        = _xpBoosts[1];
        boost1.hp        = _hpBoosts[1];
        boost1.attack    = _attackBoosts[1];
        boost1.defense   = _defenseBoosts[1];
        boost1.spAttack  = _spAttackBoosts[1];
        boost1.spDefense = _spDefenseBoosts[1];
        foodBoosts_[_food][1] = boost1;
    }

    function rmFood(ERC20 _food) external onlyOwner {
        require(foodEnabled_[_food], "Not on menu");
        foodEnabled_[_food] = false;
    }

    function changeFood(ERC20 _food, bool _burnable,
                        uint48[2] memory _xpBoosts,       uint48[2] memory _hpBoosts,
                        uint48[2] memory _attackBoosts,   uint48[2] memory _defenseBoosts,
                        uint48[2] memory _spAttackBoosts, uint48[2] memory _spDefenseBoosts) external onlyOwner {

        require(foodEnabled_[_food], "Not on menu");
        foodBurnable_[_food] = _burnable;

        FantomonLib.StatBoost memory boost0;
        boost0.xp        = _xpBoosts[0];
        boost0.hp        = _hpBoosts[0];
        boost0.attack    = _attackBoosts[0];
        boost0.defense   = _defenseBoosts[0];
        boost0.spAttack  = _spAttackBoosts[0];
        boost0.spDefense = _spDefenseBoosts[0];
        foodBoosts_[_food][0] = boost0;

        FantomonLib.StatBoost memory boost1;
        boost1.xp        = _xpBoosts[1];
        boost1.hp        = _hpBoosts[1];
        boost1.attack    = _attackBoosts[1];
        boost1.defense   = _defenseBoosts[1];
        boost1.spAttack  = _spAttackBoosts[1];
        boost1.spDefense = _spDefenseBoosts[1];
        foodBoosts_[_food][1] = boost1;
    }

    /**************************************************************************
     * Feed an Fmon with an amount of the given food.
     * Select a boost mode/option (each food has 2 boost options)
     * and choose whether to force-feed if boost surpasses MAX_XP.
     * Call helper function to update royalties if Lvl 25/50/75/100 is reached.
     **************************************************************************/
    function feed(uint256 _tokenId, ERC20 _food, uint8 _mode, uint48 _amountNoDecimals, bool _force) external {
        IFantomonStore fstore = registry_.fstore_();

        require(msg.sender == registry_.fmonNFT_().ownerOf(_tokenId), "Only token owner can");
        require(_amountNoDecimals != 0, "0 invalid amount");
        require(foodEnabled_[_food], "Not on menu");

        // Get boost by applying amount+mode to menu item
        FantomonLib.StatBoost memory boost = foodBoosts_[_food][_mode].mul(_amountNoDecimals);
        // Get current/original XP and Nutrients
        (uint48 origXp,
         FantomonLib.Stats memory nutrients) = fstore.getXpNutrients(_tokenId);

        require(nutrients.sum() < MAX_NUTRIENTS || origXp < MAX_XP, "Already maxed!");

        uint48 newXp = origXp + boost.xp;
        require(_force || newXp <= MAX_XP, "Can only force-feed past MAX_XP");  // provide some buffer

        if (newXp > MAX_XP) {
            boost.xp = MAX_XP - origXp;
            newXp = MAX_XP;
        }

        // Update the royalties at special levels
        _updateRoyalties(_tokenId, origXp, newXp);

        // Normalize the boost (in case it exceeds max), and apply to Fmon storage
        fstore._boostXpNutrients(_tokenId, _normalizeNutrientBoost(nutrients, boost));

        // BURN BABY BURN!
        // ... approval requirement handled by ERC20 contract
        if (foodBurnable_[_food]) {
            ERC20Burnable(address(_food)).burnFrom(msg.sender, _amountNoDecimals * (10**_food.decimals()));
        } else {
            _food.transferFrom(msg.sender, 0x000000000000000000000000000000000000dEaD, _amountNoDecimals * (10**_food.decimals()));
        }
    }

    /**************************************************************************
     * Helpers for feeding
     **************************************************************************/

    // Update the royalties at special levels
    function _updateRoyalties(uint256 _tokenId, uint48 _origXp, uint48 _newXp) internal {
        IFantomonRoyalties royalties = registry_.royalties_();
        address leveler = registry_.fmonNFT_().ownerOf(_tokenId);
        // Handle level up and special actions at special levels
        if (_origXp < LVL25_XP && _newXp >= LVL25_XP) {
            royalties.set25Receiver(_tokenId, leveler);
        }
        if (_origXp < LVL50_XP && _newXp >= LVL50_XP) {
            royalties.set50Receiver(_tokenId, leveler);
        }
        if (_origXp < LVL75_XP && _newXp >= LVL75_XP) {
            royalties.set75Receiver(_tokenId, leveler);
        }
        if (_origXp < MAX_XP && _newXp >= MAX_XP) {
            royalties.set100Receiver(_tokenId, leveler);
        }
    }
    // Normalize the boost (in case it exceeds max)
    function _normalizeNutrientBoost(FantomonLib.Stats memory _nutrients, FantomonLib.StatBoost memory _boost) internal pure returns (FantomonLib.StatBoost memory) {
        uint48 nutrientsLeft = MAX_NUTRIENTS - _nutrients.sum();
        // Nothing to do if no nutrients left to allocate
        if (nutrientsLeft > 0) {
            uint48 nutrientsFed = _boost.sum();  // sum of all nutrients in a boost
            if (nutrientsFed > nutrientsLeft) {
                // if this boost would pass max nutrients, don't let it!
                // get the ratio of the boost's nutrients to nutrients-left
                // and apply it to all boost elements
                _boost = _boost.applyRatio(nutrientsLeft, nutrientsFed);

                // Handle any leftovers from rounding division, make sure to add to one of the stats already being boosted
                nutrientsLeft = nutrientsLeft - _boost.sum();
                if (nutrientsLeft > 0) {
                    if (_boost.hp > 0) {
                        _boost.hp += nutrientsLeft;
                    } else if (_boost.attack > 0) {
                        _boost.attack += nutrientsLeft;
                    } else if (_boost.defense > 0) {
                        _boost.defense += nutrientsLeft;
                    } else if (_boost.spAttack > 0) {
                        _boost.spAttack += nutrientsLeft;
                    } else if (_boost.spDefense > 0) {
                        _boost.spDefense += nutrientsLeft;
                    }
                }
            }
            return _boost;
        } else {
            return FantomonLib.StatBoost(_boost.xp, 0, 0, 0, 0, 0);
        }
    }

    /**************************************************************************
     * Helper Getters for externally calculating a feed
     **************************************************************************/
    // Make-believe feed to see the impact it would have on an Fmon
    function mockFeed(uint256 _tokenId, ERC20 _food, uint8 _mode, uint48 _amount, bool _force) external view returns (FantomonLib.Fmon memory) {
        IFantomonStore fstore = registry_.fstore_();

        require(_amount != 0, "0 invalid amount");
        require(foodEnabled_[_food], "Not on menu");

        FantomonLib.StatBoost memory boost = foodBoosts_[_food][_mode].mul(_amount);
        FantomonLib.Fmon memory fmon = fstore.fmon(_tokenId);
        uint48 origXp = fmon.xp;
        FantomonLib.Stats memory nutrients = fmon.nutrients;

        require(nutrients.sum() < MAX_NUTRIENTS || origXp < MAX_XP, "Already maxed!");

        uint48 newXp = origXp + boost.xp;

        require(_force || newXp <= MAX_XP, "Can only force-feed past MAX_XP");  // provide some buffer
        if (newXp > MAX_XP) {
            boost.xp = MAX_XP - origXp;
        }
        return fmon.mockXpNutrientBoost(boost);
    }

    // How much of a given food would it take to get to max XP?
    function foodToMaxXp(uint256 _tokenId, ERC20 _food, uint256 _mode) external view returns (uint48) {
        require(foodEnabled_[_food], "Not on menu");

        uint48 xpPerFood = foodBoosts_[_food][_mode].xp;
        uint48 xpLeft = MAX_XP - registry_.fstore_().getXp(_tokenId);

        return xpLeft / xpPerFood;
    }
}