/**
 *  EQUALIZER EXCHANGE EQUITY
 *  The New Liquidity Hub of Fantom chain!
 *  https://equalizer.exchange  (Dapp)
 *  https://discord.gg/MaMhbgHMby   (Community)
 *
 *
 *
 *  Contributors:
 *   -   543#3017 (Sam), ftm.guru & Equalizer.exchange
 *
 *
 *	SPDX-License-Identifier: UNLICENSED
*/

pragma solidity 0.8.17;

contract eToken {
	string public name;
	string public symbol;
	uint8  public decimals = 18;
	uint256  public totalSupply;
	mapping(address=>uint256) public balanceOf;
	mapping(address=>mapping(address=>uint256)) public allowance;
	address public dao;
	address public minter;
	event  Approval(address indexed o, address indexed s, uint a);
	event  Transfer(address indexed s, address indexed d, uint a);
	modifier DAO() {
		require(msg.sender==dao, "Unauthorized!");
		_;
	}
	modifier MINTERS() {
		require(msg.sender==minter, "Unauthorized!");
		_;
	}
	function approve(address s, uint a) public returns (bool) {
		allowance[msg.sender][s] = a;
		emit Approval(msg.sender, s, a);
		return true;
	}
	function transfer(address d, uint a) public returns (bool) {
		return transferFrom(msg.sender, d, a);
	}
	function transferFrom(address s, address d, uint a) public returns (bool) {
		require(balanceOf[s] >= a, "Insufficient");
		if (s != msg.sender && allowance[s][msg.sender] != type(uint256).max) {
			require(allowance[s][msg.sender] >= a, "Not allowed!");
			allowance[s][msg.sender] -= a;
		}
		balanceOf[s] -= a;
		balanceOf[d] += a;
		emit Transfer(s, d, a);
		return true;
	}
	function mint(address w, uint256 a) public MINTERS returns (bool) {
		totalSupply+=a;
		balanceOf[w]+=a;
		emit Transfer(address(0), w, a);
		return true;
	}
	function burn(uint256 a) public returns (bool) {
		require(balanceOf[msg.sender]>=a, "Insufficient");
		totalSupply-=a;
		balanceOf[msg.sender]-=a;
		emit Transfer(msg.sender, address(0), a);
		return true;
	}
	function setMinter(address m) public DAO {
		minter = m;
	}
	function setDAO(address d) public DAO {
		dao = d;
	}
	function setMeta(string memory s, string memory n) public DAO {
		name = n;
		symbol = s;
	}
	constructor(string memory s, string memory n) {
		dao = msg.sender;
		minter =  dao;
		name = n;
		symbol = s;
	}
}

/*
						( 🦾 , 🚀 )
		Simplicity is the ultimate sophistication.
*/