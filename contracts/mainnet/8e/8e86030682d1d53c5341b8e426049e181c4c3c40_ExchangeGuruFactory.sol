/**
 *Submitted for verification at FtmScan.com on 2022-10-31
*/

/*

FFFFF  TTTTTTT  M   M         GGGGG  U    U  RRRRR     U    U
FF       TTT   M M M M       G       U    U  RR   R    U    U
FFFFF    TTT   M  M  M      G  GGG   U    U  RRRRR     U    U
FF       TTT   M  M  M   O  G    G   U    U  RR R      U    U
FF       TTT   M     M       GGGGG    UUUU   RR  RRR    UUUU



			**************************
			**                      **
			**     Exchange Guru    **
			**                      **
			**     A Multi-Chain    **
			**Decentralized Exchange**
			**                      **
			** A Product created by **
			**   Guru Network DAO   **
			**************************


Create Liquidity, Trade, Farm, & Vault for your own projects for free with MTV.Guru

                        Contact us at:
            https://discord.com/invite/QpyfMarNrV
                    https://t.me/FTM1337

                Powered by Guru Network (🦾,🚀)

*/

// Sources flattened with hardhat v2.0.8 https://hardhat.org

// File exchangeGuru-core/contracts/interfaces/IExchangeGuruFactory.sol

pragma solidity >=0.5.16;

interface IExchangeGuruFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function INIT_CODE_PAIR_HASH() external pure returns (bytes32);
    function feeTo() external view returns (address);
    function protocolFeeDenominator() external view returns (uint8);
    function feeToSetter() external view returns (address);
    function globalSwapFee() external view returns (uint32);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function setSwapFee(uint32 swapFee) external;
    function setProtocolFeeDenominator(uint8 _protocolFee) external;

    function setLocalSwapFee(address pair, uint32 swapFee) external;
    function setLocalProtocolFeeDenominator(address pair, uint8 swapFee) external;
}


// File exchangeGuru-core/contracts/interfaces/IExchangeGuruPair.sol

pragma solidity >=0.5.16;

interface IExchangeGuruPair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function swapFee() external view returns (uint32);
    function getProtocolFeeDenominator() external view returns (uint8);
    function getFeeTo() external view returns (address);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
    function setSwapFee(uint32) external;
    function setLocalProtocolFeeDenominator(uint8) external;
    function setLocalFeeTo(address) external;
}


// File exchangeGuru-core/contracts/interfaces/IExchangeGuruERC20.sol

pragma solidity >=0.5.16;

interface IExchangeGuruERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}


// File exchangeGuru-core/contracts/libraries/SafeMath.sol

pragma solidity =0.5.16;

// a library for performing overflow-safe math, courtesy of DappHub (https://github.com/dapphub/ds-math)

library SafeMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}


// File exchangeGuru-core/contracts/ExchangeGuruERC20.sol

pragma solidity =0.5.16;


contract ExchangeGuruERC20 is IExchangeGuruERC20 {
    using SafeMath for uint;

    uint  public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint) public nonces;

    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    constructor() public {
        uint chainId;
        assembly {
            chainId := chainid
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes('ExchangeGuru Liquidity Position')),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
    }

    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external returns (bool) {
        if (allowance[from][msg.sender] != uint(-1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(deadline >= block.timestamp, 'ExchangeGuruERC20: EXPIRED');
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'ExchangeGuruERC20: INVALID_SIGNATURE');
        _approve(owner, spender, value);
    }
}


// File exchangeGuru-core/contracts/libraries/Math.sol

pragma solidity =0.5.16;

// a library for performing various math operations

library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}


// File exchangeGuru-core/contracts/libraries/UQ112x112.sol

pragma solidity =0.5.16;

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))

// range: [0, 2**112 - 1]
// resolution: 1 / 2**112

library UQ112x112 {
    uint224 constant Q112 = 2**112;

    // encode a uint112 as a UQ112x112
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}


// File exchangeGuru-core/contracts/interfaces/IERC20.sol

pragma solidity >=0.5.16;

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}


// File exchangeGuru-core/contracts/interfaces/IExchangeGuruCallee.sol

pragma solidity >=0.5.16;

interface IExchangeGuruCallee {
    function exchangeGuruFlashLoanCall(address sender, uint amount0, uint amount1, bytes calldata data) external;
}


// File exchangeGuru-core/contracts/ExchangeGuruPair.sol

pragma solidity =0.5.16;







