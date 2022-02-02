/**
 *Submitted for verification at FtmScan.com on 2022-02-02
*/

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


pragma solidity >=0.6.4;

interface IBEP20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the token name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view returns (address);

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
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address _owner, address spender) external view returns (uint256);

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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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


pragma solidity >=0.6.0 <0.8.0;

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
    constructor () internal {
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
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


pragma solidity 0.6.12;

interface IPool {
    function stopReward() external;
    function emergencyRewardWithdraw(uint256 _amount) external;
    function updateRewardPerBlock(uint256 _rewardPerBlock) external;
    function updateBonusEndBlock(uint256 _bonusEndBlock) external;
    function updateStartBlock(uint256 _startBlock) external;
    function setLockupDuration(uint256 _lockupDuration) external;
    function setWithdrawalFeeBP(uint256 _withdrawalFeeBP) external;

    function updateDepositFeeBP(uint256 _pid, uint16 _depositFeeBP) external;
    function emergencyRewardWithdraw(uint256 _pid, uint256 _amount) external;
    function updateWithdrawalFeeBP(uint256 _pid, uint16 _withdrawalFeeBP) external;
    
    function rewardToken() external view returns (address);
    function native() external view returns (address);
}


pragma solidity 0.6.12;

contract PoolWrap is Ownable {

    IPool public pool;
    
    constructor(IPool _pool) public {
        pool = _pool;
    }

    function stopReward() public onlyOwner {
        pool.stopReward();
    }

    function emergencyRewardWithdraw(uint256 _amount) public onlyOwner {
        pool.emergencyRewardWithdraw(_amount);
        IBEP20(pool.native()).transfer(address(msg.sender), _amount);
    }
    
    function updateRewardPerBlock(uint256 _rewardPerBlock) public onlyOwner {
        pool.updateRewardPerBlock(_rewardPerBlock);
    } 
    
    function updateBonusEndBlock(uint256 _bonusEndBlock) public onlyOwner {
        pool.updateBonusEndBlock(_bonusEndBlock);
    }   
    
    function updateStartBlock(uint256 _startBlock) public onlyOwner {
        pool.updateStartBlock(_startBlock);
    }   
    
    function setLockupDuration(uint256 _lockupDuration) public onlyOwner {
        pool.setLockupDuration(_lockupDuration);
    }
    
    function setWithdrawalFeeBP(uint256 _withdrawalFeeBP) public onlyOwner {
        require(_withdrawalFeeBP <= 300, "withdrawal fee to high");
        pool.setWithdrawalFeeBP(_withdrawalFeeBP);
    }
    
    function updateDepositFeeBP(uint256 _pid, uint16 _depositFeeBP) public onlyOwner {
        require(_depositFeeBP <= 300, "deposit fee to high");
        pool.updateDepositFeeBP(_pid, _depositFeeBP);
    }

    function emergencyRewardWithdraw(uint256 _pid, uint256 _amount) public onlyOwner {
        pool.emergencyRewardWithdraw(_pid, _amount);
        IBEP20(pool.rewardToken()).transfer(address(msg.sender), _amount);
    }

    function updateWithdrawalFeeBP(uint256 _pid, uint16 _withdrawalFeeBP) public onlyOwner {
        require(_withdrawalFeeBP <= 300, "withdrawal fee to high");
        pool.updateWithdrawalFeeBP(_pid, _withdrawalFeeBP);
    }
}