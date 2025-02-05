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

// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.18;

import { ITokenBalance } from './interfaces/ITokenBalance.sol';
import { ManagerRole } from './roles/ManagerRole.sol';
import './helpers/TransferHelper.sol' as TransferHelper;
import './Constants.sol' as Constants;

abstract contract BalanceManagement is ManagerRole {
    error ReservedTokenError();

    function cleanup(address _tokenAddress, uint256 _tokenAmount) external onlyManager {
        if (isReservedToken(_tokenAddress)) {
            revert ReservedTokenError();
        }

        if (_tokenAddress == Constants.NATIVE_TOKEN_ADDRESS) {
            TransferHelper.safeTransferNative(msg.sender, _tokenAmount);
        } else {
            TransferHelper.safeTransfer(_tokenAddress, msg.sender, _tokenAmount);
        }
    }

    function tokenBalance(address _tokenAddress) public view returns (uint256) {
        if (_tokenAddress == Constants.NATIVE_TOKEN_ADDRESS) {
            return address(this).balance;
        } else {
            return ITokenBalance(_tokenAddress).balanceOf(address(this));
        }
    }

    function isReservedToken(address /*_tokenAddress*/) public view virtual returns (bool) {
        return false;
    }
}

// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.18;

uint256 constant DECIMALS_DEFAULT = 18;
uint256 constant INFINITY = type(uint256).max;
uint256 constant MILLIPERCENT_FACTOR = 100_000;
address constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.18;

struct OptionalValue {
    bool isSet;
    uint256 value;
}

struct KeyToValue {
    uint256 key;
    uint256 value;
}

struct KeyToAddressValue {
    uint256 key;
    address value;
}

struct AccountToFlag {
    address account;
    bool flag;
}

function combinedMapSet(
    mapping(uint256 => address) storage _map,
    uint256[] storage _keyList,
    mapping(uint256 => OptionalValue) storage _keyIndexMap,
    uint256 _key,
    address _value
) returns (bool isNewKey) {
    isNewKey = !_keyIndexMap[_key].isSet;

    if (isNewKey) {
        uniqueListAdd(_keyList, _keyIndexMap, _key);
    }

    _map[_key] = _value;
}

function combinedMapRemove(
    mapping(uint256 => address) storage _map,
    uint256[] storage _keyList,
    mapping(uint256 => OptionalValue) storage _keyIndexMap,
    uint256 _key
) returns (bool isChanged) {
    isChanged = _keyIndexMap[_key].isSet;

    if (isChanged) {
        delete _map[_key];
        uniqueListRemove(_keyList, _keyIndexMap, _key);
    }
}

function uniqueListAdd(
    uint256[] storage _list,
    mapping(uint256 => OptionalValue) storage _indexMap,
    uint256 _value
) returns (bool isChanged) {
    isChanged = !_indexMap[_value].isSet;

    if (isChanged) {
        _indexMap[_value] = OptionalValue(true, _list.length);
        _list.push(_value);
    }
}

function uniqueListRemove(
    uint256[] storage _list,
    mapping(uint256 => OptionalValue) storage _indexMap,
    uint256 _value
) returns (bool isChanged) {
    OptionalValue storage indexItem = _indexMap[_value];

    isChanged = indexItem.isSet;

    if (isChanged) {
        uint256 itemIndex = indexItem.value;
        uint256 lastIndex = _list.length - 1;

        if (itemIndex != lastIndex) {
            uint256 lastValue = _list[lastIndex];
            _list[itemIndex] = lastValue;
            _indexMap[lastValue].value = itemIndex;
        }

        _list.pop();
        delete _indexMap[_value];
    }
}

function uniqueAddressListAdd(
    address[] storage _list,
    mapping(address => OptionalValue) storage _indexMap,
    address _value
) returns (bool isChanged) {
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
) returns (bool isChanged) {
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
) returns (bool isChanged) {
    return
        _flag
            ? uniqueAddressListAdd(_list, _indexMap, _value)
            : uniqueAddressListRemove(_list, _indexMap, _value);
}

// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.18;

import { BalanceManagement } from '../../BalanceManagement.sol';
import '../../helpers/AddressHelper.sol' as AddressHelper;
import '../../helpers/TransferHelper.sol' as TransferHelper;
import '../../DataStructures.sol' as DataStructures;
import '../../Constants.sol' as Constants;

