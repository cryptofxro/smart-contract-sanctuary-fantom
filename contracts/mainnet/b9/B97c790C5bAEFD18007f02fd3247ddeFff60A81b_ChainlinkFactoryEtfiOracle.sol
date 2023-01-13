// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

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

// SPDX-License-Identifier: MIT
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

// SPDX-License-Identifier: GPL-3.0

/// @notice basic interface for univ2 single pair oracle
pragma solidity 0.8.9;

interface IEtfiOracle {
    function update() external returns (bool);

    function consult(uint256 amountIn) external view returns (uint256 amountOut);
    function consultAndUpdate(uint256 amountIn) external returns (uint256 amountOut);

    function isStale() external view returns (bool);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "../interfaces/IEtfiOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ChainlinkFactoryEtfiOracle is Ownable {
    mapping(address => address) public tokenToOracle;
    mapping(address => uint256) public tokenToPeriod;

    event ChainlinkOracleCreated(address indexed token, address indexed oracle);

    /**
     * @notice Get the oracle address assigned for a token
     * @param _token The token address
     */
    function getOracleForToken(address _token) external view returns (address) {
        return tokenToOracle[_token];
    }

    /**
     * @notice Sets a Chainlink oracle for a token
     * @param _token The token to create the oracle for
     * @param _period The period of the oracle which is considered valid within
     */
    function setOracleForToken(
        address _token,
        address _chainlinkOracle,
        uint256 _period
    ) external onlyOwner returns (address) {
        require(_chainlinkOracle != address(0), "invalid-oracle");
        require(_period > 0, "invalid-period");
        require(_token != address(0), "invalid-token");

        AggregatorV3Interface _oracle = AggregatorV3Interface(_chainlinkOracle);
        (, int256 _answer, , , ) = _oracle.latestRoundData();
        require(_answer > 0, "invalid-oracle-answer");
        tokenToOracle[_token] = _chainlinkOracle;
        tokenToPeriod[_token] = _period;

        emit ChainlinkOracleCreated(_token, _chainlinkOracle);
        return _chainlinkOracle;
    }

    /**
     * @notice Get the price for a token
     * @param _token The token address
     * @param _amountIn The amount of the token to get the price for
     * @return The price of the token, scaled to 6 decimals
     */
    function _getPrice(address _token, uint256 _amountIn)
        internal
        view
        returns (uint256)
    {
        address _oracle = tokenToOracle[_token];
        require(_oracle != address(0), "oracle-not-created");
        (, int256 _answer, , uint256 _updatedAt, ) = AggregatorV3Interface(
            _oracle
        ).latestRoundData();
        require(
            _updatedAt > block.timestamp - tokenToPeriod[_token],
            "oracle-stale"
        );
        require(_answer > 0, "invalid-oracle-answer");
        uint256 _tokenDecimals = IERC20Metadata(_token).decimals();
        uint256 _chainlinkDecimals = AggregatorV3Interface(_oracle).decimals();
        uint256 _usdPrice = (uint256(_answer) * _amountIn) /
            (10**_tokenDecimals);
        return _usdPrice / (10**(_chainlinkDecimals - 6));
    }

    /// @notice will revert if the oracle is stale
    function getUpdatedPrice(address _token, uint256 _amountIn)
        public
        returns (uint256)
    {
        return _getPrice(_token, _amountIn);
    }

    /// @notice will revert if the oracle is stale
    /// @notice view function to get the price of a token from users/test scripts
    function getLastPrice(address _token, uint256 _amountIn)
        external
        view
        returns (uint256)
    {
        return _getPrice(_token, _amountIn);
    }
}