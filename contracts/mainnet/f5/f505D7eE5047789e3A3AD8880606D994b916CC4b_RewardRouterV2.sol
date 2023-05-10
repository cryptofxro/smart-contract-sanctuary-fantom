// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

contract Governable {
    address public gov;

    constructor() public {
        gov = msg.sender;
    }

    modifier onlyGov() {
        require(msg.sender == gov, "Governable: forbidden");
        _;
    }

    function setGov(address _gov) external onlyGov {
        gov = _gov;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./IVault.sol";

interface IBlpManager {
    function blp() external view returns (address);
    function usdb() external view returns (address);
    function vault() external view returns (IVault);
    function cooldownDuration() external returns (uint256);
    function getAumInUsdb(bool maximise) external view returns (uint256);
    function lastAddedAt(address _account) external returns (uint256);
    function addLiquidity(address _token, uint256 _amount, uint256 _minUsdb, uint256 _minBlp) external returns (uint256);
    function addLiquidityForAccount(address _fundingAccount, address _account, address _token, uint256 _amount, uint256 _minUsdb, uint256 _minBlp) external returns (uint256);
    function removeLiquidity(address _tokenOut, uint256 _blpAmount, uint256 _minOut, address _receiver) external returns (uint256);
    function removeLiquidityForAccount(address _account, address _tokenOut, uint256 _blpAmount, uint256 _minOut, address _receiver) external returns (uint256);
    function setShortsTrackerAveragePriceWeight(uint256 _shortsTrackerAveragePriceWeight) external;
    function setCooldownDuration(uint256 _cooldownDuration) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./IVaultUtils.sol";

interface IVault {
    function isInitialized() external view returns (bool);
    function isSwapEnabled() external view returns (bool);
    function isLeverageEnabled() external view returns (bool);

    function setVaultUtils(IVaultUtils _vaultUtils) external;
    function setError(uint256 _errorCode, string calldata _error) external;

    function router() external view returns (address);
    function usdb() external view returns (address);
    function gov() external view returns (address);

    function whitelistedTokenCount() external view returns (uint256);
    function maxLeverage() external view returns (uint256);

    function minProfitTime() external view returns (uint256);
    function hasDynamicFees() external view returns (bool);
    function fundingInterval() external view returns (uint256);
    function totalTokenWeights() external view returns (uint256);
    function getTargetUsdbAmount(address _token) external view returns (uint256);

    function inManagerMode() external view returns (bool);
    function inPrivateLiquidationMode() external view returns (bool);

    function maxGasPrice() external view returns (uint256);

    function approvedRouters(address _account, address _router) external view returns (bool);
    function isLiquidator(address _account) external view returns (bool);
    function isManager(address _account) external view returns (bool);

    function minProfitBasisPoints(address _token) external view returns (uint256);
    function tokenBalances(address _token) external view returns (uint256);
    function lastFundingTimes(address _token) external view returns (uint256);

    function setMaxLeverage(uint256 _maxLeverage) external;
    function setInManagerMode(bool _inManagerMode) external;
    function setManager(address _manager, bool _isManager) external;
    function setIsSwapEnabled(bool _isSwapEnabled) external;
    function setIsLeverageEnabled(bool _isLeverageEnabled) external;
    function setMaxGasPrice(uint256 _maxGasPrice) external;
    function setUsdbAmount(address _token, uint256 _amount) external;
    function setBufferAmount(address _token, uint256 _amount) external;
    function setMaxGlobalShortSize(address _token, uint256 _amount) external;
    function setInPrivateLiquidationMode(bool _inPrivateLiquidationMode) external;
    function setLiquidator(address _liquidator, bool _isActive) external;

    function setFundingRate(uint256 _fundingInterval, uint256 _fundingRateFactor, uint256 _stableFundingRateFactor) external;

    function setFees(
        uint256 _taxBasisPoints,
        uint256 _stableTaxBasisPoints,
        uint256 _mintBurnFeeBasisPoints,
        uint256 _swapFeeBasisPoints,
        uint256 _stableSwapFeeBasisPoints,
        uint256 _marginFeeBasisPoints,
        uint256 _liquidationFeeUsd,
        uint256 _minProfitTime,
        bool _hasDynamicFees
    ) external;

    function setTokenConfig(
        address _token,
        uint256 _tokenDecimals,
        uint256 _redemptionBps,
        uint256 _minProfitBps,
        uint256 _maxUsdbAmount,
        bool _isStable,
        bool _isShortable
    ) external;

    function setPriceFeed(address _priceFeed) external;
    function withdrawFees(address _token, address _receiver) external returns (uint256);

    function directPoolDeposit(address _token) external;
    function buyUSDB(address _token, address _receiver) external returns (uint256);
    function sellUSDB(address _token, address _receiver) external returns (uint256);
    function swap(address _tokenIn, address _tokenOut, address _receiver) external returns (uint256);
    function increasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong) external;
    function decreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver) external returns (uint256);
    function validateLiquidation(address _account, address _collateralToken, address _indexToken, bool _isLong, bool _raise) external view returns (uint256, uint256);
    function liquidatePosition(address _account, address _collateralToken, address _indexToken, bool _isLong, address _feeReceiver) external;
    function tokenToUsdMin(address _token, uint256 _tokenAmount) external view returns (uint256);

    function priceFeed() external view returns (address);
    function fundingRateFactor() external view returns (uint256);
    function stableFundingRateFactor() external view returns (uint256);
    function cumulativeFundingRates(address _token) external view returns (uint256);
    function getNextFundingRate(address _token) external view returns (uint256);
    function getFeeBasisPoints(address _token, uint256 _usdbDelta, uint256 _feeBasisPoints, uint256 _taxBasisPoints, bool _increment) external view returns (uint256);

    function liquidationFeeUsd() external view returns (uint256);
    function taxBasisPoints() external view returns (uint256);
    function stableTaxBasisPoints() external view returns (uint256);
    function mintBurnFeeBasisPoints() external view returns (uint256);
    function swapFeeBasisPoints() external view returns (uint256);
    function stableSwapFeeBasisPoints() external view returns (uint256);
    function marginFeeBasisPoints() external view returns (uint256);

    function allWhitelistedTokensLength() external view returns (uint256);
    function allWhitelistedTokens(uint256) external view returns (address);
    function whitelistedTokens(address _token) external view returns (bool);
    function stableTokens(address _token) external view returns (bool);
    function shortableTokens(address _token) external view returns (bool);
    function feeReserves(address _token) external view returns (uint256);
    function globalShortSizes(address _token) external view returns (uint256);
    function globalShortAveragePrices(address _token) external view returns (uint256);
    function maxGlobalShortSizes(address _token) external view returns (uint256);
    function tokenDecimals(address _token) external view returns (uint256);
    function tokenWeights(address _token) external view returns (uint256);
    function guaranteedUsd(address _token) external view returns (uint256);
    function poolAmounts(address _token) external view returns (uint256);
    function bufferAmounts(address _token) external view returns (uint256);
    function reservedAmounts(address _token) external view returns (uint256);
    function usdbAmounts(address _token) external view returns (uint256);
    function maxUsdbAmounts(address _token) external view returns (uint256);
    function getRedemptionAmount(address _token, uint256 _usdbAmount) external view returns (uint256);
    function getMaxPrice(address _token) external view returns (uint256);
    function getMinPrice(address _token) external view returns (uint256);

    function getDelta(address _indexToken, uint256 _size, uint256 _averagePrice, bool _isLong, uint256 _lastIncreasedTime) external view returns (bool, uint256);
    function getPosition(address _account, address _collateralToken, address _indexToken, bool _isLong) external view returns (uint256, uint256, uint256, uint256, uint256, uint256, bool, uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IVaultUtils {
    function updateCumulativeFundingRate(address _collateralToken, address _indexToken) external returns (bool);
    function validateIncreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong) external view;
    function validateDecreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver) external view;
    function validateLiquidation(address _account, address _collateralToken, address _indexToken, bool _isLong, bool _raise) external view returns (uint256, uint256);
    function getEntryFundingRate(address _collateralToken, address _indexToken, bool _isLong) external view returns (uint256);
    function getPositionFee(address _account, address _collateralToken, address _indexToken, bool _isLong, uint256 _sizeDelta) external view returns (uint256);
    function getFundingFee(address _account, address _collateralToken, address _indexToken, bool _isLong, uint256 _size, uint256 _entryFundingRate) external view returns (uint256);
    function getBuyUsdbFeeBasisPoints(address _token, uint256 _usdbAmount) external view returns (uint256);
    function getSellUsdbFeeBasisPoints(address _token, uint256 _usdbAmount) external view returns (uint256);
    function getSwapFeeBasisPoints(address _tokenIn, address _tokenOut, uint256 _usdbAmount) external view returns (uint256);
    function getFeeBasisPoints(address _token, uint256 _usdbDelta, uint256 _feeBasisPoints, uint256 _taxBasisPoints, bool _increment) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
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
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
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
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
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
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
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
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
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
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./IERC20.sol";
import "../math/SafeMath.sol";
import "../utils/Address.sol";

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

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
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
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;

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
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.3._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.3._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

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
contract ReentrancyGuard {
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

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
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

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../libraries/math/SafeMath.sol";
import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";
import "../libraries/utils/Address.sol";

import "./interfaces/IRewardTracker.sol";
import "./interfaces/IRewardRouterV2.sol";
import "./interfaces/IVester.sol";
import "../tokens/interfaces/IMintable.sol";
import "../tokens/interfaces/IWETH.sol";
import "../core/interfaces/IBlpManager.sol";
import "../access/Governable.sol";

contract RewardRouterV2 is IRewardRouterV2, ReentrancyGuard, Governable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;

    bool public isInitialized;

    address public weth;

    address public bfx;
    address public esBfx;
    address public bnBfx;

    address public blp; // BFX Liquidity Provider token

    address public stakedBfxTracker;
    address public bonusBfxTracker;
    address public feeBfxTracker;

    address public override stakedBlpTracker;
    address public override feeBlpTracker;

    address public blpManager;

    address public bfxVester;
    address public blpVester;

    mapping (address => address) public pendingReceivers;

    event StakeBfx(address account, address token, uint256 amount);
    event UnstakeBfx(address account, address token, uint256 amount);

    event StakeBlp(address account, uint256 amount);
    event UnstakeBlp(address account, uint256 amount);

    receive() external payable {
        require(msg.sender == weth, "Router: invalid sender");
    }

    function initialize(
        address _weth,
        address _bfx,
        address _esBfx,
        address _bnBfx,
        address _blp,
        address _stakedBfxTracker,
        address _bonusBfxTracker,
        address _feeBfxTracker,
        address _feeBlpTracker,
        address _stakedBlpTracker,
        address _blpManager,
        address _bfxVester,
        address _blpVester
    ) external onlyGov {
        require(!isInitialized, "RewardRouter: already initialized");
        isInitialized = true;

        weth = _weth;

        bfx = _bfx;
        esBfx = _esBfx;
        bnBfx = _bnBfx;

        blp = _blp;

        stakedBfxTracker = _stakedBfxTracker;
        bonusBfxTracker = _bonusBfxTracker;
        feeBfxTracker = _feeBfxTracker;

        feeBlpTracker = _feeBlpTracker;
        stakedBlpTracker = _stakedBlpTracker;

        blpManager = _blpManager;

        bfxVester = _bfxVester;
        blpVester = _blpVester;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function batchStakeBfxForAccount(address[] memory _accounts, uint256[] memory _amounts) external nonReentrant onlyGov {
        address _bfx = bfx;
        for (uint256 i = 0; i < _accounts.length; i++) {
            _stakeBfx(msg.sender, _accounts[i], _bfx, _amounts[i]);
        }
    }

    function stakeBfxForAccount(address _account, uint256 _amount) external nonReentrant onlyGov {
        _stakeBfx(msg.sender, _account, bfx, _amount);
    }

    function stakeBfx(uint256 _amount) external nonReentrant {
        _stakeBfx(msg.sender, msg.sender, bfx, _amount);
    }

    function stakeEsBfx(uint256 _amount) external nonReentrant {
        _stakeBfx(msg.sender, msg.sender, esBfx, _amount);
    }

    function unstakeBfx(uint256 _amount) external nonReentrant {
        _unstakeBfx(msg.sender, bfx, _amount, true);
    }

    function unstakeEsBfx(uint256 _amount) external nonReentrant {
        _unstakeBfx(msg.sender, esBfx, _amount, true);
    }

    function mintAndStakeBlp(address _token, uint256 _amount, uint256 _minUsdb, uint256 _minBlp) external nonReentrant returns (uint256) {
        require(_amount > 0, "RewardRouter: invalid _amount");

        address account = msg.sender;
        uint256 blpAmount = IBlpManager(blpManager).addLiquidityForAccount(account, account, _token, _amount, _minUsdb, _minBlp);
        IRewardTracker(feeBlpTracker).stakeForAccount(account, account, blp, blpAmount);
        IRewardTracker(stakedBlpTracker).stakeForAccount(account, account, feeBlpTracker, blpAmount);

        emit StakeBlp(account, blpAmount);

        return blpAmount;
    }

    function mintAndStakeBlpETH(uint256 _minUsdb, uint256 _minBlp) external payable nonReentrant returns (uint256) {
        require(msg.value > 0, "RewardRouter: invalid msg.value");

        IWETH(weth).deposit{value: msg.value}();
        IERC20(weth).approve(blpManager, msg.value);

        address account = msg.sender;
        uint256 blpAmount = IBlpManager(blpManager).addLiquidityForAccount(address(this), account, weth, msg.value, _minUsdb, _minBlp);

        IRewardTracker(feeBlpTracker).stakeForAccount(account, account, blp, blpAmount);
        IRewardTracker(stakedBlpTracker).stakeForAccount(account, account, feeBlpTracker, blpAmount);

        emit StakeBlp(account, blpAmount);

        return blpAmount;
    }

    function unstakeAndRedeemBlp(address _tokenOut, uint256 _blpAmount, uint256 _minOut, address _receiver) external nonReentrant returns (uint256) {
        require(_blpAmount > 0, "RewardRouter: invalid _blpAmount");

        address account = msg.sender;
        IRewardTracker(stakedBlpTracker).unstakeForAccount(account, feeBlpTracker, _blpAmount, account);
        IRewardTracker(feeBlpTracker).unstakeForAccount(account, blp, _blpAmount, account);
        uint256 amountOut = IBlpManager(blpManager).removeLiquidityForAccount(account, _tokenOut, _blpAmount, _minOut, _receiver);

        emit UnstakeBlp(account, _blpAmount);

        return amountOut;
    }

    function unstakeAndRedeemBlpETH(uint256 _blpAmount, uint256 _minOut, address payable _receiver) external nonReentrant returns (uint256) {
        require(_blpAmount > 0, "RewardRouter: invalid _blpAmount");

        address account = msg.sender;
        IRewardTracker(stakedBlpTracker).unstakeForAccount(account, feeBlpTracker, _blpAmount, account);
        IRewardTracker(feeBlpTracker).unstakeForAccount(account, blp, _blpAmount, account);
        uint256 amountOut = IBlpManager(blpManager).removeLiquidityForAccount(account, weth, _blpAmount, _minOut, address(this));

        IWETH(weth).withdraw(amountOut);

        _receiver.sendValue(amountOut);

        emit UnstakeBlp(account, _blpAmount);

        return amountOut;
    }

    function claim() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(feeBfxTracker).claimForAccount(account, account);
        IRewardTracker(feeBlpTracker).claimForAccount(account, account);

        IRewardTracker(stakedBfxTracker).claimForAccount(account, account);
        IRewardTracker(stakedBlpTracker).claimForAccount(account, account);
    }

    function claimEsBfx() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(stakedBfxTracker).claimForAccount(account, account);
        IRewardTracker(stakedBlpTracker).claimForAccount(account, account);
    }

    function claimFees() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(feeBfxTracker).claimForAccount(account, account);
        IRewardTracker(feeBlpTracker).claimForAccount(account, account);
    }

    function compound() external nonReentrant {
        _compound(msg.sender);
    }

    function compoundForAccount(address _account) external nonReentrant onlyGov {
        _compound(_account);
    }

    function handleRewards(
        bool _shouldClaimBfx,
        bool _shouldStakeBfx,
        bool _shouldClaimEsBfx,
        bool _shouldStakeEsBfx,
        bool _shouldStakeMultiplierPoints,
        bool _shouldClaimWeth,
        bool _shouldConvertWethToEth
    ) external nonReentrant {
        address account = msg.sender;

        uint256 bfxAmount = 0;
        if (_shouldClaimBfx) {
            uint256 bfxAmount0 = IVester(bfxVester).claimForAccount(account, account);
            uint256 bfxAmount1 = IVester(blpVester).claimForAccount(account, account);
            bfxAmount = bfxAmount0.add(bfxAmount1);
        }

        if (_shouldStakeBfx && bfxAmount > 0) {
            _stakeBfx(account, account, bfx, bfxAmount);
        }

        uint256 esBfxAmount = 0;
        if (_shouldClaimEsBfx) {
            uint256 esBfxAmount0 = IRewardTracker(stakedBfxTracker).claimForAccount(account, account);
            uint256 esBfxAmount1 = IRewardTracker(stakedBlpTracker).claimForAccount(account, account);
            esBfxAmount = esBfxAmount0.add(esBfxAmount1);
        }

        if (_shouldStakeEsBfx && esBfxAmount > 0) {
            _stakeBfx(account, account, esBfx, esBfxAmount);
        }

        if (_shouldStakeMultiplierPoints) {
            uint256 bnBfxAmount = IRewardTracker(bonusBfxTracker).claimForAccount(account, account);
            if (bnBfxAmount > 0) {
                IRewardTracker(feeBfxTracker).stakeForAccount(account, account, bnBfx, bnBfxAmount);
            }
        }

        if (_shouldClaimWeth) {
            if (_shouldConvertWethToEth) {
                uint256 weth0 = IRewardTracker(feeBfxTracker).claimForAccount(account, address(this));
                uint256 weth1 = IRewardTracker(feeBlpTracker).claimForAccount(account, address(this));

                uint256 wethAmount = weth0.add(weth1);
                IWETH(weth).withdraw(wethAmount);

                payable(account).sendValue(wethAmount);
            } else {
                IRewardTracker(feeBfxTracker).claimForAccount(account, account);
                IRewardTracker(feeBlpTracker).claimForAccount(account, account);
            }
        }
    }

    function batchCompoundForAccounts(address[] memory _accounts) external nonReentrant onlyGov {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _compound(_accounts[i]);
        }
    }

    function signalTransfer(address _receiver) external nonReentrant {
        require(IERC20(bfxVester).balanceOf(msg.sender) == 0, "RewardRouter: sender has vested tokens");
        require(IERC20(blpVester).balanceOf(msg.sender) == 0, "RewardRouter: sender has vested tokens");

        _validateReceiver(_receiver);
        pendingReceivers[msg.sender] = _receiver;
    }

    function acceptTransfer(address _sender) external nonReentrant {
        require(IERC20(bfxVester).balanceOf(_sender) == 0, "RewardRouter: sender has vested tokens");
        require(IERC20(blpVester).balanceOf(_sender) == 0, "RewardRouter: sender has vested tokens");

        address receiver = msg.sender;
        require(pendingReceivers[_sender] == receiver, "RewardRouter: transfer not signalled");
        delete pendingReceivers[_sender];

        _validateReceiver(receiver);
        _compound(_sender);

        uint256 stakedBfx = IRewardTracker(stakedBfxTracker).depositBalances(_sender, bfx);
        if (stakedBfx > 0) {
            _unstakeBfx(_sender, bfx, stakedBfx, false);
            _stakeBfx(_sender, receiver, bfx, stakedBfx);
        }

        uint256 stakedEsBfx = IRewardTracker(stakedBfxTracker).depositBalances(_sender, esBfx);
        if (stakedEsBfx > 0) {
            _unstakeBfx(_sender, esBfx, stakedEsBfx, false);
            _stakeBfx(_sender, receiver, esBfx, stakedEsBfx);
        }

        uint256 stakedBnBfx = IRewardTracker(feeBfxTracker).depositBalances(_sender, bnBfx);
        if (stakedBnBfx > 0) {
            IRewardTracker(feeBfxTracker).unstakeForAccount(_sender, bnBfx, stakedBnBfx, _sender);
            IRewardTracker(feeBfxTracker).stakeForAccount(_sender, receiver, bnBfx, stakedBnBfx);
        }

        uint256 esBfxBalance = IERC20(esBfx).balanceOf(_sender);
        if (esBfxBalance > 0) {
            IERC20(esBfx).transferFrom(_sender, receiver, esBfxBalance);
        }

        uint256 blpAmount = IRewardTracker(feeBlpTracker).depositBalances(_sender, blp);
        if (blpAmount > 0) {
            IRewardTracker(stakedBlpTracker).unstakeForAccount(_sender, feeBlpTracker, blpAmount, _sender);
            IRewardTracker(feeBlpTracker).unstakeForAccount(_sender, blp, blpAmount, _sender);

            IRewardTracker(feeBlpTracker).stakeForAccount(_sender, receiver, blp, blpAmount);
            IRewardTracker(stakedBlpTracker).stakeForAccount(receiver, receiver, feeBlpTracker, blpAmount);
        }

        IVester(bfxVester).transferStakeValues(_sender, receiver);
        IVester(blpVester).transferStakeValues(_sender, receiver);
    }

    function _validateReceiver(address _receiver) private view {
        require(IRewardTracker(stakedBfxTracker).averageStakedAmounts(_receiver) == 0, "RewardRouter: stakedBfxTracker.averageStakedAmounts > 0");
        require(IRewardTracker(stakedBfxTracker).cumulativeRewards(_receiver) == 0, "RewardRouter: stakedBfxTracker.cumulativeRewards > 0");

        require(IRewardTracker(bonusBfxTracker).averageStakedAmounts(_receiver) == 0, "RewardRouter: bonusBfxTracker.averageStakedAmounts > 0");
        require(IRewardTracker(bonusBfxTracker).cumulativeRewards(_receiver) == 0, "RewardRouter: bonusBfxTracker.cumulativeRewards > 0");

        require(IRewardTracker(feeBfxTracker).averageStakedAmounts(_receiver) == 0, "RewardRouter: feeBfxTracker.averageStakedAmounts > 0");
        require(IRewardTracker(feeBfxTracker).cumulativeRewards(_receiver) == 0, "RewardRouter: feeBfxTracker.cumulativeRewards > 0");

        require(IVester(bfxVester).transferredAverageStakedAmounts(_receiver) == 0, "RewardRouter: BfxVester.transferredAverageStakedAmounts > 0");
        require(IVester(bfxVester).transferredCumulativeRewards(_receiver) == 0, "RewardRouter: BfxVester.transferredCumulativeRewards > 0");

        require(IRewardTracker(stakedBlpTracker).averageStakedAmounts(_receiver) == 0, "RewardRouter: stakedBlpTracker.averageStakedAmounts > 0");
        require(IRewardTracker(stakedBlpTracker).cumulativeRewards(_receiver) == 0, "RewardRouter: stakedBlpTracker.cumulativeRewards > 0");

        require(IRewardTracker(feeBlpTracker).averageStakedAmounts(_receiver) == 0, "RewardRouter: feeBlpTracker.averageStakedAmounts > 0");
        require(IRewardTracker(feeBlpTracker).cumulativeRewards(_receiver) == 0, "RewardRouter: feeBlpTracker.cumulativeRewards > 0");

        require(IVester(blpVester).transferredAverageStakedAmounts(_receiver) == 0, "RewardRouter: BfxVester.transferredAverageStakedAmounts > 0");
        require(IVester(blpVester).transferredCumulativeRewards(_receiver) == 0, "RewardRouter: BfxVester.transferredCumulativeRewards > 0");

        require(IERC20(bfxVester).balanceOf(_receiver) == 0, "RewardRouter: BfxVester.balance > 0");
        require(IERC20(blpVester).balanceOf(_receiver) == 0, "RewardRouter: blpVester.balance > 0");
    }

    function _compound(address _account) private {
        _compoundBfx(_account);
        _compoundBlp(_account);
    }

    function _compoundBfx(address _account) private {
        uint256 esBfxAmount = IRewardTracker(stakedBfxTracker).claimForAccount(_account, _account);
        if (esBfxAmount > 0) {
            _stakeBfx(_account, _account, esBfx, esBfxAmount);
        }

        uint256 bnBfxAmount = IRewardTracker(bonusBfxTracker).claimForAccount(_account, _account);
        if (bnBfxAmount > 0) {
            IRewardTracker(feeBfxTracker).stakeForAccount(_account, _account, bnBfx, bnBfxAmount);
        }
    }

    function _compoundBlp(address _account) private {
        uint256 esBfxAmount = IRewardTracker(stakedBlpTracker).claimForAccount(_account, _account);
        if (esBfxAmount > 0) {
            _stakeBfx(_account, _account, esBfx, esBfxAmount);
        }
    }

    function _stakeBfx(address _fundingAccount, address _account, address _token, uint256 _amount) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        IRewardTracker(stakedBfxTracker).stakeForAccount(_fundingAccount, _account, _token, _amount);
        IRewardTracker(bonusBfxTracker).stakeForAccount(_account, _account, stakedBfxTracker, _amount);
        IRewardTracker(feeBfxTracker).stakeForAccount(_account, _account, bonusBfxTracker, _amount);

        emit StakeBfx(_account, _token, _amount);
    }

    function _unstakeBfx(address _account, address _token, uint256 _amount, bool _shouldReduceBnBfx) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        uint256 balance = IRewardTracker(stakedBfxTracker).stakedAmounts(_account);

        IRewardTracker(feeBfxTracker).unstakeForAccount(_account, bonusBfxTracker, _amount, _account);
        IRewardTracker(bonusBfxTracker).unstakeForAccount(_account, stakedBfxTracker, _amount, _account);
        IRewardTracker(stakedBfxTracker).unstakeForAccount(_account, _token, _amount, _account);

        if (_shouldReduceBnBfx) {
            uint256 bnBfxAmount = IRewardTracker(bonusBfxTracker).claimForAccount(_account, _account);
            if (bnBfxAmount > 0) {
                IRewardTracker(feeBfxTracker).stakeForAccount(_account, _account, bnBfx, bnBfxAmount);
            }

            uint256 stakedBnBfx = IRewardTracker(feeBfxTracker).depositBalances(_account, bnBfx);
            if (stakedBnBfx > 0) {
                uint256 reductionAmount = stakedBnBfx.mul(_amount).div(balance);
                IRewardTracker(feeBfxTracker).unstakeForAccount(_account, bnBfx, reductionAmount, _account);
                IMintable(bnBfx).burn(_account, reductionAmount);
            }
        }

        emit UnstakeBfx(_account, _token, _amount);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IRewardRouterV2 {
    function feeBlpTracker() external view returns (address);
    function stakedBlpTracker() external view returns (address);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IRewardTracker {
    function depositBalances(address _account, address _depositToken) external view returns (uint256);
    function stakedAmounts(address _account) external view returns (uint256);
    function updateRewards() external;
    function stake(address _depositToken, uint256 _amount) external;
    function stakeForAccount(address _fundingAccount, address _account, address _depositToken, uint256 _amount) external;
    function unstake(address _depositToken, uint256 _amount) external;
    function unstakeForAccount(address _account, address _depositToken, uint256 _amount, address _receiver) external;
    function tokensPerInterval() external view returns (uint256);
    function claim(address _receiver) external returns (uint256);
    function claimForAccount(address _account, address _receiver) external returns (uint256);
    function claimable(address _account) external view returns (uint256);
    function averageStakedAmounts(address _account) external view returns (uint256);
    function cumulativeRewards(address _account) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IVester {
    function rewardTracker() external view returns (address);

    function claimForAccount(address _account, address _receiver) external returns (uint256);

    function claimable(address _account) external view returns (uint256);
    function cumulativeClaimAmounts(address _account) external view returns (uint256);
    function claimedAmounts(address _account) external view returns (uint256);
    function pairAmounts(address _account) external view returns (uint256);
    function getVestedAmount(address _account) external view returns (uint256);
    function transferredAverageStakedAmounts(address _account) external view returns (uint256);
    function transferredCumulativeRewards(address _account) external view returns (uint256);
    function cumulativeRewardDeductions(address _account) external view returns (uint256);
    function bonusRewards(address _account) external view returns (uint256);

    function transferStakeValues(address _sender, address _receiver) external;
    function setTransferredAverageStakedAmounts(address _account, uint256 _amount) external;
    function setTransferredCumulativeRewards(address _account, uint256 _amount) external;
    function setCumulativeRewardDeductions(address _account, uint256 _amount) external;
    function setBonusRewards(address _account, uint256 _amount) external;

    function getMaxVestableAmount(address _account) external view returns (uint256);
    function getCombinedAverageStakedAmount(address _account) external view returns (uint256);

    function depositForAccount(address _account, uint256 _amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IMintable {
    function isMinter(address _account) external returns (bool);
    function setMinter(address _minter, bool _isActive) external;
    function mint(address _account, uint256 _amount) external;
    function burn(address _account, uint256 _amount) external;
}

//SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}