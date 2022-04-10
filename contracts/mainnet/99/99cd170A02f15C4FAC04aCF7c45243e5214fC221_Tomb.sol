// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./SafeMath.sol";
import "./IERC20.sol";
import "./SafeERC20.sol";
import "./IUniswapV2Router02.sol";
import "./UniswapV2Library.sol";
import "./Withdrawable.sol";

contract Tomb is Withdrawable {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address private constant TOMB_FINANCE_TSHARE_REWARDS_POOL = 0xcc0a87F7e7c693042a9Cc703661F5060c80ACb43; 
	address private constant TOMB_FINANCE_ROUTER = 0x6D0176C5ea1e44b08D3dd001b0784cE42F47a3A7; 
	address private constant WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;
	address private constant TOMB = 0x6c021Ae822BEa943b2E66552bDe1D2696a53fbB7;
//  address private constant LP_FTM_TOMB = 0x2A651563C9d3Af67aE0388a5c8F89b867038089e;
	address private constant LP_FTM_TOMB = 0xfca12A13ac324C09e9F43B5e5cfC9262f3Ab3223;
    IUniswapV2Router02 private constant TombRouter = IUniswapV2Router02(TOMB_FINANCE_ROUTER);
 //    percentage = 99999/10000;

	bytes4 private constant FUNC_SELECTOR_DEPOSIT = bytes4(keccak256("deposit(uint256,uint256)"));
	bytes4 private constant FUNC_SELECTOR_WITHDRAW = bytes4(keccak256("withdraw(uint256,uint256)"));
	bytes4 private constant FUNC_SELECTOR_ADD_LIQUIDITY_ETH = bytes4(keccak256("addLiquidityETH(address,uint256,uint256,uint256,address,uint256)"));
//	bytes4 private constant FUNC_SELECTOR_REMOVE_LIQUIDITY = bytes4(keccak256("removeLiquidity(address,uint256,uint256,uint256,address,uint256)"));
	bytes4 private constant FUNC_SELECTOR_REMOVE_LIQUIDITY_ETH = bytes4(keccak256("removeLiquidityETH(address,uint256,uint256,uint256,address,uint256)"));
    bytes4 private constant FUNC_SELECTOR_SWAP_EXACT_TOKENS_FOR_ETH = bytes4(keccak256("swapExactTokensForETH(uint256,uint256,address[],address,uint256)"));
    bytes4 private constant FUNC_SELECTOR_SWAP_EXACT_ETH_FOR_TOKENS = bytes4(keccak256("swapExactETHForTokens(uint256,address[],address,uint256)"));

    uint liquidity;
    uint liquidityDeposited;
    uint amountOfETH;
    

	receive() payable external {}

	constructor() public {
//		IERC20(WFTM).approve(address(TOMB_FINANCE_TSHARE_REWARDS_POOL), type(uint256).max);
//      IERC20(TOMB).approve(address(TOMB_FINANCE_TSHARE_REWARDS_POOL), type(uint256).max);
        IERC20(LP_FTM_TOMB).safeApprove(address(TOMB_FINANCE_TSHARE_REWARDS_POOL), type(uint256).max);
		IERC20(WFTM).safeApprove(address(TOMB_FINANCE_ROUTER), type(uint256).max);
		IERC20(TOMB).safeApprove(address(TOMB_FINANCE_ROUTER), type(uint256).max);
        IERC20(LP_FTM_TOMB).safeApprove(address(TOMB_FINANCE_ROUTER), type(uint256).max);
   }

 /*   function approveWFTM() public{
        IERC20(WFTM).safeApprove(address(this), type(uint256).max);
    }

    function transferWFTM(uint amount) public{
        IERC20(WFTM).safeTransfer(address(this), amount);
    }
*/

 /*   function _swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) public  onlyOwner {
        uint amountIn = (address(this).balance).div(2);
        TombRouter.swapExactETHForTokens(amountOutMin, path, to, deadline);
    }
*/
    function _swapExactETHForTokens(uint256 amountTokenDesired, 
        uint256 amountOutMin, 
        address[] calldata path, 
        address to, 
        uint256 deadline
        ) public  onlyOwner returns (bytes memory){

		bytes memory data = abi.encodeWithSelector(FUNC_SELECTOR_SWAP_EXACT_ETH_FOR_TOKENS, 
        amountOutMin,
        path,
        to,
        deadline
        );

		(bool success, bytes memory returnData) = TOMB_FINANCE_ROUTER.call{value: amountTokenDesired}(data);
		require(success == true, "call failure");
		return returnData;
    }
    
    function _swapExactTokensForETH(uint amountIn, 
        uint amountOutMin, 
        address[] calldata path, 
        address to, 
        uint deadline) public onlyOwner {
        TombRouter.swapExactTokensForETH(amountIn, amountOutMin, path, to, deadline);
    }

	function _deposit(uint256 _pid, uint256 _amount) public  onlyOwner returns (bytes memory) {
		bytes memory data = abi.encodeWithSelector(FUNC_SELECTOR_DEPOSIT, _pid, _amount);
		(bool success, bytes memory returnData) = TOMB_FINANCE_TSHARE_REWARDS_POOL.call(data);
		require(success == true, "call failure");
        liquidity = 0;
        liquidityDeposited += _amount;
		return returnData;
	}

	function _withdraw(uint256 _pid, uint256 _amount) public onlyOwner  returns (bytes memory) {
		bytes memory data = abi.encodeWithSelector(FUNC_SELECTOR_WITHDRAW, _pid, _amount);
		(bool success, bytes memory returnData) = TOMB_FINANCE_TSHARE_REWARDS_POOL.call(data);
		require(success == true, "call failure");
        liquidityDeposited -= _amount;
        liquidity = IERC20(LP_FTM_TOMB).balanceOf(address(this));
		return returnData;
	}

	function _addLiquidityETH(
		address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
		) public  onlyOwner  returns (bytes memory) {
			bytes memory data = abi.encodeWithSelector(FUNC_SELECTOR_ADD_LIQUIDITY_ETH,
			token, 
			amountTokenDesired,
			amountTokenMin,
			amountETHMin,
			to,
			deadline
            );

			(bool success, bytes memory returnData) = TOMB_FINANCE_ROUTER.call{value: getLiquidityETHDesired(amountTokenDesired)}(data);
			require(success == true, "call failure");
			liquidity = IERC20(LP_FTM_TOMB).balanceOf(address(this));
			return returnData;
	}

	function _removeLiquidityETH(
		address token,
        uint256 amount,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
		) public onlyOwner  returns (bytes memory) {
			bytes memory data = abi.encodeWithSelector(FUNC_SELECTOR_REMOVE_LIQUIDITY_ETH,
			token, 
			amount,
			amountTokenMin,
			amountETHMin,
			to,
			deadline
            );

			(bool success, bytes memory returnData) = TOMB_FINANCE_ROUTER.call(data);
			require(success == true, "call failure");
			liquidity = 0;
			return returnData;
	}

    


    function AggregationExecutor_deposit(address[] calldata path) public payable onlyOwner {
        payable(address(this)).transfer(msg.value);
        amountOfETH = address(this).balance;
        uint256 _pid = 3;
//      uint256 _amount = IERC20(LP_FTM_DAI).balanceOf(address(this));
		address token = TOMB;
        uint256 amountTokenDesired;
        uint256 amountTokenMin = 1;
        uint256 amountETHMin = 1;
        uint256 amountOutMin = 1;
        address to = address(this);
        uint256 deadline = (block.timestamp).add(500);
        uint256 amountIn = amountOfETH.div(1995000).mul(999999);


        _swapExactETHForTokens(amountIn, amountOutMin, path, to, deadline);
        amountTokenDesired = IERC20(TOMB).balanceOf(address(this));

        _addLiquidityETH(token, amountTokenDesired, amountTokenMin, amountETHMin, to, deadline);

        _deposit(_pid, liquidity); 
        
        withdraw(ETHER);
    }

    function AggregationExecutor_withdraw(uint256 _amount, address[] calldata path) public  onlyOwner {
        uint256 _pid = 3;
//      uint256 _amount = IERC20(LP_FTM_DAI).balanceOf(address(this));
		address token = TOMB;
        uint256 amountTokenMin = 1;
        uint256 amountETHMin = 1;
        address to = address(this);
        uint256 deadline = (block.timestamp).add(500);
        uint amountIn;
        uint amountOutMin = 1; 

        _withdraw(_pid, _amount); 

        _removeLiquidityETH(token, _amount, amountTokenMin, amountETHMin, to, deadline);

        amountIn = IERC20(TOMB).balanceOf(address(this));
        
        _swapExactTokensForETH(amountIn, amountOutMin, path, to, deadline);

        withdraw(ETHER);
    }

    function getDepositedLiquidity(uint _pid) public view  returns (uint){
        require(_pid == 3, "getDepositedLiduidity failure");
        return liquidityDeposited;
    }


    function getLiquidityETHDesired(uint amountADesired) public returns(uint){
 //     (uint reserveA, uint reserveB) = UniswapV2Library.getReserves(factory, tokenA, tokenB);
        (uint112 _reserve0, uint112 _reserve1,) = IUniswapV2Pair(LP_FTM_TOMB).getReserves();
        uint amountBOptimal = UniswapV2Library.quote(amountADesired, _reserve1, _reserve0);
        return amountBOptimal;
    }




}