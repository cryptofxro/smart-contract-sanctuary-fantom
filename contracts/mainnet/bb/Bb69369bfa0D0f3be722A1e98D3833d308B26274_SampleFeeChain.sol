// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../FeeChain.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SampleFeeChain is OnFeeChain {
  address public owner;

  constructor(uint8 mintingChainID_, address genericHandler_)
    OnFeeChain(mintingChainID_, genericHandler_)
  {
    owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "Only owner can call this function");
    _;
  }

  function setLinker(address _linker) public onlyOwner {
    setLink(_linker);
  }

  function setFeesToken(address _feeToken) public onlyOwner {
    setFeeToken(_feeToken);
  }

  function setCrossChainGasLimit(uint256 _gasLimit) public onlyOwner {
    _setCrossChainGasLimit(_gasLimit);
  }

  function setFeeTokenForNFT(address _feeToken) public onlyOwner {
    _setFeeTokenForNFT(_feeToken);
  }

  function setFeeInTokenForNFT(uint256 _price) public onlyOwner {
    _setFeeInTokenForNFT(_price);
  }

  function sendCrossChain(address _recipient) public {
    bool sent = _sendCrossChain(_recipient);
    require(sent == true, "Unsuccessful");
  }

  function recoverFeeTokens() external onlyOwner {
    address feeToken = this.fetchFeetToken();
    uint256 amount = IERC20(feeToken).balanceOf(address(this));
    IERC20(feeToken).transfer(owner, amount);
  }

  function withdrawFeeTokenForNFT() external override onlyOwner {
    address feeToken = fetchFeeTokenForNFT();
    uint256 amount = IERC20(feeToken).balanceOf(address(this));
    IERC20(feeToken).transfer(owner, amount);
  }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@routerprotocol/router-crosstalk/contracts/RouterCrossTalk.sol";

