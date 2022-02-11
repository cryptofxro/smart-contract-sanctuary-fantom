/**
 *Submitted for verification at FtmScan.com on 2022-01-23
*/

/*

Telegram:
  http://t.me/FreemsInu

Twitter:
  http://Twitter.com/FreemsInu  

*/



// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;


library SafeMath {
    
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

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

    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}


interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface Antibot {
    function activate() external;
    function process(address from, address to, uint256 amount) external returns(uint256);
    function initiateAntiBot(address token, address pair) external;
}

interface IUniswapV2Router {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
        function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Pair {
    event Sync(uint112 reserve0, uint112 reserve1);
    function sync() external;
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDividendDistributor {
    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external;
    function setShare(address shareholder, uint256 amount) external;
    function deposit() external payable;
    function process(uint256 gas) external  returns (uint256, uint256, uint256);
}

abstract contract Ownable {
    address private _owner;
    mapping(address => bool) private authorized;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = msg.sender;
        _owner = msgSender;
        authorized[msgSender] = true;
        emit OwnershipTransferred(address(0), msgSender);
    }
    
    function owner() public view virtual returns (address) {
        return _owner;
    }
    
    function authorize(address account, bool _authorize) public onlyOwner{
        authorized[account] = _authorize;
    }
    
    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }
    
    modifier onlyAuthorized() {
        require(authorized[msg.sender], "Ownable: caller is not authorized");
        _;
    }
    
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


contract DividendDistributor is IDividendDistributor {
    using SafeMath for uint256;

    address _token;

    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }
 
    IUniswapV2Router router;

    address[] shareholders;
    mapping (address => uint256) shareholderIndexes;
    mapping (address => uint256) shareholderClaims;

    mapping (address => Share) public shares;

    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public dividendsPerShare;
    uint256 public dividendsPerShareAccuracyFactor = 10 ** 36;

    uint256 public minPeriod = 60 minutes;
    uint256 public minDistribution = 1e18 / 10; // 0.1 FTM

    uint256 currentIndex;


    modifier onlyToken() {
        require(msg.sender == _token); _;
    }

