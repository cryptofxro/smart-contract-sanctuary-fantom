// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;   

import "./interfaces/IERC20.sol";
import "./libraries/SafeERC20.sol";
import "./helpers/Ownable.sol";

contract SlotMachine is Ownable {

    // using SafeMath for uint;
    using SafeERC20 for IERC20;

    uint private Jackpot;
    address gameToken = 0x174c7106AEeCdC11389f7dD21342F05f46CCB40F;  // Devil token
    // address gameToken = 0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7;  // BUSD test token
    uint minBet = 10000000000000000000;
    uint maxBet = 100000000000000000000;

    enum Symbols {Seven, Bar, Bitcoin, Boo, Eth, Usdc, Devil, Tomb}

    struct BetInput {
        // uint inputAmount;
        bool isPlay;
        uint availableAmt;
        // bool won;
    }
    // struct PlayInfo {
    //     uint winningAmount;
    //     string reel1;
    //     string reel2;
    //     string reel3;
    //     bool hasAdditionalGame;
    //     bool wonAdditionalGame;
    //     uint additionalGameNumber;
    // }
    mapping(address => BetInput) public CurrentPlayers;
    // mapping(address => PlayInfo) public Players;
    
    event GameResult(
        address indexed player,
        bool won,
        uint amount,
        string reel1,
        string reel2,
        string reel3,
        bool canPlayAdditionalGame,
        bool wonAdditionalGame,
        uint number
    );
    event Deposited(address indexed player, uint amount);
    event Withdrew(address indexed player, uint amount);

    Symbols[21] private reel1 = [
        Symbols.Seven,
        Symbols.Bar, Symbols.Bar,
        Symbols.Bitcoin, Symbols.Bitcoin,
        Symbols.Boo,
        Symbols.Eth, Symbols.Eth, Symbols.Eth, Symbols.Eth, Symbols.Eth, Symbols.Eth, Symbols.Eth,
        Symbols.Usdc, Symbols.Usdc, Symbols.Usdc,
        Symbols.Devil, Symbols.Devil, 
        Symbols.Tomb, Symbols.Tomb, Symbols.Tomb
        ];

    Symbols[24] private reel2 = [
        Symbols.Seven,
        Symbols.Bar, 
        Symbols.Bitcoin,
        Symbols.Boo, Symbols.Boo, Symbols.Boo, Symbols.Boo,
        Symbols.Eth, Symbols.Eth, 
        Symbols.Usdc, Symbols.Usdc, Symbols.Usdc, Symbols.Usdc, Symbols.Usdc,
        Symbols.Devil, Symbols.Devil, Symbols.Devil, Symbols.Devil, Symbols.Devil, Symbols.Devil,
        Symbols.Tomb, Symbols.Tomb, Symbols.Tomb, Symbols.Tomb
        ];
    
    Symbols[23] private reel3 = [
        Symbols.Seven,
        Symbols.Bar,
        Symbols.Bitcoin, Symbols.Bitcoin,
        Symbols.Boo, Symbols.Boo, Symbols.Boo, Symbols.Boo, Symbols.Boo, Symbols.Boo, Symbols.Boo, Symbols.Boo,
        Symbols.Eth, Symbols.Eth, Symbols.Eth,
        Symbols.Usdc, Symbols.Usdc,
        Symbols.Devil, Symbols.Devil,
        Symbols.Tomb, Symbols.Tomb, Symbols.Tomb, Symbols.Tomb
        ];

    // add balance to the slot machine for liquidity
    fallback() external payable {}
    receive() external payable {}

    function GetJackpot() public view returns (uint) {
        return Jackpot;
    }

    function GetPlayInfo(address player) public view returns (BetInput memory){
        return CurrentPlayers[player];
    }

    function deposit(uint _amount) public {
        BetInput storage play = CurrentPlayers[msg.sender];
        require(_amount > 0, "Deposit amount must be greater than 0");
        require(IERC20(gameToken).balanceOf(msg.sender) >= _amount, "insufficient token for depositing in your wallet");
        
        IERC20(gameToken).safeTransferFrom(address(msg.sender), address(this), _amount);

        play.availableAmt += _amount;

        emit Deposited(msg.sender, _amount);
    }

    function withdraw() public {
        BetInput storage play = CurrentPlayers[msg.sender];
        require(play.availableAmt > 0, "no withdrawable amount");
        require(IERC20(gameToken).balanceOf(address(this)) >= play.availableAmt, "insufficient token in this contract");
        
        IERC20(gameToken).safeTransfer(msg.sender, play.availableAmt);
        play.availableAmt = 0;

        emit Withdrew(msg.sender, play.availableAmt);
    }

    function PlaySlotMachine(uint betAmount) public {
        BetInput storage play = CurrentPlayers[msg.sender];
        // require(betAmount >= minBet, "Bet size to small"); // 
        // require(betAmount * 200 + Jackpot < IERC20(gameToken).balanceOf(address(this)), "The bet input is to large to be fully payed out"); //??
        require(CurrentPlayers[msg.sender].isPlay == false, "Only one concurrent game per Player");
        require(CurrentPlayers[msg.sender].availableAmt >= betAmount, "Insufficient amount of token to play");

        // save that current sender is playing a game
        // play.inputAmount = betAmount;
        play.isPlay = true;
        play.availableAmt -= betAmount;

        // (uint reel1Index, uint reel2Index, uint reel3Index) = GetRandomIndices();
        uint[4] memory reelIndex = getRandomNumbers();
        Symbols symbol1 = reel1[reelIndex[0]];
        Symbols symbol2 = reel2[reelIndex[1]];
        Symbols symbol3 = reel3[reelIndex[2]];

        uint multiplicator = CheckIfDrawIsWinner(symbol1, symbol2, symbol3);
        bool won = multiplicator != 0;
        uint winningAmount = 0; // Todo should it be currentPlayer's []?
        bool hasAdditionalGame = multiplicator == 10; // case: 777
        bool wonAdditionalGame = false;
        uint additionalGameNumber = 0;

        if (won) {
            winningAmount = betAmount * multiplicator;
            // check if additonal game can be played
            if (hasAdditionalGame) {
                // if random number is equal to 0 --> win
                // additionalGameNumber = GetRandomNumber(10, "4");
                additionalGameNumber = reelIndex[3];
                if (additionalGameNumber == 4) {
                    uint currentJackpot = Jackpot;
                    Jackpot = 0;
                    wonAdditionalGame = true;
                    winningAmount += currentJackpot;
                }
            }
        } else {
            // add 10% of the input to the jackpot
            Jackpot += betAmount / 10;
        }
        // transfer funds or increase Jackpot
        if (winningAmount > 0) {
          play.availableAmt += winningAmount;
        }
        play.isPlay = false;

        emit GameResult(
            msg.sender,
            won,
            winningAmount,
            MapEnumString(symbol1),
            MapEnumString(symbol2),
            MapEnumString(symbol3),
            hasAdditionalGame,
            wonAdditionalGame,
            additionalGameNumber
        );

    }

    // function GetRandomIndices() private view returns (uint, uint, uint) {
    //     uint indexReel1 = GetRandomNumber(reel1.length, "1");
    //     uint indexReel2 = GetRandomNumber(reel2.length, "2");
    //     uint indexReel3 = GetRandomNumber(reel3.length, "3");

    //     // require(indexReel1 >= 0 && indexReel1 < reel1.length, "Reel1 random index out of range");
    //     // require(indexReel2 >= 0 && indexReel2 < reel2.length, "Reel2 random index out of range");
    //     // require(indexReel3 >= 0 && indexReel3 < reel3.length, "Reel3 random index out of range");
    //     return (indexReel1, indexReel2, indexReel3);
    // }

    // function GetRandomNumber(uint max, bytes32 salt) private view returns (uint) {
    //     uint randomNumber = uint256(keccak256(abi.encode(block.difficulty, now, salt))) % max;
    //     // require(randomNumber <= max, "random number out of range");
    //     return randomNumber;
    // }

    function getRandomNumbers() public view returns (uint256[4] memory) {
    uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, block.number)));
    return [
      randomNumber % reel1.length,
      randomNumber % reel2.length,
      randomNumber % reel3.length,
      randomNumber % 10
    ];
}


    function CheckIfDrawIsWinner(Symbols symbol1, Symbols symbol2, Symbols symbol3) private pure returns (uint multiplicator) {
        // Cherries
        if (symbol1 == Symbols.Devil) {
            // Devil Devil Anything
            if (symbol2 == Symbols.Devil) {
                return 3; //5
            }
            // Devil Anything Anything
            return 2;
        }
        
        // if (symbol3 == Symbols.Bar) {
        //         // Usdc Usdc Bar
        //     if (symbol1 == Symbols.Usdc && symbol2 == Symbols.Usdc) {
        //         return 4; //10
        //     }
            
        //     // Eth Eth Bar
        //     if (symbol1 == Symbols.Eth && symbol2 == Symbols.Eth) {
        //         return 5; // 14
        //     }
            
        //     // Boo Boo Bar
        //     if (symbol1 == Symbols.Boo && symbol2 == Symbols.Boo) {
        //         return 6;  // 18
        //     }
            
        //     // Bitcoin Bitcoin Bar
        //     if (symbol1 == Symbols.Bitcoin && symbol2 == Symbols.Bitcoin) {
        //         return 9;  // 100
        //     }
        // }
        
        bool areAllReelsEqual = symbol2 == symbol1 && symbol3 == symbol1;
        if (areAllReelsEqual) {
                // Usdc Usdc Usdc
            if (symbol1 == Symbols.Usdc) {
                return 10; // 10
            }
    
            // Eth Eth Eth
             else if (symbol1 == Symbols.Eth) {
                return 5;  // 14
            }
            
            // Boo Boo Boo
            if (symbol1 == Symbols.Boo) {
                return 6;  // 18
            }
            
            // Bitcoin Bitcoin Bitcoin
            if (symbol1 == Symbols.Bitcoin) {
                return 9; // 50
            }
            
            // Bar Bar Bar
            if (symbol1 == Symbols.Bar) {
                return 9; // 100
            }
            
            // 777
            if (symbol1 == Symbols.Seven) {
                return 10;     // 200
            }
        }
        
        // nothing
        return 0;
    }

    function MapEnumString(Symbols input) private pure returns (string memory) {
        if (input == Symbols.Seven) {
            return "7";
        } else if (input == Symbols.Bar) {
            return "bar";
        } else if (input == Symbols.Bitcoin) {
            return "bitcoin";
        } else if (input == Symbols.Boo) {
            return "boo";
        } else if (input == Symbols.Eth) {
            return "eth";
        } else if (input == Symbols.Usdc) {
            return "usdc";
        } else if (input == Symbols.Devil) {
            return "devil";
        } else {
            return "tomb";
        }
    }

    function setGameToken(address _newToken) public onlyOwner {
        gameToken = _newToken;
    }

    function setJackpot(uint _newValue) public onlyOwner {
        Jackpot = _newValue;
    }

    function setMinMaxBet(uint _newMinBet, uint _newMaxBet) public onlyOwner {
        minBet = _newMinBet;
        maxBet = _newMaxBet;
    } 

    // withdraw from contract by owner
    function withdrawOwner(address _to, uint amount) public onlyOwner {
        uint tokenBalance = IERC20(gameToken).balanceOf(address(this));
        require(tokenBalance > 0, "Owner has no balance to withdraw");
        require(
            tokenBalance >= amount,
            "Insufficient amount of tokens to withdraw"
        );
        // transfer some tokens to owner(or beneficient)
        IERC20(gameToken).safeTransfer(_to, amount);
    }
}

