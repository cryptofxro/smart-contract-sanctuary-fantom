/**
 *Submitted for verification at FtmScan.com on 2022-02-27
*/

// File: test.sol

pragma solidity ^0.8;


interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}


contract DefiBank {
    
    // call it DefiBank
    string public name = "DefiBank";
    address public operator;
    address public owner;
    // create 2 state variables
    address public usdc;
    address public bankToken;
    uint public TotalStaked;
    uint public TotalRewards;
    bool public RewardsOn;

    address[] public stakers;
    mapping(address => uint) public stakingBalance;
    mapping(address => bool) public hasStaked;
    mapping(address => bool) public isStaking;


    // in constructor pass in the address for USDC token and your custom bank token
    // that will be used to pay interest
    constructor() {
        operator = msg.sender;
        owner = msg.sender;
        usdc = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
        bankToken = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    }
    modifier onlyOperator() {
        require(operator == msg.sender, "BShareRewardPool: caller is not the operator");
        _;
    }


    // allow user to stake usdc tokens in contract
    
    function stakeTokens(uint _amount) public {

        // Trasnfer usdc tokens to contract for staking
        IERC20(usdc).transferFrom(msg.sender, address(this), _amount);

        // Update the staking balance in map
        stakingBalance[msg.sender] = stakingBalance[msg.sender] + _amount;
        TotalStaked += _amount;
        // Add user to stakers array if they haven't staked already
        if(!hasStaked[msg.sender]) {
            stakers.push(msg.sender);
        }

        // Update staking status to track
        isStaking[msg.sender] = true;
        hasStaked[msg.sender] = true;

    }
    function SupplyRewards(uint _amount) public onlyOperator {

        //require()

        // Trasnfer reward tokens to contract for staking
        IERC20(bankToken).transferFrom(msg.sender, address(this), _amount);

        // Update the staking balance in map
        
        TotalRewards += _amount;
        // update status for tracking
        if (TotalRewards > 0){
            RewardsOn = true;
        }


    }
    function WithdrawRewards(uint _amount) public onlyOperator {

        require(_amount <= TotalRewards);

        // Trasnfer reward tokens to contract for staking
        IERC20(bankToken).transfer(msg.sender, _amount);

        // Update the staking balance in map
        
        TotalRewards -= _amount;
        // update status for tracking
        if (TotalRewards == 0){
            RewardsOn = false;
        }


    }

        // allow user to unstake total balance and withdraw USDC from the contract
    
    function unstakeTokens() public {

    	// get the users staking balance in usdc
    	uint balance = stakingBalance[msg.sender];
    
        // reqire the amount staked needs to be greater then 0
        require(balance > 0, "staking balance can not be 0");
    
        // transfer usdc tokens out of this contract to the msg.sender
        IERC20(usdc).transfer(msg.sender, balance);

        TotalStaked -= balance;
    
        // reset staking balance map to 0
        stakingBalance[msg.sender] = 0;
    
        // update the staking status
        isStaking[msg.sender] = false;

    } 


    // Issue bank tokens as a reward for staking
    function getPoolShare(address staker) public view returns(uint256){
        return stakingBalance[staker]*(1e18)/(TotalStaked);
    }

    function issueInterestToken() public onlyOperator{
        for (uint i=0; i<stakers.length; i++) {
            address recipient = stakers[i];
            uint poolShare = getPoolShare(recipient);
            uint rewards = poolShare*TotalRewards/(1e18);
            
    // if there is a balance transfer the SAME amount of bank tokens to the account that is staking as a reward
            
            if(rewards > 0 ) {
                IERC20(bankToken).transfer(recipient, rewards);
                
            }
            
        }
        
    }
    function getBalance(address staker) external view returns(uint256) {
         return stakingBalance[staker];
    }
    function getTotalStaked() external view returns(uint256) {
         return TotalStaked;
    }


}