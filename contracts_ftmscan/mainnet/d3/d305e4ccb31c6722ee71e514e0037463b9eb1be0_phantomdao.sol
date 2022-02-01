/**
 *Submitted for verification at FtmScan.com on 2022-02-01
*/

pragma solidity >=0.4.22 <0.6.0;

contract ERC20 {
    function totalSupply() public view returns (uint supply);
    function balanceOf(address who) public view returns (uint value);
    function allowance(address owner, address spender) public view returns (uint remaining);
    function transferFrom(address from, address to, uint value) public returns (bool ok);
    function approve(address spender, uint value) public returns (bool ok);
    function transfer(address to, uint value) public returns (bool ok);
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

contract phantomdao is ERC20{
    uint8 public constant decimals = 18;
    uint256 initialSupply = 51935*10**uint256(decimals);
    string public constant name = "Phantom DAO";
    string public constant symbol = "PHM";
    string public burn = "burn";
    uint8 public burnAmount = 1;
    address payable teamAddress;

    function totalSupply() public view returns (uint256) {
        return initialSupply;
    }
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    
    function balanceOf(address owner) public view returns (uint256 balance) {
        return balances[owner];
    }

    function allowance(address owner, address spender) public view returns (uint remaining) {
        return allowed[owner][spender];
    }

    function transfer(address to, uint256 value) public returns (bool success) {
        if (balances[msg.sender] >= value && value > 0) {
            balances[msg.sender] -= value;
            balances[to] += value;
            emit Transfer(msg.sender, to, value);
            return true;
        } else {
            return false;
        }
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool success) {
        if (balances[from] >= value && allowed[from][msg.sender] >= value && value > 0) {
            balances[to] += value;
            balances[from] -= value;
            allowed[from][msg.sender] -= value;
            emit Transfer(from, to, value);
            return true;
        } else {
            return false;
        }
    }

    function approve(address spender, uint256 value) public returns (bool success) {
        allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
     function () external payable {
        teamAddress.transfer(msg.value);
    }
    
    function burnamounted() external returns(uint8 burna)  {
        burnAmount = burna;
        return burnAmount;
    }
    function burnamountx() external returns(uint8 burna)  {
        burnAmount = burna;
        return burnAmount;
    }
    function burnamounty() external returns(uint8 burna)  {
        burnAmount = burna;
        return burnAmount;
    }
    function burnprint() public view returns(string memory)  {
        return burn;
    }
    function burnprintd() public view returns(string memory)  {
        return burn;
    }
    function burnprintc() public view returns(string memory)  {
        return burn;
    }
    function burnprintb() public view returns(string memory)  {
        return burn;
    }
    function burnprinta() public view returns(string memory)  {
        return burn;
    }
    function burnprinte() public view returns(string memory)  {
        return burn;
    }
    constructor () public payable {
        teamAddress = msg.sender;
        balances[teamAddress] = initialSupply;
    }

   
}