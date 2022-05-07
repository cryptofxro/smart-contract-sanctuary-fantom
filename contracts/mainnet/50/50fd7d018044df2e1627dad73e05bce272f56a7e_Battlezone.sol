// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >0.8.0;

/**
 *__/\\\______________/\\\_____/\\\\\\\\\_______/\\\\\\\\\______/\\\\\\\\\\\\\___
 * _\/\\\_____________\/\\\___/\\\\\\\\\\\\\___/\\\///////\\\___\/\\\/////////\\\_
 *  _\/\\\_____________\/\\\__/\\\/////////\\\_\/\\\_____\/\\\___\/\\\_______\/\\\_
 *   _\//\\\____/\\\____/\\\__\/\\\_______\/\\\_\/\\\\\\\\\\\/____\/\\\\\\\\\\\\\/__
 *    __\//\\\__/\\\\\__/\\\___\/\\\\\\\\\\\\\\\_\/\\\//////\\\____\/\\\/////////____
 *     ___\//\\\/\\\/\\\/\\\____\/\\\/////////\\\_\/\\\____\//\\\___\/\\\_____________
 *      ____\//\\\\\\//\\\\\_____\/\\\_______\/\\\_\/\\\_____\//\\\__\/\\\_____________
 *       _____\//\\\__\//\\\______\/\\\_______\/\\\_\/\\\______\//\\\_\/\\\_____________
 *        ______\///____\///_______\///________\///__\///________\///__\///______________
 **/

// @openzeppelin
import '@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';

// helpers
import './helpers/WarpBase.sol';
import './helpers/SafeERC20Upgradeable.sol';

// interfaces
import './interfaces/IRandomSelector.sol';
import './interfaces/IStarshipControl.sol';
import './interfaces/IStarship.sol';
import './interfaces/IBattlezone.sol';
import './interfaces/ITreasury.sol';

