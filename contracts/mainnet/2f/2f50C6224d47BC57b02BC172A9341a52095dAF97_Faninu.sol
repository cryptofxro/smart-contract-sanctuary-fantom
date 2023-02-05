// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
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
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
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

pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

pragma solidity >=0.6.2;

import './IUniswapV2Router01.sol';

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
abstract contract Auth {
  address internal owner;
  mapping(address => bool) internal authorizations;

  constructor(address _owner) {
    owner = _owner;
    authorizations[_owner] = true;
  }

  /**
   * Function modifier to require caller to be contract owner
   */
  modifier onlyOwner() {
    require(isOwner(msg.sender), "!OWNER");
    _;
  }

  /**
   * Function modifier to require caller to be authorized
   */
  modifier authorized() {
    require(isAuthorized(msg.sender), "!AUTHORIZED");
    _;
  }

  /**
   * Authorize address. Owner only
   */
  function authorize(address adr) public onlyOwner {
    authorizations[adr] = true;
  }

  /**
   * Remove address' authorization. Owner only
   */
  function unauthorize(address adr) public onlyOwner {
    authorizations[adr] = false;
  }

  /**
   * Check if address is owner
   */
  function isOwner(address account) public view returns (bool) {
    return account == owner;
  }

  /**
   * Return address' authorization status
   */
  function isAuthorized(address adr) public view returns (bool) {
    return authorizations[adr];
  }

  /**
   * Transfer ownership to new address. Caller must be owner. Leaves old owner authorized
   */
  function transferOwnership(address payable adr) public onlyOwner {
    owner = adr;
    authorizations[adr] = true;
    emit OwnershipTransferred(adr);
  }

  event OwnershipTransferred(address owner);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IERC20.sol";

interface IDividendDistributor {
  function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external;

  function setShare(address shareholder, uint256 amount) external;

  function deposit() external payable;

  function process(uint256 gas) external;
}

contract DividendDistributor is IDividendDistributor {
  using SafeMath for uint256;

  address _token;

  struct Share {
    uint256 amount;
    uint256 totalExcluded; // excluded dividend
    uint256 totalRealised;
  }

  IERC20 WFTM = IERC20(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
  IUniswapV2Router02 router;

  address[] shareholders;
  mapping(address => uint256) shareholderIndexes;
  mapping(address => uint256) shareholderClaims;

  mapping(address => Share) public shares;

  uint256 public totalShares;
  uint256 public totalDividends;
  uint256 public totalDistributed; // to be shown in UI
  uint256 public dividendsPerShare;
  uint256 public dividendsPerShareAccuracyFactor = 10**36;

  uint256 public minPeriod = 1 hours;
  uint256 public minDistribution = 5 * (10**6);

  uint256 currentIndex;

  bool initialized;
  modifier initialization() {
    require(!initialized);
    _;
    initialized = true;
  }

  modifier onlyToken() {
    require(msg.sender == _token);
    _;
  }

  constructor(address _router) {
    router = _router != address(0)
      ? IUniswapV2Router02(_router)
      : IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    _token = msg.sender;
  }

  function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external override onlyToken {
    minPeriod = _minPeriod;
    minDistribution = _minDistribution;
  }

  function setShare(address shareholder, uint256 amount) external override onlyToken {
    if (shares[shareholder].amount > 0) {
      distributeDividend(shareholder);
    }

    if (amount > 0 && shares[shareholder].amount == 0) {
      addShareholder(shareholder);
    } else if (amount == 0 && shares[shareholder].amount > 0) {
      removeShareholder(shareholder);
    }

    totalShares = totalShares.sub(shares[shareholder].amount).add(amount);
    shares[shareholder].amount = amount;
    shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
  }

  function deposit() external payable override onlyToken {
    uint256 balanceBefore = WFTM.balanceOf(address(this));

    address[] memory path = new address[](2);
    path[0] = router.WETH();
    path[1] = address(WFTM);

    router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
      0,
      path,
      address(this),
      block.timestamp
    );

    uint256 amount = WFTM.balanceOf(address(this)).sub(balanceBefore);

    totalDividends = totalDividends.add(amount);
    dividendsPerShare = dividendsPerShare.add(dividendsPerShareAccuracyFactor.mul(amount).div(totalShares));
  }

  function process(uint256 gas) external override onlyToken {
    uint256 shareholderCount = shareholders.length;

    if (shareholderCount == 0) {
      return;
    }

    uint256 gasUsed = 0;
    uint256 gasLeft = gasleft();

    uint256 iterations = 0;

    while (gasUsed < gas && iterations < shareholderCount) {
      if (currentIndex >= shareholderCount) {
        currentIndex = 0;
      }

      if (shouldDistribute(shareholders[currentIndex])) {
        distributeDividend(shareholders[currentIndex]);
      }

      gasUsed = gasUsed.add(gasLeft.sub(gasleft()));
      gasLeft = gasleft();
      currentIndex++;
      iterations++;
    }
  }

  function shouldDistribute(address shareholder) internal view returns (bool) {
    return
      shareholderClaims[shareholder] + minPeriod < block.timestamp && getUnpaidEarnings(shareholder) > minDistribution;
  }

  function distributeDividend(address shareholder) internal {
    if (shares[shareholder].amount == 0) {
      return;
    }

    uint256 amount = getUnpaidEarnings(shareholder);
    if (amount > 0) {
      totalDistributed = totalDistributed.add(amount);
      WFTM.transfer(shareholder, amount);
      shareholderClaims[shareholder] = block.timestamp;
      shares[shareholder].totalRealised = shares[shareholder].totalRealised.add(amount);
      shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
    }
  }

  function claimDividend() external {
    distributeDividend(msg.sender);
  }

  // returns the  unpaid earnings
  function getUnpaidEarnings(address shareholder) public view returns (uint256) {
    if (shares[shareholder].amount == 0) {
      return 0;
    }

    uint256 shareholderTotalDividends = getCumulativeDividends(shares[shareholder].amount);
    uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;

    if (shareholderTotalDividends <= shareholderTotalExcluded) {
      return 0;
    }

    return shareholderTotalDividends.sub(shareholderTotalExcluded);
  }

  function getCumulativeDividends(uint256 share) internal view returns (uint256) {
    return share.mul(dividendsPerShare).div(dividendsPerShareAccuracyFactor);
  }

  function addShareholder(address shareholder) internal {
    shareholderIndexes[shareholder] = shareholders.length;
    shareholders.push(shareholder);
  }

  function removeShareholder(address shareholder) internal {
    shareholders[shareholderIndexes[shareholder]] = shareholders[shareholders.length - 1];
    shareholderIndexes[shareholders[shareholders.length - 1]] = shareholderIndexes[shareholder];
    shareholders.pop();
  }
}

/*

Fantom Inu community token.

- 3/3 tax
- Liquidity Locked
- http://twitter.com/fantom_inu_
- http://t.me/fantom_inu

*/
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./DividendDistributor.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./Auth.sol";

contract Faninu is IERC20, Auth {
  using SafeMath for uint256;

  address private constant ROUTER = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
  address private constant DEAD = 0x000000000000000000000000000000000000dEaD;
  address private constant ZERO = 0x0000000000000000000000000000000000000000;

  string private constant _name = "Fantom Inu";
  string private constant _symbol = "FANINU";
  uint8 private constant _decimals = 18;

  uint256 private _totalSupply = 1_000_000 * (10**_decimals);
  uint256 public _maxTxAmount = _totalSupply.div(50); // 5% (50_000)
  uint256 public _maxWallet = _totalSupply.div(50); // 5% (50_000)

  mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) private _allowances;

  mapping(address => bool) public isFeeExempt;
  mapping(address => bool) public isTxLimitExempt;
  mapping(address => bool) public isDividendExempt;
  mapping(address => bool) public canAddLiquidityBeforeLaunch;

  uint256 private liquidityFee;
  uint256 private buybackFee;
  uint256 private reflectionFee;
  uint256 private investmentFee;
  uint256 private totalFee;
  uint256 public feeDenominator = 10000;

  // Buy Fees
  uint256 public liquidityFeeBuy = 0;
  uint256 public buybackFeeBuy = 0;
  uint256 public reflectionFeeBuy = 0;
  uint256 public investmentFeeBuy = 300;
  uint256 public totalFeeBuy = 300; // 3%
  // Sell Fees
  uint256 public liquidityFeeSell = 0;
  uint256 public buybackFeeSell = 0;
  uint256 public reflectionFeeSell = 0;
  uint256 public investmentFeeSell = 300;
  uint256 public totalFeeSell = 300; // 5%
  // Transfer Fees
  uint256 public liquidityFeeTransfer = 0;
  uint256 public buybackFeeTransfer = 0;
  uint256 public reflectionFeeTransfer = 0;
  uint256 public investmentFeeTransfer = 1;
  uint256 public totalFeeTransfer = 1; // 0.01%

  uint256 public targetLiquidity = 10;
  uint256 public targetLiquidityDenominator = 100;

  IUniswapV2Router02 public router;
  address public pair;

  uint256 public launchedAt;
  uint256 public launchedAtTimestamp;

  // Fees receivers
  address public autoLiquidityReceiver = 0xC0a71Be07FdCfbF9EAC5deF36FEf0d535A0066f8;
  address public investmentFeeReceiver = 0x9f6Af71c76592ccfC394697e2061c21B1080c329;

  bool public autoBuybackEnabled = false;
  uint256 public autoBuybackCap;
  uint256 public autoBuybackAccumulator;
  uint256 public autoBuybackAmount;
  uint256 public autoBuybackBlockPeriod;
  uint256 public autoBuybackBlockLast;

  DividendDistributor public distributor;
  address public distributorAddress;
  uint256 private distributorGas = 500000;

  bool public swapEnabled = true;
  uint256 public swapThreshold = _totalSupply / 2000; // 0.05% (500)
  bool public inSwap;
  modifier swapping() {
    inSwap = true;
    _;
    inSwap = false;
  }

  constructor() Auth(msg.sender) {
    router = IUniswapV2Router02(ROUTER);
    pair = IUniswapV2Factory(router.factory()).createPair(router.WETH(), address(this));
    _allowances[address(this)][address(router)] = _totalSupply;

    distributor = new DividendDistributor(address(router));
    distributorAddress = address(distributor);

    isFeeExempt[msg.sender] = true;
    isTxLimitExempt[msg.sender] = true;

    canAddLiquidityBeforeLaunch[msg.sender] = true;

    isDividendExempt[pair] = true;
    isDividendExempt[address(this)] = true;
    isDividendExempt[DEAD] = true;

    approve(address(router), _totalSupply);
    approve(address(pair), _totalSupply);
    _balances[msg.sender] = _totalSupply;
    emit Transfer(address(0), msg.sender, _totalSupply);
  }

  receive() external payable {}

  function totalSupply() external view override returns (uint256) {
    return _totalSupply;
  }

  function decimals() external pure override returns (uint8) {
    return _decimals;
  }

  function symbol() external pure override returns (string memory) {
    return _symbol;
  }

  function name() external pure override returns (string memory) {
    return _name;
  }

  function getOwner() external view override returns (address) {
    return owner;
  }

  function balanceOf(address account) public view override returns (uint256) {
    return _balances[account];
  }

  function allowance(address holder, address spender) external view override returns (uint256) {
    return _allowances[holder][spender];
  }

  function approve(address spender, uint256 amount) public override returns (bool) {
    _allowances[msg.sender][spender] = amount;
    emit Approval(msg.sender, spender, amount);
    return true;
  }

  function approveMax(address spender) external returns (bool) {
    return approve(spender, _totalSupply);
  }

  function transfer(address recipient, uint256 amount) external override returns (bool) {
    return _transferFrom(msg.sender, recipient, amount);
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external override returns (bool) {
    if (_allowances[sender][msg.sender] != _totalSupply) {
      _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(amount, "Insufficient Allowance");
    }

    return _transferFrom(sender, recipient, amount);
  }

  function _transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) internal returns (bool) {
    if (inSwap) {
      return _basicTransfer(sender, recipient, amount);
    }

    // Avoid lauchpad buyers from ADD LP before launch
    if (!launched() && recipient == pair && sender == pair) {
      require(canAddLiquidityBeforeLaunch[sender]);
    }

    if (!authorizations[sender] && !authorizations[recipient]) {
      require(launched(), "Trading not open yet");
    }

    // max wallet code
    if (
      !authorizations[sender] &&
      recipient != address(this) &&
      recipient != address(DEAD) &&
      recipient != pair &&
      recipient != investmentFeeReceiver &&
      recipient != autoLiquidityReceiver
    ) {
      uint256 heldTokens = balanceOf(recipient);
      require((heldTokens + amount) <= _maxWallet, "Total Holding is currently limited, you can not buy that much.");
    }

    checkTxLimit(sender, amount);

    // Set Fees
    if (sender == pair) {
      buyFees();
    } else if (recipient == pair) {
      sellFees();
    } else {
      transferFees();
    }

    //Exchange tokens
    if (shouldSwapBack()) {
      swapBack();
    }

    if (shouldAutoBuyback()) {
      triggerAutoBuyback();
    }

    _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");

    uint256 amountReceived = shouldTakeFee(sender) ? takeFee(recipient, amount) : amount;

    _balances[recipient] = _balances[recipient].add(amountReceived);

    // Dividend tracker
    if (!isDividendExempt[sender]) {
      try distributor.setShare(sender, balanceOf(sender)) {} catch {}
    }
    if (!isDividendExempt[recipient]) {
      try distributor.setShare(recipient, balanceOf(recipient)) {} catch {}
    }

    try distributor.process(distributorGas) {} catch {}

    emit Transfer(sender, recipient, amountReceived);
    return true;
  }

  function _basicTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal returns (bool) {
    _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
    _balances[recipient] = _balances[recipient].add(amount);
    emit Transfer(sender, recipient, amount);
    return true;
  }

  function checkTxLimit(address sender, uint256 amount) internal view {
    require(amount <= _maxTxAmount || isTxLimitExempt[sender], "TX Limit Exceeded");
  }

  // Internal Functions
  function buyFees() internal {
    liquidityFee = liquidityFeeBuy;
    buybackFee = buybackFeeBuy;
    reflectionFee = reflectionFeeBuy;
    investmentFee = investmentFeeBuy;
    totalFee = totalFeeBuy;
  }

  function sellFees() internal {
    liquidityFee = liquidityFeeSell;
    buybackFee = buybackFeeSell;
    reflectionFee = reflectionFeeSell;
    investmentFee = investmentFeeSell;
    totalFee = totalFeeSell;
  }

  function transferFees() internal {
    liquidityFee = liquidityFeeTransfer;
    buybackFee = buybackFeeTransfer;
    reflectionFee = reflectionFeeTransfer;
    investmentFee = investmentFeeTransfer;
    totalFee = totalFeeTransfer;
  }

  function shouldTakeFee(address sender) internal view returns (bool) {
    return !isFeeExempt[sender];
  }

  function takeFee(address sender, uint256 amount) internal returns (uint256) {
    uint256 feeAmount = amount.mul(totalFee).div(feeDenominator);

    _balances[address(this)] = _balances[address(this)].add(feeAmount);
    emit Transfer(sender, address(this), feeAmount);

    return amount.sub(feeAmount);
  }

  function shouldSwapBack() internal view returns (bool) {
    return msg.sender != pair && !inSwap && swapEnabled && _balances[address(this)] >= swapThreshold;
  }

  function swapBack() internal swapping {
    uint256 dynamicLiquidityFee = isOverLiquified(targetLiquidity, targetLiquidityDenominator) ? 0 : liquidityFee;
    uint256 amountToLiquify = swapThreshold.mul(dynamicLiquidityFee).div(totalFee).div(2);
    uint256 amountToSwap = swapThreshold.sub(amountToLiquify);

    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = router.WETH();

    uint256 balanceBefore = address(this).balance;

    router.swapExactTokensForETHSupportingFeeOnTransferTokens(amountToSwap, 0, path, address(this), block.timestamp);

    uint256 amountETH = address(this).balance.sub(balanceBefore);

    uint256 totalETHFee = totalFee.sub(dynamicLiquidityFee.div(2));

    uint256 amountETHLiquidity = amountETH.mul(dynamicLiquidityFee).div(totalETHFee).div(2);
    uint256 amountETHReflection = amountETH.mul(reflectionFee).div(totalETHFee);
    uint256 amountETHInvestment = amountETH.mul(investmentFee).div(totalETHFee);

    try distributor.deposit{value: amountETHReflection}() {} catch {}
    payable(investmentFeeReceiver).transfer(amountETHInvestment);

    if (amountToLiquify > 0) {
      router.addLiquidityETH{value: amountETHLiquidity}(
        address(this),
        amountToLiquify,
        0,
        0,
        autoLiquidityReceiver,
        block.timestamp
      );
      emit AutoLiquify(amountETHLiquidity, amountToLiquify);
    }
  }

  // BuyBack functions
  function shouldAutoBuyback() internal view returns (bool) {
    return
      msg.sender != pair &&
      !inSwap &&
      autoBuybackEnabled &&
      autoBuybackBlockLast + autoBuybackBlockPeriod <= block.number && // After N blocks from last buyback
      address(this).balance >= autoBuybackAmount;
  }

  function triggerAutoBuyback() internal {
    buyTokens(autoBuybackAmount, DEAD);
    autoBuybackBlockLast = block.number;
    autoBuybackAccumulator = autoBuybackAccumulator.add(autoBuybackAmount);
    if (autoBuybackAccumulator > autoBuybackCap) {
      autoBuybackEnabled = false;
    }
  }

  function triggerZeusBuyback(uint256 amount) external onlyOwner {
    buyTokens(amount, DEAD);
    autoBuybackBlockLast = block.number;
    autoBuybackAccumulator = autoBuybackAccumulator.add(autoBuybackAmount);
    if (autoBuybackAccumulator > autoBuybackCap) {
      autoBuybackEnabled = false;
    }
  }

  function buyTokens(uint256 amount, address to) internal swapping {
    address[] memory path = new address[](2);
    path[0] = router.WETH();
    path[1] = address(this);

    router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(0, path, to, block.timestamp);
  }

  function setAutoBuybackSettings(
    bool _enabled,
    uint256 _cap,
    uint256 _amount,
    uint256 _period
  ) external onlyOwner {
    autoBuybackEnabled = _enabled;
    autoBuybackCap = _cap;
    autoBuybackAccumulator = 0;
    autoBuybackAmount = _amount;
    autoBuybackBlockPeriod = _period;
    autoBuybackBlockLast = block.number;
  }

  // Add extra rewards to holders
  function deposit() external payable onlyOwner {
    try distributor.deposit{value: msg.value}() {} catch {}
  }

  // Process rewards distributions to holders
  function process() external onlyOwner {
    try distributor.process(distributorGas) {} catch {}
  }

  // Stuck Balances Functions
  function rescueToken(address tokenAddress, uint256 tokens) public onlyOwner returns (bool success) {
    return IERC20(tokenAddress).transfer(msg.sender, tokens);
  }

  function clearStuckBalance(uint256 amountPercentage) external onlyOwner {
    uint256 amountETH = address(this).balance;
    payable(investmentFeeReceiver).transfer((amountETH * amountPercentage) / 100);
  }

  function setSellFees(
    uint256 _liquidityFee,
    uint256 _buybackFee,
    uint256 _reflectionFee,
    uint256 _investmentFee
  ) external onlyOwner {
    liquidityFeeSell = _liquidityFee;
    buybackFeeSell = _buybackFee;
    reflectionFeeSell = _reflectionFee;
    investmentFeeSell = _investmentFee;
    totalFeeSell = _liquidityFee + (_buybackFee) + (_reflectionFee) + (_investmentFee);
  }

  function setBuyFees(
    uint256 _liquidityFee,
    uint256 _buybackFee,
    uint256 _reflectionFee,
    uint256 _investmentFee
  ) external onlyOwner {
    liquidityFeeBuy = _liquidityFee;
    buybackFeeBuy = _buybackFee;
    reflectionFeeBuy = _reflectionFee;
    investmentFeeBuy = _investmentFee;
    totalFeeBuy = _liquidityFee + (_buybackFee) + (_reflectionFee) + (_investmentFee);
  }

  function setTransferFees(
    uint256 _liquidityFee,
    uint256 _buybackFee,
    uint256 _reflectionFee,
    uint256 _investmentFee
  ) external onlyOwner {
    liquidityFeeTransfer = _liquidityFee;
    buybackFeeTransfer = _buybackFee;
    reflectionFeeTransfer = _reflectionFee;
    investmentFeeTransfer = _investmentFee;
    totalFeeTransfer = _liquidityFee + (_buybackFee) + (_reflectionFee) + (_investmentFee);
  }

  function setFeeReceivers(address _autoLiquidityReceiver, address _investmentFeeReceiver) external onlyOwner {
    autoLiquidityReceiver = _autoLiquidityReceiver;
    investmentFeeReceiver = _investmentFeeReceiver;
  }

  function launched() internal view returns (bool) {
    return launchedAt != 0;
  }

  function launch() public onlyOwner {
    require(launchedAt == 0, "Already launched boi");
    launchedAt = block.number;
    launchedAtTimestamp = block.timestamp;
  }

  function setMaxWallet(uint256 amount) external onlyOwner {
    require(amount >= _totalSupply / 1000);
    _maxWallet = amount;
  }

  function setTxLimit(uint256 amount) external onlyOwner {
    require(amount >= _totalSupply / 1000);
    _maxTxAmount = amount;
  }

  function setIsDividendExempt(address holder, bool exempt) external onlyOwner {
    require(holder != address(this) && holder != pair);
    isDividendExempt[holder] = exempt;
    if (exempt) {
      distributor.setShare(holder, 0);
    } else {
      distributor.setShare(holder, _balances[holder]);
    }
  }

  function setIsFeeExempt(address holder, bool exempt) external onlyOwner {
    isFeeExempt[holder] = exempt;
  }

  function setIsTxLimitExempt(address holder, bool exempt) external onlyOwner {
    isTxLimitExempt[holder] = exempt;
  }

  function setSwapBackSettings(bool _enabled, uint256 _amount) external onlyOwner {
    swapEnabled = _enabled;
    swapThreshold = _amount;
  }

  function setCanTransferBeforeLaunch(address holder, bool exempt) external onlyOwner {
    canAddLiquidityBeforeLaunch[holder] = exempt; //Presale Address will be added as Exempt
    isTxLimitExempt[holder] = exempt;
    isFeeExempt[holder] = exempt;
  }

  function setTargetLiquidity(uint256 _target, uint256 _denominator) external onlyOwner {
    targetLiquidity = _target;
    targetLiquidityDenominator = _denominator;
  }

  function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external onlyOwner {
    distributor.setDistributionCriteria(_minPeriod, _minDistribution);
  }

  function setDistributorSettings(uint256 gas) external onlyOwner {
    require(gas < 900000);
    distributorGas = gas;
  }

  function getCirculatingSupply() public view returns (uint256) {
    return _totalSupply.sub(balanceOf(DEAD)).sub(balanceOf(ZERO));
  }

  function getLiquidityBacking(uint256 accuracy) public view returns (uint256) {
    return accuracy.mul(balanceOf(pair).mul(2)).div(getCirculatingSupply());
  }

  function isOverLiquified(uint256 target, uint256 accuracy) public view returns (bool) {
    return getLiquidityBacking(accuracy) > target;
  }

  event AutoLiquify(uint256 amountETH, uint256 amountMRLN);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IERC20 {
  function totalSupply() external view returns (uint256);

  function decimals() external view returns (uint8);

  function symbol() external view returns (string memory);

  function name() external view returns (string memory);

  function getOwner() external view returns (address);

  function balanceOf(address account) external view returns (uint256);

  function transfer(address recipient, uint256 amount) external returns (bool);

  function allowance(address _owner, address spender) external view returns (uint256);

  function approve(address spender, uint256 amount) external returns (bool);

  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}