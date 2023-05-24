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

// SPDX-License-Identifier: UNLICENSED
// Copyright (c) Eywa.Fi, 2021-2023 - all rights reserved
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./interfaces/IGateKeeper.sol";
import "./utils/Typecast.sol";


contract EndPoint is Typecast, Ownable {

    /// @dev version
    string public version;
    /// @dev clp address book
    address public addressBook;

    constructor (address addressBook_) {
        version = "2.2.3";
        _checkAddress(addressBook_);
        addressBook = addressBook_;
    }

    function setAddressBook(address addressBook_) external onlyOwner {
        _checkAddress(addressBook_);
        addressBook = addressBook_;
    }

    function _checkAddress(address checkingAddress) private pure {
        require(checkingAddress != address(0), "EndPoint: zero address");
    }
}

// SPDX-License-Identifier: UNLICENSED
// Copyright (c) Eywa.Fi, 2021-2023 - all rights reserved
pragma solidity 0.8.17;


interface IAddressBook {
    /// @dev returns portal by given chainId
    function portal(uint64 chainId) external view returns (address);

    /// @dev returns synthesis by given chainId
    function synthesis(uint64 chainId) external view returns (address);

    /// @dev returns router by given chainId
    function router(uint64 chainId) external view returns (address);

    /// @dev returns cryptoPoolAdapter
    function cryptoPoolAdapter() external view returns (address);

    /// @dev returns stablePoolAdapter
    function stablePoolAdapter() external view returns (address);

    /// @dev returns whitelist
    function whitelist() external view returns (address);

    /// @dev returns treasury
    function treasury() external view returns (address);

    /// @dev returns gateKeeper
    function gateKeeper() external view returns (address);

    /// @dev returns bridge
    function bridge() external view returns (address);
}

// SPDX-License-Identifier: UNLICENSED
// Copyright (c) Eywa.Fi, 2021-2023 - all rights reserved
pragma solidity 0.8.17;


interface IGateKeeper {

    function calculateCost(
        address payToken,
        uint256 dataLength,
        uint64 chainIdTo,
        address sender
    ) external returns (uint256 amountToPay);

    function sendData(
        bytes calldata data,
        address to,
        uint64 chainIdTo,
        address payToken
    ) external payable;

    function getNonce() external view returns (uint256);

    function bridge() external view returns (address);
}

// SPDX-License-Identifier: UNLICENSED
// Copyright (c) Eywa.Fi, 2021-2023 - all rights reserved
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Should be implemented by "treasury" contract in cases when third party token used instead of our synth.
 *
 * Mint\Burn can be implemented as Lock\Unlock in treasury contract.
 */
interface ISynthAdapter {
    enum SynthType { Unknown, DefaultSynth, CustomSynth, ThirdPartySynth, ThirdPartyToken }

    function mint(address account, uint256 amount) external;

    function burn(address account, uint256 amount) external;

    function setCap(uint256) external;

    function decimals() external view returns (uint8);

    function originalToken() external view returns (address);

    function synthToken() external view returns (address);

    function chainIdFrom() external view returns (uint64); // TODO what if token native in 2-3-4 chains? // []

    function chainSymbolFrom() external view returns (string memory);

    function synthType() external view returns (uint8);

    function cap() external view returns (uint256);
}

interface ISynthERC20 is ISynthAdapter, IERC20 {
    function mintWithAllowanceIncrease(address account, address spender, uint256 amount) external;
    function burnWithAllowanceDecrease(address account, address spender, uint256 amount) external;
}

// SPDX-License-Identifier: UNLICENSED
// Copyright (c) Eywa.Fi, 2021-2023 - all rights reserved
pragma solidity 0.8.17;


interface IWhitelist {

    enum TokenState { NotSet, InOut }
    enum PoolState { NotSet, AddSwapRemove }

    struct TokenStatus {
        address token;
        uint256 min;
        uint256 max;
        uint256 bridgeFee;
        TokenState state;
    }

    struct PoolStatus {
        address pool;
        uint256 aggregationFee;
        PoolState state;
    }
    
    function tokenMin(address token) external view returns (uint256);
    function tokenMax(address token) external view returns (uint256);
    function tokenMinMax(address token) external view returns (uint256, uint256);
    function bridgeFee(address token) external view returns (uint256);
    function tokenState(address token) external view returns (uint8);
    function tokenStatus(address token) external view returns (TokenStatus memory);
    function tokens(uint256 offset, uint256 count) external view returns (TokenStatus[] memory);

    function aggregationFee(address pool) external view returns (uint256);
    function poolState(address pool) external view returns (uint8);
    function poolStatus(address pool) external view returns (PoolStatus memory);
    function pools(uint256 offset, uint256 count) external view returns (PoolStatus[] memory);

}

// SPDX-License-Identifier: UNLICENSED
// Copyright (c) Eywa.Fi, 2021-2023 - all rights reserved
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./EndPoint.sol";
import "./interfaces/ISynth.sol";
import "./interfaces/IWhitelist.sol";
import "./interfaces/IAddressBook.sol";


