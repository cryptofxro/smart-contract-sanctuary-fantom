/**
 *Submitted for verification at FtmScan.com on 2022-08-10
*/

// Sources flattened with hardhat v2.9.9 https://hardhat.org

// File contracts/utils/Context.sol


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


// File contracts/utils/Ownable.sol

// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

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


// File contracts/Interfaces/ISingularityRouter.sol


pragma solidity ^0.8.14;

interface ISingularityRouter {
    event Swap(
        address indexed sender,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed to
    );

    function factory() external returns (address);

    function WETH() external returns (address);

    function poolCodeHash() external returns (bytes32);

    function poolFor(address token) external view returns (address pool);

    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function swapExactETHForTokens(
        address tokenIn,
        address tokenOut,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountOut);

    function swapExactTokensForETH(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function addLiquidity(
        address token,
        uint256 amount,
        uint256 minLiquidity,
        address to,
        uint256 deadline
    ) external returns (uint256 liquidity);

    function addLiquidityETH(
        uint256 minLiquidity,
        address to,
        uint256 deadline
    ) external payable returns (uint256 liquidity);

    function removeLiquidity(
        address token,
        uint256 liquidity,
        uint256 amountMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amount);

    function removeLiquidityETH(
        uint256 liquidity,
        uint256 amountMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amount);

    function removeLiquidityWithPermit(
        address token,
        uint256 liquidity,
        uint256 minLiquidity,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amount);

    function removeLiquidityETHWithPermit(
        uint256 liquidity,
        uint256 amountMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amount);

    function getAddLiquidityAmount(address token, uint256 amount) external view returns (uint256 mintAmount);

    function getRemoveLiquidityAmount(address token, uint256 lpAmount) external view returns (uint256 withdrawalAmount);

    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    )
        external
        view
        returns (
            uint256 amountOut,
            uint256 tradingFeeIn,
            uint256 slippageIn,
            uint256 slippageOut,
            uint256 tradingFeeOut
        );
}


// File contracts/Interfaces/IUniswapV2Router.sol



pragma solidity >=0.6.2;

interface IUniswapV2Router {
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function getAmountsIn(uint amountOut, address[] calldata path)
        external
        view
        returns (uint[] memory amounts);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);
}


// File contracts/ERC20/IERC20.sol


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


// File contracts/ERC20/IERC20Metadata.sol

// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

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


// File contracts/utils/Address.sol

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
}


// File contracts/ERC20/SafeERC20.sol


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


// File contracts/spotme.sol


pragma solidity ^0.8.1;






