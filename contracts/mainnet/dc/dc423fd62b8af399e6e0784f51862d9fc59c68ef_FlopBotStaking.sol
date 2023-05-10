/**
 *Submitted for verification at FtmScan.com on 2023-05-10
*/

/*  
 * FlopBotStaking
 * 
 * Written by: MrGreenCrypto
 * Co-Founder of CodeCraftrs.com
 * 
 * SPDX-License-Identifier: None
 */

pragma solidity 0.8.19;

interface IBEP20 {
  function decimals() external view returns (uint8);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract FlopBotStaking {
    address public constant TOKEN = 0x9DC6b7c1fd13746aB84f099B33Da7Bd825355857;
    address public constant CEO = 0x2CebE3438F946C4B64f2216B36b9E6b5c40C6811;

    uint256 public emergencyPenalty = 50;

    mapping(address => Stake[6]) public stakes;
    mapping(address => uint256) public totalLitPower;

    mapping(uint256 => uint256) public apyRateOfPool;
    mapping(uint256 => uint256) public lockDaysOfPool;
    mapping(uint256 => uint256) public freeTicketPermilleOfPool;
    
    struct Stake {
        uint256 amount;
        uint256 unlockTime;
        uint256 apy;
        uint256 lastStake;
        uint256 rewardSecondsLeft;
    }
    
    modifier onlyCEO(){
        require (msg.sender == CEO, "Only the CEO can do that");
        _;
    }

    event LitPowerUpdated(address staker, uint256 litPower);

    constructor() {
        apyRateOfPool[0] = 0;
        apyRateOfPool[1] = 5;
        apyRateOfPool[2] = 12;
        apyRateOfPool[3] = 20;
        apyRateOfPool[4] = 45;
        apyRateOfPool[5] = 110;
        lockDaysOfPool[0] = 15;
        lockDaysOfPool[1] = 30;      
        lockDaysOfPool[2] = 60;
        lockDaysOfPool[3] = 90;
        lockDaysOfPool[4] = 180;      
        lockDaysOfPool[5] = 360;
        freeTicketPermilleOfPool[0] = 0;
        freeTicketPermilleOfPool[1] = 15;
        freeTicketPermilleOfPool[2] = 30;
        freeTicketPermilleOfPool[3] = 50;
        freeTicketPermilleOfPool[4] = 80;        
        freeTicketPermilleOfPool[5] = 150;        
    }

    function stake(uint256 amount, uint256 pool) external {
        require(amount > 0, "Cannot stake nothing");
        require(IBEP20(TOKEN).transferFrom(msg.sender, address(this), amount),"Transfer failed");        
        compound(msg.sender, pool);
        stakes[msg.sender][pool].apy = apyRateOfPool[pool];
        stakes[msg.sender][pool].amount += amount;
        stakes[msg.sender][pool].unlockTime = block.timestamp + lockDaysOfPool[pool] * 1 days;
        stakes[msg.sender][pool].lastStake = block.timestamp;
        stakes[msg.sender][pool].rewardSecondsLeft = lockDaysOfPool[pool] * 1 days;
        calculateLitPower(msg.sender);
    }

    function compoundAll() external {
        for(uint256 i = 0; i<6; i++) compound(msg.sender, i);
    }    
    
    function compoundPool(uint256 pool) external {
        compound(msg.sender, pool);
    }

    function compound(address staker, uint256 pool) internal {
        uint256 amount = checkRewards(staker, pool);
        if(amount == 0) return;
        stakes[staker][pool].apy = apyRateOfPool[pool];
        stakes[staker][pool].amount += amount;
        stakes[staker][pool].unlockTime = block.timestamp + lockDaysOfPool[pool] * 1 days;
        stakes[staker][pool].lastStake = block.timestamp;
        stakes[staker][pool].rewardSecondsLeft = lockDaysOfPool[pool] * 1 days;
        calculateLitPower(staker);
    }

    function payRewards(address staker, uint256 pool) internal {
        if(stakes[staker][pool].amount == 0) return;
        uint256 rewardsTime = block.timestamp - stakes[staker][pool].lastStake;
        if(rewardsTime > stakes[staker][pool].rewardSecondsLeft) rewardsTime = stakes[staker][pool].rewardSecondsLeft;
        if(rewardsTime == 0) return;
        stakes[staker][pool].rewardSecondsLeft -= rewardsTime;
        uint256 rewardsToBePaid = stakes[staker][pool].amount * stakes[staker][pool].apy * rewardsTime / 365 days / 100;
        if(rewardsToBePaid == 0) return;
        require(IBEP20(TOKEN).transfer(staker, rewardsToBePaid),"Transfer failed");
    }

    function getAvailableRewards(address staker) public view returns (uint256) {
        uint256 rewards = 0;
        for(uint256 i = 0; i<6; i++) rewards += checkRewards(staker, i);
        return rewards;
    }

    function checkRewards(address staker, uint256 pool) public view returns (uint256) {
        if(stakes[staker][pool].amount == 0) return 0;
        uint256 rewardsTime = block.timestamp - stakes[staker][pool].lastStake;
        if(rewardsTime > stakes[staker][pool].rewardSecondsLeft) rewardsTime = stakes[staker][pool].rewardSecondsLeft;
        if(rewardsTime == 0) return 0;
        uint256 rewardsToBePaid = stakes[staker][pool].amount * stakes[staker][pool].apy * rewardsTime / 365 days / 100;
        return rewardsToBePaid;
    }

    function allStakesOfAddress(address staker) public view returns (Stake[6] memory){
        return stakes[staker];
    }

    function calculateLitPower(address staker) internal {
        uint256 litPower;
        for(uint256 i = 0; i<6; i++) litPower += stakes[staker][i].amount * (1000 + freeTicketPermilleOfPool[i]) / 1000;
        totalLitPower[staker] = litPower;
        emit LitPowerUpdated(staker, litPower);
    }

    function setPools(uint256 pool, uint256 apy, uint256 daysLocked, uint256 freeTickets) external onlyCEO {
        require(pool >= 0 && pool < 6, "Can't create more pools");
        require(apy <= 100, "Maximum APY is 100%");
        require(daysLocked < 366, "Maximum lockTime is 1 year");
        require(daysLocked > 14, "Minimum lockTime is 15 days");
        apyRateOfPool[pool] = apy;
        lockDaysOfPool[pool] = daysLocked;
        freeTicketPermilleOfPool[pool] = freeTickets;
    }

    function setEmergencyPenalty(uint256 penalty) external onlyCEO {
        require(penalty >= 0 && penalty < 100, "Error");
        emergencyPenalty = penalty;
    }

    function unstake(uint256 pool) public {
        require(block.timestamp >= stakes[msg.sender][pool].unlockTime, "Not unlocked yet");
        payRewards(msg.sender,pool);
        require(IBEP20(TOKEN).transfer(msg.sender, stakes[msg.sender][pool].amount),"Transfer failed");
        stakes[msg.sender][pool].apy = apyRateOfPool[pool];
        stakes[msg.sender][pool].amount = 0;
        stakes[msg.sender][pool].unlockTime = block.timestamp;
        stakes[msg.sender][pool].lastStake = block.timestamp;
        stakes[msg.sender][pool].rewardSecondsLeft = 0;
        calculateLitPower(msg.sender);
    }

    function emergencyUnstake(uint256 pool) public {
        require(block.timestamp < stakes[msg.sender][pool].unlockTime, "Unlocked already");
        require(IBEP20(TOKEN).transfer(msg.sender, stakes[msg.sender][pool].amount * (100 - emergencyPenalty) / 100),"Transfer failed");
        stakes[msg.sender][pool].apy = apyRateOfPool[pool];
        stakes[msg.sender][pool].amount = 0;
        stakes[msg.sender][pool].unlockTime = block.timestamp;
        stakes[msg.sender][pool].lastStake = block.timestamp;
        stakes[msg.sender][pool].rewardSecondsLeft = 0;
        calculateLitPower(msg.sender);
    }   
}