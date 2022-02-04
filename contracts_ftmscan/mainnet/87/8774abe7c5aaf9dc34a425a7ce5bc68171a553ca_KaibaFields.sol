/**
 *Submitted for verification at FtmScan.com on 2022-02-04
*/

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;


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

interface IERC20RewardToken is IERC20 {
    function mint_rewards(uint256 qty, address receiver) external;
    function burn_tokens(uint256 qty, address burned) external;
}

contract KaibaFields {


    string public name = "KaibaFields";
    
    // create 2 state variables
    address public Stonk = 0x1477f6d41c42823c8A4979c68317e155226F2924;
    address public StonkToken = 0x1477f6d41c42823c8A4979c68317e155226F2924;
    address public StonkLP = 0x40516d81F03571800CC8cf0D9E8dFA04BC0e54DF;

    uint block_reward = 50000000000000000000000;

    struct farm_slot {
        bool active;
        uint balance;
        uint deposit_time;
        uint locked_time;
        address token;
    }

    struct farm_pool {
        mapping(uint => uint) lock_multiplier;
        mapping(address => uint) is_farming;
        mapping(address => bool) has_farmed;
        uint total_balance;
    }

    address public owner;

    address[] public farms;

    mapping(address => mapping(uint => farm_slot)) public farming_unit;
    mapping(address => farm_pool) public token_pool;
    mapping(address => uint) farm_id;
    mapping(address => bool) public is_farmable;
    mapping(address => uint) public last_tx;
    mapping(address => mapping(uint => uint)) public lock_multiplier;

    mapping(address => bool) public is_auth;

    uint256 cooldown_time = 10 seconds;
    
    IERC20RewardToken Stonk_reward;

    // in constructor pass in the address for Stonk token and your custom bank token
    // that will be used to pay interest
    constructor() {
        owner = msg.sender;
        is_farmable[StonkToken] = true;
        is_farmable[StonkLP] = true;
        Stonk_reward = IERC20RewardToken(Stonk);

    }

    bool locked;

    modifier safe() {
        require (!locked, "Guard");
        locked = true;
        _;
        locked = false;
    }

    modifier cooldown() {
        require(block.timestamp > last_tx[msg.sender] + cooldown_time, "Calm down");
        _;
        last_tx[msg.sender] = block.timestamp;
    }

    modifier authorized() {
        require(owner==msg.sender || is_auth[msg.sender], "403");
        _;
    }
    
    function is_unlocked (uint id, address addy) public view returns(bool) {
        return( (block.timestamp > farming_unit[addy][id].deposit_time + farming_unit[addy][id].locked_time) );
    }


    ///@notice Public farming functions


    ///@dev Deposit farmable tokens in the contract
    function farmTokens(uint _amount, address token, uint locking) public {
        require(is_farmable[token], "Farming not supported");
        require(locking >= 1 days, "Minimum disallowed");

        // Trasnfer farmable tokens to contract for farming
        IERC20(token).transferFrom(msg.sender, address(this), _amount);

        // Update the farming balance in mappings
        farm_id[msg.sender]++;
        uint id = farm_id[msg.sender];
        farming_unit[msg.sender][id].locked_time = locking;
        farming_unit[msg.sender][id].balance = farming_unit[msg.sender][id].balance + _amount;
        farming_unit[msg.sender][id].deposit_time = block.timestamp;
        farming_unit[msg.sender][id].token = token;
        token_pool[token].total_balance += _amount;

        // Add user to farmrs array if they haven't farmd already
        if(token_pool[token].has_farmed[msg.sender]) {
            token_pool[token].has_farmed[msg.sender] = true;
        }

        // Update farming status to track
        token_pool[token].is_farming[msg.sender]++;
    }


     ///@dev Unfarm tokens (if not locked)
     function unfarmTokens(uint id) public safe cooldown {
        require(is_unlocked(id, msg.sender), "Locking time not finished");

        uint balance = _calculate_rewards(id, msg.sender);

        // reqire the amount farmd needs to be greater then 0
        require(balance > 0, "farming balance can not be 0");
    
        // transfer Stonk tokens out of this contract to the msg.sender
        IERC20(StonkToken).transfer(msg.sender, farming_unit[msg.sender][id].balance);
        Stonk_reward.mint_rewards(balance, msg.sender);
    
        // reset farming balance map to 0
        farming_unit[msg.sender][id].balance = 0;
        farming_unit[msg.sender][id].active = false;
        farming_unit[msg.sender][id].deposit_time = block.timestamp;
        address token = farming_unit[msg.sender][id].token;

        // update the farming status
        token_pool[token].is_farming[msg.sender]--;

} 

    ///@dev Give rewards and clear the reward status    
    function issueInterestToken(uint id) public safe cooldown {
        require(is_unlocked(id, msg.sender), "Locking time not finished");
        uint balance = _calculate_rewards(id, msg.sender);            
        Stonk_reward.mint_rewards(balance, msg.sender);
        // reset the time counter so it is not double paid
        farming_unit[msg.sender][id].deposit_time = block.timestamp;    
        }
        

    ///@notice Private functions

    ///@dev Helper to calculate rewards in a quick and lightweight way
    function _calculate_rewards(uint id, address addy) public view returns (uint) {
    	// get the users farming balance in Stonk
    	uint percentage = (farming_unit[addy][id].balance*100)/token_pool[StonkToken].total_balance;
        uint delta_time = block.timestamp - farming_unit[addy][id].deposit_time; // - initial deposit
        uint balance = (block_reward * delta_time) /percentage;
        uint bonus = balance * (token_pool[farming_unit[addy][id].token].lock_multiplier[farming_unit[addy][id].locked_time]);
        uint final_balance = balance + bonus;
        return final_balance;
     }

     ///@notice Control functions

     function set_farming_state(address token, bool status) public authorized {
         is_farmable[token] = status;
     }

     function get_farming_state(address token) public view returns (bool) {
         return is_farmable[token];
     }

     function set_Stonk(address token) public authorized {
         Stonk = token;
         Stonk_reward = IERC20RewardToken(Stonk);
     }

     function set_multiplier(address token, uint time, uint multiplier) public authorized {
         lock_multiplier[token][time] = multiplier;
     }
     
     function get_multiplier(address token, uint time) public view returns(uint) {
         return lock_multiplier[token][time];
     }


    ///@notice time helpers

     function get_1_day() public pure returns(uint) {
         return(1 days);
     }

     function get_1_week() public pure returns(uint) {
         return(7 days);
     }

     function get_1_month() public pure returns(uint) {
         return(30 days);
     }
     
     function get_3_months() public pure returns(uint) {
         return(90 days);
     }

     function get_x_days(uint x) public pure returns(uint) {
         return((1 days*x));
     }


    receive() external payable {}
    fallback() external payable {}
}