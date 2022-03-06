/**
 *Submitted for verification at FtmScan.com on 2022-03-06
*/

/**
 *Submitted for verification at FtmScan.com on 2022-02-04
*/

/**
 *Submitted for verification at FtmScan.com on 2022-02-04
*/

// SPDX-License-Identifier: MIT
//
// SPACE
//                                 ..                                  
//                           x .d88"                                   
//  .d``                      5888R                                    
//  @8Ne.   .u         u      '888R         u           .        .u    
//  %8888:[email protected]     us888u.    888R      us888u.   .udR88N    ud8888.  
//   `888I  888. [email protected] "8888"   888R   [email protected] "8888" <888'888k :888'8888. 
//    888I  888I 9888  9888    888R   9888  9888  9888 'Y"  d888 '88%" 
//    888I  888I 9888  9888    888R   9888  9888  9888      8888.+"    
//  uW888L  888' 9888  9888    888R   9888  9888  9888      8888L      
// '*88888Nu88P  9888  9888   .888B . 9888  9888  ?8888u../ '8888c. .+ 
// ~ '88888F`    "888*""888"  ^*888%  "888*""888"  "8888P'   "88888%   
//    888 ^       ^Y"   ^Y'     "%     ^Y"   ^Y'     "P'       "YP'    
//    *8E                                                              
//    '8>                                                              
//     "                      
//  v3 in space ~ added exitAll function to save gas
// File: @openzeppelin/contracts/token/ERC721/IERC721Receiver.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721Receiver.sol)

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

// File: @openzeppelin/contracts/security/ReentrancyGuard.sol


// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

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


// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

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

// File: contracts/PotionPalace.sol


pragma solidity >=0.8.4;






