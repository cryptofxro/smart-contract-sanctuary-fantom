// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {Operator} from "./owner/Operator.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {IModernMasonry} from "./interfaces/IModernMasonry.sol";

/// @title Treasury which utilizes two ratios as a distribution deciding condition
/// @notice Whenever prices of two configured token are over the specified ratios, the reward tokens are distributed
contract ModernTreasury is ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;

    /// Recoverer role
    bytes32 public constant RECOVERER_ROLE = keccak256("RECOVERER_ROLE");

    /// Oracle admin role
    bytes32 public constant ORACLE_ADMIN_ROLE = keccak256("ORACLE_ADMIN_ROLE");

    /// Pauser role
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// DAO fund admin role
    bytes32 public constant DAO_FUND_ADMIN_ROLE = keccak256("DAO_FUND_ADMIN_ROLE");

    /// DEV fund admin role
    bytes32 public constant DEV_FUND_ADMIN_ROLE = keccak256("DEV_FUND_ADMIN_ROLE");

    /// Reward admin role
    bytes32 public constant REWARD_ADMIN_ROLE = keccak256("REWARD_ADMIN_ROLE");

    /// Length of an epoch
    uint256 public epochLength;

    /// When does the treasury start
    uint256 public firstEpochStartTime;
    /// Current epoch counter
    uint256 public currentEpoch;

    /// Ratio for the first token pair which needs to be met to distribute rewards
    uint256 public expectedRatioOne;
    /// Ratio for the second token pair which needs to be met to distribute rewards
    uint256 public expectedRatioTwo;

    /// Price of the main token in the first pair at the end of the previous epoch
    uint256 public previousEpochRatioOne;
    /// Price of the main token in the second pair at the end of the previous epoch
    uint256 public previousEpochRatioTwo;

    /// Amount of reward tokens distributed pair epoch if ratios are met
    uint256 public tokensPerEpoch;

    /// Percentage of rewards which are transferred to DAO fund
    uint256 public daoFundSharedPercent;
    /// Percentage of rewards which are transferred to DEV fund
    uint256 public devFundSharedPercent;

    /// Is printing rewards paused, regardless of ratios
    bool public rewardsPaused;

    /// Main token in the first pair
    address public ratioOneToken;
    /// Main token in the second pair
    address public ratioTwoToken;

    /// Address of DAO fund
    address public daoFund;
    /// Address of DEV fund
    address public devFund;

    /// Address of Masonry
    address public masonry;

    /// Token distributed as reward
    IERC20 public rewardToken;
    /// Oracle for the first pair, used to fetch average price
    IOracle public ratioOneOracle;
    /// Oracle for the second pair, used to fetch average price
    IOracle public ratioTwoOracle;

    /* EVENTS */

    event DaoFundFunded(address indexed triggeredBy, address daoFundAddress, uint256 amount);
    event DevFundFunded(address indexed triggeredBy, address devFundAddress, uint256 amount);
    event MasonryFunded(address indexed triggeredBy, uint256 rewardsAmount);
    event CalledAllocateRewards(address indexed triggeredBy, uint256 ratioOneTokenPrice, uint256 ratioTwoTokenPrice);
    event RecoveredUnsupported(address indexed triggeredBy, address token, uint256 amount);
    event TokensPerEpochUpdated(address indexed triggeredBy, uint256 oldTokensPerEpoch, uint256 newTokensPerEpoch);
    event ExpectedRatioOneUpdated(address indexed triggeredBy, uint256 oldRatioOne, uint256 newRatioOne);
    event ExpectedRatioTwoUpdated(address indexed triggeredBy, uint256 oldRatioTwo, uint256 newRatioTwo);
    event RewardsPaused(address indexed triggeredBy);
    event RewardsUnpaused(address indexed triggeredBy);
    event DaoFundUpdated(address indexed triggeredBy, address oldDaoFund, address newDaoFund);
    event DevFundUpdated(address indexed triggeredBy, address oldDevFund, address newDevFund);
    event DaoFundSharedPercentUpdated(
        address indexed triggeredBy,
        uint256 oldDaoFundSharedPercent,
        uint256 newDaoFundSharedPercent
    );
    event DevFundSharedPercentUpdated(
        address indexed triggeredBy,
        uint256 oldDevFundSharedPercent,
        uint256 newDevFundSharedPercent
    );
    event RatioOneOracleUpdated(address indexed triggeredBy, address oldRatioOneOracle, address newRatioOneOracle);
    event RatioTwoOracleUpdated(address indexed triggeredBy, address oldRatioTwoOracle, address newRatioTwoOracle);
    event MasonryUpdated(address indexed triggeredBy, address oldMasonry, address newMasonry);

    /// Verifies whether epoch is ready to be advanced
    modifier checkEpoch() {
        require(block.timestamp >= nextEpochPoint(), "Epoch not ready yet");

        _;

        currentEpoch = currentEpoch + 1;
    }

    /// Verifies whether the treasury is started
    modifier checkIfStarted() {
        require(block.timestamp >= firstEpochStartTime, "Treasury not started yet");

        _;
    }

    /// Default constructor of ModernTreasury
    /// @dev verrifies whether the chosen firstEpochStartTime is in the future, and whether the provided addresses are not 0
    /// @param _epochLength Length of an epoch in seconds
    /// @param _firstEpochStartTime Start time of the treasury epochs
    /// @param _expectedRatioOne Expected ratio for the main token in first pair, that needs to be met to emit rewards
    /// @param _expectedRatioTwo Expected ratio for the main token in second pair, that needs to be met to emit rewards
    /// @param _rewardToken Token distributed as reward
    /// @param _ratioOneOracle Oracle contract for the first token ratio
    /// @param _ratioOneToken Token to be used as the main one in calculating the first ratio
    /// @param _ratioTwoOracle Oracle contract for the second token ratio
    /// @param _ratioTwoToken Token to be used as the main one in calculating the second ratio
    constructor(
        uint256 _epochLength,
        uint256 _firstEpochStartTime,
        uint256 _expectedRatioOne,
        uint256 _expectedRatioTwo,
        address _rewardToken,
        address _ratioOneOracle,
        address _ratioOneToken,
        address _ratioTwoOracle,
        address _ratioTwoToken
    ) {
        require(_epochLength > 1 hours, "Epoch cannot be shorter than 1 hour");
        require(_firstEpochStartTime > block.timestamp, "Start time needs to be in future");
        require(_expectedRatioOne > 0, "Expected ratio one cannot be 0");
        require(_expectedRatioTwo > 0, "Expected ratio two cannot be 0");
        require(_rewardToken != address(0), "Reward token cannot be address 0");
        require(_ratioOneOracle != address(0), "Ratio one oracle cannot be address 0");
        require(_ratioOneToken != address(0), "Ratio one token cannot be address 0");
        require(_ratioTwoOracle != address(0), "Ratio two oracle cannot be address 0");
        require(_ratioTwoToken != address(0), "Ratio two token cannot be address 0");

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        epochLength = _epochLength;

        firstEpochStartTime = _firstEpochStartTime;

        expectedRatioOne = _expectedRatioOne;
        expectedRatioTwo = _expectedRatioTwo;

        rewardToken = IERC20(_rewardToken);

        ratioOneOracle = IOracle(_ratioOneOracle);
        ratioOneToken = _ratioOneToken;

        ratioTwoOracle = IOracle(_ratioTwoOracle);
        ratioTwoToken = _ratioTwoToken;
    }

    /// Returns the next epoch timestamp
    function nextEpochPoint() public view returns (uint256) {
        return firstEpochStartTime + (currentEpoch * epochLength);
    }

    /// Updates oracle for the first token price ratio
    function _updateRatioOneOracle() internal {
        try ratioOneOracle.update() {} catch {}
    }

    /// Updates oracle for the second token price ratio
    function _updateRatioTwoOracle() internal {
        try ratioTwoOracle.update() {} catch {}
    }

    /// Returns an average tick price of the main token calculated by the oracle for the first token ratio
    function getRatioOneMainTokenRatio() public view returns (uint256) {
        try ratioOneOracle.consult(ratioOneToken, 1e18) returns (uint144 price) {
            return uint256(price);
        } catch {
            revert("Treasury: failed to consult ratio one token ratio from the oracle");
        }
    }

    /// Returns an average tick price of the main token calculated by the oracle for the second token ratio
    function getRatioTwoMainTokenRatio() public view returns (uint256) {
        try ratioTwoOracle.consult(ratioTwoToken, 1e18) returns (uint144 price) {
            return uint256(price);
        } catch {
            revert("Treasury: failed to consult ratio two token ratio from the oracle");
        }
    }

    /// Returns a TWAP (Time Weighted Average Price) of the main token calculated since the last oracle update until now, for the first token ratio
    function getRatioOneMainTokenTwap() external view returns (uint256) {
        try ratioOneOracle.twap(ratioOneToken, 1e18) returns (uint144 price) {
            return uint256(price);
        } catch {
            revert("Treasury: failed to consult ratio one token twap from the oracle");
        }
    }

    /// Returns a TWAP (Time Weighted Average Price) of the main token calculated since the last oracle update until now, for the first token ratio
    function getRatioTwoMainTokenTwap() external view returns (uint256) {
        try ratioTwoOracle.twap(ratioTwoToken, 1e18) returns (uint144 price) {
            return uint256(price);
        } catch {
            revert("Treasury: failed to consult ratio two token twap from the oracle");
        }
    }

    /// Whenever both token price ratios are met, allocates rewards to the masonry
    /// @dev Uses configured oracles to fetch the token prices averaged over an epoch. Additionally allocates a configured percentage of rewards to the DAO fund and DEV fund.
    function allocateRewards() external nonReentrant checkIfStarted checkEpoch {
        require(masonry != address(0), "Masonry address cannot be 0");
        _updateRatioOneOracle();
        _updateRatioTwoOracle();

        previousEpochRatioOne = getRatioOneMainTokenRatio();
        previousEpochRatioTwo = getRatioTwoMainTokenRatio();

        if (!rewardsPaused && tokensPerEpoch > 0) {
            if (previousEpochRatioOne > expectedRatioOne && previousEpochRatioTwo > expectedRatioTwo) {
                require(
                    rewardToken.balanceOf(address(this)) >= tokensPerEpoch,
                    "Not enough reward tokens in the contract"
                );

                uint256 _daoFundSharedAmount = 0;
                if (daoFundSharedPercent > 0) {
                    _daoFundSharedAmount = (tokensPerEpoch * daoFundSharedPercent) / 10000;
                    rewardToken.safeTransfer(daoFund, _daoFundSharedAmount);
                    emit DaoFundFunded(msg.sender, daoFund, _daoFundSharedAmount);
                }

                uint256 _devFundSharedAmount = 0;
                if (devFundSharedPercent > 0) {
                    _devFundSharedAmount = (tokensPerEpoch * devFundSharedPercent) / 10000;
                    rewardToken.safeTransfer(devFund, _devFundSharedAmount);
                    emit DevFundFunded(msg.sender, devFund, _devFundSharedAmount);
                }

                uint256 rewardsAmount = tokensPerEpoch - (_daoFundSharedAmount + _devFundSharedAmount);
                rewardToken.safeApprove(masonry, 0);
                rewardToken.safeApprove(masonry, rewardsAmount);

                IModernMasonry(masonry).allocateRewards(rewardsAmount);
                emit MasonryFunded(msg.sender, rewardsAmount);
            }
        }

        emit CalledAllocateRewards(msg.sender, previousEpochRatioOne, previousEpochRatioTwo);
    }

    /// Recovers tokens that are not planned to be used in the contract
    /// @dev Sends tokens to the operator
    function recoverUnsupportedTokens(IERC20 _token) external onlyRole(RECOVERER_ROLE) {
        require(address(_token) != address(rewardToken), "Cannot recover rewardToken");
        uint256 amountToRecover = _token.balanceOf(address(this));
        _token.safeTransfer(msg.sender, amountToRecover);
        emit RecoveredUnsupported(msg.sender, address(_token), amountToRecover);
    }

    /// Set tokensPerEpoch - the amount of reward tokens emitted each epoch when both ratios are met
    /// @param _newTokensPerEpoch New value of tokens per epoch
    function setTokensPerEpoch(uint256 _newTokensPerEpoch) external onlyRole(REWARD_ADMIN_ROLE) {
        uint256 oldTokensPerEpoch = tokensPerEpoch;
        tokensPerEpoch = _newTokensPerEpoch;
        emit TokensPerEpochUpdated(msg.sender, oldTokensPerEpoch, _newTokensPerEpoch);
    }

    /// Set price ratio for the main token in the first token pair, which needs to be met to emit rewards
    /// @param _newExpectedRatioOne New value for the price ratio in the first token pair
    function setExpectedRatioOne(uint256 _newExpectedRatioOne) external onlyRole(ORACLE_ADMIN_ROLE) {
        uint256 oldExpectedRatioOne = expectedRatioOne;
        expectedRatioOne = _newExpectedRatioOne;
        emit ExpectedRatioOneUpdated(msg.sender, oldExpectedRatioOne, _newExpectedRatioOne);
    }

    /// Set price ratio for the main token in the second token pair, which needs to be met to emit rewards
    /// @param _newExpectedRatioTwo New value for the price ratio in the second token pair
    function setExpectedRatioTwo(uint256 _newExpectedRatioTwo) external onlyRole(ORACLE_ADMIN_ROLE) {
        uint256 oldExpectedRatioTwo = expectedRatioTwo;
        expectedRatioTwo = _newExpectedRatioTwo;
        emit ExpectedRatioTwoUpdated(msg.sender, oldExpectedRatioTwo, _newExpectedRatioTwo);
    }

    /// Pauses rewards from being emitted independent of the ratios
    function pauseRewards() external onlyRole(PAUSER_ROLE) {
        require(!rewardsPaused, "Rewards already paused");
        rewardsPaused = true;
        emit RewardsPaused(msg.sender);
    }

    /// Resumes rewards emissions
    function unpauseRewards() external onlyRole(PAUSER_ROLE) {
        require(rewardsPaused, "Rewards already unpaused");
        rewardsPaused = false;
        emit RewardsUnpaused(msg.sender);
    }

    /// Set new DAO fund address
    /// @param _newDaoFund New DAO fund address
    function setDaoFund(address _newDaoFund) external onlyRole(DAO_FUND_ADMIN_ROLE) {
        require(_newDaoFund != address(0), "Dao Fund cannot be 0 address");
        address oldDaoFund = daoFund;
        daoFund = _newDaoFund;
        emit DaoFundUpdated(msg.sender, oldDaoFund, _newDaoFund);
    }

    /// Set new DEV fund address
    /// @param _newDevFund New DEV fund address
    function setDevFund(address _newDevFund) external onlyRole(DEV_FUND_ADMIN_ROLE) {
        require(_newDevFund != address(0), "Dev Fund cannot be 0 address");
        address oldDevFund = devFund;
        devFund = _newDevFund;
        emit DevFundUpdated(msg.sender, oldDevFund, _newDevFund);
    }

    /// Set percentage of rewards which will be send to DAO fund
    /// @param _newDaoFundSharedPercent New percentage of rewards sent to DAO fund whenever rewards are emitted (1% == 100)
    function setDaoFundSharedPercent(uint256 _newDaoFundSharedPercent) external onlyRole(DAO_FUND_ADMIN_ROLE) {
        require(_newDaoFundSharedPercent < 3000, "Dao fund share cannot be higher than 30%");
        uint256 oldDaoFundSharedPercent = daoFundSharedPercent;
        daoFundSharedPercent = _newDaoFundSharedPercent;
        emit DaoFundSharedPercentUpdated(msg.sender, oldDaoFundSharedPercent, _newDaoFundSharedPercent);
    }

    /// Set percentage of rewards which will be send to DEV fund
    /// @param _newDevFundSharedPercent New percentage of rewards sent to DEV fund whenever rewards are emitted (1% == 100)
    function setDevFundSharedPercent(uint256 _newDevFundSharedPercent) external onlyRole(DEV_FUND_ADMIN_ROLE) {
        require(_newDevFundSharedPercent < 3000, "Dev fund share cannot be higher than 30%");
        uint256 oldDevFundSharedPercent = devFundSharedPercent;
        devFundSharedPercent = _newDevFundSharedPercent;
        emit DevFundSharedPercentUpdated(msg.sender, oldDevFundSharedPercent, _newDevFundSharedPercent);
    }

    /// Set address of oracle used for calculating ratio for the first pair
    /// @param _newRatioOneOracle New address of oracle for the first pair
    function setRatioOneOracle(address _newRatioOneOracle) external onlyRole(ORACLE_ADMIN_ROLE) {
        require(_newRatioOneOracle != address(0), "Ratio One oracle cannot be 0 address");
        address oldRatioOneOracle = address(ratioOneOracle);
        ratioOneOracle = IOracle(_newRatioOneOracle);
        emit RatioOneOracleUpdated(msg.sender, oldRatioOneOracle, _newRatioOneOracle);
    }

    /// Set address of oracle used for calculating ratio for the second pair
    /// @param _newRatioTwoOracle New address of oracle for the second pair
    function setRatioTwoOracle(address _newRatioTwoOracle) external onlyRole(ORACLE_ADMIN_ROLE) {
        require(_newRatioTwoOracle != address(0), "Ratio Two oracle cannot be 0 address");
        address oldRatioTwoOracle = address(ratioTwoOracle);
        ratioTwoOracle = IOracle(_newRatioTwoOracle);
        emit RatioTwoOracleUpdated(msg.sender, oldRatioTwoOracle, _newRatioTwoOracle);
    }

    /// Set address of masonry
    /// @param _newMasonry New address of masonry
    function setMasonry(address _newMasonry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newMasonry != address(0), "Masonry address cannot be 0");
        address oldMasonry = masonry;
        masonry = _newMasonry;
        emit MasonryUpdated(msg.sender, oldMasonry, _newMasonry);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IOracle {
    function update() external;

    function consult(address _token, uint256 _amountIn) external view returns (uint144 amountOut);

    function twap(address _token, uint256 _amountIn) external view returns (uint144 _amountOut);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IModernMasonry {
    function allocateRewards(uint256 _amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// Additional access control mechanism on top of {Ownable}.
/// @dev Introduces a new - Operator role, in addition to already existing Owner role.
abstract contract Operator is Context, Ownable {
    /// Address of the Operator
    address private _operator;

    /* EVENTS */
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);

    /// Default constructor.
    constructor() {
        _operator = _msgSender();
        emit OperatorTransferred(address(0), _operator);
    }

    /// Returns the current Operator address.
    function operator() public view returns (address) {
        return _operator;
    }

    /// Access control modifier, which only allows Operator to call the annotated function.
    modifier onlyOperator() {
        require(_operator == msg.sender, "operator: caller is not the operator");
        _;
    }

    /// Access control modifier, which only allows Operator or Owner to call the annotated function.
    modifier onlyOwnerOrOperator() {
        require(
            (owner() == msg.sender) || (_operator == msg.sender),
            "operator: caller is not the owner or the operator"
        );
        _;
    }

    /// Checks if caller is an Operator.
    function isOperator() public view returns (bool) {
        return _msgSender() == _operator;
    }

    /// Checks if called is an Owner or an Operator.
    function isOwnerOrOperator() public view returns (bool) {
        return (_msgSender() == _operator) || (_msgSender() == owner());
    }

    /// Transfers Operator role to a new address.
    /// @param newOperator_ Address to which the Operator role should be transferred.
    function transferOperator(address newOperator_) public onlyOwnerOrOperator {
        _transferOperator(newOperator_);
    }

    /// Transfers Operator role to a new address.
    /// @param newOperator_ Address to which the Operator role should be transferred.
    function _transferOperator(address newOperator_) internal {
        require(newOperator_ != address(0), "operator: zero address given for new operator");
        emit OperatorTransferred(address(0), newOperator_);
        _operator = newOperator_;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/draft-IERC20Permit.sol";
import "../../../utils/Address.sol";

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
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
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
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
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

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControl.sol";
import "../utils/Context.sol";
import "../utils/Strings.sol";
import "../utils/introspection/ERC165.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
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
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

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
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
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
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
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
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
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
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
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

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                /// @solidity memory-safe-assembly
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}