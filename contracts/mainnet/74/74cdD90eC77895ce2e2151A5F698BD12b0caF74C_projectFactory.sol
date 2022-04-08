//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./SeedType.sol";

contract projectFactory is Ownable {

    ParticipationVestingSeed[] public vestedContract;

    function create_project (
        uint _numberOfPortions,
        uint timeBetweenPortions,
        uint distributionStartDate,
        uint _initialPortionUnlockingTime,
        address _adminWallet,
        address _token,
        uint _initialRelease) external onlyOwner {

    ParticipationVestingSeed projects = new ParticipationVestingSeed(
        _numberOfPortions, timeBetweenPortions, distributionStartDate, _initialPortionUnlockingTime,
            _adminWallet, _token, _initialRelease
    );
        vestedContract.push(projects);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// ParticipationVesting smart contract
contract ParticipationVestingSeed  {


    uint public totalTokensToDistribute;
    uint public totalTokensWithdrawn;
    uint public initialRelease;

    struct Participation {
        uint256 initialPortion;
        uint256 vestedAmount;
        uint256 amountPerPortion;
        bool initialPortionWithdrawn;
        bool [] isVestedPortionWithdrawn;
    }

    IERC20 public token;

    address public adminWallet;
    mapping(address => Participation) public addressToParticipation;
    mapping(address => bool) public hasParticipated;
     mapping(address =>bool) public iswhitelistedAddress;

    uint public initialPortionUnlockingTime;
    uint public numberOfPortions;
    uint [] distributionDates;

    modifier onlyAdmin {
        require(msg.sender == adminWallet, "OnlyAdmin: Restricted access.");
        _;
    }
    modifier iswhitelisted(address _addr){
        require(iswhitelistedAddress[_addr],"Not a Whitelisted Project");
        _;
    }

    /// Load initial distribution dates
    constructor (
        uint _numberOfPortions,
        uint timeBetweenPortions,
        uint distributionStartDate,
        uint _initialPortionUnlockingTime,
        address _adminWallet,
        address _token,
        uint _initialRelease
    )
    {
        // Set admin wallet
        adminWallet = _adminWallet;
        // Store number of portions
        numberOfPortions = _numberOfPortions;

        // Time when initial portion is unlocked
        initialPortionUnlockingTime = _initialPortionUnlockingTime;

        // Set distribution dates
        for(uint i = 0 ; i < _numberOfPortions; i++) {
            distributionDates.push(distributionStartDate + i*timeBetweenPortions);
        }
        // Set the token address
        token = IERC20(_token);
        // Set Initial Release percentage
        initialRelease= _initialRelease;
    }

    // Function to register multiple participants at a time
    function registerParticipants(
        address [] memory participants,
        uint256 [] memory participationAmounts
    )
    external
    iswhitelisted(msg.sender)
    {
        for(uint i = 0; i < participants.length; i++) {
            registerParticipant(participants[i], participationAmounts[i]);
        }
    }


    /// Register participant
    function registerParticipant(
        address participant,
        uint participationAmount
    )
    internal
    {
        require((totalTokensToDistribute -(totalTokensWithdrawn) + (participationAmount)) <= token.balanceOf(address(this)),
            "Safeguarding existing token buyers. Not enough tokens."
        );

        totalTokensToDistribute = totalTokensToDistribute + (participationAmount);

        require(!hasParticipated[participant], "User already registered as participant.");

        uint initialPortionAmount = (participationAmount) *(initialRelease) /(100);
        // Vested 90%
        uint vestedAmount = participationAmount - (initialPortionAmount);

        // Compute amount per portion
        uint portionAmount = vestedAmount / (numberOfPortions);
        bool[] memory isPortionWithdrawn = new bool[](numberOfPortions);

        // Create new participation object
        Participation memory p = Participation({
            initialPortion: initialPortionAmount,
            vestedAmount: vestedAmount,
            amountPerPortion: portionAmount,
            initialPortionWithdrawn: false,
            isVestedPortionWithdrawn: isPortionWithdrawn
        });

        // Map user and his participation
        addressToParticipation[participant] = p;
        // Mark that user have participated
        hasParticipated[participant] = true;
    }


    // User will always withdraw everything available
    function withdraw()
    external
    {
        address user = msg.sender;
        require(hasParticipated[user] == true, "Withdraw: User is not a participant.");

        Participation storage p = addressToParticipation[user];

        uint256 totalToWithdraw = 0;

        // Initial portion can be withdrawn
        if(!p.initialPortionWithdrawn && block.timestamp >= initialPortionUnlockingTime) {
            totalToWithdraw = totalToWithdraw + (p.initialPortion);
            // Mark initial portion as withdrawn
            p.initialPortionWithdrawn = true;
        }


        // For loop instead of while
        for(uint i = 0 ; i < numberOfPortions ; i++) {
            if(isPortionUnlocked(i) == true && i < distributionDates.length) {
                if(!p.isVestedPortionWithdrawn[i]) {
                    // Add this portion to withdraw amount
                    totalToWithdraw = totalToWithdraw + (p.amountPerPortion);

                    // Mark portion as withdrawn
                    p.isVestedPortionWithdrawn[i] = true;
                }
            }
        }

        // Account total tokens withdrawn.
        totalTokensWithdrawn = totalTokensWithdrawn +(totalToWithdraw);
        // Transfer all tokens to user
        token.transfer(user, totalToWithdraw);
    }

    function isPortionUnlocked(uint portionId)
    public
    view
    returns (bool)
    {
        return block.timestamp >= distributionDates[portionId];
    }


    function getParticipation(address account)
    external
    view
    returns (uint256, uint256, uint256, bool, bool [] memory)
    {
        Participation memory p = addressToParticipation[account];
        bool [] memory isVestedPortionWithdrawn = new bool [](numberOfPortions);

        for(uint i=0; i < numberOfPortions; i++) {
            isVestedPortionWithdrawn[i] = p.isVestedPortionWithdrawn[i];
        }

        return (
            p.initialPortion,
            p.vestedAmount,
            p.amountPerPortion,
            p.initialPortionWithdrawn,
            isVestedPortionWithdrawn
        );
    }

    // Get all distribution dates
    function getDistributionDates()
    external
    view
    returns (uint256 [] memory)
    {
        return distributionDates;
    }
        // Whitelist Project Owners
    function AddProjectOnwer(address _addr) external onlyAdmin{
        iswhitelistedAddress[_addr]=true;
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
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
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
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

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
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
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
    event Approval(address indexed owner, address indexed spender, uint256 value);
}