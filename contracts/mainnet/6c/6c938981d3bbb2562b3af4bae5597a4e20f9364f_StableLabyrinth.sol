/**
 *Submitted for verification at FtmScan.com on 2022-07-10
*/

// SPDX-License-Identifier: Apache-2.0

/*                   \______/                               \__|      
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

pragma solidity 0.8.9;

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

contract Ownable is Context {
    address private _owner;


    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
    * @dev Initializes the contract setting the deployer as the initial owner.
    */
    constructor () {
      address msgSender = _msgSender();
      _owner = msgSender;
      emit OwnershipTransferred(address(0), msgSender);
    }

    /**
    * @dev Returns the address of the current owner.
    */
    function owner() public view returns (address) {
      return _owner;
    }

    
    modifier onlyOwner() {
      require(_owner == _msgSender(), "Ownable: caller is not the owner");
      _;
    }

    function renounceOwnership() public onlyOwner {
      emit OwnershipTransferred(_owner, address(0));
      _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
      _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
      require(newOwner != address(0), "Ownable: new owner is the zero address");
      emit OwnershipTransferred(_owner, newOwner);
      _owner = newOwner;
    }
}

interface ERC20 {
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

contract StableLabyrinth is Context, Ownable {
    using SafeMath for uint256;

    address busd = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address private recAdd;
    address private marketingAdd;
    address private devAdd;
    uint256 private APES_TO_HATCH_1MINERS = 1440000;
    uint256 private PSN = 10000;
    uint256 private PSNH = 5000;
    uint256 private devFeeVal = 2;
    uint256 private marketingFeeVal = 2;
    bool private initialized = false;
    mapping (address => uint256) private hatcheryMiners;
    mapping (address => uint256) private claimedApes;
    mapping (address => uint256) private lastHatch;
    mapping (address => address) private referrals;
    uint256 private marketApes;
    
    constructor() {
        recAdd=msg.sender;
        marketingAdd=0xDEbD0E212fa296Bb55B18b6F5915e037d293864D;
        devAdd=0xD198eaE45a72d03023587426aDc4A324e121e82B;

    }
    
    function hatchApes(address ref) public {
        require(initialized);
        
        if(ref == msg.sender) {
            ref = address(0);
        }
        
        if(referrals[msg.sender] == address(0) && referrals[msg.sender] != msg.sender) {
            referrals[msg.sender] = ref;
        }
        
        uint256 apesUsed = getMyApes(msg.sender);
        uint256 newMiners = SafeMath.div(apesUsed,APES_TO_HATCH_1MINERS);
        hatcheryMiners[msg.sender] = SafeMath.add(hatcheryMiners[msg.sender],newMiners);
        claimedApes[msg.sender] = 0;
        lastHatch[msg.sender] = block.timestamp;
        
        //send referral apes
        claimedApes[referrals[msg.sender]] = SafeMath.add(claimedApes[referrals[msg.sender]],SafeMath.div(apesUsed,16));
        
        //boost market to nerf miners hoarding
        marketApes=SafeMath.add(marketApes,SafeMath.div(apesUsed,5));
    }
    
    function sellApes() public {
        require(initialized);
        uint256 hasApes = getMyApes(msg.sender);
        uint256 apeValue = calculateApeSell(hasApes);


        uint256 fee1 = devFee1(apeValue);
        uint256 fee2 = marketingFee(apeValue);
        uint256 fee3 = devFee2(apeValue);

        claimedApes[msg.sender] = 0;
        lastHatch[msg.sender] = block.timestamp;
        marketApes = SafeMath.add(marketApes,hasApes);


        ERC20(busd).transfer(recAdd, fee1);
        ERC20(busd).transfer(marketingAdd, fee2);
        ERC20(busd).transfer(devAdd, fee3);

        
        ERC20(busd).transfer(address(msg.sender), SafeMath.sub(apeValue,fee1));
        ERC20(busd).transfer(address(msg.sender), SafeMath.sub(apeValue,fee2));
        ERC20(busd).transfer(address(msg.sender), SafeMath.sub(apeValue,fee3));
    }
    
    function beanRewards(address adr) public view returns(uint256) {
        uint256 hasApes = getMyApes(adr);
        uint256 apeValue = calculateApeSell(hasApes);
        return apeValue;
    }
    
    function buyApes(address ref, uint256 amount) public {
        require(initialized);

        ERC20(busd).transferFrom(address(msg.sender), address(this), amount);
        uint256 balance = ERC20(busd).balanceOf(address(this));
        uint256 apesBought=calculateApeBuy(amount,SafeMath.sub(balance,amount));


        apesBought = SafeMath.sub(apesBought,devFee1(apesBought));
        apesBought = SafeMath.sub(apesBought,marketingFee(apesBought));
        apesBought = SafeMath.sub(apesBought,devFee2(apesBought));


        uint256 fee1 = devFee1(amount);
        uint256 fee2 = marketingFee(amount);
        uint256 fee3 = devFee2(amount);



        ERC20(busd).transfer(recAdd, fee1);
        ERC20(busd).transfer(marketingAdd, fee2);
        ERC20(busd).transfer(devAdd, fee3);

        claimedApes[msg.sender] = SafeMath.add(claimedApes[msg.sender],apesBought);
        hatchApes(ref);
    }

    
    function calculateTrade(uint256 rt,uint256 rs, uint256 bs) private view returns(uint256) {
        return SafeMath.div(SafeMath.mul(PSN,bs),SafeMath.add(PSNH,SafeMath.div(SafeMath.add(SafeMath.mul(PSN,rs),SafeMath.mul(PSNH,rt)),rt)));
    }
    
    function calculateApeSell(uint256 apes) public view returns(uint256) {
        return calculateTrade(apes,marketApes,ERC20(busd).balanceOf(address(this)));
    }
    
    function calculateApeBuy(uint256 eth,uint256 contractBalance) public view returns(uint256) {
        return calculateTrade(eth,contractBalance,marketApes);
    }
    
    function calculateApeBuySimple(uint256 eth) public view returns(uint256){
        return calculateApeBuy(eth,ERC20(busd).balanceOf(address(this)));
    }
    
    function devFee1(uint256 amount) private view returns(uint256) {
        return SafeMath.div(SafeMath.mul(amount,devFeeVal),100);
    }

    function marketingFee(uint256 amount) private view returns(uint256) {
        return SafeMath.div(SafeMath.mul(amount,marketingFeeVal),100);
    }
    
    function devFee2(uint256 amount) private view returns(uint256) {
        return SafeMath.div(SafeMath.mul(amount,devFeeVal),100);
    }
    
    function seedMarket(uint256 amount) public onlyOwner {
        require(marketApes==0);
        ERC20(busd).transferFrom(address(msg.sender), address(this), amount);
        require(marketApes==0);
        initialized=true;
        marketApes=108000000000;
    }
    
    function getBalance() public view returns(uint256) {
        return ERC20(busd).balanceOf(address(this));
    }
    
    function getMyMiners(address adr) public view returns(uint256) {
        return hatcheryMiners[adr];
    }
    
    function getMyApes(address adr) public view returns(uint256) {
        return SafeMath.add(claimedApes[adr],getApesSinceLastHatch(adr));
    }
    
    function getApesSinceLastHatch(address adr) public view returns(uint256) {
        uint256 secondsPassed=min(APES_TO_HATCH_1MINERS,SafeMath.sub(block.timestamp,lastHatch[adr]));
        return SafeMath.mul(secondsPassed,hatcheryMiners[adr]);
    }
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}