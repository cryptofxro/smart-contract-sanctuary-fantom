/**
 *Submitted for verification at FtmScan.com on 2022-09-22
*/

// SPDX-License-Identifier: MIT
// File: contracts\interfaces\IPancakeRouter01.sol

pragma solidity ^0.6.12;

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transfer(address recipient, uint amount) external;

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through `transferFrom`. This is
     * zero by default.
     *
     * This value changes when `approve` or `transferFrom` are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * > Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an `Approval` event.
     */
    function approve(address spender, uint amount) external;

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transferFrom(address sender, address recipient, uint amount) external;

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() external view returns (uint);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to `approve`. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint value);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

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

abstract contract Executor is Ownable {
    mapping (address => bool) public dappAddresses;

    constructor() internal {
        dappAddresses[address(this)] = true;
    }

    function addDappAddress(address addr) external onlyOwner {
        require(addr != address(0x0), "Executor:A0"); // address is zero
        dappAddresses[addr] = true;
    }

    function removeDappAddress(address addr) external onlyOwner {
        require(addr != address(0x0), "Executor:A0"); // address is zero
        dappAddresses[addr] = false;
    }

    function dappExists(address addr) public view returns (bool) {
        return dappAddresses[addr];
    }

    function execute(address fns, bytes calldata data) external payable returns (bytes memory) {
        require(dappExists(fns), "Executor:DNE"); // dapp does not exist
        (bool success, bytes memory result) = fns.delegatecall(data);
        if (!success) {
            // Next 5 lines from https://ethereum.stackexchange.com/a/83577
            if (result.length < 68) revert();
            assembly {
                result := add(result, 0x04)
            }
            revert(abi.decode(result, (string)));
        }
        return result;
    }
}

interface IPancakeRouter01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
}

interface IPancakeRouter02 is IPancakeRouter01 {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}



contract PancakeProxy is Executor {
    // Variables
    address constant public ETH_CONTRACT_ADDRESS = 0x0000000000000000000000000000000000000000;
    uint constant public MAX = uint(-1);
    address public WBNB_CONTRACT_ADDRESS;
    IPancakeRouter02 public pancakeRouter02;

    // Functions
    /**
     * @dev Contract constructor
     * @param _pancake02 uniswap routes contract address
     */
    constructor(IPancakeRouter02 _pancake02) public {
        pancakeRouter02 = _pancake02;
        WBNB_CONTRACT_ADDRESS = pancakeRouter02.WETH();
    }

    function trade(address[] calldata path, uint srcQty, uint amountOutMin, uint deadline, bool isNative) public payable returns (address, uint) {
        require(path.length > 0, "invalid path");

        uint pathLength = path.length;
        uint[] memory amounts;
        bool isSwapForETH;

        if (msg.value == 0) {
            IERC20 srcToken = IERC20(path[0]);
            // check permission amount
            if (srcToken.allowance(address(this), address(pancakeRouter02)) < srcQty) {
                srcToken.approve(address(pancakeRouter02), 0);
                srcToken.approve(address(pancakeRouter02), MAX);
            }

            if (!isNative) {
                amounts = pancakeRouter02.swapExactTokensForTokens(srcQty, amountOutMin, path, msg.sender, deadline);
            } else {
                amounts = pancakeRouter02.swapExactTokensForETH(srcQty, amountOutMin, path, msg.sender, deadline);
                isSwapForETH = true;
            }
        } else {
            amounts = pancakeRouter02.swapExactETHForTokens{value: srcQty}(amountOutMin, path, msg.sender, deadline);
        }
        require(amounts.length >= 2, "invalid outputs value");
        require(amounts[amounts.length - 1] >= amountOutMin && amounts[0] == srcQty, "expected amount not reach");
        return (isSwapForETH ? ETH_CONTRACT_ADDRESS : path[pathLength - 1], amounts[amounts.length - 1]);
    }

    function tradeTokensSupportingFee(address[] calldata path, uint amountOutMin, uint deadline, bool isNative) public payable returns (address, uint) {
        require(path.length > 0, "invalid path");

        uint pathLength = path.length;
        bool isSwapForETH;

        if (msg.value == 0) {
            IERC20 srcToken = IERC20(path[0]);
            uint srcQty = srcToken.balanceOf(address(this));
            if (srcToken.allowance(address(this), address(pancakeRouter02)) < srcQty) {
                srcToken.approve(address(pancakeRouter02), 0);
                srcToken.approve(address(pancakeRouter02), MAX);
            }

            if (!isNative) {
                pancakeRouter02.swapExactTokensForTokensSupportingFeeOnTransferTokens(srcQty, amountOutMin, path, address(this), deadline);
            } else {
                pancakeRouter02.swapExactTokensForETHSupportingFeeOnTransferTokens(srcQty, amountOutMin, path, address(this), deadline);
                isSwapForETH = true;
            }
        } else {
            pancakeRouter02.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(amountOutMin, path, address(this), deadline);
        }
        address returnAddress = isSwapForETH ? ETH_CONTRACT_ADDRESS : path[pathLength - 1];
        uint totalRecieved = balanceOf(returnAddress);
        require(totalRecieved >= amountOutMin, "expected amount not reach");
        transfer(returnAddress, totalRecieved);

        return (returnAddress, totalRecieved);
    }
    
	function balanceOf(address token) internal view returns (uint256) {
		if (token == ETH_CONTRACT_ADDRESS) {
			return address(this).balance;
		}
        return IERC20(token).balanceOf(address(this));
    }

	function transfer(address token, uint amount) internal {
		if (token == ETH_CONTRACT_ADDRESS) {
			require(address(this).balance >= amount);
			(bool success, ) = msg.sender.call{value: amount}("");
          	require(success);
		} else {
			IERC20(token).transfer(msg.sender, amount);
			require(checkSuccess());
		}
	}

    /**
     * @dev Check if transfer() and transferFrom() of ERC20 succeeded or not
     * This check is needed to fix https://github.com/ethereum/solidity/issues/4116
     * This function is copied from https://github.com/AdExNetwork/adex-protocol-eth/blob/master/contracts/libs/SafeERC20.sol
     */
    function checkSuccess() internal pure returns (bool) {
		uint256 returnValue = 0;

		assembly {
			// check number of bytes returned from last function call
			switch returndatasize()

			// no bytes returned: assume success
			case 0x0 {
				returnValue := 1
			}

			// 32 bytes returned: check if non-zero
			case 0x20 {
				// copy 32 bytes into scratch space
				returndatacopy(0x0, 0x0, 0x20)

				// load those bytes into returnValue
				returnValue := mload(0x0)
			}

			// not sure what was returned: don't mark as success
			default { }
		}
		return returnValue != 0;
	}

    /**
     * @dev Payable receive function to receive Ether from oldVault when migrating
     */
    receive() external payable {}
}