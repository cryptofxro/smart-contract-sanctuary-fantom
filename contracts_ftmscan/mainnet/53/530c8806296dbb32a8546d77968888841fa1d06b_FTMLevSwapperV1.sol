/**
 *Submitted for verification at FtmScan.com on 2021-11-19
*/

// File @boringcrypto/boring-solidity/contracts/libraries/[email protected]
// License-Identifier: MIT
pragma solidity 0.6.12;

/// @notice A library for performing overflow-/underflow-safe math,
/// updated with awesomeness from of DappHub (https://github.com/dapphub/ds-math).
library BoringMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require(b == 0 || (c = a * b) / b == a, "BoringMath: Mul Overflow");
    }

    function to128(uint256 a) internal pure returns (uint128 c) {
        require(a <= uint128(-1), "BoringMath: uint128 Overflow");
        c = uint128(a);
    }

    function to64(uint256 a) internal pure returns (uint64 c) {
        require(a <= uint64(-1), "BoringMath: uint64 Overflow");
        c = uint64(a);
    }

    function to32(uint256 a) internal pure returns (uint32 c) {
        require(a <= uint32(-1), "BoringMath: uint32 Overflow");
        c = uint32(a);
    }
}

/// @notice A library for performing overflow-/underflow-safe addition and subtraction on uint128.
library BoringMath128 {
    function add(uint128 a, uint128 b) internal pure returns (uint128 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint128 a, uint128 b) internal pure returns (uint128 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }
}

/// @notice A library for performing overflow-/underflow-safe addition and subtraction on uint64.
library BoringMath64 {
    function add(uint64 a, uint64 b) internal pure returns (uint64 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint64 a, uint64 b) internal pure returns (uint64 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }
}

/// @notice A library for performing overflow-/underflow-safe addition and subtraction on uint32.
library BoringMath32 {
    function add(uint32 a, uint32 b) internal pure returns (uint32 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint32 a, uint32 b) internal pure returns (uint32 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }
}

// File @sushiswap/core/contracts/uniswapv2/interfaces/[email protected]
// License-Identifier: GPL-3.0

pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function migrator() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function setMigrator(address) external;
}

// File @sushiswap/core/contracts/uniswapv2/interfaces/[email protected]
// License-Identifier: GPL-3.0

pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

// File @boringcrypto/boring-solidity/contracts/interfaces/[email protected]
// License-Identifier: MIT
pragma solidity 0.6.12;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice EIP 2612
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

// File @boringcrypto/boring-solidity/contracts/libraries/[email protected]
// License-Identifier: MIT
pragma solidity 0.6.12;

struct Rebase {
    uint128 elastic;
    uint128 base;
}