    constructor (address _router) {
        router = IUniswapV2Router(_router);
        _token = msg.sender;
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external override onlyToken {
        minPeriod = _minPeriod;
        minDistribution = _minDistribution;
    }

    function setShare(address shareholder, uint256 amount) external override onlyToken {
        if(shares[shareholder].amount > 0){
            distributeDividend(shareholder);
        }

        if(amount > 0 && shares[shareholder].amount == 0){
            addShareholder(shareholder);
        }else if(amount == 0 && shares[shareholder].amount > 0){
            removeShareholder(shareholder);
        }

        totalShares = totalShares.sub(shares[shareholder].amount).add(amount);
        shares[shareholder].amount = amount;
        shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
    }

    function deposit() external payable override  {
        
        uint256 amount = msg.value;

        totalDividends = totalDividends.add(amount);
        dividendsPerShare = dividendsPerShare.add(dividendsPerShareAccuracyFactor.mul(amount).div(totalShares));
    }

    function process(uint256 gas) external override onlyToken returns (uint256, uint256, uint256) {
        uint256 shareholderCount = shareholders.length;

        if(shareholderCount == 0) { return  (0, 0, currentIndex); }

        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();

        uint256 iterations = 0;
        uint256 claims = 0;

        while(gasUsed < gas && iterations < shareholderCount) {
            if(currentIndex >= shareholderCount){
                currentIndex = 0;
            }

            if(shouldDistribute(shareholders[currentIndex])){
                if( distributeDividend(shareholders[currentIndex]) ) {
                     claims++;
                }
            }

            gasUsed = gasUsed.add(gasLeft.sub(gasleft()));
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
        return (iterations, claims, currentIndex);
    }
    
    function shouldDistribute(address shareholder) internal view returns (bool) {
        return shareholderClaims[shareholder] + minPeriod < block.timestamp
                && getUnpaidEarnings(shareholder) > minDistribution;
    }

    function distributeDividend(address shareholder) internal returns (bool) {
        if(shares[shareholder].amount == 0){ return false; }

        uint256 amount = getUnpaidEarnings(shareholder);
        if(amount > 0){
            totalDistributed = totalDistributed.add(amount);
            
            (bool res, ) = payable(shareholder).call{value:amount, gas: 30000}("");res;
            
            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised = shares[shareholder].totalRealised.add(amount);
            shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
            return true;
        }
        return false;
    }
    
    function claimDividend() external {
        distributeDividend(msg.sender);
    }

    function getUnpaidEarnings(address shareholder) public view returns (uint256) {
        if(shares[shareholder].amount == 0){ return 0; }

        uint256 shareholderTotalDividends = getCumulativeDividends(shares[shareholder].amount);
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;

        if(shareholderTotalDividends <= shareholderTotalExcluded){ return 0; }

        return shareholderTotalDividends.sub(shareholderTotalExcluded);
    }

    function getAccount(address _account) public view returns (
            address account,
            int256 index,
            int256 iterationsUntilProcessed,
            uint256 withdrawableDividends,
            uint256 _totalDividends,
            uint256 lastClaimTime,
            uint256 nextClaimTime,
            uint256 secondsUntilAutoClaimAvailable) {
        account = _account;

        index = int256(shareholderIndexes[account]);

        iterationsUntilProcessed = -1;

        if(index >= 0) {
            if(uint256(index) > currentIndex) {
                iterationsUntilProcessed = index - int256(currentIndex);
            }
            else {
                uint256 processesUntilEndOfArray = shareholders.length > currentIndex ?
                                                        shareholders.length.sub(currentIndex) : 0;

                iterationsUntilProcessed = index + int256(processesUntilEndOfArray);
            }
        }


        withdrawableDividends = getUnpaidEarnings(account);
        _totalDividends = shares[account].totalRealised;

        lastClaimTime = shareholderClaims[account];

        nextClaimTime = lastClaimTime > 0 ? lastClaimTime.add(minPeriod) : 0;

        secondsUntilAutoClaimAvailable = nextClaimTime > block.timestamp ? nextClaimTime.sub(block.timestamp) : 0;
    }

    function getCumulativeDividends(uint256 share) internal view returns (uint256) {
        return share.mul(dividendsPerShare).div(dividendsPerShareAccuracyFactor);
    }

    function addShareholder(address shareholder) internal {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }

    function removeShareholder(address shareholder) internal {
        shareholders[shareholderIndexes[shareholder]] = shareholders[shareholders.length-1];
        shareholderIndexes[shareholders[shareholders.length-1]] = shareholderIndexes[shareholder];
        shareholders.pop();
    }
}


contract ERC20 is IERC20 {

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    
    constructor (string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }
    
    function name() public view virtual returns (string memory) {
        return _name;
    }
    
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }
    
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }
    
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }
    
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] - subtractedValue);
        return true;
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        
        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + amount;
        emit Transfer(sender, recipient, amount);
    }
    
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply + amount;
        _balances[account] = _balances[account] + amount;
        emit Transfer(address(0), account, amount);
    }
    
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account] - amount;
        _totalSupply = _totalSupply - amount;
        emit Transfer(account, address(0), amount);
    }
    
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}

