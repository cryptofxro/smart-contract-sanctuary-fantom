/**
 *Submitted for verification at FtmScan.com on 2022-04-30
*/

// File: @openzeppelin/contracts/utils/cryptography/MerkleProof.sol


// OpenZeppelin Contracts (last updated v4.5.0) (utils/cryptography/MerkleProof.sol)

pragma solidity ^0.8.0;

/**
 * @dev These functions deal with verification of Merkle Trees proofs.
 *
 * The proofs can be generated using the JavaScript library
 * https://github.com/miguelmota/merkletreejs[merkletreejs].
 * Note: the hashing algorithm should be keccak256 and pair sorting should be enabled.
 *
 * See `test/utils/cryptography/MerkleProof.test.js` for some examples.
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merklee tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. When processing the proof, the pairs
     * of leafs & pre-images are assumed to be sorted.
     *
     * _Available since v4.4._
     */
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = _efficientHash(computedHash, proofElement);
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = _efficientHash(proofElement, computedHash);
            }
        }
        return computedHash;
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}

// File: @openzeppelin/contracts/utils/Address.sol


// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

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


// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

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

// File: @openzeppelin/contracts/security/Pausable.sol


// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;


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

// File: Auction.sol


pragma solidity 0.8.12;





//       _   _____  _____   ______  _________  _____   ___   ____  _____  
//      / \ |_   _||_   _|.' ___  ||  _   _  ||_   _|.'   `.|_   \|_   _| 
//     / _ \  | |    | | / .'   \_||_/ | | \_|  | | /  .-.  \ |   \ | |   
//    / ___ \ | '    ' | | |           | |      | | | |   | | | |\ \| |   
//  _/ /   \ \_\ \__/ /  \ `.___.'\   _| |_    _| |_\  `-'  /_| |_\   |_  
// |____| |____|`.__.'    `.____ .'  |_____|  |_____|`.___.'|_____|\____| 
                                                                       

