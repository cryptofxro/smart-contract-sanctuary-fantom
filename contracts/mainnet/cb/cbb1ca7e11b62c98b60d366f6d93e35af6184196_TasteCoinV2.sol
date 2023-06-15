/**
 *Submitted for verification at FtmScan.com on 2023-06-15
*/

/**
 *Submitted for verification at Etherscan.io on 2023-05-14
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

contract TasteCoinV2 {
    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowance;
    uint public totalSupply = 1000000000000 * 10 ** 18;
    string public name = "TasteCoinV2";
    string public symbol = "TC2";
    uint public decimals = 18;
    address public owner = msg.sender;
    mapping(address => uint) public balanceOfa;
    
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    
    constructor() {
        balances[msg.sender] = totalSupply;
        
    }

        
    function balanceOf(address owner) public returns(uint) {
        return balances[owner];
    }
    
    function transfer(address to, uint value) public returns(bool) {
        require(balanceOf(msg.sender) >= value, 'balance too low');
        balances[to] += value;
        balances[msg.sender] -= value;
       emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint value) public returns(bool) {
        require(balanceOf(from) >= value, 'balance too low');
        require(allowance[from][msg.sender] >= value, 'allowance too low');
        balances[to] += value;
        balances[from] -= value;
        emit Transfer(from, to, value);
        return true;   
    }
    
    function approve(address spender, uint value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;   
    }
    modifier onlyOwner(){

        require(msg.sender == owner);
        _;
    } 
    function _mint(address _to, uint _shares) public onlyOwner{
        
        totalSupply += _shares;
        balanceOfa[_to] += _shares;
    }

    function _burn(address _from, uint _shares) public onlyOwner{
        totalSupply -= _shares;
        balanceOfa[_from] -= _shares;
    }    
        

}