contract FreemsInu is ERC20, Ownable {
   
    IUniswapV2Router public uniswapV2Router;
    address public immutable uniswapV2Pair;
    DividendDistributor public distributor;

    bool private swapping;

    address public deadAddress = address(0x0000000000000000000000000000000000000000);
    address public buybackAddress;
    address public marketingAddress;
    address public autoLiquidityReceiver;
    
    uint256 private constant TOTAL_SUPPLY = 1e9; // 1 B tokens
    uint256 private constant DECIMALS = 1e18;
    
    uint256 public maxTx = 5 * TOTAL_SUPPLY / 1000 * (DECIMALS);               // 0.5%  of total supply, 5   M tokens
    uint256 public swapTokensAtAmount = 2 * TOTAL_SUPPLY / 1000 * (DECIMALS);  // 0.2% of total supply,  2   M tokens
    uint256 public maxWallet = 15 * TOTAL_SUPPLY / 1000 * (DECIMALS);          // 1.5%  of total supply, 15  M tokens  

    uint256 public buybackPortion;
    uint256 public liquidityPortion;  
    uint256 public marketingPortion; 
    uint256 public marketingFeeIncrease;
    uint256 public marketingPortionIncrease;
    uint256 public rewardPortion;
    uint256 public buyFee;
    uint256 public sellFee;
    uint256 public totalFees;   
    
    uint256 private nAntiBotBlocks;
    uint256 private numAntiBotBlocks;
    uint256 private launchBlock;
    uint256 private tradeCooldown;
    uint256 private constant FTMRedemption = 100 * 1e18;
    bool private antiBotActive = false;
    bool private hasLaunched = false;
    mapping (address => uint256) timeLastTrade;    
    mapping(address => bool) isPunished;
    
    bool public marketingPush = false;    
    bool public automaticSwapping = true;
    bool public useSwapCooldown = true; 
    uint256 public swapCooldown = 2 minutes;
    uint256 public timeLastSwap = 0;
    uint256 public timeLastWithdraw = 0; 

    uint256 public marketingPushDuration;
    uint256 public marketingPushStart;
    
    uint256 public manualBurnFrequency = 30 minutes;
    uint256 public lastManualLpBurnTime;

    uint256 distributorGas = 300000;

    mapping (address => bool) public isExcludedFromFees;
    mapping (address => bool) public isDividendExempt;
    mapping (address => bool) public isPair;

    event Launch();
    event SetFees(uint256 indexed buyFee, uint256 indexed sellFee, uint256 indexed marketingFeeIncrease);
    event SetFeePortions(uint256 marketingPortion, uint256 liquidityPortion, uint256 buybackPortion, uint256 rewardPortion);    
    event SetTradeRestrictions(uint256 indexed maxTx, uint256 indexed maxWallet);
    event SetSwapTokensAtAmount(uint256 indexed swapTokensAtAmount);  
    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event ManualNukeLP();
    event Punish(address indexed victim);
    event AnitbotInitiated(address indexed antibot);
    event UpdateDistributor(address indexed newAddress, address indexed oldAddress);
    event ProcessedDividend(
    	uint256 iterations,
    	uint256 claims,
        uint256 lastProcessedIndex,
    	bool indexed automatic,
    	uint256 gas,
    	address indexed processor
    );
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived
    );

    
    constructor() ERC20("FreemsInu", "$FRINU", 18) {
        
        uint256 _buyFee = 8;
        uint256 _sellFee = 12;
        uint256 _marketingFeeIncrease = 0;
        
        uint256 _liquidityPortion = 40;
        uint256 _buybackPortion = 20;
        uint256 _marketingPortion = 30;
        uint256 _rewardPortion = 10;
        
        liquidityPortion = _liquidityPortion;
        marketingPortion = _marketingPortion;
        buybackPortion = _buybackPortion;
        marketingFeeIncrease = _marketingFeeIncrease;
        rewardPortion = _rewardPortion;

        buyFee = _buyFee;
        sellFee = _sellFee;        
        totalFees = _liquidityPortion + _buybackPortion + _marketingPortion + _rewardPortion;
        
        IUniswapV2Router _uniswapV2Router = IUniswapV2Router(0xF491e7B69E4244ad4002BC14e878a34207E38c29);

    	distributor = new DividendDistributor(address(_uniswapV2Router));

        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;
        isPair[_uniswapV2Pair] = true;
        
    	marketingAddress = address(0x5b218E76721cbd51A6103417B94016b25f6cCFbe);
        buybackAddress = address(0xCc0eD56068DeaCd40DB619bb2facD7cE6CBb909e);
        autoLiquidityReceiver = msg.sender;
         
        excludeFromFees(deadAddress, true);
        excludeFromFees(address(this), true);
        excludeFromFees(owner(), true);

        isDividendExempt[_uniswapV2Pair] = true;
        isDividendExempt[address(uniswapV2Router)] = true;
        isDividendExempt[address(this)] = true;
        isDividendExempt[deadAddress] = true;

        /*
            _mint is an internal function in that is only called here,
            and CANNOT be called ever again.
        */
        _mint(owner(), TOTAL_SUPPLY * (DECIMALS));
    }
    
    modifier inSwap {
        swapping = true;
        _;
        swapping = false;
    }
    
    Antibot antibot;
    function initiateAntiBot(address _antibot) public onlyOwner{
        antibot = Antibot(_antibot);
        antibot.initiateAntiBot(address(this), address(uniswapV2Pair));
        emit AnitbotInitiated(_antibot);
    }

    function setWallets(address _marketingAddress, address _buybackAddress, address _autoLiquidityReceiver) external onlyOwner{
        marketingAddress = _marketingAddress;
        buybackAddress = _buybackAddress;
        autoLiquidityReceiver = _autoLiquidityReceiver;
    }
    
    uint256 launchDurationBlocks;
    function launch(uint256 _launchDurationBlocks) public onlyOwner{
        require(!hasLaunched, "Project already launched.");
        require(_launchDurationBlocks <= 100, "Launch duration may not last longer than 5 minutes.");
        antibot.activate();
        antiBotActive = true;
        launchDurationBlocks = _launchDurationBlocks;        
        launchBlock = block.number;        
        hasLaunched = true;
        emit Launch();
    }

    function punish(address victim) external onlyOwner {
        isPunished[victim] = true;
        emit Punish(victim);
    }

    function updateUniswapV2Router(address newAddress) public onlyOwner {
        require(newAddress != address(uniswapV2Router), "The router already has that address");
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router(newAddress);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(isExcludedFromFees[account] != excluded, "Account is already the value of 'excluded'");
        isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }
    
    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != uniswapV2Pair, "The pair cannot be removed from automatedMarketMakerPairs");
    
        isPair[pair] = value;
        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateDistributor(address newAddress) public onlyOwner {
        require(newAddress != address(distributor), "The distributor already has that address");
        distributor = new DividendDistributor(address(uniswapV2Router));
        DividendDistributor newDistributor = DividendDistributor(payable(newAddress));

        emit UpdateDistributor(newAddress, address(distributor));
        distributor = newDistributor;
    }

    function setIsDividendExempt(address holder, bool exempt) external onlyOwner {
        require(holder != address(this) && holder != uniswapV2Pair);
        
        isDividendExempt[holder] = exempt;
        if(exempt){
            distributor.setShare(holder, 0);
        }else{
            distributor.setShare(holder, balanceOf(holder));
        }
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external onlyOwner {
        distributor.setDistributionCriteria(_minPeriod, _minDistribution);
    }

    function setDistributorSettings(uint256 gas) external onlyOwner {
        require(gas < 750000);
        distributorGas = gas;
    }

    function getAccountDividendsInfo(address account)
        external view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
        return distributor.getAccount(account);
    }
    
    function claim() external {
		distributor.claimDividend();
    }

    function processDividend(uint256 gas) external onlyOwner {
		(uint256 iterations, uint256 claims, uint256 lastProcessedIndex) = distributor.process(gas);
		emit ProcessedDividend(iterations, claims, lastProcessedIndex, false, gas, tx.origin);
    }
 
    function modifyTaxPortions(uint256 _marketingPortion, uint256 _liquidityPortion, uint256 _buybackPortion, uint256 _rewardPortion) public onlyOwner{
        require(0 <= _liquidityPortion && _liquidityPortion <= 50 , "Requested liquidity portion not within acceptable range.");
        require(0 <= _marketingPortion && _marketingPortion <= 50, "Requested marketing portion not within acceptable range.");
        require(0 <= _buybackPortion && _buybackPortion <= 50, "Requested buyback portion not within acceptable range.");
        require(0 <= _rewardPortion && _rewardPortion <= 50, "Requested rewardPortion portion not within acceptable range.");
        require( _marketingPortion + _liquidityPortion + _buybackPortion + _rewardPortion == 100,
         "Total fee percentage must be equal to 100.");
        
        liquidityPortion = _liquidityPortion;
        marketingPortion = _marketingPortion; 
        buybackPortion = _buybackPortion; 
        rewardPortion = _rewardPortion; 
        totalFees = _liquidityPortion + _marketingPortion + _buybackPortion + _rewardPortion;        
        emit SetFeePortions(marketingPortion, liquidityPortion, buybackPortion, rewardPortion);  
    }
    
    function modifyTaxes(uint256 _buyFee, uint256 _sellFee, uint256 _marketingFeeIncrease) public onlyOwner{
        require(0 <= _buyFee && _buyFee <= 20 , "Requested buy fee not within acceptable range.");
        require(0 <= _sellFee && _sellFee <= 20, "Requested sell fee not within acceptable range.");                
        require(0 <= _marketingFeeIncrease && _marketingFeeIncrease <= 15, "Requested marketing fee increase not within acceptable range.");   
                        
        buyFee = _buyFee;
        sellFee = _sellFee; 
        marketingFeeIncrease = _marketingFeeIncrease; 
                
        emit SetFees(buyFee, sellFee, marketingFeeIncrease);  
    }
    
    function setTradeRestrictions(uint256 _maxTx, uint256 _maxWallet) public onlyOwner{
        require(_maxTx >= (5 * TOTAL_SUPPLY / 1000), "Requested max transaction amount too low.");
        require(_maxWallet >= (15 * TOTAL_SUPPLY / 1000), "Requested max allowable wallet amount too low.");
        
        maxTx = _maxTx * DECIMALS;
        maxWallet = _maxWallet * DECIMALS;
        
        emit SetTradeRestrictions(maxTx, maxWallet);
    }

    function setSwapSettings(uint256 _swapTokensAtAmount, uint256 _swapCooldown) public onlyOwner{
        require(5 * TOTAL_SUPPLY / 1000 <= _swapTokensAtAmount && _swapTokensAtAmount <= 2 * TOTAL_SUPPLY / 100,
        "Requested contract swap amount out of acceptable range.");
        require(_swapCooldown <= 5 minutes, "Swaps too infrequent, tokens may accumulate.");
        
        swapTokensAtAmount = _swapTokensAtAmount * DECIMALS;
        swapCooldown = _swapCooldown;
         
         emit SetSwapTokensAtAmount(swapTokensAtAmount);  
    }
    
    function checkValidTrade(address from, address to, uint256 amount) private view {
        if (from != owner() && to != owner() && !isExcludedFromFees[from]) {
            require(hasLaunched, "Project has yet to launch.");
            require(amount <= maxTx, "Transfer amount exceeds the maxTxAmount."); 
            if (isPair[from]){
                require(balanceOf(address(to)) + amount <= maxWallet, "Token purchase implies maxWallet violation.");
            }
        } 
    }
    
    function _transfer(address from, address to, uint256 amount) internal override {
        if(amount == 0) {
            super._transfer(from, to, 0);
            return;
        }
    
        checkValidTrade(from, to, amount);
        bool takeFee = hasLaunched && !swapping;
        
        if(isExcludedFromFees[from] || isExcludedFromFees[to]) {
            takeFee = false;
        }
        
        if(takeFee) {
           uint256 fees;
           if(antiBotActive){
               if(block.number < launchBlock + launchDurationBlocks){                   
                    fees = antibot.process(from, to, amount);
                }
                else{
                    //Automatic disabling of antibot
                    antiBotActive = false;
                    uint256 fee = calculateFee(from, to, amount);
                    fees = amount * fee / 100;
                }
           }
           else{
            uint256 fee = calculateFee(from, to, amount);
            fees = amount * fee / 100;   
           }
           amount = amount - fees;
           super._transfer(from, address(this), fees);
        }

        if(shouldSwap(from)) {
            swapTokens(swapTokensAtAmount);
            timeLastSwap = block.timestamp;
        }
        super._transfer(from, to, amount);

        if(!isDividendExempt[from]) {
            try distributor.setShare(from, balanceOf(from)) {} catch {}
        }

        if(!isDividendExempt[to]) {
            try distributor.setShare(to, balanceOf(to)) {} catch {} 
        }

        try distributor.process(distributorGas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) 
        {
            emit ProcessedDividend(iterations, claims, lastProcessedIndex, true, distributorGas, tx.origin);
        } catch {}
    }
    
    function calculateFee(address from, address to, uint256 amount) private returns (uint256){
        uint256 fee;

        if(isPunished[to]){            
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = uniswapV2Router.WETH();            
            uint256 estimatedBNBValue = uniswapV2Router.getAmountsOut(amount, path)[1];
            if(estimatedBNBValue >= FTMRedemption){
                isPunished[to] = false;    
            }
            fee = buyFee;
            return fee;
        }
        else if(isPunished[from]){
            fee = 40;
            return fee;    
        }

        if(marketingPush){
            uint256 fullTime = marketingPushStart  + marketingPushDuration;
            if(block.timestamp < fullTime){
                fee = isPair[from] ? buyFee : sellFee + marketingFeeIncrease;
                return fee;
            }
            else{
                fee = isPair[from] ? buyFee : sellFee;
                marketingPush = false;
                marketingFeeIncrease = 0;
                marketingPortionIncrease = 0;
                return fee;
            }
        }
        else{
            fee = isPair[from] ? buyFee : sellFee;
            return fee;
        }
    }
    
    function shouldSwap(address from) private view returns (bool){
        uint256 contractTokenBalance = balanceOf(address(this));
        bool hasEnoughTokens = contractTokenBalance >= swapTokensAtAmount;
        bool validSwapTime;
        if(useSwapCooldown){
            validSwapTime = block.timestamp >= timeLastSwap + swapCooldown;
        }   
        else{
            validSwapTime = true;
        }
        return !swapping && hasEnoughTokens && automaticSwapping && validSwapTime && 
        !isPair[from] && hasLaunched && !antiBotActive;
    }    

    function toggleAutomaticSwap() external onlyAuthorized {
        automaticSwapping = automaticSwapping == true ? false : true;
    }
    
    function toggleSwapCooldown() external onlyAuthorized {
        useSwapCooldown = useSwapCooldown == true ? false : true;
    }

    function manualSwap() external onlyAuthorized {
        swapTokens(swapTokensAtAmount);
    }
    function getNumSwapAvailable() external view onlyAuthorized returns (uint256) {
        return balanceOf(address(this)) / swapTokensAtAmount;
    }

    function swapTokens(uint256 tokens) private inSwap {  

        uint256 _totalFees = (marketingPush ? 
        totalFees + marketingPortionIncrease : totalFees);               

        uint256 LPtokens = tokens * liquidityPortion / _totalFees;
        
        uint256 halfLPTokens = LPtokens / 2;
        uint256 marketingtokens = tokens * (marketingPortion + marketingPortionIncrease) /
         _totalFees;
        
        uint256 buybackTokens = tokens * buybackPortion /_totalFees ;
        
        uint256 rewardTokens = tokens - halfLPTokens - marketingtokens - buybackTokens;
        uint256 swapAmount = halfLPTokens + marketingtokens + buybackTokens + rewardTokens;
        uint256 initialBalance = address(this).balance;

        swapTokensForEth(swapAmount); 
         
        uint256 newBalance = address(this).balance - initialBalance;
        
        uint256 BNBForLP = newBalance * halfLPTokens / swapAmount;
        uint256 BNBForBuyback = newBalance * buybackTokens / swapAmount;
        uint256 BNBForReward = newBalance * rewardTokens / swapAmount;

        (bool temp,) = payable(buybackAddress).call{value: BNBForBuyback, gas: 30000}(""); 
        try distributor.deposit{value: BNBForReward}() {} catch {}

        if(halfLPTokens > 0){
            addLiquidity(halfLPTokens, BNBForLP);
            emit SwapAndLiquify(halfLPTokens, BNBForLP);
        }
        uint256 BNBForMarketing = address(this).balance;
        (temp,) = payable(marketingAddress).call{value: BNBForMarketing, gas: 30000}(""); 
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
 
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }
    
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
       uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            autoLiquidityReceiver,
            block.timestamp
        );
    }

    function doMarketingPush(uint256 _minutes, uint256 _marketingFeeIncrease, uint256 _marketingPortionIncrease) external onlyAuthorized{
        require(_minutes <= 60, "Rush may not last over two hours.");
        require(_marketingFeeIncrease <= 15, "Only an additional tax of 15% allocated to marketing is permitted.");
        require(_marketingPortionIncrease <= 60, "Only an additional portion of 60% allocated to marketing is permitted.");
        marketingPush = true;
        marketingPushDuration = _minutes * 1 minutes;
        marketingPushStart = block.timestamp;
        marketingFeeIncrease = _marketingFeeIncrease;
        marketingPortionIncrease = _marketingPortionIncrease;
    }

    // Keep that chart healthy
    function buybackToLiquidity(uint256 slippage) payable public onlyAuthorized{ 

        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);

        uint256 buyBackAmount = msg.value/2;
        uint256 liquidityBNB = msg.value - buyBackAmount;

        uint256 estimatedBuyback = uniswapV2Router.getAmountsOut(buyBackAmount, path)[1];

        uint256 tokenBalanceBefore = balanceOf(msg.sender);
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: buyBackAmount}(
            estimatedBuyback * (100 - slippage) / 100,  
            path,
            msg.sender, 
            block.timestamp
        );

        uint256 tokenAmount = balanceOf(msg.sender) - tokenBalanceBefore;
        // _approve(msg.sender, address(this), tokenAmount);
        transfer(address(this), tokenAmount);
                
        addLiquidity(tokenAmount, liquidityBNB);
    } 


    
    // Keep that LP-ratio healthy
    function manualBurnLiquidityPairTokens(uint256 percent) external onlyAuthorized returns (bool){
        require(block.timestamp > lastManualLpBurnTime + manualBurnFrequency , "Must wait for cooldown to finish");
        require(percent <= 1000, "May not nuke more than 10% of tokens in LP");
        lastManualLpBurnTime = block.timestamp;
    
        uint256 liquidityPairBalance = this.balanceOf(uniswapV2Pair);

        uint256 amountToBurn = liquidityPairBalance * percent / 10000;

        if (amountToBurn > 0){
            super._transfer(uniswapV2Pair, address(0xdead), amountToBurn);
        }

        IUniswapV2Pair pair = IUniswapV2Pair(uniswapV2Pair);
        pair.sync();
        emit ManualNukeLP();
        return true;
    }

    /*
    This function allows for 
      1. development of long-term utilty such as staking pools and
      2. withdrawing of mistransferred tokens
      Note the time-restriction placed on withdrawals, for the safety of our investors.
    */ 
    function withdrawTokens(address token, uint256 amount) external onlyAuthorized {
        if(token == address(this)){
            require(block.timestamp > timeLastWithdraw + 24 hours && 
            amount <= 2 * balanceOf(address(this)) / 100 , "A maximum of 2% of token supply may be withdrawn each 24 hours.");    
        }
        timeLastWithdraw = block.timestamp;
        IERC20(token).transfer(msg.sender, amount);
    }

    receive() external payable {}
}