/// @notice A rebasing library using overflow-/underflow-safe math.
library RebaseLibrary {
    using BoringMath for uint256;
    using BoringMath128 for uint128;

    /// @notice Calculates the base value in relationship to `elastic` and `total`.
    function toBase(
        Rebase memory total,
        uint256 elastic,
        bool roundUp
    ) internal pure returns (uint256 base) {
        if (total.elastic == 0) {
            base = elastic;
        } else {
            base = elastic.mul(total.base) / total.elastic;
            if (roundUp && base.mul(total.elastic) / total.base < elastic) {
                base = base.add(1);
            }
        }
    }

    /// @notice Calculates the elastic value in relationship to `base` and `total`.
    function toElastic(
        Rebase memory total,
        uint256 base,
        bool roundUp
    ) internal pure returns (uint256 elastic) {
        if (total.base == 0) {
            elastic = base;
        } else {
            elastic = base.mul(total.elastic) / total.base;
            if (roundUp && elastic.mul(total.base) / total.elastic < base) {
                elastic = elastic.add(1);
            }
        }
    }

    /// @notice Add `elastic` to `total` and doubles `total.base`.
    /// @return (Rebase) The new total.
    /// @return base in relationship to `elastic`.
    function add(
        Rebase memory total,
        uint256 elastic,
        bool roundUp
    ) internal pure returns (Rebase memory, uint256 base) {
        base = toBase(total, elastic, roundUp);
        total.elastic = total.elastic.add(elastic.to128());
        total.base = total.base.add(base.to128());
        return (total, base);
    }

    /// @notice Sub `base` from `total` and update `total.elastic`.
    /// @return (Rebase) The new total.
    /// @return elastic in relationship to `base`.
    function sub(
        Rebase memory total,
        uint256 base,
        bool roundUp
    ) internal pure returns (Rebase memory, uint256 elastic) {
        elastic = toElastic(total, base, roundUp);
        total.elastic = total.elastic.sub(elastic.to128());
        total.base = total.base.sub(base.to128());
        return (total, elastic);
    }

    /// @notice Add `elastic` and `base` to `total`.
    function add(
        Rebase memory total,
        uint256 elastic,
        uint256 base
    ) internal pure returns (Rebase memory) {
        total.elastic = total.elastic.add(elastic.to128());
        total.base = total.base.add(base.to128());
        return total;
    }

    /// @notice Subtract `elastic` and `base` to `total`.
    function sub(
        Rebase memory total,
        uint256 elastic,
        uint256 base
    ) internal pure returns (Rebase memory) {
        total.elastic = total.elastic.sub(elastic.to128());
        total.base = total.base.sub(base.to128());
        return total;
    }

    /// @notice Add `elastic` to `total` and update storage.
    /// @return newElastic Returns updated `elastic`.
    function addElastic(Rebase storage total, uint256 elastic) internal returns (uint256 newElastic) {
        newElastic = total.elastic = total.elastic.add(elastic.to128());
    }

    /// @notice Subtract `elastic` from `total` and update storage.
    /// @return newElastic Returns updated `elastic`.
    function subElastic(Rebase storage total, uint256 elastic) internal returns (uint256 newElastic) {
        newElastic = total.elastic = total.elastic.sub(elastic.to128());
    }
}

// File @sushiswap/bentobox-sdk/contracts/[email protected]
// License-Identifier: MIT
pragma solidity 0.6.12;

interface IBatchFlashBorrower {
    function onBatchFlashLoan(
        address sender,
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata fees,
        bytes calldata data
    ) external;
}

// File @sushiswap/bentobox-sdk/contracts/[email protected]
// License-Identifier: MIT
pragma solidity 0.6.12;

interface IFlashBorrower {
    function onFlashLoan(
        address sender,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external;
}

// File @sushiswap/bentobox-sdk/contracts/[email protected]
// License-Identifier: MIT
pragma solidity 0.6.12;

interface IStrategy {
    // Send the assets to the Strategy and call skim to invest them
    function skim(uint256 amount) external;

    // Harvest any profits made converted to the asset and pass them to the caller
    function harvest(uint256 balance, address sender) external returns (int256 amountAdded);

    // Withdraw assets. The returned amount can differ from the requested amount due to rounding.
    // The actualAmount should be very close to the amount. The difference should NOT be used to report a loss. That's what harvest is for.
    function withdraw(uint256 amount) external returns (uint256 actualAmount);