contract ExchangeGuruPair is IExchangeGuruPair, ExchangeGuruERC20 {
    using SafeMath  for uint;
    using UQ112x112 for uint224;

    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint32 public swapFee; // uses this fee as default
    uint8 public localProtocolFeeDenominator = 255; // 255 is the magic number.
    // If value is 255, discard it's local value & use Factory's value. See getProtocolFeeDenominator()
    address public localFeeTo;  // address(0) is the magic number.
    // If value is address(0), discard it's local value & use Factory's value. See getFeeTo()

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'ExchangeGuruPair: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }


    /*  As ExchangeGuruPair inherits ExchangeGuruERC20, ERC20 Meta-data is defined here in ExchangeGuruPair itself.
     *  Using function calls to save call-stack depth, allocated to fee-variables.
     *  Not instantiating name & symbol in constructor helps deploy new tokens that `createPair` in their own constructions.
     *  This aspect is required by most of the Auto-Liquidity & other Special Liquidity-Logic implementing tokens.
     */

    uint8 public constant decimals = 18;

    function name() public view returns(string memory) {
        string(abi.encodePacked("ExchangeGuru Liquidity Position: ", IERC20(token0).name(), " paired with ", IERC20(token1).name()));
    }

    function symbol() public view returns(string memory) {
        string(abi.encodePacked("exchangeGuruLP-", IERC20(token0).symbol(), "/", IERC20(token1).symbol()));
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'ExchangeGuruPair: TRANSFER_FAILED');
    }

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() public {
        factory = msg.sender;
        swapFee = IExchangeGuruFactory(factory).globalSwapFee();
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'ExchangeGuruPair: FORBIDDEN'); // sufficient check
        token0 = _token0;
        token1 = _token1;
    }

    // called by the factory to set the swapFee
    function setSwapFee(uint32 _swapFee) external {
        require(msg.sender == factory, 'ExchangeGuruPair: FORBIDDEN'); // sufficient check
        require(_swapFee <= 1000, 'ExchangeGuruPair: FORBIDDEN_FEE'); // fee percentage check
        swapFee = _swapFee;
    }

    // called by the factory to set the localProtocolFeeDenominator
    function setLocalProtocolFeeDenominator(uint8 _lpfd) external {
        require(msg.sender == factory, 'ExchangeGuruPair: FORBIDDEN'); // sufficient check
        require(_lpfd <= 255, 'ExchangeGuruPair: FORBIDDEN_DENOM'); // fee percentage check
        localProtocolFeeDenominator = _lpfd;
    }

    // called by the factory to set the localFeeTo
    function setLocalFeeTo(address _lft) external {
        require(msg.sender == factory, 'ExchangeGuruPair: FORBIDDEN'); // sufficient check
        localFeeTo = _lft;
    }

    function getProtocolFeeDenominator() public view returns(uint8) {
        if(localProtocolFeeDenominator == 255) {
            return IExchangeGuruFactory(factory).protocolFeeDenominator();
        }
        else {
            return localProtocolFeeDenominator;
        }
    }

    function getFeeTo() public view returns(address) {
        address lft = localFeeTo;
        if(lft == address(0)) {
            return IExchangeGuruFactory(factory).feeTo();
        }
        else {
            return lft;
        }
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'ExchangeGuruPair: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    // if fee is on, mint liquidity equivalent to 1/ (protocolFeeDenominator + ~1) share of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = getFeeTo();
        uint8 protocolFeeDenominator = getProtocolFeeDenominator();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(protocolFeeDenominator).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        }
        else if (_kLast != 0) {
            kLast = 0;
        }
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
           _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'ExchangeGuruPair: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'ExchangeGuruPair: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, 'ExchangeGuruPair: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'ExchangeGuruPair: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, 'ExchangeGuruPair: INVALID_TO');
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
        if (data.length > 0) IExchangeGuruCallee(to).exchangeGuruFlashLoanCall(msg.sender, amount0Out, amount1Out, data);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'ExchangeGuruPair: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
          uint balance0Adjusted = balance0.mul(10000).sub(amount0In.mul(swapFee));
          uint balance1Adjusted = balance1.mul(10000).sub(amount1In.mul(swapFee));
          require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(10000**2), 'ExchangeGuruPair: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    function skim(address to) external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    // force reserves to match balances
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
}


// File exchangeGuru-core/contracts/ExchangeGuruFactory.sol

pragma solidity =0.5.16;


contract ExchangeGuruFactory is IExchangeGuruFactory {
    address public feeTo;
    address public feeToSetter;
    uint32 public globalSwapFee = 96;	//	Default global Swap Fee, per 10k.
    uint8 public protocolFeeDenominator = 1; // uses 1/(1+_) of each swap fee. Range of uint8: 0-255.
    bytes32 public constant INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(ExchangeGuruPair).creationCode));

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address i) public {
        feeToSetter = i;
        feeTo = i;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'ExchangeGuruFactory: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'ExchangeGuruFactory: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'ExchangeGuruFactory: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(ExchangeGuruPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IExchangeGuruPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'ExchangeGuruFactory: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'ExchangeGuruFactory: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function setProtocolFeeDenominator(uint8 _protocolFeeDenominator) external {
        require(msg.sender == feeToSetter, 'ExchangeGuruFactory: FORBIDDEN');
        protocolFeeDenominator = _protocolFeeDenominator;
    }

    function setSwapFee(uint32 _swapFee) external {
        require(msg.sender == feeToSetter, 'ExchangeGuruFactory: FORBIDDEN');
        globalSwapFee = _swapFee;
    }

    function setLocalSwapFee(address _pair, uint32 _swapFee) external {
        require(msg.sender == feeToSetter, 'ExchangeGuruFactory: FORBIDDEN');
        IExchangeGuruPair(_pair).setSwapFee(_swapFee);
    }

    function setLocalProtocolFeeDenominator(address _pair, uint8 _lpfd) external {
        require(msg.sender == feeToSetter, 'ExchangeGuruFactory: FORBIDDEN');
        IExchangeGuruPair(_pair).setLocalProtocolFeeDenominator(_lpfd);
    }

    function setLocalFeeTo(address _pair, address _lft) external {
        require(msg.sender == feeToSetter, 'ExchangeGuruFactory: FORBIDDEN');
        IExchangeGuruPair(_pair).setLocalFeeTo(_lft);
    }
}