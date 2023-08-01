// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./NVXToken.sol";

contract PresaleSeed is Ownable {
    // Deposit Tokens
    IERC20 public usdc; // 0x1B6382DBDEa11d97f24495C9A90b7c88469134a4 : AXLUSDC
    IERC20 public nvxToken;

    // Claiming is enabled
    bool isClaimOpen = false;
    bool investOpen = true;

    uint256 public rate = 4000; // 0.00025 dollars
    uint256 public investmentAmount = 0;
    uint256 public VEST_START_TIMESTAMP;
    uint256 public totalInvestment = 3500;
    address[] private eligibleWallets;

    struct Vest {
        uint256 totalDue;
        uint256 vestPeriodsClaimed;
        bool withDrawnEarly;
    }

    mapping(address => Vest) public vests;

    constructor(
        address _usdc,
        address _nvxToken,
        address[] memory _eligibleSeeds
    ) {
        usdc = IERC20(_usdc);
        nvxToken = NVXToken(_nvxToken);
        eligibleWallets = _eligibleSeeds;
    }

    modifier onlySeed() {
        bool isSeed = false;
        for (uint256 i = 0; i < eligibleWallets.length; i++) {
            if (eligibleWallets[i] == msg.sender) {
                isSeed = true;
                break;
            }
        }
        require(isSeed == true, "User not eligible");
        _;
    }

    function setClaimEnabled(bool status) external onlyOwner {
        isClaimOpen = status;
    }

    function setInvestOpen(bool status) external onlyOwner {
        investOpen = status;
    }

    function manuallyAddInvestment(address investor, uint256 amount)
        public
        onlyOwner
    {
        uint256 tokensPurchased = (amount * 1e6) * rate * 1e12;
        if (vests[investor].totalDue > 0) {
            tokensPurchased += vests[investor].totalDue;
        }
        vests[investor].totalDue = tokensPurchased;
        totalInvestment += amount;
    }

    function updateVestStart(uint256 timestamp) external onlyOwner {
        if (timestamp == 0) {
            VEST_START_TIMESTAMP = block.timestamp;
        } else {
            VEST_START_TIMESTAMP = timestamp;
        }
    }

    function addEligibleWallet(address wallet) public onlyOwner {
        // Wallet has already been added
        bool walletAdded = false;
        for (uint256 i = 0; i < eligibleWallets.length; i++) {
            if (eligibleWallets[i] == wallet) {
                walletAdded = true;
                break;
            }
        }

        require(
            walletAdded == false,
            "Cannot add wallet which is already eligible"
        );

        eligibleWallets.push(wallet);
    }

    function removeEligibleWallet(address wallet) external onlyOwner {
        for (uint256 i = 0; i < eligibleWallets.length; i++) {
            if (eligibleWallets[i] == wallet) {
                // Move the last element to the position of the element to remove
                eligibleWallets[i] = eligibleWallets[
                    eligibleWallets.length - 1
                ];
                // Remove the last element
                eligibleWallets.pop();
                return;
            }
        }
        revert("Wallet not found");
    }

    function getMyVestInfo(address a) public view returns (Vest memory) {
        return vests[a];
    }

    function invest(uint256 amount) external onlySeed {
        require(investOpen == true, "Investing is now closed.");
        uint256 amountInMicroUSDC = amount * 1e6;
        require(
            usdc.balanceOf(msg.sender) >= amountInMicroUSDC,
            "Not enough USDC in wallet"
        );
        require(
            vests[msg.sender].withDrawnEarly == false,
            "Vest already withdrawn"
        );
        uint256 tokensPurchased = amountInMicroUSDC * rate * 1e12;
        if (vests[msg.sender].totalDue > 0) {
            tokensPurchased += vests[msg.sender].totalDue;
        }
        vests[msg.sender].totalDue = tokensPurchased;
        investmentAmount += amount;
        totalInvestment += amount;

        usdc.transferFrom(msg.sender, address(this), amountInMicroUSDC);
    }

    // Can withdraw early but will lose 70% of NVX tokens
    function withdrawEarly() external onlySeed {
        require(isClaimOpen == true, "Claiming paused.");
        require(
            vests[msg.sender].withDrawnEarly == false,
            "Vest already withdrawn"
        );
        uint256 claimPeriodsPassedSinceOpen = (block.timestamp -
            VEST_START_TIMESTAMP) / 28 days;
        require(
            claimPeriodsPassedSinceOpen < 6,
            "Early withdrawal now closed."
        );
        claimTokens();
        uint256 claimableMonths = 9 - vests[msg.sender].vestPeriodsClaimed;
        uint256 amountToWithdraw = ((vests[msg.sender].totalDue /
            claimableMonths) * 30) / 100;

        // Should this not set their amountRemianing to 0?
        vests[msg.sender].withDrawnEarly = true;
        vests[msg.sender].totalDue = 0;

        nvxToken.transfer(msg.sender, amountToWithdraw);
    }

    function claimTokens() public onlySeed {
        require(isClaimOpen == true, "Claiming paused.");
        require(VEST_START_TIMESTAMP > 0, "Vested period not started yet.");
        require(
            vests[msg.sender].withDrawnEarly == false,
            "You withdrew early."
        );
        require(
            vests[msg.sender].totalDue > 0,
            "You do not have an investment"
        );
        require(
            vests[msg.sender].vestPeriodsClaimed < 9,
            "You have already claimed all available NVX"
        );
        uint256 claimPeriodsPassedSinceOpen = (block.timestamp -
            VEST_START_TIMESTAMP) / 28 days;
        if (
            vests[msg.sender].vestPeriodsClaimed == 0 &&
            claimPeriodsPassedSinceOpen == 0
        ) {
            uint256 totalPerPeriod = vests[msg.sender].totalDue / 9;

            uint256 amountToClaim = totalPerPeriod;

            vests[msg.sender].vestPeriodsClaimed = 1;

            nvxToken.transfer(msg.sender, amountToClaim);
        } else {
            uint256 totalPerPeriod = vests[msg.sender].totalDue / 9;
            if (claimPeriodsPassedSinceOpen > 9) {
                claimPeriodsPassedSinceOpen = 9;
            }
            require(
                claimPeriodsPassedSinceOpen >
                    vests[msg.sender].vestPeriodsClaimed,
                "You have to wait longer to claim."
            );

            uint256 claimablePeriods = claimPeriodsPassedSinceOpen -
                vests[msg.sender].vestPeriodsClaimed;

            uint256 amountToClaim = totalPerPeriod * claimablePeriods;

            vests[msg.sender].vestPeriodsClaimed = claimPeriodsPassedSinceOpen;

            nvxToken.transfer(msg.sender, amountToClaim);
        }
    }

    function withdrawAll() public onlyOwner {
        usdc.transferFrom(
            address(this),
            owner(),
            usdc.balanceOf(address(this))
        );
    }

    function setNVXAddress(NVXToken newAddress) public onlyOwner {
        nvxToken = newAddress;
    }

    function setUSDAddress(IERC20 newAddress) public onlyOwner {
        usdc = newAddress;
    }

    function isEligible(address a) public view returns(bool) {
        bool isSeed = false;
        for (uint256 i = 0; i < eligibleWallets.length; i++) {
            if (eligibleWallets[i] == a) {
                isSeed = true;
                break;
            }
        }
        return isSeed;
    }
}

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.0;

