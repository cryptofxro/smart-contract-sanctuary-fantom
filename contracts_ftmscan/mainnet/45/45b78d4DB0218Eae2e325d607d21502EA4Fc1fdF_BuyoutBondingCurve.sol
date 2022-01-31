/**
 *Submitted for verification at FtmScan.com on 2021-12-31
*/

// File: @openzeppelin/contracts/utils/Context.sol

// 
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

// 
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

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol

// 
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

// 
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

// 
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

// File: contracts/interfaces/IOwnable.sol

pragma solidity ^0.8.9;
interface IOwnable {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function owner() external view returns (address);
    function renounceOwnership() external;
    function transferOwnership(address newOwner) external; 
}

// File: contracts/interfaces/INftCollectionSale.sol

pragma solidity 0.8.9;



// --------------------------------------------------------------------------------------
//
// (c) NftLaunchpad 16/12/2021 | 
// Designed by, DeGatchi (https://github.com/DeGatchi).
//
// --------------------------------------------------------------------------------------

interface INftCollectionSale is IOwnable {
    /**
        @dev Amount of tokens to be able to be minted.
        @return uint256     Total supply.
     */
    function totalSupply() external returns(uint256);
    /**
        @dev Amount of tokens minted.
        @return uint256     Total minted.
     */
    function totalMinted() external returns(uint256);
    /**
        @dev Allows users to know the URI + whether it has been revealed or not.
        @dev If !revealed, return "".
        @return URI         URI of the metadata.
        @return revealed    Whether URI has been revealed.
     */
    function tokenURI() external returns(string calldata URI, bool revealed);
    /**
        @dev Mint an `tokenId` to the `to` address.
        @param to       Receiver of the NFT.
        @param tokenId  Token being minted.
     */
    function mint(address to, uint256 tokenId) external;
}

// File: contracts/interfaces/ISaleModel.sol

pragma solidity ^0.8.9;


// --------------------------------------------------------------------------------------
//
// (c) ISaleModel 29/12/2021 | 
// Designed by, DeGatchi (https://github.com/DeGatchi).
//
// --------------------------------------------------------------------------------------

interface ISaleModel {

    function initData(bytes calldata payload) external;
    
}

// File: contracts/interfaces/ISaleFactory.sol

pragma solidity ^0.8.9;



// --------------------------------------------------------------------------------------
//
// (c) ISaleFactory 28/12/2021 | 
// Designed by, DeGatchi (https://github.com/DeGatchi).
//
// --------------------------------------------------------------------------------------

interface ISaleFactory {

    event Initiated();
    event SaleDeployed();
    event NewSaleModel();
    event NewCommissioner();
    event NewCommissionPerc();

    function WETH() external returns(IERC20);
    function COMMISSIONER() external returns(address);
    function COMMISSION_PERC() external returns(uint256);

    /**
        @notice Deploy a new model to be used.
        @param model    Address of the new sale model contract.
     */
    function deployModel(ISaleModel model) external;

    /**
        @notice Deploy a sale model.
        @param collection    NFT collection being sold.
        @param model        Sale model being used to conduct sale.
        @param payload      Init params data of the sale model.
     */
    function createSale(
        INftCollectionSale collection, 
        uint16 model, 
        bytes calldata payload
    ) external returns (address result, bool initialised);
}

// File: contracts/SaleModels/BuyoutBondingCurve.sol

pragma solidity ^0.8.9;

// --------------------------------------------------------------------------------------
//
// (c) BuyoutBondingCurve 27/12/2021 | SPDX-License-Identifier: MIT
// Designed by, DeGatchi (https://github.com/DeGatchi).
//
// --------------------------------------------------------------------------------------