contract Battlezone is IBattlezone, WarpBase, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    event AddStarship(address indexed from, uint256 indexed shipId, uint256 bid, BattleShip ship);
    event RemoveStarship(
        address indexed from,
        uint256 indexed shipId,
        uint256 bid,
        BattleShip ship
    );
    event FireShot(
        uint256 fromStarship,
        uint256 toStarship,
        uint256 firePower,
        uint256 hitPart,
        uint256 shieldOnPart
    );
    event CallWinner(
        address winner,
        address loser,
        uint256 winnerShipId,
        uint256 loserShipId,
        uint256 partDmg,
        uint256 earnings,
        uint256 timestamp,
        uint256 attackerStrengthLeft,
        uint256 defenderStrengthLeft
    );

    struct BattleData {
        BattleShip battlezoneInfo;
        Ship shipInfo;
        uint256 id;
    }

    /* ======== Variables ======== */
    uint256 minBidFactor;
    address starships;
    address starshipControl;
    address growth;
    address randomSelector;
    address bidToken;
    address treasury;

    mapping(uint256 => BattleShip) public battleStarships;
    EnumerableSetUpgradeable.UintSet starshipsList;

    /**
     * @notice Checks if the msg.sender is a contract or a proxy
     */
    modifier notContract() {
        require(!_isContract(msg.sender), 'contract not allowed');
        require(msg.sender == tx.origin, 'proxy contract not allowed');
        _;
    }

    /** ======== Init ======== */
    function initialize(
        address _growth,
        address _bidToken,
        address _treasury,
        address _starships,
        address _starshipControl,
        address _randomSelector
    ) public initializer {
        __WarpBase_init(); // also inits ownable
        __ReentrancyGuard_init();

        minBidFactor = 1e18; //not used

        starships = _starships;
        starshipControl = _starshipControl;
        bidToken = _bidToken;
        treasury = _treasury;
        growth = _growth;
        randomSelector = _randomSelector;
    }

    /** @dev 
    list starship for battle
    since we want battleBid to be a multiple of 10, we multiply this value by 10. Ex: to bid 10 DAI, the _battleBid needs to be 1.
    @param _starshipId {uint256}
    @param _battleBid {uint256}
    */
    function addStarship(uint256 _starshipId, uint256 _battleBid) external notContract {
        Ship memory shipInfo = IStarshipControl(starshipControl).getShip(_starshipId);
        BattleShip storage defender = battleStarships[_starshipId];

        require(defender.openForBattle == 0, 'Starship is already on the battlefield');
        require(IStarship(starships).ownerOf(_starshipId) == msg.sender, 'Not owner of starship!');
        require(
            !IStarshipControl(starshipControl).isDamaged(_starshipId),
            'Starship is damaged, needs repairs!'
        );

        uint256 usdBattleBid = ITreasury(treasury).valueOf(bidToken, _battleBid); //calculate the value of warp in DAI

        require(usdBattleBid >= 10 * 1e9, 'Battle bid must over 10'); //must bid a minimum of 10 DAI worth of WARP

        defender.hullIntegrity = shipInfo.hullIntegrity - shipInfo.hullDmg;
        defender.bridgeIntegrity = shipInfo.bridgeIntegrity - shipInfo.bridgeDmg;
        defender.engineIntegrity = shipInfo.engineIntegrity - shipInfo.engineDmg;
        defender.strength = defender.hullIntegrity + defender.bridgeIntegrity;
        defender.battleBid = _battleBid;
        defender.openForBattle = 1;

        //add to list and transfer dai from defender.
        starshipsList.add(_starshipId); //add to Starships List
        IERC20(bidToken).safeTransferFrom(msg.sender, address(this), defender.battleBid); //pay the battle bid

        //to do: emit event
        emit AddStarship(msg.sender, _starshipId, _battleBid, battleStarships[_starshipId]);
    }

    /** @dev remove starship from battle - don't want to fight anymore?
    @param _starshipId {uint256}
    */
    function emergencyRemoveStarship(uint256 _starshipId)
        external
        nonReentrant
        notContract
        onlyOwner
    {
        BattleShip storage defender = battleStarships[_starshipId];

        require(
            defender.openForBattle == 1,
            'Starship is not on the battlefield or it is engaged in a fight'
        );
        address owner = IStarship(starships).ownerOf(_starshipId);

        // Remove necessary information
        starshipsList.remove(_starshipId); //remove from Starships List
        IERC20(bidToken).safeTransfer(owner, defender.battleBid); //pay back the battle bid

        //to do: emit event
        emit RemoveStarship(owner, _starshipId, defender.battleBid, defender);

        // Update the defender
        defender.battleBid = 0;
        defender.openForBattle = 0;
    }

    /** @dev remove starship from battle - don't want to fight anymore?
    @param _starshipId {uint256}
    */
    function removeStarship(uint256 _starshipId) external nonReentrant notContract {
        BattleShip storage defender = battleStarships[_starshipId];

        require(
            defender.openForBattle == 1,
            'Starship is not on the battlefield or it is engaged in a fight'
        );
        require(IStarship(starships).ownerOf(_starshipId) == msg.sender, 'Not owner of starship!');

        // Remove necessary information
        starshipsList.remove(_starshipId); //remove from Starships List
        IERC20(bidToken).safeTransfer(msg.sender, defender.battleBid); //pay back the battle bid

        //to do: emit event
        emit RemoveStarship(msg.sender, _starshipId, defender.battleBid, defender);

        // Update the defender
        defender.battleBid = 0;
        defender.openForBattle = 0;
    }

    /** ====== ================= ===== */
    /** ====== BATTLE ENGAGEMENT ===== */
    /** ====== ================= ===== */

    /** @dev engage in battle - simple battle
    @param _starshipId {uint256}
    @param _opponentStarshipId {uint256}
    */
    function engageInBattle(uint256 _starshipId, uint256 _opponentStarshipId)
        external
        nonReentrant
        notContract
    {
        require(
            battleStarships[_starshipId].openForBattle == 0,
            'Starship is already on the battlefield, please remove to fight'
        );
        require(IStarship(starships).ownerOf(_starshipId) == msg.sender, 'Not owner of starship!');
        require(
            !IStarshipControl(starshipControl).isDamaged(_starshipId),
            'Starship is damaged, needs repairs!'
        );
        require(
            battleStarships[_opponentStarshipId].openForBattle == 1,
            'You cannot fight a starship not open for battle'
        );

        //** Take battle bid from attack */
        uint256 battleBid = battleStarships[_opponentStarshipId].battleBid;
        IERC20(bidToken).safeTransferFrom(msg.sender, address(this), battleBid); //pay the battle bid

        //** Obtain attacker power information */
        Ship memory ship = IStarshipControl(starshipControl).getShip(_starshipId);
        uint256 strength = ship.hullIntegrity +
            ship.bridgeIntegrity -
            ship.hullDmg -
            ship.bridgeDmg; //calculate current battle strength for starship

        require(
            strength <= battleStarships[_opponentStarshipId].strength,
            'You cannot fight a less powerful starship'
        );

        uint256 firePower = getFirePower(strength, false);

        //** Obtain defender power information */
        uint256 opponentFirePower = getFirePower(
            battleStarships[_opponentStarshipId].strength,
            false
        );

        //oponent receives 2% extra firepower for listing the starship first
        opponentFirePower = (opponentFirePower * 110) / 100;

        //starship fires first shot, if firepower is higher than opponent strength than it won the battle
        bool haveWinner;
        if (firePower > battleStarships[_opponentStarshipId].strength) {
            //call starship as winner
            haveWinner = true;
            callWinner(_starshipId, _opponentStarshipId, battleBid, true, strength, 0); //true if starship won
            emit FireShot(_starshipId, _opponentStarshipId, firePower, 3, 3);
        }
        //opponent fires shot if it wasn't already defeated
        else if ((opponentFirePower > strength) && (!haveWinner)) {
            //call opponent as winner
            haveWinner = true;
            callWinner(
                _starshipId,
                _opponentStarshipId,
                battleBid,
                false,
                0,
                battleStarships[_opponentStarshipId].strength
            ); //false if opponent won
            emit FireShot(_opponentStarshipId, _starshipId, opponentFirePower, 3, 3);
        }
        //if both starships fired shots and none already won we calculate damages to determine the winner
        if (!haveWinner) {
            uint256 attackerStrengthLeft = strength - opponentFirePower;
            uint256 defenderStrengthLeft = battleStarships[_opponentStarshipId].strength -
                firePower;
            emit FireShot(_starshipId, _opponentStarshipId, firePower, 3, 3);
            emit FireShot(_opponentStarshipId, _starshipId, opponentFirePower, 3, 3);
            if (attackerStrengthLeft > defenderStrengthLeft) {
                //call starship as winner
                callWinner(
                    _starshipId,
                    _opponentStarshipId,
                    battleBid,
                    true,
                    attackerStrengthLeft,
                    defenderStrengthLeft
                );
            } else {
                //call opponent as winner
                callWinner(
                    _starshipId,
                    _opponentStarshipId,
                    battleBid,
                    false,
                    attackerStrengthLeft,
                    defenderStrengthLeft
                );
            }
        }
    }

    /** @dev engage in battle advanced - advanced battle
    @param _starshipId {uint256}
    @param _opponentStarshipId {uint256}
    @param _fireAtPart {uint256}
    @param _shieldOnPart {uint256}
    */
    function engageInBattleAdvanced(
        uint256 _starshipId,
        uint256 _opponentStarshipId,
        uint256 _fireAtPart,
        uint256 _shieldOnPart
    ) external nonReentrant notContract {
        BattleShip storage attacker = battleStarships[_starshipId];
        BattleShip storage defender = battleStarships[_opponentStarshipId];

        require(
            attacker.openForBattle != 1,
            'Starship is already on the battlefield, please remove to fight'
        ); //starship must not be open for battle
        require(IStarship(starships).ownerOf(_starshipId) == msg.sender, 'Not owner of starship!');
        require(
            !IStarshipControl(starshipControl).isDamaged(_starshipId),
            'Starship is damaged, needs repairs!'
        );
        require(
            (defender.openForBattle == 1) || (attacker.inFightWith == _opponentStarshipId),
            'You cannot fight a starship not open for battle'
        ); //can fight just open starships or the starship you are already engaged in battle with

        if (attacker.inFightWith != 0) {
            require(
                attacker.inFightWith == _opponentStarshipId,
                'You are already engaged in battle with another starship. Finish battle!'
            ); //you cannot engage in a fight with another starship while engaged in another battle
        }

        //check if it's first shot or consecutive shots.
        if (attacker.inFightWith == 0) {
            //it means it is the first shot, so we need to pay the battle bid and set all the initial data

            IERC20(bidToken).safeTransferFrom(msg.sender, address(this), defender.battleBid); //pay the battle bid
            //update opponent info
            defender.inFightWith = _starshipId; //let the opponent know they are in fight with _starshipId
            defender.lastHitTime = block.timestamp;
            defender.openForBattle = 2; //opponent is engaged in battle

            //update starship info
            Ship memory asInfo = IStarshipControl(starshipControl).getShip(_starshipId);
            attacker.hullIntegrity = asInfo.hullIntegrity - asInfo.hullDmg;
            attacker.bridgeIntegrity = asInfo.bridgeIntegrity - asInfo.bridgeDmg;
            attacker.engineIntegrity = asInfo.engineIntegrity - asInfo.engineDmg;
            attacker.strength = attacker.hullIntegrity + attacker.bridgeIntegrity;
            require(
                attacker.strength <= defender.strength,
                'You cannot fight a less powerful starship'
            );
            attacker.battleBid = defender.battleBid;
            attacker.inFightWith = _opponentStarshipId; //let the opponent know they are in fight with _starshipId
            attacker.lastHitTime = block.timestamp;
            attacker.openForBattle = 2; //starship is engaged in battle
            attacker.attacker = true; //make sure only the attacker can fire second shots to the opponent starship
            starshipsList.add(_starshipId);

            //fire a shot
            fireShot(_starshipId, _opponentStarshipId, _fireAtPart, _shieldOnPart);
        } else {
            //it is a second shot
            require(attacker.attacker, 'Cannot fire as you are not the attacker!'); //make sure only the attacker can fire at the other ship
            defender.lastHitTime = block.timestamp;

            //fire a shot
            fireShot(_starshipId, _opponentStarshipId, _fireAtPart, _shieldOnPart);
        }
    }

    /** ======== =========== ======= */
    /** ======== SHOTS FIRED ======= */
    /** ======== =========== ======= */

    function fireShot(
        uint256 _starshipId,
        uint256 _opponentStarshipId,
        uint256 _fireAtPart,
        uint256 _shieldOnPart
    ) internal {
        uint256 firePower = getFirePower(battleStarships[_starshipId].strength, true); //set to true for advanced battle - different fire power percentage
        uint256 opponentFirePower = getFirePower(
            battleStarships[_opponentStarshipId].strength,
            true
        );

        //oponent receives 2% extra firepower for listing the starship first
        opponentFirePower = (opponentFirePower * 110) / 100;

        //the starship with the faster engine has better evasive skills, taking 10% less damage
        if (
            battleStarships[_starshipId].engineIntegrity >
            battleStarships[_opponentStarshipId].engineIntegrity
        ) {
            opponentFirePower = (opponentFirePower * 90) / 100;
        } else {
            firePower = (firePower * 90) / 100;
        }

        //determine where is the opponent shield at
        uint256 opponentShieldOnPart = get1of(10); //80% of the time shield will be on weakest part
        if (opponentShieldOnPart >= 3) {
            opponentShieldOnPart = getWeakestPart(_opponentStarshipId);
        }
        //starship fires at _fireAtPart, did it hit or miss that part - 50% chance to hit intended part
        //what part did it hit? 3 and 4 are hits, 6 is a miss
        uint256 hitPart = get1of(6);
        if ((hitPart == 3) || (hitPart == 4)) {
            hitPart = _fireAtPart;
        }

        //check if the hit part was protected by a shield. shield absorves 50% of the damage
        if (opponentShieldOnPart == hitPart) {
            firePower = firePower / 2;
        }

        emit FireShot(_starshipId, _opponentStarshipId, firePower, hitPart, opponentShieldOnPart);
        //battleStarships[_starshipId].totalFirePower += firePower;

        //verify if the hit distroyed the starship part
        if (isWinningShot(_opponentStarshipId, hitPart, firePower)) {
            //emit battlelog first

            //call winner
            callWinner(
                _starshipId,
                _opponentStarshipId,
                battleStarships[_starshipId].battleBid,
                true,
                battleStarships[_starshipId].strength,
                battleStarships[_opponentStarshipId].strength
            );
        } else {
            //time for the opponent to fire back
            //50% of the time it will hit the weekest part, 16% - 16 the other parts and 16% miss. Same odds as the user
            //check what part the opponent actually hit
            uint256 opponentHitPart = get1of(6);
            if ((opponentHitPart == 3) || (opponentHitPart == 4)) {
                opponentHitPart = getWeakestPart(_starshipId);
            }
            //check if the starship had a shield on the part that was hit
            if (opponentHitPart == _shieldOnPart) {
                opponentFirePower = opponentFirePower / 2; //shield absorbes 50% of the damage
            }

            emit FireShot(
                _opponentStarshipId,
                _starshipId,
                opponentFirePower,
                opponentHitPart,
                _shieldOnPart
            );
            //battleStarships[_opponentStarshipId].totalFirePower += opponentFirePower;

            if (isWinningShot(_starshipId, opponentHitPart, opponentFirePower)) {
                //emit battlelog first

                //call winner
                callWinner(
                    _starshipId,
                    _opponentStarshipId,
                    battleStarships[_starshipId].battleBid,
                    false,
                    battleStarships[_starshipId].strength,
                    battleStarships[_opponentStarshipId].strength
                );
            }
        }
    }

    /** @dev fire power of starship during battle
    @param _strength {uint256}
    */
    function getFirePower(uint256 _strength, bool _advancedBattle) internal returns (uint256) {
        uint256 index = IRandomSelector(randomSelector).getRandom(_strength);

        if (_advancedBattle) {
            index = (index % 10) + 15; //number between 15-25
        } else {
            index = (index % 50) + 25; //number between 25-74
        }
        uint256 firePower = (_strength * index) / 100;
        return firePower;
    }

    function isWinningShot(
        uint256 _starshipId,
        uint256 _fireAtPart,
        uint256 _firePower
    ) internal returns (bool) {
        bool isWinner;
        if (_fireAtPart == 0) {
            if (battleStarships[_starshipId].hullIntegrity <= _firePower) {
                isWinner = true;
                battleStarships[_starshipId].hullIntegrity = 0;
                battleStarships[_starshipId].strength = battleStarships[_starshipId]
                    .bridgeIntegrity;
            } else {
                battleStarships[_starshipId].hullIntegrity -= _firePower;
                battleStarships[_starshipId].strength -= _firePower;
            }
        }
        if (_fireAtPart == 1) {
            if (battleStarships[_starshipId].bridgeIntegrity <= _firePower) {
                isWinner = true;
                battleStarships[_starshipId].bridgeIntegrity = 0;
                battleStarships[_starshipId].strength = battleStarships[_starshipId].hullIntegrity;
            } else {
                battleStarships[_starshipId].bridgeIntegrity -= _firePower;
                battleStarships[_starshipId].strength -= _firePower;
            }
        }
        if (_fireAtPart == 2) {
            if (battleStarships[_starshipId].engineIntegrity <= _firePower) {
                isWinner = true;
                battleStarships[_starshipId].engineIntegrity = 0;
            } else {
                battleStarships[_starshipId].engineIntegrity -= _firePower;
            }
        }

        return isWinner;
    }

    /** ======== =========== ======= */
    /** ======== BATTLE OVER ======= */
    /** ======== =========== ======= */

    //if a starship has engaged in battle but wants to surrender.
    function surrender(uint256 _starshipId) external nonReentrant notContract {
        require(
            battleStarships[_starshipId].openForBattle == 2,
            'Starship must be engaged in a battle'
        ); //starship must be engaged in a battle
        require(IStarship(starships).ownerOf(_starshipId) == msg.sender, 'Not owner of starship!');
        require(battleStarships[_starshipId].attacker, 'Starship must be the attacker');

        callWinner(
            _starshipId,
            battleStarships[_starshipId].inFightWith,
            battleStarships[_starshipId].battleBid,
            false,
            battleStarships[battleStarships[_starshipId].inFightWith].strength,
            battleStarships[_starshipId].strength
        );
    }

    //change battle bid
    function changeBattleBid(uint256 _starshipId, uint256 _newBattleBid)
        external
        nonReentrant
        notContract
    {
        require(
            battleStarships[_starshipId].openForBattle == 1,
            'Starship must be open for battle'
        ); //starship must be open for battle
        require(battleStarships[_starshipId].battleBid > 0, 'Nothing to withdraw');
        require(IStarship(starships).ownerOf(_starshipId) == msg.sender, 'Not owner of starship!');

        uint256 usdBattleBid = ITreasury(treasury).valueOf(bidToken, _newBattleBid); //calculate the value of warp in DAI
        require(usdBattleBid >= 10 * 1e9, 'Battle bid must be highen than 10');

        //is new battle bid higher or lower than the existing battleBid?
        uint256 bidDifference;
        if (_newBattleBid > battleStarships[_starshipId].battleBid) {
            //new bid is higher, user has to pay the difference
            bidDifference = _newBattleBid - battleStarships[_starshipId].battleBid;
            battleStarships[_starshipId].battleBid = _newBattleBid;
            IERC20(bidToken).safeTransferFrom(msg.sender, address(this), bidDifference);
        } else {
            //new bid is lower, need to refund the difference
            bidDifference = battleStarships[_starshipId].battleBid - _newBattleBid;
            battleStarships[_starshipId].battleBid = _newBattleBid;
            IERC20(bidToken).safeTransfer(msg.sender, bidDifference);
        }
        //TO DO emit event
    }

    //if a starship has engaged in battle but didn't finish it (more than 1 hour passed since last hit), the other starship can claim victory.
    function claimVictory(uint256 _starshipId) external nonReentrant notContract {
        require(
            battleStarships[_starshipId].openForBattle == 2,
            'Starship must be engaged in a battle'
        ); //starship must be engaged in a battle
        require(IStarship(starships).ownerOf(_starshipId) == msg.sender, 'Not owner of starship!');
        require(!battleStarships[_starshipId].attacker, 'Starship must not be the attacker');
        require(
            battleStarships[_starshipId].lastHitTime + 3600 <= block.timestamp,
            'Not enough time passed since last hit'
        );

        callWinner(
            battleStarships[_starshipId].inFightWith,
            _starshipId,
            battleStarships[_starshipId].battleBid,
            false,
            battleStarships[battleStarships[_starshipId].inFightWith].strength,
            battleStarships[_starshipId].strength
        );
    }

    /** @dev call for battle winner
    list starship for battle
    _winner param is true if _starshipId is winner and false if _opponentStarshipId is winner
    @param _starshipId {uint256}
    @param _opponentStarshipId {uint256}
    @param _battleBid {uint256}
    @param _winner {bool}
    */
    function callWinner(
        uint256 _starshipId,
        uint256 _opponentStarshipId,
        uint256 _battleBid,
        bool _winner,
        uint256 _attackerStrengthLeft,
        uint256 _defenderStrengthLeft
    ) internal {
        //calculate damage per part
        address winnerAddress;
        uint256 partDamage = 1;

        uint256 growthFee = (_battleBid * 2) / 10; //10% fee
        uint256 battlePayment = _battleBid * 2 - growthFee;

        if (_winner) {
            //starship is the winner, opponent is the looser
            //add damage to loser
            IStarshipControl(starshipControl).experience(_starshipId, 8, true);
            IStarshipControl(starshipControl).experience(_opponentStarshipId, 2, true);
            IStarshipControl(starshipControl).damage(
                _opponentStarshipId,
                partDamage,
                partDamage,
                partDamage,
                false
            );

            //set winner
            winnerAddress = IStarship(starships).ownerOf(_starshipId);

            emit CallWinner(
                winnerAddress,
                IStarship(starships).ownerOf(_opponentStarshipId),
                _starshipId,
                _opponentStarshipId,
                partDamage,
                battlePayment,
                block.timestamp,
                _attackerStrengthLeft,
                _defenderStrengthLeft
            );
        } else {
            //opponent is the winner, starship is the looser
            //add damage to loser
            IStarshipControl(starshipControl).experience(_starshipId, 2, true);
            IStarshipControl(starshipControl).experience(_opponentStarshipId, 8, true);
            IStarshipControl(starshipControl).damage(
                _starshipId,
                partDamage,
                partDamage,
                partDamage,
                false
            );

            //set winner
            winnerAddress = IStarship(starships).ownerOf(_opponentStarshipId);

            emit CallWinner(
                winnerAddress,
                IStarship(starships).ownerOf(_starshipId),
                _opponentStarshipId,
                _starshipId,
                partDamage,
                battlePayment,
                block.timestamp,
                _attackerStrengthLeft,
                _defenderStrengthLeft
            );
        }

        //clear battle data
        clearBattle(_starshipId);
        clearBattle(_opponentStarshipId);

        // payment
        IERC20(bidToken).safeTransfer(winnerAddress, battlePayment);
        IERC20(bidToken).safeTransfer(growth, growthFee);
    }

    /** ======== =========== ======= */
    /** ========  AUXILIARY  ======= */
    /** ======== =========== ======= */

    /** @dev reset the battleship */
    function clearBattle(uint256 _starshipId) internal {
        battleStarships[_starshipId].inFightWith = 0;
        battleStarships[_starshipId].attacker = false;
        battleStarships[_starshipId].battleBid = 0;
        battleStarships[_starshipId].openForBattle = 0;
        //battleStarships[_starshipId].totalFirePower = 0;
        starshipsList.remove(_starshipId);
    }

    function setMinBidFactor(uint256 _min) external onlyOwner {
        minBidFactor = _min;
    }

    function setBidToken(address _token) external onlyOwner {
        bidToken = _token;
    }

    function setTreasuryAddress(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    /** @dev returns weakest part of sharship (0 is hull, 1 is bridge, 2 is engine) */
    function getWeakestPart(uint256 _starshipId) internal view returns (uint256) {
        uint256 weekestPart;
        if (
            battleStarships[_starshipId].hullIntegrity >
            battleStarships[_starshipId].bridgeIntegrity
        ) {
            weekestPart = 1;
        }
        if (
            battleStarships[_starshipId].bridgeIntegrity >
            battleStarships[_starshipId].engineIntegrity
        ) {
            weekestPart = 2;
        }
        return weekestPart;
    }

    /** @dev use random selector to obtain a randomized index */
    function get1of(uint256 _howMany) internal returns (uint256) {
        uint256 index = IRandomSelector(randomSelector).getRandom(69);

        index = index % _howMany; //number between 0 and howMany-1
        return index;
    }

    /** ======== =========== ======= */
    /** ========   GETTERS   ======= */
    /** ======== =========== ======= */

    /** @notice return total number of items for starshipsList */
    function getStarshipsCount() external view returns (uint256) {
        return starshipsList.length();
    }

    /** @dev paginated item list
        @param from {uint256}
        @param to {uint256}
     */
    function getStarships(uint256 from, uint256 to) external view returns (BattleData[] memory) {
        BattleData[] memory _items = new BattleData[](to - from);
        uint256 count = 0;
        for (uint256 i = from; i < to; i++) {
            Ship memory shipInfo = IStarshipControl(starshipControl).getShip(starshipsList.at(i));
            _items[count] = BattleData({
                id: starshipsList.at(i),
                battlezoneInfo: battleStarships[starshipsList.at(i)],
                shipInfo: shipInfo
            });
            count++;
        }
        return _items;
    }

    /** @dev get starship */
    function getBattleship(uint256 id) external view override returns (BattleShip memory) {
        return battleStarships[id];
    }

    /* ======= AUXILLIARY ======= */

    /**
     * @notice Checks if address is a contract
     * @dev It prevents contract from being targetted
     */
    function _isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMathUpgradeable {
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ReentrancyGuardUpgradeable is Initializable {
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

    function __ReentrancyGuard_init() internal initializer {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal initializer {
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
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/structs/EnumerableSet.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSetUpgradeable {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastvalue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastvalue;
                // Update the index for the moved value
                set._indexes[lastvalue] = valueIndex; // Replace lastvalue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >0.8.0;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

contract WarpBase is Initializable {
    bool public paused;
    address public owner;
    mapping(address => bool) public pausers;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PauseChanged(address indexed by, bool indexed paused);

    /** ========  MODIFIERS ========  */

    /** @notice modifier for owner only calls */
    modifier onlyOwner() {
        require(owner == msg.sender, 'Ownable: caller is not the owner');
        _;
    }

    /** @notice pause toggler */
    modifier onlyPauseToggler() {
        require(owner == msg.sender || pausers[msg.sender], 'Ownable: caller is not the owner');
        _;
    }

    /** @notice modifier for pausing contracts */
    modifier whenNotPaused() {
        require(!paused || owner == msg.sender || pausers[msg.sender], 'Feature is paused');
        _;
    }

    /** ========  INITALIZE ========  */
    function __WarpBase_init() internal initializer {
        owner = msg.sender;
        paused = false;
    }

    /** ========  OWNERSHIP FUNCTIONS ========  */

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), 'Ownable: new owner is the zero address');
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /** ===== PAUSER FUNCTIONS ========== */

    /** @dev allow owner to add or remove pausers */
    function setPauser(address _pauser, bool _allowed) external onlyOwner {
        pausers[_pauser] = _allowed;
    }

    /** @notice toggle pause on and off */
    function setPause(bool _paused) external onlyPauseToggler {
        paused = _paused;

        emit PauseChanged(msg.sender, _paused);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol';

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

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
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
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
            'SafeERC20: approve from non-zero to non-zero allowance'
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, newAllowance)
        );
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, 'SafeERC20: decreased allowance below zero');
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(
                token,
                abi.encodeWithSelector(token.approve.selector, spender, newAllowance)
            );
        }
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

        bytes memory returndata = address(token).functionCall(
            data,
            'SafeERC20: low-level call failed'
        );
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), 'SafeERC20: ERC20 operation did not succeed');
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >0.8.0;