abstract contract OnFeeChain is RouterCrossTalk {
  using SafeERC20 for IERC20;
  uint8 public immutable mintingChainID;
  address private feeTokenForNFT;
  uint256 private feeInTokenForNFT;

  uint256 private _crossChainGasLimit;

  constructor(uint8 mintingChainID_, address genericHandler_)
    RouterCrossTalk(genericHandler_)
  {
    mintingChainID = mintingChainID_;
  }

  /**
   * @notice _setFeeTokenForNFT Used to set feeToken, this can only be set by CrossChain Admin or Admins
   * @param _feeToken Address of the token to be set as fee
   */
  function _setFeeTokenForNFT(address _feeToken) internal {
    feeTokenForNFT = _feeToken;
  }

  /**
   * @notice fetchFeeTokenForNFT Used to fetch feeToken
   * @return feeToken address that is set
   */
  function fetchFeeTokenForNFT() public view returns (address) {
    return feeTokenForNFT;
  }

  /**
   * @notice _setFeeInTokenForNFT Used to set fees in Token, this can only be set by Admin
   * @param _price Amount of feeToken to be taken as price
   */
  function _setFeeInTokenForNFT(uint256 _price) internal {
    feeInTokenForNFT = _price;
  }

  /**
   * @notice fetchFeeInTokenForNFT Used to fetch fee in Token for NFT
   * @return Returns fee in Token
   */
  function fetchFeeInTokenForNFT() public view returns (uint256) {
    return feeInTokenForNFT;
  }

  /**
   * @notice setCrossChainGasLimit Used to set CrossChainGasLimit, this can only be set by CrossChain Admin or Admins
   * @param _gasLimit Amount of gasLimit that is to be set
   */
  function _setCrossChainGasLimit(uint256 _gasLimit) internal {
    _crossChainGasLimit = _gasLimit;
  }

  /**
   * @notice fetchCrossChainGasLimit Used to fetch CrossChainGasLimit
   * @return crossChainGasLimit that is set
   */
  function fetchCrossChainGasLimit() external view returns (uint256) {
    return _crossChainGasLimit;
  }

  function _sendCrossChain(address _recipient) internal returns (bool) {
    IERC20(feeTokenForNFT).safeTransferFrom(
      msg.sender,
      address(this),
      feeInTokenForNFT
    );
    bytes4 _selector = bytes4(keccak256("receiveCrossChain(address,address)"));
    bytes memory _data = abi.encode(_recipient, msg.sender);
    bool success = routerSend(
      mintingChainID,
      _selector,
      _data,
      _crossChainGasLimit
    );
    return success;
  }

  /**
   * @notice _routerSyncHandler This is an internal function to control the handling of various selectors and its corresponding
   * @param _selector Selector to interface.
   * @param _data Data to be handled.
   */
  function _routerSyncHandler(bytes4 _selector, bytes memory _data)
    internal
    virtual
    override
    returns (bool, bytes memory)
  {}

  function withdrawFeeTokenForNFT() external virtual {}
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
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

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
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "./interfaces/iGenericHandler.sol";
import "./interfaces/iRouterCrossTalk.sol";

/// @title RouterCrossTalk contract
/// @author Router Protocol
abstract contract RouterCrossTalk is Context , iRouterCrossTalk, ERC165 {

    iGenericHandler private handler;

    address private linkSetter;

    address private feeToken;

    mapping ( uint8 => address ) private Chain2Addr; // CHain ID to Address

    modifier isHandler(){
        require(_msgSender() == address(handler) , "RouterCrossTalk : Only GenericHandler can call this function" );
        _;
    }

    modifier isLinkSet(uint8 _chainID){
        require(Chain2Addr[_chainID] == address(0) , "RouterCrossTalk : Cross Chain Contract to Chain ID set" );
        _;
    }

    modifier isLinkUnSet(uint8 _chainID){
        require(Chain2Addr[_chainID] != address(0) , "RouterCrossTalk : Cross Chain Contract to Chain ID is not set" );
        _;
    }

    modifier isLinkSync( uint8 _srcChainID, address _srcAddress ){
        require(Chain2Addr[_srcChainID] == _srcAddress , "RouterCrossTalk : Source Address Not linked" );
        _;
    }

    modifier isSelf(){
        require(_msgSender() == address(this) , "RouterCrossTalk : Can only be called by Current Contract" );
        _;
    }

    constructor( address _handler ) {
        handler = iGenericHandler(_handler);
    }

    /// @notice Used to set linker address, this function is internal and can only be set by contract owner or admins
    /// @param _addr Address of linker.
    function setLink( address _addr ) internal {
        linkSetter = _addr;
    }

    /// @notice Used to set fee Token address, this function is internal and can only be set by contract owner or admins
    /// @param _addr Address of linker.
    function setFeeToken( address _addr ) internal {
        feeToken = _addr;
    }

    function fetchHandler( ) external override view returns ( address ) {
        return address(handler);
    }

    function fetchLinkSetter( ) external override view returns( address) {
        return linkSetter;
    }

    function fetchLink( uint8 _chainID ) external override view returns( address) {
        return Chain2Addr[_chainID];
    }

    function fetchFeetToken(  ) external override view returns( address) {
        return feeToken;
    }

    /// @notice routerSend This is internal function to generate a cross chain communication request.
    /// @param destChainId Destination ChainID.
    /// @param _selector Selector to interface on destination side.
    /// @param _data Data to be sent on Destination side.
    /// @param _gas Gas provided for cross chain send.
    function routerSend( uint8 destChainId , bytes4 _selector , bytes memory _data , uint256 _gas) internal isLinkUnSet( destChainId ) returns (bool success) {
        uint8 cid = handler.fetch_chainID();
        bytes32 hash = _hash(address(this),Chain2Addr[destChainId],destChainId, _selector, _data);
        handler.genericDeposit(destChainId , _selector , _data, hash , _gas , feeToken );
        emit CrossTalkSend( cid , destChainId , address(this), Chain2Addr[destChainId] ,_selector, _data , hash );
        return true;
    }

    function routerSync(uint8 srcChainID , address srcAddress , bytes4 _selector , bytes memory _data , bytes32 hash ) external override isLinkSync( srcChainID , srcAddress ) isHandler returns ( bool , bytes memory ) {
        uint8 cid = handler.fetch_chainID();
        bytes32 Dhash = _hash(Chain2Addr[srcChainID],address(this),cid, _selector, _data);
        require( Dhash == hash , "RouterSync : Valid Hash" );
        ( bool success , bytes memory _returnData ) = _routerSyncHandler( _selector , _data );
        emit CrossTalkReceive( srcChainID , cid , srcAddress , address(this), _selector, _data , hash );
        return ( success , _returnData );
    }

    /// @notice _hash This is internal function to generate the hash of all data sent or received by the contract.
    /// @param _srcAddress Source Address.
    /// @param _destAddress Destination Address.
    /// @param _destChainId Destination ChainID.
    /// @param _selector Selector to interface on destination side.
    /// @param _data Data to interface on Destination side.
    function _hash(address _srcAddress , address _destAddress , uint8 _destChainId , bytes4 _selector , bytes memory _data) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            _srcAddress,
            _destAddress,
            _destChainId,
            _selector,
            keccak256(_data)
        ));
    }

    function Link(uint8 _chainID , address _linkedContract) external override isHandler isLinkSet(_chainID) {
        Chain2Addr[_chainID] = _linkedContract;
        emit Linkevent( _chainID , _linkedContract );
    }

    function Unlink(uint8 _chainID ) external override isHandler {
        emit Unlinkevent( _chainID , Chain2Addr[_chainID] );
        Chain2Addr[_chainID] = address(0);
    }

    function approveFees(address _feeToken , uint256 _value) external {
        IERC20 token = IERC20(_feeToken);
        token.approve( address(handler) , _value );
    }

    /// @notice _routerSyncHandler This is internal function to control the handling of various selectors and its corresponding .
    /// @param _selector Selector to interface.
    /// @param _data Data to be handled.
    function _routerSyncHandler( bytes4 _selector , bytes memory _data ) internal virtual returns ( bool ,bytes memory );
    uint256[100] private __gap;

}

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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/IERC20.sol";

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
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title GenericHandler contract interface for router Crosstalk
/// @author Router Protocol
interface iGenericHandler {

