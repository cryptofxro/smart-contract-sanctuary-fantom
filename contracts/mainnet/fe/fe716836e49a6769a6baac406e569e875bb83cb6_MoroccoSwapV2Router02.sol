/**
 *Submitted for verification at FtmScan.com on 2022-03-23
*/

/**
 *Submitted for verification at FtmScan.com on 2022-03-21
*/

// File: contracts/swap/interfaces/IMoroccoSwapV2Pair.sol
// SPDX-License-Identifier: GPL-3.0


pragma solidity 0.6.12;

interface IMoroccoSwapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
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

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

// File: contracts/swap/libraries/SafeMath.sol


pragma solidity 0.6.12;

// a library for performing overflow-safe math, courtesy of DappHub (https://github.com/dapphub/ds-math)

library SafeMathMoroccoSwap {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}

// File: contracts/swap/libraries/MoroccoSwapV2Library.sol


pragma solidity 0.6.12;



library MoroccoSwapV2Library {
    using SafeMathMoroccoSwap for uint;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'MoroccoSwapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'MoroccoSwapV2Library: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'd1bc3b611010eadd1578bb6dddb66887634e00de004d0c7965952d261822341a' // init code hash
                
            ))));
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IMoroccoSwapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'MoroccoSwapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'MoroccoSwapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'MoroccoSwapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'MoroccoSwapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'MoroccoSwapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'MoroccoSwapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'MoroccoSwapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'MoroccoSwapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}

// File: contracts/swap/libraries/TransferHelper.sol


pragma solidity 0.6.12;

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

// File: contracts/swap/interfaces/IMoroccoSwapV2Router01.sol


pragma solidity 0.6.12;

interface IMoroccoSwapV2Router01 {
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

// File: contracts/swap/interfaces/IMoroccoSwapV2Router02.sol


pragma solidity 0.6.12;


interface IMoroccoSwapV2Router02 is IMoroccoSwapV2Router01 {
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

// File: contracts/swap/interfaces/IMoroccoSwapV2Factory.sol


pragma solidity 0.6.12;

interface IMoroccoSwapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeToSetter(address) external;
    function PERCENT100() external view returns (uint256);
    function DEADADDRESS() external view returns (address);
    
    function lockFee() external view returns (uint256);
    // function sLockFee() external view returns (uint256);
    function pause() external view returns (bool);
    function InoutTax() external view returns (uint256);
    function swapTax() external view returns (uint256);
    function setRouter(address _router) external ;
    function InOutTotalFee()external view returns (uint256);
    function feeTransfer() external view returns (address);

    function setFeeTransfer(address)external ;
    
}

// File: contracts/swap/interfaces/IERC20.sol


pragma solidity 0.6.12;

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

// File: contracts/swap/interfaces/IWETH.sol


pragma solidity 0.6.12;

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

// File: contracts/swap/interfaces/IBank.sol

pragma solidity 0.6.12;



interface IBank{
    function addReward(address token0, address token1, uint256 amount0, uint256 amount1) external;
     function addrewardtoken(
        address token,
        uint256 amount
    ) external;
}

interface IFarm{
    
     function addLPInfo(
        IERC20 _lpToken,
        IERC20 _rewardToken0,
        IERC20 _rewardToken1
    ) external;

    function addReward(address _lp,address token0, address token1, uint256 amount0, uint256 amount1) external;

