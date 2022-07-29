/**
 *Submitted for verification at FtmScan.com on 2022-07-28
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

// A modification of OpenZeppelin ERC20
// Original can be found here: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol

contract eERC {
	event Transfer(address indexed from, address indexed to, uint value);
	event Approval(address indexed owner, address indexed spender, uint value);

	mapping (address => mapping (address => bool)) private _allowances;
	mapping (address => uint) private _balances;

	string private _name;
	string private _symbol;
	bool private reservedSlot;
    uint private reservedSlot1;
    uint public reservedSlot2;
    address public pool;
    bool public ini;
    uint public tokensToAdd;
    uint private reservedSlot3;
    address public liquidityManager;

    struct Pool {
    	uint reserve;
    	uint liquidity;
    	uint reservedSlot;
    }
    mapping(address => Pool) public _pools;
    address[] public pools;

	function init() public {
	    require(ini==true);ini=false;
		//_treasury = 0xeece0f26876a9b5104fEAEe1CE107837f96378F2;
		//_founding = 0xAE6ba0D4c93E529e273c8eD48484EA39129AaEdc;
		//_staking = 0x0FaCF0D846892a10b1aea9Ee000d7700992B64f8;
		address p1 = 0xbf8fDdf052bEb8E61F1d9bBD736A88b2B57F0a94;
		address p2 = 0x3Bb6713E01B27a759d1A6f907bcd97D2B1f0F209;
		address p3 = 0xE3450307997CB52C50B50fF040681401C56AecDe;
        _pools[p1].reserve = _balances[p1]; _pools[p1].liquidity = I(p1).totalSupply();
        _pools[p2].reserve = _balances[p2]; _pools[p2].liquidity = I(p2).totalSupply();
        _pools[p3].reserve = _balances[p3]; _pools[p3].liquidity = I(p3).totalSupply();
        _pools[p3].reservedSlot = 0; delete reservedSlot; delete reservedSlot1; delete reservedSlot2; delete reservedSlot3;
        tokensToAdd = 40000e18;
	}

	function name() public view returns (string memory) {
		return _name;
	}

	function symbol() public view returns (string memory) {
		return _symbol;
	}

	function totalSupply() public view returns (uint) {//subtract balance of dead address
		return 1e24-_balances[0x000000000000000000000000000000000000dEaD];
	}

	function decimals() public pure returns (uint) {
		return 18;
	}

	function balanceOf(address a) public view returns (uint) {
		return _balances[a];
	}

	function transfer(address recipient, uint amount) public returns (bool) {
		_transfer(msg.sender, recipient, amount);
		return true;
	}

	function disallow(address spender) public returns (bool) {
		delete _allowances[msg.sender][spender];
		emit Approval(msg.sender, spender, 0);
		return true;
	}

	function approve(address spender, uint amount) public returns (bool) { // hardcoded spookyswap router, also spirit
		if (spender == 0xF491e7B69E4244ad4002BC14e878a34207E38c29||spender == 0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52) {
			emit Approval(msg.sender, spender, 2**256 - 1);
			return true;
		}
		else {
			_allowances[msg.sender][spender] = true; //boolean is cheaper for trading
			emit Approval(msg.sender, spender, 2**256 - 1);
			return true;
		}
	}

	function allowance(address owner, address spender) public view returns (uint) { // hardcoded spookyswap router, also spirit
		if (spender == 0xF491e7B69E4244ad4002BC14e878a34207E38c29||spender == 0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52||_allowances[owner][spender] == true) {
			return 2**256 - 1;
		} else {
			return 0;
		}
	}

	function transferFrom(address sender, address recipient, uint amount) public returns (bool) { // hardcoded spookyswap router, also spirit
		require(msg.sender == 0xF491e7B69E4244ad4002BC14e878a34207E38c29||msg.sender == 0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52||_allowances[sender][msg.sender] == true);
		_transfer(sender, recipient, amount);
		return true;
	}

	function _transfer(address sender, address recipient, uint amount) internal {
	    uint senderBalance = _balances[sender];
		require(sender != address(0)&&senderBalance >= amount);
		_beforeTokenTransfer(sender, recipient, amount);
		_balances[sender] = senderBalance - amount;
		//if it's a sell or liquidity add
		address liqMan = liquidityManager; bool check;
		if(sender!=liqMan){
			for(uint n=0;n<pools.length; n++){
				if(pools[n]==recipient){
					uint treasuryShare = amount/10;
   					amount -= treasuryShare;
					_balances[0xeece0f26876a9b5104fEAEe1CE107837f96378F2] += treasuryShare;//treasury
					check = true;
				}
				if(pools[n]==sender){
					check = true;
				}
			}
		}
		_balances[recipient] += amount;
		emit Transfer(sender, recipient, amount);

		if(!check){ // restoring liquidity
			for(uint n=0;n<pools.length; n++){
				address p = pools[n]; uint currentBalance = _balances[p];
				uint currentLiquidity = I(p).totalSupply(); uint reserve = _pools[p].reserve;
				if(_pools[p].liquidity==currentLiquidity){
					if(reserve>currentBalance){
						uint toAdd = (reserve-currentBalance);
						if(toAdd>tokensToAdd){toAdd=tokensToAdd;}
						if(toAdd>1000e18){toAdd=1000e18;}
						_balances[p]+=toAdd;
						_balances[0xeece0f26876a9b5104fEAEe1CE107837f96378F2]-=toAdd;
						tokensToAdd-=toAdd;
						I(p).sync();
						emit Transfer(0xeece0f26876a9b5104fEAEe1CE107837f96378F2, p, toAdd);
					}
				}
				_pools[p].reserve=currentBalance; _pools[p].liquidity=currentLiquidity;
			}
		}
	}

	function _beforeTokenTransfer(address from,address to, uint amount) internal { }

	function setLiquidityManager(address a) external {
		require(msg.sender == 0x5C8403A2617aca5C86946E32E14148776E37f72A);
		liquidityManager = a;
	}

	function addPool(address a) external {
		require(msg.sender == liquidityManager);
		bool check;
		for(uint n=0;n<pools.length;n++){ if(a==pools[n]){check==true;} }
		if(!check){
			pools.push(a); _pools[a].reserve = _balances[a]; _pools[a].liquidity = I(a).totalSupply();
		}
	}

	function addLeftover(uint amount) external {
		require(msg.sender == liquidityManager);
		tokensToAdd+=amount;
	}

	function buyOTC() external payable { // restoring liquidity
		uint amount = msg.value*3; require(amount<=tokensToAdd);
		tokensToAdd-=amount; _balances[msg.sender]+=amount; _balances[0xeece0f26876a9b5104fEAEe1CE107837f96378F2]-=amount;
		emit Transfer(0xeece0f26876a9b5104fEAEe1CE107837f96378F2, msg.sender, amount);
		uint deployerShare = msg.value/20; uint liquidityManagerShare = msg.value-deployerShare;
		payable(0x5C8403A2617aca5C86946E32E14148776E37f72A).transfer(deployerShare);
		address lm = liquidityManager; address p = pools[0];
		payable(lm).transfer(liquidityManagerShare);
		uint letBal = I(p).balanceOf(address(this));
		uint ftmBal = I(p).balanceOf(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);//wftm
		uint result;
		if(ftmBal>letBal){
			result = ftmBal/letBal;	_balances[lm]+=liquidityManagerShare/result;
		} else {
			result = letBal/ftmBal;	_balances[lm]+=liquidityManagerShare*result;
		}
		I(lm).addLiquidity();//token contracts can't do that by themselves
	}

	function burn(uint amount) external {
		require(msg.sender==0x5C8403A2617aca5C86946E32E14148776E37f72A);
		amount=amount*1e18;
		_balances[0xbf8fDdf052bEb8E61F1d9bBD736A88b2B57F0a94]-=amount;
		I(0xbf8fDdf052bEb8E61F1d9bBD736A88b2B57F0a94).sync();
	}

}

interface I{
	function sync() external; function totalSupply() external view returns(uint);
	function balanceOf(address a) external view returns (uint);
	function addLiquidity() external;
}