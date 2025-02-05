// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/IGaugeProxy.sol";
import "./interfaces/IOptiSwap.sol";
import "./interfaces/IGaugeVaultProxy.sol";
import "./interfaces/IVeToken.sol";
import "./interfaces/IWrappedVotingEscrowToken.sol";
import "./interfaces/ITokenDistributor.sol";
import "./interfaces/IDelegateRegistry.sol";
import "./interfaces/IGauge.sol";
import "./interfaces/IBaseV1Pair.sol";

import "./interfaces/ISpiritV2VaultTokenFactory.sol";
import "./interfaces/IVaultToken.sol";

interface OptiSwapPair {
    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external;
}

contract GaugeVaultProxyAdmin is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant MIN_DELAY = 3 days;
    uint256 public constant MAX_DELAY = 30 days;

    uint256 constant MAX_BPS = 10_000;
    uint256 constant MIN_VELOCK_BPS = 0;
    uint256 constant MAX_VELOCK_BPS = MAX_BPS / 2;

    uint256 public veLockBps = (MAX_BPS * 15) / 100; // 15%

    ISpiritV2VaultTokenFactory public vaultTokenFactory;
    IGaugeVaultProxy public gaugeVaultProxy;
    IVeToken public veToken;
    IERC20 public rewardToken;
    address public wrappedVeToken;
    address public tokenDistributor;
    address public optiSwap;
    address public manager;
    address public gaugeProxyAdmin;
    address public pendingGaugeProxyAdmin;
    uint256 public pendingGaugeProxyAdminNotBefore;

    IGaugeProxy[] m_gaugeProxyList;
    mapping(IGaugeProxy => bool) m_gaugeProxyEnabled;

    mapping(address => address) public getGauge;

    event UpdatePendingGaugeProxyAdmin(address indexed gaugeProxyAdmin, uint256 notBefore);
    event UpdateGaugeProxyAdmin(address indexed gaugeProxyAdmin);
    event UpdateVeLockBps(uint256 _newVeLockBps);
    event DepositInGauge(address vaultToken, address gauge, uint256 amount);
    event WithdrawFromGauge(address vaultToken, address gauge, uint256 amount);
    event ClaimGaugeReward(address vaultToken, address gauge, uint256 rewardTokenAmount);

    constructor(
        address _gaugeVaultProxy,
        address _veToken,
        address _wrappedVeToken,
        address _tokenDistributor,
        address _optiSwap
    ) public {
        gaugeVaultProxy = IGaugeVaultProxy(_gaugeVaultProxy);
        veToken = IVeToken(_veToken);
        rewardToken = IERC20(veToken.token());
        wrappedVeToken = _wrappedVeToken;
        tokenDistributor = _tokenDistributor;
        optiSwap = _optiSwap;
        gaugeProxyAdmin = msg.sender;
    }

    function setVaultTokenFactory(address _vaultTokenFactory) external onlyOwner {
        require(address(vaultTokenFactory) == address(0), "GaugeVaultProxyAdmin: FACTORY_ALREADY_SET");
        vaultTokenFactory = ISpiritV2VaultTokenFactory(_vaultTokenFactory);
    }

    function removeGaugeProxyAdmin() external onlyOwner {
        gaugeProxyAdmin = address(0);
        delete pendingGaugeProxyAdmin;
        delete pendingGaugeProxyAdminNotBefore;

        emit UpdateGaugeProxyAdmin(gaugeProxyAdmin);
    }

    function updatePendingGaugeProxyAdmin(address _newPendingGaugeProxyAdmin, uint256 _notBefore)
        external
        onlyOwner
        nonReentrant
    {
        if (_newPendingGaugeProxyAdmin == address(0)) {
            require(_notBefore == 0, "GaugeVaultProxyAdmin: NOT_BEFORE");
        } else {
            require(_newPendingGaugeProxyAdmin != gaugeProxyAdmin, "GaugeVaultProxyAdmin: SAME_ADMIN");
            require(_notBefore >= block.timestamp + MIN_DELAY, "GaugeVaultProxyAdmin: TOO_SOON");
            require(_notBefore < block.timestamp + MAX_DELAY, "GaugeVaultProxyAdmin: TOO_LATE");
        }

        pendingGaugeProxyAdmin = _newPendingGaugeProxyAdmin;
        pendingGaugeProxyAdminNotBefore = _notBefore;

        emit UpdatePendingGaugeProxyAdmin(_newPendingGaugeProxyAdmin, _notBefore);
    }

    function updateGaugeProxyAdmin() external onlyOwner nonReentrant {
        require(pendingGaugeProxyAdmin != address(0), "GaugeVaultProxyAdmin: INVLD_ADMIN");
        require(block.timestamp >= pendingGaugeProxyAdminNotBefore, "GaugeVaultProxyAdmin: TOO_SOON");
        require(block.timestamp < pendingGaugeProxyAdminNotBefore + GRACE_PERIOD, "GaugeVaultProxyAdmin: TOO_LATE");
        require(pendingGaugeProxyAdmin != gaugeProxyAdmin, "GaugeVaultProxyAdmin: SAME_ADMIN");

        gaugeProxyAdmin = pendingGaugeProxyAdmin;
        delete pendingGaugeProxyAdmin;
        delete pendingGaugeProxyAdminNotBefore;

        emit UpdateGaugeProxyAdmin(gaugeProxyAdmin);
    }

    function updateOptiSwap(address _optiSwap) external onlyOwner {
        optiSwap = _optiSwap;
    }

    function updateManager(address _manager) external onlyOwner {
        manager = _manager;
    }

    function updateVeLockBps(uint256 _newVeLockBps) external onlyOwnerOrManager {
        require(
            _newVeLockBps >= MIN_VELOCK_BPS && _newVeLockBps <= MAX_VELOCK_BPS,
            "GaugeVaultProxyAdmin: INVLD_VELOCK"
        );
        veLockBps = _newVeLockBps;

        emit UpdateVeLockBps(_newVeLockBps);
    }

    function gaugeBalanceOf(address _vaultToken) public view returns (uint256) {
        IVaultToken vaultToken = IVaultToken(_vaultToken);
        address underlying = vaultToken.underlying();
        return IGauge(getGauge[underlying]).balanceOf(address(gaugeVaultProxy));
    }

    function gaugeProxyListLength() external view returns (uint256) {
        return m_gaugeProxyList.length;
    }

    function gaugeProxyListItem(uint256 index) external view returns (IGaugeProxy) {
        return m_gaugeProxyList[index];
    }

    function gaugeProxyEnabled(IGaugeProxy gaugeProxy) external view returns (bool) {
        return m_gaugeProxyEnabled[gaugeProxy];
    }

    function _addGaugeProxy(IGaugeProxy gaugeProxy) internal {
        require(!m_gaugeProxyEnabled[gaugeProxy], "GaugeVaultProxyAdmin: GAUGE_PROXY_ENABLED");

        m_gaugeProxyEnabled[gaugeProxy] = true;
        m_gaugeProxyList.push(gaugeProxy);
    }

    function addGaugeProxy(IGaugeProxy gaugeProxy) external onlyGaugeProxyAdmin {
        _addGaugeProxy(gaugeProxy);
    }

    function addGaugeProxies(IGaugeProxy[] calldata gaugeProxyList) external onlyGaugeProxyAdmin {
        for (uint256 i = 0; i < gaugeProxyList.length; i++) {
            IGaugeProxy gaugeProxy = gaugeProxyList[i];
            _addGaugeProxy(gaugeProxy);
        }
    }

    function _indexOfGaugeProxy(IGaugeProxy gaugeProxy) internal view returns (uint256 index) {
        uint256 count = m_gaugeProxyList.length;
        for (uint256 i = 0; i < count; i++) {
            if (m_gaugeProxyList[i] == gaugeProxy) {
                return i;
            }
        }
        require(false, "GaugeVaultProxyAdmin: GAUGE_PROXY_NOT_FOUND");
    }

    function removeGaugeProxy(IGaugeProxy gaugeProxy) external onlyGaugeProxyAdmin {
        require(m_gaugeProxyEnabled[gaugeProxy], "GaugeVaultProxyAdmin: GAUGE_PROXY_ENABLED");

        uint256 index = _indexOfGaugeProxy(gaugeProxy);
        IGaugeProxy last = m_gaugeProxyList[m_gaugeProxyList.length - 1];
        m_gaugeProxyList[index] = last;
        m_gaugeProxyList.pop();
        delete m_gaugeProxyEnabled[gaugeProxy];
    }

    function setGauge(address _underlying, address _gaugeProxy) external onlyOwnerOrManager {
        require(!IBaseV1Pair(_underlying).stable(), "GaugeVaultProxyAdmin: STABLE");
        require(m_gaugeProxyEnabled[IGaugeProxy(_gaugeProxy)], "GaugeVaultProxyAdmin: GAUGE_PROXY_ENABLED");
        address gaugeTo = IGaugeProxy(_gaugeProxy).getGauge(_underlying);
        require(gaugeTo != address(0), "GaugeVaultProxyAdmin: NO_GAUGE");
        address gaugeFrom = getGauge[_underlying];
        if (gaugeFrom != address(0)) {
            require(IGauge(gaugeFrom).gaugeProxy() != _gaugeProxy);
            migrateGauge(_underlying, gaugeFrom, gaugeTo);
        }
        getGauge[_underlying] = gaugeTo;
    }

    function migrateGauge(
        address _underlying,
        address _gaugeFrom,
        address _gaugeTo
    ) internal {
        IGauge gaugeFrom = IGauge(_gaugeFrom);
        uint256 amount = gaugeFrom.balanceOf(address(gaugeVaultProxy));
        if (amount > 0) {
            gvpGaugeWithdraw(gaugeFrom, amount);
            IERC20 underlying = IERC20(_underlying);
            uint256 underlyingBalanceAfter = underlying.balanceOf(address(gaugeVaultProxy));
            require(underlyingBalanceAfter >= amount, "GaugeVaultProxyAdmin: INSUFFICIENT_BALANCE");
            gvpSafeApprove(underlying, address(_gaugeTo), amount);
            gvpGaugeDeposit(IGauge(_gaugeTo), amount);
        }
    }

    function depositInGauge(uint256 _amount) external onlyVaultToken nonReentrant {
        IVaultToken vaultToken = IVaultToken(msg.sender);
        IERC20 underlying = IERC20(vaultToken.underlying());
        IGauge gauge = IGauge(getGauge[address(underlying)]);
        underlying.safeTransferFrom(address(vaultToken), address(gaugeVaultProxy), _amount);
        gvpSafeApprove(underlying, address(gauge), _amount);
        gvpGaugeDeposit(gauge, _amount);
        emit DepositInGauge(msg.sender, address(gauge), _amount);
    }

    function withdrawFromGauge(uint256 _amount) external onlyVaultToken nonReentrant {
        require(_amount > 0, "GaugeVaultProxyAdmin: AMOUNT_ZERO");
        IVaultToken vaultToken = IVaultToken(msg.sender);
        IERC20 underlying = IERC20(vaultToken.underlying());
        IGauge gauge = IGauge(getGauge[address(underlying)]);
        gvpGaugeWithdraw(gauge, _amount);
        uint256 underlyingBalanceAfter = underlying.balanceOf(address(gaugeVaultProxy));
        require(underlyingBalanceAfter >= _amount, "GaugeVaultProxyAdmin: INSUFFICIENT_BALANCE");
        gvpSafeTransfer(underlying, msg.sender, _amount);
        emit WithdrawFromGauge(msg.sender, address(gauge), _amount);
    }

    function claimGaugeReward() external onlyVaultToken nonReentrant {
        IVaultToken vaultToken = IVaultToken(msg.sender);
        IGauge gauge = IGauge(getGauge[vaultToken.underlying()]);
        uint256 rewardTokenBalanceBefore = rewardToken.balanceOf(address(gaugeVaultProxy));
        gvpGaugeGetReward(gauge);
        uint256 rewardTokenBalanceAfter = rewardToken.balanceOf(address(gaugeVaultProxy));
        uint256 rewardTokenAmount = rewardTokenBalanceAfter.sub(rewardTokenBalanceBefore);
        if (rewardTokenAmount > 0) {
            uint256 lockAmount = rewardTokenAmount.mul(veLockBps).div(MAX_BPS);
            uint256 xferAmount = rewardTokenAmount.sub(lockAmount);
            gvpSafeTransfer(rewardToken, msg.sender, xferAmount);
        }
        emit ClaimGaugeReward(msg.sender, address(gauge), rewardTokenAmount);
    }

    function wrappedVeDeposit(uint256 _amount) external {
        require(_amount > 0, "GaugeVaultProxyAdmin: AMOUNT_ZERO");
        (address pair, uint256 amountOut) = IOptiSwap(optiSwap).getBestAmountOut(
            _amount,
            address(rewardToken),
            wrappedVeToken
        );
        if (pair != address(0) && amountOut > _amount) {
            // Swap
            rewardToken.safeTransferFrom(msg.sender, pair, _amount);
            if (address(rewardToken) < wrappedVeToken) {
                OptiSwapPair(pair).swap(0, amountOut, msg.sender, new bytes(0));
            } else {
                OptiSwapPair(pair).swap(amountOut, 0, msg.sender, new bytes(0));
            }
        } else {
            // Mint
            rewardToken.safeTransferFrom(msg.sender, address(gaugeVaultProxy), _amount);
            gaugeVaultProxy.increaseAmount(_amount);
            IWrappedVotingEscrowToken(wrappedVeToken).mint(msg.sender, _amount);
        }
    }

    function processVeRewards(address _feeDistributor) external onlyOwnerOrManager {
        ITokenDistributor(tokenDistributor).claim();
        if (_feeDistributor != address(0)) {
            gaugeVaultProxy.claimVeTokenReward(_feeDistributor);
        }
        uint256 amount = rewardToken.balanceOf(address(gaugeVaultProxy));
        require(amount > 0, "GaugeVaultProxyAdmin: AMOUNT_ZERO");
        (address pair, uint256 amountOut) = IOptiSwap(optiSwap).getBestAmountOut(
            amount,
            address(rewardToken),
            wrappedVeToken
        );
        if (pair != address(0) && amountOut > amount) {
            // Swap
            gaugeVaultProxy.withdrawRewardToken(amount);
            rewardToken.safeTransfer(pair, amount);
            if (address(rewardToken) < wrappedVeToken) {
                OptiSwapPair(pair).swap(0, amountOut, tokenDistributor, new bytes(0));
            } else {
                OptiSwapPair(pair).swap(amountOut, 0, tokenDistributor, new bytes(0));
            }
        } else {
            // Mint
            gaugeVaultProxy.increaseAmount(amount);
            IWrappedVotingEscrowToken(wrappedVeToken).mint(tokenDistributor, amount);
        }
    }

    function vote(
        address gaugeProxy,
        address[] calldata _tokenVote,
        uint256[] calldata _weights
    ) external onlyOwnerOrManager {
        gvpGaugeProxyVote(IGaugeProxy(gaugeProxy), _tokenVote, _weights);
    }

    function inCaseTokensGetStuck(address _token, uint256 _amount) external onlyOwnerOrManager nonReentrant {
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    function gvpExecute(address to, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory result) = gaugeVaultProxy.execute(to, 0, data);
        require(success == true, "GaugeVaultProxyAdmin: EXECUTE_FAILED");
        return result;
    }

    function gvpSafeTransfer(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        bytes memory returndata = gvpExecute(
            address(token),
            abi.encodeWithSelector(token.transfer.selector, to, amount)
        );
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "GaugeVaultProxyAdmin: SAFE_XFER_FAILED");
        }
    }

    function gvpApprove(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        bytes memory returndata = gvpExecute(
            address(token),
            abi.encodeWithSelector(token.approve.selector, to, amount)
        );
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "GaugeVaultProxyAdmin: APPROVE_FAILED");
        }
    }

    function gvpSafeApprove(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        gvpApprove(token, to, 0);
        gvpApprove(token, to, amount);
    }

    function gvpGaugeGetReward(IGauge gauge) internal {
        gvpExecute(address(gauge), abi.encodeWithSelector(gauge.getReward.selector));
    }

    function gvpGaugeDeposit(IGauge gauge, uint256 amount) internal {
        gvpExecute(address(gauge), abi.encodeWithSelector(gauge.deposit.selector, amount));
    }

    function gvpGaugeWithdraw(IGauge gauge, uint256 amount) internal {
        gvpExecute(address(gauge), abi.encodeWithSelector(gauge.withdraw.selector, amount));
    }

    function gvpGaugeProxyVote(
        IGaugeProxy gaugeProxy,
        address[] calldata _tokenVote,
        uint256[] calldata _weights
    ) internal {
        gvpExecute(address(gaugeProxy), abi.encodeWithSelector(gaugeProxy.vote.selector, _tokenVote, _weights));
    }

    function gvpClearDelegate(address _delegateRegistry, bytes32 _id) external onlyOwnerOrManager {
        _gvpClearDelegate(IDelegateRegistry(_delegateRegistry), _id);
    }

    function gvpSetDelegate(
        address _delegateRegistry,
        bytes32 _id,
        address _delegate
    ) external onlyOwnerOrManager {
        _gvpSetDelegate(IDelegateRegistry(_delegateRegistry), _id, _delegate);
    }

    function _gvpClearDelegate(IDelegateRegistry _delegateRegistry, bytes32 _id) internal {
        gvpExecute(address(_delegateRegistry), abi.encodeWithSelector(_delegateRegistry.clearDelegate.selector, _id));
    }

    function _gvpSetDelegate(
        IDelegateRegistry _delegateRegistry,
        bytes32 _id,
        address _delegate
    ) internal {
        gvpExecute(
            address(_delegateRegistry),
            abi.encodeWithSelector(_delegateRegistry.setDelegate.selector, _id, _delegate)
        );
    }

    modifier onlyOwnerOrManager() {
        require(msg.sender == owner() || msg.sender == manager, "GaugeVaultProxyAdmin: RESTRICTED");
        _;
    }

    modifier onlyVaultToken() {
        require(
            msg.sender == vaultTokenFactory.getVaultToken(IVaultToken(msg.sender).underlying()),
            "GaugeVaultProxyAdmin: ONLY_VAULT_TOKEN"
        );
        _;
    }

    modifier onlyGaugeProxyAdmin() {
        require(msg.sender == gaugeProxyAdmin, "GaugeVaultProxyAdmin: ONLY_GAUGE_PROXY_ADMIN");
        _;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../utils/Context.sol";
import "./IERC20.sol";
import "../../math/SafeMath.sol";

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
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

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
    constructor (string memory name_, string memory symbol_) public {
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
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

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
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
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
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
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
library SafeMath {
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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

    constructor () internal {
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
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IGaugeProxy {
    function getGauge(address _token) external view returns (address);

    function tokens() external view returns (address[] memory);

    function vote(address[] calldata _tokenVote, uint256[] calldata _weights) external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IOptiSwap {
    function weth() external view returns (address);

    function bridgeFromTokens(uint256 index) external view returns (address token);

    function bridgeFromTokensLength() external view returns (uint256);

    function getBridgeToken(address _token) external view returns (address bridgeToken);

    function addBridgeToken(address _token, address _bridgeToken) external;

    function getDexInfo(uint256 index) external view returns (address dex, address handler);

    function dexListLength() external view returns (uint256);

    function indexOfDex(address _dex) external view returns (uint256);

    function getDexEnabled(address _dex) external view returns (bool);

    function addDex(address _dex, address _handler) external;

    function removeDex(address _dex) external;

    function getBestAmountOut(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) external view returns (address pair, uint256 amountOut);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IMasterChefProxy.sol";
import "./IGauge.sol";
import "./IVaultToken.sol";

interface IGaugeVaultProxy is IMasterChefProxy {
    function manager() external view returns (address);

    function admin() external view returns (address);

    function pendingAdmin() external view returns (address);

    function pendingAdminNotBefore() external view returns (uint256);

    function veLockBps() external view returns (uint256);

    function removeAdmin() external;

    function updatePendingAdmin(address _newPendingAdmin, uint256 _notBefore) external;

    function updateAdmin() external;

    function updateManager(address _manager) external;

    function setVaultTokenFactory(address _vaultTokenFactory) external;

    function updateVeLockBps(uint256 _newVeLockBps) external;

    function getUnderlying(uint256 _pid) external view returns (IERC20 underlying);

    function getGauge(uint _pid) external view returns (IGauge gauge);

    function getVaultToken(uint _pid) external view returns (IVaultToken vaultToken);

    function createLock(uint256 _amount, uint256 _unlockTime) external;

    function release() external;

    function increaseAmount(uint256 _amount) external;

    function increaseTime(uint256 _unlockTime) external;

    function claimVeTokenReward(address _feeDistributor) external;

    function vote(address[] calldata _tokenVote, uint256[] calldata _weights) external;

    function withdrawRewardToken(uint256 _amount) external;

    function inCaseTokensGetStuck(address _token, uint256 _amount) external;

    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bool, bytes memory);

    event UpdatePendingAdmin(address indexed admin, uint256 notBefore);
    event UpdateAdmin(address indexed admin);

    event UpdateVeLockBps(uint256 _newVeLockFeeBps);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    event CreateLock(address indexed user, uint256 amount, uint256 unlockTime);
    event Release(address indexed user, uint256 amount, uint256 balanceAfter);
    event IncreaseAmount(address indexed user, uint256 amount);
    event IncreaseTime(address indexed user, uint256 unlockTime);
    event ClaimVeTokenReward(address indexed user, address indexed feeDistributor, uint256 amount);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IVeToken {
    function create_lock(uint256 _amount, uint256 _unlockTime) external;

    function increase_amount(uint256 _amount) external;

    function increase_unlock_time(uint256 _unlockTime) external;

    function withdraw() external;

    function locked__end(address _user) external view returns (uint256);

    function balanceOf(address _user) external view returns (uint256);

    function token() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IWrappedVotingEscrowToken {
    function manager() external view returns (address);

    function setManager(address _manager) external;

    function mint(address _to, uint256 _amount) external;

    function burn(address _from, uint256 _amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

interface ITokenDistributor {
    function token() external view returns (address);

    function xToken() external view returns (address);

    function periodLength() external view returns (uint);

    function lastClaim() external view returns (uint);

    function claim() external returns (uint amount);

    function setPeriodLength(uint newPeriodLength) external;

    event Claim(uint previousBalance, uint timeElapsed, uint amount);
    event NewPeriodLength(uint oldPeriodLength, uint newPeriodLength);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IDelegateRegistry {
    function clearDelegate(bytes32 _id) external;

    function setDelegate(bytes32 _id, address _delegate) external;

    function delegation(address _address, bytes32 _id) external view returns (address);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IGauge {
    function deposit(uint256 _amount) external;

    function depositFor(uint256 _amount, address _account) external;

    function withdraw(uint256 _amount) external;

    function withdrawAll() external;

    function balanceOf(address _account) external view returns (uint256);

    function derivedBalance(address account) external view returns (uint);

    function earned(address _account) external view returns (uint256);

    function getReward() external;

    function vote(address[] calldata _tokenVote, uint256[] calldata _weights) external;

    function gaugeProxy() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IBaseV1Pair {
    function claimFees() external returns (uint, uint);

    function tokens() external returns (address, address);

    function stable() external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface ISpiritV2VaultTokenFactory {
    function getVaultToken(address) external view returns (address);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IVaultToken {
    /*** Tarot ERC20 ***/

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /*** Pool Token ***/

    event Mint(address indexed sender, address indexed minter, uint256 mintAmount, uint256 mintTokens);
    event Redeem(address indexed sender, address indexed redeemer, uint256 redeemAmount, uint256 redeemTokens);
    event Sync(uint256 totalBalance);

    function underlying() external view returns (address);

    function factory() external view returns (address);

    function totalBalance() external view returns (uint256);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function exchangeRate() external view returns (uint256);

    function mint(address minter) external returns (uint256 mintTokens);

    function redeem(address redeemer) external returns (uint256 redeemAmount);

    function skim(address to) external;

    function sync() external;

    function _setFactory() external;

    /*** VaultToken ***/

    event Reinvest(address indexed caller, uint256 reward, uint256 bounty);

    function isVaultToken() external pure returns (bool);

    function router() external view returns (address);

    function masterChef() external view returns (address);

    function rewardsToken() external view returns (address);

    function WETH() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function swapFeeFactor() external view returns (uint256);

    function pid() external view returns (uint256);

    function REINVEST_BOUNTY() external pure returns (uint256);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function _initialize(
        address _router,
        address _masterChef,
        address _rewardsToken,
        uint256 _swapFeeFactor,
        uint256 _pid
    ) external;

    function reinvest() external;
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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

pragma solidity >=0.6.2 <0.8.0;

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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
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

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMasterChefProxy {
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. Reward tokens to distribute per block.
        uint256 lastRewardBlock; // Last block number that reward token distribution occurs.
        uint256 accRewardTokenPerShare; // Accumulated reward tokens per share, times 1e12. See below.
    }

    // Info of each user that stakes LP tokens.
    function poolInfo(uint256 _pid) external view returns (PoolInfo memory);

    function userInfo(uint256 _pid, address _address) external view returns (UserInfo memory);

    // Deposit LP tokens to MasterChef.
    function deposit(uint256 _pid, uint256 _amount) external;

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) external;
}