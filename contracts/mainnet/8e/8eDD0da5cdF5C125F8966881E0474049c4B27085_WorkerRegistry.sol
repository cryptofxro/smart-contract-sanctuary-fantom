// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import { IWorkerRegistry } from "./Interfaces.sol";

import { AddressesArray, Signature } from "../common/Libraries.sol";

contract WorkerRegistry is IWorkerRegistry, Ownable {
  using AddressesArray for address[];
  mapping(address=>uint256) public workersIndex;
  address[] public workers;


  event Register(address worker);
  event Unregister(address worker);
  
  constructor(){
    
  }

  function count() external override view returns(uint256){
    return workers.length;
  }

  function workerAt(uint256 index) external override view returns(address) {
    return workers[index];
  }

  function isWorker(address _worker) public override view returns(bool){
    return workersIndex[_worker] > 0;
  }

  function register(address _worker) external override onlyOwner {
    require(!isWorker(_worker), "AR");
    workersIndex[_worker] = block.timestamp;
    workers.insert(_worker);
    Register(_worker);
  }

  function unregister(address _worker) external override onlyOwner {
    require(isWorker(_worker), "NR");
    workersIndex[_worker] = 0;
    workers.remove(_worker);
    Unregister(_worker);
  }

  function selfUnregister() external override {
    require(isWorker(msg.sender), "NR");
    workersIndex[msg.sender] = 0;
    workers.remove(msg.sender);
    Unregister(msg.sender);
  }

  function selfRegister(uint256 nonce, bytes calldata ownerSignature) external override {
    bytes32 message = keccak256(abi.encode(msg.sender, nonce));
    require(Signature.recoverSigner(message, ownerSignature) == owner(), "NA");
    workersIndex[msg.sender] = block.timestamp;
    workers.insert(msg.sender);
    Register(msg.sender);
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

import { IWETH, IERC20 } from "../common/Interfaces.sol";

interface IWorkerRegistry {

  function count() external view returns(uint256);
  function workerAt(uint256) external view returns(address);
  function isWorker(address) external view returns(bool);
  function register(address) external;
  function unregister(address) external;
  function selfUnregister() external;
  function selfRegister(uint256 nonce, bytes calldata ownerSignature) external;
}

interface ILiquidityProvider {
  function TREASURY() external view returns(ITreasury);
  function REGISTRY() external view returns(IWorkerRegistry);
  function setWorkerRegistry(IWorkerRegistry _workerRegistry) external;
  function setTreasury(ITreasury) external;
  function initiate(address[] memory,
                    uint256[] memory,
                    bytes memory) external;
}

interface IFTMLiquidityProvider {
  function TREASURY() external view returns(ITreasury);
  function REGISTRY() external view returns(IWorkerRegistry);
  function setWorkerRegistry(IWorkerRegistry _workerRegistry) external;
  function setTreasury(ITreasury) external;
  function initiate(address,
                    uint256,
                    bytes memory) external;
}

interface ISwapExecutor {

  function routersCount() external view returns(uint256);
  function addRouter(address) external;
  function removeRouter(address) external;
  function bestSwapPrice(uint256 fromAmount, address fromToken, address toToken) external view returns(uint256, address);
  function bestNeedPrice(uint256 neededAmount, address neededToken, address fromToken) external view returns(uint256, address);
  function swap(uint256 fromAmount, address fromToken, address toToken) external returns(uint256);
  function make(uint256 needAmount, address needToken, address fromToken) external returns(uint256);
  function swapSpecific(address router, uint256 fromAmount, address fromToken, address toToken) external returns(uint256);
  
}

interface ITreasury {
  function WETH() external view returns(IWETH);
  function STABLE() external view returns(IERC20);
  function EXECUTOR() external view returns(ISwapExecutor);

  function setWETH(IWETH) external;
  function setExecutor(ISwapExecutor) external;
  function setStable(IERC20) external;
  function internalSwitch(address from, address to) external;
  function internalMake(uint256 needed, address token, address usingToken) external;
  function internalWrap() external;
  function internalUnwrap() external;
  function withdrawToken(address token, uint256 amount) external;
  function withdrawEth(uint256 amount) external;

  function trackersCount() external view returns(uint256);
  
  function addTracker(address) external;
  function removeTracker(address) external;
  
  function stableValue() external view returns(uint256);
  function ethValue() external view returns(uint256);

  function wipeAllInETH() external returns(uint256);
  function wipeAllInStable() external returns(uint256);
}


interface IWorker {
  function LIQUIDITY_PROVIDER() external view returns(ILiquidityProvider);
  function TREASURY() external view returns(ITreasury);
  function WETH() external view returns(IWETH);
  function setLiquidityProvider(ILiquidityProvider) external;
  function updateTreasury() external;
  
  function executeJob(address[] calldata assets,
                      uint256[] calldata amounts,
                      uint256[] calldata premiums ,
                      bytes calldata params)
    external returns(bool);
  function initiateJob(bytes memory) external;
  function run(bytes memory) external returns(bool);
  function neededFunds(bytes memory)
    external view returns(address[] memory,
                          uint256[] memory);
  function shouldInitiate(bytes memory work)
      external view returns(bool);
}


interface IFTMWorker {
  function LIQUIDITY_PROVIDER() external view returns(IFTMLiquidityProvider);
  function TREASURY() external view returns(ITreasury);
  function WETH() external view returns(IWETH);
  function setLiquidityProvider(IFTMLiquidityProvider) external;
  function updateTreasury() external;
  
  function executeJob(address asset,
                      uint256 amount,
                      uint256 fee,
                      bytes calldata params)
    external returns(bool);
  function initiateJob(bytes memory) external;
  function run(bytes memory) external returns(bool);
  function neededFunds(bytes memory)
    external view returns(address,
                          uint256);
  function shouldInitiate(bytes memory work)
      external view returns(bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "./Interfaces.sol";

library SafeMath {
  /**
   * @dev Returns the addition of two unsigned integers, reverting on
   * overflow.
   *
   * Counterpart to Solidity"s `+` operator.
   *
   * Requirements:
   * - Addition cannot overflow.
   */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, "SafeMath: addition overflow");

    return c;
  }

  /**
   * @dev Returns the subtraction of two unsigned integers, reverting on
   * overflow (when the result is negative).
   *
   * Counterpart to Solidity"s `-` operator.
   *
   * Requirements:
   * - Subtraction cannot overflow.
   */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    return sub(a, b, "SafeMath: subtraction overflow");
  }

  /**
   * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
   * overflow (when the result is negative).
   *
   * Counterpart to Solidity"s `-` operator.
   *
   * Requirements:
   * - Subtraction cannot overflow.
   */
  function sub(
    uint256 a,
    uint256 b,
    string memory errorMessage
  ) internal pure returns (uint256) {
    require(b <= a, errorMessage);
    uint256 c = a - b;

    return c;
  }

  /**
   * @dev Returns the multiplication of two unsigned integers, reverting on
   * overflow.
   *
   * Counterpart to Solidity"s `*` operator.
   *
   * Requirements:
   * - Multiplication cannot overflow.
   */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than requiring "a" not being zero, but the
    // benefit is lost if "b" is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b, "SafeMath: multiplication overflow");

    return c;
  }

  /**
   * @dev Returns the integer division of two unsigned integers. Reverts on
   * division by zero. The result is rounded towards zero.
   *
   * Counterpart to Solidity"s `/` operator. Note: this function uses a
   * `revert` opcode (which leaves remaining gas untouched) while Solidity
   * uses an invalid opcode to revert (consuming all remaining gas).
   *
   * Requirements:
   * - The divisor cannot be zero.
   */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    return div(a, b, "SafeMath: division by zero");
  }

  /**
   * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
   * division by zero. The result is rounded towards zero.
   *
   * Counterpart to Solidity"s `/` operator. Note: this function uses a
   * `revert` opcode (which leaves remaining gas untouched) while Solidity
   * uses an invalid opcode to revert (consuming all remaining gas).
   *
   * Requirements:
   * - The divisor cannot be zero.
   */
  function div(
    uint256 a,
    uint256 b,
    string memory errorMessage
  ) internal pure returns (uint256) {
    // Solidity only automatically asserts when dividing by 0
    require(b > 0, errorMessage);
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn"t hold

    return c;
  }

  /**
   * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
   * Reverts when dividing by zero.
   *
   * Counterpart to Solidity"s `%` operator. This function uses a `revert`
   * opcode (which leaves remaining gas untouched) while Solidity uses an
   * invalid opcode to revert (consuming all remaining gas).
   *
   * Requirements:
   * - The divisor cannot be zero.
   */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    return mod(a, b, "SafeMath: modulo by zero");
  }

  /**
   * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
   * Reverts with custom message when dividing by zero.
   *
   * Counterpart to Solidity"s `%` operator. This function uses a `revert`
   * opcode (which leaves remaining gas untouched) while Solidity uses an
   * invalid opcode to revert (consuming all remaining gas).
   *
   * Requirements:
   * - The divisor cannot be zero.
   */
  function mod(
    uint256 a,
    uint256 b,
    string memory errorMessage
  ) internal pure returns (uint256) {
    require(b != 0, errorMessage);
    return a % b;
  }
}

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
    // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
    // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
    // for accounts without code, i.e. `keccak256("")`
    bytes32 codehash;
    bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
    // solhint-disable-next-line no-inline-assembly
    assembly {
      codehash := extcodehash(account)
    }
    return (codehash != accountHash && codehash != 0x0);
  }

  /**
   * @dev Replacement for Solidity"s `transfer`: sends `amount` wei to
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

    // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
    (bool success, ) = recipient.call{value: amount}("");
    require(success, "Address: unable to send value, recipient may have reverted");
  }
}



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
  using SafeMath for uint256;
  using Address for address;

  function safeTransfer(
    IERC20 token,
    address to,
    uint256 value
  ) internal {
    callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
  }

  function safeTransferFrom(
    IERC20 token,
    address from,
    address to,
    uint256 value
  ) internal {
    callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
  }

  function safeApprove(
    IERC20 token,
    address spender,
    uint256 value
  ) internal {
    require(
      (value == 0) || (token.allowance(address(this), spender) == 0),
      "SafeERC20: approve from non-zero to non-zero allowance"
    );
    callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
  }

  function callOptionalReturn(IERC20 token, bytes memory data) private {
    require(address(token).isContract(), "SafeERC20: call to non-contract");

    // solhint-disable-next-line avoid-low-level-calls
    (bool success, bytes memory returndata) = address(token).call(data);
    require(success, "SafeERC20: low-level call failed");

    if (returndata.length > 0) {
      // Return data is optional
      // solhint-disable-next-line max-line-length
      require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
    }
  }
}

library AddressesArray {
  uint256 constant MAX_INT = 2 ** 256 - 1;
  function indexOf(address[] storage values, address value) internal view returns(uint256) {
    for(uint256 index = 0; index < values.length; index++){
      if(values[index] == value){
        return index;
      }
    }
    return MAX_INT;
  }
  function remove(address[] storage values, address value) internal {
    uint index = indexOf(values, value);
    if(index < values.length){
      removeIndex(values, index);
    }
  }
  function removeIndex(address[] storage values, uint256 index) internal {
    if(index < values.length){
      
      uint i = index;
      while(i < values.length-1){
        values[i] = values[i+1];
        i++;
      }
      values.pop();
    }
  }
  function insert(address[] storage values, address value) internal {
    if(indexOf(values, value) >= values.length){
      values.push(value);
    }
  }
}

library Signature {
  function recoverSigner(bytes32 message, bytes memory sig)
    internal
    pure
    returns (address){
    
    uint8 v;
    bytes32 r;
    bytes32 s;
    (v, r, s) = splitSignature(sig);
    return ecrecover(message, v, r, s);
  }
  
  function splitSignature(bytes memory sig)
    internal
    pure
    returns (uint8, bytes32, bytes32){
    
    require(sig.length == 65, "Invalid Signature");
    bytes32 r;
    bytes32 s;
    uint8 v;
    assembly {
    r := mload(add(sig, 32))
        s := mload(add(sig, 64))
        v := byte(0, mload(add(sig, 96)))
        }
    return (v, r, s);
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {

  /**
  * @dev Returns decimals for token
  */
  function decimals() external view returns(uint256);
  /**
  * @dev Returns full name of token
  */
  function name() external view returns(string memory);
  /**
  * @dev Returns symbol of token
  */
  function symbol() external view returns(string memory);
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


interface IWETH is IERC20 {
  function deposit() external payable;
  function withdraw(uint256) external;
}