contract Spotme is Ownable {
    using SafeERC20 for IERC20Metadata;

    event RequestEvent(
        address indexed requester,
        address indexed requested,
        address tokenRequested,
        uint256 amount,
        uint256 total,
        string message,
        string indexed requestType
    );

    enum Status {
        REQUESTED,
        FULFILLED,
        REJECTED
    }

    enum Role {
        REQUESTER,
        REQUESTEE
    }

    struct Request {
        Status status;
        address requester;
        address requestee;
        address tokenRequested;
        uint48 timeRequested;
        uint48 respondTime;
        uint256 amount;
        uint256 total;
        string message;
    }

    uint256 public swapFee; //start the fee at 0%
    uint256 public numRequests;
    uint256 public EthBalance = address(this).balance;

    mapping(address => mapping(Role => uint256[])) public userData;
    mapping(uint256 => Request) public allRequests;

    function changeFee(uint256 _newFee) external onlyOwner {
        // fee works by division -- 1% == .01 == amount/100
        //.1% == .001 == amount/1000
        swapFee = _newFee;
    }

    function withdrawFees(address _token) external onlyOwner {
        uint256 tokenBalance = IERC20Metadata(_token).balanceOf(address(this));
        address _owner = owner();
        IERC20Metadata(_token).safeTransfer(_owner, tokenBalance);
    }

    function requestUser(
        address _requestee,
        address _tokenRequested,
        uint256 _amount,
        string calldata _message
    ) external {
        //require(_tokenRequested != address(0), "Cannot request the zero token");
        require(
            _requestee != address(0),
            "Cannot request from the zero address"
        );
        require(_requestee != msg.sender, "Cannot request from yourself");
        require(_amount > 0, "Must request a positive number");
        uint256 total = _amount;
        uint256 txnFee;
        if (swapFee > 0) {
            txnFee = _amount / swapFee;
            total = txnFee + _amount;
        }
        Request memory request = Request({
            requester: msg.sender,
            requestee: _requestee,
            tokenRequested: _tokenRequested,
            status: Status.REQUESTED,
            timeRequested: uint48(block.timestamp),
            respondTime: 0,
            amount: _amount,
            total: total,
            message: _message
        });
        userData[msg.sender][Role.REQUESTER].push(numRequests);
        userData[_requestee][Role.REQUESTEE].push(numRequests);
        allRequests[numRequests] = request;
        numRequests++;
        emit RequestEvent(
            msg.sender,
            _requestee,
            _tokenRequested,
            _amount,
            total,
            _message,
            "request"
        );
    }

    function fulfillRequest(
        address _router,
        address _tokenProvided,
        address[] calldata _path,
        uint256 _id,
        uint256 _amountInMax,
        uint256 _deadline
    ) external {
        Request storage requestToFulfill = allRequests[_id];
        require(
            requestToFulfill.requestee == msg.sender,
            "the signer is not the requestee"
        );
        if (_tokenProvided == requestToFulfill.tokenRequested) {
            IERC20Metadata(_tokenProvided).safeTransferFrom(
                msg.sender,
                address(this),
                requestToFulfill.total
            );
            IERC20Metadata(_tokenProvided).safeTransfer(
                requestToFulfill.requester,
                requestToFulfill.amount
            );
        } else {
            IERC20Metadata(_tokenProvided).safeTransferFrom( //is it possible to avoid this transfer?
                msg.sender,
                address(this),
                _amountInMax
            );
            IERC20Metadata(_tokenProvided).safeIncreaseAllowance(
                _router,
                _amountInMax
            );
            IUniswapV2Router(_router).swapTokensForExactTokens(
                requestToFulfill.total,
                _amountInMax,
                _path,
                address(this),
                _deadline
            );
            IERC20Metadata(requestToFulfill.tokenRequested).safeTransfer(
                requestToFulfill.requester,
                requestToFulfill.amount
            );
            requestToFulfill.status = Status.FULFILLED;
            requestToFulfill.respondTime = uint48(block.timestamp);
            emit RequestEvent(
                requestToFulfill.requester,
                msg.sender,
                requestToFulfill.tokenRequested,
                requestToFulfill.amount,
                requestToFulfill.total,
                requestToFulfill.message,
                "fulfilled"
            );
        }
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(
            success,
            "TransferHelper::safeTransferETH: ETH transfer failed"
        );
    }

    function fulfillRequestWithEth(
        address _router,
        address[] calldata _path,
        uint256 _id,
        uint256 _deadline
    ) external payable {
        Request storage requestToFulfill = allRequests[_id];
        require(
            requestToFulfill.requestee == msg.sender,
            "the signer is not the requestee"
        );
        //first step trasnfer funds to contract
        safeTransferETH(address(this), msg.value);
        if (requestToFulfill.tokenRequested == address(0)) {
            safeTransferETH(
                requestToFulfill.requester,
                requestToFulfill.amount
            );
            EthBalance += (requestToFulfill.total - requestToFulfill.amount); 
        } else {
            IUniswapV2Router(_router).swapETHForExactTokens{value: msg.value}(
                requestToFulfill.total,
                _path,
                address(this),
                _deadline
            );
            IERC20Metadata(requestToFulfill.tokenRequested).safeTransfer(
                requestToFulfill.requester,
                requestToFulfill.amount
            );
        }
        //To refund eth
        if (address(this).balance > EthBalance) {
            safeTransferETH(msg.sender, address(this).balance - EthBalance);
        }

        requestToFulfill.status = Status.FULFILLED;
        requestToFulfill.respondTime = uint48(block.timestamp);
        emit RequestEvent(
            requestToFulfill.requester,
            msg.sender,
            requestToFulfill.tokenRequested,
            requestToFulfill.amount,
            requestToFulfill.total,
            requestToFulfill.message,
            "fulfilled"
        );
    }

    function getRequest(uint256 _id) external view returns (Request memory) {
        return (allRequests[_id]);
    }

    receive() external payable {}

    fallback() external payable {}
}