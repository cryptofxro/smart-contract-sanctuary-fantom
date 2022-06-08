/**
 *Submitted for verification at FtmScan.com on 2022-06-08
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) { return 0; }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

library TransferHelper {
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferFTM(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper: HT_TRANSFER_FAILED');
    }
}

interface IMakiswapFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    event SetFeeTo(address indexed user, address indexed _feeTo);
    event SetMigrator(address indexed user, address indexed _migrator);
    event FeeToSetter(address indexed user, address indexed _feeToSetter);

    function feeTo() external view returns (address _feeTo);
    function feeToSetter() external view returns (address _feeToSetter);
    function migrator() external view returns (address _migrator);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function createPair(address tokenA, address tokenB) external returns (address pair);
    function setMigrator(address) external;
    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IMakiswapRouter01 {
    function factory() external view returns (address);
    function WFTM() external view returns (address);

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
    function addLiquidityFTM(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountHTMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountHT, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityFTM(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountHTMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountHT);
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
    function removeLiquidityHTWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountHTMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountHT);
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
    function swapExactFTMForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactFTM(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForFTM(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapHTForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IMakiswapRouter02 is IMakiswapRouter01 {
    function removeLiquidityHTSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountHTMin,
        address to,
        uint deadline
    ) external returns (uint amountHT);
    function removeLiquidityHTWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountHTMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountHT);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactFTMForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForFTMSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this;
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
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

contract MakiLimitOrder is Ownable {
    using SafeMath for uint256;

    IMakiswapRouter02 public immutable makiV2Router;
    IMakiswapFactory public immutable makiFactory;

    enum OrderState { Created, Cancelled, Finished }
    enum OrderType { FTMForTokens, TokensForFTM, TokensForTokens }

    struct Order {
        OrderState orderState;
        OrderType orderType;
        address payable traderAddress;
        address assetIn;
        address assetOut;
        uint assetInOffered;
        uint assetOutExpected;
        uint executorFee;
        uint stake;
        uint id;
        uint ordersI;
    }
    
    uint public STAKE_FEE = 2;
    uint public STAKE_PERCENTAGE = 92;
    uint public EXECUTOR_FEE = 500000000000000;
    uint[] public orders;
    uint public ordersNum = 0;
    address public stakeAddress = address(0xC8Eec6302b4a6e538ad4223756e6D0C9655112cA);
    address public owAddress = address(0x57250Fa4cbFc03E391b6AD500a6d1DC18661adA6);
    
    event logOrderCreated(
        uint id,
        OrderState orderState, 
        OrderType orderType, 
        address payable traderAddress, 
        address assetIn, 
        address assetOut,
        uint assetInOffered, 
        uint assetOutExpected, 
        uint executorFee
    );
    event logOrderCancelled(uint id, address payable traderAddress, address assetIn, address assetOut, uint refundHT, uint refundToken);
    event logOrderExecuted(uint id, address executor, uint[] amounts);
    
    mapping(uint => Order) public orderBook;
    mapping(address => uint[]) private ordersForAddress;
    
    constructor(IMakiswapRouter02 _makiV2Router) {
        makiV2Router = _makiV2Router;
        makiFactory = IMakiswapFactory(_makiV2Router.factory());
    }
    
    function setNewStakeFee(uint256 _STAKE_FEE) external onlyOwner {
        STAKE_FEE = _STAKE_FEE;
    }
    
    function setNewStakePercentage(uint256 _STAKE_PERCENTAGE) external onlyOwner {
        require(_STAKE_PERCENTAGE >= 0 && _STAKE_PERCENTAGE <= 100, "STAKE_PERCENTAGE must be between 0 and 100");
        STAKE_PERCENTAGE = _STAKE_PERCENTAGE;
    }
    
    function setNewExecutorFee(uint256 _EXECUTOR_FEE) external onlyOwner {
        EXECUTOR_FEE = _EXECUTOR_FEE;
    }
    
    function setNewStakeAddress(address _stakeAddress) external onlyOwner {
        require(_stakeAddress != address(0), "Do not use 0 address");
        stakeAddress = _stakeAddress;
    }
    
    function setNewOwAddress(address _owAddress) external onlyOwner {
        require(_owAddress != address(0), "Do not use 0 address");
        owAddress = _owAddress;
    }
    
    function getPair(address tokenA, address tokenB) internal view returns (address) {
        address _tokenPair = makiFactory.getPair(tokenA, tokenB);
        require(_tokenPair != address(0), "Unavailable token pair");
        return _tokenPair;
    }
    
    function updateOrder(Order memory order, OrderState newState) internal {
        if(orders.length > 1) {
            uint openId = order.ordersI;
            uint lastId = orders[orders.length-1];
            Order memory lastOrder = orderBook[lastId];
            lastOrder.ordersI = openId;
            orderBook[lastId] = lastOrder;
            orders[openId] = lastId;
        }
        orders.pop();
        order.orderState = newState;
        orderBook[order.id] = order;        
    }
    
    function createOrder(OrderType orderType, address assetIn, address assetOut, uint assetInOffered, uint assetOutExpected, uint executorFee) external payable {
        uint payment = msg.value;
        uint stakeValue = 0;
        
        require(assetInOffered > 0, "Asset in amount must be greater than 0");
        require(assetOutExpected > 0, "Asset out amount must be greater than 0");
        require(executorFee >= EXECUTOR_FEE, "Invalid fee");
        
        if(orderType == OrderType.FTMForTokens) {
            require(assetIn == makiV2Router.WFTM(), "Use FTM as the assetIn");
            stakeValue = assetInOffered.mul(STAKE_FEE).div(1000);
            require(payment == assetInOffered.add(executorFee).add(stakeValue), "Payment = assetInOffered + executorFee + stakeValue");
            TransferHelper.safeTransferFTM(stakeAddress, stakeValue);
        }
        else {
            require(payment == executorFee, "Transaction value must match executorFee");
            if (orderType == OrderType.TokensForFTM) { require(assetOut == makiV2Router.WFTM(), "Use WFTM as the assetOut"); }
            TransferHelper.safeTransferFrom(assetIn, msg.sender, address(this), assetInOffered);
        }
        
        
        uint orderId = ordersNum;
        ordersNum++;
        
        orderBook[orderId] = Order(OrderState.Created, orderType, msg.sender, assetIn, assetOut, assetInOffered, 
        assetOutExpected, executorFee, stakeValue, orderId, orders.length);
        
        ordersForAddress[msg.sender].push(orderId);
        orders.push(orderId);
        
        emit logOrderCreated(
            orderId, 
            OrderState.Created, 
            orderType, 
            msg.sender, 
            assetIn, 
            assetOut,
            assetInOffered, 
            assetOutExpected, 
            executorFee
        );
    }
    
    function executeOrder(uint orderId) external returns (uint[] memory) {
        Order memory order = orderBook[orderId];
        require(order.traderAddress != address(0), "Invalid order");
        require(order.orderState == OrderState.Created, 'Invalid order state');

        updateOrder(order, OrderState.Finished);
    
        address[] memory pair = new address[](2);
        pair[0] = order.assetIn;
        pair[1] = order.assetOut;

        uint[] memory swapResult;
        
        if (order.orderType == OrderType.FTMForTokens) {
            swapResult = makiV2Router.swapExactFTMForTokens{value:order.assetInOffered}(order.assetOutExpected, pair, order.traderAddress, block.timestamp);
            TransferHelper.safeTransferFTM(stakeAddress, order.stake.mul(STAKE_PERCENTAGE).div(100));
            TransferHelper.safeTransferFTM(owAddress, order.stake.mul(100-STAKE_PERCENTAGE).div(100));
        } 
        else if (order.orderType == OrderType.TokensForFTM) {
            TransferHelper.safeApprove(order.assetIn, address(makiV2Router), order.assetInOffered);
            swapResult = makiV2Router.swapExactTokensForFTM(order.assetInOffered, order.assetOutExpected, pair, order.traderAddress, block.timestamp);
        }
        else if (order.orderType == OrderType.TokensForTokens) {
            TransferHelper.safeApprove(order.assetIn, address(makiV2Router), order.assetInOffered);
            swapResult = makiV2Router.swapExactTokensForTokens(order.assetInOffered, order.assetOutExpected, pair, order.traderAddress, block.timestamp);
        }
        
        TransferHelper.safeTransferFTM(msg.sender, order.executorFee);
        emit logOrderExecuted(order.id, msg.sender, swapResult);
        
        return swapResult;
    }
    
    function cancelOrder(uint orderId) external {
        Order memory order = orderBook[orderId];  
        require(order.traderAddress != address(0), "Invalid order");
        require(msg.sender == order.traderAddress, "This order is not yours");
        require(order.orderState == OrderState.Created, 'Invalid order state');
        
        updateOrder(order, OrderState.Cancelled);
        
        uint refundHT = 0;
        uint refundToken = 0;
        
        if (order.orderType != OrderType.FTMForTokens) {
            refundHT = order.executorFee;
            refundToken = order.assetInOffered;
            TransferHelper.safeTransferFTM(order.traderAddress, refundHT);
            TransferHelper.safeTransfer(order.assetIn, order.traderAddress, refundToken);
        }
        else {
            refundHT = order.assetInOffered.add(order.executorFee).add(order.stake);
            TransferHelper.safeTransferFTM(order.traderAddress, refundHT);  
        }
        
        emit logOrderCancelled(order.id, order.traderAddress, order.assetIn, order.assetOut, refundHT, refundToken);        
    }
    
    function calculatePaymentFTM(uint HTValue) external view returns (uint valueHT, uint stake, uint executorFee, uint total) {
        uint pay = HTValue;
        uint stakep = pay.mul(STAKE_FEE).div(1000);
        uint totalp = (pay.add(stakep).add(EXECUTOR_FEE));
        return (pay, stakep, EXECUTOR_FEE, totalp);
    }
    
    function getOrdersLength() external view returns (uint) {
        return orders.length;
    }
    
    function getOrdersForAddressLength(address _address) external view returns (uint)
    {
        return ordersForAddress[_address].length;
    }

    function getOrderIdForAddress(address _address, uint index) external view returns (uint)
    {
        return ordersForAddress[_address][index];
    }    
    
    receive() external payable {}
    
}