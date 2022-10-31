// SPDX-License-Identifier: ISC
pragma solidity ^0.8.16;

import '@openzeppelin/contracts/access/AccessControl.sol';
import './FraxlendPair.sol';

contract FujinDeployer is AccessControl {
  event LendingDeployed(address pair, address deployer);

  address[] public lendings;
  mapping(address => address) public lendingDeployer;
  mapping(address => address[]) public deployerLendings;

  address public tokenManager;
  bytes public creationCode;

  error ZeroAddress();

  bytes32 SETTER_ROLE = keccak256('SETTER_ROLE');

  constructor(
    address _tokenManager,
    address _setter,
    address _admin
  ) {
    if (_tokenManager == address(0) || _setter == address(0) || _admin == address(0)) {
      revert ZeroAddress();
    }

    tokenManager = _tokenManager;

    _grantRole(SETTER_ROLE, _setter);
    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
  }

  function deployerLendingsCount(address deployer) external view returns (uint256) {
    return deployerLendings[deployer].length;
  }

  function deployLending(
    string memory _name,
    address _rateContract,
    bytes memory _immutables,
    uint256 _liquidationFee,
    bool _isBorrowerWhitelistActive,
    bool _isLenderWhitelistActive
  ) external returns (address lendingAddress) {
    bytes memory bytecode = abi.encodePacked(
      creationCode,
      abi.encode(
        _name,
        _rateContract,
        tokenManager,
        _immutables,
        _liquidationFee,
        _isBorrowerWhitelistActive,
        _isLenderWhitelistActive
      )
    );

    bytes32 salt = '';

    assembly {
      lendingAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
    }

    lendings.push(lendingAddress);
    lendingDeployer[lendingAddress] = msg.sender;
    deployerLendings[msg.sender].push(lendingAddress);

    emit LendingDeployed(lendingAddress, msg.sender);
  }

  function setTokenManager(address _tokenManager) external onlyRole(SETTER_ROLE) {
    tokenManager = _tokenManager;
    // todo event;
  }

  function setCreationCode(bytes memory _creationCode) external onlyRole(SETTER_ROLE) {
    creationCode = _creationCode;
    // todo event;
  }
}

// SPDX-License-Identifier: ISC
pragma solidity ^0.8.16;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ========================== FraxlendPair ============================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

// Primary Author
// Drake Evans: https://github.com/DrakeEvans

// Reviewers
// Dennis: https://github.com/denett
// Sam Kazemian: https://github.com/samkazemian
// Travis Moore: https://github.com/FortisFortuna
// Jack Corddry: https://github.com/corddry
// Rich Gee: https://github.com/zer0blockchain

// ====================================================================

import './FraxlendPairCore.sol';
import './libraries/VaultAccount.sol';

