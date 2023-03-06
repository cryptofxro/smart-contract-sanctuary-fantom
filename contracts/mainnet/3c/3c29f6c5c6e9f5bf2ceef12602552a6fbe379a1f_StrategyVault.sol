// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControlUpgradeable.sol";
import "../utils/ContextUpgradeable.sol";
import "../utils/StringsUpgradeable.sol";
import "../utils/introspection/ERC165Upgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControlUpgradeable, ERC165Upgradeable {
    function __AccessControl_init() internal onlyInitializing {
    }

    function __AccessControl_init_unchained() internal onlyInitializing {
    }
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(account),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.1) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ReentrancyGuardUpgradeable is Initializable {
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

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20Upgradeable.sol";
import "./extensions/IERC20MetadataUpgradeable.sol";
import "../../utils/ContextUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20Upgradeable, IERC20MetadataUpgradeable {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    function __ERC20_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[45] private __gap;
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
interface IERC20PermitUpgradeable {
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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20MetadataUpgradeable is IERC20Upgradeable {
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
interface IERC20Upgradeable {
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

import "../IERC20Upgradeable.sol";
import "../extensions/draft-IERC20PermitUpgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
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
        IERC20PermitUpgradeable token,
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
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
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
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721Upgradeable.sol";
import "./IERC721ReceiverUpgradeable.sol";
import "./extensions/IERC721MetadataUpgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/ContextUpgradeable.sol";
import "../../utils/StringsUpgradeable.sol";
import "../../utils/introspection/ERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721Upgradeable is Initializable, ContextUpgradeable, ERC165Upgradeable, IERC721Upgradeable, IERC721MetadataUpgradeable {
    using AddressUpgradeable for address;
    using StringsUpgradeable for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    function __ERC721_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC721_init_unchained(name_, symbol_);
    }

    function __ERC721_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
        return
            interfaceId == type(IERC721Upgradeable).interfaceId ||
            interfaceId == type(IERC721MetadataUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _ownerOf(tokenId);
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner or approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     */
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId, 1);

        // Check that tokenId was not minted by `_beforeTokenTransfer` hook
        require(!_exists(tokenId), "ERC721: token already minted");

        unchecked {
            // Will not overflow unless all 2**256 token ids are minted to the same owner.
            // Given that tokens are minted one by one, it is impossible in practice that
            // this ever happens. Might change if we allow batch minting.
            // The ERC fails to describe this case.
            _balances[to] += 1;
        }

        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId, 1);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721Upgradeable.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId, 1);

        // Update ownership in case tokenId was transferred by `_beforeTokenTransfer` hook
        owner = ERC721Upgradeable.ownerOf(tokenId);

        // Clear approvals
        delete _tokenApprovals[tokenId];

        unchecked {
            // Cannot overflow, as that would require more tokens to be burned/transferred
            // out than the owner initially received through minting and transferring in.
            _balances[owner] -= 1;
        }
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId, 1);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721Upgradeable.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId, 1);

        // Check that tokenId was not transferred by `_beforeTokenTransfer` hook
        require(ERC721Upgradeable.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");

        // Clear approvals from the previous owner
        delete _tokenApprovals[tokenId];

        unchecked {
            // `_balances[from]` cannot overflow for the same reason as described in `_burn`:
            // `from`'s balance is the number of token held, which is at least one before the current
            // transfer.
            // `_balances[to]` could overflow in the conditions described in `_mint`. That would require
            // all 2**256 token ids to be minted, which in practice is impossible.
            _balances[from] -= 1;
            _balances[to] += 1;
        }
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId, 1);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721Upgradeable.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Reverts if the `tokenId` has not been minted yet.
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721ReceiverUpgradeable(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721ReceiverUpgradeable.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting and burning. If {ERC721Consecutive} is
     * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens will be transferred to `to`.
     * - When `from` is zero, the tokens will be minted for `to`.
     * - When `to` is zero, ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256, /* firstTokenId */
        uint256 batchSize
    ) internal virtual {
        if (batchSize > 1) {
            if (from != address(0)) {
                _balances[from] -= batchSize;
            }
            if (to != address(0)) {
                _balances[to] += batchSize;
            }
        }
    }

    /**
     * @dev Hook that is called after any token transfer. This includes minting and burning. If {ERC721Consecutive} is
     * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens were transferred to `to`.
     * - When `from` is zero, the tokens were minted for `to`.
     * - When `to` is zero, ``from``'s tokens were burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[44] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721Upgradeable.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721MetadataUpgradeable is IERC721Upgradeable {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721ReceiverUpgradeable {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721Upgradeable is IERC165Upgradeable {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
import "../proxy/utils/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

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
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
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
interface IERC165Upgradeable {
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library MathUpgradeable {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/MathUpgradeable.sol";

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = MathUpgradeable.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, MathUpgradeable.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/IERC20.sol";

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
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../interfaces/IPriceSource.sol";
import "../interfaces/ILiquidator.sol";
import "../USDV.sol";
import "../VaultNFTv3.sol";

/**
 * @title ERC20Stablecoin
 * @notice Vaults pool
 * @dev ERC20Stablecoin backed by ERC20 token as a collateral, and can only be minted with this collateral backing it.
 * Tokens will be minted when users deposit native token in vaults and in turn receive a loan against that collateral.
 */
