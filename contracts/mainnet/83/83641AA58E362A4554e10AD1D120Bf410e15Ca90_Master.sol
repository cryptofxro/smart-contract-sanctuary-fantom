// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20Snapshot.sol";
import "./AuthorizableNoOperator.sol";
import "./interfaces/IERC20Lockable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/ITheoretics.sol";
import "./utils/ContractGuard.sol";
import "./interfaces/ITreasury.sol";

contract Master is ERC20Snapshot, AuthorizableNoOperator, ContractGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20Lockable;
    using SafeERC20 for IERC20;


    struct UserInfo
    {
        uint256 lockToTime;
        uint256 chosenLockTime;
        address approveTransferFrom;
        uint256 lastSnapshotIndex;
        uint256 rewardEarned;
        uint256 withdrawRequestedInMaster;
        uint256 withdrawRequestedInTheory;
        uint256 lastStakeRequestBlock;
        uint256 lastWithdrawRequestBlock;
        uint256 gameLocked;
        uint256 gameLockFrom;
        uint256 gameLastUnlockTime;
    }

    mapping(address => UserInfo) public userInfo;
    IERC20Lockable private theory;
    IERC20Lockable private game;
    ITheoretics private theoretics;
    ITreasury private treasury;
    uint256 public minLockTime;
    uint256 public unlockedClaimPenalty;

    //uint256 public extraTheoryAdded;
    //uint256 public extraTheoryStakeRequested;
    //uint256 public extraTheoryWithdrawRequested;

    uint256 public totalStakeRequestedInTheory;
    uint256 public totalWithdrawRequestedInTheory;
    uint256 public totalWithdrawRequestedInMaster;
    uint256 public totalWithdrawUnclaimedInTheory;
    uint256 public totalGameUnclaimed;
    uint256 private lastInitiatePart1Epoch;
    uint256 private lastInitiatePart2Epoch;
    uint256 private lastInitiatePart1Block;
    uint256 private lastInitiatePart2Block;
    uint256 public totalGameLocked;
    struct MasterSnapshot {
        uint256 time;
        uint256 rewardReceived;
        uint256 rewardPerShare;
    }
    MasterSnapshot[] public masterHistory;
    address[] private whitelistedTokens;
    bool private emergencyUnlock;


    event RewardPaid(address indexed user, uint256 reward, uint256 lockAmount);
    event Deposit(address indexed user, uint256 amountInTheory, uint256 amountOutMaster);
    event Withdraw(address indexed user, uint256 amountInMaster, uint256 amountOutTheory);
    event WithdrawRequest(address indexed user, uint256 amountInMaster, uint256 amountOutTheory);
    event LockGame(address indexed to, uint256 value);
    event UnlockGame(address indexed to, uint256 value);

    //Permissions needed: game (Game)
    constructor(IERC20Lockable _theory,
                IERC20Lockable _game,
                ITheoretics _theoretics,
                ITreasury _treasury,
                address[] memory _whitelist) public ERC20("Master Token", "MASTER") {
        theory = _theory;
        game = _game;
        theoretics = _theoretics;
        treasury = _treasury;
        minLockTime = 365 days;
        unlockedClaimPenalty = 30 days;
        MasterSnapshot memory genesisSnapshot = MasterSnapshot({time : block.number, rewardReceived : 0, rewardPerShare : 0});
        masterHistory.push(genesisSnapshot);
        whitelistedTokens = _whitelist;
    }


    //View functions
    //For THEORY -> MASTER (forked from https://github.com/DefiKingdoms/contracts/blob/main/contracts/Bank.sol)
    function theoryToMaster(uint256 _amount) public view returns (uint256)
    {
        // Gets the amount of GovernanceToken locked in the contract
        uint256 totalGovernanceToken = theoretics.balanceOf(address(this)).add(totalStakeRequestedInTheory);
        // Gets the amount of xGovernanceToken in existence
        uint256 totalShares = totalSupply();
        // If no xGovernanceToken exists, it is 1:1
        if (totalShares == 0 || totalGovernanceToken == 0) {
            return _amount;
        }
        // Calculates the amount of xGovernanceToken the GovernanceToken is worth. The ratio will change overtime, as xGovernanceToken is burned/minted and GovernanceToken deposited + gained from fees / withdrawn.
        uint256 what = _amount.mul(totalShares).div(totalGovernanceToken);
        return what;
    }

    //For MASTER -> THEORY (forked from https://github.com/DefiKingdoms/contracts/blob/main/contracts/Bank.sol)
    function masterToTheory(uint256 _share) public view returns (uint256)
    {
        // Gets the amount of GovernanceToken locked in the contract
        uint256 totalGovernanceToken = theoretics.balanceOf(address(this)).add(totalStakeRequestedInTheory);
        // Gets the amount of xGovernanceToken in existence
        uint256 totalShares = totalSupply();
        // If no xGovernanceToken exists, it is 1:1
        if (totalShares == 0 || totalGovernanceToken == 0) {
            return _share;
        }
        // Calculates the amount of GovernanceToken the xGovernanceToken is worth
        uint256 what = _share.mul(totalGovernanceToken).div(totalShares);
        return what;
    }

    //Snapshot

    // =========== Snapshot getters

    function latestSnapshotIndex() public view returns (uint256) {
        return masterHistory.length.sub(1);
    }

    function getLatestSnapshot() internal view returns (MasterSnapshot memory) {
        return masterHistory[latestSnapshotIndex()];
    }

    function getLastSnapshotIndexOf(address theorist) public view returns (uint256) {
        return userInfo[theorist].lastSnapshotIndex;
    }

    function getLastSnapshotOf(address theorist) internal view returns (MasterSnapshot memory) {
        return masterHistory[getLastSnapshotIndexOf(theorist)];
    }

    function earned(address theorist) public view returns (uint256) {
        uint256 latestRPS = getLatestSnapshot().rewardPerShare;
        uint256 storedRPS = getLastSnapshotOf(theorist).rewardPerShare;

        return balanceOf(theorist).mul(latestRPS.sub(storedRPS)).div(1e18).add(userInfo[theorist].rewardEarned);
    }

    function canUnlockAmountGame(address _holder) public view returns (uint256) {
        uint256 lockTime = game.lockTime();
        UserInfo memory user = userInfo[_holder];
        if (block.timestamp <= user.gameLockFrom) {
            return 0;
        } else if (block.timestamp >= user.gameLockFrom.add(lockTime)) {
            return user.gameLocked;
        } else {
            uint256 releaseTime = block.timestamp.sub(user.gameLastUnlockTime);
            uint256 numberLockTime = user.gameLockFrom.add(lockTime).sub(user.gameLastUnlockTime);
            return user.gameLocked.mul(releaseTime).div(numberLockTime);
        }
    }

    function totalCanUnlockAmountGame(address _holder) external view returns (uint256) {
       return game.canUnlockAmount(_holder).add(canUnlockAmountGame(_holder));
    }

    function totalBalanceOfGame(address _holder) external view returns (uint256) {
        return userInfo[_holder].gameLocked.add(game.totalBalanceOf(_holder));
    }

    function lockOfGame(address _holder) external view returns (uint256) {
        return game.lockOf(_holder).add(userInfo[_holder].gameLocked);
    }

    function totalLockGame() external view returns (uint256) {
        return totalGameLocked.add(game.totalLock());
    }

    //Modifiers
    modifier updateReward(address theorist) {
        if (theorist != address(0)) {
            UserInfo memory user = userInfo[theorist];
            user.rewardEarned = earned(theorist);
            user.lastSnapshotIndex = latestSnapshotIndex();
            userInfo[theorist] = user;
        }
        _;
    }

    //Admin functions
    function setAdmin(uint256 lockTime, uint256 penalty, bool emergency) external onlyAuthorized
    {
        //Default: 1 year/365 days
        //Lock time too high.
        require(lockTime <= 730 days, "LT"); //730 days/2 years = length from beginning of emissions to full LTHEORY unlock.  No need to be higher than that.
        //Penalty too high.
        require(penalty <= lockTime, "PT"); //No higher than lock time.
        minLockTime = lockTime;
        unlockedClaimPenalty = penalty;
        emergencyUnlock = emergency;
    }

    function unlockGameForUser(address account, uint256 amount) public onlyAuthorized {
        // First we need to unlock all tokens the address is eligible for.
        uint256 pendingLocked = canUnlockAmountGame(account);
        if (pendingLocked > 0) {
            _unlockGame(account, pendingLocked);
        }

        // Then unlock GAME in the Game contract
        uint256 pendingLockOf = game.lockOf(account); //Lock before
        if (pendingLockOf > game.canUnlockAmount(msg.sender))
        {
            game.unlockForUser(account, 0); //Unlock amount naturally first.
            pendingLockOf = game.lockOf(account);
        }
        if(pendingLockOf > 0)
        {
            game.unlockForUser(account, amount);
            uint256 amountUnlocked = pendingLockOf.sub(game.lockOf(account)); //Lock before - lock after
            if(amount > amountUnlocked) amount = amount.sub(amountUnlocked); //Don't unlock the amount already unlocked
            else amount = 0; // <= 0? = 0
        }

        // Now that that's done, we can unlock the extra amount passed in.
        if(amount > 0 && userInfo[account].gameLocked > 0) _unlockGame(account, amount);
    }

    //Not required as no payable function.
