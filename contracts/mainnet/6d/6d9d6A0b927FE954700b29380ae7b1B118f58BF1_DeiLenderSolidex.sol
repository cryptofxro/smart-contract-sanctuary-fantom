// Be name Khoda
// Bime Abolfazl
// SPDX-License-Identifier: GPL3.0-or-later

// =================================================================================================================
//  _|_|_|    _|_|_|_|  _|    _|    _|_|_|      _|_|_|_|  _|                                                       |
//  _|    _|  _|        _|    _|  _|            _|            _|_|_|      _|_|_|  _|_|_|      _|_|_|    _|_|       |
//  _|    _|  _|_|_|    _|    _|    _|_|        _|_|_|    _|  _|    _|  _|    _|  _|    _|  _|        _|_|_|_|     |
//  _|    _|  _|        _|    _|        _|      _|        _|  _|    _|  _|    _|  _|    _|  _|        _|           |
//  _|_|_|    _|_|_|_|    _|_|    _|_|_|        _|        _|  _|    _|    _|_|_|  _|    _|    _|_|_|    _|_|_|     |
// =================================================================================================================
// ==================== DEI Lender Solidex ===================
// ==========================================================
// DEUS Finance: https://github.com/deusfinance

// Primary Author(s)
// MRM: https://github.com/smrm-dev
// MMD: https://github.com/mmd-mostafaee

// Reviewer(s)
// Vahid: https://github.com/vahid-dev
// HHZ: https://github.com/hedzed

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "./interfaces/IMintHelper.sol";
import "./interfaces/IMuon.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@boringcrypto/boring-solidity/contracts/ERC20.sol";
import "@boringcrypto/boring-solidity/contracts/interfaces/IERC20.sol";
import "@boringcrypto/boring-solidity/contracts/interfaces/IMasterContract.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringRebase.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";
import {SolidexHolder as Holder} from "./SolidexHolder.sol";

interface LpDepositor {
    function getReward(address[] calldata pools) external;
}

interface HIERC20 {
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);
}

interface IOracle {
    function getOnChainPrice() external view returns (uint256);

    function getPrice(
        uint256 price,
        uint256 timestamp,
        bytes calldata reqId,
        SchnorrSign[] calldata sigs
    ) external returns (uint256);
}