pragma solidity ^0.6.12;

// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

pragma solidity 0.6.12;

import "../interfaces/IERC20.sol";
import "./SafeMath.sol";
import "./Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance =
            token.allowance(address(this), spender).add(value);
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance =
            token.allowance(address(this), spender).sub(
                value,
                "SafeERC20: decreased allowance below zero"
            );
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata =
            address(token).functionCall(
                data,
                "SafeERC20: low-level call failed"
            );
        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(
                abi.decode(returndata, (bool)),
                "SafeERC20: ERC20 operation did not succeed"
            );
        }
    }
}

pragma solidity 0.6.12;

import "./Context.sol";

// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() internal {
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

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

pragma solidity ^0.6.12;

// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol
library SafeMath {
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
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
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
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
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
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
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
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
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
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
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
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
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
        require(b != 0, errorMessage);
        return a % b;
    }
}

pragma solidity 0.6.12;

// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/SafeERC20.sol";
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Converts an `address` into `address payable`. Note that this is
     * simply a type cast: the actual underlying value is not changed.
     *
     * _Available since v2.4.0._
     */
    function toPayable(address account)
        internal
        pure
        returns (address payable)
    {
        return address(uint160(account));
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return
            functionCallWithValue(
                target,
                data,
                value,
                "Address: low-level call with value failed"
            );
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(
            address(this).balance >= value,
            "Address: insufficient balance for call"
        );
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) =
            target.call{value: value}(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data)
        internal
        view
        returns (bytes memory)
    {
        return
            functionStaticCall(
                target,
                data,
                "Address: low-level static call failed"
            );
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.3._
     */
    function functionDelegateCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
        return
            functionDelegateCall(
                target,
                data,
                "Address: low-level delegate call failed"
            );
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.3._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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

pragma solidity 0.6.12;

// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Context.sol
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}