contract FraxlendPair is FraxlendPairCore {
  using VaultAccountingLibrary for VaultAccount;

  constructor(
    string memory _name,
    address _tokenManager,
    address _rateContract,
    bytes memory _immutables,
    uint256 _liquidationFee,
    bool _isBorrowerWhitelistActive,
    bool _isLenderWhitelistActive
  )
    FraxlendPairCore(
      _name,
      _tokenManager,
      _rateContract,
      _immutables,
      _liquidationFee,
      _isBorrowerWhitelistActive,
      _isLenderWhitelistActive
    )
    Ownable()
    Pausable()
  {}

  // ============================================================================================
  // Functions: Helpers
  // ============================================================================================

  function getConstants()
    external
    pure
    returns (
      uint256 _LTV_PRECISION,
      uint256 _LIQ_PRECISION,
      uint256 _UTIL_PREC,
      uint256 _FEE_PRECISION,
      uint256 _EXCHANGE_PRECISION,
      uint64 _DEFAULT_INT,
      uint256 _MAX_PROTOCOL_FEE
    )
  {
    _LTV_PRECISION = LTV_PRECISION;
    _LIQ_PRECISION = LIQ_PRECISION;
    _UTIL_PREC = UTIL_PREC;
    _FEE_PRECISION = FEE_PRECISION;
    _EXCHANGE_PRECISION = EXCHANGE_PRECISION;
    _DEFAULT_INT = DEFAULT_INT;
    _MAX_PROTOCOL_FEE = MAX_PROTOCOL_FEE;
  }

  /// @notice The ```getImmutableAddressBool``` function gets all the address and bool configs
  /// @return _rateContract Address of rate contract
  /// @return _DEPLOYER_CONTRACT Address of deployer contract
  /// @return _COMPTROLLER_ADDRESS Address of comptroller
  /// @return _borrowerWhitelistActive Boolean is borrower whitelist active
  /// @return _lenderWhitelistActive Boolean is lender whitelist active
  function getImmutableAddressBool()
    external
    view
    returns (
      address _rateContract,
      address _DEPLOYER_CONTRACT,
      address _COMPTROLLER_ADDRESS,
      bool _borrowerWhitelistActive,
      bool _lenderWhitelistActive
    )
  {
    _rateContract = address(rateContract);
    _DEPLOYER_CONTRACT = DEPLOYER_ADDRESS;
    _COMPTROLLER_ADDRESS = COMPTROLLER_ADDRESS;
    _borrowerWhitelistActive = borrowerWhitelistActive;
    _lenderWhitelistActive = lenderWhitelistActive;
  }

  /* need to rethink and rewrite them in new structure

    /// @notice The ```getUserSnapshot``` function gets user level accounting data
    /// @param _address The user address
    /// @return _userAssetShares The user fToken balance
    /// @return _userBorrowShares The user borrow shares
    /// @return _userCollateralBalance The user collateral balance
    function getUserSnapshot(address _address)
        external
        view
        returns (
            uint256 _userAssetShares,
            uint256 _userBorrowShares,
            uint256 _userCollateralBalance
        )
    {
        _userAssetShares = balanceOf(_address);
        _userBorrowShares = userBorrowShares[_address];
        _userCollateralBalance = userCollateralBalance[_address];
    }

    /// @notice The ```getPairAccounting``` function gets all pair level accounting numbers
    /// @return _totalAssetAmount Total assets deposited and interest accrued, total claims
    /// @return _totalAssetShares Total fTokens
    /// @return _totalBorrowAmount Total borrows
    /// @return _totalBorrowShares Total borrow shares
    /// @return _totalCollateral Total collateral
    function getPairAccounting()
        external
        view
        returns (
            uint128 _totalAssetAmount,
            uint128 _totalAssetShares,
            uint128 _totalBorrowAmount,
            uint128 _totalBorrowShares,
            uint256 _totalCollateral
        )
    {
        VaultAccount memory _totalAsset = totalAsset;
        _totalAssetAmount = _totalAsset.amount;
        _totalAssetShares = _totalAsset.shares;

        VaultAccount memory _totalBorrow = totalBorrow;
        _totalBorrowAmount = _totalBorrow.amount;
        _totalBorrowShares = _totalBorrow.shares;
        _totalCollateral = totalCollateral;
    }

*/

  /// @notice The ```toBorrowShares``` function converts a given amount of borrow debt into the number of shares
  /// @param _amount Amount of borrow
  /// @param _roundUp Whether to roundup during division
  function toBorrowShares(address _asset, uint256 _amount, bool _roundUp) external view returns (uint256) {
    return assets[_asset].totalBorrow.toShares(_amount, _roundUp);
  }

  /// @notice The ```toBorrowAmount``` function converts a given amount of borrow debt into the number of shares
  /// @param _shares Shares of borrow
  /// @param _roundUp Whether to roundup during division
  /// @return The amount of asset
  function toBorrowAmount(address _asset, uint256 _shares, bool _roundUp) external view returns (uint256) {
    return assets[_asset].totalBorrow.toAmount(_shares, _roundUp);
  }

  /// @notice The ```toAssetAmount``` function converts a given number of shares to an asset amount
  /// @param _shares Shares of asset (fToken)
  /// @param _roundUp Whether to round up after division
  /// @return The amount of asset
  function toAssetAmount(
    address _asset,
    uint256 _shares,
    bool _roundUp
  ) external view returns (uint256) {
    return assets[_asset].totalAsset.toAmount(_shares, _roundUp);
  }

  /// @notice The ```toAssetShares``` function converts a given asset amount to a number of asset shares (fTokens)
  /// @param _amount The amount of asset
  /// @param _roundUp Whether to round up after division
  /// @return The number of shares (fTokens)
  function toAssetShares(
    address _asset,
    uint256 _amount,
    bool _roundUp
  ) external view returns (uint256) {
    return assets[_asset].totalAsset.toShares(_amount, _roundUp);
  }

  // ============================================================================================
  // Functions: Configuration
  // ============================================================================================
  /// @notice The ```SetTimeLock``` event fires when the TIME_LOCK_ADDRESS is set
  /// @param _oldAddress The original address
  /// @param _newAddress The new address
  event SetTimeLock(address _oldAddress, address _newAddress);

  /// @notice The ```setTimeLock``` function sets the TIME_LOCK address
  /// @param _newAddress the new time lock address
  function setTimeLock(address _newAddress) external {
    if (msg.sender != TIME_LOCK_ADDRESS) revert OnlyTimeLock();
    emit SetTimeLock(TIME_LOCK_ADDRESS, _newAddress);
    TIME_LOCK_ADDRESS = _newAddress;
  }

  /// @notice The ```ChangeFee``` event first when the fee is changed
  /// @param _newFee The new fee
  event ChangeFee(uint32 _newFee);

  /// @notice The ```changeFee``` function changes the protocol fee, max 50%
  /// @param _newFee The new fee
  function changeFee(address token, uint32 _newFee) external whenNotPaused validAsset(token) {
    if (msg.sender != TIME_LOCK_ADDRESS) revert OnlyTimeLock();
    if (_newFee > MAX_PROTOCOL_FEE) {
      revert BadProtocolFee();
    }
    _addInterest(token);
    assets[token].currentRateInfo.feeToProtocolRate = _newFee;
    emit ChangeFee(_newFee);
  }

  /* Read this function exactly

  /// @notice The ```WithdrawFees``` event fires when the fees are withdrawn
  /// @param _shares Number of _shares (fTokens) redeemed
  /// @param _recipient To whom the assets were sent
  /// @param _amountToTransfer The amount of fees redeemed
  event WithdrawFees(uint128 _shares, address _recipient, uint256 _amountToTransfer);

  /// @notice The ```withdrawFees``` function withdraws fees accumulated
  /// @param _shares Number of fTokens to redeem
  /// @param _recipient Address to send the assets
  /// @return _amountToTransfer Amount of assets sent to recipient
  function withdrawFees(uint128 _shares, address _recipient) external onlyOwner returns (uint256 _amountToTransfer) {
    // Grab some data from state to save gas
    VaultAccount memory _totalAsset = totalAsset;
    VaultAccount memory _totalBorrow = totalBorrow;

    // Take all available if 0 value passed
    if (_shares == 0) _shares = uint128(balanceOf(address(this)));

    // We must calculate this before we subtract from _totalAsset or invoke _burn
    _amountToTransfer = _totalAsset.toAmount(_shares, true);

    // Check for sufficient withdraw liquidity
    uint256 _assetsAvailable = _totalAssetAvailable(_totalAsset, _totalBorrow);
    if (_assetsAvailable < _amountToTransfer) {
      revert InsufficientAssetsInContract(_assetsAvailable, _amountToTransfer);
    }

    // Effects: bookkeeping
    _totalAsset.amount -= uint128(_amountToTransfer);
    _totalAsset.shares -= _shares;

    // Effects: write to states
    // NOTE: will revert if _shares > balanceOf(address(this))
    _burn(address(this), _shares);
    totalAsset = _totalAsset;

    // Interactions
    assetContract.safeTransfer(_recipient, _amountToTransfer);
    emit WithdrawFees(_shares, _recipient, _amountToTransfer);
  }

  */

  /// @notice The ```SetSwapper``` event fires whenever a swapper is black or whitelisted
  /// @param _swapper The swapper address
  /// @param _approval The approval
  event SetSwapper(address _swapper, bool _approval);

  /// @notice The ```setSwapper``` function is called to black or whitelist a given swapper address
  /// @dev
  /// @param _swapper The swapper address
  /// @param _approval The approval
  function setSwapper(address _swapper, bool _approval) external onlyOwner {
    swappers[_swapper] = _approval;
    emit SetSwapper(_swapper, _approval);
  }

  /// @notice The ```SetApprovedLender``` event fires when a lender is black or whitelisted
  /// @param _address The address
  /// @param _approval The approval
  event SetApprovedLender(address indexed _address, bool _approval);

  /// @notice The ```setApprovedLenders``` function sets a given set of addresses to the whitelist
  /// @dev Cannot black list self
  /// @param _lenders The addresses who's status will be set
  /// @param _approval The approval status
  function setApprovedLenders(address[] calldata _lenders, bool _approval) external approvedLender(msg.sender) {
    for (uint256 i = 0; i < _lenders.length; i++) {
      // Do not set when _approval == false and _lender == msg.sender
      if (_approval || _lenders[i] != msg.sender) {
        approvedLenders[_lenders[i]] = _approval;
        emit SetApprovedLender(_lenders[i], _approval);
      }
    }
  }

  /// @notice The ```SetApprovedBorrower``` event fires when a borrower is black or whitelisted
  /// @param _address The address
  /// @param _approval The approval
  event SetApprovedBorrower(address indexed _address, bool _approval);

  /// @notice The ```setApprovedBorrowers``` function sets a given array of addresses to the whitelist
  /// @dev Cannot black list self
  /// @param _borrowers The addresses who's status will be set
  /// @param _approval The approval status
  function setApprovedBorrowers(address[] calldata _borrowers, bool _approval) external approvedBorrower {
    for (uint256 i = 0; i < _borrowers.length; i++) {
      // Do not set when _approval == false and _borrower == msg.sender
      if (_approval || _borrowers[i] != msg.sender) {
        approvedBorrowers[_borrowers[i]] = _approval;
        emit SetApprovedBorrower(_borrowers[i], _approval);
      }
    }
  }

  function pause() external {
    if (
      msg.sender != CIRCUIT_BREAKER_ADDRESS &&
      msg.sender != COMPTROLLER_ADDRESS &&
      msg.sender != owner() &&
      msg.sender != DEPLOYER_ADDRESS
    ) {
      revert ProtocolOrOwnerOnly();
    }
    _addInterestAll(); // accrue any interest prior to pausing as it won't accrue during pause
    _pause();
  }

  function unpause() external {
    if (msg.sender != COMPTROLLER_ADDRESS && msg.sender != owner()) {
      revert ProtocolOrOwnerOnly();
    }
    // Resets the lastTimestamp which has the effect of no interest accruing over the pause period
    _addInterestAll();
    _unpause();
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControl.sol";
import "../utils/Context.sol";
import "../utils/Strings.sol";
import "../utils/introspection/ERC165.sol";

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
abstract contract AccessControl is Context, IAccessControl, ERC165 {
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
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
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
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
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
}

// SPDX-License-Identifier: ISC
pragma solidity ^0.8.16;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ========================= FraxlendPairCore =========================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

// Primary Author
// Drake Evans: https://github.com/DrakeEvans

// Reviewers
// Dennis: https://github.com/denett
// Sam Kazemian: https://github.com/samkazemian
// Travis Moore: https://github.com/FortisFortuna
// Jack Corddry: https://github.com/corddry
// Rich Gee: https://github.com/zer0blockchain

// ====================================================================

import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeCast.sol';
import './FraxlendPairConstants.sol';
import './libraries/SafeERC20.sol';
import './interfaces/ISwapper.sol';
import './interfaces/IFraxlendPairCore.sol';

/// @title FraxlendPairCore
/// @author Drake Evans (Frax Finance) https://github.com/drakeevans
/// @notice  An abstract contract which contains the core logic and storage for the FraxlendPair
abstract contract FraxlendPairCore is IFraxlendPairCore, FraxlendPairConstants, Ownable, Pausable, ReentrancyGuard {
  using VaultAccountingLibrary for VaultAccount;
  using SafeERC20 for IERC20;
  using SafeCast for uint256;

  string public version = '1.0.0';

  // ============================================================================================
  // Settings set by constructor() & initialize()
  // ============================================================================================

  // Asset and collateral contracts
  // IERC20 internal immutable assetContract;
  // IERC20 public immutable collateralContract;

  // asset => user => amount
  mapping(address => mapping(address => uint256)) public userBorrowShares;

  // collateral => user => amount
  mapping(address => mapping(address => uint256)) public userCollateralBalance; // userCollateralBalance

  address[] public collateralsList;
  mapping(address => Collateral) public collaterals;

  address[] public assetsList;
  mapping(address => Asset) public assets;

  // Liquidation Fee
  uint256 public immutable liquidationFee;

  // Interest Rate Calculator Contract
  IRateCalculator public immutable rateContract; // For complex rate calculations
  bytes public rateInitCallData; // Optional extra data from init function to be passed to rate calculator

  // Swapper
  mapping(address => bool) public swappers; // approved swapper addresses

  // Deployer
  address public immutable DEPLOYER_ADDRESS;

  // Admin contracts
  address public immutable CIRCUIT_BREAKER_ADDRESS;
  address public immutable COMPTROLLER_ADDRESS;
  address public TIME_LOCK_ADDRESS;

  string public name;

  // ============================================================================================
  // Storage
  // ============================================================================================

  /// @notice Stores information about the current exchange rate. Collateral:Asset ratio
  /// @dev Struct packed to save SLOADs. Amount of Collateral Token to buy 1e18 Asset Token
  ExchangeRateInfo public exchangeRateInfo;
  struct ExchangeRateInfo {
    uint32 lastTimestamp;
    uint224 exchangeRate; // collateral:asset ratio. i.e. how much collateral to buy 1e18 asset
  }

  // Contract Level Accounting
  // VaultAccount public totalAsset; // amount = total amount of assets, shares = total shares outstanding
  // VaultAccount public totalBorrow; // amount = total borrow amount with interest accrued, shares = total shares outstanding
  // uint256 public totalCollateral; // total amount of collateral in contract

  // User Level Accounting
  /// @notice Stores the balance of collateral for each user
  //   mapping(address => uint256) public userCollateralBalance; // amount of collateral each user is backed
  /// @notice Stores the balance of borrow shares for each user
  //   mapping(address => uint256) public userBorrowShares; // represents the shares held by individuals
  // NOTE: user shares of assets are represented as ERC-20 tokens and accessible via balanceOf()

  // Internal Whitelists
  bool public immutable borrowerWhitelistActive;
  mapping(address => bool) public approvedBorrowers;

  bool public immutable lenderWhitelistActive;
  mapping(address => bool) public approvedLenders;

  bool public isInitialized;

  address public tokenManager;

  // ============================================================================================
  // Initialize
  // ============================================================================================

  /// @notice The ```constructor``` function is called on deployment
  /// @param _rateContract The address of the rate calculator contract
  /// @param _liquidationFee The fee paid to liquidators given as a % of the repayment (1e5 precision)
  /// @param _isBorrowerWhitelistActive Enables borrower whitelist
  /// @param _isLenderWhitelistActive Enables lender whitelist
  constructor(
    string memory _name,
    address _rateContract,
    address _tokenManager,
    bytes memory _immutables,
    uint256 _liquidationFee,
    bool _isBorrowerWhitelistActive,
    bool _isLenderWhitelistActive
  ) {
    // Handle Immutables Configuration
    {
      (address _circuitBreaker, address _comptrollerAddress, address _timeLockAddress) = abi.decode(
        _immutables,
        (address, address, address)
      );

      // Deployer contract
      DEPLOYER_ADDRESS = msg.sender;
      CIRCUIT_BREAKER_ADDRESS = _circuitBreaker;
      COMPTROLLER_ADDRESS = _comptrollerAddress;
      TIME_LOCK_ADDRESS = _timeLockAddress;
    }

    {
      // Pair Settings
      // currentRateInfo.feeToProtocolRate = DEFAULT_PROTOCOL_FEE;
      liquidationFee = _liquidationFee;

      rateContract = IRateCalculator(_rateContract);
    }

    // Set approved borrowers whitelist
    borrowerWhitelistActive = _isBorrowerWhitelistActive;

    // Set approved lenders whitelist active
    lenderWhitelistActive = _isLenderWhitelistActive;

    // set token manager
    tokenManager = _tokenManager;

    // Set name
    if (bytes(_name).length == 0) {
      revert NameEmpty();
    }

    name = _name;
  }

  error DuplicateToken(address token);

  function defineCollaterals(Collateral[] memory _collaterals) external onlyTokenManager {
    // revert if initialized before
    if (isInitialized) {
      revert AlreadyInitialized();
    }

    for (uint256 i; i < _collaterals.length; i++) {
      Collateral memory collateral = _collaterals[i];
      address tokenAddress = address(collateral.token);

      if (collateral.ltv > LTV_PRECISION) revert LTVTooHigh(collateral.ltv);

      if (address(collaterals[tokenAddress].token) != address(0)) revert DuplicateToken(tokenAddress);

      collateralsList.push(tokenAddress);
      collaterals[tokenAddress] = collateral;
    }
  }

  function defineAssets(Asset[] memory _assets) external onlyTokenManager {
    // revert if contract is already initialized
    if (isInitialized) revert AlreadyInitialized();

    for (uint256 i; i < _assets.length; i++) {
      address tokenAddress = address(_assets[i].token);
      if (address(assets[tokenAddress].token) != address(0)) revert DuplicateToken(tokenAddress);
      assetsList.push(tokenAddress);
      assets[tokenAddress] = _assets[i];
    }
  }

  error NoAssetsOrCollaterals();

  /// @notice The ```initialize``` function is called immediately after deployment
  /// @dev This function can only be called by the deployer
  /// @param _approvedBorrowers An array of approved borrower addresses
  /// @param _approvedLenders An array of approved lender addresses
  /// @param _rateInitCallData The configuration data for the Rate Calculator contract
  function initialize(
    address[] calldata _approvedBorrowers,
    address[] calldata _approvedLenders,
    bytes calldata _rateInitCallData
  ) external onlyDeployer {
    if (isInitialized) {
      revert AlreadyInitialized();
    }

    // if not assets or collaterals are defined revert
    if (assetsList.length == 0 || collateralsList.length == 0) {
      revert NoAssetsOrCollaterals();
    }

    // Set approved borrowers
    for (uint256 i = 0; i < _approvedBorrowers.length; ++i) {
      approvedBorrowers[_approvedBorrowers[i]] = true;
    }

    // Set approved lenders
    for (uint256 i = 0; i < _approvedLenders.length; ++i) {
      approvedLenders[_approvedLenders[i]] = true;
    }

    // Reverts if init data is not valid
    IRateCalculator(rateContract).requireValidInitData(_rateInitCallData);

    // Set rate init Data
    rateInitCallData = _rateInitCallData;

    // Instantiate Interest
    _addInterestAll();

    isInitialized = true;
  }

  // ============================================================================================
  // Internal Helpers
  // ============================================================================================

  /// @notice The ```_totalAssetAvailable``` function returns the total balance of Asset Tokens in the contract
  /// @param _totalAsset VaultAccount struct which stores total amount and shares for assets
  /// @param _totalBorrow VaultAccount struct which stores total amount and shares for borrows
  /// @return The balance of Asset Tokens held by contract
  function _totalAssetAvailable(VaultAccount memory _totalAsset, VaultAccount memory _totalBorrow)
    internal
    pure
    returns (uint256)
  {
    return _totalAsset.amount - _totalBorrow.amount;
  }

  function tokenValue(Asset memory token, uint256 amount) public view returns (uint256 value) {
    (, int256 price, , , ) = token.oracle.latestRoundData();
    value = (((amount) * uint256(price)) * 10**(36 - token.tokenDecimals - token.oracleDecimals)) / 1e18;
  }

  function tokenValue(Collateral memory token, uint256 amount) public view returns (uint256 value) {
    (, int256 price, , , ) = token.oracle.latestRoundData();
    value = (((amount) * uint256(price)) * 10**(36 - token.tokenDecimals - token.oracleDecimals)) / 1e18;
  }

  function effectiveCollateralValue(address _borrower) public view returns (uint256 totalValue) {
    for (uint8 i = 0; i < collateralsList.length; i++) {
      Collateral storage collateral = collaterals[collateralsList[i]];
      uint256 _userBalance = userCollateralBalance[address(collateral.token)][_borrower];
      if (_userBalance != 0) {
        uint256 userCollateralValue = tokenValue(collateral, _userBalance);
        totalValue += (userCollateralValue * collateral.ltv) / LTV_PRECISION;
      }
    }
  }

  function totalBorrowedValue(address _borrower) public view returns (uint256 requiredValue) {
    for (uint8 i = 0; i < assetsList.length; i++) {
      Asset storage asset = assets[assetsList[i]];
      uint256 userBorrowShare = userBorrowShares[address(asset.token)][_borrower];
      if (userBorrowShare != 0) {
        uint256 userBorrow = asset.totalBorrow.toAmount(userBorrowShare, true);
        uint256 userBorrowValue = tokenValue(asset, userBorrow);
        requiredValue += userBorrowValue;
      }
    }
  }

  /// @notice The ```_isSolvent``` function determines if a given borrower is solvent given an exchange rate
  /// @param _borrower The borrower address to check
  /// @return Whether borrower is solvent
  function _isSolvent(address _borrower) internal view returns (bool) {
    return totalBorrowedValue(_borrower) <= effectiveCollateralValue(_borrower);
  }

  // ============================================================================================
  // Modifiers
  // ============================================================================================

  modifier onlyTokenManager() {
    if (msg.sender != tokenManager) {
      revert OnlyTokenManager();
    }
    _;
  }

  modifier onlyDeployer() {
    if (msg.sender != DEPLOYER_ADDRESS) {
      revert NotDeployer();
    }
    _;
  }

  /// @notice Checks for solvency AFTER executing contract code
  /// @param _borrower The borrower whose solvency we will check
  modifier isSolvent(address _borrower) {
    _;
    if (!_isSolvent(_borrower)) {
      revert Insolvent();
    }
  }

  /// @notice Checks if msg.sender is an approved Borrower
  modifier approvedBorrower() {
    if (borrowerWhitelistActive && !approvedBorrowers[msg.sender]) {
      revert OnlyApprovedBorrowers();
    }
    _;
  }

  /// @notice Checks if msg.sender and _receiver are both an approved Lender
  /// @param _receiver An additional receiver address to check
  modifier approvedLender(address _receiver) {
    if (lenderWhitelistActive && (!approvedLenders[msg.sender] || !approvedLenders[_receiver])) {
      revert OnlyApprovedLenders();
    }
    _;
  }

  error InvalidToken(address token);

  modifier validAsset(address token) {
    if (address(assets[token].token) == address(0)) {
      revert InvalidToken(token);
    }
    _;
  }

  modifier validCollateral(address token) {
    if (address(collaterals[token].token) == address(0)) {
      revert InvalidToken(token);
    }
    _;
  }

  // ============================================================================================
  // Functions: Interest Accumulation and Adjustment
  // ============================================================================================

  /// @notice The ```AddInterest``` event is emitted when interest is accrued by borrowers
  /// @param _interestEarned The total interest accrued by all borrowers
  /// @param _rate The interest rate used to calculate accrued interest
  /// @param _deltaTime The time elapsed since last interest accrual
  /// @param _feesAmount The amount of fees paid to protocol
  /// @param _feesShare The amount of shares distributed to protocol
  event AddInterest(uint256 _interestEarned, uint256 _rate, uint256 _deltaTime, uint256 _feesAmount, uint256 _feesShare);

  /// @notice The ```UpdateRate``` event is emitted when the interest rate is updated
  /// @param _ratePerSec The old interest rate (per second)
  /// @param _deltaTime The time elapsed since last update
  /// @param _utilizationRate The utilization of assets in the Pair
  /// @param _newRatePerSec The new interest rate (per second)
  event UpdateRate(uint256 _ratePerSec, uint256 _deltaTime, uint256 _utilizationRate, uint256 _newRatePerSec);

  /// @notice The ```addInterest``` function is a public implementation of _addInterest and allows 3rd parties to trigger interest accrual
  /// @return _interestEarned The amount of interest accrued by all borrowers
  function addInterest(address token)
    external
    nonReentrant
    returns (
      uint256 _interestEarned,
      uint256 _feesAmount,
      uint256 _feesShare,
      uint64 _newRate
    )
  {
    return _addInterest(token);
  }

  /// @notice The ```_addInterest``` function is invoked prior to every external function and is used to accrue interest and update interest rate
  /// @dev Can only called once per block
  /// @return _interestEarned The amount of interest accrued by all borrowers
  function _addInterest(address token)
    internal
    returns (
      uint256 _interestEarned,
      uint256 _feesAmount,
      uint256 _feesShare,
      uint64 _newRate
    )
  {
    Asset storage asset = assets[token];
    // Add interest only once per block
    CurrentRateInfo memory _currentRateInfo = asset.currentRateInfo;
    if (_currentRateInfo.lastTimestamp == block.timestamp) {
      _newRate = _currentRateInfo.ratePerSec;
      return (_interestEarned, _feesAmount, _feesShare, _newRate);
    }

    // Pull some data from storage to save gas
    VaultAccount memory _totalAsset = asset.totalAsset;
    VaultAccount memory _totalBorrow = asset.totalBorrow;

    // If there are no borrows or contract is paused, no interest accrues and we reset interest rate
    if (_totalBorrow.shares == 0 || paused()) {
      if (!paused()) {
        _currentRateInfo.ratePerSec = DEFAULT_INT;
      }
      _currentRateInfo.lastTimestamp = uint64(block.timestamp);
      _currentRateInfo.lastBlock = uint64(block.number);

      // Effects: write to storage
      asset.currentRateInfo = _currentRateInfo;
    } else {
      // We know totalBorrow.shares > 0
      uint256 _deltaTime = block.timestamp - _currentRateInfo.lastTimestamp;

      // NOTE: Violates Checks-Effects-Interactions pattern
      // Be sure to mark external version NONREENTRANT (even though rateContract is trusted)
      // Calc new rate
      uint256 _utilizationRate = (UTIL_PREC * _totalBorrow.amount) / _totalAsset.amount;
      bytes memory _rateData = abi.encode(
        _currentRateInfo.ratePerSec,
        _deltaTime,
        _utilizationRate,
        block.number - _currentRateInfo.lastBlock
      );
      _newRate = IRateCalculator(rateContract).getNewRate(_rateData, rateInitCallData);

      // Event must be here to use non-mutated values
      emit UpdateRate(_currentRateInfo.ratePerSec, _deltaTime, _utilizationRate, _newRate);

      // Effects: bookkeeping
      _currentRateInfo.ratePerSec = _newRate;
      _currentRateInfo.lastTimestamp = uint64(block.timestamp);
      _currentRateInfo.lastBlock = uint64(block.number);

      // Calculate interest accrued
      _interestEarned = (_deltaTime * _totalBorrow.amount * _currentRateInfo.ratePerSec) / 1e18;

      // Accumulate interest and fees, only if no overflow upon casting
      if (
        _interestEarned + _totalBorrow.amount <= type(uint128).max && _interestEarned + _totalAsset.amount <= type(uint128).max
      ) {
        _totalBorrow.amount += uint128(_interestEarned);
        _totalAsset.amount += uint128(_interestEarned);
        if (_currentRateInfo.feeToProtocolRate > 0) {
          _feesAmount = (_interestEarned * _currentRateInfo.feeToProtocolRate) / FEE_PRECISION;

          _feesShare = (_feesAmount * _totalAsset.shares) / (_totalAsset.amount - _feesAmount);

          // Effects: Give new shares to this contract, effectively diluting lenders an amount equal to the fees
          // We can safely cast because _feesShare < _feesAmount < interestEarned which is always less than uint128
          _totalAsset.shares += uint128(_feesShare);

          // Effects: write to storage
          asset.fToken.mint(address(this), _feesShare);
        }
        emit AddInterest(_interestEarned, _currentRateInfo.ratePerSec, _deltaTime, _feesAmount, _feesShare);
      }

      // Effects: write to storage
      asset.totalAsset = _totalAsset;
      asset.currentRateInfo = _currentRateInfo;
      asset.totalBorrow = _totalBorrow;
    }
  }

  function _addInterestAll() internal {
    for (uint256 i = 0; i < assetsList.length; i++) {
      _addInterest(assetsList[i]);
    }
  }

  // ============================================================================================
  // Functions: Lending
  // ============================================================================================

  /// @notice The ```Deposit``` event fires when a user deposits assets to the pair
  /// @param caller the msg.sender
  /// @param owner the account the fTokens are sent to
  /// @param assets the amount of assets deposited
  /// @param shares the number of fTokens minted
  event Deposit(address indexed asset, address indexed caller, address indexed owner, uint256 assets, uint256 shares);

  /// @notice The ```_deposit``` function is the internal implementation for lending assets
  /// @dev Caller must invoke ```ERC20.approve``` on the Asset Token contract prior to calling function
  /// @param _amount The amount of Asset Token to be transferred
  /// @param _shares The amount of Asset Shares (fTokens) to be minted
  /// @param _receiver The address to receive the Asset Shares (fTokens)
  function _deposit(
    address token,
    uint128 _amount,
    uint128 _shares,
    address _receiver
  ) internal validAsset(token) {
    Asset storage asset = assets[token];
    asset.totalAsset.amount += _amount;
    asset.totalAsset.shares += _shares;

    asset.fToken.mint(_receiver, _shares);

    asset.token.safeTransferFrom(msg.sender, address(this), _amount);
    emit Deposit(token, msg.sender, _receiver, _amount, _shares);
  }

  /// @notice The ```deposit``` function allows a user to Lend Assets by specifying the amount of Asset Tokens to lend
  /// @dev Caller must invoke ```ERC20.approve``` on the Asset Token contract prior to calling function
  /// @param _amount The amount of Asset Token to transfer to Pair
  /// @param _receiver The address to receive the Asset Shares (fTokens)
  /// @return _sharesReceived The number of fTokens received for the deposit
  function deposit(
    address token,
    uint256 _amount,
    address _receiver
  ) external nonReentrant whenNotPaused approvedLender(_receiver) returns (uint256 _sharesReceived) {
    _addInterest(token);
    _sharesReceived = assets[token].totalAsset.toShares(_amount, false);
    _deposit(token, _amount.toUint128(), _sharesReceived.toUint128(), _receiver);
  }

  /// @notice The ```Withdraw``` event fires when a user redeems their fTokens for the underlying asset
  /// @param caller the msg.sender
  /// @param receiver The address to which the underlying asset will be transferred to
  /// @param assets The assets transferred
  /// @param shares The number of fTokens burned
  event Withdraw(address token, address indexed caller, address indexed receiver, uint256 assets, uint256 shares);

  /// @notice The ```_redeem``` function is an internal implementation which allows a Lender to pull their Asset Tokens out of the Pair
  /// @dev Caller must invoke ```ERC20.approve``` on the Asset Token contract prior to calling function
  /// @param _amountToReturn The number of Asset Tokens to return
  /// @param _shares The number of Asset Shares (fTokens) to burn
  /// @param _receiver The address to which the Asset Tokens will be transferred
  function _redeem(
    address token,
    uint128 _amountToReturn,
    uint128 _shares,
    address _receiver
  ) internal validAsset(token) {
    Asset storage asset = assets[token];
    // Check for sufficient withdraw liquidity
    uint256 _assetsAvailable = _totalAssetAvailable(asset.totalAsset, asset.totalBorrow);
    if (_assetsAvailable < _amountToReturn) {
      revert InsufficientAssetsInContract(_assetsAvailable, _amountToReturn);
    }
    // Effects: bookkeeping
    asset.totalAsset.amount -= _amountToReturn;
    asset.totalAsset.shares -= _shares;
    asset.fToken.burnFrom(msg.sender, _shares);
    // Interactions
    asset.token.safeTransfer(_receiver, _amountToReturn);
    emit Withdraw(address(asset.token), msg.sender, _receiver, _amountToReturn, _shares);
  }

  /// @notice The ```redeem``` function allows the caller to redeem their Asset Shares for Asset Tokens
  /// @param _shares The number of Asset Shares (fTokens) to burn for Asset Tokens
  /// @param _receiver The address to which the Asset Tokens will be transferred
  /// @return _amountToReturn The amount of Asset Tokens to be transferred
  function redeem(
    address token,
    uint256 _shares,
    address _receiver
  ) external nonReentrant returns (uint256 _amountToReturn) {
    _addInterest(token);
    _amountToReturn = assets[token].totalAsset.toAmount(_shares, false);
    _redeem(token, _amountToReturn.toUint128(), _shares.toUint128(), _receiver);
  }

  // ============================================================================================
  // Functions: Borrowing
  // ============================================================================================

  /// @notice The ```BorrowAsset``` event is emitted when a borrower increases their position
  /// @param _borrower The borrower whose account was debited
  /// @param _receiver The address to which the Asset Tokens were transferred
  /// @param _borrowAmount The amount of Asset Tokens transferred
  /// @param _sharesAdded The number of Borrow Shares the borrower was debited
  event BorrowAsset(
    address token,
    address indexed _borrower,
    address indexed _receiver,
    uint256 _borrowAmount,
    uint256 _sharesAdded
  );

  /// @notice The ```_borrowAsset``` function is the internal implementation for borrowing assets
  /// @param _borrowAmount The amount of the Asset Token to borrow
  /// @param _receiver The address to receive the Asset Tokens
  /// @return _sharesAdded The amount of borrow shares the msg.sender will be debited
  function _borrowAsset(
    address token,
    uint128 _borrowAmount,
    address _receiver
  ) internal validAsset(token) returns (uint256 _sharesAdded) {
    Asset storage asset = assets[token];
    VaultAccount memory _totalBorrow = asset.totalBorrow;

    // Check available capital
    uint256 _assetsAvailable = _totalAssetAvailable(asset.totalAsset, _totalBorrow);
    if (_assetsAvailable < _borrowAmount) {
      revert InsufficientAssetsInContract(_assetsAvailable, _borrowAmount);
    }

    // Effects: Bookkeeping to add shares & amounts to total Borrow accounting
    _sharesAdded = _totalBorrow.toShares(_borrowAmount, true);
    _totalBorrow.amount += _borrowAmount;
    _totalBorrow.shares += uint128(_sharesAdded);
    // NOTE: we can safely cast here because shares are always less than amount and _borrowAmount is uint128

    // Effects: write back to storage
    asset.totalBorrow = _totalBorrow;
    userBorrowShares[address(asset.token)][msg.sender] += _sharesAdded;

    // Interactions
    if (_receiver != address(this)) {
      asset.token.safeTransfer(_receiver, _borrowAmount);
    }
    emit BorrowAsset(token, msg.sender, _receiver, _borrowAmount, _sharesAdded);
  }

  /// @notice The ```borrowAsset``` function allows a user to open/increase a borrow position
  /// @dev Borrower must call ```ERC20.approve``` on the Collateral Token contract if applicable
  /// @param _borrowAmount The amount of Asset Token to borrow
  /// @param _collateralAmount The amount of Collateral Token to transfer to Pair
  /// @param _receiver The address which will receive the Asset Tokens
  /// @return _shares The number of borrow Shares the msg.sender will be debited
  function borrowAsset(
    address token,
    uint256 _borrowAmount,
    address _collateralToken,
    uint256 _collateralAmount,
    address _receiver
  ) external whenNotPaused nonReentrant isSolvent(msg.sender) approvedBorrower returns (uint256 _shares) {
    _addInterest(token);
    if (_collateralAmount > 0) {
      _addCollateral(_collateralToken, msg.sender, _collateralAmount, msg.sender);
    }
    _shares = _borrowAsset(token, _borrowAmount.toUint128(), _receiver);
  }

  event AddCollateral(address token, address indexed _sender, address indexed _borrower, uint256 _collateralAmount);

  /// @notice The ```_addCollateral``` function is an internal implementation for adding collateral to a borrowers position
  /// @param _sender The source of funds for the new collateral
  /// @param _collateralAmount The amount of Collateral Token to be transferred
  /// @param _borrower The borrower account for which the collateral should be credited
  function _addCollateral(
    address token,
    address _sender,
    uint256 _collateralAmount,
    address _borrower
  ) internal validCollateral(token) {
    Collateral storage collateral = collaterals[token];
    // Effects: write to state
    userCollateralBalance[address(collateral.token)][_borrower] += _collateralAmount;
    collateral.total += _collateralAmount;

    // Interactions
    if (_sender != address(this)) {
      collateral.token.safeTransferFrom(_sender, address(this), _collateralAmount);
    }
    emit AddCollateral(token, _sender, _borrower, _collateralAmount);
  }

  /// @notice The ```addCollateral``` function allows the caller to add Collateral Token to a borrowers position
  /// @dev msg.sender must call ERC20.approve() on the Collateral Token contract prior to invocation
  /// @param _collateralAmount The amount of Collateral Token to be added to borrower's position
  /// @param _borrower The account to be credited
  function addCollateral(
    address token,
    uint256 _collateralAmount,
    address _borrower
  ) external nonReentrant {
    // don't know why here
    // _addInterest();
    _addCollateral(token, msg.sender, _collateralAmount, _borrower);
  }

  /// @notice The ```RemoveCollateral``` event is emitted when collateral is removed from a borrower's position
  /// @param _sender The account from which funds are transferred
  /// @param _collateralAmount The amount of Collateral Token to be transferred
  /// @param _receiver The address to which Collateral Tokens will be transferred
  event RemoveCollateral(
    address token,
    address indexed _sender,
    uint256 _collateralAmount,
    address indexed _receiver,
    address indexed _borrower
  );

  /// @notice The ```_removeCollateral``` function is the internal implementation for removing collateral from a borrower's position
  /// @param _collateralAmount The amount of Collateral Token to remove from the borrower's position
  /// @param _receiver The address to receive the Collateral Token transferred
  /// @param _borrower The borrower whose account will be debited the Collateral amount
  function _removeCollateral(
    address token,
    uint256 _collateralAmount,
    address _receiver,
    address _borrower
  ) internal validCollateral(token) {
    Collateral storage collateral = collaterals[token];
    // Effects: write to state
    // Following line will revert on underflow if _collateralAmount > userCollateralBalance
    userCollateralBalance[address(collateral.token)][_borrower] -= _collateralAmount;
    // Following line will revert on underflow if totalCollateral < _collateralAmount
    collateral.total -= _collateralAmount;

    // Interactions
    if (_receiver != address(this)) {
      collateral.token.safeTransfer(_receiver, _collateralAmount);
    }
    emit RemoveCollateral(token, msg.sender, _collateralAmount, _receiver, _borrower);
  }

  /// @notice The ```removeCollateral``` function is used to remove collateral from msg.sender's borrow position
  /// @dev msg.sender must be solvent after invocation or transaction will revert
  /// @param _collateralAmount The amount of Collateral Token to transfer
  /// @param _receiver The address to receive the transferred funds
  function removeCollateral(
    address token,
    uint256 _collateralAmount,
    address _receiver
  ) external nonReentrant isSolvent(msg.sender) {
    _addInterestAll();
    _removeCollateral(token, _collateralAmount, _receiver, msg.sender);
  }

  /// @notice The ```RepayAsset``` event is emitted whenever a debt position is repaid
  /// @param _payer The address paying for the repayment
  /// @param _borrower The borrower whose account will be credited
  /// @param _amountToRepay The amount of Asset token to be transferred
  /// @param _shares The amount of Borrow Shares which will be debited from the borrower after repayment
  event RepayAsset(address token, address indexed _payer, address indexed _borrower, uint256 _amountToRepay, uint256 _shares);

  /// @notice The ```_repayAsset``` function is the internal implementation for repaying a borrow position
  /// @dev The payer must have called ERC20.approve() on the Asset Token contract prior to invocation
  /// @param _amountToRepay The amount of Asset Token to transfer
  /// @param _shares The number of Borrow Shares the sender is repaying
  /// @param _payer The address from which funds will be transferred
  /// @param _borrower The borrower account which will be credited
  function _repayAsset(
    address token,
    uint128 _amountToRepay,
    uint128 _shares,
    address _payer,
    address _borrower
  ) internal {
    Asset storage asset = assets[token];
    VaultAccount memory _totalBorrow = asset.totalBorrow;
    // Effects: Bookkeeping
    asset.totalBorrow.amount -= _amountToRepay;
    asset.totalBorrow.shares -= _shares;

    // Effects: write to state
    userBorrowShares[address(asset.token)][_borrower] -= _shares;

    // Interactions
    if (_payer != address(this)) {
      asset.token.safeTransferFrom(_payer, address(this), _amountToRepay);
    }
    emit RepayAsset(token, _payer, _borrower, _amountToRepay, _shares);
  }

  /// @notice The ```repayAsset``` function allows the caller to pay down the debt for a given borrower.
  /// @dev Caller must first invoke ```ERC20.approve()``` for the Asset Token contract
  /// @param _shares The number of Borrow Shares which will be repaid by the call
  /// @param _borrower The account for which the debt will be reduced
  /// @return _amountToRepay The amount of Asset Tokens which were transferred in order to repay the Borrow Shares
  function repayAsset(
    address _asset,
    uint256 _shares,
    address _borrower
  ) external nonReentrant validAsset(_asset) returns (uint256 _amountToRepay) {
    _addInterest(_asset);
    _amountToRepay = assets[_asset].totalBorrow.toAmount(_shares, true);
    _repayAsset(_asset, _amountToRepay.toUint128(), _shares.toUint128(), msg.sender, _borrower);
  }

  // ============================================================================================
  // Functions: Liquidations
  // ============================================================================================

  function hasCollateral(address _borrower) public view returns (bool) {
    for (uint8 i = 0; i < collateralsList.length; i++) {
      address collateralAddress = collateralsList[i];
      uint256 collateralBalance = userCollateralBalance[collateralAddress][_borrower];
      if (collateralBalance > 0) {
        return true;
      }
    }
    return false;
  }

  event AdjustAsset(address asset, address borrower, uint256 sharesToAdjust, uint256 amountToAdjust);

  function adjustAsset(
    address _asset,
    address _borrower,
    address _rewardee
  ) external {
    if (hasCollateral(_borrower)) revert HasCollateral();

    uint128 _sharesToAdjust;
    uint128 _amountToAdjust;

    uint256 borrowerShares = userBorrowShares[_asset][_borrower];
    _sharesToAdjust = uint128(borrowerShares);

    Asset storage assetToAdjust = assets[_asset];
    if (_sharesToAdjust > 0) {
      uint256 fTokenBalance = assetToAdjust.fToken.balanceOf(_rewardee);

      // redeem
      uint256 _amountToReturn = assetToAdjust.totalAsset.toAmount(fTokenBalance, true);
      assetToAdjust.totalAsset.shares -= uint128(fTokenBalance);
      assetToAdjust.totalAsset.amount -= uint128(_amountToReturn);

      _amountToAdjust = (assetToAdjust.totalBorrow.toAmount(_sharesToAdjust, false)).toUint128();
      assetToAdjust.totalAsset.amount -= _amountToAdjust;

      userBorrowShares[_asset][_borrower] = 0;
      assetToAdjust.totalBorrow.amount -= _amountToAdjust;
      assetToAdjust.totalBorrow.shares -= _sharesToAdjust;

      uint256 newShares = assetToAdjust.totalAsset.toShares(_amountToReturn, true);

      assetToAdjust.totalAsset.amount += uint128(_amountToReturn);
      assetToAdjust.totalAsset.shares += uint128(newShares);

      uint256 sharesToMint = newShares - fTokenBalance;
      assetToAdjust.fToken.mint(_rewardee, sharesToMint);
    }

    emit AdjustAsset(_asset, _borrower, _sharesToAdjust, _amountToAdjust);
  }

  /// @notice The ```Liquidate``` event is emitted when a liquidation occurs
  /// @param _borrower The borrower account for which the liquidation occurred
  /// @param _collateralForLiquidator The amount of Collateral Token transferred to the liquidator
  event Liquidate(
    address _asset,
    uint256 _sharesToLiquidate,
    address _collateral,
    address indexed _borrower,
    uint256 _collateralForLiquidator,
    uint256 _amountLiquidatorToRepay
  );

  /// @notice The ```liquidate``` function allows a third party to repay a borrower's debt if they have become insolvent
  /// @dev Caller must invoke ```ERC20.approve``` on the Asset Token contract prior to calling ```Liquidate()```
  /// @param _sharesToLiquidate The number of Borrow Shares repaid by the liquidator
  /// @param _deadline The timestamp after which tx will revert
  /// @param _borrower The account for which the repayment is credited and from whom collateral will be taken
  /// @return _collateralForLiquidator The amount of Collateral Token transferred to the liquidator
  function liquidate(
    address _asset,
    uint128 _sharesToLiquidate,
    address _collateral,
    uint256 _deadline,
    address _borrower
  ) external whenNotPaused nonReentrant approvedLender(msg.sender) returns (uint256 _collateralForLiquidator) {
    if (block.timestamp > _deadline) revert PastDeadline(block.timestamp, _deadline);

    _addInterest(_asset);

    if (_isSolvent(_borrower)) {
      revert BorrowerSolvent();
    }

    Asset memory asset = assets[_asset];
    Collateral memory collateral = collaterals[_collateral];

    // Prevent stack-too-deep
    int256 _leftoverCollateral;
    {
      // Checks & Calculations
      // Determine the liquidation amount in collateral units (i.e. how much debt is liquidator going to repay)
      uint256 _liquidationAmountInCollateralUnits = (asset.totalBorrow.toAmount(_sharesToLiquidate, false) *
        tokenValue(asset, EXCHANGE_PRECISION)) / tokenValue(collateral, EXCHANGE_PRECISION);

      // We first optimistically calculate the amount of collateral to give the liquidator based on the higher clean liquidation fee
      // This fee only applies if the liquidator does a full liquidation
      uint256 _optimisticCollateralForLiquidator = (_liquidationAmountInCollateralUnits * (LIQ_PRECISION + liquidationFee)) /
        LIQ_PRECISION;

      // Because interest accrues every block, _liquidationAmountInCollateralUnits from a few lines up is an ever increasing value
      // This means that leftoverCollateral can occasionally go negative by a few hundred wei (cleanLiqFee premium covers this for liquidator)
      _leftoverCollateral = (userCollateralBalance[_collateral][_borrower].toInt256() -
        _optimisticCollateralForLiquidator.toInt256());

      // If cleanLiquidation fee results in no leftover collateral, give liquidator all the collateral
      // This will only be true when there liquidator is cleaning out the position
      _collateralForLiquidator = _leftoverCollateral <= 0
        ? userCollateralBalance[_collateral][_borrower]
        : _optimisticCollateralForLiquidator;
    }
    // Calculated here for use during repayment, grouped with other calcs before effects start
    uint128 _amountLiquidatorToRepay = (asset.totalBorrow.toAmount(_sharesToLiquidate, true)).toUint128();

    emit Liquidate(_asset, _sharesToLiquidate, _collateral, _borrower, _collateralForLiquidator, _amountLiquidatorToRepay);
    // Effects & Interactions
    // NOTE: reverts if _shares > userBorrowShares
    _repayAsset(_asset, _amountLiquidatorToRepay, _sharesToLiquidate, msg.sender, _borrower); // liquidator repays shares on behalf of borrower
    // NOTE: reverts if _collateralForLiquidator > userCollateralBalance
    // Collateral is removed on behalf of borrower and sent to liquidator
    // NOTE: reverts if _collateralForLiquidator > userCollateralBalance

    _removeCollateral(_collateral, _collateralForLiquidator, msg.sender, _borrower);
  }

  /* Comment liquidation, leverage and repay asset using collateral features


  // ============================================================================================
  // Functions: Leverage
  // ============================================================================================

  /// @notice The ```LeveragedPosition``` event is emitted when a borrower takes out a new leveraged position
  /// @param _borrower The account for which the debt is debited
  /// @param _swapperAddress The address of the swapper which conforms the FraxSwap interface
  /// @param _borrowAmount The amount of Asset Token to be borrowed to be borrowed
  /// @param _borrowShares The number of Borrow Shares the borrower is credited
  /// @param _initialCollateralAmount The amount of initial Collateral Tokens supplied by the borrower
  /// @param _amountCollateralOut The amount of Collateral Token which was received for the Asset Tokens
  event LeveragedPosition(
    address indexed _borrower,
    address _swapperAddress,
    uint256 _borrowAmount,
    uint256 _borrowShares,
    uint256 _initialCollateralAmount,
    uint256 _amountCollateralOut
  );

  /// @notice The ```leveragedPosition``` function allows a user to enter a leveraged borrow position with minimal upfront Collateral
  /// @dev Caller must invoke ```ERC20.approve()``` on the Collateral Token contract prior to calling function
  /// @param _swapperAddress The address of the whitelisted swapper to use to swap borrowed Asset Tokens for Collateral Tokens
  /// @param _borrowAmount The amount of Asset Tokens borrowed
  /// @param _initialCollateralAmount The initial amount of Collateral Tokens supplied by the borrower
  /// @param _amountCollateralOutMin The minimum amount of Collateral Tokens to be received in exchange for the borrowed Asset Tokens
  /// @param _path An array containing the addresses of ERC20 tokens to swap.  Adheres to UniV2 style path params.
  /// @return _totalCollateralBalance The total amount of Collateral Tokens added to a users account (initial + swap)
  function leveragedPosition(
    address _swapperAddress,
    uint256 _borrowAmount,
    uint256 _initialCollateralAmount,
    uint256 _amountCollateralOutMin,
    address[] memory _path
  )
    external
    nonReentrant
    whenNotPaused
    approvedBorrower
    isSolvent(msg.sender)
    returns (uint256 _totalCollateralBalance)
  {
    _addInterest();
    _updateExchangeRate();

    IERC20 _assetContract = assetContract;
    IERC20 _collateralContract = collateralContract;

    if (!swappers[_swapperAddress]) {
      revert BadSwapper();
    }
    if (_path[0] != address(_assetContract)) {
      revert InvalidPath(address(_assetContract), _path[0]);
    }
    if (_path[_path.length - 1] != address(_collateralContract)) {
      revert InvalidPath(address(_collateralContract), _path[_path.length - 1]);
    }

    // Add initial collateral
    if (_initialCollateralAmount > 0) {
      _addCollateral(msg.sender, _initialCollateralAmount, msg.sender);
    }

    // Debit borrowers account
    // setting recipient to address(this) means no transfer will happen
    uint256 _borrowShares = _borrowAsset(_borrowAmount.toUint128(), address(this));

    // Interactions
    _assetContract.approve(_swapperAddress, _borrowAmount);

    // Even though swappers are trusted, we verify the balance before and after swap
    uint256 _initialCollateralBalance = _collateralContract.balanceOf(address(this));
    ISwapper(_swapperAddress).swapExactTokensForTokens(
      _borrowAmount,
      _amountCollateralOutMin,
      _path,
      address(this),
      block.timestamp
    );
    uint256 _finalCollateralBalance = _collateralContract.balanceOf(address(this));

    // Note: VIOLATES CHECKS-EFFECTS-INTERACTION pattern, make sure function is NONREENTRANT
    // Effects: bookkeeping & write to state
    uint256 _amountCollateralOut = _finalCollateralBalance - _initialCollateralBalance;
    if (_amountCollateralOut < _amountCollateralOutMin) {
      revert SlippageTooHigh(_amountCollateralOutMin, _amountCollateralOut);
    }

    // address(this) as _sender means no transfer occurs as the pair has already received the collateral during swap
    _addCollateral(address(this), _amountCollateralOut, msg.sender);

    _totalCollateralBalance = _initialCollateralAmount + _amountCollateralOut;
    emit LeveragedPosition(
      msg.sender,
      _swapperAddress,
      _borrowAmount,
      _borrowShares,
      _initialCollateralAmount,
      _amountCollateralOut
    );
  }

  /// @notice The ```RepayAssetWithCollateral``` event is emitted whenever ```repayAssetWithCollateral()``` is invoked
  /// @param _borrower The borrower account for which the repayment is taking place
  /// @param _swapperAddress The address of the whitelisted swapper to use for token swaps
  /// @param _collateralToSwap The amount of Collateral Token to swap and use for repayment
  /// @param _amountAssetOut The amount of Asset Token which was repaid
  /// @param _sharesRepaid The number of Borrow Shares which were repaid
  event RepayAssetWithCollateral(
    address indexed _borrower,
    address _swapperAddress,
    uint256 _collateralToSwap,
    uint256 _amountAssetOut,
    uint256 _sharesRepaid
  );

  /// @notice The ```repayAssetWithCollateral``` function allows a borrower to repay their debt using existing collateral in contract
  /// @param _swapperAddress The address of the whitelisted swapper to use for token swaps
  /// @param _collateralToSwap The amount of Collateral Tokens to swap for Asset Tokens
  /// @param _amountAssetOutMin The minimum amount of Asset Tokens to receive during the swap
  /// @param _path An array containing the addresses of ERC20 tokens to swap.  Adheres to UniV2 style path params.
  /// @return _amountAssetOut The amount of Asset Tokens received for the Collateral Tokens, the amount the borrowers account was credited
  function repayAssetWithCollateral(
    address _swapperAddress,
    uint256 _collateralToSwap,
    uint256 _amountAssetOutMin,
    address[] calldata _path
  ) external nonReentrant isSolvent(msg.sender) returns (uint256 _amountAssetOut) {
    _addInterest();
    _updateExchangeRate();

    IERC20 _assetContract = assetContract;
    IERC20 _collateralContract = collateralContract;

    if (!swappers[_swapperAddress]) {
      revert BadSwapper();
    }
    if (_path[0] != address(_collateralContract)) {
      revert InvalidPath(address(_collateralContract), _path[0]);
    }
    if (_path[_path.length - 1] != address(_assetContract)) {
      revert InvalidPath(address(_assetContract), _path[_path.length - 1]);
    }

    // Effects: bookkeeping & write to state
    // Debit users collateral balance in preparation for swap, setting _recipient to address(this) means no transfer occurs
    _removeCollateral(_collateralToSwap, address(this), msg.sender);

    // Interactions
    _collateralContract.approve(_swapperAddress, _collateralToSwap);

    // Even though swappers are trusted, we verify the balance before and after swap
    uint256 _initialAssetBalance = _assetContract.balanceOf(address(this));
    ISwapper(_swapperAddress).swapExactTokensForTokens(
      _collateralToSwap,
      _amountAssetOutMin,
      _path,
      address(this),
      block.timestamp
    );
    uint256 _finalAssetBalance = _assetContract.balanceOf(address(this));

    // Note: VIOLATES CHECKS-EFFECTS-INTERACTION pattern, make sure function is NONREENTRANT
    // Effects: bookkeeping
    _amountAssetOut = _finalAssetBalance - _initialAssetBalance;
    if (_amountAssetOut < _amountAssetOutMin) {
      revert SlippageTooHigh(_amountAssetOutMin, _amountAssetOut);
    }

    VaultAccount memory _totalBorrow = totalBorrow;
    uint256 _sharesToRepay = _totalBorrow.toShares(_amountAssetOut, false);

    // Effects: write to state
    // Note: setting _payer to address(this) means no actual transfer will occur.  Contract already has funds
    _repayAsset(_totalBorrow, _amountAssetOut.toUint128(), _sharesToRepay.toUint128(), address(this), msg.sender);

    emit RepayAssetWithCollateral(msg.sender, _swapperAddress, _collateralToSwap, _amountAssetOut, _sharesToRepay);
  }

  */
}

// SPDX-License-Identifier: ISC
pragma solidity ^0.8.16;

struct VaultAccount {
    uint128 amount; // Total amount, analogous to market cap
    uint128 shares; // Total shares, analogous to shares outstanding
}

/// @title VaultAccount Library
/// @author Drake Evans (Frax Finance) github.com/drakeevans, modified from work by @Boring_Crypto github.com/boring_crypto
/// @notice Provides a library for use with the VaultAccount struct, provides convenient math implementations
/// @dev Uses uint128 to save on storage
library VaultAccountingLibrary {
    /// @notice Calculates the shares value in relationship to `amount` and `total`
    /// @dev Given an amount, return the appropriate number of shares
    function toShares(
        VaultAccount memory total,
        uint256 amount,
        bool roundUp
    ) internal pure returns (uint256 shares) {
        if (total.amount == 0) {
            shares = amount;
        } else {
            shares = (amount * total.shares) / total.amount;
            if (roundUp && (shares * total.amount) / total.shares < amount) {
                shares = shares + 1;
            }
        }
    }

    /// @notice Calculates the amount value in relationship to `shares` and `total`
    /// @dev Given a number of shares, returns the appropriate amount
    function toAmount(
        VaultAccount memory total,
        uint256 shares,
        bool roundUp
    ) internal pure returns (uint256 amount) {
        if (total.shares == 0) {
            amount = shares;
        } else {
            amount = (shares * total.amount) / total.shares;
            if (roundUp && (amount * total.shares) / total.amount < shares) {
                amount = amount + 1;
            }
        }
    }
}

// SPDX-License-Identifier: ISC
pragma solidity ^0.8.16;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ===================== FraxlendPairConstants ========================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

// Primary Author
// Drake Evans: https://github.com/DrakeEvans

// Reviewers
// Dennis: https://github.com/denett
// Sam Kazemian: https://github.com/samkazemian
// Travis Moore: https://github.com/FortisFortuna
// Jack Corddry: https://github.com/corddry
// Rich Gee: https://github.com/zer0blockchain

// ====================================================================

abstract contract FraxlendPairConstants {
  // ============================================================================================
  // Constants
  // ============================================================================================

  // Precision settings
  uint256 internal constant LTV_PRECISION = 1e5; // 5 decimals
  uint256 internal constant LIQ_PRECISION = 1e5;
  uint256 internal constant UTIL_PREC = 1e5;
  uint256 internal constant FEE_PRECISION = 1e5;
  uint256 internal constant EXCHANGE_PRECISION = 1e18;

  // Default Interest Rate (if borrows = 0)
  uint64 internal constant DEFAULT_INT = 158049988; // 0.5% annual rate 1e18 precision

  // Protocol Fee
  // uint16 internal constant DEFAULT_PROTOCOL_FEE = 0; // 1e5 precision
  uint256 internal constant MAX_PROTOCOL_FEE = 5e4; // 50% 1e5 precision

  error Insolvent();
  error BorrowerSolvent();
  error OnlyApprovedBorrowers();
  error OnlyApprovedLenders();
  error ProtocolOrOwnerOnly();
  error OracleLTEZero(address _oracle);
  error InsufficientAssetsInContract(uint256 _assets, uint256 _request);
  error NotOnWhitelist(address _address);
  error NotDeployer();
  error NameEmpty();
  error AlreadyInitialized();
  error SlippageTooHigh(uint256 _minOut, uint256 _actual);
  error BadSwapper();
  error InvalidPath(address _expected, address _actual);
  error BadProtocolFee();
  error BorrowerWhitelistRequired();
  error OnlyTimeLock();
  error PriceTooLarge();
  error PastDeadline(uint256 _blockTimestamp, uint256 _deadline);
  error LTVTooHigh(uint256 ltv);
  error OnlyTokenManager();
  error HasCollateral();
}

// SPDX-License-Identifier: ISC
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 as OZSafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// solhint-disable avoid-low-level-calls
// solhint-disable max-line-length

/// @title SafeERC20 provides helper functions for safe transfers as well as safe metadata access
/// @author Library originally written by @Boring_Crypto github.com/boring_crypto, modified by Drake Evans (Frax Finance) github.com/drakeevans
/// @dev original: https://github.com/boringcrypto/BoringSolidity/blob/fed25c5d43cb7ce20764cd0b838e21a02ea162e9/contracts/libraries/BoringERC20.sol
library SafeERC20 {
    bytes4 private constant SIG_SYMBOL = 0x95d89b41; // symbol()
    bytes4 private constant SIG_NAME = 0x06fdde03; // name()
    bytes4 private constant SIG_DECIMALS = 0x313ce567; // decimals()

    function returnDataToString(bytes memory data) internal pure returns (string memory) {
        if (data.length >= 64) {
            return abi.decode(data, (string));
        } else if (data.length == 32) {
            uint8 i = 0;
            while (i < 32 && data[i] != 0) {
                i++;
            }
            bytes memory bytesArray = new bytes(i);
            for (i = 0; i < 32 && data[i] != 0; i++) {
                bytesArray[i] = data[i];
            }
            return string(bytesArray);
        } else {
            return "???";
        }
    }

    /// @notice Provides a safe ERC20.symbol version which returns '???' as fallback string.
    /// @param token The address of the ERC-20 token contract.
    /// @return (string) Token symbol.
    function safeSymbol(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_SYMBOL));
        return success ? returnDataToString(data) : "???";
    }

    /// @notice Provides a safe ERC20.name version which returns '???' as fallback string.
    /// @param token The address of the ERC-20 token contract.
    /// @return (string) Token name.
    function safeName(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_NAME));
        return success ? returnDataToString(data) : "???";
    }

    /// @notice Provides a safe ERC20.decimals version which returns '18' as fallback value.
    /// @param token The address of the ERC-20 token contract.
    /// @return (uint8) Token decimals.
    function safeDecimals(IERC20 token) internal view returns (uint8) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_DECIMALS));
        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        OZSafeERC20.safeTransfer(token, to, value);
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        OZSafeERC20.safeTransferFrom(token, from, to, value);
    }
}

