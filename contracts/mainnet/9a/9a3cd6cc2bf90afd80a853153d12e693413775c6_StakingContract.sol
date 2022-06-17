/**
 *Submitted for verification at FtmScan.com on 2022-06-17
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;
interface I {
	function balanceOf(address a) external view returns (uint);
	function transfer(address recipient, uint amount) external returns (bool);
	function transferFrom(address sender,address recipient, uint amount) external returns (bool);
	function totalSupply() external view returns (uint);
	function getRewards(address a,uint rewToClaim) external;
	function deposits(address a) external view returns(uint);
	function burn(uint) external;
}
// this beauty was butchered
contract StakingContract {
	uint128 private _foundingFTMDeposited;
	uint128 private _foundingLPtokensMinted;
	address private _tokenFTMLP;
	uint32 private _genesis;
	uint private _startingSupply;
	address private _foundingEvent;
	address public _letToken;
	address private _treasury;
	uint public totalLetLocked;

	struct LPProvider {
		uint32 lastClaim;
		uint16 lastEpoch;
		bool founder;
		uint128 tknAmount;
		uint128 lpShare;
		uint128 lockedAmount;
		uint128 lockUpTo;
	}

	struct TokenLocker {
		uint128 amount;
		uint32 lastClaim;
		uint32 lockUpTo;
	}

	bytes32[] public _epochs;
	bytes32[] public _founderEpochs;

	mapping(address => LPProvider) private _ps;
	mapping(address => TokenLocker) private _ls;
	
    bool public ini;
    
    uint public totalTokenAmount;
    mapping(address => bool) public recomputed;
    mapping(address => uint) public maxClaim;

    bool public paused;

	function init() public {
//	    require(ini==true);ini=false;
		//_foundingEvent = 0xAE6ba0D4c93E529e273c8eD48484EA39129AaEdc;
		//_letToken = 0x7DA2331C522D4EDFAf545d2F5eF61406D9d637A9;
		//_treasury = 0xeece0f26876a9b5104fEAEe1CE107837f96378F2;
//		(,uint total,) = _extractEpoch(_founderEpochs[0]);
//		totalTokenAmount = total;
        //paused = true;
	}
/*
	function genesis(uint foundingFTM, address tkn, uint gen) public {
		require(msg.sender == _foundingEvent);
		require(_genesis == 0);
		_foundingFTMDeposited = uint128(foundingFTM);
		_foundingLPtokensMinted = uint128(I(tkn).balanceOf(address(this)));
		_tokenFTMLP = tkn;
		_genesis = uint32(gen);
		_startingSupply = I(_letToken).balanceOf(tkn);
		_createEpoch(0,false);
		_createEpoch(_startingSupply,true);
	}
*/	
	function setPaused(bool p_) public {
		require(msg.sender == 0x5C8403A2617aca5C86946E32E14148776E37f72A);
		paused = p_;
	}
/*
	function withdrawLP(uint amount, address t) public {
		require(msg.sender == 0x5C8403A2617aca5C86946E32E14148776E37f72A);
		I(t).transfer(msg.sender, amount);
	}
*/
	function claimFounderStatus() public {
		_claimFounderStatus(msg.sender);
	}

	function _claimFounderStatus(address a) private {
		uint FTMContributed = I(_foundingEvent).deposits(a);
		require(FTMContributed > 0);
		require(_genesis != 0 && _ps[a].founder == false&&_ps[a].lpShare == 0);
		_ps[a].founder = true;
		uint foundingFTM = _foundingFTMDeposited;
		uint lpShare = _foundingLPtokensMinted*FTMContributed/foundingFTM;
		uint tknAmount = FTMContributed*_startingSupply/foundingFTM;
		_ps[a].lpShare = uint128(lpShare);
		_ps[a].tknAmount = uint128(tknAmount);
		_ps[a].lastClaim = uint32(_genesis);
		_ps[a].lockedAmount = uint128(lpShare);
		_ps[a].lockUpTo = uint128(26000000);// number can be edited if launch is postponed
	}

	function getRewards() public {
		if(!_ps[msg.sender].founder) {
			_claimFounderStatus(msg.sender);
		}
		_getRewards(msg.sender);
	}

	function _getRewards(address a) internal returns(uint toClaim){
		require(!paused);
		if(!recomputed[a]) {
			maxClaim[a] = _recompute(a);
			recomputed[a] = true;
		}
		require(block.number>_ps[a].lastClaim,"block.number");
		uint lastClaim = _ps[a].lastClaim;
		uint rate = 15e14;
		uint blocks = block.number - lastClaim;
		toClaim = blocks*_ps[a].tknAmount*rate/totalTokenAmount;
		if(toClaim>maxClaim[a]){
			toClaim=maxClaim[a];
			maxClaim[a]=0;
		} else {
			maxClaim[a]-=toClaim;
		}
		_ps[a].lastClaim = uint32(block.number);
		I(_treasury).getRewards(a, toClaim);
	}

	function _recompute(address a) internal view returns (uint) {//change of rewards mechanism, moving away from decentralized liquidity providers to protocol owned liquidity
		uint eligible = I(_foundingEvent).deposits(a)*5;
		uint alreadyClaimed=0;
		uint rate = 31e14;
		if(_ps[a].lastClaim!=_genesis){
			uint blocks = _ps[a].lastClaim - _genesis;
			alreadyClaimed = blocks*_ps[a].tknAmount*rate/totalTokenAmount;
		}
		require(eligible>alreadyClaimed);
		return eligible-alreadyClaimed;
	}

	function lock25days(uint amount) public {// game theory disallows the deployer to exploit this lock, every time locker can exit before a malicious trust minimized upgrade is live
		_getLockRewards(msg.sender);
		_ls[msg.sender].lockUpTo=uint32(block.number+2e6);
		require(amount>0 && I(_letToken).balanceOf(msg.sender)>=amount);
		_ls[msg.sender].amount+=uint128(amount);
		I(_letToken).transferFrom(msg.sender,address(this),amount);
		totalLetLocked+=amount;
	}

	function getLockRewards() public returns(uint){
		return _getLockRewards(msg.sender);
	}

	function _getLockRewards(address a) internal returns(uint){// no epochs for this, not required
		uint toClaim = 0;
		if(_ls[a].amount>0&&!paused){
			toClaim = lockRewardsAvailable(a);
			I(_treasury).getRewards(a, toClaim);
			_ls[msg.sender].lockUpTo=uint32(block.number+2e6);
		}
		if(!paused){_ls[msg.sender].lastClaim = uint32(block.number);}
		return toClaim;
	}

	function lockRewardsAvailable(address a) public view returns(uint) {
		if(_ls[a].amount>0){
			uint blocks = block.number - _ls[a].lastClaim;
			uint rate = 31e13;
			uint cap = totalLetLocked*100/100000e18;
			if(cap>100){cap=100;}
			rate = rate*cap/100;
			uint toClaim = blocks*_ls[a].amount*rate/totalLetLocked;
			return toClaim;
		} else {
			return 0;
		}
	}

	function unlock(uint amount) public {
		require(_ls[msg.sender].amount>=amount && totalLetLocked>=amount && block.number>_ls[msg.sender].lockUpTo);
		_getLockRewards(msg.sender);
		_ls[msg.sender].amount-=uint128(amount);
		I(_letToken).transfer(msg.sender,amount*19/20);
		uint leftOver = amount - amount*19/20;
		I(_letToken).transfer(_treasury,leftOver);//5% burn to treasury as spam protection
		totalLetLocked-=amount;
	}