//    function transferFTM(address payable to, uint256 amount) external onlyAuthorized onlyOneBlock
//    {
//        to.transfer(amount);
//    }

    function transferToken(IERC20 _token, address to, uint256 amount) external onlyAuthorized {
        //Required in order move MASTER and other tokens if they get stuck in the contract.
        //Some security measures in place for MASTER and THEORY.
        require(address(_token) != address(this) || amount <= balanceOf(address(this)).sub(totalWithdrawRequestedInMaster), "AF"); //Cannot transfer more than accidental funds.
        //require(address(_token) != address(theory) || amount <= theory.balanceOf(address(this)).sub(totalStakeRequested.add(totalWithdrawUnclaimed)), "Cannot withdraw pending funds."); //To prevent a number of issues that crop up when extra THEORY is removed, this function as been disabled. THEORY sent here is essentially donated to MASTER if staked. Otherwise, it is out of circulation.
        require(address(_token) != address(theory), "MP-"); //Cannot bring down price of MASTER.
        require(address(_token) != address(game) || amount <= game.balanceOf(address(this)).sub(totalGameUnclaimed).sub(totalGameLocked), "AF"); //Cannot transfer more than accidental funds.
        //WHITELIST BEGIN (Initiated in constructor due to contract size limits)
        bool isInList = false;
        uint256 i;
        uint256 len = whitelistedTokens.length;
        for(i = 0; i < len; ++i)
        {
            if(address(_token) == whitelistedTokens[i])
            {
                isInList = true;
                break;
            }
        }
        require(address(_token) == address(this) //MASTER
            || address(_token) == address(game) //GAME
            || isInList, "WL"); //Can only transfer whitelisted tokens.

        //WHITELIST END
        _token.safeTransfer(to, amount);
    }

    function stakeExternalTheory(uint256 amount) external onlyAuthorized onlyOneBlock {
        require(amount <= theory.balanceOf(address(this)).sub(totalStakeRequestedInTheory.add(totalWithdrawUnclaimedInTheory)), "PF"); //Cannot stake pending funds.
        if(lastInitiatePart2Epoch == theoretics.epoch() || theoretics.getCurrentWithdrawEpochs() == 0)
        {
            //extraTheoryAdded = extraTheoryAdded.add(amount); //Track extra theory that we will stake immediately.
            theory.safeApprove(address(theoretics), 0);
            theory.safeApprove(address(theoretics), amount);
            theoretics.stake(amount); //Stake if we already have staked this epoch or are at 0 withdraw epochs.
        }
        else
        {
            totalStakeRequestedInTheory = totalStakeRequestedInTheory.add(amount);
            //extraTheoryStakeRequested = extraTheoryStakeRequested.add(amount);
        }
    }

    //To prevent a number of issues that crop up when extra THEORY is removed, this function as been disabled. THEORY sent here is instead shared amongst the holders.