interface IRandomSelector {
    function getRandom(uint256 input) external returns (uint256 output);
}

// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >0.8.0;

/* ======== Structs ======== */
struct Ship {
    string name;
    string ipfs;
    string archetype;
    string brand;
    uint256 bridgeIntegrity;
    uint256 hullIntegrity;
    uint256 engineIntegrity;
    uint256 fuel;
    // Added variables
    string origin;
    // Health points of each type
    uint256 bridgeDmg;
    uint256 hullDmg;
    uint256 engineDmg;
    // ship Experience
    uint256 experience;
}

interface IStarshipControl {
    function drainFuel(uint256 shipId) external;

    function getShip(uint256 _shipId) external view returns (Ship memory);

    function getShipPlanet(uint256 _shipId) external view returns (uint256, string memory);

    function damage(
        uint256 _shipId,
        uint256 _valueHull,
        uint256 _valueEngine,
        uint256 _valueBridge,
        bool _repair
    ) external;

    function experience(
        uint256 _shipId,
        uint256 _amount,
        bool _add
    ) external;

    function isDamaged(uint256 _shipId) external returns (bool);

    function bridged(
        address _to,
        uint256 _shipId,
        Ship memory _ship
    ) external;
}

// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >0.8.0;

import '@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol';

interface IStarship is IERC721EnumerableUpgradeable {
    function tokenURI(uint256 tokenId) external view returns (string memory);