contract DeiLenderSolidex is BoringOwnable {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using RebaseLibrary for Rebase;
    using BoringERC20 for IERC20;

    event UpdateAccrue(uint256 interest);
    event Borrow(address from, address to, uint256 amount, uint256 debt);
    event Repay(address from, address to, uint256 amount, uint256 repayAmount);
    event AddCollateral(address from, address to, uint256 amount);
    event RemoveCollateral(address from, address to, uint256 amount);
    event Liquidate(
        address liquidator,
        address user,
        uint256 collateralAmount,
        uint256 deiAmount
    );

    IERC20 public collateral;

    IERC20 public solid;
    IERC20 public solidex;
    address public lpDepositor;
    uint256 public maxCap;

    IOracle public oracle;

    uint256 public BORROW_OPENING_FEE;

    uint256 public LIQUIDATION_RATIO;

    uint256 public totalCollateral;
    Rebase public totalBorrow;

    mapping(address => uint256) public userCollateral;
    mapping(address => uint256) public userBorrow;
    mapping(address => address) public userHolder;

    address public mintHelper;

    struct AccrueInfo {
        uint256 lastAccrued;
        uint256 feesEarned;
        uint256 interestPerSecond;
    }

    AccrueInfo public accrueInfo;

    constructor(
        IERC20 collateral_,
        IOracle oracle_,
        IERC20 solid_,
        IERC20 solidex_,
        address lpDepositor_,
        uint256 maxCap_,
        uint256 interestPerSecond_,
        uint256 borrowOpeningFee,
        uint256 liquidationRatio,
        address mintHelper_
    ) public {
        collateral = collateral_;
        accrueInfo.interestPerSecond = interestPerSecond_;
        accrueInfo.lastAccrued = block.timestamp;
        BORROW_OPENING_FEE = borrowOpeningFee;
        LIQUIDATION_RATIO = liquidationRatio;
        oracle = oracle_;
        solid = solid_;
        solidex = solidex_;
        lpDepositor = lpDepositor_;
        maxCap = maxCap_;
        mintHelper = mintHelper_;
    }

    function setOracle(IOracle oracle_) external onlyOwner {
        oracle = oracle_;
    }

    function setMaxCap(uint256 maxCap_) external onlyOwner {
        maxCap = maxCap_;
    }

    function setBorrowOpeningFee(uint256 borrowOpeningFee_) external onlyOwner {
        BORROW_OPENING_FEE = borrowOpeningFee_;
    }

    function setLiquidationRatio(uint256 liquidationRatio_) external onlyOwner {
        LIQUIDATION_RATIO = liquidationRatio_;
    }

    function setMintHelper(address mintHelper_) external onlyOwner {
        mintHelper = mintHelper_;
    }

    function getRepayAmount(uint256 amount)
        public
        view
        returns (uint256 repayAmount)
    {
        Rebase memory _totalBorrow = totalBorrow;
        (uint128 elastic, ) = getCurrentElastic();
        _totalBorrow.elastic = elastic;
        (_totalBorrow, repayAmount) = _totalBorrow.sub(amount, true);
    }

    /// @notice returns user total debt (borrowed amount + interest)
    function getDebt(address user) public view returns (uint256 debt) {
        if (totalBorrow.base == 0) return 0;

        (uint128 elastic, ) = getCurrentElastic();
        return userBorrow[user].mul(uint256(elastic)) / totalBorrow.base;
    }

    /// @notice returns liquidation price for requested user
    function getLiquidationPrice(address user) public view returns (uint256) {
        uint256 userCollateralAmount = userCollateral[user];
        if (userCollateralAmount == 0) return 0;

        uint256 liquidationPrice = (getDebt(user).mul(1e18).mul(1e18)) /
            (userCollateralAmount.mul(LIQUIDATION_RATIO));
        return liquidationPrice;
    }

    /// @notice returns withdrawable amount for requested user
    function getWithdrawableCollateralAmount(address user)
        external
        view
        returns (uint256)
    {
        uint256 userCollateralAmount = userCollateral[user];
        if (userCollateralAmount == 0) return 0;

        uint256 neededCollateral = (getDebt(user).mul(1e18).mul(1e18)) /
            (oracle.getOnChainPrice().mul(LIQUIDATION_RATIO));

        return
            userCollateralAmount > neededCollateral
                ? userCollateralAmount - neededCollateral
                : 0;
    }

    function isSolvent(address user) external view returns (bool) {
        uint256 userCollateralAmount = userCollateral[user];
        if (userCollateralAmount == 0) return getDebt(user) == 0;

        return
            userCollateralAmount.mul(oracle.getOnChainPrice()).mul(
                LIQUIDATION_RATIO
            ) /
                (uint256(1e18).mul(1e18)) >
            getDebt(user);
    }

    function isSolvent(
        address user,
        uint256 price,
        uint256 timestamp,
        bytes calldata reqId,
        SchnorrSign[] calldata sigs
    ) internal returns (bool) {
        // accrue must have already been called!

        uint256 userCollateralAmount = userCollateral[user];
        if (userCollateralAmount == 0) return getDebt(user) == 0;

        return
            userCollateralAmount
                .mul(oracle.getPrice(price, timestamp, reqId, sigs))
                .mul(LIQUIDATION_RATIO) /
                (uint256(1e18).mul(1e18)) >
            getDebt(user);
    }

    function getCurrentElastic()
        internal
        view
        returns (uint128 elastic, uint128 interest)
    {
        Rebase memory _totalBorrow = totalBorrow;
        uint256 elapsedTime = block.timestamp - accrueInfo.lastAccrued;
        if (elapsedTime != 0 && _totalBorrow.base != 0) {
            interest = (uint256(_totalBorrow.elastic)
                .mul(accrueInfo.interestPerSecond)
                .mul(elapsedTime) / 1e18).to128();
            elastic = _totalBorrow.elastic.add(interest);
        } else {
            return (totalBorrow.elastic, 0);
        }
    }

    function accrue() public {
        uint256 elapsedTime = block.timestamp - accrueInfo.lastAccrued;
        if (elapsedTime == 0) return;
        if (totalBorrow.base == 0) {
            accrueInfo.lastAccrued = uint256(block.timestamp);
            return;
        }

        (uint128 elastic, uint128 interest) = getCurrentElastic();

        accrueInfo.lastAccrued = uint256(block.timestamp);
        totalBorrow.elastic = elastic;
        accrueInfo.feesEarned = accrueInfo.feesEarned.add(interest);

        emit UpdateAccrue(interest);
    }

    function addCollateral(address to, uint256 amount) public {
        userCollateral[to] = userCollateral[to].add(amount);
        totalCollateral = totalCollateral.add(amount);
        if (userHolder[to] == address(0)) {
            Holder holder = new Holder(lpDepositor, address(this), to);
            userHolder[to] = address(holder);
        }
        collateral.safeTransferFrom(msg.sender, userHolder[to], amount);
        emit AddCollateral(msg.sender, to, amount);
    }

    /// @param price collateral price (USD)
    /// @param timestamp sign timestamp
    function removeCollateral(
        address to,
        uint256 amount,
        uint256 price,
        uint256 timestamp,
        bytes calldata reqId,
        SchnorrSign[] calldata sigs
    ) public {
        accrue();
        userCollateral[msg.sender] = userCollateral[msg.sender].sub(amount);

        totalCollateral = totalCollateral.sub(amount);

        Holder(userHolder[msg.sender]).withdrawERC20(
            address(collateral),
            to,
            amount
        );

        require(
            isSolvent(msg.sender, price, timestamp, reqId, sigs),
            "User is not solvent!"
        );
        emit RemoveCollateral(msg.sender, to, amount);
    }

    function borrow(
        address to,
        uint256 amount,
        uint256 price,
        uint256 timestamp,
        bytes calldata reqId,
        SchnorrSign[] calldata sigs
    ) public returns (uint256 debt) {
        accrue();
        uint256 fee = amount.mul(BORROW_OPENING_FEE) / 1e18;
        (totalBorrow, debt) = totalBorrow.add(amount.add(fee), true);
        accrueInfo.feesEarned = accrueInfo.feesEarned.add(fee);
        userBorrow[msg.sender] = userBorrow[msg.sender].add(debt);

        require(
            totalBorrow.elastic <= maxCap,
            "Lender total borrow exceeds cap"
        );

        require(
            isSolvent(msg.sender, price, timestamp, reqId, sigs),
            "User is not solvent!"
        );

        IMintHelper(mintHelper).mint(to, amount);

        emit Borrow(msg.sender, to, amount.add(fee), debt);
    }

    function repayElastic(address to, uint256 debt)
        public
        returns (uint256 repayAmount)
    {
        accrue();

        uint256 amount = debt.mul(totalBorrow.base) / totalBorrow.elastic;

        (totalBorrow, repayAmount) = totalBorrow.sub(amount, true);
        userBorrow[to] = userBorrow[to].sub(amount);

        IMintHelper(mintHelper).burnFrom(msg.sender, repayAmount);

        emit Repay(msg.sender, to, amount, repayAmount);
    }

    function repayBase(address to, uint256 amount)
        public
        returns (uint256 repayAmount)
    {
        accrue();

        (totalBorrow, repayAmount) = totalBorrow.sub(amount, true);
        userBorrow[to] = userBorrow[to].sub(amount);

        IMintHelper(mintHelper).burnFrom(msg.sender, repayAmount);

        emit Repay(msg.sender, to, amount, repayAmount);
    }

    function liquidate(
        address[] calldata users,
        address to,
        uint256 price,
        uint256 timestamp,
        bytes calldata reqId,
        SchnorrSign[] calldata sigs
    ) public {
        accrue();

        uint256 totalCollateralAmount;
        uint256 totalDeiAmount;

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];

            if (!isSolvent(msg.sender, price, timestamp, reqId, sigs)) {
                uint256 amount = userBorrow[user];

                uint256 deiAmount;
                (totalBorrow, deiAmount) = totalBorrow.sub(amount, true);

                totalDeiAmount += deiAmount;
                totalCollateralAmount += userCollateral[user];

                emit RemoveCollateral(user, to, userCollateral[user]);
                emit Repay(msg.sender, user, amount, deiAmount);
                emit Liquidate(
                    msg.sender,
                    user,
                    userCollateral[user],
                    deiAmount
                );

                Holder(userHolder[user]).withdrawERC20(
                    address(collateral),
                    to,
                    userCollateral[user]
                );
                userCollateral[user] = 0;
                userBorrow[user] = 0;
            }
        }

        require(totalDeiAmount != 0, "All users are solvent");

        totalCollateral = totalCollateral.sub(totalCollateralAmount);

        IMintHelper(mintHelper).burnFrom(msg.sender, totalDeiAmount);
    }

    function withdrawFees(address to, uint256 amount) public onlyOwner {
        accrue();

        IMintHelper(mintHelper).mint(to, amount);
        accrueInfo.feesEarned = accrueInfo.feesEarned.sub(amount);
    }

    function claim(address[] calldata pools) public {
        Holder(userHolder[msg.sender]).claim(pools);
    }

    function claimAndWithdraw(address[] calldata pools, address to) public {
        Holder(userHolder[msg.sender]).claim(pools);
        Holder(userHolder[msg.sender]).withdrawERC20(
            address(solid),
            to,
            solid.balanceOf(userHolder[msg.sender])
        );
        Holder(userHolder[msg.sender]).withdrawERC20(
            address(solidex),
            to,
            solidex.balanceOf(userHolder[msg.sender])
        );
    }

    function emergencyHolderWithdraw(
        address holder,
        address token,
        address to,
        uint256 amount
    ) public onlyOwner {
        Holder(holder).withdrawERC20(token, to, amount);
    }

    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) public onlyOwner {
        HIERC20(token).transfer(to, amount);
    }
}