// SPDX-License-Identifier: ISC
pragma solidity >=0.8.16;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';
import '../libraries/VaultAccount.sol';
import './IFToken.sol';
import './IRateCalculator.sol';
import '../FToken.sol';

interface IFraxlendPairCore {
  /// @notice Stores information about the current interest rate
  /// @dev struct is packed to reduce SLOADs. feeToProtocolRate is 1e5 precision, ratePerSec is 1e18 precision
  // CurrentRateInfo public currentRateInfo;
  struct CurrentRateInfo {
    uint64 lastBlock;
    uint64 feeToProtocolRate; // Fee amount 1e5 precision
    uint64 lastTimestamp;
    uint64 ratePerSec;
  }

  struct Asset {
    IERC20 token;
    uint8 tokenDecimals;
    AggregatorV3Interface oracle;
    uint8 oracleDecimals;
    VaultAccount totalAsset;
    VaultAccount totalBorrow;
    IFToken fToken;
    CurrentRateInfo currentRateInfo;
  }

  struct Collateral {
    IERC20 token;
    uint8 tokenDecimals;
    AggregatorV3Interface oracle;
    uint8 oracleDecimals;
    uint256 ltv;
    uint256 total; // totalCollateral
  }

  function DEPLOYER_ADDRESS() external view returns (address);