contract PotionPalace is IERC721Receiver, ReentrancyGuard {
    using SafeMath for uint256;

    IERC721 public arcturian;
    IERC20 public potion;

    address public esper;
    uint256 public potionPerBlock;

    struct stake {
        uint256 arcturianId;
        uint256 potionBrewedBlock;
        address owner;
    }

    // arcturianId => Stake
    mapping(uint256 => stake) public receipt;

    event arcturianEntered(address indexed staker, uint256 arcturianId, uint256 blockNumber);
    event arcturianExited(address indexed staker, uint256 arcturianId, uint256 blockNumber);
    event PotionRecieved(address indexed staker, uint256 arcturianId, uint256 stakeAmount, uint256 fromBlock, uint256 toBlock);
    event PotionBrewTimeUpdated(uint256 potionPerBlock);

    modifier onlyBrewer(uint256 arcturianId) {
        // require that this contract has the NFT
        require(arcturian.ownerOf(arcturianId) == address(this), "onlyBrewer: arcturian is not in the palace");

        // require that this token is staked
        require(receipt[arcturianId].potionBrewedBlock != 0, "onlyBrewer: arcturian is not brewing");

        // require that msg.sender is the owner of this nft
        require(receipt[arcturianId].owner == msg.sender, "onlyBrewer: arcturian will not leave the palace for you");

        _;
    }

    modifier requireTimeElapsed(uint256 arcturianId) {
        // require that some time has elapsed (IE you can not stake and unstake in the same block)
        require(
            receipt[arcturianId].potionBrewedBlock < block.number,
            "requireTimeElapsed: Potions take time to brew"
        );
        _;
    }

    modifier onlyEsper() {
        require(msg.sender == esper, "reclaimTokens: Caller is not Esper");
        _;
    }

    constructor(
    ) {
        arcturian = IERC721(0x4af7ad773e67eCF00299F7585caCc8ddbB62DC5C);
        potion = IERC20(0x3edA36088b931098e8E472748840b3dF78268c72);
        esper = 0xCc879Ab4DE63FC7Be6aAca522285D6F5d816278e;
        potionPerBlock = 333333333333;
        emit PotionBrewTimeUpdated(potionPerBlock);
    }

    /**
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

    //User must give this contract permission to take ownership of it.
    function enterPalace(uint256[] calldata arcturianId) public nonReentrant returns (bool) {
        // allow for staking multiple NFTS at one time.
        for (uint256 i = 0; i < arcturianId.length; i++) {
            _enterPalace(arcturianId[i]);
        }

        return true;
    }

    function potionBalance() public view returns (uint256) {
        return potion.balanceOf(address(this));
    }

    function getCurrentPotionBrewed(uint256 arcturianId) public view returns (uint256) {
        return _timeBrewed(arcturianId).mul(potionPerBlock);
    }

    function exitPalace(uint256 arcturianId) public nonReentrant returns (bool) {
        return _exitPalace(arcturianId);
    }
    function exitPalace(uint256[] calldata arcturianId) public nonReentrant returns (bool) {
        // allow for exiting multiple NFTS at one time.
        for (uint256 i = 0; i < arcturianId.length; i++) {
            _exitPalace(arcturianId[i]);
        }

        return true;
    }

    function _exitPalace(uint256 arcturianId) internal onlyBrewer(arcturianId) requireTimeElapsed(arcturianId) returns (bool) {
        // payout stake, this should be safe as the function is non-reentrant
        _brewPotion(arcturianId);

        // delete stake record, effectively unstaking it
        delete receipt[arcturianId];

        // return token
        arcturian.safeTransferFrom(address(this), msg.sender, arcturianId);

        emit arcturianExited(msg.sender, arcturianId, block.number);

        return true;
    }

    function collect(uint256 arcturianId) public nonReentrant onlyBrewer(arcturianId) requireTimeElapsed(arcturianId) {
        // This 'payout first' should be safe as the function is nonReentrant
        _brewPotion(arcturianId);
        // update receipt with a new block number
        receipt[arcturianId].potionBrewedBlock = block.number;
    }

     function collectAll(uint256[] calldata arcturianId) public nonReentrant returns (bool) {
        // allow for collecting multiple potions at once.
        for (uint256 i = 0; i < arcturianId.length; i++) {
            require(receipt[arcturianId[i]].owner == msg.sender,"onlyBrewer: arcturian is not brewing potions for you");
            require(receipt[arcturianId[i]].potionBrewedBlock < block.number,"requireTimeElapsed: Potions take time to brew");
            _brewPotion(arcturianId[i]);
            receipt[arcturianId[i]].potionBrewedBlock = block.number;
        }

        return true;
    }

    function changePotionPerBlock(uint256 _potionPerBlock) public onlyEsper {
        potionPerBlock = _potionPerBlock;

        emit PotionBrewTimeUpdated(potionPerBlock);
    }

    function collectPotion() external onlyEsper {
        potion.transfer(esper, potion.balanceOf(address(this)));
    }

    function updateStakingReward(uint256 _potionPerBlock) external onlyEsper {
        potionPerBlock = _potionPerBlock;

        emit PotionBrewTimeUpdated(potionPerBlock);
    }

    function _enterPalace(uint256 arcturianId) internal returns (bool) {
        // require this token is not already staked
        require(receipt[arcturianId].potionBrewedBlock == 0, "Potion Palace: arcturian is already brewing potions");

        // require this token is not already owned by this contract
        require(arcturian.ownerOf(arcturianId) != address(this), "Potion Palace: arcturian is already brewing potions");

        // take possession of the NFT
        arcturian.safeTransferFrom(msg.sender, address(this), arcturianId);

        // check that this contract is the owner
        require(arcturian.ownerOf(arcturianId) == address(this), "Potion Palace: arcturian is not in this palace");

        // start the staking from this block.
        receipt[arcturianId].arcturianId = arcturianId;
        receipt[arcturianId].potionBrewedBlock = block.number;
        receipt[arcturianId].owner = msg.sender;

        emit arcturianEntered(msg.sender, arcturianId, block.number);

        return true;
    }

    function _brewPotion(uint256 arcturianId) internal {
        /* NOTE : Must be called from non-reentrant function to be safe!*/

        // double check that the receipt exists and we're not staking from block 0
        require(receipt[arcturianId].potionBrewedBlock > 0, "_payoutPotion Palace: Can not stake from block 0");

        // earned amount is difference between the stake start block, current block multiplied by stake amount
        uint256 brewTime = _timeBrewed(arcturianId).sub(1); // don't pay for the tx block of withdrawl
        uint256 potionsMade = brewTime.mul(potionPerBlock);

        // If the palace does not have enough potion to pay out, return the arcturian
        // This prevent a NFT being locked in the contract when empty
        if (potion.balanceOf(address(this)) < potionsMade) {
            emit PotionRecieved(msg.sender, arcturianId, 0, receipt[arcturianId].potionBrewedBlock, block.number);
            return;
        }

        // payout stake
        potion.transfer(receipt[arcturianId].owner, potionsMade);

        emit PotionRecieved(msg.sender, arcturianId, potionsMade, receipt[arcturianId].potionBrewedBlock, block.number);
    }

    function _timeBrewed(uint256 arcturianId) internal view returns (uint256) {
        if (receipt[arcturianId].potionBrewedBlock == 0) {
            return 0;
        }
        return block.number.sub(receipt[arcturianId].potionBrewedBlock);
    }
}