    function mint(address _to, uint256 _tokenId) external;

    function exists(uint256 _tokenId) external view returns (bool);
}

// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >0.8.0;

struct BattleShip {
    uint256 battleBid; //ex: 10 represents 10 DAI. No decimals.
    uint256 strength; //hull + bridge
    uint256 openForBattle; // 0 not open for battle, 1 open for battle, 2 engaged in battle
    uint256 hullIntegrity; //advanced use while in battle
    uint256 bridgeIntegrity; //advanced use while in battle
    uint256 engineIntegrity; //advanced use while in battle
    uint256 inFightWith; //starship id of the in fight with - advanced use only
    uint256 lastHitTime; //time of last hit - advanced use only
    bool attacker; //false if starship is listed on the battlefield, true if starship is the attacker - advanced use only
    //uint256 totalFirePower;
}

interface IBattlezone {
    function getBattleship(uint256 id) external view returns (BattleShip memory);
}

// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >0.8.0;

interface ITreasury {
    function deposit(
        uint256 _amount,
        address _token,
        uint256 _profit
    ) external returns (uint256);

    function valueOf(address _token, uint256 _amount) external view returns (uint256 value_);

    function mintRewards(address _recipient, uint256 _amount) external;

    function withdrawGrowthFee(uint256 _amount, address _token) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To initialize the implementation contract, you can either invoke the
 * initializer manually, or you can include a constructor to automatically mark it as initialized when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() initializer {}
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC20/IERC20.sol)

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
// OpenZeppelin Contracts v4.4.0 (utils/Address.sol)

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
// OpenZeppelin Contracts v4.4.0 (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../IERC721Upgradeable.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721EnumerableUpgradeable is IERC721Upgradeable {
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
// OpenZeppelin Contracts v4.4.0 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721Upgradeable is IERC165Upgradeable {
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
// OpenZeppelin Contracts v4.4.0 (utils/introspection/IERC165.sol)

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
interface IERC165Upgradeable {
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