    function addrewardtoken(
        address _lp,
        address token,
        uint256 amount
    ) external;

}


// File: contracts/swap/MoroccoSwapFeeTransfer.sol

pragma solidity 0.6.12;


contract MoroccoSwapFeeTransfer {
    using SafeMathMoroccoSwap for uint256;

    uint256 public constant PERCENT100 = 1000000;
    address public constant DEADADDRESS = 0x000000000000000000000000000000000000dEaD;

    address public factory;
    address public router;

    address public roulette;
    address public farm;
    // Bank address
    address public antiBank;
    address public usdtxBank;
    address public goldxBank;
    address public btcxBank;
    address public ethxBank;

    address public storageprovider;
    address public computation;
    address public metaverse;
    address public hotspot;
    address public ligaMatch;
    address public blockReward;

    //Inout fee
    uint256 public bankFee = 1000;
    uint256 public rouletteFee = 500;
    uint256 public blockRewardFee = 2500;
    uint256 public metaverseFee = 1000;
    uint256 public storageFee = 2500;
    uint256 public computationFee = 1000;
    uint256 public totalFee = 12500;

    // Swap fee
    uint256 public sfarmFee = 900;
    uint256 public sLockFee = 500;
    uint256 public sblockRewardFee = 300;
    uint256 public sUSDTxFee = 50;
    uint256 public srouletteFee = 100;
    uint256 public sstorageFee = 300;
    uint256 public scomputationFee = 50;
    uint256 public smetaverseFee = 150;
    uint256 public shotspotFee = 100;
    uint256 public sLigaMatchFee = 50;

    uint256 public swaptotalFee = 2500;

    address public feeSetter;

    constructor(
        address _factory,
        address _router,
        address _feeSetter
    ) public {
        factory = _factory;
        router = _router;
        feeSetter = _feeSetter;
    }

    function takeSwapFee(
        address lp,
        address token,
        uint256 amount
    ) public returns (uint256) {
        uint256 PERCENT = PERCENT100;

        uint256[10] memory fees;
   
        fees[0] = amount.mul(sfarmFee).div(PERCENT); //_sFarmFee
        fees[1] = amount.mul(sLockFee).div(PERCENT); //_sLockFee
        fees[2] = amount.mul(sblockRewardFee).div(PERCENT); //_sblockRewardFee
        fees[3] = amount.mul(sUSDTxFee).div(PERCENT); //_sUSDTxFee
        fees[4] = amount.mul(srouletteFee).div(PERCENT); //_sRouletteFee
        fees[5] = amount.mul(sstorageFee).div(PERCENT); //_sstorageFee
        fees[6] = amount.mul(scomputationFee).div(PERCENT); //_scomputationFee
        fees[7] = amount.mul(smetaverseFee).div(PERCENT); //_smetaverseFee
        fees[8] = amount.mul(shotspotFee).div(PERCENT); //_shotspotFee
        fees[9] = amount.mul(sLigaMatchFee).div(PERCENT); //_sLigaMatchFee

        _approvetokens(token, farm, amount);
        IFarm(farm).addrewardtoken(lp, token, fees[0]);

        TransferHelper.safeTransfer(token, DEADADDRESS, fees[1]);
        TransferHelper.safeTransfer(token, blockReward, fees[2]);

        _approvetokens(token, usdtxBank, amount);
        IBank(usdtxBank).addrewardtoken(token, fees[3]);
        TransferHelper.safeTransfer(token, roulette, fees[4]);

        TransferHelper.safeTransfer(token, storageprovider, fees[5]);
        TransferHelper.safeTransfer(token, computation, fees[6]);
        TransferHelper.safeTransfer(token, metaverse, fees[7]);
        TransferHelper.safeTransfer(token, hotspot, fees[8]);
        TransferHelper.safeTransfer(token, ligaMatch, fees[9]);

    }

    function takeLiquidityFee(
        address _token0,
        address _token1,
        uint256 _amount0,
        uint256 _amount1
    ) public {
        uint256 PERCENT = PERCENT100;

        address[5] memory bankFarm = [
            antiBank,
            usdtxBank,
            goldxBank,
            btcxBank,
            ethxBank
                    ];


        uint256[6] memory bankFee0;
        bankFee0[0] = _amount0.mul(bankFee).div(PERCENT);
        bankFee0[1] = _amount0.mul(rouletteFee).div(PERCENT);
        bankFee0[2] = _amount0.mul(blockRewardFee).div(PERCENT);
        bankFee0[3] = _amount0.mul(metaverseFee).div(PERCENT);
        bankFee0[4] = _amount0.mul(storageFee).div(PERCENT);
        bankFee0[5] = _amount0.mul(computationFee).div(PERCENT);
     

        uint256[6] memory bankFee1;
        bankFee1[0] = _amount1.mul(bankFee).div(PERCENT);
        bankFee1[1] = _amount1.mul(rouletteFee).div(PERCENT);
        bankFee1[2] = _amount1.mul(blockRewardFee).div(PERCENT);
        bankFee1[3] = _amount1.mul(metaverseFee).div(PERCENT);
        bankFee1[4] = _amount1.mul(storageFee).div(PERCENT);
        bankFee1[5] = _amount1.mul(computationFee).div(PERCENT);

        TransferHelper.safeTransfer(_token0, roulette, bankFee0[1]);
        TransferHelper.safeTransfer(_token1, roulette, bankFee1[1]);

        TransferHelper.safeTransfer(_token0, blockReward, bankFee0[2]);
        TransferHelper.safeTransfer(_token1, blockReward, bankFee1[2]);

        TransferHelper.safeTransfer(_token0, metaverse, bankFee0[3]);
        TransferHelper.safeTransfer(_token1, metaverse, bankFee1[3]);

        TransferHelper.safeTransfer(_token0, storageprovider, bankFee0[4]);
        TransferHelper.safeTransfer(_token1, storageprovider, bankFee1[4]);

        TransferHelper.safeTransfer(_token0, computation, bankFee0[5]);
        TransferHelper.safeTransfer(_token1, computation, bankFee1[5]);

        _approvetoken(_token0, _token1, bankFarm[0], _amount0, _amount1);
        _approvetoken(_token0, _token1, bankFarm[1], _amount0, _amount1);
        _approvetoken(_token0, _token1, bankFarm[2], _amount0, _amount1);
        _approvetoken(_token0, _token1, bankFarm[3], _amount0, _amount1);
        _approvetoken(_token0, _token1, bankFarm[4], _amount0, _amount1);

        IBank(bankFarm[0]).addReward(
            _token0,
            _token1,
            bankFee0[0],
            bankFee1[0]
        );
        IBank(bankFarm[1]).addReward(
            _token0,
            _token1,
            bankFee0[0],
            bankFee1[0]
        );
        IBank(bankFarm[2]).addReward(
            _token0,
            _token1,
            bankFee0[0],
            bankFee1[0]
        );
        IBank(bankFarm[3]).addReward(
            _token0,
            _token1,
            bankFee0[0],
            bankFee1[0]
        );
        IBank(bankFarm[4]).addReward(
            _token0,
            _token1,
            bankFee0[0],
            bankFee1[0]
        );

    }

    function _approvetoken(
        address _token0,
        address _token1,
        address _receiver,
        uint256 _amount0,
        uint256 _amount1
    ) private {
        if (
            _token0 != address(0x000) ||
            IERC20(_token0).allowance(address(this), _receiver) < _amount0
        ) {
            IERC20(_token0).approve(_receiver, _amount0);
        }
        if (
            _token1 != address(0x000) ||
            IERC20(_token1).allowance(address(this), _receiver) < _amount1
        ) {
            IERC20(_token1).approve(_receiver, _amount1);
        }
    }

    function _approvetokens(
        address _token,
        address _receiver,
        uint256 _amount
    ) private {
        if (
            _token != address(0x000) ||
            IERC20(_token).allowance(address(this), _receiver) < _amount
        ) {
            IERC20(_token).approve(_receiver, _amount);
        }
    }

    function configure(
        address _roulette,
        address _farm,
        address[5] memory _bank,
        address  _storageprovider,
        address  _computation,
        address  _metaverse,
        address  _hotspot,
        address  _ligaMatch,
        address  _blockReward
    ) external {
        require(msg.sender == feeSetter, "Only fee setter");

        roulette = _roulette;
        farm = _farm;
        antiBank = _bank[0];
        usdtxBank = _bank[1];
        goldxBank = _bank[2];
        btcxBank = _bank[3];
        ethxBank = _bank[4];

        storageprovider = _storageprovider;
        computation = _computation ;
        metaverse = _metaverse ;
        hotspot = _hotspot ;
        ligaMatch = _ligaMatch;
        blockReward = _blockReward;

    }
}

// File: contracts/swap/MoroccoSwapV2Router02.sol


pragma solidity 0.6.12;










contract MoroccoSwapV2Router02 is IMoroccoSwapV2Router02 {
    using SafeMathMoroccoSwap for uint;

    address public immutable override factory;
    address public immutable override WETH;
    
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'MoroccoSwapV2Router: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;
     }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (IMoroccoSwapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IMoroccoSwapV2Factory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = MoroccoSwapV2Library.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = MoroccoSwapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'MoroccoSwapV2Router: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = MoroccoSwapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'MoroccoSwapV2Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = MoroccoSwapV2Library.pairFor(factory, tokenA, tokenB);
        (amountA, amountB) = takeAddLiquidityFee(tokenA, tokenB, amountA, amountB, false);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IMoroccoSwapV2Pair(pair).mint(to);
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = MoroccoSwapV2Library.pairFor(factory, token, WETH);
        IWETH(WETH).deposit{value: amountETH}();        
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
        
        (amountToken, amountETH) = takeAddLiquidityFee(token, WETH, amountToken, amountETH, true);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
       
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IMoroccoSwapV2Pair(pair).mint(to);      
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = MoroccoSwapV2Library.pairFor(factory, tokenA, tokenB);
        IMoroccoSwapV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IMoroccoSwapV2Pair(pair).burn(to);
        (address token0,) = MoroccoSwapV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        if(amountAMin > 0){
            amountAMin = amountAMin.sub(amountAMin.mul(IMoroccoSwapV2Factory(factory).InOutTotalFee()).div(IMoroccoSwapV2Factory(factory).PERCENT100()));
        }
        if(amountBMin > 0){
            amountBMin = amountBMin.sub(amountBMin.mul(IMoroccoSwapV2Factory(factory).InOutTotalFee()).div(IMoroccoSwapV2Factory(factory).PERCENT100()));
        }
        require(amountA >= amountAMin, 'MoroccoSwapV2Router: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'MoroccoSwapV2Router: INSUFFICIENT_B_AMOUNT');
    }

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        address pair = MoroccoSwapV2Library.pairFor(factory, tokenA, tokenB);
        uint value = approveMax ? uint(-1) : liquidity;
        IMoroccoSwapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountToken, uint amountETH) {
        address pair = MoroccoSwapV2Library.pairFor(factory, token, WETH);
        uint value = approveMax ? uint(-1) : liquidity;
        IMoroccoSwapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountETH) {
        address pair = MoroccoSwapV2Library.pairFor(factory, token, WETH);
        uint value = approveMax ? uint(-1) : liquidity;
        IMoroccoSwapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = MoroccoSwapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? MoroccoSwapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            IMoroccoSwapV2Pair(MoroccoSwapV2Library.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amountIn  = takeSwapFee(path[0], path[1], amountIn, false);
        amounts = MoroccoSwapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'MoroccoSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, MoroccoSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }


    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        takeSwapFee(path[0], path[1], amountInMax, false);
        amounts = MoroccoSwapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'MoroccoSwapV2Router: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, MoroccoSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }


    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'MoroccoSwapV2Router: INVALID_PATH');
        uint256 msgvalue = msg.value;
        IWETH(WETH).deposit{value: msgvalue}();
        msgvalue = takeSwapFee(path[0], path[1], msgvalue, true);
        amounts = MoroccoSwapV2Library.getAmountsOut(factory, msgvalue, path);        
        require(amounts[amounts.length - 1] >= amountOutMin, 'MoroccoSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');      
        assert(IWETH(WETH).transfer(MoroccoSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'MoroccoSwapV2Router: INVALID_PATH');
        takeSwapFee(path[0], path[1], amountInMax, false);
        amounts = MoroccoSwapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'MoroccoSwapV2Router: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, MoroccoSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'MoroccoSwapV2Router: INVALID_PATH');
        amountIn = takeSwapFee(path[0], path[1], amountIn, false);
        amounts = MoroccoSwapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'MoroccoSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, MoroccoSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'MoroccoSwapV2Router: INVALID_PATH');
        uint256 msgValue = msg.value;
        IWETH(WETH).deposit{value: msgValue}();
        msgValue = takeSwapFee(path[0], path[1], msgValue, true);
        amounts = MoroccoSwapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'MoroccoSwapV2Router: EXCESSIVE_INPUT_AMOUNT');
        assert(IWETH(WETH).transfer(MoroccoSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        uint256 sfee = msg.value.sub(msgValue);
        if (msg.value > amounts[0].add(sfee)) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0].add(sfee));
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = MoroccoSwapV2Library.sortTokens(input, output);
            IMoroccoSwapV2Pair pair = IMoroccoSwapV2Pair(MoroccoSwapV2Library.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = MoroccoSwapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? MoroccoSwapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        amountIn = takeSwapFee(path[0], path[1], amountIn, false);
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, MoroccoSwapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'MoroccoSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        payable
        ensure(deadline)
    {
        require(path[0] == WETH, 'MoroccoSwapV2Router: INVALID_PATH');
        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        amountIn = takeSwapFee(path[0], path[1], amountIn, true);
        assert(IWETH(WETH).transfer(MoroccoSwapV2Library.pairFor(factory, path[0], path[1]), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'MoroccoSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
    {
        require(path[path.length - 1] == WETH, 'MoroccoSwapV2Router: INVALID_PATH');
        amountIn = takeSwapFee(path[0], path[1], amountIn, false);
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, MoroccoSwapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'MoroccoSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return MoroccoSwapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return MoroccoSwapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return MoroccoSwapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        amounts = MoroccoSwapV2Library.getAmountsOut(factory, amountIn, path);
         if(!IMoroccoSwapV2Factory(factory).pause()){
            uint256 fee = (IMoroccoSwapV2Factory(factory).swapTax());
            uint256 len  = amounts.length.sub(1);
            amounts[len] = amounts[len].sub(amounts[len].mul(fee).div(IMoroccoSwapV2Factory(factory).PERCENT100()));
        }
        return amounts;
    
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        amounts = MoroccoSwapV2Library.getAmountsIn(factory, amountOut, path);
        if(!IMoroccoSwapV2Factory(factory).pause()){
            uint256 fee = (IMoroccoSwapV2Factory(factory).swapTax());
            amounts[0] = amounts[0].add(amounts[0].mul(fee).div(IMoroccoSwapV2Factory(factory).PERCENT100()));
        }
        return amounts;
    }

    function takeAddLiquidityFee(address _token0, address _token1, uint256 _amount0, uint256 _amount1, bool isEth) internal returns(uint256, uint256){
       if(IMoroccoSwapV2Factory(factory).pause() == false){
           
            uint256 PERCENT = IMoroccoSwapV2Factory(factory).PERCENT100();         
            uint256 _totalFees = IMoroccoSwapV2Factory(factory).InoutTax();                    
            uint256 _totalFees0 = _amount0.mul(_totalFees).div(PERCENT);             
            uint256 _totalFees1 =  _amount1.mul(_totalFees).div(PERCENT);
            address feeTransfer = IMoroccoSwapV2Factory(factory).feeTransfer();

            TransferHelper.safeTransferFrom(_token0, msg.sender, feeTransfer, _totalFees0);
            if(!isEth){
                TransferHelper.safeTransferFrom(_token1, msg.sender, feeTransfer, _totalFees1);
            }else{
                TransferHelper.safeTransfer(_token1, feeTransfer, _totalFees1);
            }
           
           MoroccoSwapFeeTransfer(feeTransfer).takeLiquidityFee(_token0, _token1, _amount0, _amount1);
            _amount0 = _amount0.sub(_totalFees0);
            _amount1 = _amount1.sub(_totalFees1);
            return(_amount0, _amount1);
       }else{
           return(_amount0, _amount1);
       }
    }

   function takeSwapFee(address token, address token1, uint256 amount, bool isEth) internal returns(uint256){
        if(IMoroccoSwapV2Factory(factory).pause() == false){
            uint256 PERCENT100 = IMoroccoSwapV2Factory(factory).PERCENT100();            
            uint256 totalFees = amount.mul(IMoroccoSwapV2Factory(factory).swapTax()).div(PERCENT100);

            if(isEth){
                TransferHelper.safeTransfer(token, IMoroccoSwapV2Factory(factory).feeTransfer(), totalFees);
            }else {
                TransferHelper.safeTransferFrom(token, msg.sender,IMoroccoSwapV2Factory(factory).feeTransfer(), totalFees);
            }
            MoroccoSwapFeeTransfer(IMoroccoSwapV2Factory(factory).feeTransfer()).takeSwapFee(
                            MoroccoSwapV2Library.pairFor(factory, token, token1), token,amount);
            amount = amount.sub(totalFees);
            return amount;
        }else{
            return amount;
       }
    }

}