contract ERC20Stablecoin is Initializable, ReentrancyGuardUpgradeable, VaultNFTv3, ILiquidator {
    using SafeERC20Upgradeable for ERC20Upgradeable;
    using SafeERC20Upgradeable for USDV;

    /**
     * @notice {usdv} price decimals
     */
    uint8 public constant TOKEN_PEG_DECIMALS = 8;

    /**
     * @notice price provider address
     */
    IPriceSource public ethPriceSource;

    /**
     * @notice minimal collateral percentage below which a vault will be liquidated
     */
    uint256 public minimumCollateralPercentage;

    /**
     * @notice total number of vaults
     */
    uint256 public vaultCount;
    /**
     * @notice system fee percentage for liquidation
     */
    uint256 public override closingFee;
    /**
     * @notice system fee percentage for payback
     */
    uint256 public paybackFee;
    /**
     * @notice total amount of deposited collateral
     */
    uint256 public totalCollateral;
    /**
     * @notice amount of minted {usdv}
     */
    uint256 public supply;
    
    /**
     * @notice index of treasury vault
     */
    uint256 public treasury;
    /**
     * @notice {usdv} rate to USD
     */
    uint256 public tokenPeg;
    /**
     * @notice returns deposited collateral amount by vault id
     */
    mapping(uint256 => uint256) public vaultCollateral;
    /**
     * @notice returns minted amount of {usdb} by vault id 
     */
    mapping(uint256 => uint256) public vaultDebt;
    
    /**
     * @notice percentage of vualt debt for single liquidation. 10000 = 100% 
     */
    uint256 public debtRatio;
    /**
     * @notice multiplier of liquidator interest. 1100 = 1.1
     */
    uint256 public gainRatio;
    /**
     * @notice max minted {usdv} amount by all vaults
     */
    uint256 public debtCeiling;

    /**
     * @notice liquidator smart contract address. 0x0 - public liquidation
     */
    address public stabilityPool;

    /**
     * @notice collateral token address
     */
    ERC20Upgradeable public collateral;

    USDV public usdv;

    /**
     * @notice decimals of rate provided {ethPriceSource}
     */
    uint8 public priceSourceDecimals;

    mapping(address => uint256) public liquidationDebt;

    // NOTE: there is a storage gap at the end of the contract

    event CreateVault(uint256 vaultID, address creator);
    event DestroyVault(uint256 vaultID);
    event TransferVault(uint256 vaultID, address from, address to);
    event DepositCollateral(uint256 vaultID, uint256 amount);
    event WithdrawCollateral(uint256 vaultID, uint256 amount);
    event BorrowToken(uint256 vaultID, uint256 amount);
    event PayBackToken(uint256 vaultID, uint256 amount, uint256 paybackFee);
    event LiquidateVault(uint256 vaultID, address owner, address buyer, uint256 debtRepaid, uint256 collateralLiquidated, uint256 closingFee);

    modifier onlyVaultOwner(uint256 vaultID) {
        require(_exists(vaultID), "Vault does not exist");
        require(ownerOf(vaultID) == msg.sender, "Vault is not owned by you");
        _;
    }

    /**
     * @notice initializer instead of constructor
     * @param ethPriceSourceAddress collateral token price provider address
     * @param _minimumCollateralPercentage minimal collateral percentage below which a vault will be liquidated
     * @param name name of vaults pool
     * @param symbol symbol of vaults pool
     * @param _stablecoin usdv address
     * @param _collateral collateral token address
     * @param meta meta provider address
     */
    function __ERC20Stablecoin_init(
        address ethPriceSourceAddress,
        uint256 _minimumCollateralPercentage,
        string memory name,
        string memory symbol,
        address _stablecoin,
        address _collateral,
        address meta
    ) onlyInitializing public {
        __ReentrancyGuard_init();
        __VaultNFTv3_init(name, symbol, meta);

        require(ethPriceSourceAddress != address(0));
        require(_minimumCollateralPercentage != 0);
        debtCeiling = 100000 * 10**18; // 100 000 USDV
        closingFee = 100; // 1%
        paybackFee = 100; // 1%
        ethPriceSource = IPriceSource(ethPriceSourceAddress);
        stabilityPool = address(0);
        tokenPeg = 100000000; // $1

        debtRatio = 5000; // pay back 50%
        gainRatio = 1100;// /10 so 1.1

        minimumCollateralPercentage = _minimumCollateralPercentage;

        collateral = ERC20Upgradeable(_collateral);
        usdv = USDV(_stablecoin);
        priceSourceDecimals = ethPriceSource.decimals();
    }


    /**
     * @notice Returns the maximum amount of minted token.
     * The goal of the debt ceiling is to prevent a large amount of token from flooding the market 
     * that could negatively affect its price
     * @return debtCeiling
     */
    function getDebtCeiling() external view returns (uint256){
        return debtCeiling;
    }

    /**
     * @notice Returns the total value of locked tokens in USD.
     */
    function getTVL() external view returns (uint256){
        return totalCollateral * getEthPriceSource();
    }

    /**
     * @notice returns true if vault {vaultID} is exist
     */
    function exists(uint256 vaultID) external view returns (bool){
        return _exists(vaultID);
    }

    /**
     * @notice Returns closingFee.
     * Users pay closingFee (by default 0.5%) when repaying their debt to unlock the underlying collateral. 
     * This fee is denominated in the collateral token.
     * @return closingFee
     */
    function getClosingFee() external view returns (uint256){
        return closingFee;
    }

    /**
     * @notice Returns tokenPeg
     * @return tokenPeg
     */
    function getTokenPriceSource() public view returns (uint256){
        return tokenPeg;
    }

    /**
     * @notice Returns price of collateral token returned by priceOracle with address ethPriceSource.
     * @return price
     */
    function getEthPriceSource() public view virtual returns (uint256){
        (,int256 price,,,) = ethPriceSource.latestRoundData();
        // convert price source decimals value to decimals of {tokenPeg}
        return _correctDecimals(uint256(price), TOKEN_PEG_DECIMALS, priceSourceDecimals);
    }

    /**
     * @dev Calculates the value of collateral times 100 and debt.
     * @return collateralValueTimes100
     * @return debtValue
     */
    function _calculateCollateralProperties(uint256 _collateral, uint256 _debt) private view returns (uint256, uint256) {
        uint256 ethPrice = getEthPriceSource();
        uint256 tokenPrice = getTokenPriceSource();
        
        assert(ethPrice != 0);
        assert(tokenPrice != 0);

        // collateral value is presented with usdv decimals precision
        uint256 collateralValue = _correctDecimals(_collateral * ethPrice, usdv.decimals(), collateral.decimals());

        uint256 debtValue = _debt * tokenPrice;

        uint256 collateralValueTimes100 = collateralValue * 100;

        return (collateralValueTimes100, debtValue);
    }

    /**
     * @dev returns true if collateral percentage more than {minimumCollateralPercentage}
     */
    function isValidCollateral(uint256 _collateral, uint256 debt) internal view returns (bool) {
        (uint256 collateralValueTimes100, uint256 debtValue) = _calculateCollateralProperties(_collateral, debt);

        uint256 collateralPercentage = collateralValueTimes100 / debtValue;

        return collateralPercentage >= minimumCollateralPercentage;
    }

    /**
     * @notice Creates vault for a sender. Emits event CreateVault(id, msg.sender)
     * NOTE: The amount of vaults created for a user is not limited.
     *
     * @return id Id of created vault
     */
    function createVault() external returns (uint256) {
        uint256 id = vaultCount;
        vaultCount = vaultCount + 1;

        _mint(msg.sender,id);

        emit CreateVault(id, msg.sender);

        return id;
    }

    /**
     * @notice Destroys specified vault. Requires no loan for vault. Pays back the entire deposit, if any.
     * Emits event DestroyVault(vaultID)
     *
     * Requirements:
     *
     * - There is no outstanding debt.
     * - The vault must exist
     * - The caller is owner of the vault
     *
     * @param vaultID Id of vault to destroy
     */
    function destroyVault(uint256 vaultID) external virtual onlyVaultOwner(vaultID) nonReentrant {
        require(vaultDebt[vaultID] == 0, "Vault has outstanding debt");

        uint256 collat = vaultCollateral[vaultID];
        totalCollateral -= collat;


        delete vaultCollateral[vaultID];
        delete vaultDebt[vaultID];

        emit DestroyVault(vaultID);

        if(collat != 0) {
            // withdraw leftover collateral
            collateral.safeTransfer(ownerOf(vaultID), collat);
        }

        _burn(vaultID);
    }

    /**
     * @notice Deposit erc20 collateral to specified 'vaultID'.
     *
     * NOTE: There isn`t check whether amount of deposited collateral > 0
     *
     * Requirements:
     *
     * - The vault must exist
     * - The caller is owner of vault
     *
     * @param vaultID Id of the vault
     * @param amount Collateral amount
     */
    function depositCollateral(uint256 vaultID, uint256 amount) external virtual onlyVaultOwner(vaultID) nonReentrant {

        collateral.safeTransferFrom(msg.sender, address(this), amount);

        vaultCollateral[vaultID] += amount;
        totalCollateral += amount;

        emit DepositCollateral(vaultID, amount);
    }

    /**
     * @notice Withdraw collaterals from 'vaultID'.
     *
     * Requirements:
     *
     * - Withdrawal would not put vault below minimum colateral percentage
     * - The vault must exist
     * - The caller is owner of vault
     *
     * @param vaultID Id of vault
     * @param amount Withdrawal amount
     */
    function withdrawCollateral(uint256 vaultID, uint256 amount) external virtual onlyVaultOwner(vaultID) nonReentrant {
        uint256 collat = vaultCollateral[vaultID];
        require(collat >= amount, "Vault does not have enough collateral");

        uint256 newCollateral = collat - amount;

        if(vaultDebt[vaultID] != 0) {
            require(isValidCollateral(newCollateral, vaultDebt[vaultID]), "Withdrawal would put vault below minimum collateral percentage");
        }

        vaultCollateral[vaultID] = newCollateral;
        totalCollateral -= amount;
        collateral.safeTransfer(msg.sender, amount);

        emit WithdrawCollateral(vaultID, amount);
    }

    /**
     * @notice Borrows specified amount of tokens 
     * 
     * NOTE: collateral must be deposited first.
     * 
     * Requirements:
     *
     * - Borrowing would not put vault below minimum colateral percentage
     * - Tokens amount must not exceed debtCeiling limit
     * - New value of total supply must be less than debtCeiling limit
     * - The vault must exist
     * - The caller is owner of vault
     *
     * @param vaultID Id of vault
     * @param amount Amount of tokens to borrow
     */
    function borrowToken(uint256 vaultID, uint256 amount) external onlyVaultOwner(vaultID) nonReentrant {
        require(amount > 0, "Must borrow non-zero amount");
        require(supply + amount <= debtCeiling, "borrowToken: Cannot mint over debtCeiling.");

        uint256 newDebt = vaultDebt[vaultID] + amount;

        require(isValidCollateral(vaultCollateral[vaultID], newDebt), "Borrow would put vault below minimum collateral percentage");

        vaultDebt[vaultID] = newDebt;

        supply += amount;
        usdv.mint(msg.sender, amount);

        emit BorrowToken(vaultID, amount);
    }

    /**
     * @notice Pays back specified amount of borrowed tokens 
     * 
     * Requirements:
     *
     * - The vault must have debt
     * - The vault must exist
     * - The caller is owner of the vault
     *
     * @param vaultID Id of vault
     * @param amount Amount of tokens to pay back
     */
    function payBackToken(uint256 vaultID, uint256 amount) external onlyVaultOwner(vaultID) nonReentrant {
        require(usdv.balanceOf(msg.sender) >= amount, "Token balance too low");
        require(vaultDebt[vaultID] >= amount, "Vault debt less than amount to pay back");

        uint256 _closingFee = _calculateClosingFee(amount, paybackFee);

        supply -= amount;
        usdv.burn(msg.sender, amount);

        vaultDebt[vaultID] = vaultDebt[vaultID] - amount;
        vaultCollateral[vaultID]=vaultCollateral[vaultID] - _closingFee;
        vaultCollateral[treasury]=vaultCollateral[treasury] + _closingFee;
        totalCollateral -= _closingFee;

        emit PayBackToken(vaultID, amount, _closingFee);
    }

    /**
     * @notice Withdraws all liquidation profits 
     */
    function getPaid() external virtual override nonReentrant {
        require(liquidationDebt[msg.sender]!=0, "Don't have anything for you.");
        uint256 amount = liquidationDebt[msg.sender];
        liquidationDebt[msg.sender]=0;
        collateral.safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Calculates the amount of debt would be paid off on liquidation
     * 
     * @param vaultID Id of the vault
     * @return uint256 Collateral extraction
     */
    function checkCost(uint256 vaultID) public view override returns (uint256) {

        if(vaultCollateral[vaultID] == 0 || vaultDebt[vaultID]==0 || !checkLiquidation(vaultID) ){
            return 0;
        }

        (, uint256 debtValue) = _calculateCollateralProperties(vaultCollateral[vaultID], vaultDebt[vaultID]);

        if(debtValue==0){
            return 0;
        }
        
        uint256 halfDebt = debtValue * debtRatio / (tokenPeg * 10000);

        return(halfDebt);
    }

    /**
     * @notice Calculates the collateral extraction on liquidation.
     * 
     * @param vaultID Id of the vault
     * @return uint256 Collateral extraction
     */
    function checkExtract(uint256 vaultID) public view override virtual returns (uint256) {

        if(vaultCollateral[vaultID] == 0|| !checkLiquidation(vaultID) ) {
            return 0;
        }

        (, uint256 debtValue) = _calculateCollateralProperties(vaultCollateral[vaultID], vaultDebt[vaultID]);

        uint256 halfDebt = debtValue * debtRatio / 10000;

        if(halfDebt==0){
            return 0;
        }
        // NOTE: this code assumes, that collateral price and token peg have equal decimals
        uint256 extract = halfDebt * gainRatio / (1000 * getEthPriceSource());
        return _correctDecimals(extract, collateral.decimals(), usdv.decimals());
    }

    /**
     * @notice Checks whether the vault`s collateral percentage would be valid after liquidation.
     *
     * @param vaultID ID of the vault to check
     * @return bool Is valid collateral percentage
     * @return uint256 collateral after liquidation
     * @return uint256 half debt
     * @return uint256 liquidation extract amount
     */
    function checkValid( uint256 vaultID ) public view returns(bool, uint256, uint256, uint256) {

        (, uint256 ogDebtValue) = _calculateCollateralProperties(vaultCollateral[vaultID], vaultDebt[vaultID] );

        uint256 halfDebt = ogDebtValue * debtRatio / 10000;

        uint256 extract = _correctDecimals(
            halfDebt * gainRatio / (1000 * getEthPriceSource()),
            collateral.decimals(),
            usdv.decimals()
        );

        uint256 newCollateral = vaultCollateral[vaultID] - extract;

        halfDebt = halfDebt / tokenPeg;

        return (isValidCollateral(newCollateral, halfDebt), newCollateral, halfDebt, extract);
    }

    /**
     * @notice Calculates collateral percentage.
     * 
     * @param vaultID Id of the vault to process
     * @return uint256 Collateral percentage
     */
    function checkCollateralPercentage(uint256 vaultID) public view returns(uint256){
        require(_exists(vaultID), "Vault does not exist");

        if(vaultCollateral[vaultID] == 0) {
            return 0;
        }

        if(vaultDebt[vaultID]==0) {
            return type(uint256).max;
        }

        (uint256 collateralValueTimes100, uint256 debtValue) = _calculateCollateralProperties(vaultCollateral[vaultID], vaultDebt[vaultID]);

        return collateralValueTimes100 / debtValue;
    }

    /**
     * @notice Calculates collateral percentage.
     *
     * @param vaultID Id of the vault to process
     * @return uint256 Collateral value times 100
     * @return uint256 Debt value
     */
    function checkCollat(uint256 vaultID) public view returns(uint256, uint256) {
        return _calculateCollateralProperties(vaultCollateral[vaultID], vaultDebt[vaultID] );
    }

    /**
     * @notice Checks usdv balance of specified address.
     *
     * @param _address Address to view
     * @return balance
     */
    function checkUSDVBalance(address _address) public view returns (uint256){
        return usdv.balanceOf(_address);
    }

    /**
     * @notice Checks if liquidation can be applied
     * 
     * @param vaultID Id of the vault
     */
    function checkLiquidation(uint256 vaultID) public view override returns (bool) {
        require(_exists(vaultID), "Vault does not exist");
        
        if(vaultCollateral[vaultID] == 0 || vaultDebt[vaultID]==0){
            return false;
        }

        uint256 collateralPercentage = checkCollateralPercentage(vaultID);

        return collateralPercentage < minimumCollateralPercentage;
    }

    /**
     * @notice Partially liquidates the vault. Gives some profit for caller which depends on 'gainRatio'. 
     * The liquidation percentage depends on 'debtRatio'.
     *
     * NOTE: Caller must give an approval to trasfer his tokens of stablecoin
     *
     * Requirements:
     * 
     * - The vault`s collateral-to-debt ratio is below the minimum percentage
     * - The vault must have debt
     * - The vault must exist
     * 
     * @param vaultID Id of the vault to liquidate
     */
    function liquidateVault(uint256 vaultID) external virtual override nonReentrant {
        require(_exists(vaultID), "Vault does not exist");
        require(stabilityPool==address(0) || msg.sender ==  stabilityPool, "liquidation is disabled for public");

        uint256 collateralPercentage = checkCollateralPercentage(vaultID);

        require(collateralPercentage < minimumCollateralPercentage, "Vault is not below minimum collateral percentage");

        uint256 halfDebt = checkCost(vaultID);

        require(usdv.balanceOf(msg.sender) >= halfDebt, "Token balance too low to pay off outstanding debt");

        supply -= halfDebt;
        usdv.burn(msg.sender, halfDebt);

        uint256 liquidationExtract = checkExtract(vaultID);

        vaultDebt[vaultID] = vaultDebt[vaultID] - halfDebt; // we paid back half of its debt.

        uint256 _closingFee = _calculateClosingFee(halfDebt, closingFee);
        
        vaultCollateral[vaultID]=vaultCollateral[vaultID] - _closingFee;
        vaultCollateral[treasury]=vaultCollateral[treasury] + _closingFee;

        // deduct the amount from the vault's collateral
        vaultCollateral[vaultID] = vaultCollateral[vaultID] - liquidationExtract;
        totalCollateral = totalCollateral - liquidationExtract - _closingFee;

        // let liquidator take the collateral
        liquidationDebt[msg.sender] = liquidationDebt[msg.sender] + liquidationExtract;

        emit LiquidateVault(vaultID, ownerOf(vaultID), msg.sender, halfDebt, liquidationExtract, _closingFee);
    }

    function _calculateClosingFee(uint256 amount, uint256 _closingFee) internal view returns(uint256) {
        uint8 usdvDecimals = usdv.decimals();
        uint8 collatDecimals = collateral.decimals();
        uint256 fee = amount * _closingFee * getTokenPriceSource() / (getEthPriceSource() * 10000);

        return _correctDecimals(fee, collatDecimals, usdvDecimals);
    }

    /**
     * @dev Converts token amount from decimalsB to decimalsA.
     * @param amount - input token amount
     * @param decimalsA - output token decimals
     * @param decimalsB - input token decimals
     * @return output token amount
     */
    function _correctDecimals(uint256 amount, uint8 decimalsA, uint8 decimalsB) internal pure returns(uint256) {
        return amount * 10**decimalsA / 10**decimalsB;
    }

    // Storage gap for upgrades
    uint256[34] private __gap;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./ERC20Stablecoin.sol";

/**
 * @title ERC20StablecoinEnhanced
 * @dev ERC20Stablecoin with admin functions
 */
contract ERC20StablecoinEnhanced is Initializable, ERC20Stablecoin, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    event UpdateGainRatio(uint256 prevValue, uint256 newValue);
    event UpdateDebtRatio(uint256 prevValue, uint256 newValue);
    event UpdateEthPriceSource(address prevValue, address newValue);
    event UpdateTokenPeg(uint256 prevValue, uint256 newValue);
    event UpdateStabilityPool(address prevValue, address newValue);
    event UpdateDebtCeiling(uint256 prevValue, uint256 newValue);
    event UpdateMinCollatPercentage(uint256 prevValue, uint256 newValue);
    event UpdateClosingFee(uint256 prevValue, uint256 newValue);
    event UpdatePaybackFee(uint256 prevValue, uint256 newValue);
    event UpdateTreasury(uint256 prevValue, uint256 newValue);

    /**
     * @notice contract initializer
     * @dev instead of constructor because of Upgradeable architecture
     * @param ethPriceSourceAddress collateral token price provider address
     * @param _minimumCollateralPercentage minimal collateral percentage below which a vault will be liquidated
     * @param name name of vaults pool
     * @param symbol symbol of vaults pool
     * @param _stablecoin usdv address
     * @param _collateral collateral token address
     * @param meta meta provider address
     */
    function initialize(
        address ethPriceSourceAddress,
        uint256 _minimumCollateralPercentage,
        string memory name,
        string memory symbol,
        address _stablecoin,
        address _collateral,
        address meta
    ) initializer virtual public  {
        __Ownable_init();
        __ERC20Stablecoin_init(
            ethPriceSourceAddress,
            _minimumCollateralPercentage,
            name,
            symbol,
            _stablecoin,
            _collateral,
            meta
        );
        treasury=0;
    }

    /**
     * @notice {gainRation} setter
     * Only for Owner
     * @param _gainRatio new gainRation
     */
    function setGainRatio(uint256 _gainRatio) external onlyOwner() {
        uint256 prevValue = gainRatio;
        gainRatio=_gainRatio;

        emit UpdateGainRatio(prevValue, _gainRatio);
    }

    /**
     * @notice {debtRation} setter
     * Only for Owner
     * @param _debtRatio new debtRation
     */
    function setDebtRatio(uint256 _debtRatio) external onlyOwner() {
        uint256 prevValue = debtRatio;
        debtRatio=_debtRatio;

        emit UpdateDebtRatio(prevValue, _debtRatio);
    }

    /**
     * @notice transfer external ERC20 {token} to {to} in {amountToken}
     * Only for Owner
     * @param to destination address
     * @param token token address
     * @param amountToken transfer amount
     */
    function transferToken(address to, address token, uint256 amountToken) external onlyOwner() {
        IERC20Upgradeable(token).safeTransfer(to, amountToken);
    }

    /**
     * @notice {ethPriceSource} setter
     * Only for Owner
     * @param ethPriceSourceAddress collateral price provider 
     * @param _priceSourceDecimals price decimals provided by {ethPriceSourceAddress}
     */
    function changeEthPriceSource(address ethPriceSourceAddress, uint8 _priceSourceDecimals) external onlyOwner() {
        address prevValue = address(ethPriceSource);

        ethPriceSource = IPriceSource(ethPriceSourceAddress);
        priceSourceDecimals = _priceSourceDecimals;

        emit UpdateEthPriceSource(prevValue, ethPriceSourceAddress);
    }
    /**
     * @notice {tokenPeg} setter
     * Only for Owner
     * @param _tokenPeg new tokenPeg
     */
    function setTokenPeg(uint256 _tokenPeg) external onlyOwner() {
        uint256 prevValue = tokenPeg;
        tokenPeg = _tokenPeg;

        emit UpdateTokenPeg(prevValue, _tokenPeg);
    }

    /**
     * @notice {stabilityPool} setter
     * Only for Owner
     * @param _pool new stabilityPool
     */
    function setStabilityPool(address _pool) external onlyOwner() {
        address prevValue = stabilityPool;
        stabilityPool = _pool;

        emit UpdateStabilityPool(prevValue, _pool);
    }

    /**
     * @notice {debtCeiling} setter
     * Only for Owner
     * @param amount new debtCeiliing
     */
    function setDebtCeiling(uint256 amount) external onlyOwner() {
        require(supply <= debtCeiling, "setDebtCeiling: Must be over the amount of outstanding debt.");

        uint256 prevValue = debtCeiling;
        debtCeiling = amount;

        emit UpdateDebtCeiling(prevValue, amount);
    }

    /**
     * @notice “minimumCollaterPercentage} setter
     * Only for Owner
     * @param _minimumCollateralPercentage new minimumCollateralPercentage
     */
    function setMinCollateralRatio(uint256 _minimumCollateralPercentage) external onlyOwner() {
        uint256 prevValue = minimumCollateralPercentage;
        minimumCollateralPercentage = _minimumCollateralPercentage;

        emit UpdateMinCollatPercentage(prevValue, _minimumCollateralPercentage);
    }

    /**
     * @notice {closingFee} setter
     * Only for Owner
     * @param amount new closingFee
     */
    function setClosingFee(uint256 amount) external onlyOwner() {
        uint256 prevValue = closingFee;
        closingFee = amount;

        emit UpdateClosingFee(prevValue, amount);
    }

    /**
     * @notice {paybackFee} setter
     * Only for Owner
     * @param amount new paybackFee
     */
    function setPaybackFee(uint256 amount) external onlyOwner() {
        uint256 prevValue = paybackFee;
        paybackFee = amount;

        emit UpdatePaybackFee(prevValue, amount);
    }

    /**
     * @notice {treasuryFee} setter
     * Only for Owner
     * @param _treasury new treasuryFee
     */
    function setTreasury(uint256 _treasury) external onlyOwner() {
        require(_exists(_treasury), "Vault does not exist");
        uint256 prevValue = treasury;
        treasury = _treasury;

        emit UpdateTreasury(prevValue, _treasury);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILiquidator {
    function liquidateVault(uint256 vaultId) external;
    function getPaid() external;
    function checkLiquidation(uint256 vaultID) external view returns (bool);
    function checkCost (uint256 vaultId) external view returns(uint256);
    function checkExtract (uint256 vaultId) external view returns(uint256);
    function closingFee() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceSource {
	function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVaultMetaProvider {
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVaultMetaRegistry {
    function getMetaProvider(address vault_address) external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IWrappedNative is IERC20 {
    function deposit() external payable returns (uint256);
    function withdraw(uint256 amount) external returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IYFVault {
    function deposit(uint256 _amount) external returns(uint256 shares);
    
    function withdraw(uint256 maxShares, address recipient, uint256 maxLoss) external returns(uint256 redeemed);

    function pricePerShare() external view returns(uint256);

    function token() external view returns(address);

    function decimals() external view returns(uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../interfaces/IWrappedNative.sol";

/**
 * @title WrappedAsset
 * @dev Allows one to call deposit and withdraw functions on different wrapped asset contracts,
 * such as WETH and WFTM. The calls will revert if functions return non zero
 * and will work as usual if functions return no value.
 */
library WrappedAsset {
    using AddressUpgradeable for address;

    uint256 public constant ERR_NO_ERROR = 0x0;

    /**
     * @dev makes sure that deposit will be succeeded
     * @param token native wrapper address
     * @param value deposit amount
     */
    function safeDeposit(IWrappedNative token, uint256 value) internal {
        bytes memory returndata = address(token).functionCallWithValue(
            abi.encodeWithSelector(token.deposit.selector), value, "WrappedAsset: low-level call failed"
        );
        if (returndata.length > 0) {
            // Return data is optional, revert on non-zero
            require(abi.decode(returndata, (uint256)) == ERR_NO_ERROR, "WrappedAsset: deposit did not succeed");
        }
    }

    /**
     * @dev makes sure that withdraw will be succeeded
     * @param token native wrapper address
     * @param amount withdraw amount
     */
    function safeWithdraw(IWrappedNative token, uint256 amount) internal {
        bytes memory returndata = address(token).functionCall(
            abi.encodeWithSelector(token.withdraw.selector, amount), "WrappedAsset: low-level call failed"
        );
        if (returndata.length > 0) {
            // Return data is optional, revert on non-zero
            require(abi.decode(returndata, (uint256)) == ERR_NO_ERROR, "WrappedAsset: withdraw did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../erc20Stablecoin/ERC20StablecoinEnhanced.sol";
import "../interfaces/IYFVault.sol";
import "../interfaces/IWrappedNative.sol";
import "../libraries/WrappedAsset.sol";


/**
 * @title StrategyVault
 * @notice Vauls storage with wrapping and unwrapping deposit token to Yearn Finance token
 */
contract StrategyVault is Initializable, ERC20StablecoinEnhanced {
    using SafeERC20Upgradeable for ERC20Upgradeable;
    using WrappedAsset for IWrappedNative;
    
    IWrappedNative public wrappedNative;
    /**
     * @notice strategy profit system fee 
     * @dev 5000 = 50%
     */
    uint256 public strategyProfitFee;
    uint256 public maxWithdrawingLossPercantage;

    /**
     * @notice initial amount of base token for profit calculation
     */
    mapping(uint256 => uint256) public initialCollateral;

    event YVExchanged(uint256 rate);
    event SystemStrategyFee(uint256 fee);
    event UpdateWithdrawingLoss(uint256 prevValue, uint256 newValue);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice contract initializer
     * @dev instead of constructor because of Upgradeable architecture
     * @param ethPriceSourceAddress collateral token price provider address
     * @param _minimumCollateralPercentage minimal collateral percentage below which a vault will be liquidated
     * @param name name of vaults pool
     * @param symbol symbol of vaults pool
     * @param _stablecoin usdv address
     * @param _collateral collateral token address
     * @param meta meta provider address
     * @param _wrappedNative native wrapper contract address
     */
    function initialize(
        address ethPriceSourceAddress,
        uint256 _minimumCollateralPercentage,
        string memory name,
        string memory symbol,
        address _stablecoin,
        address _collateral,
        address meta,
        IWrappedNative _wrappedNative,
        uint256 _maxWithdrawingLossPercantage
    ) public initializer {
        __Ownable_init();
        __ERC20Stablecoin_init(
            ethPriceSourceAddress,
            _minimumCollateralPercentage,
            name,
            symbol,
            _stablecoin,
            _collateral,
            meta
        );

        wrappedNative = _wrappedNative;
        maxWithdrawingLossPercantage = _maxWithdrawingLossPercantage;
        treasury=0;
        strategyProfitFee = 5000; // 50%
    }

    /**
     * @notice Wrap to YF Token and deposit collateral to specified 'vaultID'.
     *
     * NOTE: There isn`t check whether amount of deposited collateral > 0
     *
     * Requirements:
     *
     * - The vault must exist
     * - The caller is owner of vault
     *
     * @param vaultID Id of the vault
     * @param amount Collateral amount
     */
    function depositCollateral(uint256 vaultID, uint256 amount)
        external
        override
        onlyVaultOwner(vaultID)
        nonReentrant
    {
        IYFVault YFVault = IYFVault(address(collateral));
        ERC20Upgradeable sourceTokenAddress = ERC20Upgradeable(YFVault.token());

        sourceTokenAddress.safeTransferFrom(msg.sender, address(this), amount);
        _deposit(vaultID, amount);
    }

    /**
     * @notice Deposit native token and Wrap to YF Token and deposit collateral to specified 'vaultID'.
     *
     * NOTE: There isn`t check whether amount of deposited collateral > 0
     *
     * Requirements:
     *
     * - The vault must exist
     * - The caller is owner of vault
     *
     * @param vaultID Id of the vault
     */
    function depositCollateral(uint256 vaultID)
        external
        payable
        nonReentrant
        onlyVaultOwner(vaultID)
    {
        require(address(wrappedNative) != address(0), "Native deposit is not allowed");
        uint256 wrappedAmount = msg.value;

        wrappedNative.safeDeposit(wrappedAmount);

        _deposit(vaultID, wrappedAmount);
    }

    function _deposit(uint256 vaultID, uint256 amount) internal virtual {
        IYFVault YFVault = IYFVault(address(collateral));
        ERC20Upgradeable sourceTokenAddress = ERC20Upgradeable(YFVault.token());

        sourceTokenAddress.approve(address(YFVault), amount);
        uint256 shares = YFVault.deposit(amount);

        initialCollateral[vaultID] += amount;
        vaultCollateral[vaultID] += shares;
        totalCollateral += shares;

        emit DepositCollateral(vaultID, shares);
    }

    /**
     * @notice Destroys specified vault. Requires no loan for vault. Pays back the entire deposit, if any.
     * Emits event DestroyVault(vaultID)
     *
     * Requirements:
     *
     * - There is no outstanding debt.
     * - The vault must exist
     * - The caller is owner of the vault
     *
     * @param vaultID Id of vault to destroy
     */
    function destroyVault(uint256 vaultID)
        external
        override
        onlyVaultOwner(vaultID)
        nonReentrant
    {
        require(vaultDebt[vaultID] == 0, "Vault has outstanding debt");

        IYFVault YFVault = IYFVault(address(collateral));

        uint256 collat = vaultCollateral[vaultID];
        totalCollateral -= collat;


        delete vaultCollateral[vaultID];
        delete vaultDebt[vaultID];
        delete initialCollateral[vaultID];

        emit DestroyVault(vaultID);

        if(collat != 0) {
            // withdraw leftover collateral
            YFVault.withdraw(collat, ownerOf(vaultID), maxWithdrawingLossPercantage);
        }

        _burn(vaultID);
    }

    /**
     * @notice Withdraw collaterals from 'vaultID'.
     *
     * Requirements:
     *
     * - Withdrawal would not put vault below minimum colateral percentage
     * - The vault must exist
     * - The caller is owner of vault
     *
     * @param vaultID Id of vault
     * @param wrappedAmount amount of yvToken for withdrawing
     */
    function withdrawCollateral(uint256 vaultID, uint256 wrappedAmount)
        external
        override
        onlyVaultOwner(vaultID)
        nonReentrant
    {
        IYFVault YFVault = IYFVault(address(collateral));

        uint256 _strategyFee = _withdraw(vaultID, wrappedAmount);

        YFVault.withdraw(wrappedAmount - _strategyFee, ownerOf(vaultID), maxWithdrawingLossPercantage);

        emit WithdrawCollateral(vaultID, wrappedAmount);
    }

    /**
     * @notice Withdraw collaterals from 'vaultID' in Native Token.
     *
     * Requirements:
     *
     * - {wrappedNative} is set
     * - Withdrawal would not put vault below minimum colateral percentage
     * - The vault must exist
     * - The caller is owner of vault
     *
     * @param vaultID Id of vault
     * @param wrappedAmount amount of yvToken for withdrawing
     */
    function withdrawNativeCollateral(uint256 vaultID, uint256 wrappedAmount)
        external
        onlyVaultOwner(vaultID)
        nonReentrant
    {
        require(address(wrappedNative) != address(0), "Native is not allowed");

        IYFVault YFVault = IYFVault(address(collateral));

        uint256 _strategyFee = _withdraw(vaultID, wrappedAmount);

        uint256 redeemed = YFVault.withdraw(wrappedAmount - _strategyFee, address(this), maxWithdrawingLossPercantage);
        wrappedNative.safeWithdraw(redeemed);
        payable(msg.sender).transfer(redeemed);

        emit WithdrawCollateral(vaultID, wrappedAmount);
    }

    function _withdraw(uint256 vaultID, uint256 amount) internal returns(uint256) {
        uint256 collat = vaultCollateral[vaultID];
        uint256 newCollateral = collat - amount;
        require(collat >= newCollateral, "Vault does not have enough collateral");

        uint256 _strategyFee;
        if (vaultID == treasury) {
            _strategyFee = 0;
        } else {
            _strategyFee = _calculateStrategyFeeForVault(vaultID);
        }

        if(vaultDebt[vaultID] != 0) {
            require(isValidCollateral(newCollateral, vaultDebt[vaultID]), "Withdrawal would put vault below minimum collateral percentage");
        }

        vaultCollateral[vaultID] = newCollateral;
        totalCollateral = totalCollateral - amount;
        vaultCollateral[treasury] += _strategyFee;

        uint256 sourceTokenEquivalentAfterLiquidation = profitedCollateral(vaultID);
        initialCollateral[vaultID] = sourceTokenEquivalentAfterLiquidation;

        return _strategyFee;
    }

    /**
     * @notice Withdraws all liquidation profits 
     */
    function getPaid() external override nonReentrant {
        require(liquidationDebt[msg.sender] != 0, "Don't have anything for you.");

        IYFVault YFVault = IYFVault(address(collateral));

        uint256 amount = liquidationDebt[msg.sender];
        liquidationDebt[msg.sender] = 0;

        if (address(wrappedNative) == address(0)) {
            YFVault.withdraw(amount, msg.sender, maxWithdrawingLossPercantage);
        } else {
            uint256 redeemed = YFVault.withdraw(amount, address(this), maxWithdrawingLossPercantage);
            wrappedNative.safeWithdraw(redeemed);
            payable(msg.sender).transfer(redeemed);
        }

        uint256 exchangeRate = YFVault.pricePerShare();
        emit YVExchanged(exchangeRate);
    }

    /**
     * @notice Partially liquidates the vault. Gives some profit for caller which depends on 'gainRatio'. 
     * The liquidation percentage depends on 'debtRatio'.
     *
     * NOTE: Caller must give an approval to trasfer his tokens of stablecoin
     *
     * Requirements:
     * 
     * - The vault`s collateral-to-debt ratio is below the minimum percentage
     * - The vault must have debt
     * - The vault must exist
     * 
     * @param vaultID Id of the vault to liquidate
     */
    function liquidateVault(uint256 vaultID) external override nonReentrant {
        require(_exists(vaultID), "Vault does not exist");
        require(stabilityPool==address(0) || msg.sender ==  stabilityPool, "liquidation is disabled for public");

        uint256 collateralPercentage = checkCollateralPercentage(vaultID);

        require(collateralPercentage < minimumCollateralPercentage, "Vault is not below minimum collateral percentage");

        uint256 halfDebt = checkCost(vaultID);

        require(usdv.balanceOf(msg.sender) >= halfDebt, "Token balance too low to pay off outstanding debt");

        supply -= halfDebt;
        usdv.burn(msg.sender, halfDebt);

        uint256 liquidationExtract = super.checkExtract(vaultID);

        vaultDebt[vaultID] = vaultDebt[vaultID] - halfDebt; // we paid back half of its debt.

        uint256 _closingFee = _calculateClosingFee(halfDebt, closingFee);
        uint256 _strategyFee = _calculateStrategyFeeForVault(vaultID);

        vaultCollateral[vaultID] = vaultCollateral[vaultID] - _closingFee - _strategyFee;
        vaultCollateral[treasury] = vaultCollateral[treasury] + _closingFee + _strategyFee;

        // deduct the amount from the vault's collateral
        vaultCollateral[vaultID] = vaultCollateral[vaultID] - liquidationExtract;
        totalCollateral = totalCollateral - liquidationExtract - _closingFee - _strategyFee;

        // let liquidator take the collateral
        liquidationDebt[msg.sender] = liquidationDebt[msg.sender] + liquidationExtract;

        uint256 sourceTokenEquivalentAfterLiquidation = profitedCollateral(vaultID);
        initialCollateral[vaultID] = sourceTokenEquivalentAfterLiquidation;

        emit SystemStrategyFee(_strategyFee);
        emit LiquidateVault(vaultID, ownerOf(vaultID), msg.sender, halfDebt, liquidationExtract, _closingFee);
    }

    /**
     * @notice strategy profit
     * @param vaultID id of vault
     */
    function stratefyProfit(uint256 vaultID) public view returns(int256) {
        return int256(profitedCollateral(vaultID)) - int256(initialCollateral[vaultID]);
    }

    /**
     * @notice collateral converted to base token
     * @param vaultID id of vault
     * @return prfited amount
     */
    function profitedCollateral(uint256 vaultID) public view returns(uint256) {
        return _profitedCollateral(vaultCollateral[vaultID]);
    }
    
    function _profitedCollateral(uint256 collateralAmount) private view returns(uint256) {
        IYFVault YFVault = IYFVault(address(collateral));
        uint256 yvTokenRate = YFVault.pricePerShare();
        return collateralAmount * yvTokenRate / 10 ** YFVault.decimals();
    }

    /**
     * @notice return value of YFVault.pricePerShare(). Token - yvToken rate
     * @return yvToken price
     */
    function pricePerShare() external view returns(uint256) {
        IYFVault YFVault = IYFVault(address(collateral));
        return YFVault.pricePerShare();
    }

    /**
     * @notice Returns price of collateral token returned by priceOracle with address ethPriceSource.
     *         Convert it to yvToken price with YFVault.pricePerShare() rate
     * @return price
     */
    function getEthPriceSource() public view override returns (uint256){
        (,int256 price,,,) = ethPriceSource.latestRoundData();

        IYFVault YFVault = IYFVault(address(collateral));

        // convert price source decimals value to decimals of {tokenPeg}
        uint256 yvTokenPrice = uint256(price) * YFVault.pricePerShare();
        uint8 yvTokenPriceDecimals = priceSourceDecimals + uint8(YFVault.decimals());
        return _correctDecimals(yvTokenPrice, TOKEN_PEG_DECIMALS, yvTokenPriceDecimals);
    }

    /**
     * @notice calculate max debt limit for vault
     * @param vaultID id of a vault
     * @return max debt
     */
    function maxDebtForVault(uint256 vaultID) external view returns(uint256) {
        uint256 collateralAmount = vaultCollateral[vaultID];
        if (collateralAmount == 0) {
            return 0;
        }

        uint256 ethPrice = getEthPriceSource();
        uint256 tokenPrice = getTokenPriceSource();

        uint256 collateralValue = _correctDecimals(collateralAmount * ethPrice, usdv.decimals(), collateral.decimals());
        return collateralValue * 100 / minimumCollateralPercentage / tokenPrice;
    }

    /**
     * @notice calculate min collateral limit for vault
     * @param vaultID id of a vault
     * @return min collateral
     */
    function minCollateralForVault(uint256 vaultID) external view returns(uint256) {
        uint256 debt = vaultDebt[vaultID];
        if (debt == 0) {
            return vaultCollateral[vaultID];
        }

        uint256 ethPrice = getEthPriceSource();
        uint256 tokenPrice = getTokenPriceSource();

        uint256 debtValue = debt * tokenPrice;

        uint256 minCollateralValue = debtValue * minimumCollateralPercentage / 100;
        uint256 minCollateral = minCollateralValue / ethPrice;

        return minCollateral + 1;
    }

    /**
     * @notice Calculates the collateral extraction on liquidation.
     * 
     * @param vaultID Id of the vault
     * @return uint256 Collateral extraction
     */
    function checkExtract(uint256 vaultID) public view override virtual returns (uint256) {
        IYFVault YFVault = IYFVault(address(collateral));
        ERC20Upgradeable token = ERC20Upgradeable(YFVault.token());

        uint256 wrappedExtraction = super.checkExtract(vaultID);
        uint256 expectedUnwrappedExtraction = wrappedExtraction * YFVault.pricePerShare() / 10**YFVault.decimals();

        uint256 yfVaultBalance = token.balanceOf(address(YFVault));
        if (expectedUnwrappedExtraction > yfVaultBalance) {
            expectedUnwrappedExtraction -= expectedUnwrappedExtraction * maxWithdrawingLossPercantage / 10000;
        }
        
        return expectedUnwrappedExtraction;
    }

    /**
     * @notice {strategyProfitFee} setter
     * Only for Owner
     * @param fee new fee
     */
    function setStrategyProfitFee(uint256 fee) external onlyOwner {
        strategyProfitFee = fee;
    }

    /**
     * @notice {wrappedNative} setter
     * Only for Owner
     * @param _wrappedNative native token wrapper contract
     */
    function setWrappedNative(IWrappedNative _wrappedNative) external onlyOwner {
        wrappedNative = _wrappedNative;
    }

    /**
     * @notice {maxWithdrawingLossPercantage} setter
     * Only for Owner
     * @param _maxWithdrawingLossPercantage maximum yf vault withdrawing loss percentage
     */
    function setMaxWithdrawingLossPercantage(uint256 _maxWithdrawingLossPercantage) external onlyOwner {
        uint256 prevValue = maxWithdrawingLossPercantage;
        maxWithdrawingLossPercantage = _maxWithdrawingLossPercantage;

        emit UpdateWithdrawingLoss(prevValue, _maxWithdrawingLossPercantage);
    }

    function _calculateStrategyFeeForVault(uint256 vaultID) internal view returns (uint256) {
        IYFVault YFVault = IYFVault(address(collateral));
        int256 vaultStrategyProfitFact = stratefyProfit(vaultID);
        uint256 vaultStrategyProfit = vaultStrategyProfitFact > 0 ? uint256(vaultStrategyProfitFact) : 0;

        uint256 vaultStrategyProfitYV = vaultStrategyProfit * YFVault.decimals() / YFVault.pricePerShare();
        uint256 _strategyFee = _calculateClosingFee(vaultStrategyProfitYV, strategyProfitFee);
        return _strategyFee;
    }

    /**
     * @dev Payable fallback to allow this contract to receive protocol fee refunds.
     */
    receive() external payable {
        require(msg.sender != tx.origin, "Not allowed user transfer");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title USDV
 * @notice USDV stable coin contract
 */
contract USDV is Initializable, ERC20Upgradeable, AccessControlUpgradeable {
    bytes32 public constant MINT_BURN_ROLE = keccak256("MINT_BURN_ROLE");
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice contract initializer
     * @dev instead of constructor because of Upgradeable architecture
     */
    function initialize() external initializer {
        __ERC20_init("USDV", "USDV");
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice {OpenZeppelin-ERC20} mint tokens for {to} in {amount}
     * @dev usage limited {MINT_BURN_ROLE} role
     * @param to tokens destination address
     * @param amount amount of minting
     */
    function mint(address to, uint256 amount) external onlyRole(MINT_BURN_ROLE) {
        _mint(to, amount);
    }

    /**
     * @notice {OpenZeppelin-ERC20} burn tokens from {account} in {amount}
     * @dev usage limited {MINT_BURN_ROLE} role
     * @param account token owner address
     * @param amount amount of burning
     */
    function burn(address account, uint256 amount) external onlyRole(MINT_BURN_ROLE) {
        _burn(account, amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "./interfaces/IVaultMetaProvider.sol";
import "./interfaces/IVaultMetaRegistry.sol";


contract VaultNFTv3 is Initializable, ERC721Upgradeable {
    IVaultMetaRegistry public meta;

    function __VaultNFTv3_init(string memory name, string memory symbol, address _meta)
    onlyInitializing
    internal
    {
        __ERC721_init(name, symbol);
        meta = IVaultMetaRegistry(_meta);
    }

    /**
     * @notice returns tokenURI for {tokenId}
     * @param tokenId token id
     */
    function tokenURI(uint256 tokenId) public view override returns(string memory) {
       IVaultMetaProvider metaProvider = IVaultMetaProvider(meta.getMetaProvider(address(this)));
       return metaProvider.tokenURI(tokenId);
    }
}