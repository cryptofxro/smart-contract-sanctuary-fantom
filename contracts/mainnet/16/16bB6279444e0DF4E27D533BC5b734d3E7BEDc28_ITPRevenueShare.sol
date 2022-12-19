// SPDX-License-Identifier: MIT
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
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/draft-IERC20Permit.sol";
import "../../../utils/Address.sol";

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

// SPDX-License-Identifier: MIT
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

// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ManagerRole } from './ManagerRole.sol';
import { NativeTokenAddress } from './NativeTokenAddress.sol';
import { SafeTransfer } from './SafeTransfer.sol';


abstract contract BalanceManagement is ManagerRole, NativeTokenAddress, SafeTransfer {
    error ReservedTokenError();

    function cleanup(address _tokenAddress, uint256 _tokenAmount) external onlyManager {
        if (isReservedToken(_tokenAddress)) {
            revert ReservedTokenError();
        }

        if (_tokenAddress == NATIVE_TOKEN_ADDRESS) {
            safeTransferNative(msg.sender, _tokenAmount);
        } else {
            safeTransfer(_tokenAddress, msg.sender, _tokenAmount);
        }
    }

    function tokenBalance(address _tokenAddress) public view returns (uint256) {
        if (_tokenAddress == NATIVE_TOKEN_ADDRESS) {
            return address(this).balance;
        } else {
            return IERC20(_tokenAddress).balanceOf(address(this));
        }
    }

    function isReservedToken(address /*_tokenAddress*/) public view virtual returns (bool) {
        return false;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

abstract contract DataStructures {
    struct OptionalValue {
        bool isSet;
        uint256 value;
    }

    function uniqueAddressListAdd(
        address[] storage _list,
        mapping(address => OptionalValue) storage _indexMap,
        address _value
    ) internal returns (bool isChanged) {
        isChanged = !_indexMap[_value].isSet;

        if (isChanged) {
            _indexMap[_value] = OptionalValue(true, _list.length);
            _list.push(_value);
        }
    }

    function uniqueAddressListRemove(
        address[] storage _list,
        mapping(address => OptionalValue) storage _indexMap,
        address _value
    ) internal returns (bool isChanged) {
        OptionalValue storage indexItem = _indexMap[_value];

        isChanged = indexItem.isSet;

        if (isChanged) {
            uint256 itemIndex = indexItem.value;
            uint256 lastIndex = _list.length - 1;

            if (itemIndex != lastIndex) {
                address lastValue = _list[lastIndex];
                _list[itemIndex] = lastValue;
                _indexMap[lastValue].value = itemIndex;
            }

            _list.pop();
            delete _indexMap[_value];
        }
    }

    function uniqueAddressListUpdate(
        address[] storage _list,
        mapping(address => OptionalValue) storage _indexMap,
        address _value,
        bool _flag
    ) internal returns (bool isChanged) {
        return
            _flag
                ? uniqueAddressListAdd(_list, _indexMap, _value)
                : uniqueAddressListRemove(_list, _indexMap, _value);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import { RevenueShare } from './RevenueShare.sol';

contract ITPRevenueShare is RevenueShare {
    constructor(address _ITPToken, address _farm, address _mediator, address _USDC, address _USDT) {
        farm = _farm;
        mediator = _mediator;
        USDC = _USDC;
        USDT = _USDT;
        ITP = _ITPToken;
        lockToken = _ITPToken;
        rewardTokens.push(_ITPToken);
        rewardTokens.push(_USDC);
        rewardTokens.push(_USDT);

        rewardData[_ITPToken].lastUpdateTime = block.timestamp;
        rewardData[_USDC].lastUpdateTime = block.timestamp;
        rewardData[_USDT].lastUpdateTime = block.timestamp;

        rewardData[_ITPToken].periodFinish = block.timestamp;
        rewardData[_USDC].periodFinish = block.timestamp;
        rewardData[_USDT].periodFinish = block.timestamp;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import { Ownable } from './Ownable.sol';
import { DataStructures } from './DataStructures.sol';

abstract contract ManagerRole is Ownable, DataStructures {
    error OnlyManagerError();

    address[] public managerList;
    mapping(address => OptionalValue) public managerIndexMap;

    event SetManager(address indexed account, bool indexed value);

    modifier onlyManager() {
        if (!isManager(msg.sender)) {
            revert OnlyManagerError();
        }

        _;
    }

    function setManager(address _account, bool _value) public virtual onlyOwner {
        uniqueAddressListUpdate(managerList, managerIndexMap, _account, _value);

        emit SetManager(_account, _value);
    }

    function isManager(address _account) public view virtual returns (bool) {
        return managerIndexMap[_account].isSet;
    }

    function managerCount() public view virtual returns (uint256) {
        return managerList.length;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

abstract contract NativeTokenAddress {
    address public constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

abstract contract Ownable {
    error OnlyOwnerError();
    error ZeroAddressError();

    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert OnlyOwnerError();
        }

        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert ZeroAddressError();
        }

        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import { ManagerRole } from './ManagerRole.sol';

abstract contract Pausable is ManagerRole {
    error WhenNotPausedError();
    error WhenPausedError();

    bool public paused = false;

    event Pause();
    event Unpause();

    modifier whenNotPaused() {
        if (paused) {
            revert WhenNotPausedError();
        }

        _;
    }

    modifier whenPaused() {
        if (!paused) {
            revert WhenPausedError();
        }

        _;
    }

    function pause() public onlyManager whenNotPaused {
        paused = true;

        emit Pause();
    }

    function unpause() public onlyManager whenPaused {
        paused = false;

        emit Unpause();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Pausable } from './Pausable.sol';
import { BalanceManagement } from './BalanceManagement.sol';

contract RevenueShare is Pausable, BalanceManagement {
    using SafeERC20 for IERC20;

    struct LockedBalance {
        uint256 amount;
        uint256 unlockTime;
    }

    struct Reward {
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        uint256 balance;
    }

    struct RewardData {
        address token;
        uint256 amount;
    }

    address public farm; // StablecoinFarm
    address public mediator;
    address public USDC;
    address public USDT;
    address public ITP;
    address public lockToken; // token used as locked and reward

    uint256 public lockedSupply; // total locked tokens
    uint256 public lockDuration = 12 hours; // 12 hours by default
    uint256 public rewardsDuration = 7 days; // reward interval

    // Factor to perform multiplication and division operations
    uint256 private constant SHARE_PRECISION = 1e18;
    uint256 public constant REWARD_LOOKBACK = 1 days;

    address[] public rewardTokens;

    // user -> reward token -> amount
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint256)) public rewards;
    mapping(address => Reward) public rewardData; // total amount info for each token

    // private vars
    mapping(address => LockedBalance[]) private userLocks; // locked tokens
    mapping(address => uint256) private locked; // user -> locked tokens

    event Withdraw(address indexed user, uint256 amount);
    event Locked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, address indexed rewardsToken, uint256 reward);
    event RewardNotified(address indexed user, address indexed rewardsToken, uint256 reward);

    modifier onlyFarm() {
        require(msg.sender == farm, 'The sender should be the StablecoinFarm contract address');
        _;
    }

    modifier onlyMediator() {
        require(msg.sender == mediator, 'The sender should be the Mediator contract address');
        _;
    }

    /*
     * @dev Sets a new farm when it needs by the owner
     */
    function setFarm(address _newFarm) external onlyOwner {
        require(_newFarm != address(0), 'Provided address can not be zero');
        farm = _newFarm;
    }

    /*
     * @dev Sets a new mediator when it needs by the owner
     */
    function setMediator(address _newMediator) external onlyOwner {
        require(_newMediator != address(0), 'Provided address can not be zero');
        mediator = _newMediator;
    }

    /*
     * @dev Sets new lockDuration when it needs by the owner
     */
    function setLockDuration(uint256 _lockDuration) external onlyOwner {
        lockDuration = _lockDuration;
    }

    /*
     * @dev lock ITP tokens to receive rewards in USDC and USDT
     * 50% can be from farm or just simple lock from the user
     * @param _amount is the number of LP tokens
     * @param _user is the address who sent the _amount of tokens for locking
     */
    function lock(uint256 _amount, address _user) external {
        require(_amount > 0, 'Amount can not be zero');
        require(_user != address(0), 'Provided address can not be zero');
        _updateReward(_user);
        lockedSupply = lockedSupply + _amount;
        locked[_user] = locked[_user] + _amount;
        uint256 unlockTime = block.timestamp + lockDuration;
        uint256 idx = userLocks[_user].length;
        if (idx == 0 || userLocks[_user][idx - 1].unlockTime < unlockTime) {
            userLocks[_user].push(LockedBalance({ amount: _amount, unlockTime: unlockTime }));
        } else {
            userLocks[_user][idx - 1].amount = userLocks[_user][idx - 1].amount + _amount;
        }
        IERC20(lockToken).safeTransferFrom(msg.sender, address(this), _amount);
        emit Locked(_user, _amount);
    }

    /**
     * @dev Withdraw locked ITP tokens after locked time
     */
    function withdraw() external whenNotPaused {
        _updateReward(msg.sender);
        LockedBalance[] storage locks = userLocks[msg.sender];
        uint256 amount;
        uint256 length = locks.length;
        require(length > 0, 'Amount of locks can not be zero value');
        if (locks[length - 1].unlockTime <= block.timestamp) {
            amount = locked[msg.sender];
            delete userLocks[msg.sender];
        } else {
            for (uint256 i = 0; i < length; i++) {
                if (locks[i].unlockTime > block.timestamp) break;
                amount = amount + locks[i].amount;
                delete locks[i];
            }
        }
        require(amount > 0, 'Amount of locked tokens can not be zero value');
        locked[msg.sender] = locked[msg.sender] - amount;
        lockedSupply = lockedSupply - amount;
        IERC20(lockToken).safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    /**
     * @dev Address and claimable amount of all reward tokens for the provided user
     */
    function claimableRewards(address _user) external view returns (RewardData[] memory _rewards) {
        _rewards = new RewardData[](rewardTokens.length);
        for (uint256 i = 0; i < _rewards.length; i++) {
            _rewards[i].token = rewardTokens[i];
            _rewards[i].amount =
                _rewardInfo(
                    _user,
                    _rewards[i].token,
                    locked[_user],
                    _rewardPerToken(rewardTokens[i], lockedSupply)
                ) /
                SHARE_PRECISION;
        }
        return _rewards;
    }

    /**
     * @dev Information on a user's total/locked/avalaible balances
     */
    function checkBalances(
        address _user
    )
        external
        view
        returns (
            uint256 total,
            uint256 avalaible,
            uint256 lockedTotal,
            LockedBalance[] memory lockData
        )
    {
        LockedBalance[] storage locks = userLocks[_user];
        uint256 index;
        for (uint256 i = 0; i < locks.length; i++) {
            if (locks[i].unlockTime > block.timestamp) {
                if (index == 0) {
                    lockData = new LockedBalance[](locks.length - i);
                }
                lockData[index] = locks[i];
                index++;
                lockedTotal = lockedTotal + locks[i].amount;
            } else {
                avalaible = avalaible + locks[i].amount;
            }
        }
        total = locked[_user];
    }

    /**
     * @dev Transfer USDC, USDT, ITP tokens to the user. Have to be
     * This function will be executed by anyone each 24 hours (a user or the backend side).
     * this needs to check if new rewards were sent to the contract
     * check `notifyReward` func for mmore information
     */
    function claim() public {
        _updateReward(msg.sender);
        _getReward();
    }

    function lastTimeRewardApplicable(address _rewardToken) public view returns (uint256) {
        uint256 periodFinish = rewardData[_rewardToken].periodFinish;
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /**
     * @dev Receives ITP tokens from farm
     * @param _amount is an amount of ITP token (lockToken)
     */
    function rewardsFromPenalties(uint256 _amount) public onlyFarm {
        require(_amount > 0, 'Amount can not be zero');
        IERC20(ITP).safeTransferFrom(farm, address(this), _amount);
        _notifyReward(ITP, _amount);
    }

    /**
     * @dev Receives USDC/USDT tokens from mediator
     * @param _amount is an _amount of provided _token
     * @param _token and address of USDC or USDT tokens from mediator
     */
    function receiveAsset(address _token, uint256 _amount) public onlyMediator {
        require(_amount > 0, 'Amount can not be zero');
        require(_token != address(0), 'Provided address can not be zero');
        require(_token == USDC || _token == USDT, 'Provided token is wrong');
        IERC20(_token).safeTransferFrom(mediator, address(this), _amount);
        _notifyReward(_token, _amount);
    }

    function _rewardInfo(
        address _user,
        address _token,
        uint256 _balance,
        uint256 _rpt // current reward per token
    ) internal view returns (uint256) {
        return
            (_balance * (_rpt - userRewardPerTokenPaid[_user][_token])) /
            SHARE_PRECISION +
            rewards[_user][_token];
    }

    function _updateReward(address _user) internal {
        require(_user != address(0), 'Provided address can not be zero');
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            Reward storage r = rewardData[token];
            uint256 rpt = _rewardPerToken(token, lockedSupply);
            r.rewardPerTokenStored = rpt;
            r.lastUpdateTime = lastTimeRewardApplicable(token);
            if (_user != address(this)) {
                rewards[_user][token] = _rewardInfo(_user, token, locked[_user], rpt);
                userRewardPerTokenPaid[_user][token] = rpt;
            }
        }
    }

    function _rewardPerToken(
        address _rewardToken,
        uint256 _supply
    ) internal view returns (uint256) {
        require(_rewardToken != address(0), 'Provided address can not be zero');
        if (_supply == 0) {
            return rewardData[_rewardToken].rewardPerTokenStored;
        }
        return
            rewardData[_rewardToken].rewardPerTokenStored +
            ((lastTimeRewardApplicable(_rewardToken) - rewardData[_rewardToken].lastUpdateTime) *
                rewardData[_rewardToken].rewardRate *
                SHARE_PRECISION) /
            _supply;
    }

    function _notifyReward(address _rewardToken, uint256 _reward) internal {
        require(_rewardToken != address(0), 'Provided address can not be zero');
        Reward storage r = rewardData[_rewardToken];
        if (block.timestamp >= r.periodFinish) {
            r.rewardRate = (_reward * SHARE_PRECISION) / rewardsDuration;
        } else {
            uint256 remaining = r.periodFinish - block.timestamp;
            uint256 leftover = (remaining * r.rewardRate) / SHARE_PRECISION;
            r.rewardRate = ((_reward + leftover) * SHARE_PRECISION) / rewardsDuration;
        }
        r.lastUpdateTime = block.timestamp;
        r.periodFinish = block.timestamp + rewardsDuration;

        emit RewardNotified(msg.sender, _rewardToken, _reward);
    }

    function _getReward() internal {
        for (uint256 i; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            uint256 reward = rewards[msg.sender][token] / SHARE_PRECISION;
            if (token != address(lockToken)) {
                Reward storage r = rewardData[token];
                uint256 periodFinish = r.periodFinish;
                require(periodFinish > 0, 'Unknown reward token');
                uint256 balance = r.balance;
                uint256 unseen;
                if (periodFinish < block.timestamp + rewardsDuration - REWARD_LOOKBACK) {
                    unseen = IERC20(token).balanceOf(address(this)) - balance;
                    if (unseen > 0) {
                        _notifyReward(token, unseen);
                        balance = balance + unseen;
                    }
                }
                require(balance >= reward, 'The contract does not have enough rewards to claim');
                r.balance = balance - reward;
            }

            if (reward == 0) continue;
            rewards[msg.sender][token] = 0;
            IERC20(token).safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, token, reward);
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.17;


abstract contract SafeTransfer {

    error SafeApproveError();
    error SafeTransferError();
    error SafeTransferFromError();
    error SafeTransferNativeError();

    function safeApprove(address _token, address _to, uint256 _value) internal {
        // 0x095ea7b3 is the selector for "approve(address,uint256)"
        (bool success, bytes memory data) = _token.call(abi.encodeWithSelector(0x095ea7b3, _to, _value));

        bool condition = success && (data.length == 0 || abi.decode(data, (bool)));

        if (!condition) {
            revert SafeApproveError();
        }
    }

    function safeTransfer(address _token, address _to, uint256 _value) internal {
        // 0xa9059cbb is the selector for "transfer(address,uint256)"
        (bool success, bytes memory data) = _token.call(abi.encodeWithSelector(0xa9059cbb, _to, _value));

        bool condition = success && (data.length == 0 || abi.decode(data, (bool)));

        if (!condition) {
            revert SafeTransferError();
        }
    }

    function safeTransferFrom(address _token, address _from, address _to, uint256 _value) internal {
        // 0x23b872dd is the selector for "transferFrom(address,address,uint256)"
        (bool success, bytes memory data) = _token.call(abi.encodeWithSelector(0x23b872dd, _from, _to, _value));

        bool condition = success && (data.length == 0 || abi.decode(data, (bool)));

        if (!condition) {
            revert SafeTransferFromError();
        }
    }

    function safeTransferNative(address _to, uint256 _value) internal {
        (bool success, ) = _to.call{value: _value}(new bytes(0));

        if (!success) {
            revert SafeTransferNativeError();
        }
    }

    function safeTransferNativeUnchecked(address _to, uint256 _value) internal {
        (bool ignore, ) = _to.call{value: _value}(new bytes(0));

        ignore;
    }
}