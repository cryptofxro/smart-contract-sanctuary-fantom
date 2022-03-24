pragma solidity 0.8.4;
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

import './lib/Babylonian.sol';
import './lib/FixedPoint.sol';
import './lib/UniswapV2OracleLibrary.sol';
import './Epoch.sol';
import './Interfaces/IUniswapV2Pair.sol';
import './Interfaces/IUniswapV2Factory.sol';

// fixed window oracle that recomputes the average price for the entire period once every period
// note that the price average is only guaranteed to be over at least 1 period, but may be over a longer period
contract DollarOracle is Epoch {
	using FixedPoint for *;
	using SafeMath for uint256;

	/* ========== STATE VARIABLES ========== */

	// uniswap
	address public token0;
	address public token1;
	IUniswapV2Pair public pair;

	// oracle
	uint32 public blockTimestampLast;
	uint256 public price0CumulativeLast;
	uint256 public price1CumulativeLast;
	FixedPoint.uq112x112 public price0Average;
	FixedPoint.uq112x112 public price1Average;

	/* ========== CONSTRUCTOR ========== */

	constructor(
		IUniswapV2Pair _pair,
		uint256 _period,
		uint256 _startTime
	) Epoch(_period, _startTime, 0) {
		pair = _pair;
		token0 = pair.token0();
		token1 = pair.token1();
		price0CumulativeLast = pair.price0CumulativeLast(); // fetch the current accumulated price value (1 / 0)
		price1CumulativeLast = pair.price1CumulativeLast(); // fetch the current accumulated price value (0 / 1)
		uint112 reserve0;
		uint112 reserve1;
		(reserve0, reserve1, blockTimestampLast) = pair.getReserves();
		require(reserve0 != 0 && reserve1 != 0, 'Oracle: NO_RESERVES'); // ensure that there's liquidity in the pair
	}

	/* ========== MUTABLE FUNCTIONS ========== */

	/** @dev Updates 1-day EMA price from Uniswap.  */
	function update() external checkEpoch {
		(
			uint256 price0Cumulative,
			uint256 price1Cumulative,
			uint32 blockTimestamp
		) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
		uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

		if (timeElapsed == 0) {
			// prevent divided by zero
			return;
		}

		// overflow is desired, casting never truncates
		// cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
		price0Average = FixedPoint.uq112x112(
			uint224((price0Cumulative - price0CumulativeLast) / timeElapsed)
		);
		price1Average = FixedPoint.uq112x112(
			uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)
		);

		price0CumulativeLast = price0Cumulative;
		price1CumulativeLast = price1Cumulative;
		blockTimestampLast = blockTimestamp;

		emit Updated(price0Cumulative, price1Cumulative);
	}

	// note this will always return 0 before update has been called successfully for the first time.
	function consult(address _token, uint256 _amountIn)
		external
		view
		returns (uint144 amountOut)
	{
		if (_token == token0) {
			amountOut = price0Average.mul(_amountIn).decode144();
		} else {
			require(_token == token1, 'Oracle: INVALID_TOKEN');
			amountOut = price1Average.mul(_amountIn).decode144();
		}
	}

	function twap(address _token, uint256 _amountIn)
		external
		view
		returns (uint144 _amountOut)
	{
		(
			uint256 price0Cumulative,
			uint256 price1Cumulative,
			uint32 blockTimestamp
		) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
		uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
		if (_token == token0) {
			_amountOut = FixedPoint
				.uq112x112(
					uint224(
						(price0Cumulative - price0CumulativeLast) / timeElapsed
					)
				)
				.mul(_amountIn)
				.decode144();
		} else if (_token == token1) {
			_amountOut = FixedPoint
				.uq112x112(
					uint224(
						(price1Cumulative - price1CumulativeLast) / timeElapsed
					)
				)
				.mul(_amountIn)
				.decode144();
		}
	}

	event Updated(uint256 price0CumulativeLast, uint256 price1CumulativeLast);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is no longer needed starting with Solidity 0.8. The compiler
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

pragma solidity 0.8.4;
import '../lib/FixedPoint.sol';
import '../Interfaces/IUniswapV2Pair.sol';