// SPDX-License-Identifier: GPL3.0-or-later

interface IMintHelper {
    function dei() external view returns (address);

    function useVirtualReserve(address pool) external view returns (bool);

    function virtualReserve() external view returns (uint256);

    function MINTER_ROLE() external view returns (bytes32);

    function mint(address recv, uint256 amount) external;

    function burnFrom(address from, uint256 amount) external;

    function collatDollarBalance(uint256 collat_usd_price)
        external
        view
        returns (uint256);

    function setVirtualReserve(uint256 virtualReserve_) external;

    function setUseVirtualReserve(address pool, bool state) external;
}

// SPDX-License-Identifier: GPL-3.0

pragma experimental ABIEncoderV2;

struct SchnorrSign {
    uint256 signature;
    address owner;
    address nonce;
}

interface IMuonV02 {
    function verify(
        bytes calldata reqId,
        uint256 hash,
        SchnorrSign[] calldata _sigs
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
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

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

// Audit on 5-Jan-2021 by Keno and BoringCrypto
// Source: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol + Claimable.sol
// Edited by BoringCrypto

contract BoringOwnableData {
    address public owner;
    address public pendingOwner;
}

contract BoringOwnable is BoringOwnableData {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice `owner` defaults to msg.sender on construction.
    constructor() public {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /// @notice Transfers ownership to `newOwner`. Either directly or claimable by the new pending owner.
    /// Can only be invoked by the current `owner`.
    /// @param newOwner Address of the new owner.
    /// @param direct True if `newOwner` should be set immediately. False if `newOwner` needs to use `claimOwnership`.
    /// @param renounce Allows the `newOwner` to be `address(0)` if `direct` and `renounce` is True. Has no effect otherwise.
    function transferOwnership(
        address newOwner,
        bool direct,
        bool renounce
    ) public onlyOwner {
        if (direct) {
            // Checks
            require(newOwner != address(0) || renounce, "Ownable: zero address");

            // Effects
            emit OwnershipTransferred(owner, newOwner);
            owner = newOwner;
            pendingOwner = address(0);
        } else {
            // Effects
            pendingOwner = newOwner;
        }
    }

    /// @notice Needs to be called by `pendingOwner` to claim ownership.
    function claimOwnership() public {
        address _pendingOwner = pendingOwner;

        // Checks
        require(msg.sender == _pendingOwner, "Ownable: caller != pending owner");

        // Effects
        emit OwnershipTransferred(owner, _pendingOwner);
        owner = _pendingOwner;
        pendingOwner = address(0);
    }

    /// @notice Only allows the `owner` to execute the function.
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
import "./interfaces/IERC20.sol";
import "./Domain.sol";

// solhint-disable no-inline-assembly
// solhint-disable not-rely-on-time

// Data part taken out for building of contracts that receive delegate calls
contract ERC20Data {
    /// @notice owner > balance mapping.
    mapping(address => uint256) public balanceOf;
    /// @notice owner > spender > allowance mapping.
    mapping(address => mapping(address => uint256)) public allowance;
    /// @notice owner > nonce mapping. Used in `permit`.
    mapping(address => uint256) public nonces;
}

abstract contract ERC20 is IERC20, Domain {
    /// @notice owner > balance mapping.
    mapping(address => uint256) public override balanceOf;
    /// @notice owner > spender > allowance mapping.
    mapping(address => mapping(address => uint256)) public override allowance;
    /// @notice owner > nonce mapping. Used in `permit`.
    mapping(address => uint256) public nonces;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    /// @notice Transfers `amount` tokens from `msg.sender` to `to`.
    /// @param to The address to move the tokens.
    /// @param amount of the tokens to move.
    /// @return (bool) Returns True if succeeded.
    function transfer(address to, uint256 amount) public returns (bool) {
        // If `amount` is 0, or `msg.sender` is `to` nothing happens
        if (amount != 0 || msg.sender == to) {
            uint256 srcBalance = balanceOf[msg.sender];
            require(srcBalance >= amount, "ERC20: balance too low");
            if (msg.sender != to) {
                require(to != address(0), "ERC20: no zero address"); // Moved down so low balance calls safe some gas

                balanceOf[msg.sender] = srcBalance - amount; // Underflow is checked
                balanceOf[to] += amount;
            }
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Transfers `amount` tokens from `from` to `to`. Caller needs approval for `from`.
    /// @param from Address to draw tokens from.
    /// @param to The address to move the tokens.
    /// @param amount The token amount to move.
    /// @return (bool) Returns True if succeeded.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        // If `amount` is 0, or `from` is `to` nothing happens
        if (amount != 0) {
            uint256 srcBalance = balanceOf[from];
            require(srcBalance >= amount, "ERC20: balance too low");

            if (from != to) {
                uint256 spenderAllowance = allowance[from][msg.sender];
                // If allowance is infinite, don't decrease it to save on gas (breaks with EIP-20).
                if (spenderAllowance != type(uint256).max) {
                    require(spenderAllowance >= amount, "ERC20: allowance too low");
                    allowance[from][msg.sender] = spenderAllowance - amount; // Underflow is checked
                }
                require(to != address(0), "ERC20: no zero address"); // Moved down so other failed calls safe some gas

                balanceOf[from] = srcBalance - amount; // Underflow is checked
                balanceOf[to] += amount;
            }
        }
        emit Transfer(from, to, amount);
        return true;
    }

    /// @notice Approves `amount` from sender to be spend by `spender`.
    /// @param spender Address of the party that can draw from msg.sender's account.
    /// @param amount The maximum collective amount that `spender` can draw.
    /// @return (bool) Returns True if approved.
    function approve(address spender, uint256 amount) public override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparator();
    }

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 private constant PERMIT_SIGNATURE_HASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    /// @notice Approves `value` from `owner_` to be spend by `spender`.
    /// @param owner_ Address of the owner.
    /// @param spender The address of the spender that gets approved to draw from `owner_`.
    /// @param value The maximum collective amount that `spender` can draw.
    /// @param deadline This permit must be redeemed before this deadline (UTC timestamp in seconds).
    function permit(
        address owner_,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(owner_ != address(0), "ERC20: Owner cannot be 0");
        require(block.timestamp < deadline, "ERC20: Expired");
        require(
            ecrecover(_getDigest(keccak256(abi.encode(PERMIT_SIGNATURE_HASH, owner_, spender, value, nonces[owner_]++, deadline))), v, r, s) ==
                owner_,
            "ERC20: Invalid Signature"
        );
        allowance[owner_][spender] = value;
        emit Approval(owner_, spender, value);
    }
}

contract ERC20WithSupply is IERC20, ERC20 {
    uint256 public override totalSupply;

    function _mint(address user, uint256 amount) private {
        uint256 newTotalSupply = totalSupply + amount;
        require(newTotalSupply >= totalSupply, "Mint overflow");
        totalSupply = newTotalSupply;
        balanceOf[user] += amount;
    }

    function _burn(address user, uint256 amount) private {
        require(balanceOf[user] >= amount, "Burn too much");
        totalSupply -= amount;
        balanceOf[user] -= amount;
    }
}

// SPDX-License-Identifier: MIT
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

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IMasterContract {
    /// @notice Init function that gets called from `BoringFactory.deploy`.
    /// Also kown as the constructor for cloned contracts.
    /// Any ETH send to `BoringFactory.deploy` ends up here.
    /// @param data Can be abi encoded arguments or anything else.
    function init(bytes calldata data) external payable;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
import "./BoringMath.sol";

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

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
import "../interfaces/IERC20.sol";

// solhint-disable avoid-low-level-calls

library BoringERC20 {
    bytes4 private constant SIG_SYMBOL = 0x95d89b41; // symbol()
    bytes4 private constant SIG_NAME = 0x06fdde03; // name()
    bytes4 private constant SIG_DECIMALS = 0x313ce567; // decimals()
    bytes4 private constant SIG_TRANSFER = 0xa9059cbb; // transfer(address,uint256)
    bytes4 private constant SIG_TRANSFER_FROM = 0x23b872dd; // transferFrom(address,address,uint256)

    function returnDataToString(bytes memory data) internal pure returns (string memory) {
        if (data.length >= 64) {
            return abi.decode(data, (string));
        } else if (data.length == 32) {
            uint8 i = 0;
            while(i < 32 && data[i] != 0) {
                i++;
            }
            bytes memory bytesArray = new bytes(i);
            for (i = 0; i < 32 && data[i] != 0; i++) {
                bytesArray[i] = data[i];
            }
            return string(bytesArray);
        } else {
            return "???";
        }
    }

    /// @notice Provides a safe ERC20.symbol version which returns '???' as fallback string.
    /// @param token The address of the ERC-20 token contract.
    /// @return (string) Token symbol.
    function safeSymbol(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_SYMBOL));
        return success ? returnDataToString(data) : "???";
    }

    /// @notice Provides a safe ERC20.name version which returns '???' as fallback string.
    /// @param token The address of the ERC-20 token contract.
    /// @return (string) Token name.
    function safeName(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_NAME));
        return success ? returnDataToString(data) : "???";
    }

    /// @notice Provides a safe ERC20.decimals version which returns '18' as fallback value.
    /// @param token The address of the ERC-20 token contract.
    /// @return (uint8) Token decimals.
    function safeDecimals(IERC20 token) internal view returns (uint8) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_DECIMALS));
        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }

    /// @notice Provides a safe ERC20.transfer version for different ERC-20 implementations.
    /// Reverts on a failed transfer.
    /// @param token The address of the ERC-20 token.
    /// @param to Transfer tokens to.
    /// @param amount The token amount.
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(SIG_TRANSFER, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BoringERC20: Transfer failed");
    }

    /// @notice Provides a safe ERC20.transferFrom version for different ERC-20 implementations.
    /// Reverts on a failed transfer.
    /// @param token The address of the ERC-20 token.
    /// @param from Transfer tokens from.
    /// @param to Transfer tokens to.
    /// @param amount The token amount.
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(SIG_TRANSFER_FROM, from, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BoringERC20: TransferFrom failed");
    }
}