    // Withdraw all assets in the safest way possible. This shouldn't fail.
    function exit(uint256 balance) external returns (int256 amountAdded);
}

// File @sushiswap/bentobox-sdk/contracts/[email protected]
// License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;





interface IBentoBoxV1 {
    event LogDeploy(address indexed masterContract, bytes data, address indexed cloneAddress);
    event LogDeposit(address indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);
    event LogFlashLoan(address indexed borrower, address indexed token, uint256 amount, uint256 feeAmount, address indexed receiver);
    event LogRegisterProtocol(address indexed protocol);
    event LogSetMasterContractApproval(address indexed masterContract, address indexed user, bool approved);
    event LogStrategyDivest(address indexed token, uint256 amount);
    event LogStrategyInvest(address indexed token, uint256 amount);
    event LogStrategyLoss(address indexed token, uint256 amount);
    event LogStrategyProfit(address indexed token, uint256 amount);
    event LogStrategyQueued(address indexed token, address indexed strategy);
    event LogStrategySet(address indexed token, address indexed strategy);
    event LogStrategyTargetPercentage(address indexed token, uint256 targetPercentage);
    event LogTransfer(address indexed token, address indexed from, address indexed to, uint256 share);
    event LogWhiteListMasterContract(address indexed masterContract, bool approved);
    event LogWithdraw(address indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    function balanceOf(IERC20, address) external view returns (uint256);
    function batch(bytes[] calldata calls, bool revertOnFail) external payable returns (bool[] memory successes, bytes[] memory results);
    function batchFlashLoan(IBatchFlashBorrower borrower, address[] calldata receivers, IERC20[] calldata tokens, uint256[] calldata amounts, bytes calldata data) external;
    function claimOwnership() external;
    function deploy(address masterContract, bytes calldata data, bool useCreate2) external payable;
    function deposit(IERC20 token_, address from, address to, uint256 amount, uint256 share) external payable returns (uint256 amountOut, uint256 shareOut);
    function flashLoan(IFlashBorrower borrower, address receiver, IERC20 token, uint256 amount, bytes calldata data) external;
    function harvest(IERC20 token, bool balance, uint256 maxChangeAmount) external;
    function masterContractApproved(address, address) external view returns (bool);
    function masterContractOf(address) external view returns (address);
    function nonces(address) external view returns (uint256);
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function pendingStrategy(IERC20) external view returns (IStrategy);
    function permitToken(IERC20 token, address from, address to, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function registerProtocol() external;
    function setMasterContractApproval(address user, address masterContract, bool approved, uint8 v, bytes32 r, bytes32 s) external;
    function setStrategy(IERC20 token, IStrategy newStrategy) external;
    function setStrategyTargetPercentage(IERC20 token, uint64 targetPercentage_) external;
    function strategy(IERC20) external view returns (IStrategy);
    function strategyData(IERC20) external view returns (uint64 strategyStartDate, uint64 targetPercentage, uint128 balance);
    function toAmount(IERC20 token, uint256 share, bool roundUp) external view returns (uint256 amount);
    function toShare(IERC20 token, uint256 amount, bool roundUp) external view returns (uint256 share);
    function totals(IERC20) external view returns (Rebase memory totals_);
    function transfer(IERC20 token, address from, address to, uint256 share) external;
    function transferMultiple(IERC20 token, address from, address[] calldata tos, uint256[] calldata shares) external;
    function transferOwnership(address newOwner, bool direct, bool renounce) external;
    function whitelistMasterContract(address masterContract, bool approved) external;
    function whitelistedMasterContracts(address) external view returns (bool);
    function withdraw(IERC20 token_, address from, address to, uint256 amount, uint256 share) external returns (uint256 amountOut, uint256 shareOut);
}

// File contracts/swappers/Leverage/FTMLevSwapper.sol
// License-Identifier: MIT
pragma solidity 0.6.12;




contract FTMLevSwapperV1{
    using BoringMath for uint256;

    // Local variables
    IBentoBoxV1 public constant bentoBox = IBentoBoxV1(0xF5BCE5077908a1b7370B9ae04AdC565EBd643966);
    IUniswapV2Pair constant pair = IUniswapV2Pair(0x47F2653E97d55b2C8667233360ce9351BC6Bc834);
    IERC20 constant WFTM = IERC20(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    IERC20 public constant MIM = IERC20(0x425CCC1390bed338D98dAfF91FF0F03738B534ef);

    // Given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn.mul(997);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // Given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        uint256 numerator = reserveIn.mul(amountOut).mul(1000);
        uint256 denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    // Swaps to a flexible amount, from an exact input amount
    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom
    ) public returns (uint256 extraShare, uint256 shareReturned) {

        (uint256 amountFrom, ) = bentoBox.withdraw(MIM, address(this), address(pair), 0, shareFrom);

        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        
        uint256  amountTo = getAmountOut(amountFrom, reserve1, reserve0);
        pair.swap(amountTo, 0, address(bentoBox), new bytes(0));

        (, shareReturned) = bentoBox.deposit(WFTM, address(bentoBox), recipient, amountTo, 0);
        extraShare = shareReturned.sub(shareToMin);
    }
}