    struct RouterLinker {
        address _rSyncContract;
        uint8 _chainID;
        address _linkedContract;
        uint8 linkerType;
    }

    /// @notice UnMapContract Unmaps the contract from the RouterCrossTalk Contract
    /// @dev This function is used to map contract from router-crosstalk contract
    /// @param linker The Data object consisting of target Contract , CHainid , Contract to be Mapped and linker type.
    /// @param _sign Signature of Linker data object signed by linkerSetter address.
    function MapContract( RouterLinker calldata linker , bytes memory _sign ) external;

    /// @notice UnMapContract Unmaps the contract from the RouterCrossTalk Contract
    /// @dev This function is used to unmap contract from router-crosstalk contract
    /// @param linker The Data object consisting of target Contract , CHainid , Contract to be unMapped and linker type.
    /// @param _sign Signature of Linker data object signed by linkerSetter address.
    function UnMapContract(RouterLinker calldata linker , bytes memory _sign ) external;

    /// @notice generic deposit on generic handler contract
    /// @dev This function is called by router crosstalk contract while initiating crosschain transaction
    /// @param _destChainID Chain id to be transacted
    /// @param _selector Selector for the crosschain interface
    /// @param _data Data to be transferred
    /// @param _hash Hash of the data sent to the contract
    /// @param _gas Gas Specified for the contract function
    /// @param _feeToken Fee Token Specified for the contract function
    function genericDeposit( uint8 _destChainID, bytes4 _selector, bytes memory _data, bytes32 _hash, uint256 _gas, address _feeToken) external;

