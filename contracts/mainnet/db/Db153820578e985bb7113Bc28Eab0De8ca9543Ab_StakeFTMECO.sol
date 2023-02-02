/**
 *Submitted for verification at FtmScan.com on 2023-02-02
*/

/**
 *Submitted for verification
*/

// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.0;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
	
    function _msgData() internal view virtual returns (bytes memory) {
        this;
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;
	
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
	
    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }
	
    function owner() public view virtual returns (address) {
        return _owner;
    }
	
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
	
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }
	
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
	function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
	function isExcludedFromFee(address account) external view returns (bool);
}

library Address {
    
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
	
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }
  
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }
   
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
	
    function verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

library SafeBEP20 {
    using Address for address;
	
    function safeTransfer(IBEP20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IBEP20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }
	
    function _callOptionalReturn(IBEP20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeBEP20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeBEP20: BEP20 operation did not succeed");
        }
    }
}

contract StakeFTMECO is Ownable, ReentrancyGuard {

    using SafeBEP20 for IBEP20;
	
    uint256 public minStaking = 500 * 10**18;
	uint256 public APR = 24000;
	uint256 public poolFee;
	uint256 public totalStaked;
	
    IBEP20 public stakedToken = IBEP20(0xF617D76f0fE3Bfb19A2CA003521685ceC84ABD3d);
	
    mapping(address => UserInfo) internal userInfo;
	uint256 constant TIME_STEP = 365 days;
	
	bool public paused = false;
	
	modifier whenNotPaused() {
		require(!paused, "Contract is paused");
		_;
	}
	
	modifier whenPaused() {
		require(paused, "Contract is unpaused");
		_;
	}
	
    struct UserInfo {
        uint256 amount; 
		uint256 rewardRemaining;
		uint256 rewardWithdrawal;
        uint256 startTime;
    }
	
    event MigrateTokens(address tokenRecovered, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event NewAPR(uint256 APR);
    event MinStakePerUser(uint256 minStakePerUser);
    event Withdraw(address indexed user, uint256 amount);
	event NewPoolFee(uint256 newFee);
	event Pause();
    event Unpause();
	
    constructor() {}
	
    function deposit(uint256 amount) external nonReentrant{
	    UserInfo storage user = userInfo[msg.sender];
		
		require(!paused, "Deposit is paused");
		require(stakedToken.balanceOf(msg.sender) >= amount, "Balance not available for staking");
		require(stakedToken.isExcludedFromFee(address(this)), "Contract address is not excluded from fee");
		require(amount >= minStaking, "Amount is less than minimum staking amount");
		
		uint256 pending = pendingreward(msg.sender);
		
		user.amount = user.amount + amount;
		user.rewardRemaining = user.rewardRemaining + pending;
		user.startTime = block.timestamp;
		
		totalStaked = totalStaked + amount;
		
		stakedToken.safeTransferFrom(address(msg.sender), address(this), amount);
        emit Deposit(msg.sender, amount);
    }
	
    function withdraw() external nonReentrant{
	    UserInfo storage user = userInfo[msg.sender];
		require(user.amount > 0, "Amount is not staked");
		
		uint256 amount   = user.amount;
		uint256 pending  = pendingreward(msg.sender);
		uint256 reward   = user.rewardRemaining + pending;
		uint256 fee      = (reward * poolFee) / 10000;
		
		totalStaked = totalStaked - amount;
		
		if(stakedToken.balanceOf(address(this)) >= amount + reward - fee)
		{
		    user.rewardRemaining = 0;
			user.amount = 0;
			user.rewardWithdrawal = 0;
			
			stakedToken.safeTransfer(address(msg.sender), amount + reward - fee);
			emit Withdraw(msg.sender, amount + reward - fee);
		}
		else
		{
		    require(stakedToken.balanceOf(address(this)) >= amount, "Token balance not available for withdraw");
			
			user.rewardRemaining = reward;
			user.amount = 0;
			
			stakedToken.safeTransfer(address(msg.sender), amount);
			emit Withdraw(msg.sender, amount);
			
		}
    }
	
	function withdrawReward() external nonReentrant{
		UserInfo storage user = userInfo[msg.sender];
		
		uint256 pending = pendingreward(msg.sender);
		uint256 reward  = user.rewardRemaining + pending;
		uint256 fee     = (reward * poolFee) / 10000;
		
		require(reward > 0, "Reward amount is zero");
		require(stakedToken.balanceOf(address(this)) >= reward - fee, "Token balance not available for withdraw");
		
		if(user.amount > 0)
		{
		   user.rewardWithdrawal = user.rewardWithdrawal + reward;
		   user.rewardRemaining = 0;
		   user.startTime = block.timestamp;
		}
		else
		{
		   user.rewardWithdrawal = 0;
		   user.rewardRemaining = 0;
		}
		
		stakedToken.safeTransfer(address(msg.sender), reward-fee);
		emit Withdraw(msg.sender, reward);
    }
	
	function pendingreward(address _user) public view returns (uint256) {
        UserInfo storage user = userInfo[_user];
		if(user.amount > 0)
		{
			uint256 sTime  = user.startTime;
			uint256 eTime  = block.timestamp;
			uint256 reward = (uint(user.amount) * (APR) * (eTime-sTime)) / (TIME_STEP * 10000);
			return reward;
		}
		else
		{
		    return 0;
		}
    }
	
	function getUserInfo(address userAddress) public view returns (uint256, uint256, uint256, uint256) {
        UserInfo storage user = userInfo[userAddress];
        return (user.amount, user.rewardRemaining, user.rewardWithdrawal, user.startTime);
    }
	
	function migrateTokens(address receiver, address tokenAddress, uint256 tokenAmount) external onlyOwner nonReentrant{
       require(receiver != address(0), "zero-address not allowed");
	   
	   IBEP20(tokenAddress).safeTransfer(address(receiver), tokenAmount);
       emit MigrateTokens(tokenAddress, tokenAmount);
    }
	
	function updateMinStaking(uint256 minStakingAmount) external onlyOwner {
	    require(stakedToken.totalSupply() > minStakingAmount, "Total supply is less than minimum staking amount");
		require(minStakingAmount >= 500 * 10**18, "Amount is less than `500` tokens");
		
        minStaking = minStakingAmount;
        emit MinStakePerUser(minStakingAmount);
    }
	
	function updateAPR(uint256 newAPR) external onlyOwner {
	    require(newAPR >= 3000, "APR is less than `30%`");
		require(newAPR <= 24000, "APR is greater than `240%`");
		
        APR = newAPR;
        emit NewAPR(newAPR);
    }
	
	function updatePoolFee(uint256 newFee) external onlyOwner {
		require(newFee <= 200, "Fee is greater than `2%`");
		
        poolFee = newFee;
        emit NewPoolFee(newFee);
    }
	
	function pause() whenNotPaused external onlyOwner{
		paused = true;
		emit Pause();
	}
	
	function unpause() whenPaused external onlyOwner{
		paused = false;
		emit Unpause();
	}
}