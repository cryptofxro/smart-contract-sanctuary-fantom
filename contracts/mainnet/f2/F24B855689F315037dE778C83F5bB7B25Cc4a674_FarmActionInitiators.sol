// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

// storage of wallets/contracts allowed to initiate farm actions
contract FarmActionInitiators is Ownable {
  uint256 public constant DEFAULT_BREAK_LP_FEE = 25; // default break LP fee 0.25%
  uint256 public constant MAX_BREAK_LP_FEE = 100;    // max break LP fee is 1.00%
  uint256 public constant MAX_PCT = 10000;           // max percentage is 100.00%

  // contracts/wallets which are allowed to initiate a withdraw on behalf of someone (funds are never transfered to the initiator, but always to the ultimate beneficial owner)
  mapping(address => mapping(address => bool)) public withdrawInitiator;
  // contracts/wallets which are allowed to initiate an emergencyWithdraw on behalf of someone (funds are never transfered to the initiator, but always to the ultimate beneficial owner)
  mapping(address => mapping(address => bool)) public emergencyWithdrawInitiator;
  // contracts/wallets which are allowed to initiate a withdraw and break LP on behalf of someone (funds are never transfered to the initiator, but always to the ultimate beneficial owner)
  mapping(address => mapping(address => bool)) public breakLpInitiator;

  mapping(address => uint256) public breakLpFee;

  address public break_lp_fee_wallet;

  function registerWithdrawInitiator(address _initiator, bool _allowed) public {
    withdrawInitiator[_initiator][msg.sender] = _allowed;
  }

  function registerEmergencyWithdrawInitiator(address _initiator, bool _allowed) external {
    emergencyWithdrawInitiator[_initiator][msg.sender] = _allowed;
  }

  function registerBreakLpInitiator(address _initiator, bool _allowed) public {
    breakLpInitiator[_initiator][msg.sender] = _allowed;
    if (breakLpFee[_initiator] == 0) {
      breakLpFee[_initiator] = DEFAULT_BREAK_LP_FEE;
    }
  }

  function registerBreakLpFeeWallet(address _break_lp_fee_wallet) external onlyOwner {
    break_lp_fee_wallet = _break_lp_fee_wallet;
  }

  function registerBreakLpFee(address _initiator, uint256 _fee_percentage) external onlyOwner {
    require(_fee_percentage <= MAX_BREAK_LP_FEE, "Break LP fee too high!");
    breakLpFee[_initiator] = _fee_percentage;
  }

  function registerZapContract(address _zap_contract) public {
     registerWithdrawInitiator(_zap_contract, true);
     registerBreakLpInitiator(_zap_contract, true);
  }
  
  function calculateBreakLpFee(address _initiator, uint256 _amount) external view returns (uint256) {
    return (_amount * breakLpFee[_initiator]) / MAX_PCT;
  }
}

// SPDX-License-Identifier: MIT

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
        _setOwner(_msgSender());
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
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT

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