// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "./EIP20Interface.sol";
import "./Exponential.sol";
import "./SafeMath.sol";

library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call.value(value)(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

interface ITToken {
    function balanceOf(address owner) external view returns (uint256);

    function borrowIndex() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function totalBorrows() external view returns (uint256);

    function borrowBalanceStored(address account) external view returns (uint256);
}

interface ITombtroller {
    function isMarketListed(address tTokenAddress) external view returns (bool);

    function getAllMarkets() external view returns (ITToken[] memory);

    function rewardDistributor() external view returns (address);
}

contract RewardDistributorStorageV2 {
    /// @notice Administrator for this contract
    address public admin;

    /// @notice Active brains of Unitroller
    ITombtroller public tombtroller;

    struct RewardMarketState {
        /// @notice The market's last updated tombBorrowIndex or tombSupplyIndex
        uint208 index;
        /// @notice The timestamp number the index was last updated at
        uint48 timestamp;
    }

    /// @notice The portion of supply reward rate that each market currently receives
    mapping(uint8 => mapping(address => uint256)) public rewardSupplySpeeds;

    /// @notice The portion of borrow reward rate that each market currently receives
    mapping(uint8 => mapping(address => uint256)) public rewardBorrowSpeeds;

    /// @notice The stlLIF3 market supply state for each market
    mapping(uint8 => mapping(address => RewardMarketState)) public rewardSupplyState;

    /// @notice The stlLIF3 market borrow state for each market
    mapping(uint8 => mapping(address => RewardMarketState)) public rewardBorrowState;

    /// @notice The stlLIF3 borrow index for each market for each supplier as of the last time they accrued reward
    mapping(uint8 => mapping(address => mapping(address => uint256))) public rewardSupplierIndex;

    /// @notice The stlLIF3 borrow index for each market for each borrower as of the last time they accrued reward
    mapping(uint8 => mapping(address => mapping(address => uint256))) public rewardBorrowerIndex;

    /// @notice The stlLIF3 accrued but not yet transferred to each user
    mapping(uint8 => mapping(address => uint256)) public rewardAccrued;

    /// @notice stlLIF3 token contract address
    EIP20Interface public tomb;

    /// @notice If initializeRewardAccrued is locked
    bool public isInitializeRewardAccruedLocked;
}

contract RewardDistributorV2 is RewardDistributorStorageV2, Exponential {
    using SafeMath for uint256;

    /// @notice Emitted when a new reward supply speed is calculated for a market
    event RewardSupplySpeedUpdated(uint8 rewardType, ITToken indexed tToken, uint256 newSpeed);

    /// @notice Emitted when a new reward borrow speed is calculated for a market
    event RewardBorrowSpeedUpdated(uint8 rewardType, ITToken indexed tToken, uint256 newSpeed);

    /// @notice Emitted when stlLIF3 is distributed to a supplier
    event DistributedSupplierReward(
        uint8 rewardType,
        ITToken indexed tToken,
        address indexed supplier,
        uint256 rewardDelta,
        uint256 rewardSupplyIndex
    );

    /// @notice Emitted when stlLIF3 is distributed to a borrower
    event DistributedBorrowerReward(
        uint8 rewardType,
        ITToken indexed tToken,
        address indexed borrower,
        uint256 rewardDelta,
        uint256 rewardBorrowIndex
    );

    /// @notice Emitted when stlLIF3 is granted by admin
    event RewardGranted(uint8 rewardType, address recipient, uint256 amount);

    /// @notice Emitted when Tomb address is changed by admin
    event TombSet(EIP20Interface indexed tomb);

    /// @notice Emitted when Tombtroller address is changed by admin
    event TombtrollerSet(ITombtroller indexed newTombtroller);

    /// @notice Emitted when admin is transfered
    event AdminTransferred(address oldAdmin, address newAdmin);

    /// @notice Emitted when accruedRewards is set
    event AccruedRewardsSet(uint8 rewardType, address indexed user, uint256 amount);

    /// @notice Emitted when the setAccruedRewardsForUsers function is locked
    event InitializeRewardAccruedLocked();

    /**
     * @notice Checks if caller is admin
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin");
        _;
    }

    /**
     * @notice Checks if caller is tombtroller or admin
     */
    modifier onlyTombtrollerOrAdmin() {
        require(msg.sender == address(tombtroller) || msg.sender == admin, "only tombtroller or admin");
        _;
    }

    /**
     * @notice Checks that reward type is valid
     */
    modifier verifyRewardType(uint8 rewardType) {
        require(rewardType <= 1, "rewardType is invalid");
        _;
    }

    /**
     * @notice Initialize function, in 2 times to avoid redeploying tombtroller
     * @dev first call is made by the deploy script, the second one by tombTroller
     * when calling `_setRewardDistributor`
     */
    function initialize() public {
        require(address(tombtroller) == address(0), "already initialized");
        if (admin == address(0)) {
            admin = msg.sender;
        } else {
            tombtroller = ITombtroller(msg.sender);
        }
    }

    /**
     * @notice Payable function needed to receive FTM
     */
    function() external payable {}

    /*** User functions ***/

    /**
     * @notice Claim all the stlLIF3 accrued by holder in all markets
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param holder The address to claim stlLIF3 for
     */
    function claimReward(uint8 rewardType, address payable holder) external {
        _claimReward(rewardType, holder, tombtroller.getAllMarkets(), true, true);
    }

    /**
     * @notice Claim all the stlLIF3 accrued by holder in the specified markets
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param holder The address to claim stlLIF3 for
     * @param tTokens The list of markets to claim stlLIF3 in
     */
    function claimReward(
        uint8 rewardType,
        address payable holder,
        ITToken[] calldata tTokens
    ) external {
        _claimReward(rewardType, holder, tTokens, true, true);
    }

    /**
     * @notice Claim all stlLIF3 accrued by the holders
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param holders The addresses to claim stlLIF3 for
     * @param tTokens The list of markets to claim stlLIF3 in
     * @param borrowers Whether or not to claim stlLIF3 earned by borrowing
     * @param suppliers Whether or not to claim stlLIF3 earned by supplying
     */
    function claimReward(
        uint8 rewardType,
        address payable[] calldata holders,
        ITToken[] calldata tTokens,
        bool borrowers,
        bool suppliers
    ) external {
        uint256 len = holders.length;
        for (uint256 i; i < len; i++) {
            _claimReward(rewardType, holders[i], tTokens, borrowers, suppliers);
        }
    }

    /**
     * @notice Returns the pending stlLIF3 reward accrued by the holder
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param holder The address to check pending stlLIF3 for
     * @return pendingReward The pending stlLIF3 reward of that holder
     */
    function pendingReward(uint8 rewardType, address holder) external view returns (uint256) {
        return _pendingReward(rewardType, holder, tombtroller.getAllMarkets());
    }

    /*** Tombtroller Or Tomb Distribution Admin ***/

    /**
     * @notice Refactored function to calc and rewards accounts supplier rewards
     * @param tToken The market to verify the mint against
     * @param supplier The supplier to be rewarded
     */
    function updateAndDistributeSupplierRewardsForToken(ITToken tToken, address supplier)
        external
        onlyTombtrollerOrAdmin
    {
        for (uint8 rewardType; rewardType <= 1; rewardType++) {
            _updateRewardSupplyIndex(rewardType, tToken);
            uint256 reward = _distributeSupplierReward(rewardType, tToken, supplier);
            rewardAccrued[rewardType][supplier] = rewardAccrued[rewardType][supplier].add(reward);
        }
    }

    /**
     * @notice Refactored function to calc and rewards accounts borrower rewards
     * @param tToken The market to verify the mint against
     * @param borrower Borrower to be rewarded
     * @param marketBorrowIndex Current index of the borrow market
     */
    function updateAndDistributeBorrowerRewardsForToken(
        ITToken tToken,
        address borrower,
        Exp calldata marketBorrowIndex
    ) external onlyTombtrollerOrAdmin {
        for (uint8 rewardType; rewardType <= 1; rewardType++) {
            _updateRewardBorrowIndex(rewardType, tToken, marketBorrowIndex.mantissa);
            uint256 reward = _distributeBorrowerReward(rewardType, tToken, borrower, marketBorrowIndex.mantissa);
            rewardAccrued[rewardType][borrower] = rewardAccrued[rewardType][borrower].add(reward);
        }
    }

    /*** Tomb Distribution Admin ***/

    /**
     * @notice Set stlLIF3 speed for a single market
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param tToken The market whose reward speed to update
     * @param rewardSupplySpeed New reward supply speed for market
     * @param rewardBorrowSpeed New reward borrow speed for market
     */
    function setRewardSpeed(
        uint8 rewardType,
        ITToken tToken,
        uint256 rewardSupplySpeed,
        uint256 rewardBorrowSpeed
    ) external onlyAdmin verifyRewardType(rewardType) {
        _setRewardSupplySpeed(rewardType, tToken, rewardSupplySpeed);
        _setRewardBorrowSpeed(rewardType, tToken, rewardBorrowSpeed);
    }

    /**
     * @notice Transfer stlLIF3 to the recipient
     * @dev Note: If there is not enough stlLIF3, we do not perform the transfer at all.
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param recipient The address of the recipient to transfer stlLIF3 to
     * @param amount The amount of stlLIF3 to (possibly) transfer
     */
    function grantReward(
        uint8 rewardType,
        address payable recipient,
        uint256 amount
    ) external onlyAdmin verifyRewardType(rewardType) {
        uint256 amountLeft = _grantReward(rewardType, recipient, amount);
        require(amountLeft == 0, "insufficient tomb for grant");
        emit RewardGranted(rewardType, recipient, amount);
    }

    /**
     * @notice Set the stlLIF3 token address
     * @param _tomb The stlLIF3 token address
     */
    function setTomb(EIP20Interface _tomb) external onlyAdmin {
        require(address(tomb) == address(0), "tomb already initialized");
        tomb = _tomb;
        emit TombSet(_tomb);
    }

    /**
     * @notice Set the admin
     * @param newAdmin The address of the new admin
     */
    function setAdmin(address newAdmin) external onlyAdmin {
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminTransferred(oldAdmin, newAdmin);
    }

    /**
     * @notice Initialize rewardAccrued of users for the first time
     * @dev We initialize rewardAccrued to transfer pending rewards from previous rewarder to this one.
     * Must call lockInitializeRewardAccrued() after initialization.
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param users The list of addresses of users that did not claim their rewards
     * @param amounts The list of amounts of unclaimed rewards
     */
    function initializeRewardAccrued(
        uint8 rewardType,
        address[] calldata users,
        uint256[] calldata amounts
    ) external onlyAdmin verifyRewardType(rewardType) {
        require(!isInitializeRewardAccruedLocked, "initializeRewardAccrued is locked");
        uint256 len = users.length;
        require(len == amounts.length, "length mismatch");
        for (uint256 i; i < len; i++) {
            address user = users[i];
            uint256 amount = amounts[i];
            rewardAccrued[rewardType][user] = amount;
            emit AccruedRewardsSet(rewardType, user, amount);
        }
    }

    /**
     * @notice Lock the initializeRewardAccrued function
     */
    function lockInitializeRewardAccrued() external onlyAdmin {
        isInitializeRewardAccruedLocked = true;
        emit InitializeRewardAccruedLocked();
    }

    /*** Private functions ***/

    /**
     * @notice Set stlLIF3 supply speed
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param tToken The market whose speed to update
     * @param newRewardSupplySpeed New stlLIF3 or FTM supply speed for market
     */
    function _setRewardSupplySpeed(
        uint8 rewardType,
        ITToken tToken,
        uint256 newRewardSupplySpeed
    ) private {
        // Handle new supply speed
        uint256 currentRewardSupplySpeed = rewardSupplySpeeds[rewardType][address(tToken)];

        if (currentRewardSupplySpeed != 0) {
            // note that stlLIF3 speed could be set to 0 to halt liquidity rewards for a market
            _updateRewardSupplyIndex(rewardType, tToken);
        } else if (newRewardSupplySpeed != 0) {
            // Add the stlLIF3 market
            require(tombtroller.isMarketListed(address(tToken)), "reward market is not listed");
            rewardSupplyState[rewardType][address(tToken)].timestamp = _safe48(_getBlockTimestamp());
        }

        if (currentRewardSupplySpeed != newRewardSupplySpeed) {
            rewardSupplySpeeds[rewardType][address(tToken)] = newRewardSupplySpeed;
            emit RewardSupplySpeedUpdated(rewardType, tToken, newRewardSupplySpeed);
        }
    }

    /**
     * @notice Set stlLIF3 borrow speed
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param tToken The market whose speed to update
     * @param newRewardBorrowSpeed New stlLIF3 or FTM borrow speed for market
     */
    function _setRewardBorrowSpeed(
        uint8 rewardType,
        ITToken tToken,
        uint256 newRewardBorrowSpeed
    ) private {
        // Handle new borrow speed
        uint256 currentRewardBorrowSpeed = rewardBorrowSpeeds[rewardType][address(tToken)];

        if (currentRewardBorrowSpeed != 0) {
            // note that stlLIF3 speed could be set to 0 to halt liquidity rewards for a market
            _updateRewardBorrowIndex(rewardType, tToken, tToken.borrowIndex());
        } else if (newRewardBorrowSpeed != 0) {
            // Add the stlLIF3 market
            require(tombtroller.isMarketListed(address(tToken)), "reward market is not listed");
            rewardBorrowState[rewardType][address(tToken)].timestamp = _safe48(_getBlockTimestamp());
        }

        if (currentRewardBorrowSpeed != newRewardBorrowSpeed) {
            rewardBorrowSpeeds[rewardType][address(tToken)] = newRewardBorrowSpeed;
            emit RewardBorrowSpeedUpdated(rewardType, tToken, newRewardBorrowSpeed);
        }
    }

    /**
     * @notice Accrue stlLIF3 to the market by updating the supply index
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param tToken The market whose supply index to update
     */
    function _updateRewardSupplyIndex(uint8 rewardType, ITToken tToken) private verifyRewardType(rewardType) {
        (uint208 supplyIndex, bool update) = _getUpdatedRewardSupplyIndex(rewardType, tToken);

        if (update) {
            rewardSupplyState[rewardType][address(tToken)].index = supplyIndex;
        }
        rewardSupplyState[rewardType][address(tToken)].timestamp = _safe48(_getBlockTimestamp());
    }

    /**
     * @notice Accrue stlLIF3 to the market by updating the borrow index
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param tToken The market whose borrow index to update
     * @param marketBorrowIndex Current index of the borrow market
     */
    function _updateRewardBorrowIndex(
        uint8 rewardType,
        ITToken tToken,
        uint256 marketBorrowIndex
    ) private verifyRewardType(rewardType) {
        (uint208 borrowIndex, bool update) = _getUpdatedRewardBorrowIndex(rewardType, tToken, marketBorrowIndex);

        if (update) {
            rewardBorrowState[rewardType][address(tToken)].index = borrowIndex;
        }
        rewardBorrowState[rewardType][address(tToken)].timestamp = _safe48(_getBlockTimestamp());
    }

    /**
     * @notice Calculate stlLIF3 accrued by a supplier
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param tToken The market in which the supplier is interacting
     * @param supplier The address of the supplier to distribute stlLIF3 to
     * @return supplierReward The stlLIF3 amount of reward from market
     */
    function _distributeSupplierReward(
        uint8 rewardType,
        ITToken tToken,
        address supplier
    ) private verifyRewardType(rewardType) returns (uint208) {
        uint256 supplyIndex = rewardSupplyState[rewardType][address(tToken)].index;
        uint256 supplierIndex = rewardSupplierIndex[rewardType][address(tToken)][supplier];

        uint256 deltaIndex = supplyIndex.sub(supplierIndex);
        uint256 supplierAmount = tToken.balanceOf(supplier);
        uint208 supplierReward = _safe208(supplierAmount.mul(deltaIndex).div(doubleScale));

        if (supplyIndex != supplierIndex) {
            rewardSupplierIndex[rewardType][address(tToken)][supplier] = supplyIndex;
        }
        emit DistributedSupplierReward(rewardType, tToken, supplier, supplierReward, supplyIndex);
        return supplierReward;
    }

    /**
     * @notice Calculate stlLIF3 accrued by a borrower
     * @dev Borrowers will not begin to accrue until after the first interaction with the protocol.
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param tToken The market in which the borrower is interacting
     * @param borrower The address of the borrower to distribute stlLIF3 to
     * @param marketBorrowIndex Current index of the borrow market
     * @return borrowerReward The stlLIF3 amount of reward from market
     */
    function _distributeBorrowerReward(
        uint8 rewardType,
        ITToken tToken,
        address borrower,
        uint256 marketBorrowIndex
    ) private verifyRewardType(rewardType) returns (uint208) {
        uint256 borrowIndex = rewardBorrowState[rewardType][address(tToken)].index;
        uint256 borrowerIndex = rewardBorrowerIndex[rewardType][address(tToken)][borrower];

        uint256 deltaIndex = borrowIndex.sub(borrowerIndex);
        uint256 borrowerAmount = tToken.borrowBalanceStored(borrower).mul(expScale).div(marketBorrowIndex);
        uint208 borrowerReward = _safe208(borrowerAmount.mul(deltaIndex).div(doubleScale));

        if (borrowIndex != borrowerIndex) {
            rewardBorrowerIndex[rewardType][address(tToken)][borrower] = borrowIndex;
        }
        emit DistributedBorrowerReward(rewardType, tToken, borrower, borrowerReward, borrowIndex);
        return borrowerReward;
    }

    /**
     * @notice Claim all stlLIF3 accrued by the holders
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param holder The address to claim stlLIF3 for
     * @param tTokens The list of markets to claim stlLIF3 in
     * @param borrower Whether or not to claim stlLIF3 earned by borrowing
     * @param supplier Whether or not to claim stlLIF3 earned by supplying
     */
    function _claimReward(
        uint8 rewardType,
        address payable holder,
        ITToken[] memory tTokens,
        bool borrower,
        bool supplier
    ) private verifyRewardType(rewardType) {
        uint256 rewards = rewardAccrued[rewardType][holder];
        uint256 len = tTokens.length;
        for (uint256 i; i < len; i++) {
            ITToken tToken = tTokens[i];
            require(tombtroller.isMarketListed(address(tToken)), "market must be listed");

            if (borrower) {
                uint256 marketBorrowIndex = tToken.borrowIndex();
                _updateRewardBorrowIndex(rewardType, tToken, marketBorrowIndex);
                uint256 reward = _distributeBorrowerReward(rewardType, tToken, holder, marketBorrowIndex);
                rewards = rewards.add(reward);
            }
            if (supplier) {
                _updateRewardSupplyIndex(rewardType, tToken);
                uint256 reward = _distributeSupplierReward(rewardType, tToken, holder);
                rewards = rewards.add(reward);
            }
        }
        if (rewards != 0) {
            rewardAccrued[rewardType][holder] = _grantReward(rewardType, holder, rewards);
        }
    }

    /**
     * @notice Returns the pending stlLIF3 reward for holder
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param holder The address to return the pending stlLIF3 reward for
     * @param tTokens The markets to return the pending stlLIF3 reward in
     * @return uint256 The stlLIF3 reward for that user
     */
    function _pendingReward(
        uint8 rewardType,
        address holder,
        ITToken[] memory tTokens
    ) private view verifyRewardType(rewardType) returns (uint256) {
        uint256 rewards = rewardAccrued[rewardType][holder];
        uint256 len = tTokens.length;

        for (uint256 i; i < len; i++) {
            ITToken tToken = tTokens[i];

            uint256 supplierReward = _pendingSupplyReward(rewardType, tToken, holder);
            uint256 borrowerReward = _pendingBorrowReward(rewardType, tToken, holder, tToken.borrowIndex());

            rewards = rewards.add(supplierReward).add(borrowerReward);
        }

        return rewards;
    }

    /**
     * @notice Returns the pending stlLIF3 reward for a supplier on a market
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param holder The address to return the pending stlLIF3 reward for
     * @param tToken The market to return the pending stlLIF3 reward in
     * @return uint256 The stlLIF3 reward for that user
     */
    function _pendingSupplyReward(
        uint8 rewardType,
        ITToken tToken,
        address holder
    ) private view returns (uint256) {
        (uint256 supplyIndex, ) = _getUpdatedRewardSupplyIndex(rewardType, tToken);
        uint256 supplierIndex = rewardSupplierIndex[rewardType][address(tToken)][holder];

        uint256 deltaIndex = supplyIndex.sub(supplierIndex);
        uint256 supplierAmount = tToken.balanceOf(holder);
        return supplierAmount.mul(deltaIndex).div(doubleScale);
    }

    /**
     * @notice Returns the pending stlLIF3 reward for a borrower on a market
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param holder The address to return the pending stlLIF3 reward for
     * @param tToken The market to return the pending stlLIF3 reward in
     * @param marketBorrowIndex Current index of the borrow market
     * @return uint256 The stlLIF3 reward for that user
     */
    function _pendingBorrowReward(
        uint8 rewardType,
        ITToken tToken,
        address holder,
        uint256 marketBorrowIndex
    ) private view returns (uint256) {
        (uint256 borrowIndex, ) = _getUpdatedRewardBorrowIndex(rewardType, tToken, marketBorrowIndex);
        uint256 borrowerIndex = rewardBorrowerIndex[rewardType][address(tToken)][holder];

        uint256 deltaIndex = borrowIndex.sub(borrowerIndex);
        uint256 borrowerAmount = tToken.borrowBalanceStored(holder).mul(expScale).div(marketBorrowIndex);

        return borrowerAmount.mul(deltaIndex).div(doubleScale);
    }

    /**
     * @notice Returns the updated reward supply index
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param tToken The market whose supply index to update
     * @return uint208 The updated supply state index
     * @return bool If the stored supply state index needs to be updated
     */
    function _getUpdatedRewardSupplyIndex(uint8 rewardType, ITToken tToken) private view returns (uint208, bool) {
        RewardMarketState memory supplyState = rewardSupplyState[rewardType][address(tToken)];
        uint256 supplySpeed = rewardSupplySpeeds[rewardType][address(tToken)];
        uint256 deltaTimestamps = _getBlockTimestamp().sub(supplyState.timestamp);

        if (deltaTimestamps != 0 && supplySpeed != 0) {
            uint256 supplyTokens = tToken.totalSupply();
            if (supplyTokens != 0) {
                uint256 reward = deltaTimestamps.mul(supplySpeed);
                supplyState.index = _safe208(uint256(supplyState.index).add(reward.mul(doubleScale).div(supplyTokens)));
                return (supplyState.index, true);
            }
        }
        return (supplyState.index, false);
    }

    /**
     * @notice Returns the updated reward borrow index
     * @param rewardType 0 = stlLIF3, 1 = FTM
     * @param tToken The market whose borrow index to update
     * @param marketBorrowIndex Current index of the borrow market
     * @return uint208 The updated borrow state index
     * @return bool If the stored borrow state index needs to be updated
     */
    function _getUpdatedRewardBorrowIndex(
        uint8 rewardType,
        ITToken tToken,
        uint256 marketBorrowIndex
    ) private view returns (uint208, bool) {
        RewardMarketState memory borrowState = rewardBorrowState[rewardType][address(tToken)];
        uint256 borrowSpeed = rewardBorrowSpeeds[rewardType][address(tToken)];
        uint256 deltaTimestamps = _getBlockTimestamp().sub(borrowState.timestamp);

        if (deltaTimestamps != 0 && borrowSpeed != 0) {
            uint256 totalBorrows = tToken.totalBorrows();
            uint256 borrowAmount = totalBorrows.mul(expScale).div(marketBorrowIndex);
            if (borrowAmount != 0) {
                uint256 reward = deltaTimestamps.mul(borrowSpeed);
                borrowState.index = _safe208(uint256(borrowState.index).add(reward.mul(doubleScale).div(borrowAmount)));
                return (borrowState.index, true);
            }
        }
        return (borrowState.index, false);
    }

    /**
     * @notice Transfer stlLIF3 to the user
     * @dev Note: If there is not enough stlLIF3, we do not perform the transfer at all.
     * @param rewardType 0 = stlLIF3, 1 = FTM.
     * @param user The address of the user to transfer stlLIF3 to
     * @param amount The amount of stlLIF3 to (possibly) transfer
     * @return uint256 The amount of stlLIF3 which was NOT transferred to the user
     */
    function _grantReward(
        uint8 rewardType,
        address payable user,
        uint256 amount
    ) private returns (uint256) {
        if (amount == 0) {
            return 0;
        }
        if (rewardType == 0) {
            uint256 tombRemaining = tomb.balanceOf(address(this));
            if (amount <= tombRemaining) {
                TransferHelper.safeTransfer(address(tomb), user, amount);
                return 0;
            }
        } else if (rewardType == 1) {
            uint256 ftmRemaining = address(this).balance;
            if (amount <= ftmRemaining) {
                user.transfer(amount);
                return 0;
            }
        }
        return amount;
    }

    /**
     * @notice Function to get the current timestamp
     * @return uint256 The current timestamp
     */
    function _getBlockTimestamp() private view returns (uint256) {
        return block.timestamp;
    }

    /**
     * @notice Return x written on 48 bits while asserting that x doesn't exceed 48 bits
     * @param x The value
     * @return uint48 The value x on 48 bits
     */
    function _safe48(uint256 x) private pure returns (uint48) {
        require(x < 2**48, "exceeds 48 bits");
        return uint48(x);
    }

    /**
     * @notice Return x written on 208 bits while asserting that x doesn't exceed 208 bits
     * @param x The value
     * @return uint208 The value x on 208 bits
     */
    function _safe208(uint256 x) private pure returns (uint208) {
        require(x < 2**208, "exceeds 208 bits");
        return uint208(x);
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.5.16;

/**
 * @title ERC 20 Token Standard Interface
 *  https://eips.ethereum.org/EIPS/eip-20
 */
interface EIP20Interface {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    /**
     * @notice Get the total number of tokens in circulation
     * @return The supply of tokens
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Gets the balance of the specified address
     * @param owner The address from which the balance will be retrieved
     * @return The balance
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `dst`
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transfer(address dst, uint256 amount) external returns (bool success);

    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) external returns (bool success);

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param amount The number of tokens that are approved (-1 means infinite)
     * @return Whether or not the approval succeeded
     */
    function approve(address spender, uint256 amount) external returns (bool success);

    /**
     * @notice Get the current allowance from `owner` for `spender`
     * @param owner The address of the account which owns the tokens to be spent
     * @param spender The address of the account which may transfer tokens
     * @return The number of tokens allowed to be spent (-1 means infinite)
     */
    function allowance(address owner, address spender) external view returns (uint256 remaining);

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.5.16;

// From https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/Math.sol
// Subject to the MIT license.

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting with custom message on overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, errorMessage);

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on underflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot underflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction underflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on underflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot underflow.
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
     * @dev Returns the multiplication of two unsigned integers, reverting on overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
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
     * @dev Returns the multiplication of two unsigned integers, reverting on overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, errorMessage);

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers.
     * Reverts on division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers.
     * Reverts with custom message on division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
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

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.5.16;

import "./CarefulMath.sol";

/**
 * @title Exponential module for storing fixed-precision decimals
 * @author Compound
 * @notice Exp is a struct which stores decimals with a fixed precision of 18 decimal places.
 *         Thus, if we wanted to store the 5.1, mantissa would store 5.1e18. That is:
 *         `Exp({mantissa: 5100000000000000000})`.
 */
contract Exponential is CarefulMath {
    uint256 constant expScale = 1e18;
    uint256 constant doubleScale = 1e36;
    uint256 constant halfExpScale = expScale / 2;
    uint256 constant mantissaOne = expScale;

    struct Exp {
        uint256 mantissa;
    }

    struct Double {
        uint256 mantissa;
    }

    /**
     * @dev Creates an exponential from numerator and denominator values.
     *      Note: Returns an error if (`num` * 10e18) > MAX_INT,
     *            or if `denom` is zero.
     */
    function getExp(uint256 num, uint256 denom) internal pure returns (MathError, Exp memory) {
        (MathError err0, uint256 scaledNumerator) = mulUInt(num, expScale);
        if (err0 != MathError.NO_ERROR) {
            return (err0, Exp({mantissa: 0}));
        }

        (MathError err1, uint256 rational) = divUInt(scaledNumerator, denom);
        if (err1 != MathError.NO_ERROR) {
            return (err1, Exp({mantissa: 0}));
        }

        return (MathError.NO_ERROR, Exp({mantissa: rational}));
    }

    /**
     * @dev Adds two exponentials, returning a new exponential.
     */
    function addExp(Exp memory a, Exp memory b) internal pure returns (MathError, Exp memory) {
        (MathError error, uint256 result) = addUInt(a.mantissa, b.mantissa);

        return (error, Exp({mantissa: result}));
    }

    /**
     * @dev Subtracts two exponentials, returning a new exponential.
     */
    function subExp(Exp memory a, Exp memory b) internal pure returns (MathError, Exp memory) {
        (MathError error, uint256 result) = subUInt(a.mantissa, b.mantissa);

        return (error, Exp({mantissa: result}));
    }

    /**
     * @dev Multiply an Exp by a scalar, returning a new Exp.
     */
    function mulScalar(Exp memory a, uint256 scalar) internal pure returns (MathError, Exp memory) {
        (MathError err0, uint256 scaledMantissa) = mulUInt(a.mantissa, scalar);
        if (err0 != MathError.NO_ERROR) {
            return (err0, Exp({mantissa: 0}));
        }

        return (MathError.NO_ERROR, Exp({mantissa: scaledMantissa}));
    }

    /**
     * @dev Multiply an Exp by a scalar, then truncate to return an unsigned integer.
     */
    function mulScalarTruncate(Exp memory a, uint256 scalar) internal pure returns (MathError, uint256) {
        (MathError err, Exp memory product) = mulScalar(a, scalar);
        if (err != MathError.NO_ERROR) {
            return (err, 0);
        }

        return (MathError.NO_ERROR, truncate(product));
    }

    /**
     * @dev Multiply an Exp by a scalar, truncate, then add an to an unsigned integer, returning an unsigned integer.
     */
    function mulScalarTruncateAddUInt(
        Exp memory a,
        uint256 scalar,
        uint256 addend
    ) internal pure returns (MathError, uint256) {
        (MathError err, Exp memory product) = mulScalar(a, scalar);
        if (err != MathError.NO_ERROR) {
            return (err, 0);
        }

        return addUInt(truncate(product), addend);
    }

    /**
     * @dev Multiply an Exp by a scalar, then truncate to return an unsigned integer.
     */
    function mul_ScalarTruncate(Exp memory a, uint256 scalar) internal pure returns (uint256) {
        Exp memory product = mul_(a, scalar);
        return truncate(product);
    }

    /**
     * @dev Multiply an Exp by a scalar, truncate, then add an to an unsigned integer, returning an unsigned integer.
     */
    function mul_ScalarTruncateAddUInt(
        Exp memory a,
        uint256 scalar,
        uint256 addend
    ) internal pure returns (uint256) {
        Exp memory product = mul_(a, scalar);
        return add_(truncate(product), addend);
    }

    /**
     * @dev Divide an Exp by a scalar, returning a new Exp.
     */
    function divScalar(Exp memory a, uint256 scalar) internal pure returns (MathError, Exp memory) {
        (MathError err0, uint256 descaledMantissa) = divUInt(a.mantissa, scalar);
        if (err0 != MathError.NO_ERROR) {
            return (err0, Exp({mantissa: 0}));
        }

        return (MathError.NO_ERROR, Exp({mantissa: descaledMantissa}));
    }

    /**
     * @dev Divide a scalar by an Exp, returning a new Exp.
     */
    function divScalarByExp(uint256 scalar, Exp memory divisor) internal pure returns (MathError, Exp memory) {
        /*
          We are doing this as:
          getExp(mulUInt(expScale, scalar), divisor.mantissa)

          How it works:
          Exp = a / b;
          Scalar = s;
          `s / (a / b)` = `b * s / a` and since for an Exp `a = mantissa, b = expScale`
        */
        (MathError err0, uint256 numerator) = mulUInt(expScale, scalar);
        if (err0 != MathError.NO_ERROR) {
            return (err0, Exp({mantissa: 0}));
        }
        return getExp(numerator, divisor.mantissa);
    }

    /**
     * @dev Divide a scalar by an Exp, then truncate to return an unsigned integer.
     */
    function divScalarByExpTruncate(uint256 scalar, Exp memory divisor) internal pure returns (MathError, uint256) {
        (MathError err, Exp memory fraction) = divScalarByExp(scalar, divisor);
        if (err != MathError.NO_ERROR) {
            return (err, 0);
        }

        return (MathError.NO_ERROR, truncate(fraction));
    }

    /**
     * @dev Divide a scalar by an Exp, returning a new Exp.
     */
    function div_ScalarByExp(uint256 scalar, Exp memory divisor) internal pure returns (Exp memory) {
        /*
          We are doing this as:
          getExp(mulUInt(expScale, scalar), divisor.mantissa)

          How it works:
          Exp = a / b;
          Scalar = s;
          `s / (a / b)` = `b * s / a` and since for an Exp `a = mantissa, b = expScale`
        */
        uint256 numerator = mul_(expScale, scalar);
        return Exp({mantissa: div_(numerator, divisor)});
    }

    /**
     * @dev Divide a scalar by an Exp, then truncate to return an unsigned integer.
     */
    function div_ScalarByExpTruncate(uint256 scalar, Exp memory divisor) internal pure returns (uint256) {
        Exp memory fraction = div_ScalarByExp(scalar, divisor);
        return truncate(fraction);
    }

    /**
     * @dev Multiplies two exponentials, returning a new exponential.
     */
    function mulExp(Exp memory a, Exp memory b) internal pure returns (MathError, Exp memory) {
        (MathError err0, uint256 doubleScaledProduct) = mulUInt(a.mantissa, b.mantissa);
        if (err0 != MathError.NO_ERROR) {
            return (err0, Exp({mantissa: 0}));
        }

        // We add half the scale before dividing so that we get rounding instead of truncation.
        //  See "Listing 6" and text above it at https://accu.org/index.php/journals/1717
        // Without this change, a result like 6.6...e-19 will be truncated to 0 instead of being rounded to 1e-18.
        (MathError err1, uint256 doubleScaledProductWithHalfScale) = addUInt(halfExpScale, doubleScaledProduct);
        if (err1 != MathError.NO_ERROR) {
            return (err1, Exp({mantissa: 0}));
        }

        (MathError err2, uint256 product) = divUInt(doubleScaledProductWithHalfScale, expScale);
        // The only error `div` can return is MathError.DIVISION_BY_ZERO but we control `expScale` and it is not zero.
        assert(err2 == MathError.NO_ERROR);

        return (MathError.NO_ERROR, Exp({mantissa: product}));
    }

    /**
     * @dev Multiplies two exponentials given their mantissas, returning a new exponential.
     */
    function mulExp(uint256 a, uint256 b) internal pure returns (MathError, Exp memory) {
        return mulExp(Exp({mantissa: a}), Exp({mantissa: b}));
    }

    /**
     * @dev Multiplies three exponentials, returning a new exponential.
     */
    function mulExp3(
        Exp memory a,
        Exp memory b,
        Exp memory c
    ) internal pure returns (MathError, Exp memory) {
        (MathError err, Exp memory ab) = mulExp(a, b);
        if (err != MathError.NO_ERROR) {
            return (err, ab);
        }
        return mulExp(ab, c);
    }

    /**
     * @dev Divides two exponentials, returning a new exponential.
     *     (a/scale) / (b/scale) = (a/scale) * (scale/b) = a/b,
     *  which we can scale as an Exp by calling getExp(a.mantissa, b.mantissa)
     */
    function divExp(Exp memory a, Exp memory b) internal pure returns (MathError, Exp memory) {
        return getExp(a.mantissa, b.mantissa);
    }

    /**
     * @dev Truncates the given exp to a whole number value.
     *      For example, truncate(Exp{mantissa: 15 * expScale}) = 15
     */
    function truncate(Exp memory exp) internal pure returns (uint256) {
        // Note: We are not using careful math here as we're performing a division that cannot fail
        return exp.mantissa / expScale;
    }

    /**
     * @dev Checks if first Exp is less than second Exp.
     */
    function lessThanExp(Exp memory left, Exp memory right) internal pure returns (bool) {
        return left.mantissa < right.mantissa;
    }

    /**
     * @dev Checks if left Exp <= right Exp.
     */
    function lessThanOrEqualExp(Exp memory left, Exp memory right) internal pure returns (bool) {
        return left.mantissa <= right.mantissa;
    }

    /**
     * @dev returns true if Exp is exactly zero
     */
    function isZeroExp(Exp memory value) internal pure returns (bool) {
        return value.mantissa == 0;
    }

    function safe224(uint256 n, string memory errorMessage) internal pure returns (uint224) {
        require(n < 2**224, errorMessage);
        return uint224(n);
    }

    function safe32(uint256 n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function add_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
        return Exp({mantissa: add_(a.mantissa, b.mantissa)});
    }

    function add_(Double memory a, Double memory b) internal pure returns (Double memory) {
        return Double({mantissa: add_(a.mantissa, b.mantissa)});
    }

    function add_(uint256 a, uint256 b) internal pure returns (uint256) {
        return add_(a, b, "addition overflow");
    }

    function add_(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
        return Exp({mantissa: sub_(a.mantissa, b.mantissa)});
    }

    function sub_(Double memory a, Double memory b) internal pure returns (Double memory) {
        return Double({mantissa: sub_(a.mantissa, b.mantissa)});
    }

    function sub_(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub_(a, b, "subtraction underflow");
    }

    function sub_(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    function mul_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
        return Exp({mantissa: mul_(a.mantissa, b.mantissa) / expScale});
    }

    function mul_(Exp memory a, uint256 b) internal pure returns (Exp memory) {
        return Exp({mantissa: mul_(a.mantissa, b)});
    }

    function mul_(uint256 a, Exp memory b) internal pure returns (uint256) {
        return mul_(a, b.mantissa) / expScale;
    }

    function mul_(Double memory a, Double memory b) internal pure returns (Double memory) {
        return Double({mantissa: mul_(a.mantissa, b.mantissa) / doubleScale});
    }

    function mul_(Double memory a, uint256 b) internal pure returns (Double memory) {
        return Double({mantissa: mul_(a.mantissa, b)});
    }

    function mul_(uint256 a, Double memory b) internal pure returns (uint256) {
        return mul_(a, b.mantissa) / doubleScale;
    }

    function mul_(uint256 a, uint256 b) internal pure returns (uint256) {
        return mul_(a, b, "multiplication overflow");
    }

    function mul_(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        if (a == 0 || b == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, errorMessage);
        return c;
    }

    function div_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
        return Exp({mantissa: div_(mul_(a.mantissa, expScale), b.mantissa)});
    }

    function div_(Exp memory a, uint256 b) internal pure returns (Exp memory) {
        return Exp({mantissa: div_(a.mantissa, b)});
    }

    function div_(uint256 a, Exp memory b) internal pure returns (uint256) {
        return div_(mul_(a, expScale), b.mantissa);
    }

    function div_(Double memory a, Double memory b) internal pure returns (Double memory) {
        return Double({mantissa: div_(mul_(a.mantissa, doubleScale), b.mantissa)});
    }

    function div_(Double memory a, uint256 b) internal pure returns (Double memory) {
        return Double({mantissa: div_(a.mantissa, b)});
    }

    function div_(uint256 a, Double memory b) internal pure returns (uint256) {
        return div_(mul_(a, doubleScale), b.mantissa);
    }

    function div_(uint256 a, uint256 b) internal pure returns (uint256) {
        return div_(a, b, "divide by zero");
    }

    function div_(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    function fraction(uint256 a, uint256 b) internal pure returns (Double memory) {
        return Double({mantissa: div_(mul_(a, doubleScale), b)});
    }

    // implementation from https://github.com/Uniswap/uniswap-lib/commit/99f3f28770640ba1bb1ff460ac7c5292fb8291a0
    // original implementation: https://github.com/abdk-consulting/abdk-libraries-solidity/blob/master/ABDKMath64x64.sol#L687
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 xx = x;
        uint256 r = 1;

        if (xx >= 0x100000000000000000000000000000000) {
            xx >>= 128;
            r <<= 64;
        }
        if (xx >= 0x10000000000000000) {
            xx >>= 64;
            r <<= 32;
        }
        if (xx >= 0x100000000) {
            xx >>= 32;
            r <<= 16;
        }
        if (xx >= 0x10000) {
            xx >>= 16;
            r <<= 8;
        }
        if (xx >= 0x100) {
            xx >>= 8;
            r <<= 4;
        }
        if (xx >= 0x10) {
            xx >>= 4;
            r <<= 2;
        }
        if (xx >= 0x8) {
            r <<= 1;
        }

        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1; // Seven iterations should be enough
        uint256 r1 = x / r;
        return (r < r1 ? r : r1);
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.5.16;

/**
 * @title Careful Math
 * @author Compound
 * @notice Derived from OpenZeppelin's SafeMath library
 *         https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/math/SafeMath.sol
 */
contract CarefulMath {
    /**
     * @dev Possible error codes that we can return
     */
    enum MathError {
        NO_ERROR,
        DIVISION_BY_ZERO,
        INTEGER_OVERFLOW,
        INTEGER_UNDERFLOW
    }

    /**
     * @dev Multiplies two numbers, returns an error on overflow.
     */
    function mulUInt(uint256 a, uint256 b) internal pure returns (MathError, uint256) {
        if (a == 0) {
            return (MathError.NO_ERROR, 0);
        }

        uint256 c = a * b;

        if (c / a != b) {
            return (MathError.INTEGER_OVERFLOW, 0);
        } else {
            return (MathError.NO_ERROR, c);
        }
    }

    /**
     * @dev Integer division of two numbers, truncating the quotient.
     */
    function divUInt(uint256 a, uint256 b) internal pure returns (MathError, uint256) {
        if (b == 0) {
            return (MathError.DIVISION_BY_ZERO, 0);
        }

        return (MathError.NO_ERROR, a / b);
    }

    /**
     * @dev Subtracts two numbers, returns an error on overflow (i.e. if subtrahend is greater than minuend).
     */
    function subUInt(uint256 a, uint256 b) internal pure returns (MathError, uint256) {
        if (b <= a) {
            return (MathError.NO_ERROR, a - b);
        } else {
            return (MathError.INTEGER_UNDERFLOW, 0);
        }
    }

    /**
     * @dev Adds two numbers, returns an error on overflow.
     */
    function addUInt(uint256 a, uint256 b) internal pure returns (MathError, uint256) {
        uint256 c = a + b;

        if (c >= a) {
            return (MathError.NO_ERROR, c);
        } else {
            return (MathError.INTEGER_OVERFLOW, 0);
        }
    }

    /**
     * @dev add a and b and then subtract c
     */
    function addThenSubUInt(
        uint256 a,
        uint256 b,
        uint256 c
    ) internal pure returns (MathError, uint256) {
        (MathError err0, uint256 sum) = addUInt(a, b);

        if (err0 != MathError.NO_ERROR) {
            return (err0, 0);
        }

        return subUInt(sum, c);
    }
}