contract BuyoutBondingCurve is ISaleModel, Ownable {

    ISaleFactory public constant SALE_FACTORY = ISaleFactory(0x82D893c2147111298454670f1aB659C9130785CF);
    IERC20 public constant WETH = IERC20(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);

    address public commissioner;
    uint256 public commissionPerc;

     struct Info {
        // Whether sale has ended
        bool finalised;
        // Whether contract has given mint access or not
        bool mintAccess;
        // Address that made the sale
        address creator;
        // Token contract to mint ids from
        // Note: must be able to give permission to this contract to mint
        INftCollectionSale collection;
        // Amount raised from sale
        uint256 raised;
        // Amount not claimed from raised
        uint256 unclaimed;
    }
    Info public info;

    struct Sale {
        // Last sale price
        uint256 lastPrice;
        // The starting price of the sale
        uint128 startPrice;
        // Timestamp of when sale ends
        uint64 startTime;
        // Timestamp of when sale ends
        uint64 endTime;

        // Each token sold increases `lastPrice` by this amount
        // i.e,     500: (500 / 10,000 = 0.05)
        uint208 multiplier;
        // Total ids to sell/mint
        uint24 totalSupply;
        // Total ids sold
        uint24 totalSold;
    }
    Sale public sale;

    event Initiated();
    event ClaimedRaised();
    event Buyout();
    event Finalised();


    //  External Init
    // ----------------------------------------------------------------------
    
    /**
        @notice Convert data payload into params + init sale.
     */
    function initData(bytes calldata payload) external override {
        (
            INftCollectionSale _collection,
            uint64 _startTime,
            uint64 _endTime,
            uint128 _startPrice,
            uint208 _multiplier,
            uint24 _totalSupply
        ) = abi.decode(
            payload, (
                INftCollectionSale,
                uint64,
                uint64,
                uint128,
                uint208,
                uint24
            )
        );

        init(
            _collection,
            _startTime,
            _endTime,
            _startPrice,
            _multiplier,
            _totalSupply
        );
    }

    /**
        @notice Convert params into data.
     */
    function getInitData(
        INftCollectionSale _collection,
        uint64 _startTime,
        uint64 _endTime,
        uint128 _startPrice,
        uint208 _multiplier,
        uint24 _totalSupply
    ) external pure returns (bytes memory payload) {
        return abi.encode(
            _collection,
            _startTime,
            _endTime,
            _startPrice,
            _multiplier,
            _totalSupply
        );
    }
    

    //  Sale
    // ----------------------------------------------------------------------

    /**
        @notice Initiate the sale contract.
     */
    function init(
        INftCollectionSale _collection,
        uint64 _startTime,
        uint64 _endTime,
        uint128 _startPrice,
        uint208 _multiplier,
        uint24 _totalSupply
    ) public {
        require(_collection.owner() == address(this), "this address has no mint access");
        require(_startPrice > 0, "cannot multiply 0");
        require(_startTime >= block.timestamp, "start in future");
        require(_endTime > _startTime, "");
        require(_totalSupply > 0, "cannot mint 0");
        
        info.creator = msg.sender;
        info.collection = _collection;
        info.mintAccess = true;

        sale.startPrice = _startPrice;
        sale.lastPrice = _startPrice;
        sale.multiplier = _multiplier;
        
        sale.startTime = _startTime;
        sale.endTime = _endTime;

        sale.totalSupply = _totalSupply;

        commissioner = SALE_FACTORY.COMMISSIONER();
        commissionPerc = SALE_FACTORY.COMMISSION_PERC();

        emit Initiated();
    }   

    /**
        @notice Creator receives unclaimed raised funds.
     */
    function claimRaised() external {
        Info memory mInfo = info;
        require(msg.sender == mInfo.creator, "no access");
        info.unclaimed = 0;
        WETH.transferFrom(address(this), mInfo.creator, mInfo.unclaimed);
        emit ClaimedRaised();
    }


    //  Participation
    // ----------------------------------------------------------------------

    /**
        @notice Buyout current bundle.
        ---
        @param amountOfNfts : Amount of ids to buy.
     */
    function buyout(uint24 amountOfNfts) external {
        Info memory mInfo = info;
        require(!mInfo.finalised, "sale finalised");
        Sale memory mSale = sale;
        uint256 newTotalSold = mSale.totalSold + amountOfNfts;
        require(newTotalSold <= mSale.totalSupply, "excessive amountOfNfts");

        uint256 cost = getCostFor(amountOfNfts);

        // Send payment + update stats
        WETH.transferFrom(msg.sender, address(this), cost);
        info.raised += cost;
        info.unclaimed += cost;

        // SSTORE
        mSale.totalSold += amountOfNfts;
        sale.totalSold += amountOfNfts;

        newTotalSold = mSale.totalSold + amountOfNfts;

        // Finalise if sold out OR current time > endTime
        if (mSale.totalSold == mSale.totalSupply || block.timestamp > mSale.endTime)  {
            // Finalise sale
            info.collection.transferOwnership(mInfo.creator);
            info.finalised = true;
            emit Finalised();
        }

        // Mint bought token(s)
        for (uint256 i; i < amountOfNfts; i++) {
            mInfo.collection.mint(msg.sender, i);
        }

        emit Buyout();
    }
    
    /**
        @notice Calculates the total cost for the amount of nfts being bought.
        ---
        @param amountOfNfts : Amount of ids to buy
     */
    function getCostFor(uint24 amountOfNfts) public view returns (uint256) {
        Sale memory mSale = sale;

        uint256 adding;
        uint256 cost;

        // Calculate cost
        for (uint256 i; i < amountOfNfts; i++) {
            // i.e,     ($100 * 500) / 10,000 = $5
            adding = (mSale.lastPrice * mSale.multiplier) / 10000;
            // i.e,     $100 + $5 = $105
            mSale.lastPrice += adding;
            // add token price to cost
            cost += mSale.lastPrice;
        }

        return cost;
    }
}