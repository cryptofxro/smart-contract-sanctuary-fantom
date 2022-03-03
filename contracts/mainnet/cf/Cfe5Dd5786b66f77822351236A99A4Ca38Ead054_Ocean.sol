// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../Pearl/IPearl.sol";
import "../NFT/NautilusNFT.sol";
import "../Fuel/IFuel.sol";
import "../utils/DateTime.sol";

struct StackedNFT{
    uint256 tokenId;
    address owner;
}

struct SubmarineClaim{
    uint256 divingDate;         // Date when diving start
    uint256 tokenId;              // Id of diving's token 
    uint256 claimAmount;        // Amount to claim
    uint256 divingFinishTime;   // Time after claiming is allowed
}

struct Upgrade{
    uint256 upgradeStartTime;   // Date when upgrade start
    uint256 tokenId;              // Id of upgrading token
    uint256 targetedLevel;      // Level reached after upgrade
    uint256 upgradeFinishTime;  // Time of upgrading
}

struct KrakenClaim{
    uint256 amount;             // Amount to spread with all `nbrOfKraken`
    uint256 nbrOfKraken;        // Amount of staked kraken  
}

struct ClaimForKraken{
    uint256 amountToClaim;
    uint256 amountToBurn;
    uint256 index;
}

contract Ocean is Ownable, ReentrancyGuard, Pausable {

    //EVENTS
    event NFTStaked(address owner, uint256 tokenId);
    event NFTUnstaked(address owner, uint256 tokenId);

    /* PARAMETERS */
    // Minimum diving time in minutes
    uint256 public DIVING_TIME = 60;
    // Minimum upgrade time in minutes
    uint256 public UPGRADE_TIME = 60;

    uint256 public MAX_UPGRADE_BY_DAY = 4;

    uint256 public SUBMARINE_UPGRADE_COEF = 15;
    uint256 public SUBMARINE_FIXED_UPGRADE = 200;
    uint256 public SUBMARINE_UPGRADE_START = 400;

    uint256 public KRAKEN_UPGRADE_COEF = 50;
    uint256 public KRAKEN_FIXED_UPGRADE = 500;
    uint256 public KRAKEN_UPGRADE_START = 1000;

    uint256 public SUBMARINE_REWARD_START = 80;
    uint256 public SUBMARINE_FIXED_REWARD = 50;
    uint256 public SUBMARINE_REWARD_COEF = 20;

    uint256 public FUEL_START = 4;
    uint256 public FUEL_COEF = 20;

    uint256 public TAX_VALUE = 10;

    uint256[10] riskRateByKrakenLevel = [56,52,48,44,40,36,32,28,24,20];
    uint256[11] krakenLevelUpgrade = [0,0,5000,7500,10000,15000,20000,25000,30000,40000,50000];
    uint256[4] levelUpgradeTime= [180,180,180,120];

    // $Fuel token contract address
    IFuel public _fuel;
    // $PEARL token contract address
    IPearl public _pearl;
    // NautilusNFT contract
    NautilusNFT public _nautilusNFT;

    DateTime public dateTime;

    // Id of staked token
    mapping(uint256 => StackedNFT) public ocean;

    // Map a owner `address` to an array of all stacked tokens id
    mapping(address => uint256[]) public addressToStaked;
    // Map an address to lenght of array mapped in `addressToStaked`
    mapping(address => uint256) public addressToStackedArrayLength;

    // Number of staked submarine token
    uint256 public totalSubmarineStaked = 0;
    // Number of staked kraken token
    uint256 public totalKrakenStaked = 0;

    // Counter to get waiting claim amount for a given submarine with token `id`
    mapping(uint256 => SubmarineClaim[]) public waitingClaimForSubmarine;

    // Token is upgrading or not
    mapping(uint256 => bool) public tokenIsUpgrading;

    // Map a token to number of upgrade in the day
    mapping(uint256 => uint256) public upgradesByDay;

    // Store upgrades made on kraken
    mapping(uint256 => Upgrade[]) public submarineUpgrades;
    // Store upgrade made on submarine
    mapping(uint256 => Upgrade[]) public krakenUpgrades;

    // Map token's id to the last claim index in `allKrakenClaim`
    mapping(uint256 => uint256) public lastKrakenClaimIndex;
    // All reward from submarine taxe
    KrakenClaim[] public allKrakenClaim;

    // If token has already been staked
    mapping(uint256 => bool) public firstStaked;

    bool firstStarted = false;

    constructor(address nautilusNFT, address pearl, address fuel) {
        _pearl = IPearl(pearl);
        _nautilusNFT = NautilusNFT(nautilusNFT);
        _fuel = IFuel(fuel);

        // Pause Ocean by default
         _pause();

         dateTime = new DateTime();
    }

    /* STAKING / UNSTAKING */

    /**
    * Stake all tokens in Ocean
    * @param tokensId Array containing id of tokens
     */
    function stakeTokensInOcean(uint256[] calldata tokensId) external noContract whenNotPaused nonReentrant {

        for(uint i = 0; i < tokensId.length; i++){
            require(!_isStaked(tokensId[i]),"Token already staked");
            require(_nautilusNFT.ownerOf(tokensId[i]) == msg.sender, "You are not the owner");


            // Send $FUEL for start
            if(!firstStaked[tokensId[i]] && _isSubmarine(tokensId[i])){
                _fuel.mintStart(msg.sender);
                firstStaked[tokensId[i]] = true;     
            }

            _nautilusNFT.transferFrom(msg.sender,address(this),tokensId[i]);
            _addTokenToOcean(tokensId[i], msg.sender);

            emit NFTStaked(msg.sender,tokensId[i]);

        }

    }

    /**
    * Unstake all tokens from Ocean
    * @param tokensId Array containing id of tokens
    */
    function unstakeTokensFromOcean(uint256[] calldata tokensId) external noContract whenNotPaused nonReentrant {

        for(uint i = 0; i < tokensId.length; i++){
            require(_isStaked(tokensId[i]),"Token not staked");
            require(_isStakeOwner(tokensId[i],msg.sender),"You are not the owner");
            if(_isSubmarine(tokensId[i])){
                require(!_isDiving(tokensId[i]),"Cannot unstake while diving");
            }

            _removeTokenFromOcean(tokensId[i],msg.sender);
            _nautilusNFT.transferFrom(address(this), msg.sender, tokensId[i]);

            emit NFTUnstaked(msg.sender, tokensId[i]);

        }
  
    }

    /**
    * Emergency unstake all tokens from Ocean
    * @param tokensId Array containing id of tokens
    */
    function emergencyUnstake(uint256[] calldata tokensId) external noContract whenPaused nonReentrant{

        for(uint i = 0; i < tokensId.length; i++){
            require(_isStaked(tokensId[i]),"Token not staked");
            require(_isStakeOwner(tokensId[i],msg.sender),"You are not the owner");

            _removeTokenFromOcean(tokensId[i],msg.sender);
            _nautilusNFT.transferFrom(address(this), msg.sender, tokensId[i]);

        }


    }

    /* CLAIM */

    /**
    * Claim rewards for submarine
    * @param tokensId Array of token's id
    */
    function claimForSubmarine(uint256[] calldata tokensId) public noContract whenNotPaused nonReentrant {        

        uint256 amountToClaim = 0;

        for(uint i = 0; i < tokensId.length; i++){
            require(_isStaked(tokensId[i]),"Cannot claim rewards for unstaked token");
            require(_isSubmarine(tokensId[i]),"Cannot claim rewards for kraken");
            require(_isStakeOwner(tokensId[i], msg.sender),"Token is not yours");
                
            // Get all waiting claim for token
            SubmarineClaim[] memory waitingClaim = waitingClaimForSubmarine[tokensId[i]];

            for(uint t = 0; t < waitingClaim.length; t++){

                if(waitingClaim[t].divingFinishTime <= block.timestamp){

                    uint256 amountToClaimBeforeTaxe = waitingClaim[t].claimAmount;
                    
                    uint256 _claimForKraken = (amountToClaimBeforeTaxe*TAX_VALUE)/100;
                    uint256 _claimForSubmarine = amountToClaimBeforeTaxe-_claimForKraken;

                    // Add claim to kraken waiting list
                    allKrakenClaim.push(KrakenClaim(
                        _claimForKraken,
                        totalKrakenStaked
                    ));

                    amountToClaim = amountToClaim + _claimForSubmarine;

                    delete waitingClaimForSubmarine[tokensId[i]][t];

                }

            }

        }

        if(amountToClaim > 0){
            // Transfer claim to sender address
            _pearl.transfer(msg.sender, amountToClaim);
        }else{
            revert("Nothing to claim");
        }

    }

    /**
    * Claim rewards for kraken
    * @param tokensId Array of token's id
    */
    function claimForKraken(uint256[] calldata tokensId) public noContract whenNotPaused nonReentrant returns(uint256[] memory failedClaimed){

        ClaimForKraken memory _claimForKraken = ClaimForKraken(0,0,0);

        uint256[] memory fClaimed;

        for(uint i = 0; i < tokensId.length; i++){
            require(_isStaked(tokensId[i]),"Cannot claim reward for unstaked token");
            require(_isKraken(tokensId[i]),"Cannot claim for submarine");
            require(_isStakeOwner(tokensId[i], msg.sender),"Token is not yours");
            require(!_isUpgrading(tokensId[i]),"Cannot claim while upgrading");

            uint256 lastIndex = allKrakenClaim.length;
            uint256 currentIndex = lastKrakenClaimIndex[tokensId[i]] == 0 ? 0 : lastKrakenClaimIndex[tokensId[i]] + 1;

            // Start with next index than last
            for(uint t = currentIndex; t < lastIndex; t++ ){

                KrakenClaim memory krakenClaim = allKrakenClaim[t];

                // Verify if claim is already available (diving time of linked submarine is finished)

                uint256 rand = _random(tokensId[i]) % 10;
                uint256 b = getRiskByKrakenLevel(_nautilusNFT.getNFT(tokensId[i]).level);

                // > 1 because rand generate number [0-9] so 20% is [0-1]
                if(rand > 1){
                    _claimForKraken.amountToClaim = _claimForKraken.amountToClaim + (krakenClaim.amount / krakenClaim.nbrOfKraken);                    
                }else{
                    uint256 amountForThisToken = (krakenClaim.amount/krakenClaim.nbrOfKraken);
                    uint256 burn = (amountForThisToken * b)/100;
                    
                    _claimForKraken.amountToClaim = _claimForKraken.amountToClaim + amountForThisToken - burn;
                    _claimForKraken.amountToBurn = _claimForKraken.amountToBurn + burn;

                    // Add id to token for which claim failed
                    fClaimed[_claimForKraken.index] = tokensId[i];
                    _claimForKraken.index += 1;
                }

                // Update last claim index with the new one
                lastKrakenClaimIndex[tokensId[i]] = t;

            }

        }

        if(_claimForKraken.amountToBurn > 0){
            _pearl.burn(address(this),_claimForKraken.amountToBurn);
        }

        if(_claimForKraken.amountToClaim > 0){
            _pearl.transfer(msg.sender, _claimForKraken.amountToClaim);
        }else{
            revert("Nothing to claim");
        }

        return fClaimed;

    }

    /* DIVING */

    /**
    * Allow diving for submarines
    * @param tokensId Array of token's id
    * @param divingsTime Array of diving time for each token
    *
    * Note: Diving time of tokensId[0] = divingsTime[0]
    */
    function dive(uint256[] calldata tokensId, uint256[] calldata divingsTime) public noContract whenNotPaused nonReentrant{
        uint256 fuelNeeded = getFuelsNeeded(tokensId,divingsTime);
        require(tokensId.length == divingsTime.length, "Too much or not enough arguments");
        require(_fuel.balanceOf(msg.sender) >= fuelNeeded, "Not enough fuel to dive");

        for(uint i = 0; i < tokensId.length; i++){
            require(_isStaked(tokensId[i]),"Cannot dive until token is not staked");
            require(_isStakeOwner(tokensId[i], msg.sender),"Token are not yours");
            require(_isSubmarine(tokensId[i]),"Kraken can't dive");
            require(!_isDiving(tokensId[i]),"Token is already diving");
            require(!_isUpgrading(tokensId[i]),"Cannot dive while token is upgrading");
            require(divingsTime[i] != 0, "Cannot dive for 0 hours");

            uint256 level = _nautilusNFT.getNFT(tokensId[i]).level;

            uint256 _claim = divingsTime[i] * getRewardBySubmarineLevel(level) * 1 ether;

            uint256 unlockDate = block.timestamp + (divingsTime[i] * (DIVING_TIME * 1 minutes));

            // Add claim to submarine waiting list
            waitingClaimForSubmarine[tokensId[i]].push(SubmarineClaim(
                block.timestamp,
                tokensId[i],
                _claim,
                unlockDate
            ));
            
            // Transfer claim (for krakens and submarine) to this address
            _pearl.transferTo(address(this), _claim);

            // Burn $FUEL used to dive
            _fuel.burn(msg.sender, fuelNeeded * 1 ether);
            
        }       

    }
    

    /* UPGRADE */


    /**
    * Allow upgrading a token to next level
    * @param tokensId Array of token's id
    */
    function upgrade(uint256[] calldata tokensId) public noContract whenNotPaused nonReentrant{

        uint256 amountpearlNeeded = getTotalPearlNeededForUpgrade(tokensId) * 1 ether;

        require(_pearl.balanceOf(msg.sender) >= amountpearlNeeded,"Not enought pearl to upgrade");
        require(amountpearlNeeded > 0,"Upgrade price equal to zero");

        for(uint i = 0; i < tokensId.length; i++){
            require(_isStaked(tokensId[i]),"Cannot upgrade until token is not staked");
            require(_isStakeOwner(tokensId[i], msg.sender),"Token are not yours");
            require(!_isUpgrading(tokensId[i]),"Token already upgrading");
            require(!_isDiving(tokensId[i]),"Cannot upgrade token while diving");

            _upgradeByType(tokensId[i],_nautilusNFT.getNFT(tokensId[i]).level + 1);
    
        }

        // Burn pearl from sender's account when upgrading
        _pearl.burn(msg.sender, amountpearlNeeded);

    }

    function _upgradeByType(uint256 tokenId, uint256 levelAfterUpgrade) internal{

        if(_isSubmarine(tokenId)){

            Upgrade[] memory upgrades = submarineUpgrades[tokenId];
            if(upgrades.length != 0){
                if(dateTime.getDay(upgrades[upgrades.length-1].upgradeFinishTime) != dateTime.getDay(block.timestamp)){
                    upgradesByDay[tokenId] = 0;
                }
            }

            if(upgradesByDay[tokenId] < MAX_UPGRADE_BY_DAY){

                 submarineUpgrades[tokenId].push(Upgrade(
                    block.timestamp,
                    tokenId,
                    levelAfterUpgrade,
                    block.timestamp + ( levelUpgradeTime[upgradesByDay[tokenId]] * 1 minutes ) 
                ));

                _nautilusNFT.upgrade(tokenId);

                upgradesByDay[tokenId] += 1;


            }else{
                revert("Cannot upgrade more than MAX_UPGRADE_BY_DAY by day");
            }

        }else{

            if(levelAfterUpgrade <= 10){

                krakenUpgrades[tokenId].push(Upgrade(
                    block.timestamp,
                    tokenId,
                    levelAfterUpgrade,
                    block.timestamp + ( UPGRADE_TIME * 1 minutes )
                ));

            _nautilusNFT.upgrade(tokenId);

            }else{
                revert("Cannot upgrade kraken greater than level 10");
            }

        }

    }


    /* UTILS */

    function uint2str(uint256 _i) internal pure returns (string memory str){
        if (_i == 0){
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0){
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0){
            bstr[--k] = bytes1(uint8(48 + j % 10));
            j /= 10;
        }
        str = string(bstr);
    }

    /**
    * Internal function allowing to add tokens from ocean
    * @param id Id of token
    * @param owner Owner of token
    */
    function _addTokenToOcean(uint256 id, address owner) internal{

        uint256 typeId = _nautilusNFT.getNFT(id).typeId;
        StackedNFT memory stacked = StackedNFT(id, owner);
        ocean[id] = stacked;

        addressToStaked[owner].push(id);
        addressToStackedArrayLength[owner] += 1;

        if(typeId == 0){
            totalSubmarineStaked += 1;
        }else{
            totalKrakenStaked += 1;
            lastKrakenClaimIndex[id] = allKrakenClaim.length;
        }

    }

    /**
    * Internal function allowing to remove tokens from ocean
    * @param id Id of token 
    */
    function _removeTokenFromOcean(uint256 id, address owner) internal{

        uint256 typeId = _nautilusNFT.getNFT(id).typeId;

        // delete from ocean
        delete ocean[id];

        // Remove element from stake create a gap. So move last element at gap index the remove last element
        uint256[] storage staked = addressToStaked[owner];
        for(uint i = 0; i < staked.length; i++){
            if(staked[i] == id){
                delete staked[i];
                staked[i] = staked[staked.length-1];
                staked.pop();
                break;
            }
        }

        // Synchronize counter
        addressToStackedArrayLength[owner] -= 1;

        if(typeId == 0){
            totalSubmarineStaked -= 1;
        }else{
            totalKrakenStaked -= 1;
        }

    }

    /**
    * Generate random number from `seed`
    */
    function _random(uint256 seed) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            tx.origin,
            blockhash(block.number - 1),
            block.timestamp,
            seed,
            totalSubmarineStaked,
            totalKrakenStaked
        )));
    }

    /**
    * Return the rewards for a submarine of `level`
    * @param level Level
    */
    function getRewardBySubmarineLevel(uint256 level) public view returns(uint256){
        require(level > 0,"Cannot compute for level 0");

        uint256 reward = SUBMARINE_REWARD_START * 100;
        if(level != 1){
            for(uint i = 1; i < level; i++){
                reward = reward + (reward*SUBMARINE_REWARD_COEF)/100 + SUBMARINE_FIXED_REWARD*100; 
            }
        }
        return reward/100;
    }

    /**
    * Return the amount of $FUEL to dive for a submarine of `level`
    * @param level Level
    */
    function getFuelByLevel(uint256 level) public view returns(uint256){
        require(level > 0,"Cannot compute for level 0");

        uint256 fuel = FUEL_START * 1000;
        if(level != 1){
            for(uint i = 1; i < level; i++){
                fuel = fuel * (1000+(FUEL_COEF*10))/1000; 
            }
        }
        return fuel/1000;
    }

    /**
    * Return the amount of $PEARL needed to upgrade kraken token to level `level`
    * @param level Level
    */
    function getPriceForSubmarineLevelUpgrade(uint256 level) public view returns(uint256){
        require(level > 1,"Cannot upgrade level to [0-1] ");

        uint256 pearl = SUBMARINE_UPGRADE_START * 100;
        if(level != 2){
            for(uint i = 2; i < level; i++){
                pearl = pearl + (pearl*SUBMARINE_UPGRADE_COEF)/100 + SUBMARINE_FIXED_UPGRADE*100;
            }
        }
        return pearl/100;
    }

    /**
    *  Return the amount of $PEARL needed to upgrade submarine token to level `level`
    * @param level Level
    */
    function getPriceForKrakenLevelUpgrade(uint256 level) public view returns(uint256){
        require(level >= 2,"Cannot upgrade level to [0-1] ");
        require(level <= 10);

        return krakenLevelUpgrade[level];
    }

    /**
    * 
    */
    function getRiskByKrakenLevel(uint256 level) public view returns(uint256){
        require(level > 0 ,"Kraken level cannot be lower than 1");
        require(level <= 10, "Kraken level cannot be greater than 10");
        return riskRateByKrakenLevel[level-1];
    }

    /**
    * Return the $FUEL amount needed to upgrade all tokens of `tokensId` to next level
    * @param tokensId Array of token's id
    */
    function getTotalPearlNeededForUpgrade(uint256[] calldata tokensId) public view returns(uint256){

        uint256 pearlAmountNeeded = 0;

        for(uint i = 0; i < tokensId.length; i++){

            uint256 nextLevel = _nautilusNFT.getNFT(tokensId[i]).level + 1;

            if(_isKraken(tokensId[i])){
                if(nextLevel <= 10){
                    pearlAmountNeeded = pearlAmountNeeded + getPriceForKrakenLevelUpgrade(nextLevel);
                }else{
                    revert("Cannot upgrade kraken greater than level 10");
                }
            }else{
                pearlAmountNeeded = pearlAmountNeeded + getPriceForSubmarineLevelUpgrade(nextLevel);
            }

        }

        return pearlAmountNeeded;

    }

    /**
    * Get $FUEL amount needed for diving of all tokens for all wanted times
    * @param tokensId Array of token's id
    * @param divingsTime Array of diving time for each token
    */
    function getFuelsNeeded(uint256[] calldata tokensId, uint256[] calldata divingsTime) public view returns(uint256){
        require(tokensId.length == divingsTime.length, "too much or not enough arguments");

        uint256 amountNeeded = 0;

        for(uint i = 0; i < tokensId.length; i++){

            uint256 level = _nautilusNFT.getNFT(tokensId[i]).level;
            amountNeeded = amountNeeded + ( getFuelByLevel(level) * divingsTime[i]);

        }

        return amountNeeded;

    }

    /**
    * Return remaiming time of the last dive of a token `id`
    * @param tokenId The token id
    */
    function getRemainingDivingTime(uint256 tokenId) public view returns(uint256){
        require(_isSubmarine(tokenId), "Kraken can dive");

        SubmarineClaim[] storage waitingClaim = waitingClaimForSubmarine[tokenId];
        return waitingClaim[waitingClaim.length-1].divingFinishTime;

    }

    /**
    * Return pending claim available for a kraken with token id `id`
    * @param tokenId The token id
    */
    function getPendingClaimForKraken(uint256 tokenId) public view returns(uint256){
        require(_isKraken(tokenId),"Cannot watch pending reward for submarine");

        uint256 lastIndex = allKrakenClaim.length;
        uint256 currentIndex = lastKrakenClaimIndex[tokenId] == 0 ? 0 : lastKrakenClaimIndex[tokenId] + 1;

        uint256 amountToClaim = 0;

        // Start with next index than last
        for(uint t = currentIndex; t < lastIndex; t++ ){

            KrakenClaim memory krakenClaim = allKrakenClaim[t];
            amountToClaim = amountToClaim + (krakenClaim.amount / krakenClaim.nbrOfKraken);                    

        }

        return amountToClaim;

    }

    /**
    * Return pending claim available for a submarine with token id `id`
    * @param tokenId The token id
    */
    function getPendingClaimForSubmarine(uint256 tokenId) public view returns(uint256){
        require(_isSubmarine(tokenId),"Cannot watch pending reward for kraken");

        uint256 amountToClaim = 0;

        // Get all waiting claim for token
        SubmarineClaim[] memory waitingClaim = waitingClaimForSubmarine[tokenId];

        for(uint t = 0; t < waitingClaim.length; t++){

            if(waitingClaim[t].divingFinishTime <= block.timestamp){

                uint256 amountToClaimBeforeTaxe = waitingClaim[t].claimAmount;
                
                uint256 _claimForKraken = amountToClaimBeforeTaxe / 5;
                uint256 _claimForSubmarine = _claimForKraken*4;

                amountToClaim = amountToClaim + _claimForSubmarine;

            }

        }

        return amountToClaim;

    }

    /**
    */
    function getLenghtOfUpgradeArray(uint256 tokenId) public view returns(uint256){

        if(_isSubmarine(tokenId)){
            return submarineUpgrades[tokenId].length;
        }else{
            return krakenUpgrades[tokenId].length;
        }

    }
    

    /* VERIFIERS */

    /**
    * Verify if `receiver` is owner of stacked NFT
    * @param id Id of token
    * @param receiver Address to check
    */
    function _isStakeOwner(uint256 id, address receiver) internal view returns(bool){
        return ocean[id].owner == receiver;
    }

    /**
    * Verify if token with `id` is stacked in Ocean
    * @param id Token id
    */
    function _isStaked(uint256 id) internal view returns(bool){
        return _nautilusNFT.ownerOf(id) == address(this);
    }

    /**
    * Return `true` is token is a submarine otherwise return `false`
    * @param id Id of token
    */
    function _isSubmarine(uint256 id) internal view returns(bool){
        return _nautilusNFT.getNFT(id).typeId == 0;
    }

    /**
    * Return `true` is token is a kraken otherwise return `false`
    * @param id Id of token
    */
    function _isKraken(uint256 id) internal view returns(bool){
        return _nautilusNFT.getNFT(id).typeId == 1;
    }

    /**
    * Return `true` if token is diving otherwise `false`
    * @param id Id of token
    */
    function _isDiving(uint256 id) public view returns(bool){
        bool ret = false;
        SubmarineClaim[] memory waitingClaim = waitingClaimForSubmarine[id];
        if(waitingClaim.length != 0){
            uint256 lastDiveFinishTime = waitingClaim[waitingClaim.length-1].divingFinishTime;
            ret = lastDiveFinishTime > block.timestamp;
        }
        return ret;
    }

    /**
    * Return `true` if token is upgrading otherwise `false`
    * @param id Id of token
    */
    function _isUpgrading(uint256 id) public view returns(bool){
        bool ret = false;
        Upgrade[] memory upgrades = _isKraken(id) ? krakenUpgrades[id] : submarineUpgrades[id];
        if(upgrades.length != 0){
            uint256 lastUpgradeFinishTime = upgrades[upgrades.length-1].upgradeFinishTime;
            ret = lastUpgradeFinishTime > block.timestamp;
        }
        return ret;
    }


    /** MODIFIERS */
    

    /**
    * 
    */
    modifier noContract{
        require(tx.origin == msg.sender, "Contracts not allowed");
        _;
    }

    /* SETTERS */

    // Pause contract 
    function setPause() public onlyOwner{
        _pause();
    }

    // Pause contract 
    function setUnPause() public onlyOwner{
        _unpause();
    }

    function setTaxValue(uint256 taxValue) public onlyOwner{
        TAX_VALUE = taxValue;
    }

    function setFuelAddress(address fuelAddress) public onlyOwner{
        _fuel = IFuel(fuelAddress);
    }

    function setPearlAddress(address pearlAddress) public onlyOwner{
        _pearl = IPearl(pearlAddress);
    }

    function setNautilusNFTAddress(address nautilusNFTAddress) public onlyOwner{
        _nautilusNFT = NautilusNFT(nautilusNFTAddress);
    }

    function setDivingTime(uint256 divingTime) public onlyOwner{
        DIVING_TIME = divingTime;
    }

    function setUpgradeTime(uint256 upgradeTime) public onlyOwner{
        UPGRADE_TIME = upgradeTime;
    }

    function setSubmarineUpgradeCoef(uint256 value) public onlyOwner{
        SUBMARINE_UPGRADE_COEF = value;
    }

    function setSubmarineFixedUpgrade(uint256 value) public onlyOwner{
        SUBMARINE_FIXED_UPGRADE = value;
    }

    function setSubmarineUpgradeStart(uint256 value) public onlyOwner{
        SUBMARINE_UPGRADE_START = value;
    }

    function setKrakenUpgradeCoef(uint256 value) public onlyOwner{
        KRAKEN_UPGRADE_COEF = value;
    }
    function setKrakenFixedUpgrade(uint256 value) public onlyOwner{
        KRAKEN_FIXED_UPGRADE = value;
    }

    function setKrakenUpgradeStart(uint256 value) public onlyOwner{
        KRAKEN_UPGRADE_START = value;
    }

    function setSubmarineRewardStart(uint256 value) public onlyOwner{
        SUBMARINE_REWARD_START = value;
    }

    function setSubmarineFixedReward(uint256 value) public onlyOwner{
        SUBMARINE_FIXED_REWARD = value;
    }

    function setSubmarineRewardCoef(uint256 value) public onlyOwner{
        SUBMARINE_REWARD_COEF = value;
    }

    function setFuelStart(uint256 value) public onlyOwner{
        FUEL_START = value;
    }

    function setFuelcoef(uint256 value) public onlyOwner{
        FUEL_COEF = value;
    }

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

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
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPearl is IERC20{

    function transferTo(address recipient, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function addController(address controller) external;
    function removeController(address controller) external;
    function setStartTime(uint256 startTime) external;
    function setTax(uint256 taxeRate) external;
    function addRouter(address addr) external;

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../Pearl/IPearl.sol";
import 'base64-sol/base64.sol';

struct TransactionData{
    address buyer;
    uint256 dateBought;
    uint256 amountBought;
}

struct NFT{
    uint256 tokenId;
    uint256 typeId;
    uint256 level;
}

/**
* The contract for Nautilus NFT sale 🌊
* This contract also includes withelist mechanisms 
*/
contract NautilusNFT is ERC721Enumerable, Ownable, ReentrancyGuard, Pausable{

    using Strings for uint256;

    event AddressWhitelisted(address _address);
    event AddressFreeMint(address _address);

    event PresaleStatusChange(bool status);
    event SaleStatusChange(bool status);

    event tokenFreeMinted(address minter, uint256 tokenId);
    event TokenMinted(address minter, uint256 tokenId);

    event SaleCollected();

    string public baseURI = "";

    // Maximum amount of token created
    uint256 public constant MAX_GEN0_SUPPLY = 6_500;

    // ADDRESS
    address payable public devAddress; // Adress of dev, this is a multisig
    IPearl public pearl; // Address of Pearl token

    // LIMITS
    uint256 public constant PRESALE_LIMIT = 4;
    uint256 public constant TOTAL_LIMIT = 30;
    uint256 public constant MAX_FREE_MINT = 10; // Maximum free mint for address

    bool public presaleStart = false;
    bool public saleStart = true;

    uint256 public presalePrice = 0;
    uint256 public salePrice = 0;

    // Duration of presale in hours
    uint256 public publicSaleDuration = 48;
    uint256 public publicSaleStartTime = 0;

    // The list of all address that claim sale if cancelled
    mapping(address => bool) public addressClaimed;

    // Address which are whitelisted
    mapping(address => bool) public isWhitelisted;

    // Limit of freemint for a given address
    mapping(address => uint256) public freeMintLimit;
    // Currently free mint value
    mapping(address => uint256) public freeMintCounter;

    // The list of all transactions
    TransactionData[] public transactions;

    // Returns the transactions for each address
    mapping(address => TransactionData[]) public transactionsForAddress;

    // Mapping tokenId to a NFT
    NFT[] public nfts;

    // Define two types name
    string[2] public types = ['SUBMARINE', 'KRAKEN'];

    // Address which are controller
    mapping(address => bool) public controllers;

    // Map token id to boolean respresent if token is from GEN 1 or not
    mapping(uint256 => bool) public isGen1;

    uint256 public _gen1TokenToSell = 0;
    uint256 public _gen1TokenSelled = 0;
    uint256 public _gen1Price = 0;
    bool public _gen1Started = false;
    uint256 public _gen1KrakenLevel;
    uint256 public _gen1SubmarineLevel; 

    constructor(
        address payable _devAddress,
        uint256 _presalePriceInWei,
        uint256 _salePriceInWei,
        address _pearlAddress) ERC721("Nautilus","NAUTILUS"){

        devAddress = _devAddress;
        presalePrice = _presalePriceInWei;
        salePrice = _salePriceInWei;
        pearl = IPearl(_pearlAddress);
        
    }

    // Mint a token
    function mint() public payable nonReentrant whenNotPaused{
        require(tx.origin == msg.sender, "Contracts not allowed");
        require(transactionsForAddress[msg.sender].length < TOTAL_LIMIT + MAX_FREE_MINT,"Cannot buy more than limit");
        require(totalSupply() + 1 <= MAX_GEN0_SUPPLY,"All has been purchased");

        _mintToken(msg.sender, msg.value, false);
        
    }

    function freeMint() public nonReentrant whenNotPaused{
        require(tx.origin == msg.sender, "Contracts not allowed");
        require(presaleStart || saleStart,"Sale is not open");
        require(freeMintLimit[msg.sender] > 0, "You are not freeminted");
        require(freeMintCounter[msg.sender] < freeMintLimit[msg.sender],"Cannot buy more than free mint limit");
        require(totalSupply() + 1 <= MAX_GEN0_SUPPLY,"All has been purchased");

        
        freeMintCounter[msg.sender] = freeMintCounter[msg.sender] + 1;
        _mintToken(msg.sender,0, false);

        emit tokenFreeMinted(msg.sender,totalSupply());

    }

    function _mintToken(address _minter, uint256 _amount, bool gen1) private{

        uint256 tokenId = totalSupply();

        // Getting random number
        uint256 rand = getRandom(tokenId);

        // Store transaction datas
        TransactionData memory transaction = TransactionData(_minter, block.timestamp, _amount);
        transactions.push(transaction);
        transactionsForAddress[_minter].push(transaction);

        uint256 typeId = getRandomType(rand);
        uint256 level = gen1 ? typeId == 0 ? _gen1SubmarineLevel : _gen1KrakenLevel : 1;

        // Store NFT Metadata
        nfts.push(NFT(tokenId,typeId,level));

        _safeMint(_minter, tokenId);

        emit TokenMinted(_minter,tokenId);

    }

    /**
    * Mint a token of GEN1
    */
    function mintGen1() public nonReentrant whenNotPaused{
        require(tx.origin == msg.sender, "Contracts not allowed");
        require(_gen1Started,"GEN1 not started");
        require(_gen1TokenSelled < _gen1TokenToSell,"GEN1 batch completed.");
        require(pearl.balanceOf(msg.sender) >= _gen1Price,"Not enough Pearl to mint GEN1");

        pearl.burn(msg.sender, _gen1Price);

        _gen1TokenSelled += 1;

        _mintToken(msg.sender, 1, true);

    }


    /* WHITELIST */


    //Withelist an given address, only callable by the owner
    function addWhitelistAddress(address _toWhitelist) public onlyOwner{

        isWhitelisted[_toWhitelist] = true;

        emit AddressWhitelisted(_toWhitelist);

    }

    // Whitelist all addresses
    function addAllWhitelist(address[] calldata _toWhitelist) public onlyOwner{

        for(uint256 i = 0; i < _toWhitelist.length; i++){
            addWhitelistAddress(_toWhitelist[i]);
        }

    }

    function removeWhitelist(address[] calldata _toRemove) public onlyOwner{
        for(uint i = 0; i < _toRemove.length; i++){
            isWhitelisted[_toRemove[i]] = false;
        }
    } 


    /* FREE MINT */


    // 
    function addFreeMint(address _toFreeMint, uint256 amount) public onlyOwner{
        freeMintLimit[_toFreeMint] = amount;

        emit AddressFreeMint(_toFreeMint);
    }

    function addAllFreeMint(address[] calldata _toFreeMint, uint256[] calldata amount) public onlyOwner{
        for(uint256 i = 0; i < _toFreeMint.length; i++){
            addFreeMint(_toFreeMint[i], amount[i]);
        }
    }

    function removeFreeMint(address[] calldata _toRemove) public onlyOwner{
        for(uint256 i = 0; i < _toRemove.length; i++){
            freeMintLimit[_toRemove[i]] = 0;
            freeMintCounter[_toRemove[i]] = 0;
        }
    }


    /* CLAIM SALE */


    // Collects sale's funds. Only callable by the owner
    function collectSale(uint256 amount) public onlyOwner{
        require(address(this).balance >= amount, 'Balancer lower than amount');

        // Transfer the sale funds
        devAddress.transfer(amount);

        emit SaleCollected();
    }

    // Transfer funds
    function transferFunds(uint _amount, address _receiver) public onlyOwner{
        payable(_receiver).transfer(_amount);
    }
    

    /* REFUND  */


    // Allows user to claim their tokens if sale is cancelled
    function claimRefund() public nonReentrant whenPaused{
        require(tx.origin == msg.sender, "Contracts not allowed");
        require(!addressClaimed[msg.sender],"Address already claim sale or never participated");

        addressClaimed[msg.sender] = true;

        uint256 totalBought = 0;
        uint256 bought = transactionsForAddress[msg.sender].length;

        for(uint256 i = 0; i < bought; i++){
            totalBought += transactionsForAddress[msg.sender][i].amountBought;
        }

        payable(msg.sender).transfer(totalBought);
        
    }


    /* SETTERS */


    // Allows to set the base URI
    function setBaseURI(string calldata _URI) public onlyOwner{
        baseURI = _URI;
    }

    // Return the base URI
    function _baseURI() internal view override(ERC721) returns (string memory) {
        return baseURI;
    }

    // Toggle the presale state
    function togglePresale() public onlyOwner{
        presaleStart = !presaleStart;
        emit PresaleStatusChange(presaleStart);
    }

    // Toggle the main sale state
    function toggleSale() public onlyOwner{
        saleStart = !saleStart;
        publicSaleStartTime = block.timestamp;
        emit SaleStatusChange(saleStart);
    }

    // Pause contract 
    function setPause() public onlyOwner{
        _pause();
    }

    // Pause contract 
    function setUnPause() public onlyOwner{
        _unpause();
    }

    // Set parameters for GEN1
    function setGen1(
        uint256 gen1TokenToSell,
        uint256 gen1Price,
        uint256 gen1KrakenLevel,
        uint256 gen1SubmarineLevel
    ) public onlyOwner{
        
        _gen1TokenToSell = gen1TokenToSell;
        _gen1Price = gen1Price;

        _gen1Started = false;
        _gen1TokenSelled = 0;

        _gen1KrakenLevel = gen1KrakenLevel;
        _gen1SubmarineLevel = gen1SubmarineLevel;
        
    }

    // Set duration of public sale in hours
    function setPublicSaleDuration(uint256 durationInHours) public onlyOwner{
        publicSaleDuration = durationInHours;
    }

    function setPresalePriceInWei(uint256 price) public onlyOwner{
        presalePrice = price;
    }

    function setSalePriceInWei(uint256 price) public onlyOwner{
        salePrice = price;
    }

    function setDevAddress(address devAddr) public onlyOwner{
        devAddress = payable(devAddr);
    }

    /* OVERRIDES */


    function tokenURI(uint256 _tokenId) public view override(ERC721) returns (string memory) {
        require(_exists(_tokenId),"Token not minted yet");

        NFT memory nft = nfts[_tokenId];

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{',
                                '"name": "', types[nft.typeId], ' #', uint2str(_tokenId),'",',
                                '"description": "Dive deep into the ocean... ",',
                                '"attributes": [',
                                    getAttributes(nft),
                                '],',
                                '"image": "', getImage(nft),'"',
                            '}'
                        )
                    )
                )
            )
        );

    } 


    /* UTILS */


    function getNumberOfTransactionByAddress(address _address) public view returns(uint256){

        uint256 nbrTransactions = 0;
        
        while(true){
            TransactionData memory transaction = transactionsForAddress[_address][nbrTransactions];
            
            if(transaction.dateBought != 0){
                nbrTransactions += 1;
            }else{
                break;
            }
        }

        return nbrTransactions;

    }

    function getImage(NFT memory nft) public view returns(string memory){

        string memory url = "";
        uint256 level = nft.level;

        if(nft.typeId == 0){
            if(level >= 1 && level <= 9){
                url = "SUBMARINE_1.png";
            }
            if(level >= 10 && level <= 19){
                url =  "SUBMARINE_2.png";
            }
            if(level > 19){
                url =  "SUBMARINE_3.png";
            }
        }

        if(nft.typeId == 1){
            if(level >= 1 && level <= 2){
                url =  "KRAKEN_1.png";
            }
            if(level >= 3 && level <= 5){
                url =  "KRAKEN_2.png";
            }
            if(level >= 6 && level <= 8){
                url =  "KRAKEN_3.png";
            }
            if(level >= 9 && level <= 10){
                url =  "KRAKEN_4.png";
            }
        }

        return string(
                abi.encodePacked(
                    baseURI,
                    url
                )
            );

    }

    function getRandom(uint256 _seed) internal view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    blockhash(block.number + 4),
                    tx.origin,
                    blockhash(block.number + 2),
                    blockhash(block.number + 3),
                    blockhash(block.number + 1),
                    _seed,
                    block.timestamp
                )
            )
        );
    }

    function uint2str(uint256 _i) internal pure returns (string memory str){
        if (_i == 0){
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0){
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0){
            bstr[--k] = bytes1(uint8(48 + j % 10));
            j /= 10;
        }
        str = string(bstr);
    }

    function getRandomType(uint256 _seed) internal pure returns (uint256){

        // Generate number between 0 and 9

        if(uint256(uint256(keccak256(abi.encode(_seed, 5))) % 10) == 0){
            // 10% luck, 1 = KRAKEN
            return 1; 
        }else{
            // 90% luck, 0 = SUBMARINE
            return 0;
        }
    }

    function getAttributes(NFT memory nft) internal view returns (string memory){
        return string(
            abi.encodePacked(
                '{"trait_type": "Level",','"value": ', uint2str(nft.level),'},',
                '{"trait_type": "Type",','"value": "', types[nft.typeId],'"}'
            )
        );
    }

    function getNFT(uint id) public view returns (NFT memory){
        return nfts[id];
    }

    function toggleGen1() public onlyOwner{
        _gen1Started = !_gen1Started;
    }

    function getTransactionsForAddress(address addr) public view returns(uint256){
        return transactionsForAddress[addr].length;
    } 


    /* UPGRADES */


    /**
    * Allow upgrading a level with his `tokenId`
    * @param tokenId The token to upgrade
    */
    function upgrade(uint256 tokenId) public {
         require(controllers[msg.sender], "Only controllers can upgrade");

         NFT storage nft = nfts[tokenId];
         nft.level = nft.level + 1;

    }


    /* CONTROLLERS */


    /**
    * enables an address to upgrade
    */
    function addController(address controller) public onlyOwner {
        controllers[controller] = true;
    }

    /**
    * disables an address from upgrade
    */
    function removeController(address controller) public onlyOwner {
        controllers[controller] = false;
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface IFuel is IERC20{

    function mintStart(address receiver) external;
    function burn(address _from, uint256 _amount) external;
    function setExchangeFees(uint256 _exchangeRate) external;
    function addController(address controller) external;
    function removeController(address controller) external;

}

pragma solidity ^0.8.10;

contract DateTime {
        /*
         *  Date and Time utilities for ethereum contracts
         *
         */
        struct _DateTime {
                uint16 year;
                uint8 month;
                uint8 day;
                uint8 hour;
                uint8 minute;
                uint8 second;
                uint8 weekday;
        }

        uint constant DAY_IN_SECONDS = 86400;
        uint constant YEAR_IN_SECONDS = 31536000;
        uint constant LEAP_YEAR_IN_SECONDS = 31622400;

        uint constant HOUR_IN_SECONDS = 3600;
        uint constant MINUTE_IN_SECONDS = 60;

        uint16 constant ORIGIN_YEAR = 1970;

        function isLeapYear(uint16 year) public pure returns (bool) {
                if (year % 4 != 0) {
                        return false;
                }
                if (year % 100 != 0) {
                        return true;
                }
                if (year % 400 != 0) {
                        return false;
                }
                return true;
        }

        function leapYearsBefore(uint year) public pure returns (uint) {
                year -= 1;
                return year / 4 - year / 100 + year / 400;
        }

        function getDaysInMonth(uint8 month, uint16 year) public pure returns (uint8) {
                if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
                        return 31;
                }
                else if (month == 4 || month == 6 || month == 9 || month == 11) {
                        return 30;
                }
                else if (isLeapYear(year)) {
                        return 29;
                }
                else {
                        return 28;
                }
        }

        function parseTimestamp(uint timestamp) public pure returns (_DateTime memory dt) {
                uint secondsAccountedFor = 0;
                uint buf;
                uint8 i;

                // Year
                dt.year = getYear(timestamp);
                buf = leapYearsBefore(dt.year) - leapYearsBefore(ORIGIN_YEAR);

                secondsAccountedFor += LEAP_YEAR_IN_SECONDS * buf;
                secondsAccountedFor += YEAR_IN_SECONDS * (dt.year - ORIGIN_YEAR - buf);

                // Month
                uint secondsInMonth;
                for (i = 1; i <= 12; i++) {
                        secondsInMonth = DAY_IN_SECONDS * getDaysInMonth(i, dt.year);
                        if (secondsInMonth + secondsAccountedFor > timestamp) {
                                dt.month = i;
                                break;
                        }
                        secondsAccountedFor += secondsInMonth;
                }

                // Day
                for (i = 1; i <= getDaysInMonth(dt.month, dt.year); i++) {
                        if (DAY_IN_SECONDS + secondsAccountedFor > timestamp) {
                                dt.day = i;
                                break;
                        }
                        secondsAccountedFor += DAY_IN_SECONDS;
                }

                // Hour
                dt.hour = getHour(timestamp);

                // Minute
                dt.minute = getMinute(timestamp);

                // Second
                dt.second = getSecond(timestamp);

                // Day of week.
                dt.weekday = getWeekday(timestamp);
        }

        function getYear(uint timestamp) public pure returns (uint16) {
                uint secondsAccountedFor = 0;
                uint16 year;
                uint numLeapYears;

                // Year
                year = uint16(ORIGIN_YEAR + timestamp / YEAR_IN_SECONDS);
                numLeapYears = leapYearsBefore(year) - leapYearsBefore(ORIGIN_YEAR);

                secondsAccountedFor += LEAP_YEAR_IN_SECONDS * numLeapYears;
                secondsAccountedFor += YEAR_IN_SECONDS * (year - ORIGIN_YEAR - numLeapYears);

                while (secondsAccountedFor > timestamp) {
                        if (isLeapYear(uint16(year - 1))) {
                                secondsAccountedFor -= LEAP_YEAR_IN_SECONDS;
                        }
                        else {
                                secondsAccountedFor -= YEAR_IN_SECONDS;
                        }
                        year -= 1;
                }
                return year;
        }

        function getMonth(uint timestamp) public pure returns (uint8) {
                return parseTimestamp(timestamp).month;
        }

        function getDay(uint timestamp) public pure returns (uint8) {
                return parseTimestamp(timestamp).day;
        }

        function getHour(uint timestamp) public pure returns (uint8) {
                return uint8((timestamp / 60 / 60) % 24);
        }

        function getMinute(uint timestamp) public pure returns (uint8) {
                return uint8((timestamp / 60) % 60);
        }

        function getSecond(uint timestamp) public pure returns (uint8) {
                return uint8(timestamp % 60);
        }

        function getWeekday(uint timestamp) public pure returns (uint8) {
                return uint8((timestamp / DAY_IN_SECONDS + 4) % 7);
        }

        function toTimestamp(uint16 year, uint8 month, uint8 day) public pure returns (uint timestamp) {
                return toTimestamp(year, month, day, 0, 0, 0);
        }

        function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour) public pure returns (uint timestamp) {
                return toTimestamp(year, month, day, hour, 0, 0);
        }

        function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute) public pure returns (uint timestamp) {
                return toTimestamp(year, month, day, hour, minute, 0);
        }

        function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute, uint8 second) public pure returns (uint timestamp) {
                uint16 i;

                // Year
                for (i = ORIGIN_YEAR; i < year; i++) {
                        if (isLeapYear(i)) {
                                timestamp += LEAP_YEAR_IN_SECONDS;
                        }
                        else {
                                timestamp += YEAR_IN_SECONDS;
                        }
                }

                // Month
                uint8[12] memory monthDayCounts;
                monthDayCounts[0] = 31;
                if (isLeapYear(year)) {
                        monthDayCounts[1] = 29;
                }
                else {
                        monthDayCounts[1] = 28;
                }
                monthDayCounts[2] = 31;
                monthDayCounts[3] = 30;
                monthDayCounts[4] = 31;
                monthDayCounts[5] = 30;
                monthDayCounts[6] = 31;
                monthDayCounts[7] = 31;
                monthDayCounts[8] = 30;
                monthDayCounts[9] = 31;
                monthDayCounts[10] = 30;
                monthDayCounts[11] = 31;

                for (i = 1; i < month; i++) {
                        timestamp += DAY_IN_SECONDS * monthDayCounts[i - 1];
                }

                // Day
                timestamp += DAY_IN_SECONDS * (day - 1);

                // Hour
                timestamp += HOUR_IN_SECONDS * (hour);

                // Minute
                timestamp += MINUTE_IN_SECONDS * (minute);

                // Second
                timestamp += second;

                return timestamp;
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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

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
    function transferFrom(
        address sender,
        address recipient,
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
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/ERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "./IERC721Enumerable.sol";

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

/// @title Base64
/// @author Brecht Devos - <[email protected]>
/// @notice Provides functions for encoding/decoding base64
library Base64 {
    string internal constant TABLE_ENCODE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    bytes  internal constant TABLE_DECODE = hex"0000000000000000000000000000000000000000000000000000000000000000"
                                            hex"00000000000000000000003e0000003f3435363738393a3b3c3d000000000000"
                                            hex"00000102030405060708090a0b0c0d0e0f101112131415161718190000000000"
                                            hex"001a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132330000000000";

    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return '';

        // load the table into memory
        string memory table = TABLE_ENCODE;

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
            // set the actual output length
            mstore(result, encodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 3 bytes at a time
            for {} lt(dataPtr, endPtr) {}
            {
                // read 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // write 4 characters
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr( 6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(        input,  0x3F))))
                resultPtr := add(resultPtr, 1)
            }

            // padding with '='
            switch mod(mload(data), 3)
            case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
            case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
        }

        return result;
    }

    function decode(string memory _data) internal pure returns (bytes memory) {
        bytes memory data = bytes(_data);

        if (data.length == 0) return new bytes(0);
        require(data.length % 4 == 0, "invalid base64 decoder input");

        // load the table into memory
        bytes memory table = TABLE_DECODE;

        // every 4 characters represent 3 bytes
        uint256 decodedLen = (data.length / 4) * 3;

        // add some extra buffer at the end required for the writing
        bytes memory result = new bytes(decodedLen + 32);

        assembly {
            // padding with '='
            let lastBytes := mload(add(data, mload(data)))
            if eq(and(lastBytes, 0xFF), 0x3d) {
                decodedLen := sub(decodedLen, 1)
                if eq(and(lastBytes, 0xFFFF), 0x3d3d) {
                    decodedLen := sub(decodedLen, 1)
                }
            }

            // set the actual output length
            mstore(result, decodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 4 characters at a time
            for {} lt(dataPtr, endPtr) {}
            {
               // read 4 characters
               dataPtr := add(dataPtr, 4)
               let input := mload(dataPtr)

               // write 3 bytes
               let output := add(
                   add(
                       shl(18, and(mload(add(tablePtr, and(shr(24, input), 0xFF))), 0xFF)),
                       shl(12, and(mload(add(tablePtr, and(shr(16, input), 0xFF))), 0xFF))),
                   add(
                       shl( 6, and(mload(add(tablePtr, and(shr( 8, input), 0xFF))), 0xFF)),
                               and(mload(add(tablePtr, and(        input , 0xFF))), 0xFF)
                    )
                )
                mstore(resultPtr, shl(232, output))
                resultPtr := add(resultPtr, 3)
            }
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

pragma solidity ^0.8.0;

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
        assembly {
            size := extcodesize(account)
        }
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