contract Auction is Ownable, Pausable {
  using SafeERC20 for IERC20;

  uint256 public immutable minimumUnitPrice;
  uint256 public immutable minimumBidIncrement;
  uint256 public immutable unitPriceStepSize;
  uint256 public immutable minimumQuantity;
  uint256 public immutable maximumQuantity;
  uint256 public immutable numberOfAuctions;
  uint256 public immutable itemsPerAuction;
  address payable public immutable beneficiaryAddress;

  // Total auction length - including the last X hours inside which it can randomly end
  uint256 public auctionLengthInHours = 24;
  // The target number for the random end's random number generator.
  // MUST be < endWindows to have an even chance of ending each window
  uint256 constant randomEnd = 7;
  // Auction randomly ends within last auctionEndThresholdHrs
  uint256 public constant auctionEndThresholdHrs = 3;
  // Number of time windows inside the threshold in which the auction can randomly end
  uint256 public constant endWindows = 18;
  // block timestamp of when auction starts
  uint256 public auctionStart;
  // Merkle root of those addresses owed a refund
  bytes32 public refundMerkleRoot;

  AuctionStatus private _auctionStatus;
  uint256 private _bidIndex;

  event AuctionStarted();
  event AuctionEnded();
  event BidPlaced(
    bytes32 indexed bidHash,
    uint256 indexed auctionIndex,
    address indexed bidder,
    uint256 bidIndex,
    uint256 unitPrice,
    uint256 quantity,
    uint256 balance
  );
  event RefundIssued(address indexed refundRecipient, uint256 refundAmount);

  struct Bid {
    uint128 unitPrice;
    uint128 quantity;
  }

  struct AuctionStatus {
    bool started;
    bool ended;
  }

  // keccak256(auctionIndex, bidder address) => current bid
  mapping(bytes32 => Bid) private _bids;
  // Refunds address => excessRefunded
  mapping(address => bool) private _excessRefunded;
  // Auction end checks windowIndex => windowChecked
  mapping(uint256 => bool) private _windowChecked;

  // Beneficiary address cannot be changed after deployment.
  constructor(
    address payable beneficiaryAddress_,
    uint256 minimumUnitPrice_,
    uint256 minimumBidIncrement_,
    uint256 unitPriceStepSize_,
    uint256 maximumQuantity_,
    uint256 numberOfAuctions_,
    uint256 itemsPerAuction_
  ) {
    beneficiaryAddress = beneficiaryAddress_;
    minimumUnitPrice = minimumUnitPrice_;
    minimumBidIncrement = minimumBidIncrement_;
    unitPriceStepSize = unitPriceStepSize_;
    minimumQuantity = 1;
    maximumQuantity = maximumQuantity_;
    numberOfAuctions = numberOfAuctions_;
    itemsPerAuction = itemsPerAuction_;
    pause();
  }

  modifier whenRefundsActive() {
    require(refundMerkleRoot != 0, "Refund merkle root not set");
    _;
  }

  modifier whenAuctionActive() {
    require(!_auctionStatus.ended, "Auction has already ended");
    require(_auctionStatus.started, "Auction hasn't started yet");
    _;
  }

  modifier whenPreAuction() {
    require(!_auctionStatus.ended, "Auction has already ended");
    require(!_auctionStatus.started, "Auction has already started");
    _;
  }

  modifier whenAuctionEnded() {
    require(_auctionStatus.ended, "Auction hasn't ended yet");
    require(_auctionStatus.started, "Auction hasn't started yet");
    _;
  }

  function auctionStatus() public view returns (AuctionStatus memory) {
    return _auctionStatus;
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  function startAuction() external onlyOwner whenPreAuction {
    _auctionStatus.started = true;
    auctionStart = block.timestamp;

    if (paused()) {
      unpause();
    }
    emit AuctionStarted();
  }

  function getAuctionEnd() internal view returns (uint256) {
    return auctionStart + (auctionLengthInHours * 1 hours);
  }

  function endAuction() external whenAuctionActive {
    require(
      block.timestamp >= getAuctionEnd(),
      "Auction can't be stopped until due"
    );
    _endAuction();
  }

  function _endAuction() internal whenAuctionActive {
    _auctionStatus.ended = true;
    if (!paused()) {
      _pause();
    }
    emit AuctionEnded();
  }

  function numberOfBidsPlaced() external view returns (uint256) {
    return _bidIndex;
  }

  function getBid(uint256 auctionIndex_, address bidder_)
    external
    view
    returns (Bid memory)
  {
    return _bids[_bidHash(auctionIndex_, bidder_)];
  }

  function _bidHash(uint256 auctionIndex_, address bidder_)
    internal
    pure
    returns (bytes32)
  {
    return keccak256(abi.encode(auctionIndex_, bidder_));
  }

  function _refundHash(uint256 refundAmount_, address bidder_)
    internal
    pure
    returns (bytes32)
  {
    return keccak256(abi.encode(refundAmount_, bidder_));
  }

  // When a bidder places a bid or updates their existing bid, they will use this function.
  // - total value can never be lowered
  // - unit price can never be lowered
  // - quantity can be raised or lowered, but only if unit price is raised to meet or exceed previous total price
  function placeBid(
    uint256 auctionIndex_,
    uint256 quantity_,
    uint256 unitPrice_
  ) external payable whenNotPaused whenAuctionActive {
    // If the bidder is increasing their bid, the amount being added must be greater than or equal to the minimum bid increment.
    // A msg.value of 0 can be valid if the bidder is updating their bid but no new ether is required.
    if (msg.value > 0 && msg.value < minimumBidIncrement) {
      revert("Bid lower than minimum bid increment.");
    }

    // Ensure auctionIndex is within valid range.
    // For a multi-phase auction like loomlock, this would be insuffucient. You would need to store a state var for the current auction index and require that the auctionIndex_ param == that index.
    require(auctionIndex_ < numberOfAuctions, "Invalid auctionIndex");

    // Cache initial bid values.
    bytes32 bidHash = _bidHash(auctionIndex_, msg.sender);
    uint256 initialUnitPrice = _bids[bidHash].unitPrice;
    uint256 initialQuantity = _bids[bidHash].quantity;
    uint256 initialBalance = initialUnitPrice * initialQuantity;

    // Cache final bid values.
    uint256 finalUnitPrice = unitPrice_;
    uint256 finalQuantity = quantity_;
    uint256 finalBalance = initialBalance + msg.value;

    // Don't allow bids with a unit price scale smaller than unitPriceStepSize.
    // For example, allow 1.01 or 111.01 but don't allow 1.011.
    require(
      finalUnitPrice % unitPriceStepSize == 0,
      "Unit price step too small"
    );

    // Reject bids that don't have a quantity within the valid range.
    require(finalQuantity >= minimumQuantity, "Quantity too low");
    require(finalQuantity <= maximumQuantity, "Quantity too high");

    // Balance can never be lowered. This can't really ever happen because of the way finalBalance is defined.
    require(finalBalance >= initialBalance, "Balance can't be lowered");

    // Unit price can never be lowered.
    // Quantity can be raised or lowered, but it can only be lowered if the unit price is raised to meet or exceed the initial total value. Ensuring the the unit price is never lowered takes care of this.
    require(finalUnitPrice >= initialUnitPrice, "Unit price can't be lowered");

    // Ensure the new finalBalance equals quantity * the unit price that was given in this txn exactly. This is important to prevent rounding errors later when returning ether.
    require(
      finalQuantity * finalUnitPrice == finalBalance,
      "Quantity * Unit Price != Total Value"
    );

    // Unit price must be greater than or equal to the minimumUnitPrice.
    require(finalUnitPrice >= minimumUnitPrice, "Bid unit price too low");

    // Something must be changing from the initial bid for this new bid to be valid.
    if (
      initialUnitPrice == finalUnitPrice && initialQuantity == finalQuantity
    ) {
      revert("This bid doesn't change anything");
    }

    // Update the bidder's bid.
    _bids[bidHash].unitPrice = uint128(finalUnitPrice);
    _bids[bidHash].quantity = uint128(finalQuantity);

    emit BidPlaced(
      bidHash,
      auctionIndex_,
      msg.sender,
      _bidIndex,
      finalUnitPrice,
      finalQuantity,
      finalBalance
    );

    // Increment after emitting the BidPlaced event because counter is 0-indexed.
    _bidIndex += 1;

    // After the bid has been placed, check to see whether the auction is ended
    _checkAuctionEnd();
  }

  function withdrawContractBalance() external onlyOwner {
    (bool success, ) = beneficiaryAddress.call{value: address(this).balance}(
      ""
    );
    require(success, "Transfer failed");
  }

  // A withdraw function to avoid locking ERC20 tokens in the contract forever.
  // Tokens can only be withdrawn by the owner, to the owner.
  function transferERC20Token(IERC20 token, uint256 amount) external onlyOwner {
    token.safeTransfer(owner(), amount);
  }

  // Handles receiving ether to the contract.
  // Reject all direct payments to the contract except from beneficiary and owner.
  // Bids must be placed using the placeBid function.
  receive() external payable {
    require(msg.value > 0, "No ether was sent");
    require(
      msg.sender == beneficiaryAddress || msg.sender == owner(),
      "Only owner or beneficiary can fund contract"
    );
  }

  function setRefundMerkleRoot(bytes32 refundMerkleRoot_)
    external
    onlyOwner
    whenAuctionEnded
  {
    refundMerkleRoot = refundMerkleRoot_;
  }

  function claimRefund(uint256 refundAmount_, bytes32[] calldata proof_)
    external
    whenNotPaused
    whenAuctionEnded
    whenRefundsActive
  {
    // Can only refund if we haven't already refunded this address:
    require(!_excessRefunded[msg.sender], "Refund already issued");

    bytes32 leaf = _refundHash(refundAmount_, msg.sender);
    require(
      MerkleProof.verify(proof_, refundMerkleRoot, leaf),
      "Refund proof invalid"
    );

    // Safety check - we shouldn't be refunding more than this address has bid across all auctions. This will also
    // catch data collision exploits using other address and refund amount combinations, if
    // such are possible:
    uint256 totalBalance;
    for (
      uint256 auctionIndex = 0;
      auctionIndex < numberOfAuctions;
      auctionIndex++
    ) {
      bytes32 bidHash = _bidHash(auctionIndex, msg.sender);
      totalBalance += _bids[bidHash].unitPrice * _bids[bidHash].quantity;
    }

    require(refundAmount_ <= totalBalance, "Refund request exceeds balance");

    // Set state - we are issuing a refund to this address now, therefore
    // this logic path cannot be entered again for this address:
    _excessRefunded[msg.sender] = true;

    // State has been set, we can now send the refund:
    (bool success, ) = msg.sender.call{value: refundAmount_}("");
    require(success, "Refund failed");

    emit RefundIssued(msg.sender, refundAmount_);
  }

  function _checkAuctionEnd() internal {
    // (1) If we are at or past the end time it's the end of the action:
    if (block.timestamp >= getAuctionEnd()) {
      _endAuction();
    } else {
      // (2) Still going? See if we are in the threshold:
      uint256 auctionEndThreshold = getAuctionEnd() -
        (auctionEndThresholdHrs * 1 hours);
      if (block.timestamp >= auctionEndThreshold) {
        uint256 windowSize = (auctionEndThresholdHrs * 1 hours) / endWindows;
        uint256 windowIndex = (block.timestamp - auctionEndThreshold) /
          windowSize;
        if (!_windowChecked[windowIndex]) {
          _windowChecked[windowIndex] = true;
          // End logic is simple, we do a modulo on the random number using the number of
          // windows. We check the value (something that must be < endWindows to sure even probability each window).
          // Auction ends if they match.
          if (_getRandomNumber() % endWindows == randomEnd) {
            _endAuction();
          }
        }
      }
    }
  }

  function _getRandomNumber() internal view returns (uint256) {
    return
      uint256(keccak256(abi.encode(_bidIndex, blockhash(block.number - 1))));
  }
}