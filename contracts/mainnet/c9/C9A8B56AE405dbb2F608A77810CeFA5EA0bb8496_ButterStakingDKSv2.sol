/**
 *Submitted for verification at FtmScan.com on 2022-07-04
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b);
    }


    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }


    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b);
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }


    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b);
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

interface IBEP20 {
    function totalSupply() external view returns (uint256);

    function decimals() external view returns (uint8);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function getOwner() external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address _owner, address spender) external view returns (uint256);

   
    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

   
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

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
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            codehash := extcodehash(account)
        }
        return (codehash != accountHash && codehash != 0x0);
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
        require(address(this).balance >= amount);

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{value: amount}('');
        require(success);
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
        return functionCall(target, data);
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
        return _functionCallWithValue(target, data, 0, errorMessage);
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
        return functionCallWithValue(target, data, value);
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
        require(address(this).balance >= value);
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(
        address target,
        bytes memory data,
        uint256 weiValue,
        string memory errorMessage
    ) private returns (bytes memory) {
        require(isContract(target));

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{value: weiValue}(data);
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

library SafeBEP20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(
        IBEP20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IBEP20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IBEP20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IBEP20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0)
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IBEP20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IBEP20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(
            value,
            'decby0'
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IBEP20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)));
        }
    }
}

contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor() internal {}

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender());
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract BEP20 is Context, IBEP20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(string memory name, string memory symbol) public {
        _name = name;
        _symbol = symbol;
        _decimals = 18;
    }

    function getOwner() external override view returns (address) {
        return owner();
    }

    function name() public override view returns (string memory) {
        return _name;
    }

    function decimals() public override view returns (uint8) {
        return _decimals;
    }

    function symbol() public override view returns (string memory) {
        return _symbol;
    }

    function totalSupply() public override view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public override view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public override view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(amount, 'noallow')
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(subtractedValue, '0allow')
        );
        return true;
    }

    function mint(uint256 amount) public onlyOwner returns (bool) {
        _mint(_msgSender(), amount);
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0));
        require(recipient != address(0));

        _balances[sender] = _balances[sender].sub(amount, 'no balance');
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal {
        require(account != address(0));

        _balances[account] = _balances[account].sub(amount, 'no balance');
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(owner != address(0));
        require(spender != address(0));

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(
            account,
            _msgSender(),
            _allowances[account][_msgSender()].sub(amount, 'noallow')
        );
    }
}

interface IMigratorChef {
    function migrate(IBEP20 token) external returns (IBEP20);
}

interface ISmartChef {
    function deposit(uint256 _amount) external;
    function withdraw(uint256 _amount) external;
    function pendingReward(address _user) external view returns (uint256);
    function rewardToken() external view returns (address);
    function stakedToken() external view returns (address);
    function emergencyWithdraw() external;
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}



interface IMasterSmartChef {
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function pendingKnight(uint256 _pid, address _user) external view returns (uint256);     // CHANGE THIS ON CHANGE OF EXCHANGE
}

contract ButterStakingDKSv2 {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;



    
    address MainPoolAddress = address(0xb02e3A4B5ebC315137753e24b6Eb6aEF7D602E40);     // CHANGE THIS ON CHANGE OF EXCHANGE
    address MAIN_TOKEN_ADDRESS = address(0x6cc0E0AedbbD3C35283e38668D959F6eb3034856);     // CHANGE THIS ON CHANGE OF EXCHANGE

    IBEP20 MAIN_TOKEN = IBEP20(MAIN_TOKEN_ADDRESS);
    IUniswapV2Router02 public uniswapV2Router;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        ISmartChef current;
        ISmartChef next;
        address[] currentSwapPath;
        address[] nextSwapPath;
        uint256 stakedAmount;
        address[] users;
    }
    
    struct DetailsStruct{
        ISmartChef currentPool;
        ISmartChef nextPool;
        uint256 InToken;
        address TokenAddress;
        uint256 InMain;
        uint256 userAmount;
        uint256 totalAmount;
        uint256 fee;
        uint256 pid;
        uint256 MainActive;
        uint dAllowed;
    }

    address teamAddress;
    address teamAddress2;
    uint depositAllowed = 1;
    PoolInfo public PoolData;
    uint256 teamFee = 40;
    uint256 MainPoolPid = 3;
    uint256 MainPoolActivated = 0;
    IMasterSmartChef MainPool;

    mapping (address => UserInfo) public userInfo;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor() public {
        teamAddress = 0xFCD677d4Bbee1fB1B5fB5C195E902c4e5F98a090;
        teamAddress2 = 0xE5009C5ac2d84196484fa0848a3fBa96460B71e9;
        // CHANGE THIS ON CHANGE OF EXCHANGE
        uniswapV2Router = IUniswapV2Router02(address(0x045312C737a6b7a115906Be0aD0ef53A6AA38106)); //SWAP CONTRACT
        MainPool = IMasterSmartChef(MainPoolAddress);
    }

    bool internal locked = false;
    modifier noReentrant() {
        require(!locked);
        locked = true;
        _;
        locked = false;
    }

    function userlist() external view returns (address[] memory) {
        address[] memory usrs = PoolData.users;
        return usrs;
    }
    
    function currentSwapPathList() external view returns (address[] memory) {
        address[] memory swap = PoolData.currentSwapPath;
        return swap;
    }

    

    function setNewTeamFee(uint256 fees) public {
        require(msg.sender == teamAddress || msg.sender == teamAddress2);
        require(fees <= 50);
        teamFee = fees;
    }
           

    function set(ISmartChef _nextSmartChef, address[] memory swapPath) public {
        require(msg.sender == teamAddress || msg.sender == teamAddress2);
        PoolInfo storage pool = PoolData;
        pool.next = _nextSmartChef;
        pool.nextSwapPath = swapPath;
        WithdrawAndRecalculateRewards(1);        
        DepositToNewPool();
    }
 

    function ToggleMainPool() public {
        require(msg.sender == teamAddress || msg.sender == teamAddress2);
        WithdrawAndRecalculateRewards(1);
        if (MainPoolActivated == 0) {
            MainPoolActivated = 1;
        } else {
            MainPoolActivated = 0;
        }
        DepositToNewPool();
    }


    function ChangeMainPoolPID(uint256 newPID) public {
        require(msg.sender == teamAddress || msg.sender == teamAddress2);
        require(MainPoolActivated == 0);
        MainPoolPid = newPID;
    }


    function setNotSwap(ISmartChef _nextSmartChef, address[] memory swapPath) public {
        require(msg.sender == teamAddress || msg.sender == teamAddress2);
        PoolInfo storage pool = PoolData;
        pool.next = _nextSmartChef;
        pool.nextSwapPath = swapPath;
        WithdrawAndRecalculateRewards(0);        
        DepositToNewPool();
    }

    
    function setNotSwapER(ISmartChef _nextSmartChef, address[] memory swapPath) public {
        require(msg.sender == teamAddress || msg.sender == teamAddress2);
        PoolInfo storage pool = PoolData;
        pool.next = _nextSmartChef;
        pool.nextSwapPath = swapPath;
        WithdrawAndRecalculateRewards(2);        
        DepositToNewPool();
    }


    function changeCurrentSwapPath(address[] memory swapPath) public {
        require(msg.sender == teamAddress || msg.sender == teamAddress2);
        PoolInfo storage pool = PoolData;
        pool.currentSwapPath = swapPath;
    }


 
    function changeSwapRouter(address to) public {
        require(msg.sender == teamAddress || msg.sender == teamAddress2);
        uniswapV2Router = IUniswapV2Router02(address(to)); //SWAP CONTRACT
    }

    
    function firstSetNoTVL(ISmartChef _currentSmartChef, address[] memory swapPath) public {
        require(msg.sender == teamAddress || msg.sender == teamAddress2);
        PoolInfo storage pool = PoolData;
        pool.current = _currentSmartChef;
        pool.next = _currentSmartChef;     
        pool.currentSwapPath = swapPath;
        pool.nextSwapPath = swapPath;
    }


    function toggleDeposits() public {
        require(msg.sender == teamAddress || msg.sender == teamAddress2);
        if(depositAllowed == 1){
            depositAllowed = 0;
        } else {
            depositAllowed = 1;
        }        
    }

    function emergencyReturn() public {
        require(msg.sender == teamAddress || msg.sender == teamAddress2);
        IBEP20 rewardToken = IBEP20(PoolData.current.rewardToken());

        PoolInfo memory pool = PoolData;
        uint256 MainReward = 0;
        uint256 afterMainBalance = 0;
        if (MainPoolActivated == 0){
            pool.current.withdraw(pool.stakedAmount); 
            uint256 afterRewardBalance = rewardToken.balanceOf(address(this));
            uint256 beforeMainBalance = MAIN_TOKEN.balanceOf(address(this));
            if (afterRewardBalance > 0) {
                swapTokensForMain(rewardToken, afterRewardBalance);
            }
            afterMainBalance = MAIN_TOKEN.balanceOf(address(this));
            MainReward = afterMainBalance.sub(beforeMainBalance);
        } else {
            MainPool.withdraw(MainPoolPid, pool.stakedAmount);
            afterMainBalance = MAIN_TOKEN.balanceOf(address(this));
            MainReward = afterMainBalance.sub(pool.stakedAmount);
        }
        

        uint256 teamReward = MainReward.mul(teamFee).div(1000);
        MAIN_TOKEN.transfer(address(teamAddress), teamReward.div(2));
        MAIN_TOKEN.transfer(address(teamAddress2), teamReward.div(2));
        teamReward = teamReward.div(2) + teamReward.div(2); 
        MainReward = MainReward.sub(teamReward);

        for (uint256 uid = 0; uid < pool.users.length; ++uid) {
            address addr = pool.users[uid];
            UserInfo storage currentUser = userInfo[addr];
            uint256 withamount = currentUser.rewardDebt.add(MainReward.mul(currentUser.amount.add(currentUser.rewardDebt)).div(pool.stakedAmount));
            withamount = currentUser.amount.add(withamount).mul(999).div(1000);
            if (withamount > 0){
                if (currentUser.amount > 0 ){
                    MAIN_TOKEN.transfer(addr, withamount);
                }               
            }            
            currentUser.rewardDebt = 0;            
            currentUser.amount = 0;
        }
        afterMainBalance = MAIN_TOKEN.balanceOf(address(this));
        if (afterMainBalance > 0){
            MAIN_TOKEN.transfer(teamAddress, afterMainBalance.div(2));
            MAIN_TOKEN.transfer(teamAddress2, afterMainBalance.div(2));
        }
        pool.stakedAmount = 0;
    }

    function emergencyReturnNoSwap() public {
        require(msg.sender == teamAddress || msg.sender == teamAddress2);
        PoolInfo memory pool = PoolData;

        if (MainPoolActivated == 0){
            pool.current.withdraw(pool.stakedAmount); 
        } else {
            MainPool.withdraw(MainPoolPid, pool.stakedAmount);
        }
        
        uint256 afterMainBalance = MAIN_TOKEN.balanceOf(address(this));

        for (uint256 uid = 0; uid < pool.users.length; ++uid) { 
            address addr = pool.users[uid];
            UserInfo storage currentUser = userInfo[addr];
            uint256 withamount = currentUser.rewardDebt;
            withamount = currentUser.amount.add(withamount).mul(999).div(1000);
            if (withamount > 0){
                if (currentUser.amount > 0 ){
                    MAIN_TOKEN.transfer(addr, withamount);
                }               
            }            
            currentUser.rewardDebt = 0;            
            currentUser.amount = 0;
        }
        afterMainBalance = MAIN_TOKEN.balanceOf(address(this));
        if (afterMainBalance > 0){
            MAIN_TOKEN.transfer(teamAddress, afterMainBalance.div(2));
            MAIN_TOKEN.transfer(teamAddress2, afterMainBalance.div(2));
        }
        pool.stakedAmount = 0;
    }

    
    function emergencyReturnNoSwapNoFee() public {
        require(msg.sender == teamAddress || msg.sender == teamAddress2);
        PoolInfo memory pool = PoolData;
        if (MainPoolActivated == 0){
            pool.current.withdraw(pool.stakedAmount); 
        } else {
            MainPool.withdraw(MainPoolPid, pool.stakedAmount);
        }
        

        for (uint256 uid = 0; uid < pool.users.length; ++uid) { 
            address addr = pool.users[uid];
            UserInfo storage currentUser = userInfo[addr];
            uint256 withamount = currentUser.amount.add(currentUser.rewardDebt);
            if (withamount > 0){
                if (currentUser.amount > 0 ){
                    MAIN_TOKEN.transfer(addr, withamount);
                }               
            }            
            currentUser.rewardDebt = 0;            
            currentUser.amount = 0;
        }
        pool.stakedAmount = 0;
    }

    function DepositsAllowed() external view returns (uint) {
        return depositAllowed;
    }

    
    function Details(address _user) external view returns (DetailsStruct memory) {
        UserInfo storage user = userInfo[_user];
        DetailsStruct memory PendingDetails;      
        if (MainPoolActivated == 1){
            PendingDetails.InToken = MainPool.pendingKnight(MainPoolPid, address(this));
            PendingDetails.TokenAddress = MAIN_TOKEN_ADDRESS;
        }else{
            PendingDetails.InToken = PoolData.current.pendingReward(address(this));            
            PendingDetails.TokenAddress = PoolData.current.rewardToken();
        }
        PendingDetails.InToken  = PendingDetails.InToken.mul(user.amount).div(PoolData.stakedAmount);
        PendingDetails.InMain = user.rewardDebt;
        PendingDetails.userAmount = user.amount;
        PendingDetails.totalAmount = PoolData.stakedAmount;
        PendingDetails.currentPool = PoolData.current;
        PendingDetails.nextPool = PoolData.next;
        PendingDetails.fee = teamFee;
        PendingDetails.pid = MainPoolPid;
        PendingDetails.MainActive = MainPoolActivated;
        PendingDetails.dAllowed = depositAllowed;
        return PendingDetails;
    }

    function deposit(uint256 _amount) public noReentrant  {
        require(depositAllowed == 1);
        require(_amount > 100000000000000000); 
        require(MAIN_TOKEN.balanceOf(msg.sender) >= _amount); 
        require(MAIN_TOKEN.allowance(msg.sender, address(this)) > 0);
        if (PoolData.stakedAmount > 0){
            WithdrawAndRecalculateRewards(1); 
        }

        UserInfo storage user = userInfo[msg.sender];
        PoolInfo storage pool = PoolData;
        MAIN_TOKEN.transferFrom(address(msg.sender), address(this), _amount); 
        user.amount = user.amount.add(_amount).add(user.rewardDebt);
        user.rewardDebt = 0;
        pool.stakedAmount = pool.stakedAmount.add(_amount);

        //add user to pool user array
        bool UserIsThere = false;
        address[] storage users = pool.users;
        for (uint256 uid = 0; uid < users.length; ++uid) { 
            address addr = users[uid];
            if (addr == msg.sender){
                UserIsThere = true;
            }
        }


        if (UserIsThere == false) {
            users.push(msg.sender);
        }

        DepositToNewPool();

        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public noReentrant {        
        require(_amount > 100000000000000000); 
        WithdrawAndRecalculateRewards(1);    
        UserInfo storage user = userInfo[msg.sender];        
        require(user.amount.add(user.rewardDebt) >= _amount); 
        
        PoolInfo storage pool = PoolData;        
        MAIN_TOKEN.transfer(address(msg.sender), _amount);
        
        user.amount = user.amount.add(user.rewardDebt).sub(_amount);
        user.rewardDebt = 0;
        pool.stakedAmount = pool.stakedAmount.sub(_amount);

        DepositToNewPool();

        emit Withdraw(msg.sender,  _amount);
    }

    
    function withdrawall() public noReentrant {  
        UserInfo storage user = userInfo[msg.sender];         
        require(user.amount.add(user.rewardDebt) >= 0); 
        WithdrawAndRecalculateRewards(1);         
             
        
        PoolInfo storage pool = PoolData;        

        uint256 all = user.amount.add(user.rewardDebt);
        MAIN_TOKEN.transfer(address(msg.sender), all);
        
        user.amount = 0;
        user.rewardDebt = 0;
        pool.stakedAmount = pool.stakedAmount.sub(all);

        DepositToNewPool();

        emit Withdraw(msg.sender, all);
    }

    function WithdrawAndRecalculateRewards(uint8 swapmode) private {        
        PoolInfo memory pool = PoolData;
        if (MainPoolActivated == 0) {
            IBEP20 rewardToken = IBEP20(PoolData.current.rewardToken());
            if (swapmode < 2) {//es cancel swap o es regular
                pool.current.withdraw(pool.stakedAmount);
            } else { //es emergencyWithdraw
                pool.current.emergencyWithdraw();
            }
            uint256 afterRewardBalance = rewardToken.balanceOf(address(this));
            uint256 beforeMainBalance = MAIN_TOKEN.balanceOf(address(this));            
            if (afterRewardBalance > 0 && swapmode == 1) {
                swapTokensForMain(rewardToken, afterRewardBalance);
                uint256 afterMainBalance = MAIN_TOKEN.balanceOf(address(this));
                uint256 MainReward = afterMainBalance.sub(beforeMainBalance);
        
                uint256 teamReward = MainReward.mul(teamFee).div(1000);
                MAIN_TOKEN.transfer(address(teamAddress), teamReward.div(2));
                MAIN_TOKEN.transfer(address(teamAddress2), teamReward.div(2));
                teamReward = teamReward.div(2) + teamReward.div(2);
                MainReward = MainReward.sub(teamReward);

                for (uint256 uid = 0; uid < pool.users.length; ++uid) { 
                    address addr = pool.users[uid];
                    UserInfo storage currentUser = userInfo[addr];
                    currentUser.rewardDebt = currentUser.rewardDebt.add(MainReward.mul(currentUser.amount.add(currentUser.rewardDebt)).div(pool.stakedAmount));
                }
            }
        } else {             //si estamos en mainpool
            MainPool.withdraw(MainPoolPid, pool.stakedAmount);            
            uint256 beforeMainBalance = MAIN_TOKEN.balanceOf(address(this));
            if (beforeMainBalance > pool.stakedAmount){                                
                uint256 MainReward = beforeMainBalance.sub(pool.stakedAmount);                
                uint256 teamReward = MainReward.mul(teamFee).div(1000);
                MAIN_TOKEN.transfer(address(teamAddress), teamReward.div(2));
                MAIN_TOKEN.transfer(address(teamAddress2), teamReward.div(2));
                teamReward = teamReward.div(2) + teamReward.div(2); 
                MainReward = MainReward.sub(teamReward);                
                for (uint256 uid = 0; uid < pool.users.length; ++uid) { 
                    address addr = pool.users[uid];
                    UserInfo storage currentUser = userInfo[addr];
                    currentUser.rewardDebt = currentUser.rewardDebt.add(MainReward.mul(currentUser.amount.add(currentUser.rewardDebt)).div(pool.stakedAmount));
                }
            }
        }
    }


    function DepositToNewPool() private{
        PoolInfo storage pool = PoolData;
        uint256 afterMainBalance = MAIN_TOKEN.balanceOf(address(this));
        if (MainPoolActivated == 0){
            if (pool.current == pool.next) {
                MAIN_TOKEN.approve(address(pool.current), afterMainBalance);
                pool.current.deposit(afterMainBalance);
                pool.stakedAmount = afterMainBalance;
            } else {
                MAIN_TOKEN.approve(address(pool.next), afterMainBalance);
                pool.next.deposit(afterMainBalance);
                pool.stakedAmount = afterMainBalance;
                pool.current = pool.next;
            } 
        } else {            
            MAIN_TOKEN.approve(address(MainPool), afterMainBalance);
            MainPool.deposit(MainPoolPid, afterMainBalance);
            pool.stakedAmount = afterMainBalance;
        }
    }

    function setTeamAddress(address _teamAddress) public {
        require(msg.sender == teamAddress);
        teamAddress = _teamAddress;
    }

    function setTeamAddress2(address _teamAddress2) public {
        require(msg.sender == teamAddress2);
        teamAddress = _teamAddress2;
    }

    function swapTokensForMain(IBEP20 rewardToken, uint256 tokenAmount) private {
        address[] memory path = new address[](PoolData.currentSwapPath.length + 2);
        path[0] = address(rewardToken);        
        for (uint i=0; i < PoolData.currentSwapPath.length; i++){
            path[i+1] = PoolData.currentSwapPath[i];
        }
        path[PoolData.currentSwapPath.length + 1] = address(MAIN_TOKEN);
        rewardToken.approve(address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);
    }
}