// library with helper methods for oracles that are concerned with computing average prices
library UniswapV2OracleLibrary {
	using FixedPoint for *;

	// helper function that returns the current block timestamp within the range of uint32, i.e. [0, 2**32 - 1]
	function currentBlockTimestamp() internal view returns (uint32) {
		return uint32(block.timestamp % 2**32);
	}

	// produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
	function currentCumulativePrices(address pair)
		internal
		view
		returns (
			uint256 price0Cumulative,
			uint256 price1Cumulative,
			uint32 blockTimestamp
		)
	{
		blockTimestamp = currentBlockTimestamp();
		price0Cumulative = IUniswapV2Pair(pair).price0CumulativeLast();
		price1Cumulative = IUniswapV2Pair(pair).price1CumulativeLast();

		// if time has elapsed since the last update on the pair, mock the accumulated price values
		(
			uint112 reserve0,
			uint112 reserve1,
			uint32 blockTimestampLast
		) = IUniswapV2Pair(pair).getReserves();
		if (blockTimestampLast != blockTimestamp) {
			// subtraction overflow is desired
			uint32 timeElapsed = blockTimestamp - blockTimestampLast;
			// addition overflow is desired
			// counterfactual
			price0Cumulative +=
				uint256(FixedPoint.fraction(reserve1, reserve0)._x) *
				timeElapsed;
			// counterfactual
			price1Cumulative +=
				uint256(FixedPoint.fraction(reserve0, reserve1)._x) *
				timeElapsed;
		}
	}
}

pragma solidity 0.8.4;
import './Babylonian.sol';

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))
library FixedPoint {
	// range: [0, 2**112 - 1]
	// resolution: 1 / 2**112
	struct uq112x112 {
		uint224 _x;
	}

	// range: [0, 2**144 - 1]
	// resolution: 1 / 2**112
	struct uq144x112 {
		uint256 _x;
	}

	uint8 private constant RESOLUTION = 112;
	uint256 private constant Q112 = uint256(1) << RESOLUTION;
	uint256 private constant Q224 = Q112 << RESOLUTION;

	// encode a uint112 as a UQ112x112
	function encode(uint112 x) internal pure returns (uq112x112 memory) {
		return uq112x112(uint224(x) << RESOLUTION);
	}

	// encodes a uint144 as a UQ144x112
	function encode144(uint144 x) internal pure returns (uq144x112 memory) {
		return uq144x112(uint256(x) << RESOLUTION);
	}

	// divide a UQ112x112 by a uint112, returning a UQ112x112
	function div(uq112x112 memory self, uint112 x)
		internal
		pure
		returns (uq112x112 memory)
	{
		require(x != 0, 'FixedPoint: DIV_BY_ZERO');
		return uq112x112(self._x / uint224(x));
	}

	// multiply a UQ112x112 by a uint, returning a UQ144x112
	// reverts on overflow
	function mul(uq112x112 memory self, uint256 y)
		internal
		pure
		returns (uq144x112 memory)
	{
		uint256 z;
		require(
			y == 0 || (z = uint256(self._x) * y) / y == uint256(self._x),
			'FixedPoint: MULTIPLICATION_OVERFLOW'
		);
		return uq144x112(z);
	}

	// returns a UQ112x112 which represents the ratio of the numerator to the denominator
	// equivalent to encode(numerator).div(denominator)
	function fraction(uint112 numerator, uint112 denominator)
		internal
		pure
		returns (uq112x112 memory)
	{
		require(denominator > 0, 'FixedPoint: DIV_BY_ZERO');
		return uq112x112((uint224(numerator) << RESOLUTION) / denominator);
	}

	// decode a UQ112x112 into a uint112 by truncating after the radix point
	function decode(uq112x112 memory self) internal pure returns (uint112) {
		return uint112(self._x >> RESOLUTION);
	}

	// decode a UQ144x112 into a uint144 by truncating after the radix point
	function decode144(uq144x112 memory self) internal pure returns (uint144) {
		return uint144(self._x >> RESOLUTION);
	}

	// take the reciprocal of a UQ112x112
	function reciprocal(uq112x112 memory self)
		internal
		pure
		returns (uq112x112 memory)
	{
		require(self._x != 0, 'FixedPoint: ZERO_RECIPROCAL');
		return uq112x112(uint224(Q224 / self._x));
	}

	// square root of a UQ112x112
	function sqrt(uq112x112 memory self)
		internal
		pure
		returns (uq112x112 memory)
	{
		return uq112x112(uint224(Babylonian.sqrt(uint256(self._x)) << 56));
	}
}

pragma solidity 0.8.4;

