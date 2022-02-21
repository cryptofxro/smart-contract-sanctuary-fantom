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

// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFantasm is IERC20 {
    function mint(address _address, uint256 _amount) external;

    function burn(uint256 _amount) external;

    function setRewarder(address _rewarder) external returns (bool);

    function setTreasuryFund(address _rewarder)
        external
        returns (
            uint256 _allocation,
            uint256 _vestingDuration,
            uint256 _vestingStart
        );

    function setDevFund(address _rewarder)
        external
        returns (
            uint256 _allocation,
            uint256 _vestingDuration,
            uint256 _vestingStart
        );

    function setPool(address _pool) external returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IFantasmOracle {
    function getFantasmPrice() external view returns (uint256);

    function getFantasmTWAP() external view returns (uint256);

    function getXftmTWAP() external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface ITreasury {
    function maxXftmSupply() external view returns (uint256);

    function info()
        external
        view
        returns (
            uint256 _collateralRatio,
            uint256 _mintingFee,
            uint256 _redemptionFee
        );
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IXftm is IERC20 {
    function burn(address _address, uint256 _amount) external;

    function burn(uint256 _amount) external;

    function mint(address _address, uint256 _amount) external;

    function setMinter(address _minter) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;
import "../interfaces/IXftm.sol";
import "../interfaces/IFantasm.sol";
import "../interfaces/IFantasmOracle.sol";
import "../interfaces/ITreasury.sol";

// To provide views with current on-chain data
contract FantasmLens {
    uint256 private constant PRICE_PRECISION = 1e18;
    uint256 private constant COLLATERAL_RATIO_MAX = 1e6;
    uint256 private constant PRECISION = 1e6;

    IFantasmOracle public fantasmOracle;
    ITreasury public treasury;

    constructor(address _treasury, address _oracle) {
        treasury = ITreasury(_treasury);
        fantasmOracle = IFantasmOracle(_oracle);
    }

    /// @notice Calculate the expected results for minting
    /// @param _ftmIn Amount of FTM input.
    /// @param _fantasmIn Amount of FSM input.
    /// @return _xftmOut : the amount of XFTM output.
    /// @return _minFtmIn : the required amount of FSM input.
    /// @return _minFantasmIn : the required amount of FSM input.
    /// @return _fee : the fee amount in FTM.
    function calcMint(uint256 _ftmIn, uint256 _fantasmIn)
        public
        view
        returns (
            uint256 _xftmOut,
            uint256 _minFtmIn,
            uint256 _minFantasmIn,
            uint256 _fee
        )
    {
        (uint256 _cr, uint256 _mintingFee, ) = treasury.info();
        uint256 _fantasmPrice = fantasmOracle.getFantasmPrice();
        require(_fantasmPrice > 0, "FantasmLens::calcMint: Invalid Fantasm price");
        uint256 _totalValue = 0; // total value in FTM

        if (_cr == COLLATERAL_RATIO_MAX || (_cr > 0 && _ftmIn > 0)) {
            _totalValue = (_ftmIn * COLLATERAL_RATIO_MAX) / _cr;
            _minFtmIn = _ftmIn;
            _minFantasmIn = ((_totalValue - _ftmIn) * PRICE_PRECISION) / _fantasmPrice;
        } else {
            uint256 _fantasmValue = (_fantasmIn * _fantasmPrice) / PRICE_PRECISION;
            _totalValue = (_fantasmValue * COLLATERAL_RATIO_MAX) / (COLLATERAL_RATIO_MAX - _cr);
            _minFantasmIn = _fantasmIn;
            _minFtmIn = _totalValue - _fantasmValue;
        }
        _xftmOut = _totalValue - ((_totalValue * _mintingFee) / PRECISION);
        _fee = (_ftmIn * _mintingFee) / PRECISION;
    }

    function calcZapMint(uint256 _ftmIn)
        public
        view
        returns (
            uint256 _xftmOut,
            uint256 _fantasmOut,
            uint256 _ftmFee,
            uint256 _ftmSwapIn
        )
    {
        (uint256 _cr, uint256 _mintingFee, ) = treasury.info();
        uint256 _fantasmPrice = fantasmOracle.getFantasmPrice();
        require(_fantasmPrice > 0, "Pool::calcZapMint: Invalid Fantasm price");
        _ftmSwapIn = (_ftmIn * (COLLATERAL_RATIO_MAX - _cr)) / COLLATERAL_RATIO_MAX;
        _fantasmOut = (_ftmSwapIn * PRICE_PRECISION) / _fantasmPrice;
        _ftmFee = (_ftmIn * _mintingFee * _cr) / COLLATERAL_RATIO_MAX / PRECISION;
        _xftmOut = _ftmIn - ((_ftmIn * _mintingFee) / PRECISION);
    }
}