// Be name Khoda
// Bime Abolfazl
// SPDX-License-Identifier: MIT

// =================================================================================================================
//  _|_|_|    _|_|_|_|  _|    _|    _|_|_|      _|_|_|_|  _|                                                       |
//  _|    _|  _|        _|    _|  _|            _|            _|_|_|      _|_|_|  _|_|_|      _|_|_|    _|_|       |
//  _|    _|  _|_|_|    _|    _|    _|_|        _|_|_|    _|  _|    _|  _|    _|  _|    _|  _|        _|_|_|_|     |
//  _|    _|  _|        _|    _|        _|      _|        _|  _|    _|  _|    _|  _|    _|  _|        _|           |
//  _|_|_|    _|_|_|_|    _|_|    _|_|_|        _|        _|  _|    _|    _|_|_|  _|    _|    _|_|_|    _|_|_|     |
// =================================================================================================================
// ==================== Holder ===================
// ==============================================
// DEUS Finance: https://github.com/deusfinance

// Primary Author(s)
// Mmd: https://github.com/mmd-mostafaee

pragma solidity 0.6.12;

interface LpDepositor {
    function getReward(address[] calldata pools) external;
}

interface HIERC20 {
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);
}

contract SolidexHolder {
    LpDepositor public lpDepositor;
    address public lender;
    address public user;

    constructor(
        address lpDepositor_,
        address lender_,
        address user_
    ) public {
        lpDepositor = LpDepositor(lpDepositor_);
        lender = lender_;
        user = user_;
    }

    function claim(address[] calldata pools) public {
        lpDepositor.getReward(pools);
    }

    function withdrawERC20(
        address token,
        address to,
        uint256 amount
    ) public returns (bool) {
        require(msg.sender == lender, "SolidexHolder: You are not lender");
        HIERC20(token).transfer(to, amount);
        return true;
    }
}

