/*
     ,-""""-.
   ,'      _ `.
  /       )_)  \
 :              :
 \              /
  \            /
   `.        ,'
     `.    ,'
       `.,'
        /\`.   ,-._
            `-'         Banksy.farm

 */

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


/*
  TABLE ERROR REFERENCE:
  ERR1: The sender is on the blacklist. Please contact to support.
  ERR2: The recipient is on the blacklist. Please contact to support.
  ERR3: User cannot send more than allowed.
  ERR4: User is not operator.
  ERR5: User is excluded from antibot system.
  ERR6: Bot address is already on the blacklist.
  ERR7: The expiration time has to be greater than 0.
  ERR8: Bot address is not found on the blacklist.
  ERR9: Address cant be 0.
*/

// BanksyToken
contract BanksyTokenV3 is ERC20, Ownable {

    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);
    event TransferTaxRateUpdated(address indexed operator, uint256 previousRate, uint256 newRate);
    event HoldingAmountRateUpdated(address indexed operator, uint256 previousRate, uint256 newRate);
    event AntiBotWorkingStatus(address indexed operator, bool previousStatus, bool newStatus);
    event AddBotAddress(address indexed botAddress);
    event RemoveBotAddress(address indexed botAddress);
    event ExcludedOperatorsUpdated(address indexed operatorAddress, bool previousStatus, bool newStatus);
    event ExcludedHoldersUpdated(address indexed holderAddress, bool previousStatus, bool newStatus);
    

    using SafeMath for uint256;

    ///@dev Max transfer amount rate. (default is 3% of total supply)
    uint16 public maxUserTransferAmountRate = 300;
    
    ///@dev Max holding rate. (default is 9% of total supply)
    uint16 public maxUserHoldAmountRate = 900;

    ///@dev Length of blacklist addressess
    uint256 public blacklistLength;
 
    ///@dev Enable|Disable antiBot
    bool public antiBotWorking;
    
    ///@dev Exclude operators from antiBot system
    mapping(address => bool) private _excludedOperatorsFromAntiBot;

    ///@dev Exclude holders from antiBot system
    mapping(address => bool) private _excludedHoldersFromAntiBot;

    ///@dev mapping store blacklist. address=>ExpirationTime 
    mapping(address => uint256) private _blacklist;
    

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    
    // operator role
    address internal _operator;

    // MODIFIERS
    modifier antiBot(address _sender, address _recipient, uint256 _amount) { 
        //check blacklist
        require(!_blacklistCheck(_sender), "ERR1");
        require(!_blacklistCheck(_recipient), "ERR2");

        // This code will be disabled after launch and before farming
        if (antiBotWorking){
            // check  if sender|recipient has a tx amount is within the allowed limits
            if (_isNotOperatorExcludedFromAntiBot(_sender)){
                if(_isNotOperatorExcludedFromAntiBot(_recipient))
                    require(_amount <= _maxUserTransferAmount(), "ERR3");
            }
        }
        _;
    }

    modifier onlyOperator() {
        require(_operator == _msgSender(), "ERR4");
        _;
    }
    
    constructor() 
        ERC20('BANKSY', 'BANKSY')
    {
      // Exclude operator addresses, lps, etc from antibot system
        _excludedOperatorsFromAntiBot[msg.sender] = true;
        _excludedOperatorsFromAntiBot[address(0)] = true;
        _excludedOperatorsFromAntiBot[address(this)] = true;
        _excludedOperatorsFromAntiBot[BURN_ADDRESS] = true;

        _operator = _msgSender();
    }
    

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
    
    //INTERNALS
    
    /// @dev overrides transfer function to use antibot system
    function _transfer(address _sender, address _recipient, uint256 _amount) internal virtual override antiBot(_sender, _recipient, _amount) {
        // Autodetect is sender is a BOT
        // This code will be disabled after launch and before farming
        if (antiBotWorking){
            // check  if sender|recipient has a tx amount is within the allowed limits
            if (_isNotHolderExcludedFromAntiBot(_sender)){
                if(_isNotOperatorExcludedFromAntiBot(_sender)){
                    if (balanceOf(_sender) > _maxUserHoldAmount()) {
                        _addBotAddressToBlackList(_sender, type(uint256).max);
                        return;
                    }
                }
            }
        }
        
        super._transfer(_sender, _recipient, _amount);
    }

    /// @dev internal function to add address to blacklist.
    function _addBotAddressToBlackList(address _botAddress, uint256 _expirationTime) internal {
        require(_isNotHolderExcludedFromAntiBot(_botAddress), "ERR5");
        require(_isNotOperatorExcludedFromAntiBot(_botAddress), "ERR5");
        require(_blacklist[_botAddress] == 0, "ERR6");
        require(_expirationTime > 0, "ERR7");

        _blacklist[_botAddress] = _expirationTime;
        blacklistLength = blacklistLength.add(1);

        emit AddBotAddress(_botAddress);
    }
    
    ///@dev internal function to remove address from blacklist.
    function _removeBotAddressToBlackList(address _botAddress) internal {
        require(_blacklist[_botAddress] > 0, "ERR8");

        delete _blacklist[_botAddress];
        blacklistLength = blacklistLength.sub(1);

        emit RemoveBotAddress(_botAddress);
    }

    ///@dev Check if the address is excluded from antibot system.
    function _isNotHolderExcludedFromAntiBot(address _userAddress) internal view returns(bool) {
        return(!_excludedHoldersFromAntiBot[_userAddress]);
    }

    ///@dev Check if the address is excluded from antibot system.
    function _isNotOperatorExcludedFromAntiBot(address _userAddress) internal view returns(bool) {
        return(!_excludedOperatorsFromAntiBot[_userAddress]);
    }

    ///@dev Max user transfer allowed
    function _maxUserTransferAmount() internal view returns (uint256) {
        return totalSupply().mul(maxUserTransferAmountRate).div(10000);
    }

    ///@dev Max user Holding allowed
    function _maxUserHoldAmount() internal view returns (uint256) {
        return totalSupply().mul(maxUserHoldAmountRate).div(10000);
    }

    ///@dev check if the address is in the blacklist or expired
    function _blacklistCheck(address _botAddress) internal view returns(bool) {
        if(_blacklist[_botAddress] > 0)
            return _blacklist[_botAddress] > block.timestamp;
        else 
            return false;
    }

    // PUBLICS
 
    ///@dev Max user transfer allowed
    function maxUserTransferAmount() external view returns (uint256) {
        return _maxUserTransferAmount();
    }

    ///@dev Max user Holding allowed
    function maxUserHoldAmount() external view returns (uint256) {
        return _maxUserHoldAmount();
    }

     ///@dev check if the address is in the blacklist or expired
    function blacklistCheck(address _botAddress) external view returns(bool) {
        return _blacklistCheck(_botAddress);     
    }
    
    ///@dev check if the address is in the blacklist or not
    function blacklistCheckExpirationTime(address _botAddress) external view returns(uint256){
        return _blacklist[_botAddress];
    }


    // EXTERNALS

    ///@dev Update operator address status
    function updateOperatorsFromAntiBot(address _operatorAddress, bool _status) external onlyOwner {
        require(_operatorAddress != address(0), "ERR9");

        emit ExcludedOperatorsUpdated(_operatorAddress, _excludedOperatorsFromAntiBot[_operatorAddress], _status);

        _excludedOperatorsFromAntiBot[_operatorAddress] = _status;
    }

    ///@dev Update operator address status
    function updateHoldersFromAntiBot(address _holderAddress, bool _status) external onlyOwner {
        require(_holderAddress != address(0), "ERR9");

        emit ExcludedHoldersUpdated(_holderAddress, _excludedHoldersFromAntiBot[_holderAddress], _status);

        _excludedHoldersFromAntiBot[_holderAddress] = _status;
    }


    ///@dev Update operator address
    function transferOperator(address newOperator) external onlyOperator {
        require(newOperator != address(0), "ERR9");
        
        emit OperatorTransferred(_operator, newOperator);

        _operator = newOperator;
    }

    function operator() external view returns (address) {
        return _operator;
    }

     ///@dev Updates the max holding amount. 
    function updateMaxUserHoldAmountRate(uint16 _maxUserHoldAmountRate) external onlyOwner {
        require(_maxUserHoldAmountRate >= 500);
        require(_maxUserHoldAmountRate <= 10000);
        
        emit TransferTaxRateUpdated(_msgSender(), maxUserHoldAmountRate, _maxUserHoldAmountRate);

        maxUserHoldAmountRate = _maxUserHoldAmountRate;
    }

    ///@dev Updates the max user transfer amount. 
    function updateMaxUserTransferAmountRate(uint16 _maxUserTransferAmountRate) external onlyOwner {
        require(_maxUserTransferAmountRate >= 50);
        require(_maxUserTransferAmountRate <= 10000);
        
        emit HoldingAmountRateUpdated(_msgSender(), maxUserHoldAmountRate, _maxUserTransferAmountRate);

        maxUserTransferAmountRate = _maxUserTransferAmountRate;
    }

    
    ///@dev Update the antiBotWorking status: ENABLE|DISABLE.
    function updateStatusAntiBotWorking(bool _status) external onlyOwner {
        emit AntiBotWorkingStatus(_msgSender(), antiBotWorking, _status);

        antiBotWorking = _status;
    }

     ///@dev Add an address to the blacklist. Only the owner can add. Owner is the address of the Governance contract.
    function addBotAddress(address _botAddress, uint256 _expirationTime) external onlyOwner {
        _addBotAddressToBlackList(_botAddress, _expirationTime);
    }
    
    ///@dev Remove an address from the blacklist. Only the owner can remove. Owner is the address of the Governance contract.
    function removeBotAddress(address botAddress) external onlyOperator {
        _removeBotAddressToBlackList(botAddress);
    }
    
    ///@dev Add multi address to the blacklist. Only the owner can add. Owner is the address of the Governance contract.
    function addBotAddressBatch(address[] memory _addresses, uint256 _expirationTime) external onlyOwner {
        require(_addresses.length > 0);

        for(uint i=0;i<_addresses.length;i++){
            _addBotAddressToBlackList(_addresses[i], _expirationTime);
        }
    }
    
    ///@dev Remove multi address from the blacklist. Only the owner can remove. Owner is the address of the Governance contract.
    function removeBotAddressBatch(address[] memory _addresses) external onlyOperator {
        require(_addresses.length > 0);

        for(uint i=0;i<_addresses.length;i++){
            _removeBotAddressToBlackList(_addresses[i]);
        }
    }

    ///@dev Check if the address is excluded from antibot system.
    function isExcludedOperatorFromAntiBot(address _userAddress) external view returns(bool) {
        return(_excludedOperatorsFromAntiBot[_userAddress]);
    }

    ///@dev Check if the address is excluded from antibot system.
    function isExcludedHolderFromAntiBot(address _userAddress) external view returns(bool) {
        return(_excludedHoldersFromAntiBot[_userAddress]);
    }
}

// SPDX-License-Identifier: MIT

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
        _setOwner(_msgSender());
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
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is no longer needed starting with Solidity 0.8. The compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
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
        return a + b;
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
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
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
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
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
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
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
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT

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
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
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
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
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
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
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
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
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

pragma solidity ^0.8.0;

/*
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

pragma solidity ^0.8.0;

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
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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