//    function withdrawExternalTheory(uint256 amount) external onlyAuthorized onlyOneBlock {
//        //This doesn't prevent all damage to people who got in after 1.0x, but it prevents a full withdrawal.
//        require(amount >= extraTheoryAdded, "Can't withdraw past 1.0x.");
//        extraTheoryAdded = extraTheoryAdded.sub(amount); //Subtract early so we don't go over max amount.
//        extraTheoryWithdrawRequested = extraTheoryWithdrawRequested.add(amount);
//    }

    //Internal functions

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal updateReward(from) updateReward(to) virtual override {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal virtual override {
        address daoFund = treasury.daoFund();
        address own = owner();
        UserInfo storage user = userInfo[to];
        if(user.lockToTime == 0 || !(authorized[msg.sender] || own == msg.sender || daoFund == msg.sender || address(this) == msg.sender
        || authorized[from] || own == from || daoFund == from || address(this) == from
        || authorized[to] || own == to || daoFund == to || address(this) == to))
        {
            require(user.lockToTime == 0 || user.approveTransferFrom == from, "Receiver did not approve transfer.");
            user.approveTransferFrom = address(0);
            uint256 nextTime = block.timestamp.add(minLockTime);
            if(nextTime > user.lockToTime) user.lockToTime = nextTime;
        }
        super._transfer(from, to, amount);

    }

    function lockGame(address _holder, uint256 _amount) internal
    {
        UserInfo storage user = userInfo[_holder];
        uint256 amount = canUnlockAmountGame(_holder);

        if(user.gameLocked > 0) _unlockGame(_holder, amount); //Before we lock more, make sure we unlock everything we can, even if noUnlockBeforeTransfer is set.

        uint256 _lockFromTime = block.timestamp;
        user.gameLockFrom = _lockFromTime;

        user.gameLocked = user.gameLocked.add(_amount);
        totalGameLocked = totalGameLocked.add(_amount);
        if (user.gameLastUnlockTime < user.gameLockFrom) {
            user.gameLastUnlockTime = user.gameLockFrom;
        }
        emit LockGame(_holder, _amount);
    }

    function _unlockGame(address holder, uint256 amount) internal {
        UserInfo storage user = userInfo[holder];
        require(user.gameLocked > 0, "ILT"); //Insufficient locked tokens

        // Make sure they aren't trying to unlock more than they have locked.
        if (amount > user.gameLocked) {
            amount = user.gameLocked;
        }

        // If the amount is greater than the total balance, set it to max.
        if (amount > totalGameLocked) {
            amount = totalGameLocked;
        }
        game.safeTransfer(holder, amount);
        user.gameLocked = user.gameLocked.sub(amount);
        user.gameLastUnlockTime = block.timestamp;
        totalGameLocked = totalGameLocked.sub(amount);

        emit UnlockGame(holder, amount);
    }
    function _claimGame() internal
    {
        uint256 reward = userInfo[msg.sender].rewardEarned;
        if (reward > 0) {
            userInfo[msg.sender].rewardEarned = 0;
            totalGameUnclaimed = totalGameUnclaimed.sub(reward);
            // GAME can always be locked.
            uint256 lockAmount = 0;
            uint256 lockPercentage = theoretics.getLockPercentage();
            require(lockPercentage <= 100, "LP"); //Invalid lock percentage, check Theoretics contract.
            lockAmount = reward.mul(lockPercentage).div(100);
            //if(lockAmount > 0) game.lock(msg.sender, lockAmount); //Due to security measures, this won't work. We have to make separate LGAME.
            lockGame(msg.sender, lockAmount);
            game.safeTransfer(msg.sender, reward.sub(lockAmount));
            emit RewardPaid(msg.sender, reward, lockAmount);
        }
    }

    function _initiatePart1(bool allowEmergency) internal
    {
        //Unlock all LGAME, transfer GAME, then relock at normal rate.
        uint256 initialBalance = game.totalBalanceOf(address(this));
        //uint256 _withdrawLockupEpochs = theoretics.withdrawLockupEpochs();
        //uint256 _rewardLockupEpochs = theoretics.rewardLockupEpochs();
        //uint256 _pegMaxUnlock = theoretics.pegMaxUnlock();
        //theoretics.setLockUp(0, 0, _pegMaxUnlock); //Can't use these because of onlyOneBlock.

        //We may have had a saving grace: But we do have a saving grace: farm.getLockPercentage(). If that is at 95%, then we have 0 lockups.
        //But I was TOO anal about security: The function returns 0 after the pool ends, no matter what.

        //Instead, we must limit claiming and staking to every getCurrentWithdrawEpochs() epochs with a window of 5 hours and 30 minutes (you can request at any time, but it will execute once after this window).
        //Instead of withdrawing/claiming from theoretics here, we store withdraw requests and withdraw the full amount for everybody at once after 5 hours and 30 minutes.
        //If there are no withdraw requests, just claim and stake instead of withdrawing and staking. If there are no claim/withdraw requests, just stake. If there are no stake requests, fail the function.
        //The user can then come back at any time after to receive their withdraw/claim.
        //If getCurrentWithdrawEpochs() is 0, just call the initiator function immediately.

        if(totalWithdrawRequestedInMaster != 0)
        {
            //Burn requested master so price remains the same.
            _burn(address(this), totalWithdrawRequestedInMaster);
            totalWithdrawRequestedInMaster = 0;
        }

        if(totalWithdrawRequestedInTheory
        //.add(extraTheoryWithdrawRequested)
            == 0) theoretics.claimReward();
        else
        {
            uint256 initialBalanceTheory = theory.balanceOf(address(this));

            uint256 what = totalWithdrawRequestedInTheory
            //.add(extraTheoryWithdrawRequested);
            ;
            totalWithdrawRequestedInTheory = 0;

            //Now that I think about it, we could probably do something like this to burn immediately and avoid delayed prices altogether. But it is getting too complicated, and the current system helps MASTER holders anyways.
            if(what > totalStakeRequestedInTheory) //Withdraw > Stake: Only withdraw. We need a bit more to pay our debt.
            {
                what = what.sub(totalStakeRequestedInTheory); //Withdraw less to handle "stake". Reserves (staked amount chilling in the contract) will cover some of our debt (requested withdraws).
                totalStakeRequestedInTheory = 0; //Don't stake in part 2 anymore, as it was already technically "staked" here.
            }
            else //Stake >= Withdraw: Only stake or do nothing. We have enough THEORY in our reserves to support all the withdraws.
            {
                totalStakeRequestedInTheory = totalStakeRequestedInTheory.sub(what); //Stake less to handle "withdraw". Reserves (staked amount chilling in the contract) will cover all of our debt (requested withdraws). Stake the remaining reserves here, if any.
                what = 0; //Don't withdraw in part 1 anymore, it was already "withdrawn" here.
            }

            if(what > 0)
            {
                theoretics.withdraw(what);

                uint256 newBalanceTheory = theory.balanceOf(address(this));
                uint256 whatAfterWithdrawFee = newBalanceTheory.sub(initialBalanceTheory);

                uint256 withdrawFee = what.sub(whatAfterWithdrawFee);
                address daoFund = treasury.daoFund();
                if(!allowEmergency || withdrawFee > 0 && theory.allowance(daoFund, address(this)) >= withdrawFee) theory.safeTransferFrom(daoFund, address(this), withdrawFee); //Send withdraw fee back to us. Don't allow this function to hold up funds.

    //            if(extraTheoryWithdrawRequested > 0)
    //            {
    //                theory.safeTransfer(treasury.daoFund(), extraTheoryWithdrawRequested);
    //                extraTheoryWithdrawRequested = 0;
    //            }
            }
            else
            {
                theoretics.claimReward(); //Claim.
            }
        }
        //theoretics.setLockUp(_withdrawLockupEpochs, _rewardLockupEpochs, _pegMaxUnlock);
        //Unlock
        uint256 extraLocked = game.lockOf(address(this)).sub(game.canUnlockAmount(address(this)));
        if(extraLocked > 0)
        {
            game.unlockForUser(address(this), extraLocked);
        }
        uint256 newBalance = game.totalBalanceOf(address(this));
        uint256 amount = newBalance.sub(initialBalance);
        totalGameUnclaimed = totalGameUnclaimed.add(amount);

        //Calculate amount to earn
        // Create & add new snapshot
        uint256 prevRPS = getLatestSnapshot().rewardPerShare;
        uint256 supply = totalSupply();
        //Nobody earns any GAME if everyone withdraws. If that's the case, all GAME goes to the treasury's daoFund.
        uint256 nextRPS = supply == 0 ? prevRPS : prevRPS.add(amount.mul(1e18).div(supply)); //Otherwise, GAME is distributed amongst those who have not yet burned their MASTER.

        if(supply == 0)
        {
            game.safeTransfer(treasury.daoFund(), amount);
        }

        MasterSnapshot memory newSnapshot = MasterSnapshot({
        time: block.number,
        rewardReceived: amount,
        rewardPerShare: nextRPS
        });
        masterHistory.push(newSnapshot);

        lastInitiatePart1Epoch = theoretics.epoch();
        lastInitiatePart1Block = block.number;
    }

    function _sellToTheory() internal
    {
        UserInfo storage user = userInfo[msg.sender];
        //require(block.timestamp >= user.lockToTime, "Still locked!"); //Allow locked people to withdraw since it no longer counts towards their rewards.
        require(user.withdrawRequestedInMaster > 0, "No zero amount allowed.");
        require(theoretics.getCurrentWithdrawEpochs() == 0 || lastInitiatePart1Block > user.lastWithdrawRequestBlock, "Initiator Part 1 not yet called or called too soon.");

        //Burn
        uint256 what = user.withdrawRequestedInTheory;

        totalWithdrawUnclaimedInTheory = totalWithdrawUnclaimedInTheory.sub(what);
        //We already handle burn en-masse
        uint256 amountInMaster = user.withdrawRequestedInMaster;
        user.withdrawRequestedInMaster = 0;
        user.withdrawRequestedInTheory = 0;
        theory.safeTransfer(msg.sender, what);
        emit Withdraw(msg.sender, amountInMaster, what);
    }

    //Public functions
    function buyFromTheory(uint256 amountInTheory, uint256 lockTime) public onlyOneBlock updateReward(msg.sender)
    {
        require(amountInTheory > 0, "No zero amount allowed.");
        UserInfo storage user = userInfo[msg.sender];
        uint256 withdrawEpochs = theoretics.getCurrentWithdrawEpochs();
        require(user.withdrawRequestedInMaster == 0 && (withdrawEpochs == 0 || user.lastWithdrawRequestBlock == 0 || lastInitiatePart1Block > user.lastWithdrawRequestBlock), "Cannot stake with a withdraw pending.");

        //Lock
        if(lockTime < minLockTime) lockTime = minLockTime;
        //Just in case we want bonuses/airdrops for those who lock longer. This would have to be done outside of this contract, as it provides no bonuses by itself.
        uint256 nextTime = block.timestamp.add(lockTime);

        user.chosenLockTime = lockTime;
        if(nextTime > user.lockToTime) user.lockToTime = nextTime;

        //Mint
        uint256 what = theoryToMaster(amountInTheory);
        theory.safeTransferFrom(msg.sender, address(this), amountInTheory);

        _mint(msg.sender, what); //Don't delay mint, since price has to stay the same or higher (or else withdraws could be borked). Delayed buys could make it go lower.
        if(lastInitiatePart2Epoch == theoretics.epoch() || withdrawEpochs == 0)
        {
            address theoreticsAddress = address(theoretics);
            theory.safeApprove(theoreticsAddress, 0);
            theory.safeApprove(theoreticsAddress, amountInTheory);
            theoretics.stake(amountInTheory); //Stake if we already have staked this epoch or are at 0 withdraw epochs.
        }
        else
        {
            totalStakeRequestedInTheory = totalStakeRequestedInTheory.add(amountInTheory);
        }

        user.lastStakeRequestBlock = block.number;
        emit Deposit(msg.sender, amountInTheory, what);
    }

    function requestSellToTheory(uint256 amountInMaster, bool allowEmergency) public onlyOneBlock updateReward(msg.sender)
    {
        UserInfo storage user = userInfo[msg.sender];
        require(block.timestamp >= user.lockToTime || emergencyUnlock, "Still locked!");
        require(amountInMaster > 0, "No zero amount allowed.");
        uint256 withdrawEpochs = theoretics.getCurrentWithdrawEpochs();
        require(withdrawEpochs == 0 || user.lastStakeRequestBlock == 0 || lastInitiatePart2Block > user.lastStakeRequestBlock, "Cannot withdraw with a stake pending.");

        if(amountInMaster == balanceOf(msg.sender)) _claimGame(); //Final GAME claim before moving to THEORY.

        //Add. Since we have to transfer here to avoid transfer exploits, we cannot do a replace.
        _transfer(msg.sender, address(this), amountInMaster); //This will handle exceeded balance.
        user.withdrawRequestedInMaster = user.withdrawRequestedInMaster.add(amountInMaster);
        totalWithdrawRequestedInMaster = totalWithdrawRequestedInMaster.add(amountInMaster);

        //If price increases between now and burn, the extra will be used for future withdrawals, increasing the price further.
        //Price should not be able to decrease between now and burn.
        uint256 what = masterToTheory(amountInMaster);

        user.withdrawRequestedInTheory = user.withdrawRequestedInTheory.add(what);
        totalWithdrawRequestedInTheory = totalWithdrawRequestedInTheory.add(what);
        totalWithdrawUnclaimedInTheory = totalWithdrawUnclaimedInTheory.add(what);

        user.lastWithdrawRequestBlock = block.number;
        emit WithdrawRequest(msg.sender, amountInMaster, what);
        if(withdrawEpochs == 0)
        {
            _initiatePart1(allowEmergency);
            _sellToTheory();
        }
    }

    function sellToTheory() public onlyOneBlock updateReward(msg.sender)
    {
        require(theoretics.getCurrentWithdrawEpochs() != 0, "Call requestSellToTheory instead.");
        _sellToTheory();
    }

    function claimGame() public onlyOneBlock updateReward(msg.sender)
    {
        require(earned(msg.sender) > 0, "No GAME to claim."); //Avoid locking yourself for nothing.
        //If you claim GAME after your lock time is over, you are locked up for 30 more days by default.
        UserInfo storage user = userInfo[msg.sender];
        if(block.timestamp >= user.lockToTime)
        {
            user.lockToTime = block.timestamp.add(unlockedClaimPenalty);
        }
        _claimGame();
    }

    function initiatePart1(bool allowEmergency) public onlyOneBlock
    {
        uint256 withdrawEpochs = theoretics.getCurrentWithdrawEpochs();
        uint256 nextEpochPoint = theoretics.nextEpochPoint();
        uint256 epoch = theoretics.epoch();
        //Every getCurrentWithdrawEpochs() epochs
        require(withdrawEpochs == 0 || epoch.mod(withdrawEpochs) == 0, "WE"); // Must call at a withdraw epoch.
        //Only in last 30 minutes of the epoch.
        require(block.timestamp > nextEpochPoint || nextEpochPoint.sub(block.timestamp) <= 30 minutes, "30"); //Must be called at most 30 minutes before epoch ends.
        //No calling twice within the epoch.
        require(lastInitiatePart1Epoch != epoch, "AC"); //Already called.
       _initiatePart1(allowEmergency);
    }

    function initiatePart2() public onlyOneBlock
    {
        uint256 withdrawEpochs = theoretics.getCurrentWithdrawEpochs();
        uint256 nextEpochPoint = theoretics.nextEpochPoint();
        uint256 epoch = theoretics.epoch();
        //Every getCurrentWithdrawEpochs() epochs
        require(withdrawEpochs == 0 || epoch.mod(withdrawEpochs) == 0, "WE"); //Must call at a withdraw epoch.
        //Only in last 30 minutes of the epoch.
        require(block.timestamp > nextEpochPoint || nextEpochPoint.sub(block.timestamp) <= 30 minutes, "30"); //Must be called at most 30 minutes before epoch ends.
        //No calling twice within the epoch.
        require(lastInitiatePart2Epoch != epoch, "AC"); //Already called.
        //No calling before part 1.
        require(lastInitiatePart1Epoch == epoch, "IP1"); //Initiate part 1 first.
        if(totalStakeRequestedInTheory > 0)
        {
            address theoreticsAddress = address(theoretics);
            theory.safeApprove(theoreticsAddress, 0);
            theory.safeApprove(theoreticsAddress, totalStakeRequestedInTheory);
            theoretics.stake(totalStakeRequestedInTheory);
            //extraTheoryAdded = extraTheoryAdded.add(extraTheoryStakeRequested); //Track extra theory that we have staked.
            //extraTheoryStakeRequested = 0;
            totalStakeRequestedInTheory = 0;
        }
        lastInitiatePart2Epoch = epoch;
        lastInitiatePart2Block = block.number;
    }

    function approveTransferFrom(address from) public
    {
        userInfo[msg.sender].approveTransferFrom = from;
    }

    function unlockGame() public {
        uint256 amount = canUnlockAmountGame(msg.sender);
        uint256 lockOf = game.lockOf(msg.sender);
        uint256 gameAmount = game.canUnlockAmount(msg.sender);
        UserInfo memory user = userInfo[msg.sender];
        require(user.gameLocked > 0 || lockOf > gameAmount, "ILT"); //Insufficient locked tokens
        if (user.gameLocked > 0) _unlockGame(msg.sender, amount);
        //Unlock GAME in smart contract as well (only if it won't revert), otherwise still have to call unlock() first.
        if (lockOf > gameAmount) game.unlockForUser(msg.sender, 0);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../math/SafeMath.sol";
import "../../utils/Arrays.sol";
import "../../utils/Counters.sol";
import "./ERC20.sol";

/**
 * @dev This contract extends an ERC20 token with a snapshot mechanism. When a snapshot is created, the balances and
 * total supply at the time are recorded for later access.
 *
 * This can be used to safely create mechanisms based on token balances such as trustless dividends or weighted voting.
 * In naive implementations it's possible to perform a "double spend" attack by reusing the same balance from different
 * accounts. By using snapshots to calculate dividends or voting power, those attacks no longer apply. It can also be
 * used to create an efficient ERC20 forking mechanism.
 *
 * Snapshots are created by the internal {_snapshot} function, which will emit the {Snapshot} event and return a
 * snapshot id. To get the total supply at the time of a snapshot, call the function {totalSupplyAt} with the snapshot
 * id. To get the balance of an account at the time of a snapshot, call the {balanceOfAt} function with the snapshot id
 * and the account address.
 *
 * ==== Gas Costs
 *
 * Snapshots are efficient. Snapshot creation is _O(1)_. Retrieval of balances or total supply from a snapshot is _O(log
 * n)_ in the number of snapshots that have been created, although _n_ for a specific account will generally be much
 * smaller since identical balances in subsequent snapshots are stored as a single entry.
 *
 * There is a constant overhead for normal ERC20 transfers due to the additional snapshot bookkeeping. This overhead is
 * only significant for the first transfer that immediately follows a snapshot for a particular account. Subsequent
 * transfers will have normal cost until the next snapshot, and so on.
 */
abstract contract ERC20Snapshot is ERC20 {
    // Inspired by Jordi Baylina's MiniMeToken to record historical balances:
    // https://github.com/Giveth/minimd/blob/ea04d950eea153a04c51fa510b068b9dded390cb/contracts/MiniMeToken.sol

    using SafeMath for uint256;
    using Arrays for uint256[];
    using Counters for Counters.Counter;

    // Snapshotted values have arrays of ids and the value corresponding to that id. These could be an array of a
    // Snapshot struct, but that would impede usage of functions that work on an array.
    struct Snapshots {
        uint256[] ids;
        uint256[] values;
    }

    mapping (address => Snapshots) private _accountBalanceSnapshots;
    Snapshots private _totalSupplySnapshots;

    // Snapshot ids increase monotonically, with the first value being 1. An id of 0 is invalid.
    Counters.Counter private _currentSnapshotId;

    /**
     * @dev Emitted by {_snapshot} when a snapshot identified by `id` is created.
     */
    event Snapshot(uint256 id);

    /**
     * @dev Creates a new snapshot and returns its snapshot id.
     *
     * Emits a {Snapshot} event that contains the same id.
     *
     * {_snapshot} is `internal` and you have to decide how to expose it externally. Its usage may be restricted to a
     * set of accounts, for example using {AccessControl}, or it may be open to the public.
     *
     * [WARNING]
     * ====
     * While an open way of calling {_snapshot} is required for certain trust minimization mechanisms such as forking,
     * you must consider that it can potentially be used by attackers in two ways.
     *
     * First, it can be used to increase the cost of retrieval of values from snapshots, although it will grow
     * logarithmically thus rendering this attack ineffective in the long term. Second, it can be used to target
     * specific accounts and increase the cost of ERC20 transfers for them, in the ways specified in the Gas Costs
     * section above.
     *
     * We haven't measured the actual numbers; if this is something you're interested in please reach out to us.
     * ====
     */
    function _snapshot() internal virtual returns (uint256) {
        _currentSnapshotId.increment();

        uint256 currentId = _currentSnapshotId.current();
        emit Snapshot(currentId);
        return currentId;
    }

    /**
     * @dev Retrieves the balance of `account` at the time `snapshotId` was created.
     */
    function balanceOfAt(address account, uint256 snapshotId) public view virtual returns (uint256) {
        (bool snapshotted, uint256 value) = _valueAt(snapshotId, _accountBalanceSnapshots[account]);

        return snapshotted ? value : balanceOf(account);
    }

    /**
     * @dev Retrieves the total supply at the time `snapshotId` was created.
     */
    function totalSupplyAt(uint256 snapshotId) public view virtual returns(uint256) {
        (bool snapshotted, uint256 value) = _valueAt(snapshotId, _totalSupplySnapshots);

        return snapshotted ? value : totalSupply();
    }


    // Update balance and/or total supply snapshots before the values are modified. This is implemented
    // in the _beforeTokenTransfer hook, which is executed for _mint, _burn, and _transfer operations.
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
      super._beforeTokenTransfer(from, to, amount);

      if (from == address(0)) {
        // mint
        _updateAccountSnapshot(to);
        _updateTotalSupplySnapshot();
      } else if (to == address(0)) {
        // burn
        _updateAccountSnapshot(from);
        _updateTotalSupplySnapshot();
      } else {
        // transfer
        _updateAccountSnapshot(from);
        _updateAccountSnapshot(to);
      }
    }

    function _valueAt(uint256 snapshotId, Snapshots storage snapshots)
        private view returns (bool, uint256)
    {
        require(snapshotId > 0, "ERC20Snapshot: id is 0");
        // solhint-disable-next-line max-line-length
        require(snapshotId <= _currentSnapshotId.current(), "ERC20Snapshot: nonexistent id");

        // When a valid snapshot is queried, there are three possibilities:
        //  a) The queried value was not modified after the snapshot was taken. Therefore, a snapshot entry was never
        //  created for this id, and all stored snapshot ids are smaller than the requested one. The value that corresponds
        //  to this id is the current one.
        //  b) The queried value was modified after the snapshot was taken. Therefore, there will be an entry with the
        //  requested id, and its value is the one to return.
        //  c) More snapshots were created after the requested one, and the queried value was later modified. There will be
        //  no entry for the requested id: the value that corresponds to it is that of the smallest snapshot id that is
        //  larger than the requested one.
        //
        // In summary, we need to find an element in an array, returning the index of the smallest value that is larger if
        // it is not found, unless said value doesn't exist (e.g. when all values are smaller). Arrays.findUpperBound does
        // exactly this.

        uint256 index = snapshots.ids.findUpperBound(snapshotId);

        if (index == snapshots.ids.length) {
            return (false, 0);
        } else {
            return (true, snapshots.values[index]);
        }
    }

    function _updateAccountSnapshot(address account) private {
        _updateSnapshot(_accountBalanceSnapshots[account], balanceOf(account));
    }

    function _updateTotalSupplySnapshot() private {
        _updateSnapshot(_totalSupplySnapshots, totalSupply());
    }

    function _updateSnapshot(Snapshots storage snapshots, uint256 currentValue) private {
        uint256 currentId = _currentSnapshotId.current();
        if (_lastSnapshotId(snapshots.ids) < currentId) {
            snapshots.ids.push(currentId);
            snapshots.values.push(currentValue);
        }
    }

    function _lastSnapshotId(uint256[] storage ids) private view returns (uint256) {
        if (ids.length == 0) {
            return 0;
        } else {
            return ids[ids.length - 1];
        }
    }
}

pragma solidity 0.6.12;
import "@openzeppelin/contracts/access/Ownable.sol";

contract AuthorizableNoOperator is Ownable {
    mapping(address => bool) public authorized;

    modifier onlyAuthorized() {
        require(authorized[msg.sender] || owner() == msg.sender, "caller is not authorized");
        _;
    }

    function addAuthorized(address _toAdd) public onlyOwner {
        authorized[_toAdd] = true;
    }

    function removeAuthorized(address _toRemove) public onlyOwner {
        require(_toRemove != msg.sender);
        authorized[_toRemove] = false;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Lockable is IERC20 {
    function lock(address _holder, uint256 _amount) external;
    function lockOf(address account) external view returns (uint256);
    function totalLock() external view returns (uint256);
    function lockTime() external view returns (uint256);
    function totalBalanceOf(address account) external view returns (uint256);
    function canUnlockAmount(address account) external view returns (uint256);
    function unlockForUser(address account, uint256 amount) external;
    function burn(uint256 amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

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
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
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
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ITheoretics {
    function balanceOf(address _mason) external view returns (uint256);

    function earned(address _mason) external view returns (uint256);

    function canWithdraw(address _mason) external view returns (bool);

    function canClaimReward(address theorist) external view returns (bool);

    function epoch() external view returns (uint256);

    function nextEpochPoint() external view returns (uint256);

    function getGamePrice() external view returns (uint256);

    function setOperator(address _operator) external;

    function setLockUp(uint256 _withdrawLockupEpochs, uint256 _rewardLockupEpochs, uint256 _pegMaxUnlock) external;

    function stake(uint256 _amount) external;

    function withdraw(uint256 _amount) external;

    function exit() external;

    function claimReward() external;

    function allocateSeigniorage(uint256 _amount) external;

    function governanceRecoverUnsupported(address _token, uint256 _amount, address _to) external;

    function getCurrentWithdrawEpochs() external view returns (uint256);

    function getCurrentClaimEpochs() external view returns (uint256);

    function getWithdrawFeeOf(address _user) external view returns (uint256);

    function getLockPercentage() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function getLatestSnapshot() external view returns (uint256 time, uint256 rewardReceived, uint256 rewardPerShare);

    function latestSnapshotIndex() external view returns (uint256);

    function theoreticsHistory(uint256 index) external view returns (uint256 time, uint256 rewardReceived, uint256 rewardPerShare);
}

pragma solidity 0.6.12;

contract ContractGuard {
    mapping(uint256 => mapping(address => bool)) private _status;

    function checkSameOriginReentranted() internal view returns (bool) {
        return _status[block.number][tx.origin];
    }

    function checkSameSenderReentranted() internal view returns (bool) {
        return _status[block.number][msg.sender];
    }

    modifier onlyOneBlock() {
        require(!checkSameOriginReentranted(), "ContractGuard: one block, one function");
        require(!checkSameSenderReentranted(), "ContractGuard: one block, one function");

        _;

        _status[block.number][tx.origin] = true;
        _status[block.number][msg.sender] = true;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ITreasury {
    function epoch() external view returns (uint256);

    function nextEpochPoint() external view returns (uint256);

    function getGamePrice() external view returns (uint256);

    function gamePriceOne() external view returns (uint256);
    function gamePriceCeiling() external view returns (uint256);
    function initialized() external view returns (bool);
    function daoFund() external view returns (address);

    function buyBonds(uint256 amount, uint256 targetPrice) external;

    function redeemBonds(uint256 amount, uint256 targetPrice) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
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
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
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
        require(b <= a, "SafeMath: subtraction overflow");
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
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
        require(b > 0, "SafeMath: modulo by zero");
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
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
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
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../math/Math.sol";

/**
 * @dev Collection of functions related to array types.
 */
library Arrays {
   /**
     * @dev Searches a sorted `array` and returns the first index that contains
     * a value greater or equal to `element`. If no such index exists (i.e. all
     * values in the array are strictly less than `element`), the array length is
     * returned. Time complexity O(log n).
     *
     * `array` is expected to be sorted in ascending order, and to contain no
     * repeated elements.
     */
    function findUpperBound(uint256[] storage array, uint256 element) internal view returns (uint256) {
        if (array.length == 0) {
            return 0;
        }

        uint256 low = 0;
        uint256 high = array.length;

        while (low < high) {
            uint256 mid = Math.average(low, high);

            // Note that mid will always be strictly less than high (i.e. it will be a valid array index)
            // because Math.average rounds down (it does integer division with truncation).
            if (array[mid] > element) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        // At this point `low` is the exclusive upper bound. We will return the inclusive upper bound.
        if (low > 0 && array[low - 1] == element) {
            return low - 1;
        } else {
            return low;
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../math/SafeMath.sol";

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented or decremented by one. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 * Since it is not possible to overflow a 256 bit integer with increments of one, `increment` can skip the {SafeMath}
 * overflow check, thereby saving gas. This does assume however correct usage, in that the underlying `_value` is never
 * directly accessed.
 */
library Counters {
    using SafeMath for uint256;

    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        // The {SafeMath} overflow check can be skipped here, see the comment at the top
        counter._value += 1;
    }

    function decrement(Counter storage counter) internal {
        counter._value = counter._value.sub(1);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../utils/Context.sol";
import "./IERC20.sol";
import "../../math/SafeMath.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}

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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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