//Dar panah khoda

// SPDX-License-Identifier: MIT
// Based on code and smartness by Ross Campbell and Keno
// Uses immutable to store the domain separator to reduce gas usage
// If the chain id changes due to a fork, the forked chain will calculate on the fly.
pragma solidity 0.6.12;

// solhint-disable no-inline-assembly

contract Domain {
    bytes32 private constant DOMAIN_SEPARATOR_SIGNATURE_HASH = keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");
    // See https://eips.ethereum.org/EIPS/eip-191
    string private constant EIP191_PREFIX_FOR_EIP712_STRUCTURED_DATA = "\x19\x01";

    // solhint-disable var-name-mixedcase
    bytes32 private immutable _DOMAIN_SEPARATOR;
    uint256 private immutable DOMAIN_SEPARATOR_CHAIN_ID;    

    /// @dev Calculate the DOMAIN_SEPARATOR
    function _calculateDomainSeparator(uint256 chainId) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                DOMAIN_SEPARATOR_SIGNATURE_HASH,
                chainId,
                address(this)
            )
        );
    }

    constructor() public {
        uint256 chainId; assembly {chainId := chainid()}
        _DOMAIN_SEPARATOR = _calculateDomainSeparator(DOMAIN_SEPARATOR_CHAIN_ID = chainId);
    }

    /// @dev Return the DOMAIN_SEPARATOR
    // It's named internal to allow making it public from the contract that uses it by creating a simple view function
    // with the desired public name, such as DOMAIN_SEPARATOR or domainSeparator.
    // solhint-disable-next-line func-name-mixedcase
    function _domainSeparator() internal view returns (bytes32) {
        uint256 chainId; assembly {chainId := chainid()}
        return chainId == DOMAIN_SEPARATOR_CHAIN_ID ? _DOMAIN_SEPARATOR : _calculateDomainSeparator(chainId);
    }

    function _getDigest(bytes32 dataHash) internal view returns (bytes32 digest) {
        digest =
            keccak256(
                abi.encodePacked(
                    EIP191_PREFIX_FOR_EIP712_STRUCTURED_DATA,
                    _domainSeparator(),
                    dataHash
                )
            );
    }
}