contract SynthesisV2 is EndPoint  {

    using Address for address;

    /// @dev fee denominator
    uint256 public constant FEE_DENOMINATOR = 10000;
    /// @dev original => synthetic
    mapping(address => address) public synthByOriginal;

    event Synthesized(address token, uint256 amount, address from, address to);
    event Move(address token, uint256 amount, address from, address to, uint64 chainIdTo);
    event Burn(address token, uint256 amount, address from, address to);
    event SynthRegistered(address originalToken, address syntheticToken);

    modifier onlyRouter() {
        address router = IAddressBook(addressBook).router(uint64(block.chainid));
        require(router == msg.sender, "Portal: router only");
        _;
    }

    constructor(address addressBook_) EndPoint(addressBook_) {

    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function setCap(address token, uint256 cap_) external onlyOwner {
        ISynthAdapter adapterImpl = ISynthAdapter(token);
        adapterImpl.setCap(cap_);
    }

    /**
     * @dev Get token representation address.
     *
     * @param otoken_ original token address.
     */
    function getSynth(address otoken_) external view returns (address) {
        return synthByOriginal[otoken_];
    }

    /**
     * @dev Mints synthetic token. Can be called only by bridge after initiation on a second chain.
     *
     * If synth is thirdparty synth or some another token otoken MUST be an ISynthAdapter with
     * mint\burn like implemenatation. SynthAdapter have to lock\release token.
     *
     * @param otoken origin token address;
     * @param amount amount to mint;
     * @param from minter address;
     * @param to recipient address.
     */
    function mint(
        address otoken,
        uint256 amount,
        address from,
        address to
    ) external onlyRouter returns (uint256 amountOut) {
        IAddressBook addressBookImpl = IAddressBook(addressBook);
        address whitelist = addressBookImpl.whitelist();
        address treasury = addressBookImpl.treasury();
        uint256 fee = amount * IWhitelist(whitelist).bridgeFee(otoken) / FEE_DENOMINATOR;
        ISynthERC20 synthImpl = ISynthERC20(synthByOriginal[otoken]);
        require(address(synthImpl) != address(0), "Synthesis: synth not set");
        amountOut = amount - fee;
        synthImpl.mint(treasury, fee);
        synthImpl.mint(to, amountOut);
        emit Synthesized(address(synthImpl), amount, from, to);
    }

    /**
     * @dev Mints synthetic token. Can be called only by bridge after initiation on a second chain.
     *
     * If synth is thirdparty synth or some another token otoken MUST be an ISynthAdapter with
     * mint\burn like implemenatation. SynthAdapter have to lock\release token.
     *
     * @param stoken synth token address;
     * @param amount amount to mint;
     * @param from minter address;
     * @param to recipient address.
     */
    function emergencyMint(
        address stoken,
        uint256 amount,
        address from,
        address to
    ) external onlyRouter returns (uint256 amountOut) {
        ISynthERC20 synthImpl = ISynthERC20(stoken);
        require(address(synthImpl) != address(0), "Synthesis: synth not set");
        require(synthByOriginal[synthImpl.originalToken()] == stoken, "Synthesis: synth not set");
        amountOut = amount;
        synthImpl.mint(to, amountOut);
        emit Synthesized(address(synthImpl), amount, from, to);
    }

    /**
     * @dev Burns given synthetic token and unlocks the original one (mints) in the origin (another) chain.
     *
     * @param stoken stoken token address;
     * @param amount amount to burn;
     * @param to recipient address;
     * @param chainIdTo destination chain id.
     */
    function burn(
        address stoken,
        uint256 amount,
        address from,
        address to,
        uint64 chainIdTo
    ) external onlyRouter {
        ISynthERC20 impl = ISynthERC20(stoken);
        impl.burn(from, amount);
        if (impl.chainIdFrom() != chainIdTo) {
            emit Move(stoken, amount, from, to, chainIdTo);
        } else {
            emit Burn(stoken, amount, from, to);
        }
    }

    /**
     * @dev Sets synths.
     *
     * @param stokens array of ISynthERC20 tokens.
     */
    function setSynths(address[] calldata stokens) external onlyOwner {
        for (uint256 i = 0; i < stokens.length; ++i) {
            _setSynth(stokens[i]);
        }
    }

    function _setSynth(address stoken_) private {
        ISynthERC20 impl = ISynthERC20(stoken_);
        address otoken = impl.originalToken();
        require(otoken != address(0), "Synthesis: synth incorrect");
        require(synthByOriginal[otoken] == address(0), "Synthesis: synth already set");
        if (
            impl.synthType() == uint8(ISynthAdapter.SynthType.DefaultSynth) ||
            impl.synthType() == uint8(ISynthAdapter.SynthType.CustomSynth)
        ) {
            require(impl.totalSupply() == 0, "Synthesis: totalSupply incorrect");
        }
        synthByOriginal[otoken] = stoken_;
        emit SynthRegistered(otoken, stoken_);
    }
    
}

// SPDX-License-Identifier: UNLICENSED
// Copyright (c) Eywa.Fi, 2021-2023 - all rights reserved
pragma solidity 0.8.17;


abstract contract Typecast {
    function castToAddress(bytes32 x) public pure returns (address) {
        return address(uint160(uint256(x)));
    }

    function castToBytes32(address a) public pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }
}