    /// @notice Fetches ChainID for the native chain
    function fetch_chainID( ) external view returns ( uint8 );

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title iRouterCrossTalk contract interface for router Crosstalk
/// @author Router Protocol
interface iRouterCrossTalk is IERC165 {

    /// @notice Link event is emitted when a new link is created.
    /// @param ChainID Chain id the contract is linked to.
    /// @param linkedContract Contract address linked to.
    event Linkevent( uint8 indexed ChainID , address indexed linkedContract );

    /// @notice UnLink event is emitted when a link is removed.
    /// @param ChainID Chain id the contract is unlinked to.
    /// @param linkedContract Contract address unlinked to.
    event Unlinkevent( uint8 indexed ChainID , address indexed linkedContract );

    /// @notice CrossTalkSend Event is emited when a request is generated in soruce side when cross chain request is generated.
    /// @param sourceChain Source ChainID.
    /// @param destChain Destination ChainID.
    /// @param sourceAddress Source Address.
    /// @param destinationAddress Destination Address.
    /// @param _selector Selector to interface on destination side.
    /// @param _data Data to interface on Destination side.
    /// @param _hash Hash of the data sent.
    event CrossTalkSend(uint8 indexed sourceChain , uint8 indexed destChain , address sourceAddress , address destinationAddress ,bytes4 indexed _selector, bytes _data , bytes32 _hash );

    /// @notice CrossTalkReceive Event is emited when a request is recived in destination side when cross chain request accepted by contract.
    /// @param sourceChain Source ChainID.
    /// @param destChain Destination ChainID.
    /// @param sourceAddress Source Address.
    /// @param destinationAddress Destination Address.
    /// @param _selector Selector to interface on destination side.
    /// @param _data Data to interface on Destination side.
    /// @param _hash Hash of the data sent.
    event CrossTalkReceive(uint8 indexed sourceChain , uint8 indexed destChain , address sourceAddress , address destinationAddress ,bytes4 indexed _selector, bytes _data , bytes32 _hash );

    /// @notice routerSync This is a public function and can only be called by Generic Handler of router infrastructure
    /// @param srcChainID Source ChainID.
    /// @param srcAddress Destination ChainID.
    /// @param _selector Selector to interface on destination side.
    /// @param _data Data to interface on Destination side.
    /// @param hash Hash of the data sent.
    function routerSync(uint8 srcChainID , address srcAddress , bytes4 _selector , bytes calldata _data , bytes32 hash ) external returns ( bool , bytes memory );

    /// @notice Link This is a public function and can only be called by Generic Handler of router infrastructure
    /// @notice This function links contract on other chain ID's.
    /// @notice This is an administrative function and can only be initiated by linkSetter address.
    /// @param _chainID network Chain ID linked Contract linked to.
    /// @param _linkedContract Linked Contract address.
    function Link(uint8 _chainID , address _linkedContract) external;

    /// @notice UnLink This is a public function and can only be called by Generic Handler of router infrastructure
    /// @notice This function unLinks contract on other chain ID's.
    /// @notice This is an administrative function and can only be initiated by linkSetter address.
    /// @param _chainID network Chain ID linked Contract linked to.
    function Unlink(uint8 _chainID ) external;

    /// @notice fetchLinkSetter This is a public function and fetches the linksetter address.
    function fetchLinkSetter( ) external view returns( address );

    /// @notice fetchLinkSetter This is a public function and fetches the address the contract is linked to.
    /// @param _chainID Chain ID information.
    function fetchLink( uint8 _chainID ) external view returns( address );

    /// @notice fetchLinkSetter This is a public function and fetches the generic handler address.
    function fetchHandler( ) external view returns ( address );

    /// @notice fetchFeetToken This is a public function and fetches the fee token set by admin.
    function fetchFeetToken(  ) external view returns( address );

}

// SPDX-License-Identifier: MIT
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