// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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

// SPDX-License-Identifier: MIT
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRegistry.sol";

contract Registry is IRegistry, Ownable {
    mapping(address => address) public getVaultPipeline;

    mapping(bytes32 => bytes) public getPipelineData;

    mapping(address => bool) public isTokenWhitelisted;

    mapping(address => address) public getPriceFeed;

    address public defaultUniswapV2Router;

    mapping(address => mapping(address => SwapData)) private _swapData;

    // RESTRICTED FUNCTIONS

    function setVaultPipeline(address vault, address pipeline)
        external
        onlyOwner
    {
        getVaultPipeline[vault] = pipeline;
    }

    function setPipelineData(bytes32 slot, bytes memory data)
        external
        onlyOwner
    {
        getPipelineData[slot] = data;
    }

    function setTokenWhitelisted(address token, bool whitelisted)
        external
        onlyOwner
    {
        isTokenWhitelisted[token] = whitelisted;
    }

    function setPriceFeed(address token, address feed) external onlyOwner {
        getPriceFeed[token] = feed;
    }

    function setDefaultUniswapV2Router(address router) external onlyOwner {
        defaultUniswapV2Router = router;
    }

    // VIEW FUNCTIONS

    function getSwapData(address from, address to)
        external
        view
        returns (SwapData memory)
    {
        if (_swapData[from][to].swapType != SwapType.None) {
            return _swapData[from][to];
        } else {
            return _swapData[to][from];
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IRegistry {
    function getVaultPipeline(address vault) external view returns (address);

    function getPipelineData(bytes32 slot) external view returns (bytes memory);

    function isTokenWhitelisted(address token) external view returns (bool);

    function getPriceFeed(address token) external view returns (address);

    enum SwapType {
        None,
        UniswapV2
    }

    struct SwapData {
        SwapType swapType;
        bytes data;
    }

    function getSwapData(address from, address to)
        external
        view
        returns (SwapData memory);

    function defaultUniswapV2Router() external view returns (address);
}