// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../token/ControlledTokenProxyFactory.sol";
import "../token/TicketProxyFactory.sol";

/* solium-disable security/no-block-members */
contract ControlledTokenBuilder {

  event CreatedControlledToken(address indexed token);
  event CreatedTicket(address indexed token);

  ControlledTokenProxyFactory public controlledTokenProxyFactory;
  TicketProxyFactory public ticketProxyFactory;

  struct ControlledTokenConfig {
    string name;
    string symbol;
    uint8 decimals;
    TokenControllerInterface controller;
  }

  constructor (
    ControlledTokenProxyFactory _controlledTokenProxyFactory,
    TicketProxyFactory _ticketProxyFactory
  ) public {
    require(address(_controlledTokenProxyFactory) != address(0), "ControlledTokenBuilder/controlledTokenProxyFactory-not-zero");
    require(address(_ticketProxyFactory) != address(0), "ControlledTokenBuilder/ticketProxyFactory-not-zero");
    controlledTokenProxyFactory = _controlledTokenProxyFactory;
    ticketProxyFactory = _ticketProxyFactory;
  }

  function createControlledToken(
    ControlledTokenConfig calldata config
  ) external returns (ControlledToken) {
    ControlledToken token = controlledTokenProxyFactory.create();

    token.initialize(
      config.name,
      config.symbol,
      config.decimals,
      config.controller
    );

    emit CreatedControlledToken(address(token));

    return token;
  }

  function createTicket(
    ControlledTokenConfig calldata config
  ) external returns (Ticket) {
    Ticket token = ticketProxyFactory.create();

    token.initialize(
      config.name,
      config.symbol,
      config.decimals,
      config.controller
    );

    emit CreatedTicket(address(token));

    return token;
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "./ControlledToken.sol";
import "../external/openzeppelin/ProxyFactory.sol";

/// @title Controlled ERC20 Token Factory
/// @notice Minimal proxy pattern for creating new Controlled ERC20 Tokens
contract ControlledTokenProxyFactory is ProxyFactory {

  /// @notice Contract template for deploying proxied tokens
  ControlledToken public instance;

  /// @notice Initializes the Factory with an instance of the Controlled ERC20 Token
  constructor () public {
    instance = new ControlledToken();
  }

  /// @notice Creates a new Controlled ERC20 Token as a proxy of the template instance
  /// @return A reference to the new proxied Controlled ERC20 Token
  function create() external returns (ControlledToken) {
    return ControlledToken(deployMinimal(address(instance), ""));
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import "./Ticket.sol";
import "../external/openzeppelin/ProxyFactory.sol";

/// @title Controlled ERC20 Token Factory
/// @notice Minimal proxy pattern for creating new Controlled ERC20 Tokens
contract TicketProxyFactory is ProxyFactory {

  /// @notice Contract template for deploying proxied tokens
  Ticket public instance;

  /// @notice Initializes the Factory with an instance of the Controlled ERC20 Token
  constructor () public {
    instance = new Ticket();
  }

  /// @notice Creates a new Controlled ERC20 Token as a proxy of the template instance
  /// @return A reference to the new proxied Controlled ERC20 Token
  function create() external returns (Ticket) {
    return Ticket(deployMinimal(address(instance), ""));
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/drafts/ERC20PermitUpgradeable.sol";

import "./TokenControllerInterface.sol";
import "./ControlledTokenInterface.sol";

/// @title Controlled ERC20 Token
/// @notice ERC20 Tokens with a controller for minting & burning
contract ControlledToken is ERC20PermitUpgradeable, ControlledTokenInterface {
    /// @dev Emitted when an instance is initialized
    event Initialized(
        string _name,
        string _symbol,
        uint8 _decimals,
        TokenControllerInterface _controller
    );

    /// @notice Interface to the contract responsible for controlling mint/burn
    TokenControllerInterface public override controller;

    /// @notice Initializes the Controlled Token with Token Details and the Controller
    /// @param _name The name of the Token
    /// @param _symbol The symbol for the Token
    /// @param _decimals The number of decimals for the Token
    /// @param _controller Address of the Controller contract for minting & burning
    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        TokenControllerInterface _controller
    ) public virtual initializer {
        require(
            address(_controller) != address(0),
            "ControlledToken/controller-not-zero"
        );
        __ERC20_init(_name, _symbol);
        __ERC20Permit_init("PoolTogether ControlledToken");
        controller = _controller;
        _setupDecimals(_decimals);

        emit Initialized(_name, _symbol, _decimals, _controller);
    }

    /// @notice Allows the controller to mint tokens for a user account
    /// @dev May be overridden to provide more granular control over minting
    /// @param _user Address of the receiver of the minted tokens
    /// @param _amount Amount of tokens to mint
    function controllerMint(address _user, uint256 _amount)
        external
        virtual
        override
        onlyController
    {
        _mint(_user, _amount);
    }

    /// @notice Allows the controller to burn tokens from a user account
    /// @dev May be overridden to provide more granular control over burning
    /// @param _user Address of the holder account to burn tokens from
    /// @param _amount Amount of tokens to burn
    function controllerBurn(address _user, uint256 _amount)
        external
        virtual
        override
        onlyController
    {
        _burn(_user, _amount);
    }

    /// @notice Allows an operator via the controller to burn tokens on behalf of a user account
    /// @dev May be overridden to provide more granular control over operator-burning
    /// @param _operator Address of the operator performing the burn action via the controller contract
    /// @param _user Address of the holder account to burn tokens from
    /// @param _amount Amount of tokens to burn
    function controllerBurnFrom(
        address _operator,
        address _user,
        uint256 _amount
    ) external virtual override onlyController {
        if (_operator != _user) {
            uint256 decreasedAllowance = allowance(_user, _operator).sub(
                _amount,
                "ControlledToken/exceeds-allowance"
            );
            _approve(_user, _operator, decreasedAllowance);
        }
        _burn(_user, _amount);
    }

    /// @dev Function modifier to ensure that the caller is the controller contract
    modifier onlyController() {
        require(
            _msgSender() == address(controller),
            "ControlledToken/only-controller"
        );
        _;
    }

    /// @dev Controller hook to provide notifications & rule validations on token transfers to the controller.
    /// This includes minting and burning.
    /// May be overridden to provide more granular control over operator-burning
    /// @param from Address of the account sending the tokens (address(0x0) on minting)
    /// @param to Address of the account receiving the tokens (address(0x0) on burning)
    /// @param amount Amount of tokens being transferred
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        controller.beforeTokenTransfer(from, to, amount);
    }
}

pragma solidity 0.6.12;

// solium-disable security/no-inline-assembly
// solium-disable security/no-low-level-calls
contract ProxyFactory {

  event ProxyCreated(address proxy);

  function deployMinimal(address _logic, bytes memory _data) public returns (address proxy) {
    // Adapted from https://github.com/optionality/clone-factory/blob/32782f82dfc5a00d103a7e61a17a5dedbd1e8e9d/contracts/CloneFactory.sol
    bytes20 targetBytes = bytes20(_logic);
    assembly {
      let clone := mload(0x40)
      mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
      mstore(add(clone, 0x14), targetBytes)
      mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
      proxy := create(0, clone, 0x37)
    }

    emit ProxyCreated(address(proxy));

    if(_data.length > 0) {
      (bool success,) = proxy.call(_data);
      require(success, "ProxyFactory/constructor-call-failed");
    }
  }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.5 <0.8.0;

import "../token/ERC20/ERC20Upgradeable.sol";
import "./IERC20PermitUpgradeable.sol";
import "../cryptography/ECDSAUpgradeable.sol";
import "../utils/CountersUpgradeable.sol";
import "./EIP712Upgradeable.sol";
import "../proxy/Initializable.sol";

/**
 * @dev Implementation of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * _Available since v3.4._
 */
abstract contract ERC20PermitUpgradeable is Initializable, ERC20Upgradeable, IERC20PermitUpgradeable, EIP712Upgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    mapping (address => CountersUpgradeable.Counter) private _nonces;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private _PERMIT_TYPEHASH;

    /**
     * @dev Initializes the {EIP712} domain separator using the `name` parameter, and setting `version` to `"1"`.
     *
     * It's a good idea to use the same `name` that is defined as the ERC20 token name.
     */
    function __ERC20Permit_init(string memory name) internal initializer {
        __Context_init_unchained();
        __EIP712_init_unchained(name, "1");
        __ERC20Permit_init_unchained(name);
    }

    function __ERC20Permit_init_unchained(string memory name) internal initializer {
        _PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    }

    /**
     * @dev See {IERC20Permit-permit}.
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public virtual override {
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp <= deadline, "ERC20Permit: expired deadline");

        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                _nonces[owner].current(),
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSAUpgradeable.recover(hash, v, r, s);
        require(signer == owner, "ERC20Permit: invalid signature");

        _nonces[owner].increment();
        _approve(owner, spender, value);
    }

    /**
     * @dev See {IERC20Permit-nonces}.
     */
    function nonces(address owner) public view override returns (uint256) {
        return _nonces[owner].current();
    }

    /**
     * @dev See {IERC20Permit-DOMAIN_SEPARATOR}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.7.0;

/// @title Controlled ERC20 Token Interface
/// @notice Required interface for Controlled ERC20 Tokens linked to a Prize Pool
/// @dev Defines the spec required to be implemented by a Controlled ERC20 Token
interface TokenControllerInterface {

  /// @dev Controller hook to provide notifications & rule validations on token transfers to the controller.
  /// This includes minting and burning.
  /// @param from Address of the account sending the tokens (address(0x0) on minting)
  /// @param to Address of the account receiving the tokens (address(0x0) on burning)
  /// @param amount Amount of tokens being transferred
  function beforeTokenTransfer(address from, address to, uint256 amount) external;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "./TokenControllerInterface.sol";

/// @title Controlled ERC20 Token
/// @notice ERC20 Tokens with a controller for minting & burning
interface ControlledTokenInterface is IERC20Upgradeable {

  /// @notice Interface to the contract responsible for controlling mint/burn
  function controller() external view returns (TokenControllerInterface);

  /// @notice Allows the controller to mint tokens for a user account
  /// @dev May be overridden to provide more granular control over minting
  /// @param _user Address of the receiver of the minted tokens
  /// @param _amount Amount of tokens to mint
  function controllerMint(address _user, uint256 _amount) external;

  /// @notice Allows the controller to burn tokens from a user account
  /// @dev May be overridden to provide more granular control over burning
  /// @param _user Address of the holder account to burn tokens from
  /// @param _amount Amount of tokens to burn
  function controllerBurn(address _user, uint256 _amount) external;

  /// @notice Allows an operator via the controller to burn tokens on behalf of a user account
  /// @dev May be overridden to provide more granular control over operator-burning
  /// @param _operator Address of the operator performing the burn action via the controller contract
  /// @param _user Address of the holder account to burn tokens from
  /// @param _amount Amount of tokens to burn
  function controllerBurnFrom(address _operator, address _user, uint256 _amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../utils/ContextUpgradeable.sol";
import "./IERC20Upgradeable.sol";
import "../../math/SafeMathUpgradeable.sol";
import "../../proxy/Initializable.sol";

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
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
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
contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20Upgradeable {
    using SafeMathUpgradeable for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    function __ERC20_init(string memory name_, string memory symbol_) internal initializer {
        __Context_init_unchained();
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal initializer {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return _decimals;
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
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
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
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
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

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
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
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
    uint256[44] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20PermitUpgradeable {
    /**
     * @dev Sets `value` as the allowance of `spender` over `owner`'s tokens,
     * given `owner`'s signed approval.
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
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for `permit`, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSAUpgradeable {
    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        // Check the signature length
        if (signature.length != 65) {
            revert("ECDSA: invalid signature length");
        }

        // Divide the signature in r, s and v variables
        bytes32 r;
        bytes32 s;
        uint8 v;

        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        return recover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover-bytes32-bytes-} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (281): 0 < s < secp256k1n ÷ 2 + 1, and for v in (282): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "ECDSA: invalid signature 's' value");
        require(v == 27 || v == 28, "ECDSA: invalid signature 'v' value");

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0), "ECDSA: invalid signature");

        return signer;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * replicates the behavior of the
     * https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_sign[`eth_sign`]
     * JSON-RPC method.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../math/SafeMathUpgradeable.sol";

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented or decremented by one. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 * Since it is not possible to overflow a 256 bit integer with increments of one, `increment` can skip the {SafeMath}
 * overflow check, thereby saving gas. This does assume however correct usage, in that the underlying `_value` is never
 * directly accessed.
 */
library CountersUpgradeable {
    using SafeMathUpgradeable for uint256;

    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        // The {SafeMath} overflow check can be skipped here, see the comment at the top
        counter._value += 1;
    }

    function decrement(Counter storage counter) internal {
        counter._value = counter._value.sub(1);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
import "../proxy/Initializable.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP 712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding specified in the EIP is very generic, and such a generic implementation in Solidity is not feasible,
 * thus this contract does not implement the encoding itself. Protocols need to implement the type-specific encoding
 * they need in their contracts using a combination of `abi.encode` and `keccak256`.
 *
 * This contract implements the EIP 712 domain separator ({_domainSeparatorV4}) that is used as part of the encoding
 * scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA
 * ({_hashTypedDataV4}).
 *
 * The implementation of the domain separator was designed to be as efficient as possible while still properly updating
 * the chain id to protect against replay attacks on an eventual fork of the chain.
 *
 * NOTE: This contract implements the version of the encoding known as "v4", as implemented by the JSON RPC method
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
 *
 * _Available since v3.4._
 */
abstract contract EIP712Upgradeable is Initializable {
    /* solhint-disable var-name-mixedcase */
    bytes32 private _HASHED_NAME;
    bytes32 private _HASHED_VERSION;
    bytes32 private constant _TYPE_HASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    /* solhint-enable var-name-mixedcase */

    /**
     * @dev Initializes the domain separator and parameter caches.
     *
     * The meaning of `name` and `version` is specified in
     * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP 712]:
     *
     * - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
     * - `version`: the current major version of the signing domain.
     *
     * NOTE: These parameters cannot be changed except through a xref:learn::upgrading-smart-contracts.adoc[smart
     * contract upgrade].
     */
    function __EIP712_init(string memory name, string memory version) internal initializer {
        __EIP712_init_unchained(name, version);
    }

    function __EIP712_init_unchained(string memory name, string memory version) internal initializer {
        bytes32 hashedName = keccak256(bytes(name));
        bytes32 hashedVersion = keccak256(bytes(version));
        _HASHED_NAME = hashedName;
        _HASHED_VERSION = hashedVersion;
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        return _buildDomainSeparator(_TYPE_HASH, _EIP712NameHash(), _EIP712VersionHash());
    }

    function _buildDomainSeparator(bytes32 typeHash, bytes32 name, bytes32 version) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                typeHash,
                name,
                version,
                _getChainId(),
                address(this)
            )
        );
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
     *
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     */
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparatorV4(), structHash));
    }

    function _getChainId() private view returns (uint256 chainId) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        // solhint-disable-next-line no-inline-assembly
        assembly {
            chainId := chainid()
        }
    }

    /**
     * @dev The hash of the name parameter for the EIP712 domain.
     *
     * NOTE: This function reads from storage by default, but can be redefined to return a constant value if gas costs
     * are a concern.
     */
    function _EIP712NameHash() internal virtual view returns (bytes32) {
        return _HASHED_NAME;
    }

    /**
     * @dev The hash of the version parameter for the EIP712 domain.
     *
     * NOTE: This function reads from storage by default, but can be redefined to return a constant value if gas costs
     * are a concern.
     */
    function _EIP712VersionHash() internal virtual view returns (bytes32) {
        return _HASHED_VERSION;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

// solhint-disable-next-line compiler-version
pragma solidity >=0.4.24 <0.8.0;

import "../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {

    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || _isConstructor() || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
import "../proxy/Initializable.sol";

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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

pragma solidity >=0.6.0 <0.8.0;

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
library SafeMathUpgradeable {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

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
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
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
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
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
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
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
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

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

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "sortition-sum-tree-factory/contracts/SortitionSumTreeFactory.sol";
import "@pooltogether/uniform-random-number/contracts/UniformRandomNumber.sol";

import "./ControlledToken.sol";
import "./TicketInterface.sol";

contract Ticket is ControlledToken, TicketInterface {
  using SortitionSumTreeFactory for SortitionSumTreeFactory.SortitionSumTrees;

  bytes32 constant private TREE_KEY = keccak256("PoolTogether/Ticket");
  uint256 constant private MAX_TREE_LEAVES = 5;

  /// @dev Emitted when an instance is initialized
  event Initialized(
    string _name,
    string _symbol,
    uint8 _decimals,
    TokenControllerInterface _controller
  );

  // Ticket-weighted odds
  SortitionSumTreeFactory.SortitionSumTrees internal sortitionSumTrees;

  /// @notice Initializes the Controlled Token with Token Details and the Controller
  /// @param _name The name of the Token
  /// @param _symbol The symbol for the Token
  /// @param _decimals The number of decimals for the Token
  /// @param _controller Address of the Controller contract for minting & burning
  function initialize(
    string memory _name,
    string memory _symbol,
    uint8 _decimals,
    TokenControllerInterface _controller
  )
    public
    virtual
    override
    initializer
  {
    require(address(_controller) != address(0), "Ticket/controller-not-zero");
    ControlledToken.initialize(_name, _symbol, _decimals, _controller);
    sortitionSumTrees.createTree(TREE_KEY, MAX_TREE_LEAVES);
    emit Initialized(
      _name,
      _symbol,
      _decimals,
      _controller
    );
  }

  /// @notice Returns the user's chance of winning.
  function chanceOf(address user) external view returns (uint256) {
    return sortitionSumTrees.stakeOf(TREE_KEY, bytes32(uint256(user)));
  }

  /// @notice Selects a user using a random number.  The random number will be uniformly bounded to the ticket totalSupply.
  /// @param randomNumber The random number to use to select a user.
  /// @return The winner
  function draw(uint256 randomNumber) external view override returns (address) {
    uint256 bound = totalSupply();
    address selected;
    if (bound == 0) {
      selected = address(0);
    } else {
      uint256 token = UniformRandomNumber.uniform(randomNumber, bound);
      selected = address(uint256(sortitionSumTrees.draw(TREE_KEY, token)));
    }
    return selected;
  }

  /// @dev Controller hook to provide notifications & rule validations on token transfers to the controller.
  /// This includes minting and burning.
  /// May be overridden to provide more granular control over operator-burning
  /// @param from Address of the account sending the tokens (address(0x0) on minting)
  /// @param to Address of the account receiving the tokens (address(0x0) on burning)
  /// @param amount Amount of tokens being transferred
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
    super._beforeTokenTransfer(from, to, amount);

    // optimize: ignore transfers to self
    if (from == to) {
      return;
    }

    if (from != address(0)) {
      uint256 fromBalance = balanceOf(from).sub(amount);
      sortitionSumTrees.set(TREE_KEY, fromBalance, bytes32(uint256(from)));
    }

    if (to != address(0)) {
      uint256 toBalance = balanceOf(to).add(amount);
      sortitionSumTrees.set(TREE_KEY, toBalance, bytes32(uint256(to)));
    }
  }

}

/**
 *  @reviewers: [@clesaege, @unknownunknown1, @ferittuncer]
 *  @auditors: []
 *  @bounties: [<14 days 10 ETH max payout>]
 *  @deployments: []
 */

pragma solidity ^0.6.0;

/**
 *  @title SortitionSumTreeFactory
 *  @author Enrique Piqueras - <[email protected]>
 *  @dev A factory of trees that keep track of staked values for sortition.
 */
library SortitionSumTreeFactory {
    /* Structs */

    struct SortitionSumTree {
        uint K; // The maximum number of childs per node.
        // We use this to keep track of vacant positions in the tree after removing a leaf. This is for keeping the tree as balanced as possible without spending gas on moving nodes around.
        uint[] stack;
        uint[] nodes;
        // Two-way mapping of IDs to node indexes. Note that node index 0 is reserved for the root node, and means the ID does not have a node.
        mapping(bytes32 => uint) IDsToNodeIndexes;
        mapping(uint => bytes32) nodeIndexesToIDs;
    }

    /* Storage */

    struct SortitionSumTrees {
        mapping(bytes32 => SortitionSumTree) sortitionSumTrees;
    }

    /* internal */

    /**
     *  @dev Create a sortition sum tree at the specified key.
     *  @param _key The key of the new tree.
     *  @param _K The number of children each node in the tree should have.
     */
    function createTree(SortitionSumTrees storage self, bytes32 _key, uint _K) internal {
        SortitionSumTree storage tree = self.sortitionSumTrees[_key];
        require(tree.K == 0, "Tree already exists.");
        require(_K > 1, "K must be greater than one.");
        tree.K = _K;
        tree.stack = new uint[](0);
        tree.nodes = new uint[](0);
        tree.nodes.push(0);
    }

    /**
     *  @dev Set a value of a tree.
     *  @param _key The key of the tree.
     *  @param _value The new value.
     *  @param _ID The ID of the value.
     *  `O(log_k(n))` where
     *  `k` is the maximum number of childs per node in the tree,
     *   and `n` is the maximum number of nodes ever appended.
     */
    function set(SortitionSumTrees storage self, bytes32 _key, uint _value, bytes32 _ID) internal {
        SortitionSumTree storage tree = self.sortitionSumTrees[_key];
        uint treeIndex = tree.IDsToNodeIndexes[_ID];

        if (treeIndex == 0) { // No existing node.
            if (_value != 0) { // Non zero value.
                // Append.
                // Add node.
                if (tree.stack.length == 0) { // No vacant spots.
                    // Get the index and append the value.
                    treeIndex = tree.nodes.length;
                    tree.nodes.push(_value);

                    // Potentially append a new node and make the parent a sum node.
                    if (treeIndex != 1 && (treeIndex - 1) % tree.K == 0) { // Is first child.
                        uint parentIndex = treeIndex / tree.K;
                        bytes32 parentID = tree.nodeIndexesToIDs[parentIndex];
                        uint newIndex = treeIndex + 1;
                        tree.nodes.push(tree.nodes[parentIndex]);
                        delete tree.nodeIndexesToIDs[parentIndex];
                        tree.IDsToNodeIndexes[parentID] = newIndex;
                        tree.nodeIndexesToIDs[newIndex] = parentID;
                    }
                } else { // Some vacant spot.
                    // Pop the stack and append the value.
                    treeIndex = tree.stack[tree.stack.length - 1];
                    tree.stack.pop();
                    tree.nodes[treeIndex] = _value;
                }

                // Add label.
                tree.IDsToNodeIndexes[_ID] = treeIndex;
                tree.nodeIndexesToIDs[treeIndex] = _ID;

                updateParents(self, _key, treeIndex, true, _value);
            }
        } else { // Existing node.
            if (_value == 0) { // Zero value.
                // Remove.
                // Remember value and set to 0.
                uint value = tree.nodes[treeIndex];
                tree.nodes[treeIndex] = 0;

                // Push to stack.
                tree.stack.push(treeIndex);

                // Clear label.
                delete tree.IDsToNodeIndexes[_ID];
                delete tree.nodeIndexesToIDs[treeIndex];

                updateParents(self, _key, treeIndex, false, value);
            } else if (_value != tree.nodes[treeIndex]) { // New, non zero value.
                // Set.
                bool plusOrMinus = tree.nodes[treeIndex] <= _value;
                uint plusOrMinusValue = plusOrMinus ? _value - tree.nodes[treeIndex] : tree.nodes[treeIndex] - _value;
                tree.nodes[treeIndex] = _value;

                updateParents(self, _key, treeIndex, plusOrMinus, plusOrMinusValue);
            }
        }
    }

    /* internal Views */

    /**
     *  @dev Query the leaves of a tree. Note that if `startIndex == 0`, the tree is empty and the root node will be returned.
     *  @param _key The key of the tree to get the leaves from.
     *  @param _cursor The pagination cursor.
     *  @param _count The number of items to return.
     *  @return startIndex The index at which leaves start
     *  @return values The values of the returned leaves
     *  @return hasMore Whether there are more for pagination.
     *  `O(n)` where
     *  `n` is the maximum number of nodes ever appended.
     */
    function queryLeafs(
        SortitionSumTrees storage self,
        bytes32 _key,
        uint _cursor,
        uint _count
    ) internal view returns(uint startIndex, uint[] memory values, bool hasMore) {
        SortitionSumTree storage tree = self.sortitionSumTrees[_key];

        // Find the start index.
        for (uint i = 0; i < tree.nodes.length; i++) {
            if ((tree.K * i) + 1 >= tree.nodes.length) {
                startIndex = i;
                break;
            }
        }

        // Get the values.
        uint loopStartIndex = startIndex + _cursor;
        values = new uint[](loopStartIndex + _count > tree.nodes.length ? tree.nodes.length - loopStartIndex : _count);
        uint valuesIndex = 0;
        for (uint j = loopStartIndex; j < tree.nodes.length; j++) {
            if (valuesIndex < _count) {
                values[valuesIndex] = tree.nodes[j];
                valuesIndex++;
            } else {
                hasMore = true;
                break;
            }
        }
    }

    /**
     *  @dev Draw an ID from a tree using a number. Note that this function reverts if the sum of all values in the tree is 0.
     *  @param _key The key of the tree.
     *  @param _drawnNumber The drawn number.
     *  @return ID The drawn ID.
     *  `O(k * log_k(n))` where
     *  `k` is the maximum number of childs per node in the tree,
     *   and `n` is the maximum number of nodes ever appended.
     */
    function draw(SortitionSumTrees storage self, bytes32 _key, uint _drawnNumber) internal view returns(bytes32 ID) {
        SortitionSumTree storage tree = self.sortitionSumTrees[_key];
        uint treeIndex = 0;
        uint currentDrawnNumber = _drawnNumber % tree.nodes[0];

        while ((tree.K * treeIndex) + 1 < tree.nodes.length)  // While it still has children.
            for (uint i = 1; i <= tree.K; i++) { // Loop over children.
                uint nodeIndex = (tree.K * treeIndex) + i;
                uint nodeValue = tree.nodes[nodeIndex];

                if (currentDrawnNumber >= nodeValue) currentDrawnNumber -= nodeValue; // Go to the next child.
                else { // Pick this child.
                    treeIndex = nodeIndex;
                    break;
                }
            }
        
        ID = tree.nodeIndexesToIDs[treeIndex];
    }

    /** @dev Gets a specified ID's associated value.
     *  @param _key The key of the tree.
     *  @param _ID The ID of the value.
     *  @return value The associated value.
     */
    function stakeOf(SortitionSumTrees storage self, bytes32 _key, bytes32 _ID) internal view returns(uint value) {
        SortitionSumTree storage tree = self.sortitionSumTrees[_key];
        uint treeIndex = tree.IDsToNodeIndexes[_ID];

        if (treeIndex == 0) value = 0;
        else value = tree.nodes[treeIndex];
    }

    function total(SortitionSumTrees storage self, bytes32 _key) internal view returns (uint) {
        SortitionSumTree storage tree = self.sortitionSumTrees[_key];
        if (tree.nodes.length == 0) {
            return 0;
        } else {
            return tree.nodes[0];
        }
    }

    /* Private */

    /**
     *  @dev Update all the parents of a node.
     *  @param _key The key of the tree to update.
     *  @param _treeIndex The index of the node to start from.
     *  @param _plusOrMinus Wether to add (true) or substract (false).
     *  @param _value The value to add or substract.
     *  `O(log_k(n))` where
     *  `k` is the maximum number of childs per node in the tree,
     *   and `n` is the maximum number of nodes ever appended.
     */
    function updateParents(SortitionSumTrees storage self, bytes32 _key, uint _treeIndex, bool _plusOrMinus, uint _value) private {
        SortitionSumTree storage tree = self.sortitionSumTrees[_key];

        uint parentIndex = _treeIndex;
        while (parentIndex != 0) {
            parentIndex = (parentIndex - 1) / tree.K;
            tree.nodes[parentIndex] = _plusOrMinus ? tree.nodes[parentIndex] + _value : tree.nodes[parentIndex] - _value;
        }
    }
}

/**
Copyright 2019 PoolTogether LLC

This file is part of PoolTogether.

PoolTogether is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation under version 3 of the License.

PoolTogether is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with PoolTogether.  If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity >=0.6.0 <0.8.0;

/**
 * @author Brendan Asselstine
 * @notice A library that uses entropy to select a random number within a bound.  Compensates for modulo bias.
 * @dev Thanks to https://medium.com/hownetworks/dont-waste-cycles-with-modulo-bias-35b6fdafcf94
 */
library UniformRandomNumber {
  /// @notice Select a random number without modulo bias using a random seed and upper bound
  /// @param _entropy The seed for randomness
  /// @param _upperBound The upper bound of the desired number
  /// @return A random number less than the _upperBound
  function uniform(uint256 _entropy, uint256 _upperBound) internal pure returns (uint256) {
    require(_upperBound > 0, "UniformRand/min-bound");
    uint256 min = -_upperBound % _upperBound;
    uint256 random = _entropy;
    while (true) {
      if (random >= min) {
        break;
      }
      random = uint256(keccak256(abi.encodePacked(random)));
    }
    return random % _upperBound;
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.7.0;

/// @title Interface that allows a user to draw an address using an index
interface TicketInterface {
  /// @notice Selects a user using a random number.  The random number will be uniformly bounded to the ticket totalSupply.
  /// @param randomNumber The random number to use to select a user.
  /// @return The winner
  function draw(uint256 randomNumber) external view returns (address);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./ControlledTokenBuilder.sol";
import "../prize-strategy/multiple-winners/MultipleWinnersProxyFactory.sol";

/* solium-disable security/no-block-members */
contract MultipleWinnersBuilder {

  event MultipleWinnersCreated(address indexed prizeStrategy);

  struct MultipleWinnersConfig {
    RNGInterface rngService;
    uint256 prizePeriodStart;
    uint256 prizePeriodSeconds;
    string ticketName;
    string ticketSymbol;
    string sponsorshipName;
    string sponsorshipSymbol;
    uint256 ticketCreditLimitMantissa;
    uint256 ticketCreditRateMantissa;
    uint256 numberOfWinners;
    MultipleWinners.PrizeSplitConfig[] prizeSplits;
    bool splitExternalErc20Awards;
  }

  MultipleWinnersProxyFactory public multipleWinnersProxyFactory;
  ControlledTokenBuilder public controlledTokenBuilder;

  constructor (
    MultipleWinnersProxyFactory _multipleWinnersProxyFactory,
    ControlledTokenBuilder _controlledTokenBuilder
  ) public {
    require(address(_multipleWinnersProxyFactory) != address(0), "MultipleWinnersBuilder/multipleWinnersProxyFactory-not-zero");
    require(address(_controlledTokenBuilder) != address(0), "MultipleWinnersBuilder/token-builder-not-zero");
    multipleWinnersProxyFactory = _multipleWinnersProxyFactory;
    controlledTokenBuilder = _controlledTokenBuilder;
  }

  function createMultipleWinners(
    PrizePool prizePool,
    MultipleWinnersConfig memory prizeStrategyConfig,
    uint8 decimals,
    address owner
  ) external returns (MultipleWinners) {
    MultipleWinners mw = multipleWinnersProxyFactory.create();

    Ticket ticket = _createTicket(
      prizeStrategyConfig.ticketName,
      prizeStrategyConfig.ticketSymbol,
      decimals,
      prizePool
    );

    ControlledToken sponsorship = _createSponsorship(
      prizeStrategyConfig.sponsorshipName,
      prizeStrategyConfig.sponsorshipSymbol,
      decimals,
      prizePool
    );

    mw.initializeMultipleWinners(
      prizeStrategyConfig.prizePeriodStart,
      prizeStrategyConfig.prizePeriodSeconds,
      prizePool,
      ticket,
      sponsorship,
      prizeStrategyConfig.rngService,
      prizeStrategyConfig.numberOfWinners
    );

    mw.setPrizeSplits(prizeStrategyConfig.prizeSplits);

    if (prizeStrategyConfig.splitExternalErc20Awards) {
      mw.setSplitExternalErc20Awards(true);
    }

    mw.transferOwnership(owner);

    emit MultipleWinnersCreated(address(mw));

    return mw;
  }

  function _createTicket(
    string memory name,
    string memory token,
    uint8 decimals,
    PrizePool prizePool
  ) internal returns (Ticket) {
    return controlledTokenBuilder.createTicket(
      ControlledTokenBuilder.ControlledTokenConfig(
        name,
        token,
        decimals,
        prizePool
      )
    );
  }

  function _createSponsorship(
    string memory name,
    string memory token,
    uint8 decimals,
    PrizePool prizePool
  ) internal returns (ControlledToken) {
    return controlledTokenBuilder.createControlledToken(
      ControlledTokenBuilder.ControlledTokenConfig(
        name,
        token,
        decimals,
        prizePool
      )
    );
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "./MultipleWinners.sol";
import "../../external/openzeppelin/ProxyFactory.sol";

/// @title Creates a minimal proxy to the MultipleWinners prize strategy.  Very cheap to deploy.
contract MultipleWinnersProxyFactory is ProxyFactory {

  MultipleWinners public instance;

  constructor () public {
    instance = new MultipleWinners();
  }

  function create() external returns (MultipleWinners) {
    return MultipleWinners(deployMinimal(address(instance), ""));
  }

}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../PrizeSplit.sol";
import "../PeriodicPrizeStrategy.sol";

contract MultipleWinners is PeriodicPrizeStrategy, PrizeSplit {
    // Maximum number number of winners per award distribution period
    uint256 internal __numberOfWinners;

    // Toggle for distributing external ERC 20 awards to all winners
    bool public splitExternalErc20Awards;

    // Mapping of addresses isBlocked status. Can prevent an address from selected during award distribution
    mapping(address => bool) public isBlocklisted;

    // Carry over the awarded prize for the next drawing when selected winners is less than __numberOfWinners
    bool public carryOverBlocklist;

    // Limit ticket.draw() retry attempts when a blocked address is selected in _distribute.
    uint256 public blocklistRetryCount;

    /**
     * @notice Emitted when splitExternalErc20Awards is toggled.
     * @dev Emitted when splitExternalErc20Awards is toggled between awarding external ERC20 to main or all winners.
     */
    event SplitExternalErc20AwardsSet(bool splitExternalErc20Awards);

    /**
     * @notice Emitted when numberOfWinners is set.
     * @dev Emitted when numberOfWinners is set, which limits the maximum number of potentially selected winners.
     * @param numberOfWinners Maximum potentially selected winners
     */
    event NumberOfWinnersSet(uint256 numberOfWinners);

    /**
     * @notice Emitted when carryOverBlocklist is toggled.
     * @dev Emitted when carryOverBlocklist is toggled for distribution of the primary and secondary prizes.
     * @param carry Awarded prize carry over status
     */
    event BlocklistCarrySet(bool carry);

    /**
     * @notice Emitted when a user is blocked/unblocked from receiving a prize award.
     * @dev Emitted when a contract owner blocks/unblocks user from award selection in _distribute.
     * @param user Address of user to block or unblock
     * @param isBlocked User blocked status
     */
    event BlocklistSet(address indexed user, bool isBlocked);

    /**
     * @notice Emitted when a new draw retry limit is set.
     * @dev Emitted when a new draw retry limit is set. Retry limit is set to limit gas spendings if a blocked user continues to be drawn.
     * @param count Number of winner selection retry attempts
     */
    event BlocklistRetryCountSet(uint256 count);

    /**
     * @notice Emitted when the winner selection retry limit is reached during award distribution.
     * @dev Emitted when the maximum number of users has not been selected after the blocklistRetryCount is reached.
     * @param numberOfWinners Total number of winners selected before the blocklistRetryCount is reached.
     */
    event RetryMaxLimitReached(uint256 numberOfWinners);

    /**
     * @notice Emitted when no winner can be selected during the prize distribution.
     * @dev Emitted when no winner can be selected in _distribute due to ticket.totalSupply() equaling zero.
     */
    event NoWinners();

    function initializeMultipleWinners(
        uint256 _prizePeriodStart,
        uint256 _prizePeriodSeconds,
        PrizePool _prizePool,
        TicketInterface _ticket,
        IERC20Upgradeable _sponsorship,
        RNGInterface _rng,
        uint256 _numberOfWinners
    ) public initializer {
        IERC20Upgradeable[] memory _externalErc20Awards;

        PeriodicPrizeStrategy.initialize(
            _prizePeriodStart,
            _prizePeriodSeconds,
            _prizePool,
            _ticket,
            _sponsorship,
            _rng,
            _externalErc20Awards
        );

        _setNumberOfWinners(_numberOfWinners);
    }

    /**
     * @notice Block/unblock a user from winning during prize distribution.
     * @dev Block/unblock a user from winning award in prize distribution by updating the isBlocklisted mapping.
     * @param _user Address of blocked user
     * @param _isBlocked Blocked Status (true or false) of user
     */
    function setBlocklisted(address _user, bool _isBlocked)
        external
        onlyOwner
        requireAwardNotInProgress
        returns (bool)
    {
        isBlocklisted[_user] = _isBlocked;

        emit BlocklistSet(_user, _isBlocked);

        return true;
    }

    /**
     * @notice Toggle if an unawarded prize amount should be kept for the next draw or evenly distrubted to selected winners.
     * @dev Toggles if the main prize (prizePool.captureAwardBalance) and secondary prizes (LootBox) should be kept for the next draw or evenly distrubted if maximum number of winners is not selected.
     * @param _carry Award carry over status (true or false)
     */
    function setCarryBlocklist(bool _carry)
        external
        onlyOwner
        requireAwardNotInProgress
        returns (bool)
    {
        carryOverBlocklist = _carry;

        emit BlocklistCarrySet(_carry);

        return true;
    }

    /**
     * @notice Sets the number of attempts for winner selection if a blocked address is chosen.
     * @dev Limits winner selection (ticket.draw) retries to avoid to gas limit reached errors. Increases the probability of not reaching the maximum number of winners if to low.
     * @param _count Number of retry attempts
     */
    function setBlocklistRetryCount(uint256 _count)
        external
        onlyOwner
        requireAwardNotInProgress
        returns (bool)
    {
        blocklistRetryCount = _count;

        emit BlocklistRetryCountSet(_count);

        return true;
    }

    /**
     * @notice Toggle external ERC20 awards for all prize winners.
     * @dev Toggle external ERC20 awards for all prize winners. If unset will distribute external ERC20 awards to main winner.
     * @param _splitExternalErc20Awards Toggle splitting external ERC20 awards.
     */
    function setSplitExternalErc20Awards(bool _splitExternalErc20Awards)
        external
        onlyOwner
        requireAwardNotInProgress
    {
        splitExternalErc20Awards = _splitExternalErc20Awards;

        emit SplitExternalErc20AwardsSet(splitExternalErc20Awards);
    }

    /**
     * @notice Sets maximum number of winners.
     * @dev Sets maximum number of winners per award distribution period.
     * @param count Number of winners.
     */
    function setNumberOfWinners(uint256 count)
        external
        onlyOwner
        requireAwardNotInProgress
    {
        _setNumberOfWinners(count);
    }

    /**
     * @dev Set the maximum number of winners. Must be greater than 0.
     * @param count Number of winners.
     */
    function _setNumberOfWinners(uint256 count) internal {
        require(count > 0, "MultipleWinners/winners-gte-one");

        __numberOfWinners = count;
        emit NumberOfWinnersSet(count);
    }

    /**
     * @notice Maximum number of winners per award distribution period
     * @dev Read maximum number of winners per award distribution period from internal __numberOfWinners variable.
     * @return __numberOfWinners The total number of winners per prize award.
     */
    function numberOfWinners() external view returns (uint256) {
        return __numberOfWinners;
    }

    /**
     * @notice Award ticket or sponsorship tokens to prize split recipient.
     * @dev Award ticket or sponsorship tokens to prize split recipient via the linked PrizePool contract.
     * @param target Recipient of minted tokens
     * @param amount Amount of minted tokens
     * @param tokenIndex Index (0 or 1) of a token in the prizePool.tokens mapping
     */
    function _awardPrizeSplitAmount(
        address target,
        uint256 amount,
        uint8 tokenIndex
    ) internal override {
        _awardToken(target, amount, tokenIndex);
    }

    /**
     * @notice Distributes captured award balance to winners
     * @dev Distributes the captured award balance to the main winner and secondary winners if __numberOfWinners greater than 1.
     * @param randomNumber Random number seed used to select winners
     */
    function _distribute(uint256 randomNumber) internal override {
        uint256 prize = prizePool.captureAwardBalance();

        // distributes prize to prize splits and returns remaining award.
        prize = _distributePrizeSplits(prize);

        if (IERC20Upgradeable(address(ticket)).totalSupply() == 0) {
            emit NoWinners();
            return;
        }

        bool _carryOverBlocklistPrizes = carryOverBlocklist;

        // main winner is simply the first that is drawn
        uint256 numberOfWinners = __numberOfWinners;
        address[] memory winners = new address[](numberOfWinners);
        uint256 nextRandom = randomNumber;
        uint256 winnerCount = 0;
        uint256 retries = 0;
        uint256 _retryCount = blocklistRetryCount;
        while (winnerCount < numberOfWinners) {
            address winner = ticket.draw(nextRandom);

            if (!isBlocklisted[winner]) {
                winners[winnerCount++] = winner;
            } else if (++retries >= _retryCount) {
                emit RetryMaxLimitReached(winnerCount);
                if (winnerCount == 0) {
                    emit NoWinners();
                }
                break;
            }

            // add some arbitrary numbers to the previous random number to ensure no matches with the UniformRandomNumber lib
            bytes32 nextRandomHash = keccak256(
                abi.encodePacked(nextRandom + 499 + winnerCount * 521)
            );
            nextRandom = uint256(nextRandomHash);
        }

        // yield prize is split up among all winners
        uint256 prizeShare = _carryOverBlocklistPrizes
            ? prize.div(numberOfWinners)
            : prize.div(winnerCount);
        if (prizeShare > 0) {
            for (uint256 i = 0; i < winnerCount; i++) {
                _awardTickets(winners[i], prizeShare);
            }
        }

        if (splitExternalErc20Awards) {
            address currentToken = externalErc20s.start();
            while (
                currentToken != address(0) &&
                currentToken != externalErc20s.end()
            ) {
                uint256 balance = IERC20Upgradeable(currentToken).balanceOf(
                    address(prizePool)
                );
                uint256 split = _carryOverBlocklistPrizes
                    ? balance.div(numberOfWinners)
                    : balance.div(winnerCount);
                if (split > 0) {
                    for (uint256 i = 0; i < winnerCount; i++) {
                        prizePool.awardExternalERC20(
                            winners[i],
                            currentToken,
                            split
                        );
                    }
                }
                currentToken = externalErc20s.next(currentToken);
            }
        } else {
            _awardExternalErc20s(winners[0]);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
  * @title Abstract prize split contract for adding unique award distribution to static addresses. 
  * @author Kames Geraghty (PoolTogether Inc)
*/
abstract contract PrizeSplit is OwnableUpgradeable {
  using SafeMathUpgradeable for uint256;
  
  PrizeSplitConfig[] internal _prizeSplits;

  /**
    * @notice The prize split configuration struct.
    * @dev The prize split configuration struct used to award prize splits during distribution.
    * @param target Address of recipient receiving the prize split distribution
    * @param percentage Percentage of prize split using a 0-1000 range for single decimal precision i.e. 125 = 12.5%
    * @param token Position of controlled token in prizePool.tokens (i.e. ticket or sponsorship)
  */
  struct PrizeSplitConfig {
      address target;
      uint16 percentage;
      uint8 token;
  }

  /**
    * @notice Emitted when a PrizeSplitConfig config is added or updated.
    * @dev Emitted when aPrizeSplitConfig config is added or updated in setPrizeSplits or setPrizeSplit.
    * @param target Address of prize split recipient
    * @param percentage Percentage of prize split. Must be between 0 and 1000 for single decimal precision
    * @param token Index (0 or 1) of token in the prizePool.tokens mapping
    * @param index Index of prize split in the prizeSplts array
  */
  event PrizeSplitSet(address indexed target, uint16 percentage, uint8 token, uint256 index);

  /**
    * @notice Emitted when a PrizeSplitConfig config is removed.
    * @dev Emitted when a PrizeSplitConfig config is removed from the _prizeSplits array.
    * @param target Index of a previously active prize split config
  */
  event PrizeSplitRemoved(uint256 indexed target);

  /**
    * @notice Mints ticket or sponsorship tokens to prize split recipient.
    * @dev Mints ticket or sponsorship tokens to prize split recipient via the linked PrizePool contract.
    * @param target Recipient of minted tokens
    * @param amount Amount of minted tokens
    * @param tokenIndex Index (0 or 1) of a token in the prizePool.tokens mapping
  */
  function _awardPrizeSplitAmount(address target, uint256 amount, uint8 tokenIndex) virtual internal;

  /**
    * @notice Read all prize splits configs.
    * @dev Read all PrizeSplitConfig structs stored in _prizeSplits.
    * @return _prizeSplits Array of PrizeSplitConfig structs
  */
  function prizeSplits() external view returns (PrizeSplitConfig[] memory) {
    return _prizeSplits;
  }

  /**
    * @notice Read prize split config from active PrizeSplits.
    * @dev Read PrizeSplitConfig struct from _prizeSplits array.
    * @param prizeSplitIndex Index position of PrizeSplitConfig
    * @return PrizeSplitConfig Single prize split config
  */
  function prizeSplit(uint256 prizeSplitIndex) external view returns (PrizeSplitConfig memory) {
    return _prizeSplits[prizeSplitIndex];
  }

  /**
    * @notice Set and remove prize split(s) configs.
    * @dev Set and remove prize split configs by passing a new PrizeSplitConfig structs array. Will remove existing PrizeSplitConfig(s) if passed array length is less than existing _prizeSplits length.
    * @param newPrizeSplits Array of PrizeSplitConfig structs
  */
  function setPrizeSplits(PrizeSplitConfig[] calldata newPrizeSplits) external onlyOwner {
    uint256 newPrizeSplitsLength = newPrizeSplits.length;

    // Add and/or update prize split configs using newPrizeSplits PrizeSplitConfig structs array.
    for (uint256 index = 0; index < newPrizeSplitsLength; index++) {
      PrizeSplitConfig memory split = newPrizeSplits[index];
      require(split.token <= 1, "MultipleWinners/invalid-prizesplit-token");
      require(split.target != address(0), "MultipleWinners/invalid-prizesplit-target");
      
      if (_prizeSplits.length <= index) {
        _prizeSplits.push(split);
      } else {
        PrizeSplitConfig memory currentSplit = _prizeSplits[index];
        if (split.target != currentSplit.target || split.percentage != currentSplit.percentage || split.token != currentSplit.token) {
          _prizeSplits[index] = split;
        } else {
          continue;
        }
      }

      // Emit the added/updated prize split config.
      emit PrizeSplitSet(split.target, split.percentage, split.token, index);
    }

    // Remove old prize splits configs. Match storage _prizesSplits.length with the passed newPrizeSplits.length
    while (_prizeSplits.length > newPrizeSplitsLength) {
      uint256 _index = _prizeSplits.length.sub(1);
      _prizeSplits.pop();
      emit PrizeSplitRemoved(_index);
    }

    // Total prize split do not exceed 100%
    uint256 totalPercentage = _totalPrizeSplitPercentageAmount();
    require(totalPercentage <= 1000, "MultipleWinners/invalid-prizesplit-percentage-total");
  }

  /**
    * @notice Updates a previously set prize split config.
    * @dev Updates a prize split config by passing a new PrizeSplitConfig struct and current index position. Limited to contract owner.
    * @param prizeStrategySplit PrizeSplitConfig config struct
    * @param prizeSplitIndex Index position of PrizeSplitConfig to update
  */
  function setPrizeSplit(PrizeSplitConfig memory prizeStrategySplit, uint8 prizeSplitIndex) external onlyOwner {
    require(prizeSplitIndex < _prizeSplits.length, "MultipleWinners/nonexistent-prizesplit");
    require(prizeStrategySplit.token <= 1, "MultipleWinners/invalid-prizesplit-token");
    require(prizeStrategySplit.target != address(0), "MultipleWinners/invalid-prizesplit-target");
    
    // Update the prize split config
    _prizeSplits[prizeSplitIndex] = prizeStrategySplit;

    // Total prize split do not exceed 100%
    uint256 totalPercentage = _totalPrizeSplitPercentageAmount();
    require(totalPercentage <= 1000, "MultipleWinners/invalid-prizesplit-percentage-total");

    // Emit updated prize split config
    emit PrizeSplitSet(prizeStrategySplit.target, prizeStrategySplit.percentage, prizeStrategySplit.token, prizeSplitIndex);
  }

  /**
  * @notice Calculate single prize split distribution amount.
  * @dev Calculate single prize split distribution amount using the total prize amount and prize split percentage.
  * @param amount Total prize award distribution amount
  * @param percentage Percentage with single decimal precision using 0-1000 ranges
  */
  function _getPrizeSplitAmount(uint256 amount, uint16 percentage) internal pure returns (uint256) {
    return (amount * percentage).div(1000);
  }

  /**
  * @notice Calculates total prize split percentage amount.
  * @dev Calculates total PrizeSplitConfig percentage(s) amount. Used to check the total does not exceed 100% of award distribution.
  * @return Total prize split(s) percentage amount
  */
  function _totalPrizeSplitPercentageAmount() internal view returns (uint256) {
    uint256 _tempTotalPercentage;
    uint256 prizeSplitsLength = _prizeSplits.length;
    for (uint8 index = 0; index < prizeSplitsLength; index++) {
      PrizeSplitConfig memory split = _prizeSplits[index];
      _tempTotalPercentage = _tempTotalPercentage.add(split.percentage);
    }
    return _tempTotalPercentage;
  }

  /**
  * @notice Distributes prize split(s).
  * @dev Distributes prize split(s) by awarding ticket or sponsorship tokens.
  * @param prize Starting prize award amount
  * @return Total prize award distribution amount exlcuding the awarded prize split(s)
  */
  function _distributePrizeSplits(uint256 prize) internal returns (uint256) {
    // Store temporary total prize amount for multiple calculations using initial prize amount.
    uint256 _prizeTemp = prize;
    uint256 prizeSplitsLength = _prizeSplits.length;
    for (uint256 index = 0; index < prizeSplitsLength; index++) {
      PrizeSplitConfig memory split = _prizeSplits[index];
      uint256 _splitAmount = _getPrizeSplitAmount(_prizeTemp, split.percentage);

      // Award the prize split distribution amount.
      _awardPrizeSplitAmount(split.target, _splitAmount, split.token);

      // Update the remaining prize amount after distributing the prize split percentage.
      prize = prize.sub(_splitAmount);
    }

    return prize;
  }

}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/introspection/ERC165CheckerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@pooltogether/pooltogether-rng-contracts/contracts/RNGInterface.sol";
import "@pooltogether/fixed-point/contracts/FixedPoint.sol";

import "../token/TokenListener.sol";
import "../token/TokenControllerInterface.sol";
import "../token/ControlledToken.sol";
import "../token/TicketInterface.sol";
import "../prize-pool/PrizePool.sol";
import "../Constants.sol";
import "./PeriodicPrizeStrategyListenerInterface.sol";
import "./PeriodicPrizeStrategyListenerLibrary.sol";
import "./BeforeAwardListener.sol";

/* solium-disable security/no-block-members */
abstract contract PeriodicPrizeStrategy is
    Initializable,
    OwnableUpgradeable,
    TokenListener
{
    using SafeMathUpgradeable for uint256;
    using SafeMathUpgradeable for uint16;
    using SafeCastUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MappedSinglyLinkedList for MappedSinglyLinkedList.Mapping;
    using AddressUpgradeable for address;
    using ERC165CheckerUpgradeable for address;

    uint256 internal constant ETHEREUM_BLOCK_TIME_ESTIMATE_MANTISSA =
        13.4 ether;

    event PrizePoolOpened(
        address indexed operator,
        uint256 indexed prizePeriodStartedAt
    );

    event RngRequestFailed();

    event PrizePoolAwardStarted(
        address indexed operator,
        address indexed prizePool,
        uint32 indexed rngRequestId,
        uint32 rngLockBlock
    );

    event PrizePoolAwardCancelled(
        address indexed operator,
        address indexed prizePool,
        uint32 indexed rngRequestId,
        uint32 rngLockBlock
    );

    event PrizePoolAwarded(address indexed operator, uint256 randomNumber);

    event RngServiceUpdated(RNGInterface indexed rngService);

    event TokenListenerUpdated(TokenListenerInterface indexed tokenListener);

    event RngRequestTimeoutSet(uint32 rngRequestTimeout);

    event PrizePeriodSecondsUpdated(uint256 prizePeriodSeconds);

    event BeforeAwardListenerSet(
        BeforeAwardListenerInterface indexed beforeAwardListener
    );

    event PeriodicPrizeStrategyListenerSet(
        PeriodicPrizeStrategyListenerInterface indexed periodicPrizeStrategyListener
    );

    event ExternalErc20AwardAdded(IERC20Upgradeable indexed externalErc20);

    event ExternalErc20AwardRemoved(
        IERC20Upgradeable indexed externalErc20Award
    );

    event Initialized(
        uint256 prizePeriodStart,
        uint256 prizePeriodSeconds,
        PrizePool indexed prizePool,
        TicketInterface ticket,
        IERC20Upgradeable sponsorship,
        RNGInterface rng,
        IERC20Upgradeable[] externalErc20Awards
    );

    struct RngRequest {
        uint32 id;
        uint32 lockBlock;
        uint32 requestedAt;
    }

    /// @notice Semver Version
    string public constant VERSION = "3.4.5";

    // Comptroller
    TokenListenerInterface public tokenListener;

    // Contract Interfaces
    PrizePool public prizePool;
    TicketInterface public ticket;
    IERC20Upgradeable public sponsorship;
    RNGInterface public rng;

    // Current RNG Request
    RngRequest internal rngRequest;

    /// @notice RNG Request Timeout.  In fact, this is really a "complete award" timeout.
    /// If the rng completes the award can still be cancelled.
    uint32 public rngRequestTimeout;

    // Prize period
    uint256 public prizePeriodSeconds;
    uint256 public prizePeriodStartedAt;

    // External tokens awarded as part of prize
    MappedSinglyLinkedList.Mapping internal externalErc20s;

    /// @notice A listener that is called before the prize is awarded
    BeforeAwardListenerInterface public beforeAwardListener;

    /// @notice A listener that is called after the prize is awarded
    PeriodicPrizeStrategyListenerInterface public periodicPrizeStrategyListener;

    /// @notice Initializes a new strategy
    /// @param _prizePeriodStart The starting timestamp of the prize period.
    /// @param _prizePeriodSeconds The duration of the prize period in seconds
    /// @param _prizePool The prize pool to award
    /// @param _ticket The ticket to use to draw winners
    /// @param _sponsorship The sponsorship token
    /// @param _rng The RNG service to use
    function initialize(
        uint256 _prizePeriodStart,
        uint256 _prizePeriodSeconds,
        PrizePool _prizePool,
        TicketInterface _ticket,
        IERC20Upgradeable _sponsorship,
        RNGInterface _rng,
        IERC20Upgradeable[] memory externalErc20Awards
    ) public initializer {
        require(
            address(_prizePool) != address(0),
            "PeriodicPrizeStrategy/prize-pool-not-zero"
        );
        require(
            address(_ticket) != address(0),
            "PeriodicPrizeStrategy/ticket-not-zero"
        );
        require(
            address(_sponsorship) != address(0),
            "PeriodicPrizeStrategy/sponsorship-not-zero"
        );
        require(
            address(_rng) != address(0),
            "PeriodicPrizeStrategy/rng-not-zero"
        );
        prizePool = _prizePool;
        ticket = _ticket;
        rng = _rng;
        sponsorship = _sponsorship;
        _setPrizePeriodSeconds(_prizePeriodSeconds);

        __Ownable_init();

        externalErc20s.initialize();
        for (uint256 i = 0; i < externalErc20Awards.length; i++) {
            _addExternalErc20Award(externalErc20Awards[i]);
        }

        prizePeriodSeconds = _prizePeriodSeconds;
        prizePeriodStartedAt = _prizePeriodStart;

        // 30 min timeout
        _setRngRequestTimeout(1800);

        emit Initialized(
            _prizePeriodStart,
            _prizePeriodSeconds,
            _prizePool,
            _ticket,
            _sponsorship,
            _rng,
            externalErc20Awards
        );
        emit PrizePoolOpened(_msgSender(), prizePeriodStartedAt);
    }

    function _distribute(uint256 randomNumber) internal virtual;

    /// @notice Calculates and returns the currently accrued prize
    /// @return The current prize size
    function currentPrize() public view returns (uint256) {
        return prizePool.awardBalance();
    }

    /// @notice Allows the owner to set the token listener
    /// @param _tokenListener A contract that implements the token listener interface.
    function setTokenListener(TokenListenerInterface _tokenListener)
        external
        onlyOwner
        requireAwardNotInProgress
    {
        require(
            address(0) == address(_tokenListener) ||
                address(_tokenListener).supportsInterface(
                    TokenListenerLibrary.ERC165_INTERFACE_ID_TOKEN_LISTENER
                ),
            "PeriodicPrizeStrategy/token-listener-invalid"
        );

        tokenListener = _tokenListener;

        emit TokenListenerUpdated(tokenListener);
    }

    /// @notice Estimates the remaining blocks until the prize given a number of seconds per block
    /// @param secondsPerBlockMantissa The number of seconds per block to use for the calculation.  Should be a fixed point 18 number like Ether.
    /// @return The estimated number of blocks remaining until the prize can be awarded.
    function estimateRemainingBlocksToPrize(uint256 secondsPerBlockMantissa)
        public
        view
        returns (uint256)
    {
        return
            FixedPoint.divideUintByMantissa(
                _prizePeriodRemainingSeconds(),
                secondsPerBlockMantissa
            );
    }

    /// @notice Returns the number of seconds remaining until the prize can be awarded.
    /// @return The number of seconds remaining until the prize can be awarded.
    function prizePeriodRemainingSeconds() external view returns (uint256) {
        return _prizePeriodRemainingSeconds();
    }

    /// @notice Returns the number of seconds remaining until the prize can be awarded.
    /// @return The number of seconds remaining until the prize can be awarded.
    function _prizePeriodRemainingSeconds() internal view returns (uint256) {
        uint256 endAt = _prizePeriodEndAt();
        uint256 time = _currentTime();
        if (time > endAt) {
            return 0;
        }
        return endAt.sub(time);
    }

    /// @notice Returns whether the prize period is over
    /// @return True if the prize period is over, false otherwise
    function isPrizePeriodOver() external view returns (bool) {
        return _isPrizePeriodOver();
    }

    /// @notice Returns whether the prize period is over
    /// @return True if the prize period is over, false otherwise
    function _isPrizePeriodOver() internal view returns (bool) {
        return _currentTime() >= _prizePeriodEndAt();
    }

    /// @notice Awards collateral as tickets to a user
    /// @param user Recipient of minted tokens
    /// @param amount Amount of minted tokens
    function _awardTickets(address user, uint256 amount) internal {
        prizePool.award(user, amount, address(ticket));
    }

    /// @notice Mints ticket or sponsorship tokens for user.
    /// @dev Mints ticket or sponsorship tokens by looking up the address in the prizePool.tokens mapping.
    /// @param user Recipient of minted tokens
    /// @param amount Amount of minted tokens
    /// @param tokenIndex Index (0 or 1) of a token in the prizePool.tokens mapping
    function _awardToken(
        address user,
        uint256 amount,
        uint8 tokenIndex
    ) internal {
        ControlledTokenInterface[] memory _controlledTokens = prizePool
            .tokens();
        require(
            tokenIndex <= _controlledTokens.length,
            "PeriodicPrizeStrategy/award-invalid-token-index"
        );
        ControlledTokenInterface _token = _controlledTokens[tokenIndex];
        prizePool.award(user, amount, address(_token));
    }

    /// @notice Awards all external tokens with non-zero balances to the given user.  The external tokens must be held by the PrizePool contract.
    /// @param winner The user to transfer the tokens to
    function _awardAllExternalTokens(address winner) internal {
        _awardExternalErc20s(winner);
    }

    /// @notice Awards all external ERC20 tokens with non-zero balances to the given user.
    /// The external tokens must be held by the PrizePool contract.
    /// @param winner The user to transfer the tokens to
    function _awardExternalErc20s(address winner) internal {
        address currentToken = externalErc20s.start();
        while (
            currentToken != address(0) && currentToken != externalErc20s.end()
        ) {
            uint256 balance = IERC20Upgradeable(currentToken).balanceOf(
                address(prizePool)
            );
            if (balance > 0) {
                prizePool.awardExternalERC20(winner, currentToken, balance);
            }
            currentToken = externalErc20s.next(currentToken);
        }
    }

    /// @notice Returns the timestamp at which the prize period ends
    /// @return The timestamp at which the prize period ends.
    function prizePeriodEndAt() external view returns (uint256) {
        // current prize started at is non-inclusive, so add one
        return _prizePeriodEndAt();
    }

    /// @notice Returns the timestamp at which the prize period ends
    /// @return The timestamp at which the prize period ends.
    function _prizePeriodEndAt() internal view returns (uint256) {
        // current prize started at is non-inclusive, so add one
        return prizePeriodStartedAt.add(prizePeriodSeconds);
    }

    /// @notice Called by the PrizePool for transfers of controlled tokens
    /// @dev Note that this is only for *transfers*, not mints or burns
    /// @param controlledToken The type of collateral that is being sent
    function beforeTokenTransfer(
        address from,
        address to,
        uint256 amount,
        address controlledToken
    ) external override onlyPrizePool {
        require(from != to, "PeriodicPrizeStrategy/transfer-to-self");

        if (controlledToken == address(ticket)) {
            _requireAwardNotInProgress();
        }

        if (address(tokenListener) != address(0)) {
            tokenListener.beforeTokenTransfer(
                from,
                to,
                amount,
                controlledToken
            );
        }
    }

    /// @notice Called by the PrizePool when minting controlled tokens
    /// @param controlledToken The type of collateral that is being minted
    function beforeTokenMint(
        address to,
        uint256 amount,
        address controlledToken,
        address referrer
    ) external override onlyPrizePool {
        if (controlledToken == address(ticket)) {
            _requireAwardNotInProgress();
        }
        if (address(tokenListener) != address(0)) {
            tokenListener.beforeTokenMint(
                to,
                amount,
                controlledToken,
                referrer
            );
        }
    }

    /// @notice returns the current time.  Used for testing.
    /// @return The current time (block.timestamp)
    function _currentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    /// @notice returns the current time.  Used for testing.
    /// @return The current time (block.timestamp)
    function _currentBlock() internal view virtual returns (uint256) {
        return block.number;
    }

    /// @notice Starts the award process by starting random number request.  The prize period must have ended.
    /// @dev The RNG-Request-Fee is expected to be held within this contract before calling this function
    function startAward() external requireCanStartAward {
        (address feeToken, uint256 requestFee) = rng.getRequestFee();
        if (feeToken != address(0) && requestFee > 0) {
            IERC20Upgradeable(feeToken).safeApprove(address(rng), requestFee);
        }

        (uint32 requestId, uint32 lockBlock) = rng.requestRandomNumber();
        rngRequest.id = requestId;
        rngRequest.lockBlock = lockBlock;
        rngRequest.requestedAt = _currentTime().toUint32();

        emit PrizePoolAwardStarted(
            _msgSender(),
            address(prizePool),
            requestId,
            lockBlock
        );
    }

    /// @notice Can be called by anyone to unlock the tickets if the RNG has timed out.
    function cancelAward() public {
        require(isRngTimedOut(), "PeriodicPrizeStrategy/rng-not-timedout");
        uint32 requestId = rngRequest.id;
        uint32 lockBlock = rngRequest.lockBlock;
        delete rngRequest;
        emit RngRequestFailed();
        emit PrizePoolAwardCancelled(
            msg.sender,
            address(prizePool),
            requestId,
            lockBlock
        );
    }

    /// @notice Completes the award process and awards the winners.  The random number must have been requested and is now available.
    function completeAward() external requireCanCompleteAward {
        uint256 randomNumber = rng.randomNumber(rngRequest.id);
        delete rngRequest;

        if (address(beforeAwardListener) != address(0)) {
            beforeAwardListener.beforePrizePoolAwarded(
                randomNumber,
                prizePeriodStartedAt
            );
        }
        _distribute(randomNumber);
        if (address(periodicPrizeStrategyListener) != address(0)) {
            periodicPrizeStrategyListener.afterPrizePoolAwarded(
                randomNumber,
                prizePeriodStartedAt
            );
        }

        // to avoid clock drift, we should calculate the start time based on the previous period start time.
        prizePeriodStartedAt = _calculateNextPrizePeriodStartTime(
            _currentTime()
        );

        emit PrizePoolAwarded(_msgSender(), randomNumber);
        emit PrizePoolOpened(_msgSender(), prizePeriodStartedAt);
    }

    /// @notice Allows the owner to set a listener that is triggered immediately before the award is distributed
    /// @dev The listener must implement ERC165 and the BeforeAwardListenerInterface
    /// @param _beforeAwardListener The address of the listener contract
    function setBeforeAwardListener(
        BeforeAwardListenerInterface _beforeAwardListener
    ) external onlyOwner requireAwardNotInProgress {
        require(
            address(0) == address(_beforeAwardListener) ||
                address(_beforeAwardListener).supportsInterface(
                    BeforeAwardListenerLibrary
                        .ERC165_INTERFACE_ID_BEFORE_AWARD_LISTENER
                ),
            "PeriodicPrizeStrategy/beforeAwardListener-invalid"
        );

        beforeAwardListener = _beforeAwardListener;

        emit BeforeAwardListenerSet(_beforeAwardListener);
    }

    /// @notice Allows the owner to set a listener for prize strategy callbacks.
    /// @param _periodicPrizeStrategyListener The address of the listener contract
    function setPeriodicPrizeStrategyListener(
        PeriodicPrizeStrategyListenerInterface _periodicPrizeStrategyListener
    ) external onlyOwner requireAwardNotInProgress {
        require(
            address(0) == address(_periodicPrizeStrategyListener) ||
                address(_periodicPrizeStrategyListener).supportsInterface(
                    PeriodicPrizeStrategyListenerLibrary
                        .ERC165_INTERFACE_ID_PERIODIC_PRIZE_STRATEGY_LISTENER
                ),
            "PeriodicPrizeStrategy/prizeStrategyListener-invalid"
        );

        periodicPrizeStrategyListener = _periodicPrizeStrategyListener;

        emit PeriodicPrizeStrategyListenerSet(_periodicPrizeStrategyListener);
    }

    function _calculateNextPrizePeriodStartTime(uint256 currentTime)
        internal
        view
        returns (uint256)
    {
        uint256 elapsedPeriods = currentTime.sub(prizePeriodStartedAt).div(
            prizePeriodSeconds
        );
        return prizePeriodStartedAt.add(elapsedPeriods.mul(prizePeriodSeconds));
    }

    /// @notice Calculates when the next prize period will start
    /// @param currentTime The timestamp to use as the current time
    /// @return The timestamp at which the next prize period would start
    function calculateNextPrizePeriodStartTime(uint256 currentTime)
        external
        view
        returns (uint256)
    {
        return _calculateNextPrizePeriodStartTime(currentTime);
    }

    /// @notice Returns whether an award process can be started
    /// @return True if an award can be started, false otherwise.
    function canStartAward() external view returns (bool) {
        return _isPrizePeriodOver() && !isRngRequested();
    }

    /// @notice Returns whether an award process can be completed
    /// @return True if an award can be completed, false otherwise.
    function canCompleteAward() external view returns (bool) {
        return isRngRequested() && isRngCompleted();
    }

    /// @notice Returns whether a random number has been requested
    /// @return True if a random number has been requested, false otherwise.
    function isRngRequested() public view returns (bool) {
        return rngRequest.id != 0;
    }

    /// @notice Returns whether the random number request has completed.
    /// @return True if a random number request has completed, false otherwise.
    function isRngCompleted() public view returns (bool) {
        return rng.isRequestComplete(rngRequest.id);
    }

    /// @notice Returns the block number that the current RNG request has been locked to
    /// @return The block number that the RNG request is locked to
    function getLastRngLockBlock() external view returns (uint32) {
        return rngRequest.lockBlock;
    }

    /// @notice Returns the current RNG Request ID
    /// @return The current Request ID
    function getLastRngRequestId() external view returns (uint32) {
        return rngRequest.id;
    }

    /// @notice Sets the RNG service that the Prize Strategy is connected to
    /// @param rngService The address of the new RNG service interface
    function setRngService(RNGInterface rngService)
        external
        onlyOwner
        requireAwardNotInProgress
    {
        require(!isRngRequested(), "PeriodicPrizeStrategy/rng-in-flight");

        rng = rngService;
        emit RngServiceUpdated(rngService);
    }

    /// @notice Allows the owner to set the RNG request timeout in seconds.  This is the time that must elapsed before the RNG request can be cancelled and the pool unlocked.
    /// @param _rngRequestTimeout The RNG request timeout in seconds.
    function setRngRequestTimeout(uint32 _rngRequestTimeout)
        external
        onlyOwner
        requireAwardNotInProgress
    {
        _setRngRequestTimeout(_rngRequestTimeout);
    }

    /// @notice Sets the RNG request timeout in seconds.  This is the time that must elapsed before the RNG request can be cancelled and the pool unlocked.
    /// @param _rngRequestTimeout The RNG request timeout in seconds.
    function _setRngRequestTimeout(uint32 _rngRequestTimeout) internal {
        require(
            _rngRequestTimeout > 60,
            "PeriodicPrizeStrategy/rng-timeout-gt-60-secs"
        );
        rngRequestTimeout = _rngRequestTimeout;
        emit RngRequestTimeoutSet(rngRequestTimeout);
    }

    /// @notice Allows the owner to set the prize period in seconds.
    /// @param _prizePeriodSeconds The new prize period in seconds.  Must be greater than zero.
    function setPrizePeriodSeconds(uint256 _prizePeriodSeconds)
        external
        onlyOwner
        requireAwardNotInProgress
    {
        _setPrizePeriodSeconds(_prizePeriodSeconds);
    }

    /// @notice Sets the prize period in seconds.
    /// @param _prizePeriodSeconds The new prize period in seconds.  Must be greater than zero.
    function _setPrizePeriodSeconds(uint256 _prizePeriodSeconds) internal {
        require(
            _prizePeriodSeconds > 0,
            "PeriodicPrizeStrategy/prize-period-greater-than-zero"
        );
        prizePeriodSeconds = _prizePeriodSeconds;

        emit PrizePeriodSecondsUpdated(prizePeriodSeconds);
    }

    /// @notice Gets the current list of External ERC20 tokens that will be awarded with the current prize
    /// @return An array of External ERC20 token addresses
    function getExternalErc20Awards() external view returns (address[] memory) {
        return externalErc20s.addressArray();
    }

    /// @notice Adds an external ERC20 token type as an additional prize that can be awarded
    /// @dev Only the Prize-Strategy owner/creator can assign external tokens,
    /// and they must be approved by the Prize-Pool
    /// @param _externalErc20 The address of an ERC20 token to be awarded
    function addExternalErc20Award(IERC20Upgradeable _externalErc20)
        external
        onlyOwnerOrListener
        requireAwardNotInProgress
    {
        _addExternalErc20Award(_externalErc20);
    }

    function _addExternalErc20Award(IERC20Upgradeable _externalErc20) internal {
        require(
            address(_externalErc20).isContract(),
            "PeriodicPrizeStrategy/erc20-null"
        );
        require(
            prizePool.canAwardExternal(address(_externalErc20)),
            "PeriodicPrizeStrategy/cannot-award-external"
        );
        (bool succeeded, bytes memory returnValue) = address(_externalErc20)
            .staticcall(abi.encodeWithSignature("totalSupply()"));
        require(succeeded, "PeriodicPrizeStrategy/erc20-invalid");
        externalErc20s.addAddress(address(_externalErc20));
        emit ExternalErc20AwardAdded(_externalErc20);
    }

    function addExternalErc20Awards(
        IERC20Upgradeable[] calldata _externalErc20s
    ) external onlyOwnerOrListener requireAwardNotInProgress {
        for (uint256 i = 0; i < _externalErc20s.length; i++) {
            _addExternalErc20Award(_externalErc20s[i]);
        }
    }

    /// @notice Removes an external ERC20 token type as an additional prize that can be awarded
    /// @dev Only the Prize-Strategy owner/creator can remove external tokens
    /// @param _externalErc20 The address of an ERC20 token to be removed
    /// @param _prevExternalErc20 The address of the previous ERC20 token in the `externalErc20s` list.
    /// If the ERC20 is the first address, then the previous address is the SENTINEL address: 0x0000000000000000000000000000000000000001
    function removeExternalErc20Award(
        IERC20Upgradeable _externalErc20,
        IERC20Upgradeable _prevExternalErc20
    ) external onlyOwner requireAwardNotInProgress {
        externalErc20s.removeAddress(
            address(_prevExternalErc20),
            address(_externalErc20)
        );
        emit ExternalErc20AwardRemoved(_externalErc20);
    }

    function _requireAwardNotInProgress() internal view {
        uint256 currentBlock = _currentBlock();
        require(
            rngRequest.lockBlock == 0 || currentBlock < rngRequest.lockBlock,
            "PeriodicPrizeStrategy/rng-in-flight"
        );
    }

    function isRngTimedOut() public view returns (bool) {
        if (rngRequest.requestedAt == 0) {
            return false;
        } else {
            return
                _currentTime() >
                uint256(rngRequestTimeout).add(rngRequest.requestedAt);
        }
    }

    modifier onlyOwnerOrListener() {
        require(
            _msgSender() == owner() ||
                _msgSender() == address(periodicPrizeStrategyListener) ||
                _msgSender() == address(beforeAwardListener),
            "PeriodicPrizeStrategy/only-owner-or-listener"
        );
        _;
    }

    modifier requireAwardNotInProgress() {
        _requireAwardNotInProgress();
        _;
    }

    modifier requireCanStartAward() {
        require(
            _isPrizePeriodOver(),
            "PeriodicPrizeStrategy/prize-period-not-over"
        );
        require(
            !isRngRequested(),
            "PeriodicPrizeStrategy/rng-already-requested"
        );
        _;
    }

    modifier requireCanCompleteAward() {
        require(isRngRequested(), "PeriodicPrizeStrategy/rng-not-requested");
        require(isRngCompleted(), "PeriodicPrizeStrategy/rng-not-complete");
        _;
    }

    modifier onlyPrizePool() {
        require(
            _msgSender() == address(prizePool),
            "PeriodicPrizeStrategy/only-prize-pool"
        );
        _;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/Initializable.sol";
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
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;


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
library SafeCastUpgradeable {

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value < 2**128, "SafeCast: value doesn\'t fit in 128 bits");
        return uint128(value);
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
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value < 2**64, "SafeCast: value doesn\'t fit in 64 bits");
        return uint64(value);
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
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value < 2**32, "SafeCast: value doesn\'t fit in 32 bits");
        return uint32(value);
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
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value < 2**16, "SafeCast: value doesn\'t fit in 16 bits");
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
     * - input must fit into 8 bits.
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value < 2**8, "SafeCast: value doesn\'t fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
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
        require(value >= -2**127 && value < 2**127, "SafeCast: value doesn\'t fit in 128 bits");
        return int128(value);
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
        require(value >= -2**63 && value < 2**63, "SafeCast: value doesn\'t fit in 64 bits");
        return int64(value);
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
        require(value >= -2**31 && value < 2**31, "SafeCast: value doesn\'t fit in 32 bits");
        return int32(value);
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
        require(value >= -2**15 && value < 2**15, "SafeCast: value doesn\'t fit in 16 bits");
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
     * - input must fit into 8 bits.
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8) {
        require(value >= -2**7 && value < 2**7, "SafeCast: value doesn\'t fit in 8 bits");
        return int8(value);
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        require(value < 2**255, "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

/**
 * @dev Library used to query support of an interface declared via {IERC165}.
 *
 * Note that these functions return the actual result of the query: they do not
 * `revert` if an interface is not supported. It is up to the caller to decide
 * what to do in these cases.
 */
library ERC165CheckerUpgradeable {
    // As per the EIP-165 spec, no interface should ever match 0xffffffff
    bytes4 private constant _INTERFACE_ID_INVALID = 0xffffffff;

    /*
     * bytes4(keccak256('supportsInterface(bytes4)')) == 0x01ffc9a7
     */
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;

    /**
     * @dev Returns true if `account` supports the {IERC165} interface,
     */
    function supportsERC165(address account) internal view returns (bool) {
        // Any contract that implements ERC165 must explicitly indicate support of
        // InterfaceId_ERC165 and explicitly indicate non-support of InterfaceId_Invalid
        return _supportsERC165Interface(account, _INTERFACE_ID_ERC165) &&
            !_supportsERC165Interface(account, _INTERFACE_ID_INVALID);
    }

    /**
     * @dev Returns true if `account` supports the interface defined by
     * `interfaceId`. Support for {IERC165} itself is queried automatically.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsInterface(address account, bytes4 interfaceId) internal view returns (bool) {
        // query support of both ERC165 as per the spec and support of _interfaceId
        return supportsERC165(account) &&
            _supportsERC165Interface(account, interfaceId);
    }

    /**
     * @dev Returns a boolean array where each value corresponds to the
     * interfaces passed in and whether they're supported or not. This allows
     * you to batch check interfaces for a contract where your expectation
     * is that some interfaces may not be supported.
     *
     * See {IERC165-supportsInterface}.
     *
     * _Available since v3.4._
     */
    function getSupportedInterfaces(address account, bytes4[] memory interfaceIds) internal view returns (bool[] memory) {
        // an array of booleans corresponding to interfaceIds and whether they're supported or not
        bool[] memory interfaceIdsSupported = new bool[](interfaceIds.length);

        // query support of ERC165 itself
        if (supportsERC165(account)) {
            // query support of each interface in interfaceIds
            for (uint256 i = 0; i < interfaceIds.length; i++) {
                interfaceIdsSupported[i] = _supportsERC165Interface(account, interfaceIds[i]);
            }
        }

        return interfaceIdsSupported;
    }

    /**
     * @dev Returns true if `account` supports all the interfaces defined in
     * `interfaceIds`. Support for {IERC165} itself is queried automatically.
     *
     * Batch-querying can lead to gas savings by skipping repeated checks for
     * {IERC165} support.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsAllInterfaces(address account, bytes4[] memory interfaceIds) internal view returns (bool) {
        // query support of ERC165 itself
        if (!supportsERC165(account)) {
            return false;
        }

        // query support of each interface in _interfaceIds
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            if (!_supportsERC165Interface(account, interfaceIds[i])) {
                return false;
            }
        }

        // all interfaces supported
        return true;
    }

    /**
     * @notice Query if a contract implements an interface, does not check ERC165 support
     * @param account The address of the contract to query for support of an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return true if the contract at account indicates support of the interface with
     * identifier interfaceId, false otherwise
     * @dev Assumes that account contains a contract that supports ERC165, otherwise
     * the behavior of this method is undefined. This precondition can be checked
     * with {supportsERC165}.
     * Interface identification is specified in ERC-165.
     */
    function _supportsERC165Interface(address account, bytes4 interfaceId) private view returns (bool) {
        // success determines whether the staticcall succeeded and result determines
        // whether the contract at account indicates support of _interfaceId
        (bool success, bool result) = _callERC165SupportsInterface(account, interfaceId);

        return (success && result);
    }

    /**
     * @notice Calls the function with selector 0x01ffc9a7 (ERC165) and suppresses throw
     * @param account The address of the contract to query for support of an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return success true if the STATICCALL succeeded, false otherwise
     * @return result true if the STATICCALL succeeded and the contract at account
     * indicates support of the interface with identifier interfaceId, false otherwise
     */
    function _callERC165SupportsInterface(address account, bytes4 interfaceId)
        private
        view
        returns (bool, bool)
    {
        bytes memory encodedParams = abi.encodeWithSelector(_INTERFACE_ID_ERC165, interfaceId);
        (bool success, bytes memory result) = account.staticcall{ gas: 30000 }(encodedParams);
        if (result.length < 32) return (false, false);
        return (success, abi.decode(result, (bool)));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./IERC20Upgradeable.sol";
import "../../math/SafeMathUpgradeable.sol";
import "../../utils/AddressUpgradeable.sol";

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
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    function safeTransfer(IERC20Upgradeable token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20Upgradeable token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
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

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0;

/// @title Random Number Generator Interface
/// @notice Provides an interface for requesting random numbers from 3rd-party RNG services (Chainlink VRF, Starkware VDF, etc..)
interface RNGInterface {

  /// @notice Emitted when a new request for a random number has been submitted
  /// @param requestId The indexed ID of the request used to get the results of the RNG service
  /// @param sender The indexed address of the sender of the request
  event RandomNumberRequested(uint32 indexed requestId, address indexed sender);

  /// @notice Emitted when an existing request for a random number has been completed
  /// @param requestId The indexed ID of the request used to get the results of the RNG service
  /// @param randomNumber The random number produced by the 3rd-party service
  event RandomNumberCompleted(uint32 indexed requestId, uint256 randomNumber);

  /// @notice Gets the last request id used by the RNG service
  /// @return requestId The last request id used in the last request
  function getLastRequestId() external view returns (uint32 requestId);

  /// @notice Gets the Fee for making a Request against an RNG service
  /// @return feeToken The address of the token that is used to pay fees
  /// @return requestFee The fee required to be paid to make a request
  function getRequestFee() external view returns (address feeToken, uint256 requestFee);

  /// @notice Sends a request for a random number to the 3rd-party service
  /// @dev Some services will complete the request immediately, others may have a time-delay
  /// @dev Some services require payment in the form of a token, such as $LINK for Chainlink VRF
  /// @return requestId The ID of the request used to get the results of the RNG service
  /// @return lockBlock The block number at which the RNG service will start generating time-delayed randomness.  The calling contract
  /// should "lock" all activity until the result is available via the `requestId`
  function requestRandomNumber() external returns (uint32 requestId, uint32 lockBlock);

  /// @notice Checks if the request for randomness from the 3rd-party service has completed
  /// @dev For time-delayed requests, this function is used to check/confirm completion
  /// @param requestId The ID of the request used to get the results of the RNG service
  /// @return isCompleted True if the request has completed and a random number is available, false otherwise
  function isRequestComplete(uint32 requestId) external view returns (bool isCompleted);

  /// @notice Gets the random number produced by the 3rd-party service
  /// @param requestId The ID of the request used to get the results of the RNG service
  /// @return randomNum The random number
  function randomNumber(uint32 requestId) external returns (uint256 randomNum);
}

/**
Copyright 2020 PoolTogether Inc.

This file is part of PoolTogether.

PoolTogether is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation under version 3 of the License.

PoolTogether is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with PoolTogether.  If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity >=0.6.0 <0.8.0;

import "./external/openzeppelin/OpenZeppelinSafeMath_V3_3_0.sol";

/**
 * @author Brendan Asselstine
 * @notice Provides basic fixed point math calculations.
 *
 * This library calculates integer fractions by scaling values by 1e18 then performing standard integer math.
 */
library FixedPoint {
    using OpenZeppelinSafeMath_V3_3_0 for uint256;

    // The scale to use for fixed point numbers.  Same as Ether for simplicity.
    uint256 internal constant SCALE = 1e18;

    /**
        * Calculates a Fixed18 mantissa given the numerator and denominator
        *
        * The mantissa = (numerator * 1e18) / denominator
        *
        * @param numerator The mantissa numerator
        * @param denominator The mantissa denominator
        * @return The mantissa of the fraction
        */
    function calculateMantissa(uint256 numerator, uint256 denominator) internal pure returns (uint256) {
        uint256 mantissa = numerator.mul(SCALE);
        mantissa = mantissa.div(denominator);
        return mantissa;
    }

    /**
        * Multiplies a Fixed18 number by an integer.
        *
        * @param b The whole integer to multiply
        * @param mantissa The Fixed18 number
        * @return An integer that is the result of multiplying the params.
        */
    function multiplyUintByMantissa(uint256 b, uint256 mantissa) internal pure returns (uint256) {
        uint256 result = mantissa.mul(b);
        result = result.div(SCALE);
        return result;
    }

    /**
    * Divides an integer by a fixed point 18 mantissa
    *
    * @param dividend The integer to divide
    * @param mantissa The fixed point 18 number to serve as the divisor
    * @return An integer that is the result of dividing an integer by a fixed point 18 mantissa
    */
    function divideUintByMantissa(uint256 dividend, uint256 mantissa) internal pure returns (uint256) {
        uint256 result = SCALE.mul(dividend);
        result = result.div(mantissa);
        return result;
    }
}

pragma solidity ^0.6.4;

import "./TokenListenerInterface.sol";
import "./TokenListenerLibrary.sol";
import "../Constants.sol";

abstract contract TokenListener is TokenListenerInterface {
  function supportsInterface(bytes4 interfaceId) external override view returns (bool) {
    return (
      interfaceId == Constants.ERC165_INTERFACE_ID_ERC165 || 
      interfaceId == TokenListenerLibrary.ERC165_INTERFACE_ID_TOKEN_LISTENER
    );
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/introspection/ERC165CheckerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@pooltogether/fixed-point/contracts/FixedPoint.sol";

import "../external/compound/ICompLike.sol";
import "../registry/RegistryInterface.sol";
import "../reserve/ReserveInterface.sol";
import "../token/TokenListenerInterface.sol";
import "../token/TokenListenerLibrary.sol";
import "../token/ControlledToken.sol";
import "../token/TokenControllerInterface.sol";
import "../utils/MappedSinglyLinkedList.sol";
import "./PrizePoolInterface.sol";

/// @title Escrows assets and deposits them into a yield source.  Exposes interest to Prize Strategy.  Users deposit and withdraw from this contract to participate in Prize Pool.
/// @notice Accounting is managed using Controlled Tokens, whose mint and burn functions can only be called by this contract.
/// @dev Must be inherited to provide specific yield-bearing asset control, such as Compound cTokens
abstract contract PrizePool is
    PrizePoolInterface,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    TokenControllerInterface
{
    using SafeMathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MappedSinglyLinkedList for MappedSinglyLinkedList.Mapping;
    using ERC165CheckerUpgradeable for address;

    /// @dev Emitted when an instance is initialized
    event Initialized(address reserveRegistry, uint256 maxExitFeeMantissa);

    /// @dev Event emitted when controlled token is added
    event ControlledTokenAdded(ControlledTokenInterface indexed token);

    /// @dev Emitted when reserve is captured.
    event ReserveFeeCaptured(uint256 amount);

    event AwardCaptured(uint256 amount);

    /// @dev Event emitted when assets are deposited
    event Deposited(
        address indexed operator,
        address indexed to,
        address indexed token,
        uint256 amount,
        address referrer
    );

    /// @dev Event emitted when interest is awarded to a winner
    event Awarded(
        address indexed winner,
        address indexed token,
        uint256 amount
    );

    /// @dev Event emitted when external ERC20s are awarded to a winner
    event AwardedExternalERC20(
        address indexed winner,
        address indexed token,
        uint256 amount
    );

    /// @dev Event emitted when external ERC20s are transferred out
    event TransferredExternalERC20(
        address indexed to,
        address indexed token,
        uint256 amount
    );

    /// @dev Event emitted when assets are withdrawn instantly
    event InstantWithdrawal(
        address indexed operator,
        address indexed from,
        address indexed token,
        uint256 amount,
        uint256 redeemed,
        uint256 exitFee
    );

    event ReserveWithdrawal(address indexed to, uint256 amount);

    /// @dev Event emitted when the Liquidity Cap is set
    event LiquidityCapSet(uint256 liquidityCap);

    /// @dev Event emitted when the Credit plan is set
    event CreditPlanSet(
        address token,
        uint128 creditLimitMantissa,
        uint128 creditRateMantissa
    );

    /// @dev Event emitted when the Prize Strategy is set
    event PrizeStrategySet(address indexed prizeStrategy);

    /// @dev Emitted when credit is minted
    event CreditMinted(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    /// @dev Emitted when credit is burned
    event CreditBurned(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    struct CreditPlan {
        uint128 creditLimitMantissa;
        uint128 creditRateMantissa;
    }

    struct CreditBalance {
        uint192 balance;
        uint32 timestamp;
        bool initialized;
    }

    /// @notice Semver Version
    string public constant VERSION = "3.4.5";

    /// @dev Reserve to which reserve fees are sent
    RegistryInterface public reserveRegistry;

    /// @dev An array of all the controlled tokens
    ControlledTokenInterface[] internal _tokens;

    /// @dev The Prize Strategy that this Prize Pool is bound to.
    TokenListenerInterface public prizeStrategy;

    /// @dev The maximum possible exit fee fraction as a fixed point 18 number.
    /// For example, if the maxExitFeeMantissa is "0.1 ether", then the maximum exit fee for a withdrawal of 100 Dai will be 10 Dai
    uint256 public maxExitFeeMantissa;

    /// @dev The total funds that have been allocated to the reserve
    uint256 public reserveTotalSupply;

    /// @dev The total amount of funds that the prize pool can hold.
    uint256 public liquidityCap;

    /// @dev the The awardable balance
    uint256 internal _currentAwardBalance;

    /// @dev Stores the credit plan for each token.
    mapping(address => CreditPlan) internal _tokenCreditPlans;

    /// @dev Stores each users balance of credit per token.
    mapping(address => mapping(address => CreditBalance))
        internal _tokenCreditBalances;

    /// @notice Initializes the Prize Pool
    /// @param _controlledTokens Array of ControlledTokens that are controlled by this Prize Pool.
    /// @param _maxExitFeeMantissa The maximum exit fee size
    function initialize(
        RegistryInterface _reserveRegistry,
        ControlledTokenInterface[] memory _controlledTokens,
        uint256 _maxExitFeeMantissa
    ) public initializer {
        require(
            address(_reserveRegistry) != address(0),
            "PrizePool/reserveRegistry-not-zero"
        );
        uint256 controlledTokensLength = _controlledTokens.length;
        _tokens = new ControlledTokenInterface[](controlledTokensLength);

        for (uint256 i = 0; i < controlledTokensLength; i++) {
            ControlledTokenInterface controlledToken = _controlledTokens[i];
            _addControlledToken(controlledToken, i);
        }
        __Ownable_init();
        __ReentrancyGuard_init();
        _setLiquidityCap(uint256(-1));

        reserveRegistry = _reserveRegistry;
        maxExitFeeMantissa = _maxExitFeeMantissa;

        emit Initialized(address(_reserveRegistry), maxExitFeeMantissa);
    }

    /// @dev Returns the address of the underlying ERC20 asset
    /// @return The address of the asset
    function token() external view override returns (address) {
        return address(_token());
    }

    /// @dev Returns the total underlying balance of all assets. This includes both principal and interest.
    /// @return The underlying balance of assets
    function balance() external returns (uint256) {
        return _balance();
    }

    /// @dev Checks with the Prize Pool if a specific token type may be awarded as an external prize
    /// @param _externalToken The address of the token to check
    /// @return True if the token may be awarded, false otherwise
    function canAwardExternal(address _externalToken)
        external
        view
        returns (bool)
    {
        return _canAwardExternal(_externalToken);
    }

    /// @notice Deposit assets into the Prize Pool in exchange for tokens
    /// @param to The address receiving the newly minted tokens
    /// @param amount The amount of assets to deposit
    /// @param controlledToken The address of the type of token the user is minting
    /// @param referrer The referrer of the deposit
    function depositTo(
        address to,
        uint256 amount,
        address controlledToken,
        address referrer
    )
        external
        override
        nonReentrant
        onlyControlledToken(controlledToken)
        canAddLiquidity(amount)
    {
        address operator = _msgSender();

        _mint(to, amount, controlledToken, referrer);

        _token().safeTransferFrom(operator, address(this), amount);
        _supply(amount);

        emit Deposited(operator, to, controlledToken, amount, referrer);
    }

    /// @notice Withdraw assets from the Prize Pool instantly.  A fairness fee may be charged for an early exit.
    /// @param from The address to redeem tokens from.
    /// @param amount The amount of tokens to redeem for assets.
    /// @param controlledToken The address of the token to redeem (i.e. ticket or sponsorship)
    /// @param maximumExitFee The maximum exit fee the caller is willing to pay.  This should be pre-calculated by the calculateExitFee() fxn.
    /// @return The actual exit fee paid
    function withdrawInstantlyFrom(
        address from,
        uint256 amount,
        address controlledToken,
        uint256 maximumExitFee
    )
        external
        override
        nonReentrant
        onlyControlledToken(controlledToken)
        returns (uint256)
    {
        (
            uint256 exitFee,
            uint256 burnedCredit
        ) = _calculateEarlyExitFeeLessBurnedCredit(
                from,
                controlledToken,
                amount
            );
        require(
            exitFee <= maximumExitFee,
            "PrizePool/exit-fee-exceeds-user-maximum"
        );

        // burn the credit
        _burnCredit(from, controlledToken, burnedCredit);

        // burn the tickets
        ControlledToken(controlledToken).controllerBurnFrom(
            _msgSender(),
            from,
            amount
        );

        // redeem the tickets less the fee, then add the earning
        uint256 amountLessFee = amount.sub(exitFee);
        uint256 amount = _ticketToAmount(amountLessFee);
        uint256 redeemed = _redeem(amount);

        _token().safeTransfer(from, redeemed);

        emit InstantWithdrawal(
            _msgSender(),
            from,
            controlledToken,
            amount,
            redeemed,
            exitFee
        );

        return exitFee;
    }

    /// @notice Limits the exit fee to the maximum as hard-coded into the contract
    /// @param withdrawalAmount The amount that is attempting to be withdrawn
    /// @param exitFee The exit fee to check against the limit
    /// @return The passed exit fee if it is less than the maximum, otherwise the maximum fee is returned.
    function _limitExitFee(uint256 withdrawalAmount, uint256 exitFee)
        internal
        view
        returns (uint256)
    {
        uint256 maxFee = FixedPoint.multiplyUintByMantissa(
            withdrawalAmount,
            maxExitFeeMantissa
        );
        if (exitFee > maxFee) {
            exitFee = maxFee;
        }
        return exitFee;
    }

    /// @notice Updates the Prize Strategy when tokens are transferred between holders.
    /// @param from The address the tokens are being transferred from (0 if minting)
    /// @param to The address the tokens are being transferred to (0 if burning)
    /// @param amount The amount of tokens being trasferred
    function beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) external override onlyControlledToken(msg.sender) {
        if (from != address(0)) {
            uint256 fromBeforeBalance = IERC20Upgradeable(msg.sender).balanceOf(
                from
            );
            // first accrue credit for their old balance
            uint256 newCreditBalance = _calculateCreditBalance(
                from,
                msg.sender,
                fromBeforeBalance,
                0
            );

            if (from != to) {
                // if they are sending funds to someone else, we need to limit their accrued credit to their new balance
                newCreditBalance = _applyCreditLimit(
                    msg.sender,
                    fromBeforeBalance.sub(amount),
                    newCreditBalance
                );
            }

            _updateCreditBalance(from, msg.sender, newCreditBalance);
        }
        if (to != address(0) && to != from) {
            _accrueCredit(
                to,
                msg.sender,
                IERC20Upgradeable(msg.sender).balanceOf(to),
                0
            );
        }
        // if we aren't minting
        if (from != address(0) && address(prizeStrategy) != address(0)) {
            prizeStrategy.beforeTokenTransfer(from, to, amount, msg.sender);
        }
    }

    /// @notice Returns the balance that is available to award.
    /// @dev captureAwardBalance() should be called first
    /// @return The total amount of assets to be awarded for the current prize
    function awardBalance() external view override returns (uint256) {
        return _currentAwardBalance;
    }

    /// @notice Captures any available interest as award balance.
    /// @dev This function also captures the reserve fees.
    /// @return The total amount of assets to be awarded for the current prize
    function captureAwardBalance()
        public
        override
        nonReentrant
        returns (uint256)
    {
        uint256 tokenTotalSupply = _tokenTotalSupply();

        // it's possible for the balance to be slightly less due to rounding errors in the underlying yield source
        uint256 currentBalance = _balance();
        uint256 totalInterest = (currentBalance > tokenTotalSupply)
            ? currentBalance.sub(tokenTotalSupply)
            : 0;
        uint256 unaccountedPrizeBalance = (totalInterest > _currentAwardBalance)
            ? totalInterest.sub(_currentAwardBalance)
            : 0;

        if (unaccountedPrizeBalance > 0) {
            uint256 reserveFee = calculateReserveFee(unaccountedPrizeBalance);
            if (reserveFee > 0) {
                reserveTotalSupply = reserveTotalSupply.add(reserveFee);
                unaccountedPrizeBalance = unaccountedPrizeBalance.sub(
                    reserveFee
                );
                emit ReserveFeeCaptured(reserveFee);
            }
            _currentAwardBalance = _currentAwardBalance.add(
                unaccountedPrizeBalance
            );

            emit AwardCaptured(unaccountedPrizeBalance);
        }

        return _currentAwardBalance;
    }

    function withdrawReserve(address to)
        external
        override
        onlyReserve
        returns (uint256)
    {
        uint256 amount = reserveTotalSupply;
        reserveTotalSupply = 0;
        uint256 redeemed = _redeem(amount);

        _token().safeTransfer(address(to), redeemed);

        emit ReserveWithdrawal(to, amount);

        return redeemed;
    }

    /// @notice Called by the prize strategy to award prizes.
    /// @dev The amount awarded must be less than the awardBalance()
    /// @param to The address of the winner that receives the award
    /// @param amount The amount of assets to be awarded
    /// @param controlledToken The address of the asset token being awarded
    function award(
        address to,
        uint256 amount,
        address controlledToken
    ) external override onlyPrizeStrategy onlyControlledToken(controlledToken) {
        if (amount == 0) {
            return;
        }

        require(
            amount <= _currentAwardBalance,
            "PrizePool/award-exceeds-avail"
        );
        _currentAwardBalance = _currentAwardBalance.sub(amount);

        _mint(to, amount, controlledToken, address(0));

        uint256 extraCredit = _calculateEarlyExitFeeNoCredit(
            controlledToken,
            amount
        );
        _accrueCredit(
            to,
            controlledToken,
            IERC20Upgradeable(controlledToken).balanceOf(to),
            extraCredit
        );

        emit Awarded(to, controlledToken, amount);
    }

    /// @notice Called by the Prize-Strategy to transfer out external ERC20 tokens
    /// @dev Used to transfer out tokens held by the Prize Pool.  Could be liquidated, or anything.
    /// @param to The address of the winner that receives the award
    /// @param amount The amount of external assets to be awarded
    /// @param externalToken The address of the external asset token being awarded
    function transferExternalERC20(
        address to,
        address externalToken,
        uint256 amount
    ) external override onlyPrizeStrategy {
        if (_transferOut(to, externalToken, amount)) {
            emit TransferredExternalERC20(to, externalToken, amount);
        }
    }

    /// @notice Called by the Prize-Strategy to award external ERC20 prizes
    /// @dev Used to award any arbitrary tokens held by the Prize Pool
    /// @param to The address of the winner that receives the award
    /// @param amount The amount of external assets to be awarded
    /// @param externalToken The address of the external asset token being awarded
    function awardExternalERC20(
        address to,
        address externalToken,
        uint256 amount
    ) external override onlyPrizeStrategy {
        if (_transferOut(to, externalToken, amount)) {
            emit AwardedExternalERC20(to, externalToken, amount);
        }
    }

    function _transferOut(
        address to,
        address externalToken,
        uint256 amount
    ) internal returns (bool) {
        require(
            _canAwardExternal(externalToken),
            "PrizePool/invalid-external-token"
        );

        if (amount == 0) {
            return false;
        }

        IERC20Upgradeable(externalToken).safeTransfer(to, amount);

        return true;
    }

    /// @notice Called to mint controlled tokens.  Ensures that token listener callbacks are fired.
    /// @param to The user who is receiving the tokens
    /// @param amount The amount of tokens they are receiving
    /// @param controlledToken The token that is going to be minted
    /// @param referrer The user who referred the minting
    function _mint(
        address to,
        uint256 amount,
        address controlledToken,
        address referrer
    ) internal {
        if (address(prizeStrategy) != address(0)) {
            prizeStrategy.beforeTokenMint(
                to,
                amount,
                controlledToken,
                referrer
            );
        }
        ControlledToken(controlledToken).controllerMint(to, amount);
    }

    /// @notice Calculates the reserve portion of the given amount of funds.  If there is no reserve address, the portion will be zero.
    /// @param amount The prize amount
    /// @return The size of the reserve portion of the prize
    function calculateReserveFee(uint256 amount) public view returns (uint256) {
        ReserveInterface reserve = ReserveInterface(reserveRegistry.lookup());
        if (address(reserve) == address(0)) {
            return 0;
        }
        uint256 reserveRateMantissa = reserve.reserveRateMantissa(
            address(this)
        );
        if (reserveRateMantissa == 0) {
            return 0;
        }
        return FixedPoint.multiplyUintByMantissa(amount, reserveRateMantissa);
    }

    /// @notice Calculates the early exit fee for the given amount
    /// @param from The user who is withdrawing
    /// @param controlledToken The type of collateral being withdrawn
    /// @param amount The amount of collateral to be withdrawn
    /// @return exitFee The exit fee
    /// @return burnedCredit The user's credit that was burned
    function calculateEarlyExitFee(
        address from,
        address controlledToken,
        uint256 amount
    ) external override returns (uint256 exitFee, uint256 burnedCredit) {
        (exitFee, burnedCredit) = _calculateEarlyExitFeeLessBurnedCredit(
            from,
            controlledToken,
            amount
        );
    }

    /// @dev Calculates the early exit fee for the given amount
    /// @param amount The amount of collateral to be withdrawn
    /// @return Exit fee
    function _calculateEarlyExitFeeNoCredit(
        address controlledToken,
        uint256 amount
    ) internal view returns (uint256) {
        return
            _limitExitFee(
                amount,
                FixedPoint.multiplyUintByMantissa(
                    amount,
                    _tokenCreditPlans[controlledToken].creditLimitMantissa
                )
            );
    }

    /// @notice Estimates the amount of time it will take for a given amount of funds to accrue the given amount of credit.
    /// @param _principal The principal amount on which interest is accruing
    /// @param _interest The amount of interest that must accrue
    /// @return durationSeconds The duration of time it will take to accrue the given amount of interest, in seconds.
    function estimateCreditAccrualTime(
        address _controlledToken,
        uint256 _principal,
        uint256 _interest
    ) external view override returns (uint256 durationSeconds) {
        durationSeconds = _estimateCreditAccrualTime(
            _controlledToken,
            _principal,
            _interest
        );
    }

    /// @notice Estimates the amount of time it will take for a given amount of funds to accrue the given amount of credit
    /// @param _principal The principal amount on which interest is accruing
    /// @param _interest The amount of interest that must accrue
    /// @return durationSeconds The duration of time it will take to accrue the given amount of interest, in seconds.
    function _estimateCreditAccrualTime(
        address _controlledToken,
        uint256 _principal,
        uint256 _interest
    ) internal view returns (uint256 durationSeconds) {
        // interest = credit rate * principal * time
        // => time = interest / (credit rate * principal)
        uint256 accruedPerSecond = FixedPoint.multiplyUintByMantissa(
            _principal,
            _tokenCreditPlans[_controlledToken].creditRateMantissa
        );
        if (accruedPerSecond == 0) {
            return 0;
        }
        return _interest.div(accruedPerSecond);
    }

    /// @notice Burns a users credit.
    /// @param user The user whose credit should be burned
    /// @param credit The amount of credit to burn
    function _burnCredit(
        address user,
        address controlledToken,
        uint256 credit
    ) internal {
        _tokenCreditBalances[controlledToken][user].balance = uint256(
            _tokenCreditBalances[controlledToken][user].balance
        ).sub(credit).toUint128();

        emit CreditBurned(user, controlledToken, credit);
    }

    /// @notice Accrues ticket credit for a user assuming their current balance is the passed balance.  May burn credit if they exceed their limit.
    /// @param user The user for whom to accrue credit
    /// @param controlledToken The controlled token whose balance we are checking
    /// @param controlledTokenBalance The balance to use for the user
    /// @param extra Additional credit to be added
    function _accrueCredit(
        address user,
        address controlledToken,
        uint256 controlledTokenBalance,
        uint256 extra
    ) internal {
        _updateCreditBalance(
            user,
            controlledToken,
            _calculateCreditBalance(
                user,
                controlledToken,
                controlledTokenBalance,
                extra
            )
        );
    }

    function _calculateCreditBalance(
        address user,
        address controlledToken,
        uint256 controlledTokenBalance,
        uint256 extra
    ) internal view returns (uint256) {
        uint256 newBalance;
        CreditBalance storage creditBalance = _tokenCreditBalances[
            controlledToken
        ][user];
        if (!creditBalance.initialized) {
            newBalance = 0;
        } else {
            uint256 credit = _calculateAccruedCredit(
                user,
                controlledToken,
                controlledTokenBalance
            );
            newBalance = _applyCreditLimit(
                controlledToken,
                controlledTokenBalance,
                uint256(creditBalance.balance).add(credit).add(extra)
            );
        }
        return newBalance;
    }

    function _updateCreditBalance(
        address user,
        address controlledToken,
        uint256 newBalance
    ) internal {
        uint256 oldBalance = _tokenCreditBalances[controlledToken][user]
            .balance;

        _tokenCreditBalances[controlledToken][user] = CreditBalance({
            balance: newBalance.toUint128(),
            timestamp: _currentTime().toUint32(),
            initialized: true
        });

        if (oldBalance < newBalance) {
            emit CreditMinted(
                user,
                controlledToken,
                newBalance.sub(oldBalance)
            );
        } else if (newBalance < oldBalance) {
            emit CreditBurned(
                user,
                controlledToken,
                oldBalance.sub(newBalance)
            );
        }
    }

    /// @notice Applies the credit limit to a credit balance.  The balance cannot exceed the credit limit.
    /// @param controlledToken The controlled token that the user holds
    /// @param controlledTokenBalance The users ticket balance (used to calculate credit limit)
    /// @param creditBalance The new credit balance to be checked
    /// @return The users new credit balance.  Will not exceed the credit limit.
    function _applyCreditLimit(
        address controlledToken,
        uint256 controlledTokenBalance,
        uint256 creditBalance
    ) internal view returns (uint256) {
        uint256 creditLimit = FixedPoint.multiplyUintByMantissa(
            controlledTokenBalance,
            _tokenCreditPlans[controlledToken].creditLimitMantissa
        );
        if (creditBalance > creditLimit) {
            creditBalance = creditLimit;
        }

        return creditBalance;
    }

    /// @notice Calculates the accrued interest for a user
    /// @param user The user whose credit should be calculated.
    /// @param controlledToken The controlled token that the user holds
    /// @param controlledTokenBalance The user's current balance of the controlled tokens.
    /// @return The credit that has accrued since the last credit update.
    function _calculateAccruedCredit(
        address user,
        address controlledToken,
        uint256 controlledTokenBalance
    ) internal view returns (uint256) {
        uint256 userTimestamp = _tokenCreditBalances[controlledToken][user]
            .timestamp;

        if (!_tokenCreditBalances[controlledToken][user].initialized) {
            return 0;
        }

        uint256 deltaTime = _currentTime().sub(userTimestamp);
        uint256 deltaMantissa = deltaTime.mul(
            _tokenCreditPlans[controlledToken].creditRateMantissa
        );
        return
            FixedPoint.multiplyUintByMantissa(
                controlledTokenBalance,
                deltaMantissa
            );
    }

    /// @notice Returns the credit balance for a given user.  Not that this includes both minted credit and pending credit.
    /// @param user The user whose credit balance should be returned
    /// @return The balance of the users credit
    function balanceOfCredit(address user, address controlledToken)
        external
        override
        onlyControlledToken(controlledToken)
        returns (uint256)
    {
        _accrueCredit(
            user,
            controlledToken,
            IERC20Upgradeable(controlledToken).balanceOf(user),
            0
        );
        return _tokenCreditBalances[controlledToken][user].balance;
    }

    /// @notice Sets the rate at which credit accrues per second.  The credit rate is a fixed point 18 number (like Ether).
    /// @param _controlledToken The controlled token for whom to set the credit plan
    /// @param _creditRateMantissa The credit rate to set.  Is a fixed point 18 decimal (like Ether).
    /// @param _creditLimitMantissa The credit limit to set.  Is a fixed point 18 decimal (like Ether).
    function setCreditPlanOf(
        address _controlledToken,
        uint128 _creditRateMantissa,
        uint128 _creditLimitMantissa
    ) external override onlyControlledToken(_controlledToken) onlyOwner {
        _tokenCreditPlans[_controlledToken] = CreditPlan({
            creditLimitMantissa: _creditLimitMantissa,
            creditRateMantissa: _creditRateMantissa
        });

        emit CreditPlanSet(
            _controlledToken,
            _creditLimitMantissa,
            _creditRateMantissa
        );
    }

    /// @notice Returns the credit rate of a controlled token
    /// @param controlledToken The controlled token to retrieve the credit rates for
    /// @return creditLimitMantissa The credit limit fraction.  This number is used to calculate both the credit limit and early exit fee.
    /// @return creditRateMantissa The credit rate. This is the amount of tokens that accrue per second.
    function creditPlanOf(address controlledToken)
        external
        view
        override
        returns (uint128 creditLimitMantissa, uint128 creditRateMantissa)
    {
        creditLimitMantissa = _tokenCreditPlans[controlledToken]
            .creditLimitMantissa;
        creditRateMantissa = _tokenCreditPlans[controlledToken]
            .creditRateMantissa;
    }

    /// @notice Calculate the early exit for a user given a withdrawal amount.  The user's credit is taken into account.
    /// @param from The user who is withdrawing
    /// @param controlledToken The token they are withdrawing
    /// @param amount The amount of funds they are withdrawing
    /// @return earlyExitFee The additional exit fee that should be charged.
    /// @return creditBurned The amount of credit that will be burned
    function _calculateEarlyExitFeeLessBurnedCredit(
        address from,
        address controlledToken,
        uint256 amount
    ) internal returns (uint256 earlyExitFee, uint256 creditBurned) {
        uint256 controlledTokenBalance = IERC20Upgradeable(controlledToken)
            .balanceOf(from);
        require(controlledTokenBalance >= amount, "PrizePool/insuff-funds");
        _accrueCredit(from, controlledToken, controlledTokenBalance, 0);
        /*
    The credit is used *last*.  Always charge the fees up-front.

    How to calculate:

    Calculate their remaining exit fee.  I.e. full exit fee of their balance less their credit.

    If the exit fee on their withdrawal is greater than the remaining exit fee, then they'll have to pay the difference.
    */

        // Determine available usable credit based on withdraw amount
        uint256 remainingExitFee = _calculateEarlyExitFeeNoCredit(
            controlledToken,
            controlledTokenBalance.sub(amount)
        );

        uint256 availableCredit;
        if (
            _tokenCreditBalances[controlledToken][from].balance >=
            remainingExitFee
        ) {
            availableCredit = uint256(
                _tokenCreditBalances[controlledToken][from].balance
            ).sub(remainingExitFee);
        }

        // Determine amount of credit to burn and amount of fees required
        uint256 totalExitFee = _calculateEarlyExitFeeNoCredit(
            controlledToken,
            amount
        );
        creditBurned = (availableCredit > totalExitFee)
            ? totalExitFee
            : availableCredit;
        earlyExitFee = totalExitFee.sub(creditBurned);
    }

    /// @notice Allows the Governor to set a cap on the amount of liquidity that he pool can hold
    /// @param _liquidityCap The new liquidity cap for the prize pool
    function setLiquidityCap(uint256 _liquidityCap)
        external
        override
        onlyOwner
    {
        _setLiquidityCap(_liquidityCap);
    }

    function _setLiquidityCap(uint256 _liquidityCap) internal {
        liquidityCap = _liquidityCap;
        emit LiquidityCapSet(_liquidityCap);
    }

    /// @notice Adds a new controlled token
    /// @param _controlledToken The controlled token to add.
    /// @param index The index to add the controlledToken
    function _addControlledToken(
        ControlledTokenInterface _controlledToken,
        uint256 index
    ) internal {
        require(
            _controlledToken.controller() == this,
            "PrizePool/token-ctrlr-mismatch"
        );

        _tokens[index] = _controlledToken;
        emit ControlledTokenAdded(_controlledToken);
    }

    /// @notice Sets the prize strategy of the prize pool.  Only callable by the owner.
    /// @param _prizeStrategy The new prize strategy
    function setPrizeStrategy(TokenListenerInterface _prizeStrategy)
        external
        override
        onlyOwner
    {
        _setPrizeStrategy(_prizeStrategy);
    }

    /// @notice Sets the prize strategy of the prize pool.  Only callable by the owner.
    /// @param _prizeStrategy The new prize strategy
    function _setPrizeStrategy(TokenListenerInterface _prizeStrategy) internal {
        require(
            address(_prizeStrategy) != address(0),
            "PrizePool/prizeStrategy-not-zero"
        );
        require(
            address(_prizeStrategy).supportsInterface(
                TokenListenerLibrary.ERC165_INTERFACE_ID_TOKEN_LISTENER
            ),
            "PrizePool/prizeStrategy-invalid"
        );
        prizeStrategy = _prizeStrategy;

        emit PrizeStrategySet(address(_prizeStrategy));
    }

    /// @notice An array of the Tokens controlled by the Prize Pool (ie. Tickets, Sponsorship)
    /// @return An array of controlled token addresses
    function tokens()
        external
        view
        override
        returns (ControlledTokenInterface[] memory)
    {
        return _tokens;
    }

    /// @dev Gets the current time as represented by the current block
    /// @return The timestamp of the current block
    function _currentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    /// @notice The total of all controlled tokens
    /// @return The current total of all tokens
    function accountedBalance() external view override returns (uint256) {
        return _tokenTotalSupply();
    }

    /// @notice Delegate the votes for a Compound COMP-like token held by the prize pool
    /// @param compLike The COMP-like token held by the prize pool that should be delegated
    /// @param to The address to delegate to
    function compLikeDelegate(ICompLike compLike, address to)
        external
        onlyOwner
    {
        if (compLike.balanceOf(address(this)) > 0) {
            compLike.delegate(to);
        }
    }

    /// @notice The total of all controlled tokens
    /// @return The current total of all tokens
    function _tokenTotalSupply() internal view returns (uint256) {
        uint256 total = reserveTotalSupply;
        ControlledTokenInterface[] memory tokens = _tokens; // SLOAD
        uint256 tokensLength = tokens.length;

        for (uint256 i = 0; i < tokensLength; i++) {
            total = total.add(IERC20Upgradeable(tokens[i]).totalSupply());
        }

        return total;
    }

    function _ticketToAmount(uint256 ticket) public view returns (uint256) {
        uint256 tokenTotalSupply = _tokenTotalSupply();
        uint256 share = ticket.mul(_currentAwardBalance).div(tokenTotalSupply);
        uint256 amount = ticket.add(share);
        return amount;
    }

    /// @dev Checks if the Prize Pool can receive liquidity based on the current cap
    /// @param _amount The amount of liquidity to be added to the Prize Pool
    /// @return True if the Prize Pool can receive the specified amount of liquidity
    function _canAddLiquidity(uint256 _amount) internal view returns (bool) {
        uint256 tokenTotalSupply = _tokenTotalSupply();
        return (tokenTotalSupply.add(_amount) <= liquidityCap);
    }

    /// @dev Checks if a specific token is controlled by the Prize Pool
    /// @param controlledToken The address of the token to check
    /// @return True if the token is a controlled token, false otherwise
    function _isControlled(ControlledTokenInterface controlledToken)
        internal
        view
        returns (bool)
    {
        ControlledTokenInterface[] memory tokens = _tokens; // SLOAD
        uint256 tokensLength = tokens.length;

        for (uint256 i = 0; i < tokensLength; i++) {
            if (tokens[i] == controlledToken) return true;
        }
        return false;
    }

    /// @dev Checks if a specific token is controlled by the Prize Pool
    /// @param controlledToken The address of the token to check
    /// @return True if the token is a controlled token, false otherwise
    function isControlled(ControlledTokenInterface controlledToken)
        external
        view
        returns (bool)
    {
        return _isControlled(controlledToken);
    }

    /// @notice Determines whether the passed token can be transferred out as an external award.
    /// @dev Different yield sources will hold the deposits as another kind of token: such a Compound's cToken.  The
    /// prize strategy should not be allowed to move those tokens.
    /// @param _externalToken The address of the token to check
    /// @return True if the token may be awarded, false otherwise
    function _canAwardExternal(address _externalToken)
        internal
        view
        virtual
        returns (bool);

    /// @notice Returns the ERC20 asset token used for deposits.
    /// @return The ERC20 asset token
    function _token() internal view virtual returns (IERC20Upgradeable);

    /// @notice Returns the total balance (in asset tokens).  This includes the deposits and interest.
    /// @return The underlying balance of asset tokens
    function _balance() internal virtual returns (uint256);

    /// @notice Supplies asset tokens to the yield source.
    /// @param mintAmount The amount of asset tokens to be supplied
    function _supply(uint256 mintAmount) internal virtual;

    /// @notice Redeems asset tokens from the yield source.
    /// @param redeemAmount The amount of yield-bearing tokens to be redeemed
    /// @return The actual amount of tokens that were redeemed.
    function _redeem(uint256 redeemAmount) internal virtual returns (uint256);

    /// @dev Function modifier to ensure usage of tokens controlled by the Prize Pool
    /// @param controlledToken The address of the token to check
    modifier onlyControlledToken(address controlledToken) {
        require(
            _isControlled(ControlledTokenInterface(controlledToken)),
            "PrizePool/unknown-token"
        );
        _;
    }

    /// @dev Function modifier to ensure caller is the prize-strategy
    modifier onlyPrizeStrategy() {
        require(
            _msgSender() == address(prizeStrategy),
            "PrizePool/only-prizeStrategy"
        );
        _;
    }

    /// @dev Function modifier to ensure the deposit amount does not exceed the liquidity cap (if set)
    modifier canAddLiquidity(uint256 _amount) {
        require(_canAddLiquidity(_amount), "PrizePool/exceeds-liquidity-cap");
        _;
    }

    modifier onlyReserve() {
        ReserveInterface reserve = ReserveInterface(reserveRegistry.lookup());
        require(address(reserve) == msg.sender, "PrizePool/only-reserve");
        _;
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

library Constants {
  bytes4 public constant ERC165_INTERFACE_ID_ERC165 = 0x01ffc9a7;
  bytes4 public constant ERC165_INTERFACE_ID_ERC721 = 0x80ac58cd;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/introspection/IERC165Upgradeable.sol";

/* solium-disable security/no-block-members */
interface PeriodicPrizeStrategyListenerInterface is IERC165Upgradeable {
  function afterPrizePoolAwarded(uint256 randomNumber, uint256 prizePeriodStartedAt) external;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

library PeriodicPrizeStrategyListenerLibrary {
  /*
    *     bytes4(keccak256('afterPrizePoolAwarded(uint256,uint256)')) == 0x575072c6
    */
  bytes4 public constant ERC165_INTERFACE_ID_PERIODIC_PRIZE_STRATEGY_LISTENER = 0x575072c6;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "./BeforeAwardListenerInterface.sol";
import "../Constants.sol";
import "./BeforeAwardListenerLibrary.sol";

abstract contract BeforeAwardListener is BeforeAwardListenerInterface {
  function supportsInterface(bytes4 interfaceId) external override view returns (bool) {
    return (
      interfaceId == Constants.ERC165_INTERFACE_ID_ERC165 || 
      interfaceId == BeforeAwardListenerLibrary.ERC165_INTERFACE_ID_BEFORE_AWARD_LISTENER
    );
  }
}

// SPDX-License-Identifier: MIT

// NOTE: Copied from OpenZeppelin Contracts version 3.3.0

pragma solidity >=0.6.0 <0.8.0;

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
library OpenZeppelinSafeMath_V3_3_0 {
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

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.7.0;

import "@openzeppelin/contracts-upgradeable/introspection/IERC165Upgradeable.sol";

/// @title An interface that allows a contract to listen to token mint, transfer and burn events.
interface TokenListenerInterface is IERC165Upgradeable {
  /// @notice Called when tokens are minted.
  /// @param to The address of the receiver of the minted tokens.
  /// @param amount The amount of tokens being minted
  /// @param controlledToken The address of the token that is being minted
  /// @param referrer The address that referred the minting.
  function beforeTokenMint(address to, uint256 amount, address controlledToken, address referrer) external;

  /// @notice Called when tokens are transferred or burned.
  /// @param from The address of the sender of the token transfer
  /// @param to The address of the receiver of the token transfer.  Will be the zero address if burning.
  /// @param amount The amount of tokens transferred
  /// @param controlledToken The address of the token that was transferred
  function beforeTokenTransfer(address from, address to, uint256 amount, address controlledToken) external;
}

pragma solidity 0.6.12;

library TokenListenerLibrary {
  /*
    *     bytes4(keccak256('beforeTokenMint(address,uint256,address,address)')) == 0x4d7f3db0
    *     bytes4(keccak256('beforeTokenTransfer(address,address,uint256,address)')) == 0xb2210957
    *
    *     => 0x4d7f3db0 ^ 0xb2210957 == 0xff5e34e7
    */
  bytes4 public constant ERC165_INTERFACE_ID_TOKEN_LISTENER = 0xff5e34e7;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

pragma solidity >=0.6.0 <0.8.0;
import "../proxy/Initializable.sol";

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

    function __ReentrancyGuard_init() internal initializer {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal initializer {
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
    uint256[49] private __gap;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface ICompLike is IERC20Upgradeable {
  function getCurrentVotes(address account) external view returns (uint96);
  function delegate(address delegatee) external;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.7.0;

/// @title Interface that allows a user to draw an address using an index
interface RegistryInterface {
  function lookup() external view returns (address);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.7.0;

/// @title Interface that allows a user to draw an address using an index
interface ReserveInterface {
  function reserveRateMantissa(address prizePool) external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

/// @notice An efficient implementation of a singly linked list of addresses
/// @dev A mapping(address => address) tracks the 'next' pointer.  A special address called the SENTINEL is used to denote the beginning and end of the list.
library MappedSinglyLinkedList {

  /// @notice The special value address used to denote the end of the list
  address public constant SENTINEL = address(0x1);

  /// @notice The data structure to use for the list.
  struct Mapping {
    uint256 count;

    mapping(address => address) addressMap;
  }

  /// @notice Initializes the list.
  /// @dev It is important that this is called so that the SENTINEL is correctly setup.
  function initialize(Mapping storage self) internal {
    require(self.count == 0, "Already init");
    self.addressMap[SENTINEL] = SENTINEL;
  }

  function start(Mapping storage self) internal view returns (address) {
    return self.addressMap[SENTINEL];
  }

  function next(Mapping storage self, address current) internal view returns (address) {
    return self.addressMap[current];
  }

  function end(Mapping storage) internal pure returns (address) {
    return SENTINEL;
  }

  function addAddresses(Mapping storage self, address[] memory addresses) internal {
    for (uint256 i = 0; i < addresses.length; i++) {
      addAddress(self, addresses[i]);
    }
  }

  /// @notice Adds an address to the front of the list.
  /// @param self The Mapping struct that this function is attached to
  /// @param newAddress The address to shift to the front of the list
  function addAddress(Mapping storage self, address newAddress) internal {
    require(newAddress != SENTINEL && newAddress != address(0), "Invalid address");
    require(self.addressMap[newAddress] == address(0), "Already added");
    self.addressMap[newAddress] = self.addressMap[SENTINEL];
    self.addressMap[SENTINEL] = newAddress;
    self.count = self.count + 1;
  }

  /// @notice Removes an address from the list
  /// @param self The Mapping struct that this function is attached to
  /// @param prevAddress The address that precedes the address to be removed.  This may be the SENTINEL if at the start.
  /// @param addr The address to remove from the list.
  function removeAddress(Mapping storage self, address prevAddress, address addr) internal {
    require(addr != SENTINEL && addr != address(0), "Invalid address");
    require(self.addressMap[prevAddress] == addr, "Invalid prevAddress");
    self.addressMap[prevAddress] = self.addressMap[addr];
    delete self.addressMap[addr];
    self.count = self.count - 1;
  }

  /// @notice Determines whether the list contains the given address
  /// @param self The Mapping struct that this function is attached to
  /// @param addr The address to check
  /// @return True if the address is contained, false otherwise.
  function contains(Mapping storage self, address addr) internal view returns (bool) {
    return addr != SENTINEL && addr != address(0) && self.addressMap[addr] != address(0);
  }

  /// @notice Returns an address array of all the addresses in this list
  /// @dev Contains a for loop, so complexity is O(n) wrt the list size
  /// @param self The Mapping struct that this function is attached to
  /// @return An array of all the addresses
  function addressArray(Mapping storage self) internal view returns (address[] memory) {
    address[] memory array = new address[](self.count);
    uint256 count;
    address currentAddress = self.addressMap[SENTINEL];
    while (currentAddress != address(0) && currentAddress != SENTINEL) {
      array[count] = currentAddress;
      currentAddress = self.addressMap[currentAddress];
      count++;
    }
    return array;
  }

  /// @notice Removes every address from the list
  /// @param self The Mapping struct that this function is attached to
  function clearAll(Mapping storage self) internal {
    address currentAddress = self.addressMap[SENTINEL];
    while (currentAddress != address(0) && currentAddress != SENTINEL) {
      address nextAddress = self.addressMap[currentAddress];
      delete self.addressMap[currentAddress];
      currentAddress = nextAddress;
    }
    self.addressMap[SENTINEL] = SENTINEL;
    self.count = 0;
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "../token/TokenListenerInterface.sol";
import "../token/ControlledTokenInterface.sol";

/// @title Escrows assets and deposits them into a yield source.  Exposes interest to Prize Strategy.  Users deposit and withdraw from this contract to participate in Prize Pool.
/// @notice Accounting is managed using Controlled Tokens, whose mint and burn functions can only be called by this contract.
/// @dev Must be inherited to provide specific yield-bearing asset control, such as Compound cTokens
interface PrizePoolInterface {
    /// @notice Deposit assets into the Prize Pool in exchange for tokens
    /// @param to The address receiving the newly minted tokens
    /// @param amount The amount of assets to deposit
    /// @param controlledToken The address of the type of token the user is minting
    /// @param referrer The referrer of the deposit
    function depositTo(
        address to,
        uint256 amount,
        address controlledToken,
        address referrer
    ) external;

    /// @notice Withdraw assets from the Prize Pool instantly.  A fairness fee may be charged for an early exit.
    /// @param from The address to redeem tokens from.
    /// @param amount The amount of tokens to redeem for assets.
    /// @param controlledToken The address of the token to redeem (i.e. ticket or sponsorship)
    /// @param maximumExitFee The maximum exit fee the caller is willing to pay.  This should be pre-calculated by the calculateExitFee() fxn.
    /// @return The actual exit fee paid
    function withdrawInstantlyFrom(
        address from,
        uint256 amount,
        address controlledToken,
        uint256 maximumExitFee
    ) external returns (uint256);

    function withdrawReserve(address to) external returns (uint256);

    /// @notice Returns the balance that is available to award.
    /// @dev captureAwardBalance() should be called first
    /// @return The total amount of assets to be awarded for the current prize
    function awardBalance() external view returns (uint256);

    /// @notice Captures any available interest as award balance.
    /// @dev This function also captures the reserve fees.
    /// @return The total amount of assets to be awarded for the current prize
    function captureAwardBalance() external returns (uint256);

    /// @notice Called by the prize strategy to award prizes.
    /// @dev The amount awarded must be less than the awardBalance()
    /// @param to The address of the winner that receives the award
    /// @param amount The amount of assets to be awarded
    /// @param controlledToken The address of the asset token being awarded
    function award(
        address to,
        uint256 amount,
        address controlledToken
    ) external;

    /// @notice Called by the Prize-Strategy to transfer out external ERC20 tokens
    /// @dev Used to transfer out tokens held by the Prize Pool.  Could be liquidated, or anything.
    /// @param to The address of the winner that receives the award
    /// @param amount The amount of external assets to be awarded
    /// @param externalToken The address of the external asset token being awarded
    function transferExternalERC20(
        address to,
        address externalToken,
        uint256 amount
    ) external;

    /// @notice Called by the Prize-Strategy to award external ERC20 prizes
    /// @dev Used to award any arbitrary tokens held by the Prize Pool
    /// @param to The address of the winner that receives the award
    /// @param amount The amount of external assets to be awarded
    /// @param externalToken The address of the external asset token being awarded
    function awardExternalERC20(
        address to,
        address externalToken,
        uint256 amount
    ) external;

    /// @notice Calculates the early exit fee for the given amount
    /// @param from The user who is withdrawing
    /// @param controlledToken The type of collateral being withdrawn
    /// @param amount The amount of collateral to be withdrawn
    /// @return exitFee The exit fee
    /// @return burnedCredit The user's credit that was burned
    function calculateEarlyExitFee(
        address from,
        address controlledToken,
        uint256 amount
    ) external returns (uint256 exitFee, uint256 burnedCredit);

    /// @notice Estimates the amount of time it will take for a given amount of funds to accrue the given amount of credit.
    /// @param _principal The principal amount on which interest is accruing
    /// @param _interest The amount of interest that must accrue
    /// @return durationSeconds The duration of time it will take to accrue the given amount of interest, in seconds.
    function estimateCreditAccrualTime(
        address _controlledToken,
        uint256 _principal,
        uint256 _interest
    ) external view returns (uint256 durationSeconds);

    /// @notice Returns the credit balance for a given user.  Not that this includes both minted credit and pending credit.
    /// @param user The user whose credit balance should be returned
    /// @return The balance of the users credit
    function balanceOfCredit(address user, address controlledToken)
        external
        returns (uint256);

    /// @notice Sets the rate at which credit accrues per second.  The credit rate is a fixed point 18 number (like Ether).
    /// @param _controlledToken The controlled token for whom to set the credit plan
    /// @param _creditRateMantissa The credit rate to set.  Is a fixed point 18 decimal (like Ether).
    /// @param _creditLimitMantissa The credit limit to set.  Is a fixed point 18 decimal (like Ether).
    function setCreditPlanOf(
        address _controlledToken,
        uint128 _creditRateMantissa,
        uint128 _creditLimitMantissa
    ) external;

    /// @notice Returns the credit rate of a controlled token
    /// @param controlledToken The controlled token to retrieve the credit rates for
    /// @return creditLimitMantissa The credit limit fraction.  This number is used to calculate both the credit limit and early exit fee.
    /// @return creditRateMantissa The credit rate. This is the amount of tokens that accrue per second.
    function creditPlanOf(address controlledToken)
        external
        view
        returns (uint128 creditLimitMantissa, uint128 creditRateMantissa);

    /// @notice Allows the Governor to set a cap on the amount of liquidity that he pool can hold
    /// @param _liquidityCap The new liquidity cap for the prize pool
    function setLiquidityCap(uint256 _liquidityCap) external;

    /// @notice Sets the prize strategy of the prize pool.  Only callable by the owner.
    /// @param _prizeStrategy The new prize strategy.  Must implement TokenListenerInterface
    function setPrizeStrategy(TokenListenerInterface _prizeStrategy) external;

    /// @dev Returns the address of the underlying ERC20 asset
    /// @return The address of the asset
    function token() external view returns (address);

    /// @notice An array of the Tokens controlled by the Prize Pool (ie. Tickets, Sponsorship)
    /// @return An array of controlled token addresses
    function tokens() external view returns (ControlledTokenInterface[] memory);

    /// @notice The total of all controlled tokens
    /// @return The current total of all tokens
    function accountedBalance() external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/introspection/IERC165Upgradeable.sol";

/// @notice The interface for the Periodic Prize Strategy before award listener.  This listener will be called immediately before the award is distributed.
interface BeforeAwardListenerInterface is IERC165Upgradeable {
  /// @notice Called immediately before the award is distributed
  function beforePrizePoolAwarded(uint256 randomNumber, uint256 prizePeriodStartedAt) external;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

library BeforeAwardListenerLibrary {
  /*
    *     bytes4(keccak256('beforePrizePoolAwarded(uint256,uint256)')) == 0x4cdf9c3e
    */
  bytes4 public constant ERC165_INTERFACE_ID_BEFORE_AWARD_LISTENER = 0x4cdf9c3e;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";
import "@pooltogether/yield-source-interface/contracts/IYieldSource.sol";

import "../registry/RegistryInterface.sol";
import "../prize-pool/yield-source/YieldSourcePrizePoolProxyFactory.sol";
import "./MultipleWinnersBuilder.sol";

contract PoolWithMultipleWinnersBuilder {
    using SafeCastUpgradeable for uint256;

    event YieldSourcePrizePoolWithMultipleWinnersCreated(
        YieldSourcePrizePool indexed prizePool,
        MultipleWinners indexed prizeStrategy
    );

    /// @notice The configuration used to initialize the Yield Source Compound Prize Pool
    struct YieldSourcePrizePoolConfig {
        IYieldSource yieldSource;
        uint256 maxExitFeeMantissa;
    }

    RegistryInterface public reserveRegistry;
    YieldSourcePrizePoolProxyFactory public yieldSourcePrizePoolProxyFactory;
    MultipleWinnersBuilder public multipleWinnersBuilder;

    constructor(
        RegistryInterface _reserveRegistry,
        YieldSourcePrizePoolProxyFactory _yieldSourcePrizePoolProxyFactory,
        MultipleWinnersBuilder _multipleWinnersBuilder
    ) public {
        require(
            address(_reserveRegistry) != address(0),
            "GlobalBuilder/reserveRegistry-not-zero"
        );
        require(
            address(_yieldSourcePrizePoolProxyFactory) != address(0),
            "GlobalBuilder/yieldSourcePrizePoolProxyFactory-not-zero"
        );
        require(
            address(_multipleWinnersBuilder) != address(0),
            "GlobalBuilder/multipleWinnersBuilder-not-zero"
        );
        reserveRegistry = _reserveRegistry;
        yieldSourcePrizePoolProxyFactory = _yieldSourcePrizePoolProxyFactory;
        multipleWinnersBuilder = _multipleWinnersBuilder;
    }

    function createYieldSourceMultipleWinners(
        YieldSourcePrizePoolConfig memory prizePoolConfig,
        MultipleWinnersBuilder.MultipleWinnersConfig memory prizeStrategyConfig,
        uint8 decimals
    ) external returns (YieldSourcePrizePool) {
        YieldSourcePrizePool prizePool = yieldSourcePrizePoolProxyFactory
            .create();
        MultipleWinners prizeStrategy = multipleWinnersBuilder
            .createMultipleWinners(
                prizePool,
                prizeStrategyConfig,
                decimals,
                msg.sender
            );
        prizePool.initializeYieldSourcePrizePool(
            reserveRegistry,
            _tokens(prizeStrategy),
            prizePoolConfig.maxExitFeeMantissa,
            prizePoolConfig.yieldSource
        );
        prizePool.setPrizeStrategy(prizeStrategy);
        prizePool.setCreditPlanOf(
            address(prizeStrategy.ticket()),
            prizeStrategyConfig.ticketCreditRateMantissa.toUint128(),
            prizeStrategyConfig.ticketCreditLimitMantissa.toUint128()
        );
        prizePool.transferOwnership(msg.sender);
        emit YieldSourcePrizePoolWithMultipleWinnersCreated(
            prizePool,
            prizeStrategy
        );
        return prizePool;
    }

    function _tokens(MultipleWinners _multipleWinners)
        internal
        view
        returns (ControlledTokenInterface[] memory)
    {
        ControlledTokenInterface[]
            memory tokens = new ControlledTokenInterface[](2);
        tokens[0] = ControlledTokenInterface(
            address(_multipleWinners.ticket())
        );
        tokens[1] = ControlledTokenInterface(
            address(_multipleWinners.sponsorship())
        );
        return tokens;
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0;

/// @title Defines the functions used to interact with a yield source.  The Prize Pool inherits this contract.
/// @notice Prize Pools subclasses need to implement this interface so that yield can be generated.
interface IYieldSource {
    /// @notice Returns the ERC20 asset token used for deposits.
    /// @return The ERC20 asset token address.
    function depositToken() external view returns (address);

    /// @notice Returns the total balance (in asset tokens).  This includes the deposits and interest.
    /// @return The underlying balance of asset tokens.
    function balanceOfToken(address addr) external returns (uint256);

    /// @notice Supplies tokens to the yield source.  Allows assets to be supplied on other user's behalf using the `to` param.
    /// @param amount The amount of asset tokens to be supplied.  Denominated in `depositToken()` as above.
    /// @param to The user whose balance will receive the tokens
    function supplyTokenTo(uint256 amount, address to) external;

    /// @notice Redeems tokens from the yield source.
    /// @param amount The amount of asset tokens to withdraw.  Denominated in `depositToken()` as above.
    /// @return The actual amount of interst bearing tokens that were redeemed.
    function redeemToken(uint256 amount) external returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "./YieldSourcePrizePool.sol";
import "../../external/openzeppelin/ProxyFactory.sol";

/// @title Yield Source Prize Pool Proxy Factory
/// @notice Minimal proxy pattern for creating new Yield Source Prize Pools
contract YieldSourcePrizePoolProxyFactory is ProxyFactory {

  /// @notice Contract template for deploying proxied Prize Pools
  YieldSourcePrizePool public instance;

  /// @notice Initializes the Factory with an instance of the Yield Source Prize Pool
  constructor () public {
    instance = new YieldSourcePrizePool();
  }

  /// @notice Creates a new Yield Source Prize Pool as a proxy of the template instance
  /// @return A reference to the new proxied Yield Source Prize Pool
  function create() external returns (YieldSourcePrizePool) {
    return YieldSourcePrizePool(deployMinimal(address(instance), ""));
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "@pooltogether/yield-source-interface/contracts/IYieldSource.sol";

import "../PrizePool.sol";

contract YieldSourcePrizePool is PrizePool {

  using SafeERC20Upgradeable for IERC20Upgradeable;
  using AddressUpgradeable for address;

  IYieldSource public yieldSource;

  event YieldSourcePrizePoolInitialized(address indexed yieldSource);

  /// @notice Initializes the Prize Pool and Yield Service with the required contract connections
  /// @param _controlledTokens Array of addresses for the Ticket and Sponsorship Tokens controlled by the Prize Pool
  /// @param _maxExitFeeMantissa The maximum exit fee size, relative to the withdrawal amount
  /// @param _yieldSource Address of the yield source
  function initializeYieldSourcePrizePool (
    RegistryInterface _reserveRegistry,
    ControlledTokenInterface[] memory _controlledTokens,
    uint256 _maxExitFeeMantissa,
    IYieldSource _yieldSource
  )
    public
    initializer
  {
    require(address(_yieldSource).isContract(), "YieldSourcePrizePool/yield-source-not-contract-address");
    PrizePool.initialize(
      _reserveRegistry,
      _controlledTokens,
      _maxExitFeeMantissa
    );
    yieldSource = _yieldSource;

    // A hack to determine whether it's an actual yield source
    (bool succeeded,) = address(_yieldSource).staticcall(abi.encode(_yieldSource.depositToken.selector));
    require(succeeded, "YieldSourcePrizePool/invalid-yield-source");

    emit YieldSourcePrizePoolInitialized(address(_yieldSource));
  }

  /// @notice Determines whether the passed token can be transferred out as an external award.
  /// @dev Different yield sources will hold the deposits as another kind of token: such a Compound's cToken.  The
  /// prize strategy should not be allowed to move those tokens.
  /// @param _externalToken The address of the token to check
  /// @return True if the token may be awarded, false otherwise
  function _canAwardExternal(address _externalToken) internal override view returns (bool) {
    return _externalToken != address(yieldSource);
  }

  /// @notice Returns the total balance (in asset tokens).  This includes the deposits and interest.
  /// @return The underlying balance of asset tokens
  function _balance() internal override returns (uint256) {
    return yieldSource.balanceOfToken(address(this));
  }

  function _token() internal override view returns (IERC20Upgradeable) {
    return IERC20Upgradeable(yieldSource.depositToken());
  }

  /// @notice Supplies asset tokens to the yield source.
  /// @param mintAmount The amount of asset tokens to be supplied
  function _supply(uint256 mintAmount) internal override {
    _token().safeApprove(address(yieldSource), mintAmount);
    yieldSource.supplyTokenTo(mintAmount, address(this));
  }

  /// @notice Redeems asset tokens from the yield source.
  /// @param redeemAmount The amount of yield-bearing tokens to be redeemed
  /// @return The actual amount of tokens that were redeemed.
  function _redeem(uint256 redeemAmount) internal override returns (uint256) {
    return yieldSource.redeemToken(redeemAmount);
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "./TokenFaucet.sol";
import "../external/openzeppelin/ProxyFactory.sol";

/// @title Stake Prize Pool Proxy Factory
/// @notice Minimal proxy pattern for creating new TokenFaucet contracts
contract TokenFaucetProxyFactory is ProxyFactory {

  /// @notice Contract template for deploying proxied Comptrollers
  TokenFaucet public instance;

  /// @notice Initializes the Factory with an instance of the TokenFaucet
  constructor () public {
    instance = new TokenFaucet();
  }

  /// @notice Creates a new TokenFaucet
  /// @param _asset The asset to disburse to users
  /// @param _measure The token to use to measure a users portion
  /// @param _dripRatePerSecond The amount of the asset to drip each second
  /// @return A reference to the new proxied TokenFaucet
  function create(
    IERC20Upgradeable _asset,
    IERC20Upgradeable _measure,
    uint256 _dripRatePerSecond
  ) public returns (TokenFaucet) {
    TokenFaucet tokenFaucet = TokenFaucet(deployMinimal(address(instance), ""));
    tokenFaucet.initialize(
      _asset, _measure, _dripRatePerSecond
    );
    tokenFaucet.transferOwnership(msg.sender);
    return tokenFaucet;
  }

  /// @notice Creates a new TokenFaucet and immediately deposits funds
  /// @param _asset The asset to disburse to users
  /// @param _measure The token to use to measure a users portion
  /// @param _dripRatePerSecond The amount of the asset to drip each second
  /// @param _amount The amount of assets to deposit into the faucet
  /// @return A reference to the new proxied TokenFaucet
  function createAndDeposit(
    IERC20Upgradeable _asset,
    IERC20Upgradeable _measure,
    uint256 _dripRatePerSecond,
    uint256 _amount
  ) external returns (TokenFaucet) {
    TokenFaucet faucet = create(_asset, _measure, _dripRatePerSecond);
    _asset.transferFrom(msg.sender, address(faucet), _amount);
  }

  /// @notice Runs claim on all passed comptrollers for a user.
  /// @param user The user to claim for
  /// @param tokenFaucets The tokenFaucets to call claim on.
  function claimAll(address user, TokenFaucet[] calldata tokenFaucets) external {
    for (uint256 i = 0; i < tokenFaucets.length; i++) {
      tokenFaucets[i].claim(user);
    }
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@pooltogether/fixed-point/contracts/FixedPoint.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../utils/ExtendedSafeCast.sol";
import "../token/TokenListener.sol";

/// @title Disburses a token at a fixed rate per second to holders of another token.
/// @notice The tokens are dripped at a "drip rate per second".  This is the number of tokens that
/// are dripped each second.  A user's share of the dripped tokens is based on how many 'measure' tokens they hold.
/* solium-disable security/no-block-members */
contract TokenFaucet is OwnableUpgradeable, TokenListener {
  using SafeMathUpgradeable for uint256;
  using SafeCastUpgradeable for uint256;
  using ExtendedSafeCast for uint256;

  event Initialized(
    IERC20Upgradeable indexed asset,
    IERC20Upgradeable indexed measure,
    uint256 dripRatePerSecond
  );

  event Dripped(
    uint256 newTokens
  );

  event Deposited(
    address indexed user,
    uint256 amount
  );

  event Withdrawn(
    address indexed to,
    uint256 amount
  );

  event Claimed(
    address indexed user,
    uint256 newTokens
  );

  event DripRateChanged(
    uint256 dripRatePerSecond
  );

  struct UserState {
    uint128 lastExchangeRateMantissa;
    uint128 balance;
  }

  /// @notice The token that is being disbursed
  IERC20Upgradeable public asset;

  /// @notice The token that is user to measure a user's portion of disbursed tokens
  IERC20Upgradeable public measure;

  /// @notice The total number of tokens that are disbursed each second
  uint256 public dripRatePerSecond;

  /// @notice The cumulative exchange rate of measure token supply : dripped tokens
  uint112 public exchangeRateMantissa;

  /// @notice The total amount of tokens that have been dripped but not claimed
  uint112 public totalUnclaimed;

  /// @notice The timestamp at which the tokens were last dripped
  uint32 public lastDripTimestamp;

  /// @notice The data structure that tracks when a user last received tokens
  mapping(address => UserState) public userStates;

  /// @notice Initializes a new Comptroller V2
  /// @param _asset The asset to disburse to users
  /// @param _measure The token to use to measure a users portion
  /// @param _dripRatePerSecond The amount of the asset to drip each second
  function initialize (
    IERC20Upgradeable _asset,
    IERC20Upgradeable _measure,
    uint256 _dripRatePerSecond
  ) public initializer {
    __Ownable_init();
    lastDripTimestamp = _currentTime();
    asset = _asset;
    measure = _measure;
    setDripRatePerSecond(_dripRatePerSecond);

    emit Initialized(
      asset,
      measure,
      dripRatePerSecond
    );
  }

  /// @notice Safely deposits asset tokens into the faucet.  Must be pre-approved
  /// This should be used instead of transferring directly because the drip function must
  /// be called before receiving new assets.
  /// @param amount The amount of asset tokens to add (must be approved already)
  function deposit(uint256 amount) external {
    drip();
    asset.transferFrom(msg.sender, address(this), amount);

    emit Deposited(msg.sender, amount);
  }

  /// @notice Allows the owner to withdraw tokens that have not been dripped yet.
  /// @param to The address to withdraw to
  /// @param amount The amount to withdraw
  function withdrawTo(address to, uint256 amount) external onlyOwner {
    drip();
    uint256 assetTotalSupply = asset.balanceOf(address(this));
    uint256 availableTotalSupply = assetTotalSupply.sub(totalUnclaimed);
    require(amount <= availableTotalSupply, "TokenFaucet/insufficient-funds");
    asset.transfer(to, amount);

    emit Withdrawn(to, amount);
  }

  /// @notice Transfers all unclaimed tokens to the user
  /// @param user The user to claim tokens for
  /// @return The amount of tokens that were claimed.
  function claim(address user) external returns (uint256) {
    drip();
    _captureNewTokensForUser(user);
    uint256 balance = userStates[user].balance;
    userStates[user].balance = 0;
    totalUnclaimed = uint256(totalUnclaimed).sub(balance).toUint112();
    asset.transfer(user, balance);

    emit Claimed(user, balance);

    return balance;
  }

  /// @notice Drips new tokens.
  /// @dev Should be called immediately before any measure token mints/transfers/burns
  /// @return The number of new tokens dripped.
  function drip() public returns (uint256) {
    uint256 currentTimestamp = _currentTime();

    // this should only run once per block.
    if (lastDripTimestamp == uint32(currentTimestamp)) {
      return 0;
    }

    uint256 assetTotalSupply = asset.balanceOf(address(this));
    uint256 availableTotalSupply = assetTotalSupply.sub(totalUnclaimed);
    uint256 newSeconds = currentTimestamp.sub(lastDripTimestamp);
    uint256 nextExchangeRateMantissa = exchangeRateMantissa;
    uint256 newTokens;
    uint256 measureTotalSupply = measure.totalSupply();

    if (measureTotalSupply > 0 && availableTotalSupply > 0) {
      newTokens = newSeconds.mul(dripRatePerSecond);
      if (newTokens > availableTotalSupply) {
        newTokens = availableTotalSupply;
      }
      uint256 indexDeltaMantissa = FixedPoint.calculateMantissa(newTokens, measureTotalSupply);
      nextExchangeRateMantissa = nextExchangeRateMantissa.add(indexDeltaMantissa);

      emit Dripped(
        newTokens
      );
    }

    exchangeRateMantissa = nextExchangeRateMantissa.toUint112();
    totalUnclaimed = uint256(totalUnclaimed).add(newTokens).toUint112();
    lastDripTimestamp = currentTimestamp.toUint32();

    return newTokens;
  }

  /// @notice Allows the owner to set the drip rate per second.  This is the number of tokens that are dripped each second.
  /// @param _dripRatePerSecond The new drip rate in tokens per second
  function setDripRatePerSecond(uint256 _dripRatePerSecond) public onlyOwner {
    require(_dripRatePerSecond > 0, "TokenFaucet/dripRate-gt-zero");

    // ensure we're all caught up
    drip();

    dripRatePerSecond = _dripRatePerSecond;

    emit DripRateChanged(dripRatePerSecond);
  }

  /// @notice Captures new tokens for a user
  /// @dev This must be called before changes to the user's balance (i.e. before mint, transfer or burns)
  /// @param user The user to capture tokens for
  /// @return The number of new tokens
  function _captureNewTokensForUser(
    address user
  ) private returns (uint128) {
    UserState storage userState = userStates[user];
    if (exchangeRateMantissa == userState.lastExchangeRateMantissa) {
      // ignore if exchange rate is same
      return 0;
    }
    uint256 deltaExchangeRateMantissa = uint256(exchangeRateMantissa).sub(userState.lastExchangeRateMantissa);
    uint256 userMeasureBalance = measure.balanceOf(user);
    uint128 newTokens = FixedPoint.multiplyUintByMantissa(userMeasureBalance, deltaExchangeRateMantissa).toUint128();

    userStates[user] = UserState({
      lastExchangeRateMantissa: exchangeRateMantissa,
      balance: uint256(userState.balance).add(newTokens).toUint128()
    });

    return newTokens;
  }

  /// @notice Should be called before a user mints new "measure" tokens.
  /// @param to The user who is minting the tokens
  /// @param token The token they are minting
  function beforeTokenMint(
    address to,
    uint256,
    address token,
    address
  )
    external
    override
  {
    if (token == address(measure)) {
      drip();
      _captureNewTokensForUser(to);
    }
  }

  /// @notice Should be called before "measure" tokens are transferred or burned
  /// @param from The user who is sending the tokens
  /// @param to The user who is receiving the tokens
  /// @param token The token token they are burning
  function beforeTokenTransfer(
    address from,
    address to,
    uint256,
    address token
  )
    external
    override
  {
    // must be measure and not be minting
    if (token == address(measure) && from != address(0)) {
      drip();
      _captureNewTokensForUser(to);
      _captureNewTokensForUser(from);
    }
  }

  /// @notice returns the current time.  Allows for override in testing.
  /// @return The current time (block.timestamp)
  function _currentTime() internal virtual view returns (uint32) {
    return block.timestamp.toUint32();
  }

}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

library ExtendedSafeCast {

  /**
    * @dev Converts an unsigned uint256 into a unsigned uint112.
    *
    * Requirements:
    *
    * - input must be less than or equal to maxUint112.
    */
  function toUint112(uint256 value) internal pure returns (uint112) {
    require(value < 2**112, "SafeCast: value doesn't fit in an uint112");
    return uint112(value);
  }

  /**
    * @dev Converts an unsigned uint256 into a unsigned uint96.
    *
    * Requirements:
    *
    * - input must be less than or equal to maxUint96.
    */
  function toUint96(uint256 value) internal pure returns (uint96) {
    require(value < 2**96, "SafeCast: value doesn't fit in an uint96");
    return uint96(value);
  }

}

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../token-faucet/TokenFaucet.sol";

/* solium-disable security/no-block-members */
contract TokenFaucetHarness is TokenFaucet {

  uint32 internal time;

  function setCurrentTime(uint32 _time) external {
    time = _time;
  }

  function _currentTime() internal override view returns (uint32) {
    return time;
  }

}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "./PeriodicPrizeStrategyListenerInterface.sol";
import "./PeriodicPrizeStrategyListenerLibrary.sol";
import "../Constants.sol";

abstract contract PeriodicPrizeStrategyListener is PeriodicPrizeStrategyListenerInterface {
  function supportsInterface(bytes4 interfaceId) external override view returns (bool) {
    return (
      interfaceId == Constants.ERC165_INTERFACE_ID_ERC165 || 
      interfaceId == PeriodicPrizeStrategyListenerLibrary.ERC165_INTERFACE_ID_PERIODIC_PRIZE_STRATEGY_LISTENER
    );
  }
}

pragma solidity 0.6.12;

import "../prize-strategy/PeriodicPrizeStrategyListener.sol";

/* solium-disable security/no-block-members */
contract PeriodicPrizeStrategyListenerStub is PeriodicPrizeStrategyListener {

  event Awarded();

  function afterPrizePoolAwarded(uint256 randomNumber, uint256 prizePeriodStartedAt) external override {
    emit Awarded();
  }
}

pragma solidity 0.6.12;

import "../prize-strategy/PeriodicPrizeStrategy.sol";
import "./PeriodicPrizeStrategyDistributorInterface.sol";

/* solium-disable security/no-block-members */
contract PeriodicPrizeStrategyHarness is PeriodicPrizeStrategy {

  PeriodicPrizeStrategyDistributorInterface distributor;

  function setDistributor(PeriodicPrizeStrategyDistributorInterface _distributor) external {
    distributor = _distributor;
  }

  uint256 internal time;
  function setCurrentTime(uint256 _time) external {
    time = _time;
  }

  function _currentTime() internal override view returns (uint256) {
    return time;
  }

  function setRngRequest(uint32 requestId, uint32 lockBlock) external {
    rngRequest.id = requestId;
    rngRequest.lockBlock = lockBlock;
  }

  function _distribute(uint256 randomNumber) internal override {
    distributor.distribute(randomNumber);
  }

  function forceBeforeAwardListener(BeforeAwardListenerInterface listener) external {
    beforeAwardListener = listener;
  }
}

pragma solidity 0.6.12;

import "../prize-strategy/PeriodicPrizeStrategy.sol";

/* solium-disable security/no-block-members */
interface PeriodicPrizeStrategyDistributorInterface {
  function distribute(uint256 randomNumber) external;
}

pragma solidity 0.6.12;

import "../prize-strategy/BeforeAwardListener.sol";

/* solium-disable security/no-block-members */
contract BeforeAwardListenerStub is BeforeAwardListener {

  event Awarded();

  function beforePrizePoolAwarded(uint256 randomNumber, uint256 prizePeriodStartedAt) external override {
    emit Awarded();
  }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./IERC165Upgradeable.sol";
import "../proxy/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts may inherit from this and call {_registerInterface} to declare
 * their support of an interface.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    /*
     * bytes4(keccak256('supportsInterface(bytes4)')) == 0x01ffc9a7
     */
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;

    /**
     * @dev Mapping of interface ids to whether or not it's supported.
     */
    mapping(bytes4 => bool) private _supportedInterfaces;

    function __ERC165_init() internal initializer {
        __ERC165_init_unchained();
    }

    function __ERC165_init_unchained() internal initializer {
        // Derived contracts need only register support for their own interfaces,
        // we register support for ERC165 itself here
        _registerInterface(_INTERFACE_ID_ERC165);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     *
     * Time complexity O(1), guaranteed to always use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return _supportedInterfaces[interfaceId];
    }

    /**
     * @dev Registers the contract as an implementer of the interface defined by
     * `interfaceId`. Support of the actual ERC165 interface is automatic and
     * registering its interface id is not required.
     *
     * See {IERC165-supportsInterface}.
     *
     * Requirements:
     *
     * - `interfaceId` cannot be the ERC165 invalid interface (`0xffffffff`).
     */
    function _registerInterface(bytes4 interfaceId) internal virtual {
        require(interfaceId != 0xffffffff, "ERC165: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@pooltogether/fixed-point/contracts/FixedPoint.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@pooltogether/yield-source-interface/contracts/IYieldSource.sol";

import "../external/compound/CTokenInterface.sol";

/// @title Defines the functions used to interact with a yield source.  The Prize Pool inherits this contract.
/// @dev THIS CONTRACT IS EXPERIMENTAL!  USE AT YOUR OWN RISK
/// @notice Prize Pools subclasses need to implement this interface so that yield can be generated.
contract CTokenYieldSource is IYieldSource {
  using SafeMathUpgradeable for uint256;

  event CTokenYieldSourceInitialized(address indexed cToken);

  mapping(address => uint256) public balances;

  /// @notice Interface for the Yield-bearing cToken by Compound
  CTokenInterface public cToken;

  /// @notice Initializes the Yield Service with the Compound cToken
  /// @param _cToken Address of the Compound cToken interface
  constructor (
    CTokenInterface _cToken
  )
    public
  {
    cToken = _cToken;

    emit CTokenYieldSourceInitialized(address(cToken));
  }

  /// @notice Returns the ERC20 asset token used for deposits.
  /// @return The ERC20 asset token
  function depositToken() public override view returns (address) {
    return _tokenAddress();
  }

  function _tokenAddress() internal view returns (address) {
    return cToken.underlying();
  }

  function _token() internal view returns (IERC20Upgradeable) {
    return IERC20Upgradeable(_tokenAddress());
  }

  /// @notice Returns the total balance (in asset tokens).  This includes the deposits and interest.
  /// @return The underlying balance of asset tokens
  function balanceOfToken(address addr) external override returns (uint256) {
    uint256 totalUnderlying = cToken.balanceOfUnderlying(address(this));
    uint256 total = cToken.balanceOf(address(this));
    if (total == 0) {
      return 0;
    }
    return balances[addr].mul(totalUnderlying).div(total);
  }

  /// @notice Supplies asset tokens to the yield source.
  /// @param amount The amount of asset tokens to be supplied
  function supplyTokenTo(uint256 amount, address to) external override {
    _token().transferFrom(msg.sender, address(this), amount);
    IERC20Upgradeable(cToken.underlying()).approve(address(cToken), amount);
    uint256 cTokenBalanceBefore = cToken.balanceOf(address(this));
    require(cToken.mint(amount) == 0, "CTokenYieldSource/mint-failed");
    uint256 cTokenDiff = cToken.balanceOf(address(this)).sub(cTokenBalanceBefore);
    balances[to] = balances[to].add(cTokenDiff);
  }

  /// @notice Redeems asset tokens from the yield source.
  /// @param redeemAmount The amount of yield-bearing tokens to be redeemed
  /// @return The actual amount of tokens that were redeemed.
  function redeemToken(uint256 redeemAmount) external override returns (uint256) {
    uint256 cTokenBalanceBefore = cToken.balanceOf(address(this));
    uint256 balanceBefore = _token().balanceOf(address(this));
    require(cToken.redeemUnderlying(redeemAmount) == 0, "CTokenYieldSource/redeem-failed");
    uint256 cTokenDiff = cTokenBalanceBefore.sub(cToken.balanceOf(address(this)));
    uint256 diff = _token().balanceOf(address(this)).sub(balanceBefore);
    balances[msg.sender] = balances[msg.sender].sub(cTokenDiff);
    _token().transfer(msg.sender, diff);
    return diff;
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface CTokenInterface is IERC20Upgradeable {
    function decimals() external view returns (uint8);
    function totalSupply() external override view returns (uint256);
    function underlying() external view returns (address);
    function balanceOfUnderlying(address owner) external returns (uint256);
    function supplyRatePerBlock() external returns (uint256);
    function exchangeRateCurrent() external returns (uint256);
    function mint(uint256 mintAmount) external returns (uint256);
    function redeem(uint256 amount) external returns (uint256);
    function balanceOf(address user) external override view returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../token/ControlledToken.sol";
import "../prize-strategy/PrizeSplit.sol";

/* solium-disable security/no-block-members */
contract PrizeSplitHarness is PrizeSplit {

  ControlledToken[] internal externalErc20s;

  constructor () public {
    __Ownable_init();
  }

  function initialize(ControlledToken[] calldata tokens) public {
    for (uint256 index = 0; index < tokens.length; index++) {
      externalErc20s.push(tokens[index]);
    }
  }

  function _awardPrizeSplitAmount(address target, uint256 amount, uint8 tokenIndex) override internal{
    require(tokenIndex == 0 || tokenIndex == 1, "PrizeSplitHarness/invalid-prizesplit-token-type");
    ControlledToken _token = externalErc20s[tokenIndex];
    _token.controllerMint(target, amount);
  }

  function distribute(uint256 prizeAmount) external returns (uint256) {
    prizeAmount = _distributePrizeSplits(prizeAmount);

    return prizeAmount;
  }

  function beforeTokenTransfer(address from, address to, uint256 amount) external {
    return;
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.7.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./ReserveInterface.sol";
import "../prize-pool/PrizePoolInterface.sol";

/// @title Interface that allows a user to draw an address using an index
contract Reserve is OwnableUpgradeable, ReserveInterface {

  event ReserveRateMantissaSet(uint256 rateMantissa);

  uint256 public rateMantissa;

  constructor () public {
    __Ownable_init();
  }

  function setRateMantissa(
    uint256 _rateMantissa
  )
    external
    onlyOwner
  {
    rateMantissa = _rateMantissa;

    emit ReserveRateMantissaSet(rateMantissa);
  }

  function withdrawReserve(address prizePool, address to) external onlyOwner returns (uint256) {
    return PrizePoolInterface(prizePool).withdrawReserve(to);
  }

  function reserveRateMantissa(address) external view override returns (uint256) {
    return rateMantissa;
  }
}

pragma solidity 0.6.12;

import "../prize-pool/PrizePool.sol";
import "./YieldSourceStub.sol";

contract PrizePoolHarness is PrizePool {

  uint256 public currentTime;

  YieldSourceStub stubYieldSource;

  function initializeAll(
    RegistryInterface _reserveRegistry,
    ControlledTokenInterface[] memory _controlledTokens,
    uint256 _maxExitFeeMantissa,
    YieldSourceStub _stubYieldSource
  )
    public
  {
    PrizePool.initialize(
      _reserveRegistry,
      _controlledTokens,
      _maxExitFeeMantissa
    );
    stubYieldSource = _stubYieldSource;
  }

  function supply(uint256 mintAmount) external {
    _supply(mintAmount);
  }

  function redeem(uint256 redeemAmount) external {
    _redeem(redeemAmount);
  }

  function setCurrentTime(uint256 _currentTime) external {
    currentTime = _currentTime;
  }

  function _currentTime() internal override view returns (uint256) {
    return currentTime;
  }

  function _canAwardExternal(address _externalToken) internal override view returns (bool) {
    return stubYieldSource.canAwardExternal(_externalToken);
  }

  function _token() internal override view returns (IERC20Upgradeable) {
    return stubYieldSource.token();
  }

  function _balance() internal override returns (uint256) {
    return stubYieldSource.balance();
  }

  function _supply(uint256 mintAmount) internal override {
    return stubYieldSource.supply(mintAmount);
  }

  function _redeem(uint256 redeemAmount) internal override returns (uint256) {
    return stubYieldSource.redeem(redeemAmount);
  }
}

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface YieldSourceStub {
  function canAwardExternal(address _externalToken) external view returns (bool);

  function token() external view returns (IERC20Upgradeable);

  function balance() external returns (uint256);

  function supply(uint256 mintAmount) external;

  function redeem(uint256 redeemAmount) external returns (uint256);
}

pragma solidity 0.6.12;

import "../prize-pool/yield-source/YieldSourcePrizePool.sol";

/* solium-disable security/no-block-members */
contract YieldSourcePrizePoolHarness is YieldSourcePrizePool {

  uint256 public currentTime;

  function setCurrentTime(uint256 _currentTime) external {
    currentTime = _currentTime;
  }

  function _currentTime() internal override view returns (uint256) {
    return currentTime;
  }

  function supply(uint256 mintAmount) external {
    _supply(mintAmount);
  }

  function redeem(uint256 redeemAmount) external returns (uint256) {
    return _redeem(redeemAmount);
  }
}

pragma solidity 0.6.12;

import "./YieldSourcePrizePoolHarness.sol";
import "../external/openzeppelin/ProxyFactory.sol";

/// @title YieldSource Prize Pool Proxy Factory
/// @notice Minimal proxy pattern for creating new YieldSource Prize Pools
contract YieldSourcePrizePoolHarnessProxyFactory is ProxyFactory {

  /// @notice Contract template for deploying proxied Prize Pools
  YieldSourcePrizePoolHarness public instance;

  /// @notice Initializes the Factory with an instance of the YieldSource Prize Pool
  constructor () public {
    instance = new YieldSourcePrizePoolHarness();
  }

  /// @notice Creates a new YieldSource Prize Pool as a proxy of the template instance
  /// @return A reference to the new proxied YieldSource Prize Pool
  function create() external returns (YieldSourcePrizePoolHarness) {
    return YieldSourcePrizePoolHarness(deployMinimal(address(instance), ""));
  }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../utils/ContextUpgradeable.sol";
import "./IERC721Upgradeable.sol";
import "./IERC721MetadataUpgradeable.sol";
import "./IERC721EnumerableUpgradeable.sol";
import "./IERC721ReceiverUpgradeable.sol";
import "../../introspection/ERC165Upgradeable.sol";
import "../../math/SafeMathUpgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/EnumerableSetUpgradeable.sol";
import "../../utils/EnumerableMapUpgradeable.sol";
import "../../utils/StringsUpgradeable.sol";
import "../../proxy/Initializable.sol";

/**
 * @title ERC721 Non-Fungible Token Standard basic implementation
 * @dev see https://eips.ethereum.org/EIPS/eip-721
 */
contract ERC721Upgradeable is Initializable, ContextUpgradeable, ERC165Upgradeable, IERC721Upgradeable, IERC721MetadataUpgradeable, IERC721EnumerableUpgradeable {
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    using EnumerableMapUpgradeable for EnumerableMapUpgradeable.UintToAddressMap;
    using StringsUpgradeable for uint256;

    // Equals to `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    // which can be also obtained as `IERC721Receiver(0).onERC721Received.selector`
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    // Mapping from holder address to their (enumerable) set of owned tokens
    mapping (address => EnumerableSetUpgradeable.UintSet) private _holderTokens;

    // Enumerable mapping from token ids to their owners
    EnumerableMapUpgradeable.UintToAddressMap private _tokenOwners;

    // Mapping from token ID to approved address
    mapping (uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping (address => mapping (address => bool)) private _operatorApprovals;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Optional mapping for token URIs
    mapping (uint256 => string) private _tokenURIs;

    // Base URI
    string private _baseURI;

    /*
     *     bytes4(keccak256('balanceOf(address)')) == 0x70a08231
     *     bytes4(keccak256('ownerOf(uint256)')) == 0x6352211e
     *     bytes4(keccak256('approve(address,uint256)')) == 0x095ea7b3
     *     bytes4(keccak256('getApproved(uint256)')) == 0x081812fc
     *     bytes4(keccak256('setApprovalForAll(address,bool)')) == 0xa22cb465
     *     bytes4(keccak256('isApprovedForAll(address,address)')) == 0xe985e9c5
     *     bytes4(keccak256('transferFrom(address,address,uint256)')) == 0x23b872dd
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256)')) == 0x42842e0e
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)')) == 0xb88d4fde
     *
     *     => 0x70a08231 ^ 0x6352211e ^ 0x095ea7b3 ^ 0x081812fc ^
     *        0xa22cb465 ^ 0xe985e9c5 ^ 0x23b872dd ^ 0x42842e0e ^ 0xb88d4fde == 0x80ac58cd
     */
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    /*
     *     bytes4(keccak256('name()')) == 0x06fdde03
     *     bytes4(keccak256('symbol()')) == 0x95d89b41
     *     bytes4(keccak256('tokenURI(uint256)')) == 0xc87b56dd
     *
     *     => 0x06fdde03 ^ 0x95d89b41 ^ 0xc87b56dd == 0x5b5e139f
     */
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;

    /*
     *     bytes4(keccak256('totalSupply()')) == 0x18160ddd
     *     bytes4(keccak256('tokenOfOwnerByIndex(address,uint256)')) == 0x2f745c59
     *     bytes4(keccak256('tokenByIndex(uint256)')) == 0x4f6ccce7
     *
     *     => 0x18160ddd ^ 0x2f745c59 ^ 0x4f6ccce7 == 0x780e9d63
     */
    bytes4 private constant _INTERFACE_ID_ERC721_ENUMERABLE = 0x780e9d63;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    function __ERC721_init(string memory name_, string memory symbol_) internal initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __ERC721_init_unchained(name_, symbol_);
    }

    function __ERC721_init_unchained(string memory name_, string memory symbol_) internal initializer {
        _name = name_;
        _symbol = symbol_;

        // register the supported interfaces to conform to ERC721 via ERC165
        _registerInterface(_INTERFACE_ID_ERC721);
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
        _registerInterface(_INTERFACE_ID_ERC721_ENUMERABLE);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _holderTokens[owner].length();
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        return _tokenOwners.get(tokenId, "ERC721: owner query for nonexistent token");
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
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(base, tokenId.toString()));
    }

    /**
    * @dev Returns the base URI set via {_setBaseURI}. This will be
    * automatically added as a prefix in {tokenURI} to each token's URI, or
    * to the token ID if no specific URI is set for that token ID.
    */
    function baseURI() public view virtual returns (string memory) {
        return _baseURI;
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        return _holderTokens[owner].at(index);
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        // _tokenOwners are indexed by tokenIds, so .length() returns the number of tokenIds
        return _tokenOwners.length();
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        (uint256 tokenId, ) = _tokenOwners.at(index);
        return tokenId;
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(_msgSender() == owner || ERC721Upgradeable.isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(operator != _msgSender(), "ERC721: approve to caller");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
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
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
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
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
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
        return _tokenOwners.contains(tokenId);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || ERC721Upgradeable.isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     d*
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
    function _safeMint(address to, uint256 tokenId, bytes memory _data) internal virtual {
        _mint(to, tokenId);
        require(_checkOnERC721Received(address(0), to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
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

        _beforeTokenTransfer(address(0), to, tokenId);

        _holderTokens[to].add(tokenId);

        _tokenOwners.set(tokenId, to);

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721Upgradeable.ownerOf(tokenId); // internal owner

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        // Clear metadata (if any)
        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }

        _holderTokens[owner].remove(tokenId);

        _tokenOwners.remove(tokenId);

        emit Transfer(owner, address(0), tokenId);
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
    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        require(ERC721Upgradeable.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own"); // internal owner
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);

        _tokenOwners.set(tokenId, to);

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    /**
     * @dev Internal function to set the base URI for all token IDs. It is
     * automatically added as a prefix to the value returned in {tokenURI},
     * or to the token ID if {tokenURI} is empty.
     */
    function _setBaseURI(string memory baseURI_) internal virtual {
        _baseURI = baseURI_;
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data)
        private returns (bool)
    {
        if (!to.isContract()) {
            return true;
        }
        bytes memory returndata = to.functionCall(abi.encodeWithSelector(
            IERC721ReceiverUpgradeable(to).onERC721Received.selector,
            _msgSender(),
            from,
            tokenId,
            _data
        ), "ERC721: transfer to non ERC721Receiver implementer");
        bytes4 retval = abi.decode(returndata, (bytes4));
        return (retval == _ERC721_RECEIVED);
    }

    function _approve(address to, uint256 tokenId) private {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721Upgradeable.ownerOf(tokenId), to, tokenId); // internal owner
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual { }
    uint256[41] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

import "../../introspection/IERC165Upgradeable.sol";

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
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
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
    function transferFrom(address from, address to, uint256 tokenId) external;

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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

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
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

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
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

import "./IERC721Upgradeable.sol";

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

pragma solidity >=0.6.2 <0.8.0;

import "./IERC721Upgradeable.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721EnumerableUpgradeable is IERC721Upgradeable {

    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSetUpgradeable {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;

        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping (bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) { // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            // When the value to delete is the last one, the swap operation is unnecessary. However, since this occurs
            // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

            bytes32 lastvalue = set._values[lastIndex];

            // Move the last value to the index where the value to delete is
            set._values[toDeleteIndex] = lastvalue;
            // Update the index for the moved value
            set._indexes[lastvalue] = toDeleteIndex + 1; // All indexes are 1-based

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        require(set._values.length > index, "EnumerableSet: index out of bounds");
        return set._values[index];
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }


    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Library for managing an enumerable variant of Solidity's
 * https://solidity.readthedocs.io/en/latest/types.html#mapping-types[`mapping`]
 * type.
 *
 * Maps have the following properties:
 *
 * - Entries are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Entries are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableMap for EnumerableMap.UintToAddressMap;
 *
 *     // Declare a set state variable
 *     EnumerableMap.UintToAddressMap private myMap;
 * }
 * ```
 *
 * As of v3.0.0, only maps of type `uint256 -> address` (`UintToAddressMap`) are
 * supported.
 */
library EnumerableMapUpgradeable {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Map type with
    // bytes32 keys and values.
    // The Map implementation uses private functions, and user-facing
    // implementations (such as Uint256ToAddressMap) are just wrappers around
    // the underlying Map.
    // This means that we can only create new EnumerableMaps for types that fit
    // in bytes32.

    struct MapEntry {
        bytes32 _key;
        bytes32 _value;
    }

    struct Map {
        // Storage of map keys and values
        MapEntry[] _entries;

        // Position of the entry defined by a key in the `entries` array, plus 1
        // because index 0 means a key is not in the map.
        mapping (bytes32 => uint256) _indexes;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function _set(Map storage map, bytes32 key, bytes32 value) private returns (bool) {
        // We read and store the key's index to prevent multiple reads from the same storage slot
        uint256 keyIndex = map._indexes[key];

        if (keyIndex == 0) { // Equivalent to !contains(map, key)
            map._entries.push(MapEntry({ _key: key, _value: value }));
            // The entry is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            map._indexes[key] = map._entries.length;
            return true;
        } else {
            map._entries[keyIndex - 1]._value = value;
            return false;
        }
    }

    /**
     * @dev Removes a key-value pair from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function _remove(Map storage map, bytes32 key) private returns (bool) {
        // We read and store the key's index to prevent multiple reads from the same storage slot
        uint256 keyIndex = map._indexes[key];

        if (keyIndex != 0) { // Equivalent to contains(map, key)
            // To delete a key-value pair from the _entries array in O(1), we swap the entry to delete with the last one
            // in the array, and then remove the last entry (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = keyIndex - 1;
            uint256 lastIndex = map._entries.length - 1;

            // When the entry to delete is the last one, the swap operation is unnecessary. However, since this occurs
            // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

            MapEntry storage lastEntry = map._entries[lastIndex];

            // Move the last entry to the index where the entry to delete is
            map._entries[toDeleteIndex] = lastEntry;
            // Update the index for the moved entry
            map._indexes[lastEntry._key] = toDeleteIndex + 1; // All indexes are 1-based

            // Delete the slot where the moved entry was stored
            map._entries.pop();

            // Delete the index for the deleted slot
            delete map._indexes[key];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function _contains(Map storage map, bytes32 key) private view returns (bool) {
        return map._indexes[key] != 0;
    }

    /**
     * @dev Returns the number of key-value pairs in the map. O(1).
     */
    function _length(Map storage map) private view returns (uint256) {
        return map._entries.length;
    }

   /**
    * @dev Returns the key-value pair stored at position `index` in the map. O(1).
    *
    * Note that there are no guarantees on the ordering of entries inside the
    * array, and it may change when more entries are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function _at(Map storage map, uint256 index) private view returns (bytes32, bytes32) {
        require(map._entries.length > index, "EnumerableMap: index out of bounds");

        MapEntry storage entry = map._entries[index];
        return (entry._key, entry._value);
    }

    /**
     * @dev Tries to returns the value associated with `key`.  O(1).
     * Does not revert if `key` is not in the map.
     */
    function _tryGet(Map storage map, bytes32 key) private view returns (bool, bytes32) {
        uint256 keyIndex = map._indexes[key];
        if (keyIndex == 0) return (false, 0); // Equivalent to contains(map, key)
        return (true, map._entries[keyIndex - 1]._value); // All indexes are 1-based
    }

    /**
     * @dev Returns the value associated with `key`.  O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function _get(Map storage map, bytes32 key) private view returns (bytes32) {
        uint256 keyIndex = map._indexes[key];
        require(keyIndex != 0, "EnumerableMap: nonexistent key"); // Equivalent to contains(map, key)
        return map._entries[keyIndex - 1]._value; // All indexes are 1-based
    }

    /**
     * @dev Same as {_get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {_tryGet}.
     */
    function _get(Map storage map, bytes32 key, string memory errorMessage) private view returns (bytes32) {
        uint256 keyIndex = map._indexes[key];
        require(keyIndex != 0, errorMessage); // Equivalent to contains(map, key)
        return map._entries[keyIndex - 1]._value; // All indexes are 1-based
    }

    // UintToAddressMap

    struct UintToAddressMap {
        Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(UintToAddressMap storage map, uint256 key, address value) internal returns (bool) {
        return _set(map._inner, bytes32(key), bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(UintToAddressMap storage map, uint256 key) internal returns (bool) {
        return _remove(map._inner, bytes32(key));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(UintToAddressMap storage map, uint256 key) internal view returns (bool) {
        return _contains(map._inner, bytes32(key));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(UintToAddressMap storage map) internal view returns (uint256) {
        return _length(map._inner);
    }

   /**
    * @dev Returns the element stored at position `index` in the set. O(1).
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(UintToAddressMap storage map, uint256 index) internal view returns (uint256, address) {
        (bytes32 key, bytes32 value) = _at(map._inner, index);
        return (uint256(key), address(uint160(uint256(value))));
    }

    /**
     * @dev Tries to returns the value associated with `key`.  O(1).
     * Does not revert if `key` is not in the map.
     *
     * _Available since v3.4._
     */
    function tryGet(UintToAddressMap storage map, uint256 key) internal view returns (bool, address) {
        (bool success, bytes32 value) = _tryGet(map._inner, bytes32(key));
        return (success, address(uint160(uint256(value))));
    }

    /**
     * @dev Returns the value associated with `key`.  O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(UintToAddressMap storage map, uint256 key) internal view returns (address) {
        return address(uint160(uint256(_get(map._inner, bytes32(key)))));
    }

    /**
     * @dev Same as {get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryGet}.
     */
    function get(UintToAddressMap storage map, uint256 key, string memory errorMessage) internal view returns (address) {
        return address(uint160(uint256(_get(map._inner, bytes32(key), errorMessage))));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    /**
     * @dev Converts a `uint256` to its ASCII `string` representation.
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
        uint256 index = digits - 1;
        temp = value;
        while (temp != 0) {
            buffer[index--] = bytes1(uint8(48 + temp % 10));
            temp /= 10;
        }
        return string(buffer);
    }
}

pragma solidity 0.6.12;
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract NFT is ERC721Upgradeable {
  function initialize (
    string memory name_, string memory symbol_
  ) external initializer {
    __ERC721_init(name_, symbol_);
    _safeMint(msg.sender, 0);
  }

  function simulateSafeTransferFrom(address from, address to, uint256 tokenId) public {
    ERC721Upgradeable.safeTransferFrom(from, to, tokenId);
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "../external/maker/DaiInterface.sol";

contract Dai is DaiInterface {
  using SafeMathUpgradeable for uint256;
  using AddressUpgradeable for address;

  mapping (address => uint256) private _balances;

  mapping (address => mapping (address => uint256)) private _allowances;

  uint256 private _totalSupply;

  string private _name;
  string private _symbol;
  uint8 private _decimals;

  /**
    * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
    * a default value of 18.
    *
    * To select a different value for {decimals}, use {_setupDecimals}.
    *
    * All three of these values are immutable: they can only be set once during
    * construction.
    */
  constructor (uint256 chainId_) public {
    string memory version = "1";

    _name = "Dai Stablecoin";
    _symbol = "DAI";
    _decimals = 18;

    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        keccak256(bytes(_name)),
        keccak256(bytes(version)),
        chainId_,
        address(this)
      )
    );
  }

  /**
    * @dev Returns the name of the token.
    */
  function name() public view returns (string memory) {
      return _name;
  }

  /**
    * @dev Returns the symbol of the token, usually a shorter version of the
    * name.
    */
  function symbol() public view returns (string memory) {
      return _symbol;
  }

  /**
    * @dev Returns the number of decimals used to get its user representation.
    * For example, if `decimals` equals `2`, a balance of `505` tokens should
    * be displayed to a user as `5,05` (`505 / 10 ** 2`).
    *
    * Tokens usually opt for a value of 18, imitating the relationship between
    * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
    * called.
    *
    * NOTE: This information is only used for _display_ purposes: it in
    * no way affects any of the arithmetic of the contract, including
    * {IERC20-balanceOf} and {IERC20-transfer}.
    */
  function decimals() public view returns (uint8) {
      return _decimals;
  }

  /**
    * @dev See {IERC20-totalSupply}.
    */
  function totalSupply() public view override returns (uint256) {
      return _totalSupply;
  }

  /**
    * @dev See {IERC20-balanceOf}.
    */
  function balanceOf(address account) public view override returns (uint256) {
      return _balances[account];
  }

  /**
    * @dev See {IERC20-transfer}.
    *
    * Requirements:
    *
    * - `recipient` cannot be the zero address.
    * - the caller must have a balance of at least `amount`.
    */
  function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
      _transfer(msg.sender, recipient, amount);
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
    * Requirements:
    *
    * - `spender` cannot be the zero address.
    */
  function approve(address spender, uint256 amount) public virtual override returns (bool) {
      _approve(msg.sender, spender, amount);
      return true;
  }

  /**
    * @dev See {IERC20-transferFrom}.
    *
    * Emits an {Approval} event indicating the updated allowance. This is not
    * required by the EIP. See the note at the beginning of {ERC20};
    *
    * Requirements:
    * - `sender` and `recipient` cannot be the zero address.
    * - `sender` must have a balance of at least `amount`.
    * - the caller must have allowance for ``sender``'s tokens of at least
    * `amount`.
    */
  function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
      _transfer(sender, recipient, amount);
      _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
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
      _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
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
      _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
      return true;
  }

  /**
    * @dev Moves tokens `amount` from `sender` to `recipient`.
    *
    * This is internal function is equivalent to {transfer}, and can be used to
    * e.g. implement automatic token fees, slashing mechanisms, etc.
    *
    * Emits a {Transfer} event.
    *
    * Requirements:
    *
    * - `sender` cannot be the zero address.
    * - `recipient` cannot be the zero address.
    * - `sender` must have a balance of at least `amount`.
    */
  function _transfer(address sender, address recipient, uint256 amount) internal virtual {
      require(sender != address(0), "ERC20: transfer from the zero address");
      require(recipient != address(0), "ERC20: transfer to the zero address");

      _beforeTokenTransfer(sender, recipient, amount);

      _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
      _balances[recipient] = _balances[recipient].add(amount);
      emit Transfer(sender, recipient, amount);
  }

  /** @dev Creates `amount` tokens and assigns them to `account`, increasing
    * the total supply.
    *
    * Emits a {Transfer} event with `from` set to the zero address.
    *
    * Requirements
    *
    * - `to` cannot be the zero address.
    */
  function _mint(address account, uint256 amount) internal virtual {
      require(account != address(0), "ERC20: mint to the zero address");

      _beforeTokenTransfer(address(0), account, amount);

      _totalSupply = _totalSupply.add(amount);
      _balances[account] = _balances[account].add(amount);
      emit Transfer(address(0), account, amount);
  }

  /**
    * @dev Destroys `amount` tokens from `account`, reducing the
    * total supply.
    *
    * Emits a {Transfer} event with `to` set to the zero address.
    *
    * Requirements
    *
    * - `account` cannot be the zero address.
    * - `account` must have at least `amount` tokens.
    */
  function _burn(address account, uint256 amount) internal virtual {
      require(account != address(0), "ERC20: burn from the zero address");

      _beforeTokenTransfer(account, address(0), amount);

      _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
      _totalSupply = _totalSupply.sub(amount);
      emit Transfer(account, address(0), amount);
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
  function _approve(address owner, address spender, uint256 amount) internal virtual {
      require(owner != address(0), "ERC20: approve from the zero address");
      require(spender != address(0), "ERC20: approve to the zero address");

      _allowances[owner][spender] = amount;
      emit Approval(owner, spender, amount);
  }

  /**
    * @dev Sets {decimals} to a value other than the default one of 18.
    *
    * WARNING: This function should only be called from the constructor. Most
    * applications that interact with token contracts will not expect
    * {decimals} to ever change, and may work incorrectly if it does.
    */
  function _setupDecimals(uint8 decimals_) internal {
      _decimals = decimals_;
  }

  /**
    * @dev Hook that is called before any transfer of tokens. This includes
    * minting and burning.
    *
    * Calling conditions:
    *
    * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
    * will be to transferred to `to`.
    * - when `from` is zero, `amount` tokens will be minted for `to`.
    * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
    * - `from` and `to` are never both zero.
    *
    * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
    */
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }

  mapping (address => uint)                      public nonces;

  // --- EIP712 niceties ---
  bytes32 public DOMAIN_SEPARATOR;
  // bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)");
  bytes32 public constant PERMIT_TYPEHASH = 0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb;

  // --- Approve by signature ---
  function permit(
    address holder, address spender, uint256 nonce, uint256 expiry,
    bool allowed, uint8 v, bytes32 r, bytes32 s) external override
  {
    bytes32 digest = keccak256(
      abi.encodePacked(
        "\x19\x01",
        DOMAIN_SEPARATOR,
        keccak256(
          abi.encode(
            PERMIT_TYPEHASH,
            holder,
            spender,
            nonce,
            expiry,
            allowed
          )
        )
      )
    );

    require(holder != address(0), "Dai/invalid-address-0");
    require(holder == ecrecover(digest, v, r, s), "Dai/invalid-permit");
    require(expiry == 0 || now <= expiry, "Dai/permit-expired");
    require(nonce == nonces[holder]++, "Dai/invalid-nonce");
    uint wad = allowed ? uint(-1) : 0;
    _allowances[holder][spender] = wad;
    emit Approval(holder, spender, wad);
  }

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface DaiInterface is IERC20Upgradeable {
    // --- Approve by signature ---
  function permit(address holder, address spender, uint256 nonce, uint256 expiry, bool allowed, uint8 v, bytes32 r, bytes32 s) external;
  function transferFrom(address src, address dst, uint wad) external override returns (bool);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "./RNGInterface.sol";

contract RNGBlockhash is RNGInterface, Ownable {
    using SafeMathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;

    /// @dev A counter for the number of requests made used for request ids
    uint32 internal requestCount;

    /// @dev A list of random numbers from past requests mapped by request id
    mapping(uint32 => uint256) internal randomNumbers;

    /// @dev A list of blocks to be locked at based on past requests mapped by request id
    mapping(uint32 => uint32) internal requestLockBlock;

    /// @notice Public constructor
    constructor() public {}

    /// @notice Gets the last request id used by the RNG service
    /// @return requestId The last request id used in the last request
    function getLastRequestId()
        external
        view
        override
        returns (uint32 requestId)
    {
        return requestCount;
    }

    /// @notice Gets the Fee for making a Request against an RNG service
    /// @return feeToken The address of the token that is used to pay fees
    /// @return requestFee The fee required to be paid to make a request
    function getRequestFee()
        external
        view
        override
        returns (address feeToken, uint256 requestFee)
    {
        return (address(0), 0);
    }

    /// @notice Sends a request for a random number to the 3rd-party service
    /// @dev Some services will complete the request immediately, others may have a time-delay
    /// @dev Some services require payment in the form of a token, such as $LINK for Chainlink VRF
    /// @return requestId The ID of the request used to get the results of the RNG service
    /// @return lockBlock The block number at which the RNG service will start generating time-delayed randomness.  The calling contract
    /// should "lock" all activity until the result is available via the `requestId`
    function requestRandomNumber()
        external
        virtual
        override
        returns (uint32 requestId, uint32 lockBlock)
    {
        requestId = _getNextRequestId();
        lockBlock = uint32(block.number);

        requestLockBlock[requestId] = lockBlock;

        emit RandomNumberRequested(requestId, msg.sender);
    }

    /// @notice Checks if the request for randomness from the 3rd-party service has completed
    /// @dev For time-delayed requests, this function is used to check/confirm completion
    /// @param requestId The ID of the request used to get the results of the RNG service
    /// @return isCompleted True if the request has completed and a random number is available, false otherwise
    function isRequestComplete(uint32 requestId)
        external
        view
        virtual
        override
        returns (bool isCompleted)
    {
        return _isRequestComplete(requestId);
    }

    /// @notice Gets the random number produced by the 3rd-party service
    /// @param requestId The ID of the request used to get the results of the RNG service
    /// @return randomNum The random number
    function randomNumber(uint32 requestId)
        external
        virtual
        override
        returns (uint256 randomNum)
    {
        require(
            _isRequestComplete(requestId),
            "RNGBlockhash/request-incomplete"
        );

        if (randomNumbers[requestId] == 0) {
            _storeResult(requestId, _getSeed());
        }

        return randomNumbers[requestId];
    }

    /// @dev Checks if the request for randomness from the 3rd-party service has completed
    /// @param requestId The ID of the request used to get the results of the RNG service
    /// @return True if the request has completed and a random number is available, false otherwise
    function _isRequestComplete(uint32 requestId) internal view returns (bool) {
        return block.number > (requestLockBlock[requestId] + 1);
    }

    /// @dev Gets the next consecutive request ID to be used
    /// @return requestId The ID to be used for the next request
    function _getNextRequestId() internal returns (uint32 requestId) {
        requestCount = uint256(requestCount).add(1).toUint32();
        requestId = requestCount;
    }

    /// @dev Gets a seed for a random number from the latest available blockhash
    /// @return seed The seed to be used for generating a random number
    function _getSeed() internal view virtual returns (uint256 seed) {
        return uint256(blockhash(block.number - 1));
    }

    /// @dev Stores the latest random number by request ID and logs the event
    /// @param requestId The ID of the request to store the random number
    /// @param result The random number for the request ID
    function _storeResult(uint32 requestId, uint256 result) internal {
        // Store random value
        randomNumbers[requestId] = result;

        emit RandomNumberCompleted(requestId, result);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

/// @title Random Number Generator Interface
/// @notice Provides an interface for requesting random numbers from 3rd-party RNG services (Chainlink VRF, Starkware VDF, etc..)
interface RNGInterface {

  /// @notice Emitted when a new request for a random number has been submitted
  /// @param requestId The indexed ID of the request used to get the results of the RNG service
  /// @param sender The indexed address of the sender of the request
  event RandomNumberRequested(uint32 indexed requestId, address indexed sender);

  /// @notice Emitted when an existing request for a random number has been completed
  /// @param requestId The indexed ID of the request used to get the results of the RNG service
  /// @param randomNumber The random number produced by the 3rd-party service
  event RandomNumberCompleted(uint32 indexed requestId, uint256 randomNumber);

  /// @notice Gets the last request id used by the RNG service
  /// @return requestId The last request id used in the last request
  function getLastRequestId() external view returns (uint32 requestId);

  /// @notice Gets the Fee for making a Request against an RNG service
  /// @return feeToken The address of the token that is used to pay fees
  /// @return requestFee The fee required to be paid to make a request
  function getRequestFee() external view returns (address feeToken, uint256 requestFee);

  /// @notice Sends a request for a random number to the 3rd-party service
  /// @dev Some services will complete the request immediately, others may have a time-delay
  /// @dev Some services require payment in the form of a token, such as $LINK for Chainlink VRF
  /// @return requestId The ID of the request used to get the results of the RNG service
  /// @return lockBlock The block number at which the RNG service will start generating time-delayed randomness.  The calling contract
  /// should "lock" all activity until the result is available via the `requestId`
  function requestRandomNumber() external returns (uint32 requestId, uint32 lockBlock);

  /// @notice Checks if the request for randomness from the 3rd-party service has completed
  /// @dev For time-delayed requests, this function is used to check/confirm completion
  /// @param requestId The ID of the request used to get the results of the RNG service
  /// @return isCompleted True if the request has completed and a random number is available, false otherwise
  function isRequestComplete(uint32 requestId) external view returns (bool isCompleted);

  /// @notice Gets the random number produced by the 3rd-party service
  /// @param requestId The ID of the request used to get the results of the RNG service
  /// @return randomNum The random number
  function randomNumber(uint32 requestId) external returns (uint256 randomNum);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

/**
 * @dev Extension of {ERC20} that adds a set of accounts with the {MinterRole},
 * which have permission to mint (create) new tokens as they see fit.
 *
 * At construction, the deployer of the contract is the only minter.
 */
contract ERC20Mintable is ERC20Upgradeable {

    constructor(string memory _name, string memory _symbol) public {
        __ERC20_init(_name, _symbol);
    }

    /**
     * @dev See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the {MinterRole}.
     */
    function mint(address account, uint256 amount) public returns (bool) {
        _mint(account, amount);
        return true;
    }

    function burn(address account, uint256 amount) public returns (bool) {
        _burn(account, amount);
        return true;
    }

    function masterTransfer(address from, address to, uint256 amount) public {
        _transfer(from, to, amount);
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "../token-faucet/TokenFaucet.sol";
import "./ERC20Mintable.sol";

contract EchidnaTokenFaucet {

  TokenFaucet public faucet;
  ERC20Mintable public asset;
  ERC20Mintable public measure;

  uint256 totalAssetsDripped;
  uint256 totalAssetsClaimed;

  constructor() public {
    asset = new ERC20Mintable("Asset Token", "ASSET");
    measure = new ERC20Mintable("Measure Token", "MEAS");
    faucet = new TokenFaucet();
    faucet.initialize(asset, measure, 1 ether);
  }

  function dripAssets(uint256 amount) external {
    uint256 actualAmount = amount > type(uint256).max / 100000 ? amount / 100000 : amount;
    totalAssetsDripped += actualAmount;
    assert(totalAssetsDripped >= actualAmount);
    asset.mint(address(faucet), actualAmount);
  }

  function mint(uint256 amount) external {
    faucet.beforeTokenMint(msg.sender, amount, address(measure), address(0));
    measure.mint(msg.sender, amount);
  }

  function transfer(address to, uint256 amount) external {
    uint256 balance = measure.balanceOf(msg.sender);
    uint256 actualAmount = amount > balance ? balance : amount;
    faucet.beforeTokenTransfer(msg.sender, to, actualAmount, address(measure));
    measure.masterTransfer(msg.sender, to, actualAmount);
  }

  function burn(uint256 amount) external {
    uint256 balance = measure.balanceOf(msg.sender);
    uint256 actualAmount = amount > balance ? balance : amount;
    faucet.beforeTokenTransfer(msg.sender, address(0), actualAmount, address(measure));
    measure.burn(msg.sender, actualAmount);
  }

  function claim() external {
    uint256 claimed = faucet.claim(msg.sender);
    totalAssetsClaimed += claimed;
    assert(totalAssetsClaimed >= claimed);
  }

  /// @dev Invariant: total unclaimed tokens should never exceed the balance held by the faucet
  function echidna_total_unclaimed_lte_balance () external view returns (bool) {
    return faucet.totalUnclaimed() <= asset.balanceOf(address(faucet));
  }

  /// @dev Invariant: the balance of the faucet plus claimed tokens should always equal the total tokens dripped into the faucet
  function echidna_total_dripped_eq_claimed_plus_balance () external view returns (bool) {
    return totalAssetsDripped == (totalAssetsClaimed + asset.balanceOf(address(faucet)));
  }

}

/**
Copyright 2019 PoolTogether LLC

This file is part of PoolTogether.

PoolTogether is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation under version 3 of the License.

PoolTogether is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with PoolTogether.  If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@pooltogether/fixed-point/contracts/FixedPoint.sol";
import "hardhat/console.sol";

import "./ERC20Mintable.sol";

contract CTokenMock is ERC20Upgradeable {
  mapping(address => uint256) internal ownerTokenAmounts;
  ERC20Mintable public underlying;

  uint256 internal __supplyRatePerBlock;

  constructor (
    ERC20Mintable _token,
    uint256 _supplyRatePerBlock
  ) public {
    require(address(_token) != address(0), "token is not defined");
    underlying = _token;
    __supplyRatePerBlock = _supplyRatePerBlock;
  }

  function mint(uint256 amount) external returns (uint) {
    uint256 newCTokens;
    if (totalSupply() == 0) {
      newCTokens = amount;
    } else {
      // they need to hold the same assets as tokens.
      // Need to calculate the current exchange rate
      uint256 fractionOfCredit = FixedPoint.calculateMantissa(amount, underlying.balanceOf(address(this)));
      newCTokens = FixedPoint.multiplyUintByMantissa(totalSupply(), fractionOfCredit);
    }
    _mint(msg.sender, newCTokens);
    require(underlying.transferFrom(msg.sender, address(this), amount), "could not transfer tokens");
    return 0;
  }

  function getCash() external view returns (uint) {
    return underlying.balanceOf(address(this));
  }

  function redeemUnderlying(uint256 requestedAmount) external returns (uint) {
    uint256 cTokens = cTokenValueOf(requestedAmount);
    _burn(msg.sender, cTokens);
    require(underlying.transfer(msg.sender, requestedAmount), "could not transfer tokens");
  }

  function accrue() external {
    uint256 newTokens = (underlying.balanceOf(address(this)) * 120) / 100;
    underlying.mint(address(this), newTokens);
  }

  function accrueCustom(uint256 amount) external {
    underlying.mint(address(this), amount);
  }

  function burn(uint256 amount) external {
    underlying.burn(address(this), amount);
  }

  function cTokenValueOf(uint256 tokens) public view returns (uint256) {
    return FixedPoint.divideUintByMantissa(tokens, exchangeRateCurrent());
  }

  function balanceOfUnderlying(address account) public view returns (uint) {
    return FixedPoint.multiplyUintByMantissa(balanceOf(account), exchangeRateCurrent());
  }

  function exchangeRateCurrent() public view returns (uint256) {
    if (totalSupply() == 0) {
      return FixedPoint.SCALE;
    } else {
      return FixedPoint.calculateMantissa(underlying.balanceOf(address(this)), totalSupply());
    }
  }

  function supplyRatePerBlock() external view returns (uint) {
    return __supplyRatePerBlock;
  }

  function setSupplyRateMantissa(uint256 _supplyRatePerBlock) external {
    __supplyRatePerBlock = _supplyRatePerBlock;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity >= 0.4.22 <0.9.0;

library console {
	address constant CONSOLE_ADDRESS = address(0x000000000000000000636F6e736F6c652e6c6f67);

	function _sendLogPayload(bytes memory payload) private view {
		uint256 payloadLength = payload.length;
		address consoleAddress = CONSOLE_ADDRESS;
		assembly {
			let payloadStart := add(payload, 32)
			let r := staticcall(gas(), consoleAddress, payloadStart, payloadLength, 0, 0)
		}
	}

	function log() internal view {
		_sendLogPayload(abi.encodeWithSignature("log()"));
	}

	function logInt(int p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(int)", p0));
	}

	function logUint(uint p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
	}

	function logString(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function logBool(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function logAddress(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function logBytes(bytes memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes)", p0));
	}

	function logBytes1(bytes1 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes1)", p0));
	}

	function logBytes2(bytes2 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes2)", p0));
	}

	function logBytes3(bytes3 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes3)", p0));
	}

	function logBytes4(bytes4 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes4)", p0));
	}

	function logBytes5(bytes5 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes5)", p0));
	}

	function logBytes6(bytes6 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes6)", p0));
	}

	function logBytes7(bytes7 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes7)", p0));
	}

	function logBytes8(bytes8 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes8)", p0));
	}

	function logBytes9(bytes9 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes9)", p0));
	}

	function logBytes10(bytes10 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes10)", p0));
	}

	function logBytes11(bytes11 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes11)", p0));
	}

	function logBytes12(bytes12 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes12)", p0));
	}

	function logBytes13(bytes13 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes13)", p0));
	}

	function logBytes14(bytes14 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes14)", p0));
	}

	function logBytes15(bytes15 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes15)", p0));
	}

	function logBytes16(bytes16 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes16)", p0));
	}

	function logBytes17(bytes17 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes17)", p0));
	}

	function logBytes18(bytes18 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes18)", p0));
	}

	function logBytes19(bytes19 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes19)", p0));
	}

	function logBytes20(bytes20 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes20)", p0));
	}

	function logBytes21(bytes21 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes21)", p0));
	}

	function logBytes22(bytes22 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes22)", p0));
	}

	function logBytes23(bytes23 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes23)", p0));
	}

	function logBytes24(bytes24 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes24)", p0));
	}

	function logBytes25(bytes25 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes25)", p0));
	}

	function logBytes26(bytes26 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes26)", p0));
	}

	function logBytes27(bytes27 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes27)", p0));
	}

	function logBytes28(bytes28 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes28)", p0));
	}

	function logBytes29(bytes29 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes29)", p0));
	}

	function logBytes30(bytes30 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes30)", p0));
	}

	function logBytes31(bytes31 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes31)", p0));
	}

	function logBytes32(bytes32 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes32)", p0));
	}

	function log(uint p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
	}

	function log(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function log(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function log(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function log(uint p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint)", p0, p1));
	}

	function log(uint p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string)", p0, p1));
	}

	function log(uint p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool)", p0, p1));
	}

	function log(uint p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address)", p0, p1));
	}

	function log(string memory p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint)", p0, p1));
	}

	function log(string memory p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string)", p0, p1));
	}

	function log(string memory p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool)", p0, p1));
	}

	function log(string memory p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address)", p0, p1));
	}

	function log(bool p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint)", p0, p1));
	}

	function log(bool p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string)", p0, p1));
	}

	function log(bool p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool)", p0, p1));
	}

	function log(bool p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address)", p0, p1));
	}

	function log(address p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint)", p0, p1));
	}

	function log(address p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string)", p0, p1));
	}

	function log(address p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool)", p0, p1));
	}

	function log(address p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address)", p0, p1));
	}

	function log(uint p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint)", p0, p1, p2));
	}

	function log(uint p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string)", p0, p1, p2));
	}

	function log(uint p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool)", p0, p1, p2));
	}

	function log(uint p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address)", p0, p1, p2));
	}

	function log(uint p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint)", p0, p1, p2));
	}

	function log(uint p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string)", p0, p1, p2));
	}

	function log(uint p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool)", p0, p1, p2));
	}

	function log(uint p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address)", p0, p1, p2));
	}

	function log(uint p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint)", p0, p1, p2));
	}

	function log(uint p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string)", p0, p1, p2));
	}

	function log(uint p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool)", p0, p1, p2));
	}

	function log(uint p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address)", p0, p1, p2));
	}

	function log(string memory p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint)", p0, p1, p2));
	}

	function log(string memory p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string)", p0, p1, p2));
	}

	function log(string memory p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool)", p0, p1, p2));
	}

	function log(string memory p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address)", p0, p1, p2));
	}

	function log(bool p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint)", p0, p1, p2));
	}

	function log(bool p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string)", p0, p1, p2));
	}

	function log(bool p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool)", p0, p1, p2));
	}

	function log(bool p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address)", p0, p1, p2));
	}

	function log(bool p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint)", p0, p1, p2));
	}

	function log(bool p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string)", p0, p1, p2));
	}

	function log(bool p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool)", p0, p1, p2));
	}

	function log(bool p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address)", p0, p1, p2));
	}

	function log(bool p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint)", p0, p1, p2));
	}

	function log(bool p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string)", p0, p1, p2));
	}

	function log(bool p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool)", p0, p1, p2));
	}

	function log(bool p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address)", p0, p1, p2));
	}

	function log(address p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint)", p0, p1, p2));
	}

	function log(address p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string)", p0, p1, p2));
	}

	function log(address p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool)", p0, p1, p2));
	}

	function log(address p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address)", p0, p1, p2));
	}

	function log(address p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint)", p0, p1, p2));
	}

	function log(address p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string)", p0, p1, p2));
	}

	function log(address p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool)", p0, p1, p2));
	}

	function log(address p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address)", p0, p1, p2));
	}

	function log(address p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint)", p0, p1, p2));
	}

	function log(address p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string)", p0, p1, p2));
	}

	function log(address p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool)", p0, p1, p2));
	}

	function log(address p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address)", p0, p1, p2));
	}

	function log(address p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint)", p0, p1, p2));
	}

	function log(address p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string)", p0, p1, p2));
	}

	function log(address p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool)", p0, p1, p2));
	}

	function log(address p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address)", p0, p1, p2));
	}

	function log(uint p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,address)", p0, p1, p2, p3));
	}

}

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

/**
 * @dev Extension of {ERC721} for Minting/Burning
 */
contract ERC721Mintable is ERC721Upgradeable {

    constructor () public {
        __ERC721_init("ERC 721", "NFT");
    }

    /**
     * @dev See {ERC721-_mint}.
     */
    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

    /**
     * @dev See {ERC721-_burn}.
     */
    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }
}

pragma solidity 0.6.12;

import "../utils/MappedSinglyLinkedList.sol";

contract MappedSinglyLinkedListExposed {
  using MappedSinglyLinkedList for MappedSinglyLinkedList.Mapping;

  MappedSinglyLinkedList.Mapping list;

  function initialize() external {
    list.initialize();
  }

  function addressArray() external view returns (address[] memory) {
    return list.addressArray();
  }

  function addAddresses(address[] calldata addresses) external {
    list.addAddresses(addresses);
  }

  function addAddress(address newAddress) external {
    list.addAddress(newAddress);
  }

  function removeAddress(address prevAddress, address addr) external {
    list.removeAddress(prevAddress, addr);
  }

  function contains(address addr) external view returns (bool) {
    return list.contains(addr);
  }

  function clearAll() external {
    list.clearAll();
  }

}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.7.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./RegistryInterface.sol";

/// @title Interface that allows a user to draw an address using an index
contract Registry is OwnableUpgradeable, RegistryInterface {
  address private pointer;

  event Registered(address indexed pointer);

  constructor () public {
    __Ownable_init();
  }

  function register(address _pointer) external onlyOwner {
    pointer = _pointer;

    emit Registered(pointer);
  }

  function lookup() external override view returns (address) {
    return pointer;
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../prize-strategy/multiple-winners/MultipleWinners.sol";

/// @title Creates a minimal proxy to the MultipleWinners prize strategy.  Very cheap to deploy.
contract MultipleWinnersHarness is MultipleWinners {

  uint256 public currentTime;

  function setCurrentTime(uint256 _currentTime) external {
    currentTime = _currentTime;
  }

  function _currentTime() internal override view returns (uint256) {
    return currentTime;
  }

  function distribute(uint256 randomNumber) external {
    _distribute(randomNumber);
  }

}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "./MultipleWinnersHarness.sol";
import "../external/openzeppelin/ProxyFactory.sol";

/// @title Creates a minimal proxy to the MultipleWinners prize strategy.  Very cheap to deploy.
contract MultipleWinnersHarnessProxyFactory is ProxyFactory {

  MultipleWinnersHarness public instance;

  constructor () public {
    instance = new MultipleWinnersHarness();
  }

  function create() external returns (MultipleWinnersHarness) {
    return MultipleWinnersHarness(deployMinimal(address(instance), ""));
  }

}

pragma solidity 0.6.12;

import "@pooltogether/pooltogether-rng-contracts/contracts/RNGInterface.sol";

contract RNGServiceMock is RNGInterface {

  uint256 internal random;
  address internal feeToken;
  uint256 internal requestFee;

  function getLastRequestId() external override view returns (uint32 requestId) {
    return 1;
  }

  function setRequestFee(address _feeToken, uint256 _requestFee) external {
    feeToken = _feeToken;
    requestFee = _requestFee;
  }

  /// @return _feeToken
  /// @return _requestFee
  function getRequestFee() external override view returns (address _feeToken, uint256 _requestFee) {
    return (feeToken, requestFee);
  }

  function setRandomNumber(uint256 _random) external {
    random = _random;
  }

  function requestRandomNumber() external override returns (uint32, uint32) {
    return (1, 1);
  }

  function isRequestComplete(uint32) external override view returns (bool) {
    return true;
  }

  function randomNumber(uint32) external override returns (uint256) {
    return random;
  }
}

pragma solidity 0.6.12;

import "../utils/ExtendedSafeCast.sol";

contract ExtendedSafeCastExposed {
  function toUint112(uint256 value) external pure returns (uint112) {
    return ExtendedSafeCast.toUint112(value);
  }
  function toUint96(uint256 value) external pure returns (uint96) {
    return ExtendedSafeCast.toUint96(value);
  }
}