library Babylonian {
	function sqrt(uint256 y) internal pure returns (uint256 z) {
		if (y > 3) {
			z = y;
			uint256 x = y / 2 + 1;
			while (x < z) {
				z = x;
				x = (y / x + x) / 2;
			}
		} else if (y != 0) {
			z = 1;
		}
		// else z = 0
	}
}

pragma solidity 0.8.4;

interface IUniswapV2Pair {
	event Approval(
		address indexed owner,
		address indexed spender,
		uint256 value
	);
	event Transfer(address indexed from, address indexed to, uint256 value);

	function name() external pure returns (string memory);

	function symbol() external pure returns (string memory);

	function decimals() external pure returns (uint8);

	function totalSupply() external view returns (uint256);

	function balanceOf(address owner) external view returns (uint256);

	function allowance(address owner, address spender)
		external
		view
		returns (uint256);

	function approve(address spender, uint256 value) external returns (bool);

	function transfer(address to, uint256 value) external returns (bool);

	function transferFrom(
		address from,
		address to,
		uint256 value
	) external returns (bool);

	function DOMAIN_SEPARATOR() external view returns (bytes32);

	function PERMIT_TYPEHASH() external pure returns (bytes32);

	function nonces(address owner) external view returns (uint256);

	function permit(
		address owner,
		address spender,
		uint256 value,
		uint256 deadline,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external;

	event Mint(address indexed sender, uint256 amount0, uint256 amount1);
	event Burn(
		address indexed sender,
		uint256 amount0,
		uint256 amount1,
		address indexed to
	);
	event Swap(
		address indexed sender,
		uint256 amount0In,
		uint256 amount1In,
		uint256 amount0Out,
		uint256 amount1Out,
		address indexed to
	);
	event Sync(uint112 reserve0, uint112 reserve1);

	function MINIMUM_LIQUIDITY() external pure returns (uint256);

	function factory() external view returns (address);

	function token0() external view returns (address);

	function token1() external view returns (address);

	function getReserves()
		external
		view
		returns (
			uint112 reserve0,
			uint112 reserve1,
			uint32 blockTimestampLast
		);

	function price0CumulativeLast() external view returns (uint256);

	function price1CumulativeLast() external view returns (uint256);

	function kLast() external view returns (uint256);

	function mint(address to) external returns (uint256 liquidity);

	function burn(address to)
		external
		returns (uint256 amount0, uint256 amount1);

	function swap(
		uint256 amount0Out,
		uint256 amount1Out,
		address to,
		bytes calldata data
	) external;

	function skim(address to) external;

	function sync() external;

	function initialize(address, address) external;
}

pragma solidity 0.8.4;

interface IUniswapV2Factory {
	event PairCreated(
		address indexed token0,
		address indexed token1,
		address pair,
		uint256
	);

	function feeTo() external view returns (address);

	function feeToSetter() external view returns (address);

	function getPair(address tokenA, address tokenB)
		external
		view
		returns (address pair);

	function allPairs(uint256) external view returns (address pair);

	function allPairsLength() external view returns (uint256);

	function createPair(address tokenA, address tokenB)
		external
		returns (address pair);

	function setFeeTo(address) external;

	function setFeeToSetter(address) external;
}

pragma solidity 0.8.4;
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract Epoch {
	using SafeMath for uint256;

	uint256 private immutable period;
	uint256 private startTime;
	uint256 private epoch;

	/* ========== CONSTRUCTOR ========== */

	constructor(
		uint256 _period,
		uint256 _startTime,
		uint256 _startEpoch
	) {
		period = _period;
		startTime = _startTime;
		epoch = _startEpoch;
	}

	/* ========== Modifier ========== */

	modifier checkStartTime() {
		require(block.timestamp >= startTime, 'Epoch: not started yet');

		_;
	}

	modifier checkEpoch() {
		require(block.timestamp >= nextEpochPoint(), 'Epoch: not allowed');

		_;

		epoch = epoch.add(1);
	}

	/* ========== VIEW FUNCTIONS ========== */

	function getCurrentEpoch() external view returns (uint256) {
		return epoch;
	}

	function getPeriod() external view returns (uint256) {
		return period;
	}

	function getStartTime() external view returns (uint256) {
		return startTime;
	}

	function nextEpochPoint() public view returns (uint256) {
		return startTime.add(epoch.mul(period));
	}
}