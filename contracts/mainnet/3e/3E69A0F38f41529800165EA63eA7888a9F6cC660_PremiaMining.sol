// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorInterface {
  function latestAnswer() external view returns (int256);

  function latestTimestamp() external view returns (uint256);

  function latestRound() external view returns (uint256);

  function getAnswer(uint256 roundId) external view returns (int256);

  function getTimestamp(uint256 roundId) external view returns (uint256);

  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

  event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}

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

pragma solidity ^0.8.0;

import { ABDKMath64x64 } from 'abdk-libraries-solidity/ABDKMath64x64.sol';

/**
 * @title SolidState token extensions for ABDKMath64x64 library
 */
library ABDKMath64x64Token {
    using ABDKMath64x64 for int128;

    /**
     * @notice convert 64x64 fixed point representation of token amount to decimal
     * @param value64x64 64x64 fixed point representation of token amount
     * @param decimals token display decimals
     * @return value decimal representation of token amount
     */
    function toDecimals(int128 value64x64, uint8 decimals)
        internal
        pure
        returns (uint256 value)
    {
        value = value64x64.mulu(10**decimals);
    }

    /**
     * @notice convert decimal representation of token amount to 64x64 fixed point
     * @param value decimal representation of token amount
     * @param decimals token display decimals
     * @return value64x64 64x64 fixed point representation of token amount
     */
    function fromDecimals(uint256 value, uint8 decimals)
        internal
        pure
        returns (int128 value64x64)
    {
        value64x64 = ABDKMath64x64.divu(value, 10**decimals);
    }

    /**
     * @notice convert 64x64 fixed point representation of token amount to wei (18 decimals)
     * @param value64x64 64x64 fixed point representation of token amount
     * @return value wei representation of token amount
     */
    function toWei(int128 value64x64) internal pure returns (uint256 value) {
        value = toDecimals(value64x64, 18);
    }

    /**
     * @notice convert wei representation (18 decimals) of token amount to 64x64 fixed point
     * @param value wei representation of token amount
     * @return value64x64 64x64 fixed point representation of token amount
     */
    function fromWei(uint256 value) internal pure returns (int128 value64x64) {
        value64x64 = fromDecimals(value, 18);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC173Internal } from '../../interfaces/IERC173Internal.sol';

interface IOwnableInternal is IERC173Internal {
    error Ownable__NotOwner();
    error Ownable__NotTransitiveOwner();
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC173 } from '../../interfaces/IERC173.sol';
import { AddressUtils } from '../../utils/AddressUtils.sol';
import { IOwnableInternal } from './IOwnableInternal.sol';
import { OwnableStorage } from './OwnableStorage.sol';

abstract contract OwnableInternal is IOwnableInternal {
    using AddressUtils for address;

    modifier onlyOwner() {
        if (msg.sender != _owner()) revert Ownable__NotOwner();
        _;
    }

    modifier onlyTransitiveOwner() {
        if (msg.sender != _transitiveOwner())
            revert Ownable__NotTransitiveOwner();
        _;
    }

    function _owner() internal view virtual returns (address) {
        return OwnableStorage.layout().owner;
    }

    function _transitiveOwner() internal view virtual returns (address owner) {
        owner = _owner();

        while (owner.isContract()) {
            try IERC173(owner).owner() returns (address transitiveOwner) {
                owner = transitiveOwner;
            } catch {
                break;
            }
        }
    }

    function _transferOwnership(address account) internal virtual {
        _setOwner(account);
    }

    function _setOwner(address account) internal virtual {
        OwnableStorage.Layout storage l = OwnableStorage.layout();
        emit OwnershipTransferred(l.owner, account);
        l.owner = account;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

library OwnableStorage {
    struct Layout {
        address owner;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('solidstate.contracts.storage.Ownable');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title Set implementation with enumeration functions
 * @dev derived from https://github.com/OpenZeppelin/openzeppelin-contracts (MIT license)
 */
library EnumerableSet {
    error EnumerableSet__IndexOutOfBounds();

    struct Set {
        bytes32[] _values;
        // 1-indexed to allow 0 to signify nonexistence
        mapping(bytes32 => uint256) _indexes;
    }

    struct Bytes32Set {
        Set _inner;
    }

    struct AddressSet {
        Set _inner;
    }

    struct UintSet {
        Set _inner;
    }

    function at(
        Bytes32Set storage set,
        uint256 index
    ) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    function at(
        AddressSet storage set,
        uint256 index
    ) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    function at(
        UintSet storage set,
        uint256 index
    ) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    function contains(
        Bytes32Set storage set,
        bytes32 value
    ) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    function contains(
        AddressSet storage set,
        address value
    ) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    function contains(
        UintSet storage set,
        uint256 value
    ) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    function indexOf(
        Bytes32Set storage set,
        bytes32 value
    ) internal view returns (uint256) {
        return _indexOf(set._inner, value);
    }

    function indexOf(
        AddressSet storage set,
        address value
    ) internal view returns (uint256) {
        return _indexOf(set._inner, bytes32(uint256(uint160(value))));
    }

    function indexOf(
        UintSet storage set,
        uint256 value
    ) internal view returns (uint256) {
        return _indexOf(set._inner, bytes32(value));
    }

    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    function add(
        Bytes32Set storage set,
        bytes32 value
    ) internal returns (bool) {
        return _add(set._inner, value);
    }

    function add(
        AddressSet storage set,
        address value
    ) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    function remove(
        Bytes32Set storage set,
        bytes32 value
    ) internal returns (bool) {
        return _remove(set._inner, value);
    }

    function remove(
        AddressSet storage set,
        address value
    ) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    function remove(
        UintSet storage set,
        uint256 value
    ) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    function toArray(
        Bytes32Set storage set
    ) internal view returns (bytes32[] memory) {
        return set._inner._values;
    }

    function toArray(
        AddressSet storage set
    ) internal view returns (address[] memory) {
        bytes32[] storage values = set._inner._values;
        address[] storage array;

        assembly {
            array.slot := values.slot
        }

        return array;
    }

    function toArray(
        UintSet storage set
    ) internal view returns (uint256[] memory) {
        bytes32[] storage values = set._inner._values;
        uint256[] storage array;

        assembly {
            array.slot := values.slot
        }

        return array;
    }

    function _at(
        Set storage set,
        uint256 index
    ) private view returns (bytes32) {
        if (index >= set._values.length)
            revert EnumerableSet__IndexOutOfBounds();
        return set._values[index];
    }

    function _contains(
        Set storage set,
        bytes32 value
    ) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    function _indexOf(
        Set storage set,
        bytes32 value
    ) private view returns (uint256) {
        unchecked {
            return set._indexes[value] - 1;
        }
    }

    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    function _add(
        Set storage set,
        bytes32 value
    ) private returns (bool status) {
        if (!_contains(set, value)) {
            set._values.push(value);
            set._indexes[value] = set._values.length;
            status = true;
        }
    }

    function _remove(
        Set storage set,
        bytes32 value
    ) private returns (bool status) {
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            unchecked {
                bytes32 last = set._values[set._values.length - 1];

                // move last value to now-vacant index

                set._values[valueIndex - 1] = last;
                set._indexes[last] = valueIndex;
            }
            // clear last index

            set._values.pop();
            delete set._indexes[value];

            status = true;
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC165Internal } from './IERC165Internal.sol';

/**
 * @title ERC165 interface registration interface
 * @dev see https://eips.ethereum.org/EIPS/eip-165
 */
interface IERC165 is IERC165Internal {
    /**
     * @notice query whether contract has registered support for given interface
     * @param interfaceId interface id
     * @return bool whether interface is supported
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC165Internal } from './IERC165Internal.sol';

/**
 * @title ERC165 interface registration interface
 */
interface IERC165Internal {

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC173Internal } from './IERC173Internal.sol';

/**
 * @title Contract ownership standard interface
 * @dev see https://eips.ethereum.org/EIPS/eip-173
 */
interface IERC173 is IERC173Internal {
    /**
     * @notice get the ERC173 contract owner
     * @return conrtact owner
     */
    function owner() external view returns (address);

    /**
     * @notice transfer contract ownership to new account
     * @param account address of new owner
     */
    function transferOwnership(address account) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title Partial ERC173 interface needed by internal functions
 */
interface IERC173Internal {
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC20Internal } from './IERC20Internal.sol';

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface IERC20 is IERC20Internal {
    /**
     * @notice query the total minted token supply
     * @return token supply
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice query the token balance of given account
     * @param account address to query
     * @return token balance
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice query the allowance granted from given holder to given spender
     * @param holder approver of allowance
     * @param spender recipient of allowance
     * @return token allowance
     */
    function allowance(
        address holder,
        address spender
    ) external view returns (uint256);

    /**
     * @notice grant approval to spender to spend tokens
     * @dev prefer ERC20Extended functions to avoid transaction-ordering vulnerability (see https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729)
     * @param spender recipient of allowance
     * @param amount quantity of tokens approved for spending
     * @return success status (always true; otherwise function should revert)
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @notice transfer tokens to given recipient
     * @param recipient beneficiary of token transfer
     * @param amount quantity of tokens to transfer
     * @return success status (always true; otherwise function should revert)
     */
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @notice transfer tokens to given recipient on behalf of given holder
     * @param holder holder of tokens prior to transfer
     * @param recipient beneficiary of token transfer
     * @param amount quantity of tokens to transfer
     * @return success status (always true; otherwise function should revert)
     */
    function transferFrom(
        address holder,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title Partial ERC20 interface needed by internal functions
 */
interface IERC20Internal {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { EnumerableSet } from '../../../data/EnumerableSet.sol';

library ERC1155EnumerableStorage {
    struct Layout {
        mapping(uint256 => uint256) totalSupply;
        mapping(uint256 => EnumerableSet.AddressSet) accountsByToken;
        mapping(address => EnumerableSet.UintSet) tokensByAccount;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('solidstate.contracts.storage.ERC1155Enumerable');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC1155MetadataInternal } from './IERC1155MetadataInternal.sol';

/**
 * @title ERC1155Metadata interface
 */
interface IERC1155Metadata is IERC1155MetadataInternal {
    /**
     * @notice get generated URI for given token
     * @return token URI
     */
    function uri(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title Partial ERC1155Metadata interface needed by internal functions
 */
interface IERC1155MetadataInternal {
    event URI(string value, uint256 indexed tokenId);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC20 } from '../../../interfaces/IERC20.sol';
import { IERC20BaseInternal } from './IERC20BaseInternal.sol';

/**
 * @title ERC20 base interface
 */
interface IERC20Base is IERC20BaseInternal, IERC20 {

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC20Internal } from '../../../interfaces/IERC20Internal.sol';

/**
 * @title ERC20 base interface
 */
interface IERC20BaseInternal is IERC20Internal {
    error ERC20Base__ApproveFromZeroAddress();
    error ERC20Base__ApproveToZeroAddress();
    error ERC20Base__BurnExceedsBalance();
    error ERC20Base__BurnFromZeroAddress();
    error ERC20Base__InsufficientAllowance();
    error ERC20Base__MintToZeroAddress();
    error ERC20Base__TransferExceedsBalance();
    error ERC20Base__TransferFromZeroAddress();
    error ERC20Base__TransferToZeroAddress();
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC20ExtendedInternal } from './IERC20ExtendedInternal.sol';

/**
 * @title ERC20 extended interface
 */
interface IERC20Extended is IERC20ExtendedInternal {
    /**
     * @notice increase spend amount granted to spender
     * @param spender address whose allowance to increase
     * @param amount quantity by which to increase allowance
     * @return success status (always true; otherwise function will revert)
     */
    function increaseAllowance(
        address spender,
        uint256 amount
    ) external returns (bool);

    /**
     * @notice decrease spend amount granted to spender
     * @param spender address whose allowance to decrease
     * @param amount quantity by which to decrease allowance
     * @return success status (always true; otherwise function will revert)
     */
    function decreaseAllowance(
        address spender,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC20BaseInternal } from '../base/IERC20BaseInternal.sol';

/**
 * @title ERC20 extended internal interface
 */
interface IERC20ExtendedInternal is IERC20BaseInternal {
    error ERC20Extended__ExcessiveAllowance();
    error ERC20Extended__InsufficientAllowance();
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC20Base } from './base/IERC20Base.sol';
import { IERC20Extended } from './extended/IERC20Extended.sol';
import { IERC20Metadata } from './metadata/IERC20Metadata.sol';
import { IERC20Permit } from './permit/IERC20Permit.sol';

interface ISolidStateERC20 is
    IERC20Base,
    IERC20Extended,
    IERC20Metadata,
    IERC20Permit
{}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC20MetadataInternal } from './IERC20MetadataInternal.sol';

/**
 * @title ERC20 metadata interface
 */
interface IERC20Metadata is IERC20MetadataInternal {
    /**
     * @notice return token name
     * @return token name
     */
    function name() external view returns (string memory);

    /**
     * @notice return token symbol
     * @return token symbol
     */
    function symbol() external view returns (string memory);

    /**
     * @notice return token decimals, generally used only for display purposes
     * @return token decimals
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title ERC20 metadata internal interface
 */
interface IERC20MetadataInternal {

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC20Metadata } from '../metadata/IERC20Metadata.sol';
import { IERC2612 } from './IERC2612.sol';
import { IERC20PermitInternal } from './IERC20PermitInternal.sol';

// TODO: note that IERC20Metadata is needed for eth-permit library

interface IERC20Permit is IERC20PermitInternal, IERC2612 {

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC2612Internal } from './IERC2612Internal.sol';

interface IERC20PermitInternal is IERC2612Internal {
    error ERC20Permit__ExpiredDeadline();
    error ERC20Permit__InvalidSignature();
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC2612Internal } from './IERC2612Internal.sol';

/**
 * @title ERC2612 interface
 * @dev see https://eips.ethereum.org/EIPS/eip-2612.
 */
interface IERC2612 is IERC2612Internal {
    /**
     * @notice return the EIP-712 domain separator unique to contract and chain
     * @return domainSeparator domain separator
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32 domainSeparator);

    /**
     * @notice get the current ERC2612 nonce for the given address
     * @return current nonce
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @notice approve spender to transfer tokens held by owner via signature
     * @dev this function may be vulnerable to approval replay attacks
     * @param owner holder of tokens and signer of permit
     * @param spender beneficiary of approval
     * @param amount quantity of tokens to approve
     * @param v secp256k1 'v' value
     * @param r secp256k1 'r' value
     * @param s secp256k1 's' value
     */
    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

interface IERC2612Internal {}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { UintUtils } from './UintUtils.sol';

library AddressUtils {
    using UintUtils for uint256;

    error AddressUtils__InsufficientBalance();
    error AddressUtils__NotContract();
    error AddressUtils__SendValueFailed();

    function toString(address account) internal pure returns (string memory) {
        return uint256(uint160(account)).toHexString(20);
    }

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function sendValue(address payable account, uint256 amount) internal {
        (bool success, ) = account.call{ value: amount }('');
        if (!success) revert AddressUtils__SendValueFailed();
    }

    function functionCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory) {
        return
            functionCall(target, data, 'AddressUtils: failed low-level call');
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory error
    ) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, error);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return
            functionCallWithValue(
                target,
                data,
                value,
                'AddressUtils: failed low-level call with value'
            );
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory error
    ) internal returns (bytes memory) {
        if (value > address(this).balance)
            revert AddressUtils__InsufficientBalance();
        return _functionCallWithValue(target, data, value, error);
    }

    /**
     * @notice execute arbitrary external call with limited gas usage and amount of copied return data
     * @dev derived from https://github.com/nomad-xyz/ExcessivelySafeCall (MIT License)
     * @param target recipient of call
     * @param gasAmount gas allowance for call
     * @param value native token value to include in call
     * @param maxCopy maximum number of bytes to copy from return data
     * @param data encoded call data
     * @return success whether call is successful
     * @return returnData copied return data
     */
    function excessivelySafeCall(
        address target,
        uint256 gasAmount,
        uint256 value,
        uint16 maxCopy,
        bytes memory data
    ) internal returns (bool success, bytes memory returnData) {
        returnData = new bytes(maxCopy);

        assembly {
            // execute external call via assembly to avoid automatic copying of return data
            success := call(
                gasAmount,
                target,
                value,
                add(data, 0x20),
                mload(data),
                0,
                0
            )

            // determine whether to limit amount of data to copy
            let toCopy := returndatasize()

            if gt(toCopy, maxCopy) {
                toCopy := maxCopy
            }

            // store the length of the copied bytes
            mstore(returnData, toCopy)

            // copy the bytes from returndata[0:toCopy]
            returndatacopy(add(returnData, 0x20), 0, toCopy)
        }
    }

    function _functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory error
    ) private returns (bytes memory) {
        if (!isContract(target)) revert AddressUtils__NotContract();

        (bool success, bytes memory returnData) = target.call{ value: value }(
            data
        );

        if (success) {
            return returnData;
        } else if (returnData.length > 0) {
            assembly {
                let returnData_size := mload(returnData)
                revert(add(32, returnData), returnData_size)
            }
        } else {
            revert(error);
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC20 } from '../interfaces/IERC20.sol';
import { AddressUtils } from './AddressUtils.sol';

/**
 * @title Safe ERC20 interaction library
 * @dev derived from https://github.com/OpenZeppelin/openzeppelin-contracts/ (MIT license)
 */
library SafeERC20 {
    using AddressUtils for address;

    error SafeERC20__ApproveFromNonZeroToNonZero();
    error SafeERC20__DecreaseAllowanceBelowZero();
    error SafeERC20__OperationFailed();

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
    }

    /**
     * @dev safeApprove (like approve) should only be called when setting an initial allowance or when resetting it to zero; otherwise prefer safeIncreaseAllowance and safeDecreaseAllowance
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        if ((value != 0) && (token.allowance(address(this), spender) != 0))
            revert SafeERC20__ApproveFromNonZeroToNonZero();

        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            if (oldAllowance < value)
                revert SafeERC20__DecreaseAllowanceBelowZero();
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(
                token,
                abi.encodeWithSelector(
                    token.approve.selector,
                    spender,
                    newAllowance
                )
            );
        }
    }

    /**
     * @notice send transaction data and check validity of return value, if present
     * @param token ERC20 token interface
     * @param data transaction data
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(
            data,
            'SafeERC20: low-level call failed'
        );

        if (returndata.length > 0) {
            if (!abi.decode(returndata, (bool)))
                revert SafeERC20__OperationFailed();
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title utility functions for uint256 operations
 * @dev derived from https://github.com/OpenZeppelin/openzeppelin-contracts/ (MIT license)
 */
library UintUtils {
    error UintUtils__InsufficientHexLength();

    bytes16 private constant HEX_SYMBOLS = '0123456789abcdef';

    function add(uint256 a, int256 b) internal pure returns (uint256) {
        return b < 0 ? sub(a, -b) : a + uint256(b);
    }

    function sub(uint256 a, int256 b) internal pure returns (uint256) {
        return b < 0 ? add(a, -b) : a - uint256(b);
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return '0';
        }

        uint256 temp = value;
        uint256 digits;

        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);

        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }

    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return '0x00';
        }

        uint256 length = 0;

        for (uint256 temp = value; temp != 0; temp >>= 8) {
            unchecked {
                length++;
            }
        }

        return toHexString(value, length);
    }

    function toHexString(
        uint256 value,
        uint256 length
    ) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = '0';
        buffer[1] = 'x';

        unchecked {
            for (uint256 i = 2 * length + 1; i > 1; --i) {
                buffer[i] = HEX_SYMBOLS[value & 0xf];
                value >>= 4;
            }
        }

        if (value != 0) revert UintUtils__InsufficientHexLength();

        return string(buffer);
    }
}

// SPDX-License-Identifier: BSD-4-Clause
/*
 * ABDK Math 64.64 Smart Contract Library.  Copyright © 2019 by ABDK Consulting.
 * Author: Mikhail Vladimirov <[email protected]>
 */
pragma solidity ^0.8.0;

/**
 * Smart contract library of mathematical functions operating with signed
 * 64.64-bit fixed point numbers.  Signed 64.64-bit fixed point number is
 * basically a simple fraction whose numerator is signed 128-bit integer and
 * denominator is 2^64.  As long as denominator is always the same, there is no
 * need to store it, thus in Solidity signed 64.64-bit fixed point numbers are
 * represented by int128 type holding only the numerator.
 */
library ABDKMath64x64 {
  /*
   * Minimum value signed 64.64-bit fixed point number may have. 
   */
  int128 private constant MIN_64x64 = -0x80000000000000000000000000000000;

  /*
   * Maximum value signed 64.64-bit fixed point number may have. 
   */
  int128 private constant MAX_64x64 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

  /**
   * Convert signed 256-bit integer number into signed 64.64-bit fixed point
   * number.  Revert on overflow.
   *
   * @param x signed 256-bit integer number
   * @return signed 64.64-bit fixed point number
   */
  function fromInt (int256 x) internal pure returns (int128) {
    unchecked {
      require (x >= -0x8000000000000000 && x <= 0x7FFFFFFFFFFFFFFF);
      return int128 (x << 64);
    }
  }

  /**
   * Convert signed 64.64 fixed point number into signed 64-bit integer number
   * rounding down.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 64-bit integer number
   */
  function toInt (int128 x) internal pure returns (int64) {
    unchecked {
      return int64 (x >> 64);
    }
  }

  /**
   * Convert unsigned 256-bit integer number into signed 64.64-bit fixed point
   * number.  Revert on overflow.
   *
   * @param x unsigned 256-bit integer number
   * @return signed 64.64-bit fixed point number
   */
  function fromUInt (uint256 x) internal pure returns (int128) {
    unchecked {
      require (x <= 0x7FFFFFFFFFFFFFFF);
      return int128 (int256 (x << 64));
    }
  }

  /**
   * Convert signed 64.64 fixed point number into unsigned 64-bit integer
   * number rounding down.  Revert on underflow.
   *
   * @param x signed 64.64-bit fixed point number
   * @return unsigned 64-bit integer number
   */
  function toUInt (int128 x) internal pure returns (uint64) {
    unchecked {
      require (x >= 0);
      return uint64 (uint128 (x >> 64));
    }
  }

  /**
   * Convert signed 128.128 fixed point number into signed 64.64-bit fixed point
   * number rounding down.  Revert on overflow.
   *
   * @param x signed 128.128-bin fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function from128x128 (int256 x) internal pure returns (int128) {
    unchecked {
      int256 result = x >> 64;
      require (result >= MIN_64x64 && result <= MAX_64x64);
      return int128 (result);
    }
  }

  /**
   * Convert signed 64.64 fixed point number into signed 128.128 fixed point
   * number.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 128.128 fixed point number
   */
  function to128x128 (int128 x) internal pure returns (int256) {
    unchecked {
      return int256 (x) << 64;
    }
  }

  /**
   * Calculate x + y.  Revert on overflow.
   *
   * @param x signed 64.64-bit fixed point number
   * @param y signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function add (int128 x, int128 y) internal pure returns (int128) {
    unchecked {
      int256 result = int256(x) + y;
      require (result >= MIN_64x64 && result <= MAX_64x64);
      return int128 (result);
    }
  }

  /**
   * Calculate x - y.  Revert on overflow.
   *
   * @param x signed 64.64-bit fixed point number
   * @param y signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function sub (int128 x, int128 y) internal pure returns (int128) {
    unchecked {
      int256 result = int256(x) - y;
      require (result >= MIN_64x64 && result <= MAX_64x64);
      return int128 (result);
    }
  }

  /**
   * Calculate x * y rounding down.  Revert on overflow.
   *
   * @param x signed 64.64-bit fixed point number
   * @param y signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function mul (int128 x, int128 y) internal pure returns (int128) {
    unchecked {
      int256 result = int256(x) * y >> 64;
      require (result >= MIN_64x64 && result <= MAX_64x64);
      return int128 (result);
    }
  }

  /**
   * Calculate x * y rounding towards zero, where x is signed 64.64 fixed point
   * number and y is signed 256-bit integer number.  Revert on overflow.
   *
   * @param x signed 64.64 fixed point number
   * @param y signed 256-bit integer number
   * @return signed 256-bit integer number
   */
  function muli (int128 x, int256 y) internal pure returns (int256) {
    unchecked {
      if (x == MIN_64x64) {
        require (y >= -0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF &&
          y <= 0x1000000000000000000000000000000000000000000000000);
        return -y << 63;
      } else {
        bool negativeResult = false;
        if (x < 0) {
          x = -x;
          negativeResult = true;
        }
        if (y < 0) {
          y = -y; // We rely on overflow behavior here
          negativeResult = !negativeResult;
        }
        uint256 absoluteResult = mulu (x, uint256 (y));
        if (negativeResult) {
          require (absoluteResult <=
            0x8000000000000000000000000000000000000000000000000000000000000000);
          return -int256 (absoluteResult); // We rely on overflow behavior here
        } else {
          require (absoluteResult <=
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
          return int256 (absoluteResult);
        }
      }
    }
  }

  /**
   * Calculate x * y rounding down, where x is signed 64.64 fixed point number
   * and y is unsigned 256-bit integer number.  Revert on overflow.
   *
   * @param x signed 64.64 fixed point number
   * @param y unsigned 256-bit integer number
   * @return unsigned 256-bit integer number
   */
  function mulu (int128 x, uint256 y) internal pure returns (uint256) {
    unchecked {
      if (y == 0) return 0;

      require (x >= 0);

      uint256 lo = (uint256 (int256 (x)) * (y & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)) >> 64;
      uint256 hi = uint256 (int256 (x)) * (y >> 128);

      require (hi <= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
      hi <<= 64;

      require (hi <=
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF - lo);
      return hi + lo;
    }
  }

  /**
   * Calculate x / y rounding towards zero.  Revert on overflow or when y is
   * zero.
   *
   * @param x signed 64.64-bit fixed point number
   * @param y signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function div (int128 x, int128 y) internal pure returns (int128) {
    unchecked {
      require (y != 0);
      int256 result = (int256 (x) << 64) / y;
      require (result >= MIN_64x64 && result <= MAX_64x64);
      return int128 (result);
    }
  }

  /**
   * Calculate x / y rounding towards zero, where x and y are signed 256-bit
   * integer numbers.  Revert on overflow or when y is zero.
   *
   * @param x signed 256-bit integer number
   * @param y signed 256-bit integer number
   * @return signed 64.64-bit fixed point number
   */
  function divi (int256 x, int256 y) internal pure returns (int128) {
    unchecked {
      require (y != 0);

      bool negativeResult = false;
      if (x < 0) {
        x = -x; // We rely on overflow behavior here
        negativeResult = true;
      }
      if (y < 0) {
        y = -y; // We rely on overflow behavior here
        negativeResult = !negativeResult;
      }
      uint128 absoluteResult = divuu (uint256 (x), uint256 (y));
      if (negativeResult) {
        require (absoluteResult <= 0x80000000000000000000000000000000);
        return -int128 (absoluteResult); // We rely on overflow behavior here
      } else {
        require (absoluteResult <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
        return int128 (absoluteResult); // We rely on overflow behavior here
      }
    }
  }

  /**
   * Calculate x / y rounding towards zero, where x and y are unsigned 256-bit
   * integer numbers.  Revert on overflow or when y is zero.
   *
   * @param x unsigned 256-bit integer number
   * @param y unsigned 256-bit integer number
   * @return signed 64.64-bit fixed point number
   */
  function divu (uint256 x, uint256 y) internal pure returns (int128) {
    unchecked {
      require (y != 0);
      uint128 result = divuu (x, y);
      require (result <= uint128 (MAX_64x64));
      return int128 (result);
    }
  }

  /**
   * Calculate -x.  Revert on overflow.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function neg (int128 x) internal pure returns (int128) {
    unchecked {
      require (x != MIN_64x64);
      return -x;
    }
  }

  /**
   * Calculate |x|.  Revert on overflow.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function abs (int128 x) internal pure returns (int128) {
    unchecked {
      require (x != MIN_64x64);
      return x < 0 ? -x : x;
    }
  }

  /**
   * Calculate 1 / x rounding towards zero.  Revert on overflow or when x is
   * zero.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function inv (int128 x) internal pure returns (int128) {
    unchecked {
      require (x != 0);
      int256 result = int256 (0x100000000000000000000000000000000) / x;
      require (result >= MIN_64x64 && result <= MAX_64x64);
      return int128 (result);
    }
  }

  /**
   * Calculate arithmetics average of x and y, i.e. (x + y) / 2 rounding down.
   *
   * @param x signed 64.64-bit fixed point number
   * @param y signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function avg (int128 x, int128 y) internal pure returns (int128) {
    unchecked {
      return int128 ((int256 (x) + int256 (y)) >> 1);
    }
  }

  /**
   * Calculate geometric average of x and y, i.e. sqrt (x * y) rounding down.
   * Revert on overflow or in case x * y is negative.
   *
   * @param x signed 64.64-bit fixed point number
   * @param y signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function gavg (int128 x, int128 y) internal pure returns (int128) {
    unchecked {
      int256 m = int256 (x) * int256 (y);
      require (m >= 0);
      require (m <
          0x4000000000000000000000000000000000000000000000000000000000000000);
      return int128 (sqrtu (uint256 (m)));
    }
  }

  /**
   * Calculate x^y assuming 0^0 is 1, where x is signed 64.64 fixed point number
   * and y is unsigned 256-bit integer number.  Revert on overflow.
   *
   * @param x signed 64.64-bit fixed point number
   * @param y uint256 value
   * @return signed 64.64-bit fixed point number
   */
  function pow (int128 x, uint256 y) internal pure returns (int128) {
    unchecked {
      bool negative = x < 0 && y & 1 == 1;

      uint256 absX = uint128 (x < 0 ? -x : x);
      uint256 absResult;
      absResult = 0x100000000000000000000000000000000;

      if (absX <= 0x10000000000000000) {
        absX <<= 63;
        while (y != 0) {
          if (y & 0x1 != 0) {
            absResult = absResult * absX >> 127;
          }
          absX = absX * absX >> 127;

          if (y & 0x2 != 0) {
            absResult = absResult * absX >> 127;
          }
          absX = absX * absX >> 127;

          if (y & 0x4 != 0) {
            absResult = absResult * absX >> 127;
          }
          absX = absX * absX >> 127;

          if (y & 0x8 != 0) {
            absResult = absResult * absX >> 127;
          }
          absX = absX * absX >> 127;

          y >>= 4;
        }

        absResult >>= 64;
      } else {
        uint256 absXShift = 63;
        if (absX < 0x1000000000000000000000000) { absX <<= 32; absXShift -= 32; }
        if (absX < 0x10000000000000000000000000000) { absX <<= 16; absXShift -= 16; }
        if (absX < 0x1000000000000000000000000000000) { absX <<= 8; absXShift -= 8; }
        if (absX < 0x10000000000000000000000000000000) { absX <<= 4; absXShift -= 4; }
        if (absX < 0x40000000000000000000000000000000) { absX <<= 2; absXShift -= 2; }
        if (absX < 0x80000000000000000000000000000000) { absX <<= 1; absXShift -= 1; }

        uint256 resultShift = 0;
        while (y != 0) {
          require (absXShift < 64);

          if (y & 0x1 != 0) {
            absResult = absResult * absX >> 127;
            resultShift += absXShift;
            if (absResult > 0x100000000000000000000000000000000) {
              absResult >>= 1;
              resultShift += 1;
            }
          }
          absX = absX * absX >> 127;
          absXShift <<= 1;
          if (absX >= 0x100000000000000000000000000000000) {
              absX >>= 1;
              absXShift += 1;
          }

          y >>= 1;
        }

        require (resultShift < 64);
        absResult >>= 64 - resultShift;
      }
      int256 result = negative ? -int256 (absResult) : int256 (absResult);
      require (result >= MIN_64x64 && result <= MAX_64x64);
      return int128 (result);
    }
  }

  /**
   * Calculate sqrt (x) rounding down.  Revert if x < 0.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function sqrt (int128 x) internal pure returns (int128) {
    unchecked {
      require (x >= 0);
      return int128 (sqrtu (uint256 (int256 (x)) << 64));
    }
  }

  /**
   * Calculate binary logarithm of x.  Revert if x <= 0.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function log_2 (int128 x) internal pure returns (int128) {
    unchecked {
      require (x > 0);

      int256 msb = 0;
      int256 xc = x;
      if (xc >= 0x10000000000000000) { xc >>= 64; msb += 64; }
      if (xc >= 0x100000000) { xc >>= 32; msb += 32; }
      if (xc >= 0x10000) { xc >>= 16; msb += 16; }
      if (xc >= 0x100) { xc >>= 8; msb += 8; }
      if (xc >= 0x10) { xc >>= 4; msb += 4; }
      if (xc >= 0x4) { xc >>= 2; msb += 2; }
      if (xc >= 0x2) msb += 1;  // No need to shift xc anymore

      int256 result = msb - 64 << 64;
      uint256 ux = uint256 (int256 (x)) << uint256 (127 - msb);
      for (int256 bit = 0x8000000000000000; bit > 0; bit >>= 1) {
        ux *= ux;
        uint256 b = ux >> 255;
        ux >>= 127 + b;
        result += bit * int256 (b);
      }

      return int128 (result);
    }
  }

  /**
   * Calculate natural logarithm of x.  Revert if x <= 0.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function ln (int128 x) internal pure returns (int128) {
    unchecked {
      require (x > 0);

      return int128 (int256 (
          uint256 (int256 (log_2 (x))) * 0xB17217F7D1CF79ABC9E3B39803F2F6AF >> 128));
    }
  }

  /**
   * Calculate binary exponent of x.  Revert on overflow.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function exp_2 (int128 x) internal pure returns (int128) {
    unchecked {
      require (x < 0x400000000000000000); // Overflow

      if (x < -0x400000000000000000) return 0; // Underflow

      uint256 result = 0x80000000000000000000000000000000;

      if (x & 0x8000000000000000 > 0)
        result = result * 0x16A09E667F3BCC908B2FB1366EA957D3E >> 128;
      if (x & 0x4000000000000000 > 0)
        result = result * 0x1306FE0A31B7152DE8D5A46305C85EDEC >> 128;
      if (x & 0x2000000000000000 > 0)
        result = result * 0x1172B83C7D517ADCDF7C8C50EB14A791F >> 128;
      if (x & 0x1000000000000000 > 0)
        result = result * 0x10B5586CF9890F6298B92B71842A98363 >> 128;
      if (x & 0x800000000000000 > 0)
        result = result * 0x1059B0D31585743AE7C548EB68CA417FD >> 128;
      if (x & 0x400000000000000 > 0)
        result = result * 0x102C9A3E778060EE6F7CACA4F7A29BDE8 >> 128;
      if (x & 0x200000000000000 > 0)
        result = result * 0x10163DA9FB33356D84A66AE336DCDFA3F >> 128;
      if (x & 0x100000000000000 > 0)
        result = result * 0x100B1AFA5ABCBED6129AB13EC11DC9543 >> 128;
      if (x & 0x80000000000000 > 0)
        result = result * 0x10058C86DA1C09EA1FF19D294CF2F679B >> 128;
      if (x & 0x40000000000000 > 0)
        result = result * 0x1002C605E2E8CEC506D21BFC89A23A00F >> 128;
      if (x & 0x20000000000000 > 0)
        result = result * 0x100162F3904051FA128BCA9C55C31E5DF >> 128;
      if (x & 0x10000000000000 > 0)
        result = result * 0x1000B175EFFDC76BA38E31671CA939725 >> 128;
      if (x & 0x8000000000000 > 0)
        result = result * 0x100058BA01FB9F96D6CACD4B180917C3D >> 128;
      if (x & 0x4000000000000 > 0)
        result = result * 0x10002C5CC37DA9491D0985C348C68E7B3 >> 128;
      if (x & 0x2000000000000 > 0)
        result = result * 0x1000162E525EE054754457D5995292026 >> 128;
      if (x & 0x1000000000000 > 0)
        result = result * 0x10000B17255775C040618BF4A4ADE83FC >> 128;
      if (x & 0x800000000000 > 0)
        result = result * 0x1000058B91B5BC9AE2EED81E9B7D4CFAB >> 128;
      if (x & 0x400000000000 > 0)
        result = result * 0x100002C5C89D5EC6CA4D7C8ACC017B7C9 >> 128;
      if (x & 0x200000000000 > 0)
        result = result * 0x10000162E43F4F831060E02D839A9D16D >> 128;
      if (x & 0x100000000000 > 0)
        result = result * 0x100000B1721BCFC99D9F890EA06911763 >> 128;
      if (x & 0x80000000000 > 0)
        result = result * 0x10000058B90CF1E6D97F9CA14DBCC1628 >> 128;
      if (x & 0x40000000000 > 0)
        result = result * 0x1000002C5C863B73F016468F6BAC5CA2B >> 128;
      if (x & 0x20000000000 > 0)
        result = result * 0x100000162E430E5A18F6119E3C02282A5 >> 128;
      if (x & 0x10000000000 > 0)
        result = result * 0x1000000B1721835514B86E6D96EFD1BFE >> 128;
      if (x & 0x8000000000 > 0)
        result = result * 0x100000058B90C0B48C6BE5DF846C5B2EF >> 128;
      if (x & 0x4000000000 > 0)
        result = result * 0x10000002C5C8601CC6B9E94213C72737A >> 128;
      if (x & 0x2000000000 > 0)
        result = result * 0x1000000162E42FFF037DF38AA2B219F06 >> 128;
      if (x & 0x1000000000 > 0)
        result = result * 0x10000000B17217FBA9C739AA5819F44F9 >> 128;
      if (x & 0x800000000 > 0)
        result = result * 0x1000000058B90BFCDEE5ACD3C1CEDC823 >> 128;
      if (x & 0x400000000 > 0)
        result = result * 0x100000002C5C85FE31F35A6A30DA1BE50 >> 128;
      if (x & 0x200000000 > 0)
        result = result * 0x10000000162E42FF0999CE3541B9FFFCF >> 128;
      if (x & 0x100000000 > 0)
        result = result * 0x100000000B17217F80F4EF5AADDA45554 >> 128;
      if (x & 0x80000000 > 0)
        result = result * 0x10000000058B90BFBF8479BD5A81B51AD >> 128;
      if (x & 0x40000000 > 0)
        result = result * 0x1000000002C5C85FDF84BD62AE30A74CC >> 128;
      if (x & 0x20000000 > 0)
        result = result * 0x100000000162E42FEFB2FED257559BDAA >> 128;
      if (x & 0x10000000 > 0)
        result = result * 0x1000000000B17217F7D5A7716BBA4A9AE >> 128;
      if (x & 0x8000000 > 0)
        result = result * 0x100000000058B90BFBE9DDBAC5E109CCE >> 128;
      if (x & 0x4000000 > 0)
        result = result * 0x10000000002C5C85FDF4B15DE6F17EB0D >> 128;
      if (x & 0x2000000 > 0)
        result = result * 0x1000000000162E42FEFA494F1478FDE05 >> 128;
      if (x & 0x1000000 > 0)
        result = result * 0x10000000000B17217F7D20CF927C8E94C >> 128;
      if (x & 0x800000 > 0)
        result = result * 0x1000000000058B90BFBE8F71CB4E4B33D >> 128;
      if (x & 0x400000 > 0)
        result = result * 0x100000000002C5C85FDF477B662B26945 >> 128;
      if (x & 0x200000 > 0)
        result = result * 0x10000000000162E42FEFA3AE53369388C >> 128;
      if (x & 0x100000 > 0)
        result = result * 0x100000000000B17217F7D1D351A389D40 >> 128;
      if (x & 0x80000 > 0)
        result = result * 0x10000000000058B90BFBE8E8B2D3D4EDE >> 128;
      if (x & 0x40000 > 0)
        result = result * 0x1000000000002C5C85FDF4741BEA6E77E >> 128;
      if (x & 0x20000 > 0)
        result = result * 0x100000000000162E42FEFA39FE95583C2 >> 128;
      if (x & 0x10000 > 0)
        result = result * 0x1000000000000B17217F7D1CFB72B45E1 >> 128;
      if (x & 0x8000 > 0)
        result = result * 0x100000000000058B90BFBE8E7CC35C3F0 >> 128;
      if (x & 0x4000 > 0)
        result = result * 0x10000000000002C5C85FDF473E242EA38 >> 128;
      if (x & 0x2000 > 0)
        result = result * 0x1000000000000162E42FEFA39F02B772C >> 128;
      if (x & 0x1000 > 0)
        result = result * 0x10000000000000B17217F7D1CF7D83C1A >> 128;
      if (x & 0x800 > 0)
        result = result * 0x1000000000000058B90BFBE8E7BDCBE2E >> 128;
      if (x & 0x400 > 0)
        result = result * 0x100000000000002C5C85FDF473DEA871F >> 128;
      if (x & 0x200 > 0)
        result = result * 0x10000000000000162E42FEFA39EF44D91 >> 128;
      if (x & 0x100 > 0)
        result = result * 0x100000000000000B17217F7D1CF79E949 >> 128;
      if (x & 0x80 > 0)
        result = result * 0x10000000000000058B90BFBE8E7BCE544 >> 128;
      if (x & 0x40 > 0)
        result = result * 0x1000000000000002C5C85FDF473DE6ECA >> 128;
      if (x & 0x20 > 0)
        result = result * 0x100000000000000162E42FEFA39EF366F >> 128;
      if (x & 0x10 > 0)
        result = result * 0x1000000000000000B17217F7D1CF79AFA >> 128;
      if (x & 0x8 > 0)
        result = result * 0x100000000000000058B90BFBE8E7BCD6D >> 128;
      if (x & 0x4 > 0)
        result = result * 0x10000000000000002C5C85FDF473DE6B2 >> 128;
      if (x & 0x2 > 0)
        result = result * 0x1000000000000000162E42FEFA39EF358 >> 128;
      if (x & 0x1 > 0)
        result = result * 0x10000000000000000B17217F7D1CF79AB >> 128;

      result >>= uint256 (int256 (63 - (x >> 64)));
      require (result <= uint256 (int256 (MAX_64x64)));

      return int128 (int256 (result));
    }
  }

  /**
   * Calculate natural exponent of x.  Revert on overflow.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function exp (int128 x) internal pure returns (int128) {
    unchecked {
      require (x < 0x400000000000000000); // Overflow

      if (x < -0x400000000000000000) return 0; // Underflow

      return exp_2 (
          int128 (int256 (x) * 0x171547652B82FE1777D0FFDA0D23A7D12 >> 128));
    }
  }

  /**
   * Calculate x / y rounding towards zero, where x and y are unsigned 256-bit
   * integer numbers.  Revert on overflow or when y is zero.
   *
   * @param x unsigned 256-bit integer number
   * @param y unsigned 256-bit integer number
   * @return unsigned 64.64-bit fixed point number
   */
  function divuu (uint256 x, uint256 y) private pure returns (uint128) {
    unchecked {
      require (y != 0);

      uint256 result;

      if (x <= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        result = (x << 64) / y;
      else {
        uint256 msb = 192;
        uint256 xc = x >> 192;
        if (xc >= 0x100000000) { xc >>= 32; msb += 32; }
        if (xc >= 0x10000) { xc >>= 16; msb += 16; }
        if (xc >= 0x100) { xc >>= 8; msb += 8; }
        if (xc >= 0x10) { xc >>= 4; msb += 4; }
        if (xc >= 0x4) { xc >>= 2; msb += 2; }
        if (xc >= 0x2) msb += 1;  // No need to shift xc anymore

        result = (x << 255 - msb) / ((y - 1 >> msb - 191) + 1);
        require (result <= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

        uint256 hi = result * (y >> 128);
        uint256 lo = result * (y & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

        uint256 xh = x >> 192;
        uint256 xl = x << 64;

        if (xl < lo) xh -= 1;
        xl -= lo; // We rely on overflow behavior here
        lo = hi << 128;
        if (xl < lo) xh -= 1;
        xl -= lo; // We rely on overflow behavior here

        assert (xh == hi >> 128);

        result += xl / y;
      }

      require (result <= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
      return uint128 (result);
    }
  }

  /**
   * Calculate sqrt (x) rounding down, where x is unsigned 256-bit integer
   * number.
   *
   * @param x unsigned 256-bit integer number
   * @return unsigned 128-bit integer number
   */
  function sqrtu (uint256 x) private pure returns (uint128) {
    unchecked {
      if (x == 0) return 0;
      else {
        uint256 xx = x;
        uint256 r = 1;
        if (xx >= 0x100000000000000000000000000000000) { xx >>= 128; r <<= 64; }
        if (xx >= 0x10000000000000000) { xx >>= 64; r <<= 32; }
        if (xx >= 0x100000000) { xx >>= 32; r <<= 16; }
        if (xx >= 0x10000) { xx >>= 16; r <<= 8; }
        if (xx >= 0x100) { xx >>= 8; r <<= 4; }
        if (xx >= 0x10) { xx >>= 4; r <<= 2; }
        if (xx >= 0x4) { r <<= 1; }
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1; // Seven iterations should be enough
        uint256 r1 = x / r;
        return uint128 (r < r1 ? r : r1);
      }
    }
  }
}

// SPDX-License-Identifier: LGPL-3.0-or-later

pragma solidity ^0.8.0;

interface IProxyManager {
    function getPoolList() external view returns (address[] memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IOFTCore} from "./IOFTCore.sol";
import {ISolidStateERC20} from "@solidstate/contracts/token/ERC20/ISolidStateERC20.sol";

/**
 * @dev Interface of the OFT standard
 */
interface IOFT is IOFTCore, ISolidStateERC20 {
    error OFT_InsufficientAllowance();
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "@solidstate/contracts/interfaces/IERC20.sol";
import {IERC165} from "@solidstate/contracts/interfaces/IERC165.sol";

/**
 * @dev Interface of the IOFT core standard
 */
interface IOFTCore is IERC165 {
    /**
     * @dev estimate send token `tokenId` to (`dstChainId`, `toAddress`)
     * dstChainId - L0 defined chain id to send tokens too
     * toAddress - dynamic bytes array which contains the address to whom you are sending tokens to on the dstChain
     * amount - amount of the tokens to transfer
     * useZro - indicates to use zro to pay L0 fees
     * adapterParam - flexible bytes array to indicate messaging adapter services in L0
     */
    function estimateSendFee(
        uint16 dstChainId,
        bytes calldata toAddress,
        uint256 amount,
        bool useZro,
        bytes calldata adapterParams
    ) external view returns (uint256 nativeFee, uint256 zroFee);

    /**
     * @dev send `amount` amount of token to (`dstChainId`, `toAddress`) from `from`
     * `from` the owner of token
     * `dstChainId` the destination chain identifier
     * `toAddress` can be any size depending on the `dstChainId`.
     * `amount` the quantity of tokens in wei
     * `refundAddress` the address LayerZero refunds if too much message fee is sent
     * `zroPaymentAddress` set to address(0x0) if not paying in ZRO (LayerZero Token)
     * `adapterParams` is a flexible bytes array to indicate messaging adapter services
     */
    function sendFrom(
        address from,
        uint16 dstChainId,
        bytes calldata toAddress,
        uint256 amount,
        address payable refundAddress,
        address zroPaymentAddress,
        bytes calldata adapterParams
    ) external payable;

    /**
     * @dev returns the circulating amount of tokens on current chain
     */
    function circulatingSupply() external view returns (uint256);

    /**
     * @dev Emitted when `amount` tokens are moved from the `sender` to (`dstChainId`, `toAddress`)
     * `nonce` is the outbound nonce
     */
    event SendToChain(
        address indexed sender,
        uint16 indexed dstChainId,
        bytes indexed toAddress,
        uint256 amount
    );

    /**
     * @dev Emitted when `amount` tokens are received from `srcChainId` into the `toAddress` on the local chain.
     * `nonce` is the inbound nonce.
     */
    event ReceiveFromChain(
        uint16 indexed srcChainId,
        bytes indexed srcAddress,
        address indexed toAddress,
        uint256 amount
    );

    event SetUseCustomAdapterParams(bool _useCustomAdapterParams);
}

// SPDX-License-Identifier: BUSL-1.1
// For further clarification please see https://license.premia.legal

pragma solidity ^0.8.0;

import {ABDKMath64x64} from "abdk-libraries-solidity/ABDKMath64x64.sol";

library OptionMath {
    using ABDKMath64x64 for int128;

    struct QuoteArgs {
        int128 varianceAnnualized64x64; // 64x64 fixed point representation of annualized variance
        int128 strike64x64; // 64x64 fixed point representation of strike price
        int128 spot64x64; // 64x64 fixed point representation of spot price
        int128 timeToMaturity64x64; // 64x64 fixed point representation of duration of option contract (in years)
        int128 oldCLevel64x64; // 64x64 fixed point representation of C-Level of Pool before purchase
        int128 oldPoolState; // 64x64 fixed point representation of current state of the pool
        int128 newPoolState; // 64x64 fixed point representation of state of the pool after trade
        int128 steepness64x64; // 64x64 fixed point representation of Pool state delta multiplier
        int128 minAPY64x64; // 64x64 fixed point representation of minimum APY for capital locked up to underwrite options
        bool isCall; // whether to price "call" or "put" option
    }

    struct CalculateCLevelDecayArgs {
        int128 timeIntervalsElapsed64x64; // 64x64 fixed point representation of quantity of discrete arbitrary intervals elapsed since last update
        int128 oldCLevel64x64; // 64x64 fixed point representation of C-Level prior to accounting for decay
        int128 utilization64x64; // 64x64 fixed point representation of pool capital utilization rate
        int128 utilizationLowerBound64x64;
        int128 utilizationUpperBound64x64;
        int128 cLevelLowerBound64x64;
        int128 cLevelUpperBound64x64;
        int128 cConvergenceULowerBound64x64;
        int128 cConvergenceUUpperBound64x64;
    }

    // 64x64 fixed point integer constants
    int128 internal constant ONE_64x64 = 0x10000000000000000;
    int128 internal constant THREE_64x64 = 0x30000000000000000;

    // 64x64 fixed point constants used in Choudhury’s approximation of the Black-Scholes CDF
    int128 private constant CDF_CONST_0 = 0x09109f285df452394; // 2260 / 3989
    int128 private constant CDF_CONST_1 = 0x19abac0ea1da65036; // 6400 / 3989
    int128 private constant CDF_CONST_2 = 0x0d3c84b78b749bd6b; // 3300 / 3989

    /**
     * @notice recalculate C-Level based on change in liquidity
     * @param initialCLevel64x64 64x64 fixed point representation of C-Level of Pool before update
     * @param oldPoolState64x64 64x64 fixed point representation of liquidity in pool before update
     * @param newPoolState64x64 64x64 fixed point representation of liquidity in pool after update
     * @param steepness64x64 64x64 fixed point representation of steepness coefficient
     * @return 64x64 fixed point representation of new C-Level
     */
    function calculateCLevel(
        int128 initialCLevel64x64,
        int128 oldPoolState64x64,
        int128 newPoolState64x64,
        int128 steepness64x64
    ) external pure returns (int128) {
        return
            newPoolState64x64
                .sub(oldPoolState64x64)
                .div(
                    oldPoolState64x64 > newPoolState64x64
                        ? oldPoolState64x64
                        : newPoolState64x64
                )
                .mul(steepness64x64)
                .neg()
                .exp()
                .mul(initialCLevel64x64);
    }

    /**
     * @notice calculate the price of an option using the Premia Finance model
     * @param args arguments of quotePrice
     * @return premiaPrice64x64 64x64 fixed point representation of Premia option price
     * @return cLevel64x64 64x64 fixed point representation of C-Level of Pool after purchase
     */
    function quotePrice(
        QuoteArgs memory args
    )
        external
        pure
        returns (
            int128 premiaPrice64x64,
            int128 cLevel64x64,
            int128 slippageCoefficient64x64
        )
    {
        int128 deltaPoolState64x64 = args
            .newPoolState
            .sub(args.oldPoolState)
            .div(args.oldPoolState)
            .mul(args.steepness64x64);
        int128 tradingDelta64x64 = deltaPoolState64x64.neg().exp();

        int128 blackScholesPrice64x64 = _blackScholesPrice(
            args.varianceAnnualized64x64,
            args.strike64x64,
            args.spot64x64,
            args.timeToMaturity64x64,
            args.isCall
        );

        cLevel64x64 = tradingDelta64x64.mul(args.oldCLevel64x64);
        slippageCoefficient64x64 = ONE_64x64.sub(tradingDelta64x64).div(
            deltaPoolState64x64
        );

        premiaPrice64x64 = blackScholesPrice64x64.mul(cLevel64x64).mul(
            slippageCoefficient64x64
        );

        int128 intrinsicValue64x64;

        if (args.isCall && args.strike64x64 < args.spot64x64) {
            intrinsicValue64x64 = args.spot64x64.sub(args.strike64x64);
        } else if (!args.isCall && args.strike64x64 > args.spot64x64) {
            intrinsicValue64x64 = args.strike64x64.sub(args.spot64x64);
        }

        int128 collateralValue64x64 = args.isCall
            ? args.spot64x64
            : args.strike64x64;

        int128 minPrice64x64 = intrinsicValue64x64.add(
            collateralValue64x64.mul(args.minAPY64x64).mul(
                args.timeToMaturity64x64
            )
        );

        if (minPrice64x64 > premiaPrice64x64) {
            premiaPrice64x64 = minPrice64x64;
        }
    }

    /**
     * @notice calculate the decay of C-Level based on heat diffusion function
     * @param args structured CalculateCLevelDecayArgs
     * @return cLevelDecayed64x64 C-Level after accounting for decay
     */
    function calculateCLevelDecay(
        CalculateCLevelDecayArgs memory args
    ) external pure returns (int128 cLevelDecayed64x64) {
        int128 convFHighU64x64 = (args.utilization64x64 >=
            args.utilizationUpperBound64x64 &&
            args.oldCLevel64x64 <= args.cLevelLowerBound64x64)
            ? ONE_64x64
            : int128(0);

        int128 convFLowU64x64 = (args.utilization64x64 <=
            args.utilizationLowerBound64x64 &&
            args.oldCLevel64x64 >= args.cLevelUpperBound64x64)
            ? ONE_64x64
            : int128(0);

        cLevelDecayed64x64 = args
            .oldCLevel64x64
            .sub(args.cConvergenceULowerBound64x64.mul(convFLowU64x64))
            .sub(args.cConvergenceUUpperBound64x64.mul(convFHighU64x64))
            .mul(
                convFLowU64x64
                    .mul(ONE_64x64.sub(args.utilization64x64))
                    .add(convFHighU64x64.mul(args.utilization64x64))
                    .mul(args.timeIntervalsElapsed64x64)
                    .neg()
                    .exp()
            )
            .add(
                args.cConvergenceULowerBound64x64.mul(convFLowU64x64).add(
                    args.cConvergenceUUpperBound64x64.mul(convFHighU64x64)
                )
            );
    }

    /**
     * @notice calculate the exponential decay coefficient for a given interval
     * @param oldTimestamp timestamp of previous update
     * @param newTimestamp current timestamp
     * @return 64x64 fixed point representation of exponential decay coefficient
     */
    function _decay(
        uint256 oldTimestamp,
        uint256 newTimestamp
    ) internal pure returns (int128) {
        return
            ONE_64x64.sub(
                (-ABDKMath64x64.divu(newTimestamp - oldTimestamp, 7 days)).exp()
            );
    }

    /**
     * @notice calculate Choudhury’s approximation of the Black-Scholes CDF
     * @param input64x64 64x64 fixed point representation of random variable
     * @return 64x64 fixed point representation of the approximated CDF of x
     */
    function _N(int128 input64x64) internal pure returns (int128) {
        // squaring via mul is cheaper than via pow
        int128 inputSquared64x64 = input64x64.mul(input64x64);

        int128 value64x64 = (-inputSquared64x64 >> 1).exp().div(
            CDF_CONST_0.add(CDF_CONST_1.mul(input64x64.abs())).add(
                CDF_CONST_2.mul(inputSquared64x64.add(THREE_64x64).sqrt())
            )
        );

        return input64x64 > 0 ? ONE_64x64.sub(value64x64) : value64x64;
    }

    /**
     * @notice calculate the price of an option using the Black-Scholes model
     * @param varianceAnnualized64x64 64x64 fixed point representation of annualized variance
     * @param strike64x64 64x64 fixed point representation of strike price
     * @param spot64x64 64x64 fixed point representation of spot price
     * @param timeToMaturity64x64 64x64 fixed point representation of duration of option contract (in years)
     * @param isCall whether to price "call" or "put" option
     * @return 64x64 fixed point representation of Black-Scholes option price
     */
    function _blackScholesPrice(
        int128 varianceAnnualized64x64,
        int128 strike64x64,
        int128 spot64x64,
        int128 timeToMaturity64x64,
        bool isCall
    ) internal pure returns (int128) {
        int128 cumulativeVariance64x64 = timeToMaturity64x64.mul(
            varianceAnnualized64x64
        );
        int128 cumulativeVarianceSqrt64x64 = cumulativeVariance64x64.sqrt();

        int128 d1_64x64 = spot64x64
            .div(strike64x64)
            .ln()
            .add(cumulativeVariance64x64 >> 1)
            .div(cumulativeVarianceSqrt64x64);
        int128 d2_64x64 = d1_64x64.sub(cumulativeVarianceSqrt64x64);

        if (isCall) {
            return
                spot64x64.mul(_N(d1_64x64)).sub(strike64x64.mul(_N(d2_64x64)));
        } else {
            return
                -spot64x64.mul(_N(-d1_64x64)).sub(
                    strike64x64.mul(_N(-d2_64x64))
                );
        }
    }
}

// SPDX-License-Identifier: LGPL-3.0-or-later

pragma solidity ^0.8.0;

import {PremiaMiningStorage} from "./PremiaMiningStorage.sol";

interface IPremiaMining {
    struct PoolAllocPoints {
        address pool;
        bool isCallPool;
        uint256 votes;
        uint256 poolUtilizationRateBPS; // 100% = 1e4
    }

    event Claim(
        address indexed user,
        address indexed pool,
        bool indexed isCallPool,
        uint256 rewardAmount
    );

    event UpdatePoolAlloc(
        address indexed pool,
        bool indexed isCallPool,
        uint256 votes,
        uint256 poolUtilizationRateBPS
    );

    function addPremiaRewards(uint256 _amount) external;

    function premiaRewardsAvailable() external view returns (uint256);

    function getTotalAllocationPoints() external view returns (uint256);

    function getPoolInfo(
        address pool,
        bool isCallPool
    ) external view returns (PremiaMiningStorage.PoolInfo memory);

    function getPremiaPerYear() external view returns (uint256);

    function pendingPremia(
        address _pool,
        bool _isCallPool,
        address _user
    ) external view returns (uint256);

    function updatePool(
        address _pool,
        bool _isCallPool,
        uint256 _totalTVL,
        uint256 _utilizationRate
    ) external;

    function allocatePending(
        address _user,
        address _pool,
        bool _isCallPool,
        uint256 _userTVLOld,
        uint256 _userTVLNew,
        uint256 _totalTVL,
        uint256 _utilizationRate
    ) external;

    function claim(
        address _user,
        address _pool,
        bool _isCallPool,
        uint256 _userTVLOld,
        uint256 _userTVLNew,
        uint256 _totalTVL,
        uint256 _utilizationRate
    ) external;
}

// SPDX-License-Identifier: BUSL-1.1
// For further clarification please see https://license.premia.legal

pragma solidity ^0.8.0;

import {OwnableInternal, OwnableStorage} from "@solidstate/contracts/access/ownable/OwnableInternal.sol";
import {IERC20} from "@solidstate/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@solidstate/contracts/utils/SafeERC20.sol";

import {PremiaMiningStorage} from "./PremiaMiningStorage.sol";
import {IPremiaMining} from "./IPremiaMining.sol";
import {IPoolIO} from "../pool/IPoolIO.sol";
import {IPoolView} from "../pool/IPoolView.sol";
import {IVxPremia} from "../staking/IVxPremia.sol";
import {VxPremiaStorage} from "../staking/VxPremiaStorage.sol";
import {IProxyManager} from "../core/IProxyManager.sol";

/**
 * @title Premia liquidity mining contract, derived from Sushiswap's MasterChef.sol ( https://github.com/sushiswap/sushiswap )
 */
contract PremiaMining is IPremiaMining, OwnableInternal {
    using PremiaMiningStorage for PremiaMiningStorage.Layout;
    using SafeERC20 for IERC20;

    address internal immutable PROXY_MANAGER;
    address internal immutable PREMIA;
    address internal immutable VX_PREMIA;

    uint256 private constant ONE_YEAR = 365 days;
    uint256 private constant INVERSE_BASIS_POINT = 1e4;
    uint256 private constant MIN_POINT_MULTIPLIER = 2500; // 25% -> If utilization rate is less than this value, we use this value instead

    constructor(address _proxyManager, address _premia, address _vxPremia) {
        PROXY_MANAGER = _proxyManager;
        PREMIA = _premia;
        VX_PREMIA = _vxPremia;
    }

    modifier onlyPool(address _pool) {
        _validatePool(_pool);
        _;
    }

    /**
     * @notice validate that pool is registered on the proxy manager and is the message sender
     * @param _pool pool to validate
     */
    function _validatePool(address _pool) private {
        require(msg.sender == _pool, "Not pool");

        PremiaMiningStorage.Layout storage l = PremiaMiningStorage.layout();

        if (l.pools[_pool]) return;

        address[] memory poolList = IProxyManager(PROXY_MANAGER).getPoolList();

        for (uint256 i = 0; i < poolList.length; i++) {
            l.pools[poolList[i]] = true;
        }

        require(l.pools[_pool], "Not pool");
    }

    /**
     * @notice Add premia rewards to distribute. Can only be called by the owner
     * @param _amount Amount of premia to add
     */
    function addPremiaRewards(uint256 _amount) external onlyOwner {
        PremiaMiningStorage.Layout storage l = PremiaMiningStorage.layout();
        IERC20(PREMIA).safeTransferFrom(msg.sender, address(this), _amount);
        l.premiaAvailable += _amount;
    }

    /**
     * @notice Get amount of premia reward available to distribute
     * @return Amount of premia reward available to distribute
     */
    function premiaRewardsAvailable() external view returns (uint256) {
        return PremiaMiningStorage.layout().premiaAvailable;
    }

    /**
     * @notice Get the total allocation points
     * @return Total allocation points
     */
    function getTotalAllocationPoints() external view returns (uint256) {
        return PremiaMiningStorage.layout().totalAllocPoint;
    }

    /**
     * @notice Get pool info
     * @param pool address of the pool
     * @param isCallPool whether we want infos of the CALL pool or the PUT pool
     * @return Pool info
     */
    function getPoolInfo(
        address pool,
        bool isCallPool
    ) external view returns (PremiaMiningStorage.PoolInfo memory) {
        return PremiaMiningStorage.layout().poolInfo[pool][isCallPool];
    }

    /**
     * @notice Get the amount of premia emitted per year
     * @return Premia emitted per year
     */
    function getPremiaPerYear() external view returns (uint256) {
        return PremiaMiningStorage.layout().premiaPerYear;
    }

    /**
     * @notice Set new alloc points for an option pool. Can only be called by the owner.
     * @param _premiaPerYear Amount of PREMIA per year to allocate as reward across all pools
     */
    function setPremiaPerYear(uint256 _premiaPerYear) external onlyOwner {
        PremiaMiningStorage.layout().premiaPerYear = _premiaPerYear;
    }

    function _setPoolAllocPoints(
        PremiaMiningStorage.Layout storage l,
        IPremiaMining.PoolAllocPoints memory _data
    ) internal {
        if (_data.poolUtilizationRateBPS < MIN_POINT_MULTIPLIER) {
            _data.poolUtilizationRateBPS = MIN_POINT_MULTIPLIER;
        }

        uint256 allocPoints = (_data.votes * _data.poolUtilizationRateBPS) /
            INVERSE_BASIS_POINT;

        l.totalAllocPoint =
            l.totalAllocPoint -
            l.poolInfo[_data.pool][_data.isCallPool].allocPoint +
            allocPoints;
        l.poolInfo[_data.pool][_data.isCallPool].allocPoint = allocPoints;

        // If alloc points set for a new pool, we initialize the last reward timestamp
        if (l.poolInfo[_data.pool][_data.isCallPool].lastRewardTimestamp == 0) {
            l.poolInfo[_data.pool][_data.isCallPool].lastRewardTimestamp = block
                .timestamp;
        }

        emit UpdatePoolAlloc(
            _data.pool,
            _data.isCallPool,
            _data.votes,
            _data.poolUtilizationRateBPS
        );
    }

    /**
     * @notice Get pending premia reward for a user on a pool
     * @param _pool Address of option pool contract
     * @param _isCallPool True if for call option pool, False if for put option pool
     */
    function pendingPremia(
        address _pool,
        bool _isCallPool,
        address _user
    ) external view returns (uint256) {
        uint256 TVL;
        uint256 userTVL;

        {
            (uint256 underlyingTVL, uint256 baseTVL) = IPoolView(_pool)
                .getTotalTVL();
            TVL = _isCallPool ? underlyingTVL : baseTVL;
        }

        {
            (uint256 userUnderlyingTVL, uint256 userBaseTVL) = IPoolView(_pool)
                .getUserTVL(_user);
            userTVL = _isCallPool ? userUnderlyingTVL : userBaseTVL;
        }

        PremiaMiningStorage.Layout storage l = PremiaMiningStorage.layout();
        PremiaMiningStorage.PoolInfo storage pool = l.poolInfo[_pool][
            _isCallPool
        ];

        PremiaMiningStorage.UserInfo storage user = l.userInfo[_pool][
            _isCallPool
        ][_user];
        uint256 accPremiaPerShare = pool.accPremiaPerShare;

        if (
            block.timestamp > pool.lastRewardTimestamp &&
            TVL > 0 &&
            pool.allocPoint > 0
        ) {
            uint256 premiaReward = (((block.timestamp -
                pool.lastRewardTimestamp) * l.premiaPerYear) *
                pool.allocPoint) /
                l.totalAllocPoint /
                ONE_YEAR;

            // If we are running out of rewards to distribute, distribute whats left
            if (premiaReward > l.premiaAvailable) {
                premiaReward = l.premiaAvailable;
            }

            accPremiaPerShare += (premiaReward * 1e12) / TVL;
        }
        return
            ((userTVL * accPremiaPerShare) / 1e12) -
            user.rewardDebt +
            user.reward;
    }

    /**
     * @notice Update reward variables of the given pool to be up-to-date. Only callable by the option pool
     * @param _pool Address of option pool contract
     * @param _isCallPool True if for call option pool, False if for put option pool
     * @param _totalTVL Total amount of tokens deposited in the option pool
     * @param _utilizationRate Utilization rate of the pool (1e4 = 100%)
     */
    function updatePool(
        address _pool,
        bool _isCallPool,
        uint256 _totalTVL,
        uint256 _utilizationRate
    ) external onlyPool(_pool) {
        _updatePool(_pool, _isCallPool, _totalTVL, _utilizationRate);
    }

    /**
     * @notice Update reward variables of the given pool to be up-to-date. Only callable by the option pool
     * @param _pool Address of option pool contract
     * @param _isCallPool True if for call option pool, False if for put option pool
     * @param _totalTVL Total amount of tokens deposited in the option pool
     * @param _utilizationRate Utilization rate of the pool (1e4 = 100%)
     */
    function _updatePool(
        address _pool,
        bool _isCallPool,
        uint256 _totalTVL,
        uint256 _utilizationRate
    ) internal {
        PremiaMiningStorage.Layout storage l = PremiaMiningStorage.layout();

        PremiaMiningStorage.PoolInfo storage pool = l.poolInfo[_pool][
            _isCallPool
        ];

        if (block.timestamp <= pool.lastRewardTimestamp) {
            return;
        }

        if (_totalTVL > 0 && pool.allocPoint > 0) {
            uint256 premiaReward = (((block.timestamp -
                pool.lastRewardTimestamp) * l.premiaPerYear) *
                pool.allocPoint) /
                l.totalAllocPoint /
                ONE_YEAR;

            // If we are running out of rewards to distribute, distribute whats left
            if (premiaReward > l.premiaAvailable) {
                premiaReward = l.premiaAvailable;
            }

            l.premiaAvailable -= premiaReward;
            pool.accPremiaPerShare += (premiaReward * 1e12) / _totalTVL;
        }

        pool.lastRewardTimestamp = block.timestamp;

        _updatePoolAllocPoints(l, _pool, _isCallPool, _utilizationRate);
    }

    function _updatePoolAllocPoints(
        PremiaMiningStorage.Layout storage l,
        address pool,
        bool isCallPool,
        uint256 utilizationRate
    ) internal virtual {
        uint256 votes = IVxPremia(VX_PREMIA).getPoolVotes(
            VxPremiaStorage.VoteVersion.V2,
            abi.encodePacked(pool, isCallPool)
        );
        _setPoolAllocPoints(
            l,
            IPremiaMining.PoolAllocPoints(
                pool,
                isCallPool,
                votes,
                utilizationRate
            )
        );
    }

    /**
     * @notice Allocate pending rewards to a user. Only callable by the option pool
     * @param _user User for whom allocate the rewards
     * @param _pool Address of option pool contract
     * @param _isCallPool True if for call option pool, False if for put option pool
     * @param _userTVLOld Total amount of tokens deposited in the option pool by user before the allocation update
     * @param _userTVLNew Total amount of tokens deposited in the option pool by user after the allocation update
     * @param _totalTVL Total amount of tokens deposited in the option pool
     * @param _utilizationRate Utilization rate of the pool (1e4 = 100%)
     */
    function allocatePending(
        address _user,
        address _pool,
        bool _isCallPool,
        uint256 _userTVLOld,
        uint256 _userTVLNew,
        uint256 _totalTVL,
        uint256 _utilizationRate
    ) external onlyPool(_pool) {
        _allocatePending(
            _user,
            _pool,
            _isCallPool,
            _userTVLOld,
            _userTVLNew,
            _totalTVL,
            _utilizationRate
        );
    }

    /**
     * @notice Allocate pending rewards to a user. Only callable by the option pool
     * @param _user User for whom allocate the rewards
     * @param _pool Address of option pool contract
     * @param _isCallPool True if for call option pool, False if for put option pool
     * @param _userTVLOld Total amount of tokens deposited in the option pool by user before the allocation update
     * @param _userTVLNew Total amount of tokens deposited in the option pool by user after the allocation update
     * @param _totalTVL Total amount of tokens deposited in the option pool
     * @param _utilizationRate Utilization rate of the pool (1e4 = 100%)
     */
    function _allocatePending(
        address _user,
        address _pool,
        bool _isCallPool,
        uint256 _userTVLOld,
        uint256 _userTVLNew,
        uint256 _totalTVL,
        uint256 _utilizationRate
    ) internal {
        PremiaMiningStorage.Layout storage l = PremiaMiningStorage.layout();
        PremiaMiningStorage.PoolInfo storage pool = l.poolInfo[_pool][
            _isCallPool
        ];
        PremiaMiningStorage.UserInfo storage user = l.userInfo[_pool][
            _isCallPool
        ][_user];

        _updatePool(_pool, _isCallPool, _totalTVL, _utilizationRate);

        user.reward +=
            ((_userTVLOld * pool.accPremiaPerShare) / 1e12) -
            user.rewardDebt;

        user.rewardDebt = (_userTVLNew * pool.accPremiaPerShare) / 1e12;
    }

    /**
     * @notice Update user reward allocation + claim allocated PREMIA reward. Only callable by the option pool
     * @param _user User claiming the rewards
     * @param _pool Address of option pool contract
     * @param _isCallPool True if for call option pool, False if for put option pool
     * @param _userTVLOld Total amount of tokens deposited in the option pool by user before the allocation update
     * @param _userTVLNew Total amount of tokens deposited in the option pool by user after the allocation update
     * @param _totalTVL Total amount of tokens deposited in the option pool
     * @param _utilizationRate Utilization rate of the pool (1e4 = 100%)
     */
    function claim(
        address _user,
        address _pool,
        bool _isCallPool,
        uint256 _userTVLOld,
        uint256 _userTVLNew,
        uint256 _totalTVL,
        uint256 _utilizationRate
    ) external onlyPool(_pool) {
        PremiaMiningStorage.Layout storage l = PremiaMiningStorage.layout();

        _allocatePending(
            _user,
            _pool,
            _isCallPool,
            _userTVLOld,
            _userTVLNew,
            _totalTVL,
            _utilizationRate
        );

        uint256 reward = l.userInfo[_pool][_isCallPool][_user].reward;
        l.userInfo[_pool][_isCallPool][_user].reward = 0;
        _safePremiaTransfer(_user, reward);

        emit Claim(_user, _pool, _isCallPool, reward);
    }

    /**
     * @notice Trigger reward distribution by multiple pools
     * @param account address whose rewards to claim
     * @param pools list of pools to call
     * @param isCall list of bools indicating whether each pool is call pool
     */
    function multiClaim(
        address account,
        address[] calldata pools,
        bool[] calldata isCall
    ) external {
        require(pools.length == isCall.length);

        for (uint256 i; i < pools.length; i++) {
            IPoolIO(pools[i]).claimRewards(account, isCall[i]);
        }
    }

    /**
     * @notice Safe premia transfer function, just in case if rounding error causes pool to not have enough PREMIA.
     * @param _to Address where to transfer the Premia
     * @param _amount Amount of tokens to transfer
     */
    function _safePremiaTransfer(address _to, uint256 _amount) internal {
        IERC20 premia = IERC20(PREMIA);

        uint256 premiaBal = premia.balanceOf(address(this));
        if (_amount > premiaBal) {
            premia.safeTransfer(_to, premiaBal);
        } else {
            premia.safeTransfer(_to, _amount);
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1
// For further clarification please see https://license.premia.legal

pragma solidity ^0.8.0;

library PremiaMiningStorage {
    bytes32 internal constant STORAGE_SLOT =
        keccak256("premia.contracts.storage.PremiaMining");

    // Info of each pool.
    struct PoolInfo {
        uint256 allocPoint; // How many allocation points assigned to this pool. PREMIA to distribute per block.
        uint256 lastRewardTimestamp; // Last timestamp that PREMIA distribution occurs
        uint256 accPremiaPerShare; // Accumulated PREMIA per share, times 1e12. See below.
    }

    // Info of each user.
    struct UserInfo {
        uint256 reward; // Total allocated unclaimed reward
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of PREMIA
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accPremiaPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accPremiaPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    struct Layout {
        // Total PREMIA left to distribute
        uint256 premiaAvailable;
        // Amount of premia distributed per year
        uint256 premiaPerYear;
        // pool -> isCallPool -> PoolInfo
        mapping(address => mapping(bool => PoolInfo)) poolInfo;
        // pool -> isCallPool -> user -> UserInfo
        mapping(address => mapping(bool => mapping(address => UserInfo))) userInfo;
        // Total allocation points. Must be the sum of all allocation points in all pools.
        uint256 totalAllocPoint;
        // pool -> whether pool is valid
        mapping(address => bool) pools;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

// SPDX-License-Identifier: LGPL-3.0-or-later

pragma solidity ^0.8.0;

interface IPoolInternal {
    struct SwapArgs {
        // token to pass in to swap
        address tokenIn;
        // amount of tokenIn to trade
        uint256 amountInMax;
        //min amount out to be used to purchase
        uint256 amountOutMin;
        // exchange address to call to execute the trade
        address callee;
        // address for which to set allowance for the trade
        address allowanceTarget;
        // data to execute the trade
        bytes data;
        // address to which refund excess tokens
        address refundAddress;
    }
}

// SPDX-License-Identifier: LGPL-3.0-or-later

pragma solidity ^0.8.0;

import {IPoolInternal} from "./IPoolInternal.sol";

/**
 * @notice Pool interface for LP position and platform fee management functions
 */
interface IPoolIO {
    /**
     * @notice set timestamp after which reinvestment is disabled
     * @param timestamp timestamp to begin divestment
     * @param isCallPool whether we set divestment timestamp for the call pool or put pool
     */
    function setDivestmentTimestamp(uint64 timestamp, bool isCallPool) external;

    /**
     * @notice deposit underlying currency, underwriting calls of that currency with respect to base currency
     * @param amount quantity of underlying currency to deposit
     * @param isCallPool whether to deposit underlying in the call pool or base in the put pool
     */
    function deposit(uint256 amount, bool isCallPool) external payable;

    /**
     * @notice  swap any token to collateral asset through exchange proxy and deposit
     * @dev     any attached msg.value will be wrapped.
     *          if tokenIn is wrappedNativeToken, both msg.value and {amountInMax} amount of wrappedNativeToken will be used
     * @param s swap arguments
     * @param isCallPool whether to deposit underlying in the call pool or base in the put pool
     */
    function swapAndDeposit(
        IPoolInternal.SwapArgs memory s,
        bool isCallPool
    ) external payable;

    /**
     * @notice redeem pool share tokens for underlying asset
     * @param amount quantity of share tokens to redeem
     * @param isCallPool whether to deposit underlying in the call pool or base in the put pool
     */
    function withdraw(uint256 amount, bool isCallPool) external;

    /**
     * @notice reassign short position to new underwriter
     * @param tokenId ERC1155 token id (long or short)
     * @param contractSize quantity of option contract tokens to reassign
     * @param divest whether to withdraw freed funds after reassignment
     * @return baseCost quantity of tokens required to reassign short position
     * @return feeCost quantity of tokens required to pay fees
     * @return amountOut quantity of liquidity freed and transferred to owner
     */
    function reassign(
        uint256 tokenId,
        uint256 contractSize,
        bool divest
    ) external returns (uint256 baseCost, uint256 feeCost, uint256 amountOut);

    /**
     * @notice reassign set of short position to new underwriter
     * @param tokenIds array of ERC1155 token ids (long or short)
     * @param contractSizes array of quantities of option contract tokens to reassign
     * @param divest whether to withdraw freed funds after reassignment
     * @return baseCosts quantities of tokens required to reassign each short position
     * @return feeCosts quantities of tokens required to pay fees
     * @return amountOutCall quantity of call pool liquidity freed and transferred to owner
     * @return amountOutPut quantity of put pool liquidity freed and transferred to owner
     */
    function reassignBatch(
        uint256[] calldata tokenIds,
        uint256[] calldata contractSizes,
        bool divest
    )
        external
        returns (
            uint256[] memory baseCosts,
            uint256[] memory feeCosts,
            uint256 amountOutCall,
            uint256 amountOutPut
        );

    /**
     * @notice transfer accumulated fees to the fee receiver
     * @return amountOutCall quantity of underlying tokens transferred
     * @return amountOutPut quantity of base tokens transferred
     */
    function withdrawFees()
        external
        returns (uint256 amountOutCall, uint256 amountOutPut);

    /**
     * @notice burn corresponding long and short option tokens and withdraw collateral
     * @param tokenId ERC1155 token id (long or short)
     * @param contractSize quantity of option contract tokens to annihilate
     * @param divest whether to withdraw freed funds after annihilation
     */
    function annihilate(
        uint256 tokenId,
        uint256 contractSize,
        bool divest
    ) external;

    /**
     * @notice claim earned PREMIA emissions
     * @param isCallPool true for call, false for put
     */
    function claimRewards(bool isCallPool) external;

    /**
     * @notice claim earned PREMIA emissions on behalf of given account
     * @param account account on whose behalf to claim rewards
     * @param isCallPool true for call, false for put
     */
    function claimRewards(address account, bool isCallPool) external;

    /**
     * @notice TODO
     */
    function updateMiningPools() external;
}

// SPDX-License-Identifier: LGPL-3.0-or-later

pragma solidity ^0.8.0;

import {IERC1155Metadata} from "@solidstate/contracts/token/ERC1155/metadata/IERC1155Metadata.sol";

import {PoolStorage} from "./PoolStorage.sol";

/**
 * @notice Pool view function interface
 */
interface IPoolView is IERC1155Metadata {
    /**
     * @notice get fee receiver address
     * @dev called by PremiaMakerKeeper
     * @return fee receiver address
     */
    function getFeeReceiverAddress() external view returns (address);

    /**
     * @notice get fundamental pool attributes
     * @return structured PoolSettings
     */
    function getPoolSettings()
        external
        view
        returns (PoolStorage.PoolSettings memory);

    /**
     * @notice get the list of all token ids in circulation
     * @return list of token ids
     */
    function getTokenIds() external view returns (uint256[] memory);

    /**
     * @notice get current C-Level, accounting for unrealized decay and pending deposits
     * @param isCall whether query is for call or put pool
     * @return cLevel64x64 64x64 fixed point representation of C-Level
     */
    function getCLevel64x64(bool isCall) external view returns (int128);

    /**
     * @notice get pool APY fee
     * @return 64x64 fixed point representation of APY fee
     */
    function getApyFee64x64() external view returns (int128);

    /**
     * @notice get steepness coefficient
     * @param isCall whether query is for call or put pool
     * @return 64x64 fixed point representation of C steepness of Pool
     */
    function getSteepness64x64(bool isCall) external view returns (int128);

    /**
     * @notice get oracle price at timestamp
     * @param timestamp timestamp to query
     * @return 64x64 fixed point representation of price
     */
    function getPrice64x64(uint256 timestamp) external view returns (int128);

    /**
     * @notice get first oracle price update after timestamp. If no update has been registered yet, return current price feed spot price
     * @param timestamp timestamp to query
     * @return spot64x64 64x64 fixed point representation of price
     */
    function getPriceAfter64x64(
        uint256 timestamp
    ) external view returns (int128 spot64x64);

    /**
     * @notice get parameters for token id
     * @param tokenId token id to query
     * @return token type enum
     * @return maturity
     * @return 64x64 fixed point representation of strike price
     */
    function getParametersForTokenId(
        uint256 tokenId
    ) external pure returns (PoolStorage.TokenType, uint64, int128);

    /**
     * @notice get minimum purchase and interval amounts
     * @return minCallTokenAmount minimum call pool amount
     * @return minPutTokenAmount minimum put pool amount
     */
    function getMinimumAmounts()
        external
        view
        returns (uint256 minCallTokenAmount, uint256 minPutTokenAmount);

    /**
     * @notice get TVL (total value locked) for given address
     * @param account address whose TVL to query
     * @return underlyingTVL user total value locked in call pool (in underlying token amount)
     * @return baseTVL user total value locked in put pool (in base token amount)
     */
    function getUserTVL(
        address account
    ) external view returns (uint256 underlyingTVL, uint256 baseTVL);

    /**
     * @notice get TVL (total value locked) of entire Pool
     * @return underlyingTVL total value locked in call pool (in underlying token amount)
     * @return baseTVL total value locked in put pool (in base token amount)
     */
    function getTotalTVL()
        external
        view
        returns (uint256 underlyingTVL, uint256 baseTVL);

    /**
     * @notice get position in the liquidity queue of the Pool
     * @param account account address whose liquidity position to query
     * @param isCallPool whether query is for call or put pool
     * @return liquidityBeforePosition total available liquidity before account's liquidity queue
     * @return positionSize size of the account's liquidity queue position
     */
    function getLiquidityQueuePosition(
        address account,
        bool isCallPool
    )
        external
        view
        returns (uint256 liquidityBeforePosition, uint256 positionSize);

    /**
     * @notice get the amount of APY fees reserved for given user and token id
     * @param account account whose reserved fees to query
     * @param shortTokenId short token id whose reserved fees to query
     * @return amount quantity of fees reserved
     */
    function getFeesReserved(
        address account,
        uint256 shortTokenId
    ) external view returns (uint256 amount);

    /**
     * @notice get the address of PremiaMining contract
     * @return address of PremiaMining contract
     */
    function getPremiaMining() external view returns (address);

    /**
     * @notice get the gradual divestment timestamps of a user
     * @param account address whose divestment timestamps to query
     * @return callDivestmentTimestamp gradual divestment timestamp of the user for the call pool
     * @return putDivestmentTimestamp gradual divestment timestamp of the user for the put pool
     */
    function getDivestmentTimestamps(
        address account
    )
        external
        view
        returns (
            uint256 callDivestmentTimestamp,
            uint256 putDivestmentTimestamp
        );

    /**
     * @notice get the spot price offset used to account for price feed lag
     * @return spotOffset64x64 64x64 fixed point representation of spot price offset
     */
    function getSpotOffset64x64()
        external
        view
        returns (int128 spotOffset64x64);

    /**
     * @notice get the exchange helper address
     * @return exchangeHelper exchange helper address
     */
    function getExchangeHelper() external view returns (address exchangeHelper);
}

// SPDX-License-Identifier: BUSL-1.1
// For further clarification please see https://license.premia.legal

pragma solidity ^0.8.0;

import {AggregatorInterface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorInterface.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {ABDKMath64x64Token} from "@solidstate/abdk-math-extensions/contracts/ABDKMath64x64Token.sol";
import {EnumerableSet, ERC1155EnumerableStorage} from "@solidstate/contracts/token/ERC1155/enumerable/ERC1155EnumerableStorage.sol";
import {ABDKMath64x64} from "abdk-libraries-solidity/ABDKMath64x64.sol";

import {OptionMath} from "../libraries/OptionMath.sol";

library PoolStorage {
    using ABDKMath64x64 for int128;
    using PoolStorage for PoolStorage.Layout;

    enum TokenType {
        UNDERLYING_FREE_LIQ,
        BASE_FREE_LIQ,
        UNDERLYING_RESERVED_LIQ,
        BASE_RESERVED_LIQ,
        LONG_CALL,
        SHORT_CALL,
        LONG_PUT,
        SHORT_PUT
    }

    struct PoolSettings {
        address underlying;
        address base;
        address underlyingOracle;
        address baseOracle;
    }

    struct QuoteArgsInternal {
        address feePayer; // address of the fee payer
        uint64 maturity; // timestamp of option maturity
        int128 strike64x64; // 64x64 fixed point representation of strike price
        int128 spot64x64; // 64x64 fixed point representation of spot price
        uint256 contractSize; // size of option contract
        bool isCall; // true for call, false for put
    }

    struct QuoteResultInternal {
        int128 baseCost64x64; // 64x64 fixed point representation of option cost denominated in underlying currency (without fee)
        int128 feeCost64x64; // 64x64 fixed point representation of option fee cost denominated in underlying currency for call, or base currency for put
        int128 cLevel64x64; // 64x64 fixed point representation of C-Level of Pool after purchase
        int128 slippageCoefficient64x64; // 64x64 fixed point representation of slippage coefficient for given order size
    }

    struct BatchData {
        uint256 eta;
        uint256 totalPendingDeposits;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("premia.contracts.storage.Pool");

    uint256 private constant C_DECAY_BUFFER = 12 hours;
    uint256 private constant C_DECAY_INTERVAL = 4 hours;

    int128 internal constant ONE_64x64 = 0x10000000000000000;

    struct Layout {
        // ERC20 token addresses
        address base;
        address underlying;
        // AggregatorV3Interface oracle addresses
        address baseOracle;
        address underlyingOracle;
        // token metadata
        uint8 underlyingDecimals;
        uint8 baseDecimals;
        // minimum amounts
        uint256 baseMinimum;
        uint256 underlyingMinimum;
        // deposit caps
        uint256 _deprecated_basePoolCap;
        uint256 _deprecated_underlyingPoolCap;
        // market state
        int128 _deprecated_steepness64x64;
        int128 cLevelBase64x64;
        int128 cLevelUnderlying64x64;
        uint256 cLevelBaseUpdatedAt;
        uint256 cLevelUnderlyingUpdatedAt;
        uint256 updatedAt;
        // User -> isCall -> depositedAt
        mapping(address => mapping(bool => uint256)) depositedAt;
        mapping(address => mapping(bool => uint256)) divestmentTimestamps;
        // doubly linked list of free liquidity intervals
        // isCall -> User -> User
        mapping(bool => mapping(address => address)) liquidityQueueAscending;
        mapping(bool => mapping(address => address)) liquidityQueueDescending;
        // minimum resolution price bucket => price
        mapping(uint256 => int128) bucketPrices64x64;
        // sequence id (minimum resolution price bucket / 256) => price update sequence
        mapping(uint256 => uint256) priceUpdateSequences;
        // isCall -> batch data
        mapping(bool => BatchData) nextDeposits;
        // user -> batch timestamp -> isCall -> pending amount
        mapping(address => mapping(uint256 => mapping(bool => uint256))) pendingDeposits;
        EnumerableSet.UintSet tokenIds;
        // user -> isCallPool -> total value locked of user (Used for liquidity mining)
        mapping(address => mapping(bool => uint256)) userTVL;
        // isCallPool -> total value locked
        mapping(bool => uint256) totalTVL;
        // steepness values
        int128 steepnessBase64x64;
        int128 steepnessUnderlying64x64;
        // User -> isCallPool -> isBuybackEnabled
        mapping(address => mapping(bool => bool)) isBuybackEnabled;
        // LongTokenId -> minC
        mapping(uint256 => int128) minCLevel64x64;
        // APY fee tracking
        // underwriter -> shortTokenId -> amount
        mapping(address => mapping(uint256 => uint256)) feesReserved;
        // shortTokenId -> 64x64 fixed point representation of apy fee
        mapping(uint256 => int128) feeReserveRates;
        // APY fee paid by underwriters
        // Also used along with multiplier to calculate minimum option price as APY
        int128 feeApy64x64;
        // adjustment applied to spot price for puchase calculations
        int128 spotOffset64x64;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    /**
     * @notice calculate ERC1155 token id for given option parameters
     * @param tokenType TokenType enum
     * @param maturity timestamp of option maturity
     * @param strike64x64 64x64 fixed point representation of strike price
     * @return tokenId token id
     */
    function formatTokenId(
        TokenType tokenType,
        uint64 maturity,
        int128 strike64x64
    ) internal pure returns (uint256 tokenId) {
        tokenId =
            (uint256(tokenType) << 248) +
            (uint256(maturity) << 128) +
            uint256(int256(strike64x64));
    }

    /**
     * @notice derive option maturity and strike price from ERC1155 token id
     * @param tokenId token id
     * @return tokenType TokenType enum
     * @return maturity timestamp of option maturity
     * @return strike64x64 option strike price
     */
    function parseTokenId(
        uint256 tokenId
    )
        internal
        pure
        returns (TokenType tokenType, uint64 maturity, int128 strike64x64)
    {
        assembly {
            tokenType := shr(248, tokenId)
            maturity := shr(128, tokenId)
            strike64x64 := tokenId
        }
    }

    function getTokenType(
        bool isCall,
        bool isLong
    ) internal pure returns (TokenType tokenType) {
        if (isCall) {
            tokenType = isLong ? TokenType.LONG_CALL : TokenType.SHORT_CALL;
        } else {
            tokenType = isLong ? TokenType.LONG_PUT : TokenType.SHORT_PUT;
        }
    }

    function getPoolToken(
        Layout storage l,
        bool isCall
    ) internal view returns (address token) {
        token = isCall ? l.underlying : l.base;
    }

    function getTokenDecimals(
        Layout storage l,
        bool isCall
    ) internal view returns (uint8 decimals) {
        decimals = isCall ? l.underlyingDecimals : l.baseDecimals;
    }

    function getMinimumAmount(
        Layout storage l,
        bool isCall
    ) internal view returns (uint256 minimumAmount) {
        minimumAmount = isCall ? l.underlyingMinimum : l.baseMinimum;
    }

    /**
     * @notice get the total supply of free liquidity tokens, minus pending deposits
     * @param l storage layout struct
     * @param isCall whether query is for call or put pool
     * @return 64x64 fixed point representation of total free liquidity
     */
    function totalFreeLiquiditySupply64x64(
        Layout storage l,
        bool isCall
    ) internal view returns (int128) {
        uint256 tokenId = formatTokenId(
            isCall ? TokenType.UNDERLYING_FREE_LIQ : TokenType.BASE_FREE_LIQ,
            0,
            0
        );

        return
            ABDKMath64x64Token.fromDecimals(
                ERC1155EnumerableStorage.layout().totalSupply[tokenId] -
                    l.totalPendingDeposits(isCall),
                l.getTokenDecimals(isCall)
            );
    }

    function getReinvestmentStatus(
        Layout storage l,
        address account,
        bool isCallPool
    ) internal view returns (bool) {
        uint256 timestamp = l.divestmentTimestamps[account][isCallPool];
        return timestamp == 0 || timestamp > block.timestamp;
    }

    function getFeeApy64x64(
        Layout storage l
    ) internal view returns (int128 feeApy64x64) {
        feeApy64x64 = l.feeApy64x64;

        if (feeApy64x64 == 0) {
            // if APY fee is not set, set to 0.025
            feeApy64x64 = 0x666666666666666;
        }
    }

    function getMinApy64x64(
        Layout storage l
    ) internal view returns (int128 feeApy64x64) {
        feeApy64x64 = l.getFeeApy64x64() << 3;
    }

    function addUnderwriter(
        Layout storage l,
        address account,
        bool isCallPool
    ) internal {
        require(account != address(0));

        mapping(address => address) storage asc = l.liquidityQueueAscending[
            isCallPool
        ];
        mapping(address => address) storage desc = l.liquidityQueueDescending[
            isCallPool
        ];

        if (_isInQueue(account, asc, desc)) return;

        address last = desc[address(0)];

        asc[last] = account;
        desc[account] = last;
        desc[address(0)] = account;
    }

    function removeUnderwriter(
        Layout storage l,
        address account,
        bool isCallPool
    ) internal {
        require(account != address(0));

        mapping(address => address) storage asc = l.liquidityQueueAscending[
            isCallPool
        ];
        mapping(address => address) storage desc = l.liquidityQueueDescending[
            isCallPool
        ];

        if (!_isInQueue(account, asc, desc)) return;

        address prev = desc[account];
        address next = asc[account];
        asc[prev] = next;
        desc[next] = prev;
        delete asc[account];
        delete desc[account];
    }

    function isInQueue(
        Layout storage l,
        address account,
        bool isCallPool
    ) internal view returns (bool) {
        mapping(address => address) storage asc = l.liquidityQueueAscending[
            isCallPool
        ];
        mapping(address => address) storage desc = l.liquidityQueueDescending[
            isCallPool
        ];

        return _isInQueue(account, asc, desc);
    }

    function _isInQueue(
        address account,
        mapping(address => address) storage asc,
        mapping(address => address) storage desc
    ) private view returns (bool) {
        return asc[account] != address(0) || desc[address(0)] == account;
    }

    /**
     * @notice get current C-Level, without accounting for pending adjustments
     * @param l storage layout struct
     * @param isCall whether query is for call or put pool
     * @return cLevel64x64 64x64 fixed point representation of C-Level
     */
    function getRawCLevel64x64(
        Layout storage l,
        bool isCall
    ) internal view returns (int128 cLevel64x64) {
        cLevel64x64 = isCall ? l.cLevelUnderlying64x64 : l.cLevelBase64x64;
    }

    /**
     * @notice get current C-Level, accounting for unrealized decay
     * @param l storage layout struct
     * @param isCall whether query is for call or put pool
     * @param utilization64x64 utilization of the pool
     * @return cLevel64x64 64x64 fixed point representation of C-Level
     */
    function getDecayAdjustedCLevel64x64(
        Layout storage l,
        bool isCall,
        int128 utilization64x64
    ) internal view returns (int128 cLevel64x64) {
        // get raw C-Level from storage
        cLevel64x64 = l.getRawCLevel64x64(isCall);

        // account for C-Level decay
        cLevel64x64 = l.applyCLevelDecayAdjustment(
            cLevel64x64,
            isCall,
            utilization64x64
        );
    }

    /**
     * @notice get updated C-Level and pool liquidity level, accounting for decay and pending deposits
     * @param l storage layout struct
     * @param isCall whether to update C-Level for call or put pool
     * @return cLevel64x64 64x64 fixed point representation of C-Level
     * @return liquidity64x64 64x64 fixed point representation of new liquidity amount
     */
    function getRealPoolState(
        Layout storage l,
        bool isCall
    ) internal view returns (int128 cLevel64x64, int128 liquidity64x64) {
        PoolStorage.BatchData storage batchData = l.nextDeposits[isCall];

        int128 oldCLevel64x64 = l.getDecayAdjustedCLevel64x64(
            isCall,
            l.getUtilization64x64(isCall)
        );
        int128 oldLiquidity64x64 = l.totalFreeLiquiditySupply64x64(isCall);

        if (
            batchData.totalPendingDeposits > 0 &&
            batchData.eta != 0 &&
            block.timestamp >= batchData.eta
        ) {
            liquidity64x64 = ABDKMath64x64Token
                .fromDecimals(
                    batchData.totalPendingDeposits,
                    l.getTokenDecimals(isCall)
                )
                .add(oldLiquidity64x64);

            cLevel64x64 = l.applyCLevelLiquidityChangeAdjustment(
                oldCLevel64x64,
                oldLiquidity64x64,
                liquidity64x64,
                isCall
            );
        } else {
            cLevel64x64 = oldCLevel64x64;
            liquidity64x64 = oldLiquidity64x64;
        }
    }

    /**
     * @notice calculate updated C-Level, accounting for unrealized decay
     * @param l storage layout struct
     * @param oldCLevel64x64 64x64 fixed point representation pool C-Level before accounting for decay
     * @param isCall whether query is for call or put pool
     * @return cLevel64x64 64x64 fixed point representation of C-Level of Pool after accounting for decay
     */
    function applyCLevelDecayAdjustment(
        Layout storage l,
        int128 oldCLevel64x64,
        bool isCall,
        int128 utilization64x64
    ) internal view returns (int128 cLevel64x64) {
        uint256 timeElapsed = block.timestamp -
            (isCall ? l.cLevelUnderlyingUpdatedAt : l.cLevelBaseUpdatedAt);

        // do not apply C decay if less than 24 hours have elapsed

        if (timeElapsed > C_DECAY_BUFFER) {
            timeElapsed -= C_DECAY_BUFFER;
        } else {
            return oldCLevel64x64;
        }

        int128 timeIntervalsElapsed64x64 = ABDKMath64x64.divu(
            timeElapsed,
            C_DECAY_INTERVAL
        );

        return
            OptionMath.calculateCLevelDecay(
                OptionMath.CalculateCLevelDecayArgs(
                    timeIntervalsElapsed64x64,
                    oldCLevel64x64,
                    utilization64x64,
                    0xb333333333333333, // 0.7
                    0xe666666666666666, // 0.9
                    0x10000000000000000, // 1.0
                    0x10000000000000000, // 1.0
                    0xe666666666666666, // 0.9
                    0x56fc2a2c515da32ea // 2e
                )
            );
    }

    function getUtilization64x64(
        Layout storage l,
        bool isCall
    ) internal view returns (int128 utilization64x64) {
        uint256 tokenId = formatTokenId(
            isCall ? TokenType.UNDERLYING_FREE_LIQ : TokenType.BASE_FREE_LIQ,
            0,
            0
        );

        uint256 tvl = l.totalTVL[isCall];
        uint256 pendingDeposits = l.totalPendingDeposits(isCall);

        if (tvl <= pendingDeposits) return 0;

        uint256 freeLiq = ERC1155EnumerableStorage.layout().totalSupply[
            tokenId
        ];

        if (tvl < freeLiq) {
            // workaround for TVL underflow issue
            freeLiq = tvl;
        }

        utilization64x64 = ABDKMath64x64.divu(
            tvl - freeLiq,
            tvl - pendingDeposits
        );

        // Safeguard check
        require(utilization64x64 <= ONE_64x64, "utilization > 1");
    }

    /**
     * @notice calculate updated C-Level, accounting for change in liquidity
     * @param l storage layout struct
     * @param oldCLevel64x64 64x64 fixed point representation pool C-Level before accounting for liquidity change
     * @param oldLiquidity64x64 64x64 fixed point representation of previous liquidity
     * @param newLiquidity64x64 64x64 fixed point representation of current liquidity
     * @param isCallPool whether to update C-Level for call or put pool
     * @return cLevel64x64 64x64 fixed point representation of C-Level
     */
    function applyCLevelLiquidityChangeAdjustment(
        Layout storage l,
        int128 oldCLevel64x64,
        int128 oldLiquidity64x64,
        int128 newLiquidity64x64,
        bool isCallPool
    ) internal view returns (int128 cLevel64x64) {
        int128 steepness64x64 = isCallPool
            ? l.steepnessUnderlying64x64
            : l.steepnessBase64x64;

        // fallback to deprecated storage value if side-specific value is not set
        if (steepness64x64 == 0) steepness64x64 = l._deprecated_steepness64x64;

        cLevel64x64 = OptionMath.calculateCLevel(
            oldCLevel64x64,
            oldLiquidity64x64,
            newLiquidity64x64,
            steepness64x64
        );

        if (cLevel64x64 < 0xb333333333333333) {
            cLevel64x64 = int128(0xb333333333333333); // 64x64 fixed point representation of 0.7
        }
    }

    /**
     * @notice set C-Level to arbitrary pre-calculated value
     * @param cLevel64x64 new C-Level of pool
     * @param isCallPool whether to update C-Level for call or put pool
     */
    function setCLevel(
        Layout storage l,
        int128 cLevel64x64,
        bool isCallPool
    ) internal {
        if (isCallPool) {
            l.cLevelUnderlying64x64 = cLevel64x64;
            l.cLevelUnderlyingUpdatedAt = block.timestamp;
        } else {
            l.cLevelBase64x64 = cLevel64x64;
            l.cLevelBaseUpdatedAt = block.timestamp;
        }
    }

    function setOracles(
        Layout storage l,
        address baseOracle,
        address underlyingOracle
    ) internal {
        require(
            AggregatorV3Interface(baseOracle).decimals() ==
                AggregatorV3Interface(underlyingOracle).decimals(),
            "Pool: oracle decimals must match"
        );

        l.baseOracle = baseOracle;
        l.underlyingOracle = underlyingOracle;
    }

    function fetchPriceUpdate(
        Layout storage l
    ) internal view returns (int128 price64x64) {
        int256 priceUnderlying = AggregatorInterface(l.underlyingOracle)
            .latestAnswer();
        int256 priceBase = AggregatorInterface(l.baseOracle).latestAnswer();

        return ABDKMath64x64.divi(priceUnderlying, priceBase);
    }

    /**
     * @notice set price update for hourly bucket corresponding to given timestamp
     * @param l storage layout struct
     * @param timestamp timestamp to update
     * @param price64x64 64x64 fixed point representation of price
     */
    function setPriceUpdate(
        Layout storage l,
        uint256 timestamp,
        int128 price64x64
    ) internal {
        uint256 bucket = timestamp / (1 hours);
        l.bucketPrices64x64[bucket] = price64x64;
        l.priceUpdateSequences[bucket >> 8] += 1 << (255 - (bucket & 255));
    }

    /**
     * @notice get price update for hourly bucket corresponding to given timestamp
     * @param l storage layout struct
     * @param timestamp timestamp to query
     * @return 64x64 fixed point representation of price
     */
    function getPriceUpdate(
        Layout storage l,
        uint256 timestamp
    ) internal view returns (int128) {
        return l.bucketPrices64x64[timestamp / (1 hours)];
    }

    /**
     * @notice get first price update available following given timestamp
     * @param l storage layout struct
     * @param timestamp timestamp to query
     * @return 64x64 fixed point representation of price
     */
    function getPriceUpdateAfter(
        Layout storage l,
        uint256 timestamp
    ) internal view returns (int128) {
        // price updates are grouped into hourly buckets
        uint256 bucket = timestamp / (1 hours);
        // divide by 256 to get the index of the relevant price update sequence
        uint256 sequenceId = bucket >> 8;

        // get position within sequence relevant to current price update

        uint256 offset = bucket & 255;
        // shift to skip buckets from earlier in sequence
        uint256 sequence = (l.priceUpdateSequences[sequenceId] << offset) >>
            offset;

        // iterate through future sequences until a price update is found
        // sequence corresponding to current timestamp used as upper bound

        uint256 currentPriceUpdateSequenceId = block.timestamp / (256 hours);

        while (sequence == 0 && sequenceId <= currentPriceUpdateSequenceId) {
            sequence = l.priceUpdateSequences[++sequenceId];
        }

        // if no price update is found (sequence == 0) function will return 0
        // this should never occur, as each relevant external function triggers a price update

        // the most significant bit of the sequence corresponds to the offset of the relevant bucket

        uint256 msb;

        for (uint256 i = 128; i > 0; i >>= 1) {
            if (sequence >> i > 0) {
                msb += i;
                sequence >>= i;
            }
        }

        return l.bucketPrices64x64[((sequenceId + 1) << 8) - msb - 1];
    }

    function totalPendingDeposits(
        Layout storage l,
        bool isCallPool
    ) internal view returns (uint256) {
        return l.nextDeposits[isCallPool].totalPendingDeposits;
    }

    function pendingDepositsOf(
        Layout storage l,
        address account,
        bool isCallPool
    ) internal view returns (uint256) {
        return
            l.pendingDeposits[account][l.nextDeposits[isCallPool].eta][
                isCallPool
            ];
    }

    function contractSizeToBaseTokenAmount(
        Layout storage l,
        uint256 contractSize,
        int128 price64x64,
        bool isCallPool
    ) internal view returns (uint256 tokenAmount) {
        if (isCallPool) {
            tokenAmount = contractSize;
        } else {
            uint256 value = price64x64.mulu(contractSize);

            int128 value64x64 = ABDKMath64x64Token.fromDecimals(
                value,
                l.underlyingDecimals
            );

            tokenAmount = ABDKMath64x64Token.toDecimals(
                value64x64,
                l.baseDecimals
            );
        }
    }

    function setBuybackEnabled(
        Layout storage l,
        bool state,
        bool isCallPool
    ) internal {
        l.isBuybackEnabled[msg.sender][isCallPool] = state;
    }
}

// SPDX-License-Identifier: LGPL-3.0-or-later

pragma solidity ^0.8.0;

import {PremiaStakingStorage} from "./PremiaStakingStorage.sol";
import {IOFT} from "../layerZero/token/oft/IOFT.sol";

import {IERC2612} from "@solidstate/contracts/token/ERC20/permit/IERC2612.sol";

// IERC20Metadata inheritance not possible due to linearization issue
interface IPremiaStaking is IERC2612, IOFT {
    error PremiaStaking__CantTransfer();
    error PremiaStaking__ExcessiveStakePeriod();
    error PremiaStaking__InsufficientSwapOutput();
    error PremiaStaking__NoPendingWithdrawal();
    error PremiaStaking__NotEnoughLiquidity();
    error PremiaStaking__PeriodTooShort();
    error PremiaStaking__StakeLocked();
    error PremiaStaking__StakeNotLocked();
    error PremiaStaking__WithdrawalStillPending();

    event Stake(
        address indexed user,
        uint256 amount,
        uint64 stakePeriod,
        uint64 lockedUntil
    );

    event Unstake(
        address indexed user,
        uint256 amount,
        uint256 fee,
        uint256 startDate
    );

    event Harvest(address indexed user, uint256 amount);

    event EarlyUnstakeRewardCollected(address indexed user, uint256 amount);

    event Withdraw(address indexed user, uint256 amount);

    event RewardsAdded(uint256 amount);

    struct StakeLevel {
        uint256 amount; // Amount to stake
        uint256 discountBPS; // Discount when amount is reached
    }

    struct SwapArgs {
        //min amount out to be used to purchase
        uint256 amountOutMin;
        // exchange address to call to execute the trade
        address callee;
        // address for which to set allowance for the trade
        address allowanceTarget;
        // data to execute the trade
        bytes data;
        // address to which refund excess tokens
        address refundAddress;
    }

    event BridgeLock(
        address indexed user,
        uint64 stakePeriod,
        uint64 lockedUntil
    );

    event UpdateLock(
        address indexed user,
        uint64 oldStakePeriod,
        uint64 newStakePeriod
    );

    /**
     * @notice Returns the reward token address
     * @return The reward token address
     */
    function getRewardToken() external view returns (address);

    /**
     * @notice add premia tokens as available tokens to be distributed as rewards
     * @param amount amount of premia tokens to add as rewards
     */
    function addRewards(uint256 amount) external;

    /**
     * @notice get amount of tokens that have not yet been distributed as rewards
     * @return rewards amount of tokens not yet distributed as rewards
     * @return unstakeRewards amount of PREMIA not yet claimed from early unstake fees
     */
    function getAvailableRewards()
        external
        view
        returns (uint256 rewards, uint256 unstakeRewards);

    /**
     * @notice get pending amount of tokens to be distributed as rewards to stakers
     * @return amount of tokens pending to be distributed as rewards
     */
    function getPendingRewards() external view returns (uint256);

    /**
     * @notice get pending withdrawal data of a user
     * @return amount pending withdrawal amount
     * @return startDate start timestamp of withdrawal
     * @return unlockDate timestamp at which withdrawal becomes available
     */
    function getPendingWithdrawal(
        address user
    )
        external
        view
        returns (uint256 amount, uint256 startDate, uint256 unlockDate);

    /**
     * @notice get the amount of PREMIA available for withdrawal
     * @return amount of PREMIA available for withdrawal
     */
    function getAvailablePremiaAmount() external view returns (uint256);

    /**
     * @notice Stake using IERC2612 permit
     * @param amount The amount of xPremia to stake
     * @param period The lockup period (in seconds)
     * @param deadline Deadline after which permit will fail
     * @param v V
     * @param r R
     * @param s S
     */
    function stakeWithPermit(
        uint256 amount,
        uint64 period,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @notice Lockup xPremia for protocol fee discounts
     *          Longer period of locking will apply a multiplier on the amount staked, in the fee discount calculation
     * @param amount The amount of xPremia to stake
     * @param period The lockup period (in seconds)
     */
    function stake(uint256 amount, uint64 period) external;

    /**
     * @notice update vxPremia lock
     * @param period The new lockup period (in seconds)
     */
    function updateLock(uint64 period) external;

    /**
     * @notice harvest rewards, convert to PREMIA using exchange helper, and stake
     * @param s swap arguments
     * @param stakePeriod The lockup period (in seconds)
     */
    function harvestAndStake(
        IPremiaStaking.SwapArgs memory s,
        uint64 stakePeriod
    ) external;

    /**
     * @notice Harvest rewards directly to user wallet
     */
    function harvest() external;

    /**
     * @notice Get pending rewards amount, including pending pool update
     * @param user User for which to calculate pending rewards
     * @return reward amount of pending rewards from protocol fees (in REWARD_TOKEN)
     * @return unstakeReward amount of pending rewards from early unstake fees (in PREMIA)
     */
    function getPendingUserRewards(
        address user
    ) external view returns (uint256 reward, uint256 unstakeReward);

    /**
     * @notice unstake tokens before end of the lock period, for a fee
     * @param amount the amount of vxPremia to unstake
     */
    function earlyUnstake(uint256 amount) external;

    /**
     * @notice get early unstake fee for given user
     * @param user address of the user
     * @return feePercentage % fee to pay for early unstake (1e4 = 100%)
     */
    function getEarlyUnstakeFeeBPS(
        address user
    ) external view returns (uint256 feePercentage);

    /**
     * @notice Initiate the withdrawal process by burning xPremia, starting the delay period
     * @param amount quantity of xPremia to unstake
     */
    function startWithdraw(uint256 amount) external;

    /**
     * @notice Withdraw underlying premia
     */
    function withdraw() external;

    //////////
    // View //
    //////////

    /**
     * Calculate the stake amount of a user, after applying the bonus from the lockup period chosen
     * @param user The user from which to query the stake amount
     * @return The user stake amount after applying the bonus
     */
    function getUserPower(address user) external view returns (uint256);

    /**
     * Return the total power across all users (applying the bonus from lockup period chosen)
     * @return The total power across all users
     */
    function getTotalPower() external view returns (uint256);

    /**
     * @notice Calculate the % of fee discount for user, based on his stake
     * @param user The _user for which the discount is for
     * @return Percentage of protocol fee discount (in basis point)
     *         Ex : 1000 = 10% fee discount
     */
    function getDiscountBPS(address user) external view returns (uint256);

    /**
     * @notice Get stake levels
     * @return Stake levels
     *         Ex : 2500 = -25%
     */
    function getStakeLevels() external returns (StakeLevel[] memory);

    /**
     * @notice Get stake period multiplier
     * @param period The duration (in seconds) for which tokens are locked
     * @return The multiplier for this staking period
     *         Ex : 20000 = x2
     */
    function getStakePeriodMultiplierBPS(
        uint256 period
    ) external returns (uint256);

    /**
     * @notice Get staking infos of a user
     * @param user The user address for which to get staking infos
     * @return The staking infos of the user
     */
    function getUserInfo(
        address user
    ) external view returns (PremiaStakingStorage.UserInfo memory);
}

// SPDX-License-Identifier: LGPL-3.0-or-later

pragma solidity ^0.8.0;

import {VxPremiaStorage} from "./VxPremiaStorage.sol";
import {IPremiaStaking} from "./IPremiaStaking.sol";

interface IVxPremia is IPremiaStaking {
    error VxPremia__InvalidPoolAddress();
    error VxPremia__InvalidVoteTarget();
    error VxPremia__NotEnoughVotingPower();

    event AddVote(
        address indexed voter,
        VxPremiaStorage.VoteVersion indexed version,
        bytes target,
        uint256 amount
    );
    event RemoveVote(
        address indexed voter,
        VxPremiaStorage.VoteVersion indexed version,
        bytes target,
        uint256 amount
    );

    /**
     * @notice get total votes for specific pools
     * @param version version of target (used to know how to decode data)
     * @param target ABI encoded target of the votes
     * @return total votes for specific pool
     */
    function getPoolVotes(
        VxPremiaStorage.VoteVersion version,
        bytes memory target
    ) external view returns (uint256);

    /**
     * @notice get votes of user
     * @param user user from which to get votes
     * @return votes of user
     */
    function getUserVotes(
        address user
    ) external view returns (VxPremiaStorage.Vote[] memory);

    /**
     * @notice add or remove votes, in the limit of the user voting power
     * @param votes votes to cast
     */
    function castVotes(VxPremiaStorage.Vote[] memory votes) external;
}

// SPDX-License-Identifier: BUSL-1.1
// For further clarification please see https://license.premia.legal

pragma solidity ^0.8.0;

library PremiaStakingStorage {
    bytes32 internal constant STORAGE_SLOT =
        keccak256("premia.contracts.staking.PremiaStaking");

    struct Withdrawal {
        uint256 amount; // Premia amount
        uint256 startDate; // Will unlock at startDate + withdrawalDelay
    }

    struct UserInfo {
        uint256 reward; // Amount of rewards accrued which havent been claimed yet
        uint256 rewardDebt; // Debt to subtract from reward calculation
        uint256 unstakeRewardDebt; // Debt to subtract from reward calculation from early unstake fee
        uint64 stakePeriod; // Stake period selected by user
        uint64 lockedUntil; // Timestamp at which the lock ends
    }

    struct Layout {
        uint256 pendingWithdrawal;
        uint256 _deprecated_withdrawalDelay;
        mapping(address => Withdrawal) withdrawals;
        uint256 availableRewards;
        uint256 lastRewardUpdate; // Timestamp of last reward distribution update
        uint256 totalPower; // Total power of all staked tokens (underlying amount with multiplier applied)
        mapping(address => UserInfo) userInfo;
        uint256 accRewardPerShare;
        uint256 accUnstakeRewardPerShare;
        uint256 availableUnstakeRewards;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1
// For further clarification please see https://license.premia.legal

pragma solidity ^0.8.0;

library VxPremiaStorage {
    bytes32 internal constant STORAGE_SLOT =
        keccak256("premia.contracts.staking.VxPremia");

    enum VoteVersion {
        V2 // poolAddress : 20 bytes / isCallPool : 2 bytes
    }

    struct Vote {
        uint256 amount;
        VoteVersion version;
        bytes target;
    }

    struct Layout {
        mapping(address => Vote[]) userVotes;
        // Vote version -> Pool identifier -> Vote amount
        mapping(VoteVersion => mapping(bytes => uint256)) votes;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}