contract NVXToken is ERC20, Ownable {
    uint256 public initialSupply = 2000000000 * 10**18;
    // Percentage of transfer amount to burn
    uint256 private _burnPercentage = 1;
    mapping(address => bool) approvedContracts;

    // Define Contract Events
    event burnPercentageUpdated(uint256 from, uint256 to);
    event ContractApprovalUpdated(address contractAddress, bool status);

    constructor() ERC20("NOVABL0X", "NVX") {
        _mint(msg.sender, initialSupply);
    }

    modifier onlyApproved() {
        require(
            approvedContracts[msg.sender] == true,
            "Caller is not approved"
        );
        _;
    }

    function setOnlyApproved(address a, bool status) public onlyOwner {
        approvedContracts[a] = status;
        emit ContractApprovalUpdated(a, status);
    }

    function _burnOnTransfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        uint256 burnAmount = (amount * _burnPercentage) / 100; // Corrected burn calculation

        // Transfer to recipient
        _transfer(from, to, amount - burnAmount);
        // Burn
        _burn(from, burnAmount);
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _burnOnTransfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _burnOnTransfer(sender, recipient, amount);
        return true;
    }

    function transferWithoutBurn(address to, uint256 amount)
        external
        virtual
        onlyApproved
        returns (bool)
    {
        _transfer(msg.sender, to, amount);
        return true;
    }

    // BurnPercentage getters and setters
    function getBurnPercentage() external view returns (uint256) {
        return _burnPercentage;
    }

    function setBurnPercentage(uint256 _newBurnPercentage)
        external
        onlyOwner
        returns (bool)
    {
        require(
            _newBurnPercentage <= 100,
            "Cannot set burn percentage above 1%"
        );
        uint256 _old = _burnPercentage;
        _burnPercentage = _newBurnPercentage;

        emit burnPercentageUpdated(_old, _burnPercentage);
        return true;
    }

    function withdraw() external payable onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success);
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
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/ERC20.sol)

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