contract MTFeeMediator is BalanceManagement {
    address public buybackAddress;
    address public feeDistributionMTLockersAddress;
    address public feeDistributionLPLockersAddress;
    address public treasuryAddress;

    uint256 public buybackPart; // Value in millipercent
    uint256 public MTLockersPart; // Value in millipercent
    uint256 public LPLockersPart; // Value in millipercent

    address[] public assetList;
    mapping(address => DataStructures.OptionalValue) public assetIndexMap;

    event SetBuybackAddress(address indexed buybackAddress);
    event SetFeeDistributionMTLockersAddress(address indexed feeDistributionMTLockersAddress);
    event SetFeeDistributionLPLockersAddress(address indexed feeDistributionLPLockersAddress);
    event SetTreasuryAddress(address indexed treasuryAddress);

    event SetDistributionParts(uint256 buybackPart, uint256 MTLockersPart, uint256 LPLockersPart);

    error PartValueError();

    constructor(
        address _buybackAddress,
        address _MTLockersAddress,
        address _LPLockersAddress,
        address _treasuryAddress,
        uint256 _buybackPart, // Value in millipercent
        uint256 _MTLockersPart, // Value in millipercent
        uint256 _LPLockersPart, // Value in millipercent
        address[] memory _assets,
        address _owner,
        address[] memory _managers,
        bool _addOwnerToManagers
    ) {
        buybackAddress = _buybackAddress;
        feeDistributionMTLockersAddress = _MTLockersAddress;
        feeDistributionLPLockersAddress = _LPLockersAddress;
        treasuryAddress = _treasuryAddress;

        _setDistributionParts(_buybackPart, _MTLockersPart, _LPLockersPart);

        for (uint256 index; index < _assets.length; index++) {
            _setAsset(_assets[index], true);
        }

        _initRoles(_owner, _managers, _addOwnerToManagers);
    }

    function setBuybackAddress(address _buybackAddress) external onlyManager {
        buybackAddress = _buybackAddress;
    }

    function setFeeDistributionMTLockersAddress(address _MTLockersAddress) external onlyManager {
        feeDistributionMTLockersAddress = _MTLockersAddress;

        emit SetFeeDistributionMTLockersAddress(_MTLockersAddress);
    }

    function setFeeDistributionLPLockersAddress(address _LPLockersAddress) external onlyManager {
        feeDistributionLPLockersAddress = _LPLockersAddress;

        emit SetFeeDistributionMTLockersAddress(_LPLockersAddress);
    }

    function setTreasuryAddress(address _treasuryAddress) external onlyManager {
        treasuryAddress = _treasuryAddress;

        emit SetTreasuryAddress(_treasuryAddress);
    }

    function setDistributionParts(
        uint256 _buybackPart,
        uint256 _MTLockersPart,
        uint256 _LPLockersPart
    ) external onlyManager {
        _setDistributionParts(_buybackPart, _MTLockersPart, _LPLockersPart);
    }

    function setAsset(address _tokenAddress, bool _value) external onlyManager {
        _setAsset(_tokenAddress, _value);
    }

    function process() external onlyManager {
        uint256 assetListLength = assetList.length;

        for (uint256 assetIndex; assetIndex < assetListLength; assetIndex++) {
            address assetToken = assetList[assetIndex];

            uint256 assetBalance = tokenBalance(assetToken);

            if (assetBalance > 0) {
                uint256 buybackAmount = (assetBalance * buybackPart) /
                    Constants.MILLIPERCENT_FACTOR;
                uint256 MTLockersAmount = (assetBalance * MTLockersPart) /
                    Constants.MILLIPERCENT_FACTOR;
                uint256 LPLockersAmount = (assetBalance * LPLockersPart) /
                    Constants.MILLIPERCENT_FACTOR;
                uint256 treasuryAmount = assetBalance -
                    buybackAmount -
                    MTLockersAmount -
                    LPLockersAmount;

                if (buybackAmount > 0) {
                    if (AddressHelper.isContract(buybackAddress)) {
                        // Transfer to buyback contract
                        TransferHelper.safeTransfer(assetToken, buybackAddress, buybackAmount);
                    } else {
                        // Transfer to EOA for manual buyback
                        TransferHelper.safeTransfer(assetToken, buybackAddress, buybackAmount);
                    }
                }

                if (MTLockersAmount > 0) {
                    // Transfer to fee distribution (MT Lockers) contract
                    TransferHelper.safeTransfer(
                        assetToken,
                        feeDistributionMTLockersAddress,
                        MTLockersAmount
                    );
                }

                if (LPLockersAmount > 0) {
                    // Transfer to fee distribution (LP Lockers) contract
                    TransferHelper.safeTransfer(
                        assetToken,
                        feeDistributionLPLockersAddress,
                        LPLockersAmount
                    );
                }

                // Transfer to treasury
                if (treasuryAmount > 0) {
                    TransferHelper.safeTransfer(assetToken, treasuryAddress, treasuryAmount);
                }
            }
        }
    }

    function assetCount() external view returns (uint256) {
        return assetList.length;
    }

    function fullAssetList() external view returns (address[] memory) {
        return assetList;
    }

    function isAsset(address _tokenAddress) public view returns (bool) {
        return assetIndexMap[_tokenAddress].isSet;
    }

    function isReservedToken(address _tokenAddress) public view override returns (bool) {
        return !isAsset(_tokenAddress);
    }

    // Values in millipercent
    function _setDistributionParts(
        uint256 _buybackPart,
        uint256 _MTLockersPart,
        uint256 _LPLockersPart
    ) private {
        if (_buybackPart + _MTLockersPart + _LPLockersPart > Constants.MILLIPERCENT_FACTOR) {
            revert PartValueError();
        }

        buybackPart = _buybackPart;
        MTLockersPart = _MTLockersPart;
        LPLockersPart = _LPLockersPart;

        emit SetDistributionParts(_buybackPart, _MTLockersPart, _LPLockersPart);
    }

    function _setAsset(address _tokenAddress, bool _value) private {
        DataStructures.uniqueAddressListUpdate(assetList, assetIndexMap, _tokenAddress, _value);
    }
}

// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.18;

error NonContractAddressError(address account);

function isContract(address _account) view returns (bool) {
    return _account.code.length > 0;
}

function requireContract(address _account) view {
    if (!isContract(_account)) {
        revert NonContractAddressError(_account);
    }
}

function requireContractOrZeroAddress(address _account) view {
    if (_account != address(0)) {
        requireContract(_account);
    }
}

// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.18;

error SafeApproveError();
error SafeTransferError();
error SafeTransferFromError();
error SafeTransferNativeError();

function safeApprove(address _token, address _to, uint256 _value) {
    // 0x095ea7b3 is the selector for "approve(address,uint256)"
    (bool success, bytes memory data) = _token.call(
        abi.encodeWithSelector(0x095ea7b3, _to, _value)
    );

    bool condition = success && (data.length == 0 || abi.decode(data, (bool)));

    if (!condition) {
        revert SafeApproveError();
    }
}

function safeTransfer(address _token, address _to, uint256 _value) {
    // 0xa9059cbb is the selector for "transfer(address,uint256)"
    (bool success, bytes memory data) = _token.call(
        abi.encodeWithSelector(0xa9059cbb, _to, _value)
    );

    bool condition = success && (data.length == 0 || abi.decode(data, (bool)));

    if (!condition) {
        revert SafeTransferError();
    }
}

function safeTransferFrom(address _token, address _from, address _to, uint256 _value) {
    // 0x23b872dd is the selector for "transferFrom(address,address,uint256)"
    (bool success, bytes memory data) = _token.call(
        abi.encodeWithSelector(0x23b872dd, _from, _to, _value)
    );

    bool condition = success && (data.length == 0 || abi.decode(data, (bool)));

    if (!condition) {
        revert SafeTransferFromError();
    }
}

function safeTransferNative(address _to, uint256 _value) {
    (bool success, ) = _to.call{ value: _value }(new bytes(0));

    if (!success) {
        revert SafeTransferNativeError();
    }
}

// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.18;

interface ITokenBalance {
    function balanceOf(address _account) external view returns (uint256);
}

// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.18;

import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { RoleBearers } from './RoleBearers.sol';

abstract contract ManagerRole is Ownable, RoleBearers {
    bytes32 private constant ROLE_KEY = keccak256('Manager');

    event SetManager(address indexed account, bool indexed value);
    event RenounceManagerRole(address indexed account);

    error OnlyManagerError();

    modifier onlyManager() {
        if (!isManager(msg.sender)) {
            revert OnlyManagerError();
        }

        _;
    }

    function setManager(address _account, bool _value) public onlyOwner {
        _setRoleBearer(ROLE_KEY, _account, _value);

        emit SetManager(_account, _value);
    }

    function renounceManagerRole() public onlyManager {
        _setRoleBearer(ROLE_KEY, msg.sender, false);

        emit RenounceManagerRole(msg.sender);
    }

    function isManager(address _account) public view returns (bool) {
        return _isRoleBearer(ROLE_KEY, _account);
    }

    function managerCount() public view returns (uint256) {
        return _roleBearerCount(ROLE_KEY);
    }

    function fullManagerList() public view returns (address[] memory) {
        return _fullRoleBearerList(ROLE_KEY);
    }

    function _initRoles(
        address _owner,
        address[] memory _managers,
        bool _addOwnerToManagers
    ) internal {
        address ownerAddress = _owner == address(0) ? msg.sender : _owner;

        for (uint256 index; index < _managers.length; index++) {
            setManager(_managers[index], true);
        }

        if (_addOwnerToManagers && !isManager(ownerAddress)) {
            setManager(ownerAddress, true);
        }

        if (ownerAddress != msg.sender) {
            transferOwnership(ownerAddress);
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.18;

import '../DataStructures.sol' as DataStructures;

abstract contract RoleBearers {
    mapping(bytes32 => address[]) private roleBearerTable;
    mapping(bytes32 => mapping(address => DataStructures.OptionalValue))
        private roleBearerIndexTable;

    function _setRoleBearer(bytes32 _roleKey, address _account, bool _value) internal {
        DataStructures.uniqueAddressListUpdate(
            roleBearerTable[_roleKey],
            roleBearerIndexTable[_roleKey],
            _account,
            _value
        );
    }

    function _isRoleBearer(bytes32 _roleKey, address _account) internal view returns (bool) {
        return roleBearerIndexTable[_roleKey][_account].isSet;
    }

    function _roleBearerCount(bytes32 _roleKey) internal view returns (uint256) {
        return roleBearerTable[_roleKey].length;
    }

    function _fullRoleBearerList(bytes32 _roleKey) internal view returns (address[] memory) {
        return roleBearerTable[_roleKey];
    }
}