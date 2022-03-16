/**
 *Submitted for verification at FtmScan.com on 2022-03-15
*/

// File: contracts/Context.sol


// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity >=0.5.0;

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
// File: contracts/Ownable.sol


// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity >=0.5.0;


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
// File: contracts/PeggerRewards.sol

pragma solidity >=0.5.0;



interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}



contract PeggerRewards is Ownable{
    address peggerContract;
    address wftm;
    uint256 feeRate;
    uint256 totalFee;
    constructor (uint256 _feeRate,address _wftm){
        wftm = _wftm;
        feeRate = _feeRate;

    }

    struct User {
        uint256 rewardAmount;
    }

    mapping(address=>User) public users;

    function depositRewards(address user,uint256 amount) external{
        IERC20(wftm).transferFrom(msg.sender,address(this),amount);
        uint256 fee = calculateFee(amount);
        sendFee(fee);
        users[user].rewardAmount += amount-fee;
    }

     function withdrawRewards (uint256 amount) external{
         if(users[msg.sender].rewardAmount>=amount){
             users[msg.sender].rewardAmount -= amount;
             IERC20(wftm).transfer(msg.sender,amount);
         }
    }
    function withdrawAll() external{
          require(IERC20(wftm).transfer(msg.sender,users[msg.sender].rewardAmount),"error in rewardAmount");
          users[msg.sender].rewardAmount = 0;
    }

    function emergencyWithdraw (uint256 amount) public onlyOwner{
        IERC20(wftm).transfer(msg.sender,amount);
    }

    function sendFee(uint256 amount) internal  {
        totalFee += amount;
    }
    function withdrawFee() public onlyOwner  {
        IERC20(wftm).transfer(msg.sender,totalFee);
    }

    function calculateFee(uint256 amount) internal returns(uint256 _amount) {
        uint256 fee = amount*feeRate/100;
        return fee;
    }

    function setPeggerContract(address _contract) public onlyOwner {
        peggerContract = _contract;
    }

    




}