  function defineAssets(Asset[] memory _assets) external;

  function defineCollaterals(Collateral[] memory _collaterals) external;

  function name() external view returns (string memory);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

interface ISwapper {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

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
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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
abstract contract ReentrancyGuard {
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

    constructor() {
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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/math/SafeCast.sol)

pragma solidity ^0.8.0;

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCast {
    /**
     * @dev Returns the downcasted uint248 from uint256, reverting on
     * overflow (when the input is greater than largest uint248).
     *
     * Counterpart to Solidity's `uint248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     *
     * _Available since v4.7._
     */
    function toUint248(uint256 value) internal pure returns (uint248) {
        require(value <= type(uint248).max, "SafeCast: value doesn't fit in 248 bits");
        return uint248(value);
    }

    /**
     * @dev Returns the downcasted uint240 from uint256, reverting on
     * overflow (when the input is greater than largest uint240).
     *
     * Counterpart to Solidity's `uint240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     *
     * _Available since v4.7._
     */
    function toUint240(uint256 value) internal pure returns (uint240) {
        require(value <= type(uint240).max, "SafeCast: value doesn't fit in 240 bits");
        return uint240(value);
    }

    /**
     * @dev Returns the downcasted uint232 from uint256, reverting on
     * overflow (when the input is greater than largest uint232).
     *
     * Counterpart to Solidity's `uint232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     *
     * _Available since v4.7._
     */
    function toUint232(uint256 value) internal pure returns (uint232) {
        require(value <= type(uint232).max, "SafeCast: value doesn't fit in 232 bits");
        return uint232(value);
    }

    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     *
     * _Available since v4.2._
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(value <= type(uint224).max, "SafeCast: value doesn't fit in 224 bits");
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint216 from uint256, reverting on
     * overflow (when the input is greater than largest uint216).
     *
     * Counterpart to Solidity's `uint216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     *
     * _Available since v4.7._
     */
    function toUint216(uint256 value) internal pure returns (uint216) {
        require(value <= type(uint216).max, "SafeCast: value doesn't fit in 216 bits");
        return uint216(value);
    }

    /**
     * @dev Returns the downcasted uint208 from uint256, reverting on
     * overflow (when the input is greater than largest uint208).
     *
     * Counterpart to Solidity's `uint208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     *
     * _Available since v4.7._
     */
    function toUint208(uint256 value) internal pure returns (uint208) {
        require(value <= type(uint208).max, "SafeCast: value doesn't fit in 208 bits");
        return uint208(value);
    }

    /**
     * @dev Returns the downcasted uint200 from uint256, reverting on
     * overflow (when the input is greater than largest uint200).
     *
     * Counterpart to Solidity's `uint200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     *
     * _Available since v4.7._
     */
    function toUint200(uint256 value) internal pure returns (uint200) {
        require(value <= type(uint200).max, "SafeCast: value doesn't fit in 200 bits");
        return uint200(value);
    }

    /**
     * @dev Returns the downcasted uint192 from uint256, reverting on
     * overflow (when the input is greater than largest uint192).
     *
     * Counterpart to Solidity's `uint192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     *
     * _Available since v4.7._
     */
    function toUint192(uint256 value) internal pure returns (uint192) {
        require(value <= type(uint192).max, "SafeCast: value doesn't fit in 192 bits");
        return uint192(value);
    }

    /**
     * @dev Returns the downcasted uint184 from uint256, reverting on
     * overflow (when the input is greater than largest uint184).
     *
     * Counterpart to Solidity's `uint184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     *
     * _Available since v4.7._
     */
    function toUint184(uint256 value) internal pure returns (uint184) {
        require(value <= type(uint184).max, "SafeCast: value doesn't fit in 184 bits");
        return uint184(value);
    }

    /**
     * @dev Returns the downcasted uint176 from uint256, reverting on
     * overflow (when the input is greater than largest uint176).
     *
     * Counterpart to Solidity's `uint176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     *
     * _Available since v4.7._
     */
    function toUint176(uint256 value) internal pure returns (uint176) {
        require(value <= type(uint176).max, "SafeCast: value doesn't fit in 176 bits");
        return uint176(value);
    }

    /**
     * @dev Returns the downcasted uint168 from uint256, reverting on
     * overflow (when the input is greater than largest uint168).
     *
     * Counterpart to Solidity's `uint168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     *
     * _Available since v4.7._
     */
    function toUint168(uint256 value) internal pure returns (uint168) {
        require(value <= type(uint168).max, "SafeCast: value doesn't fit in 168 bits");
        return uint168(value);
    }

    /**
     * @dev Returns the downcasted uint160 from uint256, reverting on
     * overflow (when the input is greater than largest uint160).
     *
     * Counterpart to Solidity's `uint160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     *
     * _Available since v4.7._
     */
    function toUint160(uint256 value) internal pure returns (uint160) {
        require(value <= type(uint160).max, "SafeCast: value doesn't fit in 160 bits");
        return uint160(value);
    }

    /**
     * @dev Returns the downcasted uint152 from uint256, reverting on
     * overflow (when the input is greater than largest uint152).
     *
     * Counterpart to Solidity's `uint152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     *
     * _Available since v4.7._
     */
    function toUint152(uint256 value) internal pure returns (uint152) {
        require(value <= type(uint152).max, "SafeCast: value doesn't fit in 152 bits");
        return uint152(value);
    }

    /**
     * @dev Returns the downcasted uint144 from uint256, reverting on
     * overflow (when the input is greater than largest uint144).
     *
     * Counterpart to Solidity's `uint144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     *
     * _Available since v4.7._
     */
    function toUint144(uint256 value) internal pure returns (uint144) {
        require(value <= type(uint144).max, "SafeCast: value doesn't fit in 144 bits");
        return uint144(value);
    }

    /**
     * @dev Returns the downcasted uint136 from uint256, reverting on
     * overflow (when the input is greater than largest uint136).
     *
     * Counterpart to Solidity's `uint136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     *
     * _Available since v4.7._
     */
    function toUint136(uint256 value) internal pure returns (uint136) {
        require(value <= type(uint136).max, "SafeCast: value doesn't fit in 136 bits");
        return uint136(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v2.5._
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint120 from uint256, reverting on
     * overflow (when the input is greater than largest uint120).
     *
     * Counterpart to Solidity's `uint120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     *
     * _Available since v4.7._
     */
    function toUint120(uint256 value) internal pure returns (uint120) {
        require(value <= type(uint120).max, "SafeCast: value doesn't fit in 120 bits");
        return uint120(value);
    }

    /**
     * @dev Returns the downcasted uint112 from uint256, reverting on
     * overflow (when the input is greater than largest uint112).
     *
     * Counterpart to Solidity's `uint112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     *
     * _Available since v4.7._
     */
    function toUint112(uint256 value) internal pure returns (uint112) {
        require(value <= type(uint112).max, "SafeCast: value doesn't fit in 112 bits");
        return uint112(value);
    }

    /**
     * @dev Returns the downcasted uint104 from uint256, reverting on
     * overflow (when the input is greater than largest uint104).
     *
     * Counterpart to Solidity's `uint104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     *
     * _Available since v4.7._
     */
    function toUint104(uint256 value) internal pure returns (uint104) {
        require(value <= type(uint104).max, "SafeCast: value doesn't fit in 104 bits");
        return uint104(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     *
     * _Available since v4.2._
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value <= type(uint96).max, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint88 from uint256, reverting on
     * overflow (when the input is greater than largest uint88).
     *
     * Counterpart to Solidity's `uint88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     *
     * _Available since v4.7._
     */
    function toUint88(uint256 value) internal pure returns (uint88) {
        require(value <= type(uint88).max, "SafeCast: value doesn't fit in 88 bits");
        return uint88(value);
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     *
     * _Available since v4.7._
     */
    function toUint80(uint256 value) internal pure returns (uint80) {
        require(value <= type(uint80).max, "SafeCast: value doesn't fit in 80 bits");
        return uint80(value);
    }

    /**
     * @dev Returns the downcasted uint72 from uint256, reverting on
     * overflow (when the input is greater than largest uint72).
     *
     * Counterpart to Solidity's `uint72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     *
     * _Available since v4.7._
     */
    function toUint72(uint256 value) internal pure returns (uint72) {
        require(value <= type(uint72).max, "SafeCast: value doesn't fit in 72 bits");
        return uint72(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v2.5._
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value <= type(uint64).max, "SafeCast: value doesn't fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint56 from uint256, reverting on
     * overflow (when the input is greater than largest uint56).
     *
     * Counterpart to Solidity's `uint56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     *
     * _Available since v4.7._
     */
    function toUint56(uint256 value) internal pure returns (uint56) {
        require(value <= type(uint56).max, "SafeCast: value doesn't fit in 56 bits");
        return uint56(value);
    }

    /**
     * @dev Returns the downcasted uint48 from uint256, reverting on
     * overflow (when the input is greater than largest uint48).
     *
     * Counterpart to Solidity's `uint48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     *
     * _Available since v4.7._
     */
    function toUint48(uint256 value) internal pure returns (uint48) {
        require(value <= type(uint48).max, "SafeCast: value doesn't fit in 48 bits");
        return uint48(value);
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     *
     * _Available since v4.7._
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        require(value <= type(uint40).max, "SafeCast: value doesn't fit in 40 bits");
        return uint40(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v2.5._
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint24 from uint256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     *
     * _Available since v4.7._
     */
    function toUint24(uint256 value) internal pure returns (uint24) {
        require(value <= type(uint24).max, "SafeCast: value doesn't fit in 24 bits");
        return uint24(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v2.5._
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value <= type(uint16).max, "SafeCast: value doesn't fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     *
     * _Available since v2.5._
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "SafeCast: value doesn't fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     *
     * _Available since v3.0._
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int248 from int256, reverting on
     * overflow (when the input is less than smallest int248 or
     * greater than largest int248).
     *
     * Counterpart to Solidity's `int248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     *
     * _Available since v4.7._
     */
    function toInt248(int256 value) internal pure returns (int248) {
        require(value >= type(int248).min && value <= type(int248).max, "SafeCast: value doesn't fit in 248 bits");
        return int248(value);
    }

    /**
     * @dev Returns the downcasted int240 from int256, reverting on
     * overflow (when the input is less than smallest int240 or
     * greater than largest int240).
     *
     * Counterpart to Solidity's `int240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     *
     * _Available since v4.7._
     */
    function toInt240(int256 value) internal pure returns (int240) {
        require(value >= type(int240).min && value <= type(int240).max, "SafeCast: value doesn't fit in 240 bits");
        return int240(value);
    }

    /**
     * @dev Returns the downcasted int232 from int256, reverting on
     * overflow (when the input is less than smallest int232 or
     * greater than largest int232).
     *
     * Counterpart to Solidity's `int232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     *
     * _Available since v4.7._
     */
    function toInt232(int256 value) internal pure returns (int232) {
        require(value >= type(int232).min && value <= type(int232).max, "SafeCast: value doesn't fit in 232 bits");
        return int232(value);
    }

    /**
     * @dev Returns the downcasted int224 from int256, reverting on
     * overflow (when the input is less than smallest int224 or
     * greater than largest int224).
     *
     * Counterpart to Solidity's `int224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     *
     * _Available since v4.7._
     */
    function toInt224(int256 value) internal pure returns (int224) {
        require(value >= type(int224).min && value <= type(int224).max, "SafeCast: value doesn't fit in 224 bits");
        return int224(value);
    }

    /**
     * @dev Returns the downcasted int216 from int256, reverting on
     * overflow (when the input is less than smallest int216 or
     * greater than largest int216).
     *
     * Counterpart to Solidity's `int216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     *
     * _Available since v4.7._
     */
    function toInt216(int256 value) internal pure returns (int216) {
        require(value >= type(int216).min && value <= type(int216).max, "SafeCast: value doesn't fit in 216 bits");
        return int216(value);
    }

    /**
     * @dev Returns the downcasted int208 from int256, reverting on
     * overflow (when the input is less than smallest int208 or
     * greater than largest int208).
     *
     * Counterpart to Solidity's `int208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     *
     * _Available since v4.7._
     */
    function toInt208(int256 value) internal pure returns (int208) {
        require(value >= type(int208).min && value <= type(int208).max, "SafeCast: value doesn't fit in 208 bits");
        return int208(value);
    }

    /**
     * @dev Returns the downcasted int200 from int256, reverting on
     * overflow (when the input is less than smallest int200 or
     * greater than largest int200).
     *
     * Counterpart to Solidity's `int200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     *
     * _Available since v4.7._
     */
    function toInt200(int256 value) internal pure returns (int200) {
        require(value >= type(int200).min && value <= type(int200).max, "SafeCast: value doesn't fit in 200 bits");
        return int200(value);
    }

    /**
     * @dev Returns the downcasted int192 from int256, reverting on
     * overflow (when the input is less than smallest int192 or
     * greater than largest int192).
     *
     * Counterpart to Solidity's `int192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     *
     * _Available since v4.7._
     */
    function toInt192(int256 value) internal pure returns (int192) {
        require(value >= type(int192).min && value <= type(int192).max, "SafeCast: value doesn't fit in 192 bits");
        return int192(value);
    }

    /**
     * @dev Returns the downcasted int184 from int256, reverting on
     * overflow (when the input is less than smallest int184 or
     * greater than largest int184).
     *
     * Counterpart to Solidity's `int184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     *
     * _Available since v4.7._
     */
    function toInt184(int256 value) internal pure returns (int184) {
        require(value >= type(int184).min && value <= type(int184).max, "SafeCast: value doesn't fit in 184 bits");
        return int184(value);
    }

    /**
     * @dev Returns the downcasted int176 from int256, reverting on
     * overflow (when the input is less than smallest int176 or
     * greater than largest int176).
     *
     * Counterpart to Solidity's `int176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     *
     * _Available since v4.7._
     */
    function toInt176(int256 value) internal pure returns (int176) {
        require(value >= type(int176).min && value <= type(int176).max, "SafeCast: value doesn't fit in 176 bits");
        return int176(value);
    }

    /**
     * @dev Returns the downcasted int168 from int256, reverting on
     * overflow (when the input is less than smallest int168 or
     * greater than largest int168).
     *
     * Counterpart to Solidity's `int168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     *
     * _Available since v4.7._
     */
    function toInt168(int256 value) internal pure returns (int168) {
        require(value >= type(int168).min && value <= type(int168).max, "SafeCast: value doesn't fit in 168 bits");
        return int168(value);
    }

    /**
     * @dev Returns the downcasted int160 from int256, reverting on
     * overflow (when the input is less than smallest int160 or
     * greater than largest int160).
     *
     * Counterpart to Solidity's `int160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     *
     * _Available since v4.7._
     */
    function toInt160(int256 value) internal pure returns (int160) {
        require(value >= type(int160).min && value <= type(int160).max, "SafeCast: value doesn't fit in 160 bits");
        return int160(value);
    }

    /**
     * @dev Returns the downcasted int152 from int256, reverting on
     * overflow (when the input is less than smallest int152 or
     * greater than largest int152).
     *
     * Counterpart to Solidity's `int152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     *
     * _Available since v4.7._
     */
    function toInt152(int256 value) internal pure returns (int152) {
        require(value >= type(int152).min && value <= type(int152).max, "SafeCast: value doesn't fit in 152 bits");
        return int152(value);
    }

    /**
     * @dev Returns the downcasted int144 from int256, reverting on
     * overflow (when the input is less than smallest int144 or
     * greater than largest int144).
     *
     * Counterpart to Solidity's `int144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     *
     * _Available since v4.7._
     */
    function toInt144(int256 value) internal pure returns (int144) {
        require(value >= type(int144).min && value <= type(int144).max, "SafeCast: value doesn't fit in 144 bits");
        return int144(value);
    }

    /**
     * @dev Returns the downcasted int136 from int256, reverting on
     * overflow (when the input is less than smallest int136 or
     * greater than largest int136).
     *
     * Counterpart to Solidity's `int136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     *
     * _Available since v4.7._
     */
    function toInt136(int256 value) internal pure returns (int136) {
        require(value >= type(int136).min && value <= type(int136).max, "SafeCast: value doesn't fit in 136 bits");
        return int136(value);
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128) {
        require(value >= type(int128).min && value <= type(int128).max, "SafeCast: value doesn't fit in 128 bits");
        return int128(value);
    }

    /**
     * @dev Returns the downcasted int120 from int256, reverting on
     * overflow (when the input is less than smallest int120 or
     * greater than largest int120).
     *
     * Counterpart to Solidity's `int120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     *
     * _Available since v4.7._
     */
    function toInt120(int256 value) internal pure returns (int120) {
        require(value >= type(int120).min && value <= type(int120).max, "SafeCast: value doesn't fit in 120 bits");
        return int120(value);
    }

    /**
     * @dev Returns the downcasted int112 from int256, reverting on
     * overflow (when the input is less than smallest int112 or
     * greater than largest int112).
     *
     * Counterpart to Solidity's `int112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     *
     * _Available since v4.7._
     */
    function toInt112(int256 value) internal pure returns (int112) {
        require(value >= type(int112).min && value <= type(int112).max, "SafeCast: value doesn't fit in 112 bits");
        return int112(value);
    }

    /**
     * @dev Returns the downcasted int104 from int256, reverting on
     * overflow (when the input is less than smallest int104 or
     * greater than largest int104).
     *
     * Counterpart to Solidity's `int104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     *
     * _Available since v4.7._
     */
    function toInt104(int256 value) internal pure returns (int104) {
        require(value >= type(int104).min && value <= type(int104).max, "SafeCast: value doesn't fit in 104 bits");
        return int104(value);
    }

    /**
     * @dev Returns the downcasted int96 from int256, reverting on
     * overflow (when the input is less than smallest int96 or
     * greater than largest int96).
     *
     * Counterpart to Solidity's `int96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     *
     * _Available since v4.7._
     */
    function toInt96(int256 value) internal pure returns (int96) {
        require(value >= type(int96).min && value <= type(int96).max, "SafeCast: value doesn't fit in 96 bits");
        return int96(value);
    }

    /**
     * @dev Returns the downcasted int88 from int256, reverting on
     * overflow (when the input is less than smallest int88 or
     * greater than largest int88).
     *
     * Counterpart to Solidity's `int88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     *
     * _Available since v4.7._
     */
    function toInt88(int256 value) internal pure returns (int88) {
        require(value >= type(int88).min && value <= type(int88).max, "SafeCast: value doesn't fit in 88 bits");
        return int88(value);
    }

    /**
     * @dev Returns the downcasted int80 from int256, reverting on
     * overflow (when the input is less than smallest int80 or
     * greater than largest int80).
     *
     * Counterpart to Solidity's `int80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     *
     * _Available since v4.7._
     */
    function toInt80(int256 value) internal pure returns (int80) {
        require(value >= type(int80).min && value <= type(int80).max, "SafeCast: value doesn't fit in 80 bits");
        return int80(value);
    }

    /**
     * @dev Returns the downcasted int72 from int256, reverting on
     * overflow (when the input is less than smallest int72 or
     * greater than largest int72).
     *
     * Counterpart to Solidity's `int72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     *
     * _Available since v4.7._
     */
    function toInt72(int256 value) internal pure returns (int72) {
        require(value >= type(int72).min && value <= type(int72).max, "SafeCast: value doesn't fit in 72 bits");
        return int72(value);
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64) {
        require(value >= type(int64).min && value <= type(int64).max, "SafeCast: value doesn't fit in 64 bits");
        return int64(value);
    }

    /**
     * @dev Returns the downcasted int56 from int256, reverting on
     * overflow (when the input is less than smallest int56 or
     * greater than largest int56).
     *
     * Counterpart to Solidity's `int56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     *
     * _Available since v4.7._
     */
    function toInt56(int256 value) internal pure returns (int56) {
        require(value >= type(int56).min && value <= type(int56).max, "SafeCast: value doesn't fit in 56 bits");
        return int56(value);
    }

    /**
     * @dev Returns the downcasted int48 from int256, reverting on
     * overflow (when the input is less than smallest int48 or
     * greater than largest int48).
     *
     * Counterpart to Solidity's `int48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     *
     * _Available since v4.7._
     */
    function toInt48(int256 value) internal pure returns (int48) {
        require(value >= type(int48).min && value <= type(int48).max, "SafeCast: value doesn't fit in 48 bits");
        return int48(value);
    }

    /**
     * @dev Returns the downcasted int40 from int256, reverting on
     * overflow (when the input is less than smallest int40 or
     * greater than largest int40).
     *
     * Counterpart to Solidity's `int40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     *
     * _Available since v4.7._
     */
    function toInt40(int256 value) internal pure returns (int40) {
        require(value >= type(int40).min && value <= type(int40).max, "SafeCast: value doesn't fit in 40 bits");
        return int40(value);
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32) {
        require(value >= type(int32).min && value <= type(int32).max, "SafeCast: value doesn't fit in 32 bits");
        return int32(value);
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is less than smallest int24 or
     * greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     *
     * _Available since v4.7._
     */
    function toInt24(int256 value) internal pure returns (int24) {
        require(value >= type(int24).min && value <= type(int24).max, "SafeCast: value doesn't fit in 24 bits");
        return int24(value);
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16) {
        require(value >= type(int16).min && value <= type(int16).max, "SafeCast: value doesn't fit in 16 bits");
        return int16(value);
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8) {
        require(value >= type(int8).min && value <= type(int8).max, "SafeCast: value doesn't fit in 8 bits");
        return int8(value);
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     *
     * _Available since v3.0._
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/IERC20.sol";

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
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract FToken is ERC20, ERC20Burnable, Ownable {
  constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

  function mint(address to, uint256 amount) public onlyOwner {
    _mint(to, amount);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IFToken {
  function mint(address to, uint256 amount) external;

  function burn(uint256 amount) external;

  function burnFrom(address account, uint256 amount) external;

  function transferOwnership(address newOwner) external;

  function balanceOf(address user) external returns (uint256);
}

// SPDX-License-Identifier: ISC
pragma solidity >=0.8.16;

interface IRateCalculator {
    function name() external pure returns (string memory);

    function requireValidInitData(bytes calldata _initData) external pure;

    function getConstants() external pure returns (bytes memory _calldata);

    function getNewRate(bytes calldata _data, bytes calldata _initData) external view returns (uint64 _newRatePerSec);
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
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
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
contract ERC20 is Context, IERC20, IERC20Metadata {
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
    constructor(string memory name_, string memory symbol_) {
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
        }
        _balances[to] += amount;

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
        _balances[account] += amount;
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
        }
        _totalSupply -= amount;

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/extensions/ERC20Burnable.sol)

pragma solidity ^0.8.0;

import "../ERC20.sol";
import "../../../utils/Context.sol";

/**
 * @dev Extension of {ERC20} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
abstract contract ERC20Burnable is Context, ERC20 {
    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
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

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
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