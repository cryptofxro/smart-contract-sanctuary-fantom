pragma solidity 0.8.9;

import "Context.sol";
import "Ownable.sol";
import "SafeMath.sol";

contract LeaningTower is Context, Ownable {
    using SafeMath for uint256;

    uint256 private maxMiningTime = 1080000; 
    uint256 private minerPrice = 1e17;
    uint256 public dailyAPR = 5;
    uint256 public maxSellPercent = 5;
    uint256 private devFeeVal = 3;
    bool private initialized = false;
    address payable private recAdd;
    mapping (address => uint256) private hatcheryMiners; 
    mapping (address => uint256) private claimedEggs; 
    mapping (address => uint256) private lastHatch;
    mapping (address => uint256) private lastSell;
    mapping (address => address) private referrals;
    mapping (uint256 => address) public users;
    mapping (address => bool) public enteredUsers;
    mapping (address => bool) public voted;
    mapping (address => bool) public eligible;
    uint256 public numUsers;
    uint256 public bonusPercent = 1;
    uint256 private bonusTime;
    address public winner;
    uint256 public random;
    bool private paid = false;
    uint256 public voteToMigrate;
    address payable public newContract;
    uint256 public numEligibleUsers;
    bool public startMigrateSequence;

    event newRandom(uint256 random);

    constructor() {
        recAdd = payable(msg.sender);
    }
    
    //Owner functions
    function payWinner(address _winner) onlyOwner public {
        require(initialized);
        require(!paid);
        
        uint256 winnings = SafeMath.div(SafeMath.mul(address(this).balance, bonusPercent), 100);
        uint256 newMiners = SafeMath.div(winnings, minerPrice);
        hatcheryMiners[msg.sender] = SafeMath.add(hatcheryMiners[msg.sender],newMiners);

        paid = true;
        winner = _winner;
    }

    function changeSettings(uint256 _maxMiningTime, uint256 _minerPrice, uint256 _dailyAPR, uint256 _maxSellPercent, uint256 _bonusPercent) onlyOwner public {
        require(_dailyAPR > 1 && _dailyAPR < 10);
        require(_maxSellPercent > 1 && _maxSellPercent < 10);
        require(_bonusPercent < 5);
        
        maxMiningTime = _maxMiningTime;
        minerPrice = _minerPrice;
        dailyAPR = _dailyAPR;
        maxSellPercent = _maxSellPercent;
        bonusPercent = _bonusPercent;
    }
        
    function seedMarket() public payable onlyOwner {
        require(!initialized);
        initialized = true;
        bonusTime = block.timestamp + 86400; //starts 1 day after init
    }

    //User functions
    function hatchEggs(address ref) public {
        require(initialized);
        
        if (block.timestamp > bonusTime) {
            bonusTime = SafeMath.add(bonusTime, 86400);
            paid = false;
            random = _getRand();
            emit newRandom(random);
        }
        
        uint256 eggsUsed = getMyEggs(msg.sender);
        uint256 newMiners = SafeMath.div(eggsUsed,minerPrice);
        hatcheryMiners[msg.sender] = SafeMath.add(hatcheryMiners[msg.sender],newMiners);
        claimedEggs[msg.sender] = 0;
        lastHatch[msg.sender] = block.timestamp;
    }
    
    function sellEggs() public {
        require(initialized);
        require(block.timestamp > lastSell[msg.sender] + 6 days, "6 day minimum");

        uint256 numEggs = getMyEggs(msg.sender);
        uint256 maxSell = SafeMath.div(SafeMath.mul(SafeMath.mul(hatcheryMiners[msg.sender], minerPrice),maxSellPercent),100);

        if (numEggs < maxSell) {
            claimedEggs[msg.sender] = 0;
            payable (msg.sender).transfer(numEggs);
        } else {
            claimedEggs[msg.sender] = SafeMath.sub(numEggs, maxSell);
            payable (msg.sender).transfer(maxSell);
        }
        
        lastHatch[msg.sender] = block.timestamp;
        lastSell[msg.sender] = block.timestamp;
    }
    
    function buyEggs(address ref) public payable {
        require(initialized);
        uint256 fee = devFee(msg.value);
        uint256 eggsBought = SafeMath.sub(msg.value,fee);

        recAdd.transfer(fee);
        claimedEggs[msg.sender] = SafeMath.add(claimedEggs[msg.sender],eggsBought);

        if (!enteredUsers[msg.sender]) { //first timer
            enteredUsers[msg.sender] = true;
            users[numUsers] = msg.sender;
            numUsers = SafeMath.add(numUsers, 1);
            lastSell[msg.sender] = block.timestamp;
        }

        if (eggsBought > SafeMath.div(address(this).balance, 100) && !eligible[msg.sender] ) {
            eligible[msg.sender] = true;
            numEligibleUsers = SafeMath.add(numEligibleUsers, 1);
        }

        if(ref == msg.sender) {
            ref = address(0);
        }
        
        if(referrals[msg.sender] == address(0) && referrals[msg.sender] != msg.sender) {
            referrals[msg.sender] = ref;
        }
        claimedEggs[referrals[msg.sender]] = SafeMath.add(claimedEggs[referrals[msg.sender]],SafeMath.div(eggsBought,10));

        hatchEggs(ref);
    }

    //Accessory functions
    function beanRewards(address adr) public view returns(uint256) {
        return getMyEggs(adr);
    }
    
    function devFee(uint256 amount) private view returns(uint256) {
        return SafeMath.div(SafeMath.mul(amount,devFeeVal),100);
    }
    
    function getBalance() public view returns(uint256) {
        return address(this).balance;
    }
    
    function getMyMiners(address adr) public view returns(uint256) {
        return hatcheryMiners[adr];
    }
    
    function getMyEggs(address adr) public view returns(uint256) {
        return SafeMath.add(claimedEggs[adr],getEggsSinceLastHatch(adr));
    }

    function getWinner() public view returns(address) {
        return winner;
    }
    
    function getEggsSinceLastHatch(address adr) public view returns(uint256) {
        uint256 secondsPassed = min(maxMiningTime,SafeMath.sub(block.timestamp,lastHatch[adr]));
        return SafeMath.mul(SafeMath.mul(SafeMath.div(SafeMath.mul(secondsPassed,1e13),864),hatcheryMiners[adr]),dailyAPR);
    }
    
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function _getRand() internal returns(uint) {
        return uint(keccak256(abi.encodePacked(blockhash(block.number - 1),block.timestamp,block.difficulty, msg.sender))); 
    }

    //Migrate functions
    function ownerStartMigrateSequence(address payable _newContract) onlyOwner public {
        startMigrateSequence = true;
        newContract = _newContract;
        initialized = false; 
    }

    function voteMigrate() public {
        require(eligible[msg.sender]);
        require(!voted[msg.sender]);
        require(startMigrateSequence);

        voteToMigrate = SafeMath.add(voteToMigrate, 1);
        voted[msg.sender] = true;
    }
    
    function migrate() onlyOwner public {
        require (voteToMigrate > SafeMath.div(numEligibleUsers, 2), "need more votes");
        newContract.transfer(address(this).balance);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}