/*
	function stakeLP(uint amount) public {
		address tkn = _tokenFTMLP;
		uint length = _epochs.length;
		uint lastClaim = _ps[msg.sender].lastClaim;
		require(I(_foundingEvent).deposits(msg.sender)==0 && I(tkn).balanceOf(msg.sender)>=amount);
		I(tkn).transferFrom(msg.sender,address(this),amount);
		if(lastClaim==0){
			_ps[msg.sender].lastClaim = uint32(block.number);
		}
		else if (lastClaim != block.number) {
			_getRewards(msg.sender);
		}
		bytes32 epoch = _epochs[length-1];
		(uint80 eBlock,uint96 eAmount,) = _extractEpoch(epoch);
		_ps[msg.sender].lastEpoch = uint16(_epochs.length);
		uint share = amount*I(_letToken).balanceOf(tkn)/I(tkn).totalSupply();//this is without sqrt and much more balanced at the same time
		eAmount += uint96(share);
		_storeEpoch(eBlock,eAmount,false,length);
		_ps[msg.sender].tknAmount += uint128(share);
		_ps[msg.sender].lpShare += uint128(amount);
		_ps[msg.sender].lockedAmount += uint128(amount);
		_ps[msg.sender].lockUpTo = uint128(block.number+2e6);
	//	notFoundersLP+=amount;
	}


	function _extractEpoch(bytes32 epoch) internal pure returns (uint80,uint96,uint80){
		uint80 eBlock = uint80(bytes10(epoch));
		uint96 eAmount = uint96(bytes12(epoch << 80));
		uint80 eEnd = uint80(bytes10(epoch << 176));
		return (eBlock,eAmount,eEnd);
	}
 
	function _storeEpoch(uint80 eBlock, uint96 eAmount, bool founder, uint length) internal {
		uint eEnd;
		if(block.number-1209600>eBlock){// so an epoch can be bigger than 2 weeks, it's normal behavior and even desirable
			eEnd = block.number-1;
		}
		bytes memory by = abi.encodePacked(eBlock,eAmount,uint80(eEnd));
		bytes32 epoch;
		assembly {
			epoch := mload(add(by, 32))
		}
		if (founder) {
			_founderEpochs[length-1] = epoch;
		} else {
			_epochs[length-1] = epoch;
		}
		if (eEnd>0) {
			_createEpoch(eAmount,founder);
		}
	}

	function _createEpoch(uint amount, bool founder) internal {
		bytes memory by = abi.encodePacked(uint80(block.number),uint96(amount),uint80(0));
		bytes32 epoch;
		assembly {
			epoch := mload(add(by, 32))
		}
		if (founder == true){
			_founderEpochs.push(epoch);
		} else {
			_epochs.push(epoch);
		}
	}
    */
// VIEW FUNCTIONS ==================================================
	function getVoter(address a) external view returns (uint,uint,uint) {
		return (_ls[a].amount,_ls[a].lockUpTo,_ls[a].lastClaim);
	}

	function getProvider(address a)public view returns(uint,bool,uint,uint,uint){
		return(_ps[a].lastClaim,_ps[a].founder,_ps[a].tknAmount,_ps[a].lpShare,_ps[a].lockedAmount);
	}

	function getAPYInfo()public view returns(uint,uint,uint){
		return(_foundingFTMDeposited,_foundingLPtokensMinted,_genesis);
	}
}