///SPDX-License-Identifier:MIT
/**
    @title EquipmentMinter
    @author Eman @SgtChiliPapi
    @notice: This contract serves as the router/minter for the Equipment NFT. It communicates with the VRF contract,
    performs the necessary calculations to determine the equipment's properties and stats and ultimately calls the mint 
    function of the NFT contract with the calculated results as arguments. Only this contract can call the NFT's mint function
    and only one router at a time can be set in the NFT contract as well.
    
*/
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../utils/BreakdownUint256.sol";
import "../libraries/equipment/CraftingRecipes.sol";
import "../libraries/structs/GlobalStructs.sol";
import "../libraries/structs/CharacterStructs.sol";

interface _RandomizationContract {
    function requestRandomWords(address user, uint32 numWords, bool experimental) external returns (uint256 requestId);
    function getRequestStatus(uint256 _requestId) external view returns(bool fulfilled, uint256[] memory randomWords);
}

interface _EquipmentLibrary {
    function getEquipmentDetails(uint256 _type, uint256 _rarity, uint256 _dominant_stat, uint256 extremity) external returns (equipment_details memory);
}

interface _Equipments {
    function _mintEquipment(address user, equipment_properties memory equipment_props, battle_stats memory _equipment_stats) external;
}

interface _Characters {
    function isOwner(address _owner, uint256 _character) external view returns (bool);
    function character(uint256 _character_id) external view returns (character_properties memory);
}

interface _EnerLink {
    function mint(address to, uint256 amount) external;
}

contract EquipmentMinter is Ownable, Pausable{
    ///The randomization contract for generating random numbers for mint
    _RandomizationContract private randomizer;
    _Characters private characters;
    _EnerLink private enerlink;
    address private vrfContract;

    ///The core: Equipment NFT contract deployment.
    _Equipments equipmentsNft;

    ///The beneficiary of the msg.value being sent to the contract for every mint request.
    address private vrf_refunder;

    ///Map out a user's address to its equipment crafting request (if any) {request_id, equipment_type, number_of_items}. If none, the request_id == 0.
    mapping (address => equipment_request) public request;

    ///The msg.value required to mint to prevent spam and deplete VRF funds.
    ///Currently unset (0) for judging purposes as stated in the hackathon rules.
    uint256 public mint_fee;

    ///mapping to restrict free mints to players/characters
    //character => equipment_type => bool
    mapping(uint256 => mapping(uint256 => bool)) public character_minted_free;

    ///Arrays of addresses for the materials and catalyst tokens
    address[4] private materials_addresses;
    address[4] private catalysts_addresses; 
    
    event EquipmentRequested(address indexed player_address, equipment_request request);
    constructor(address equipmentsNftAddress, address charactersAddress, address enerlinkAddress, address[4] memory materials, address[4] memory catalysts){
        equipmentsNft = _Equipments(equipmentsNftAddress);
        characters = _Characters(charactersAddress);
        enerlink = _EnerLink(enerlinkAddress);
        materials_addresses = materials;
        catalysts_addresses = catalysts;
        vrf_refunder = msg.sender;
    }

    ///@notice This function requests n random number/s from the VRF contract to be consumed with the mint.
    function requestEquipment(uint64 _equipment_type , uint256 item_count) public payable whenNotPaused{
        ///We can only allow one request per address at a time. A request shall be completed (minted the equipment) to be able request another one.
        equipment_request memory _request = request[msg.sender];
        require(_request.request_id == 0, "eMNTR: There is a request pending mint.");

        ///Equipment/Items can only be weapon, armor, helm, accessory, and consumable. 0-4
        require(_equipment_type < 5, "eMNTR: Incorrect number for an equipment type.");
        
        ///The MATIC being received is not payment for the NFT but rather to simply replenish the VRF subscribtion's funds and also serves as an effective anti-spam measure as well.
        ///Restrict number of mints to below 4 to avoid insufficient gas errors and accidental requests for very large number of mints.
        require(item_count > 0 && item_count < 4, "eMNTR: Can only request to mint 1 to 3 items at a time.");
        require(msg.value >= (item_count * mint_fee), "eMNTR: Incorrect amount for equipment minting. Send exactly 0.01 MATIC per item requested.");
        
        ///Burn the materials from the user's balance.
        bool enough = getEquipmentRequirements(_equipment_type, item_count);
        require(enough, "eMNTR: Not enough materials for this crafting transaction.");
        
        ///@notice EXTCALL to VRF contract. Set the caller's current equipment_request to the returned request_id by the VRF contract.
        ///The bool argument here notifies the vrf contract that the request being sent is NOT experimental.
        request[msg.sender] = equipment_request({
            request_id: randomizer.requestRandomWords(msg.sender, uint32(item_count),  false),
            equipment_type: _equipment_type,
            number_of_items: uint32(item_count),
            time_requested: block.timestamp,
            free: false
        });
        
        emit EquipmentRequested(msg.sender, request[msg.sender]);
    }

    ///@notice This function is flagged as EXPERIMENTAL. This invokes a request to the VRF of random numbers which are when
    ///fulfilled, the VRF (automatically) mints the NFT within the same transaction as the fulfillment.
    ///This function requests n random number/s from the VRF contract to be consumed with the mint.
    function requestEquipmentExperimental(uint64 _equipment_type /**, uint32 item_count */) public payable whenNotPaused{
        ///We can only allow one request per address at a time. A request shall be completed (minted the equipment) to be able request another one.
        equipment_request memory _request = request[msg.sender];
        require(_request.request_id == 0, "eMNTR: There is a request pending mint.");

        ///Equipment/Items can only be weapon, armor, helm, accessory, and consumable. 0-4
        require(_equipment_type < 5, "eMNTR: Incorrect number for an equipment type.");
        
        ///The MATIC being received is not payment for the NFT but rather to simply replenish the VRF subscribtion's funds and also serves as an effective anti-spam measure as well.
        ///Using a constant 1 as n or number of equipments to be minted so as to stay well below the gas Limit of
        ///the VRF's fulfillRandomWords() as it is also responsible for triggering the actual minting.
        ///In case we can have make it clear that minting multiple equipments is safe, we can allow multiple mints by specifying the 
        ///desired number of mints per transaction.
            ///Restrict number of mints to below 4 to avoid insufficient gas errors and requests for very large number of mints.
            // require(item_count > 0 && item_count < 4, "eMNTR: Can only request to mint 1 to 3 items at a time.");
        require(msg.value >= (/**item_count */ 1 * mint_fee), "eMNTR: Incorrect amount for equipment minting. Send exactly 0.01 MATIC per item requested.");
        
        ///Burn the materials from the user's balance.
        ///Using a constant 1. See above reason on line 57 (unwrapped).
        bool enough = getEquipmentRequirements(_equipment_type, 1 /**item_count */);
        require(enough, "eMNTR: Not enough materials for this crafting transaction.");
        
        ///@notice EXTCALL to VRF contract. Set the caller's current equipment_request to the returned request_id by the VRF contract.
        ///Using a constant 1. See above reason on line 57 (unwrapped).
        ///The bool argument here notifies the vrf contract that the request being sent is experimental.
        request[msg.sender] = equipment_request({
            request_id: randomizer.requestRandomWords(/**item_count */msg.sender, 1, true),
            equipment_type: _equipment_type,
            number_of_items: 1,
            time_requested: block.timestamp,
            free: false
        });
        
        emit EquipmentRequested(msg.sender, request[msg.sender]);
    }

    ///@notice This is to mint equipments for free to give out starting characters a minting experience. The free mint will always
    ///give out common equipment.
    function requestEquipmentFree(uint256 character_id, uint64 _equipment_type /**, uint32 item_count */) public payable whenNotPaused{
        ///We can only allow one request per address at a time. A request shall be completed (minted the equipment) to be able request another one.
        equipment_request memory _request = request[msg.sender];
        require(_request.request_id == 0, "eMNTR: There is a request pending mint.");

        ///Equipment/Items can only be weapon, armor, helm, accessory, and consumable. 0-4
        require(_equipment_type < 5, "eMNTR: invalid eqpt type.");

        ///Require 0.01 msg.value
        require(msg.value >= (/**item_count */ 1 * mint_fee), "eMNTR: send 0.01 matic");

        ///Allow only one free mint per character per equipment
        require(!character_minted_free[character_id][_equipment_type], "eMNTR: character already minted.");

        ///Allow only characters with exp greater than 200
        require(characters.character(character_id).exp > 99, "eMNTR: insuf char exp.");

        ///Check ownership
        require(characters.isOwner(msg.sender, character_id), "eMNTR: character not owned.");

        ///Update the character and user mapping to free mints immediately after checking
        character_minted_free[character_id][_equipment_type] = true;

        ///@notice EXTCALL to VRF contract. Set the caller's current equipment_request to the returned request_id by the VRF contract.
        ///Using a constant 1. See above reason on line 57 (unwrapped).
        ///The first bool argument here notifies the vrf contract that the request being sent is experimental.
        request[msg.sender] = equipment_request({
            request_id: randomizer.requestRandomWords(/**item_count */ msg.sender, 1, false),
            equipment_type: _equipment_type,
            number_of_items: 1,
            time_requested: block.timestamp,
            free: true
        });
        
        emit EquipmentRequested(msg.sender, request[msg.sender]);
    }

    ///@notice This function will reset the senders request. In case requests dont get fulfilled by the VRF within an hour.
    function cancelRequestExperimental() public {
        equipment_request memory _request = request[msg.sender];
        (bool fulfilled,) = randomizer.getRequestStatus(_request.request_id);
        require(_request.request_id > 0, "eMNTR: Cannot cancel non-existing requests.");
        require((block.timestamp - _request.time_requested) > 3600, "eMNTR: Cannot cancel requests that havent lapsed 1 hour from time requested.");
        require(!fulfilled, "eMNTR: Cannot cancel requests that have already been fulfilled.");
        request[msg.sender] = equipment_request({
            request_id: 0,
            equipment_type: 0,
            number_of_items: 0,
            time_requested: block.timestamp,
            free: false
        });
    }

    ///@notice This function will get the recipe for the equipment to be crafted and will check the token balances of the user for 
    ///each material required. If enough balance is determined, proceed to burn the amounts from the user's token balances.
    function getEquipmentRequirements(uint256 equipment_type, uint256 item_count) internal returns (bool enough){
        ///We will assume at first that the user has enough balances for the materials required. Then we will check each materials
        ///one by one. If we determine that the user in fact DOES NOT have enough balance in any one of the materials, then we will
        ///set this to false and the transaction will revert.
        enough = true;

        ///We determine the recipe by equipment type.
        item_recipe memory recipe = CraftingRecipes.getRecipe(equipment_type);

        ///Determine the total amounts required. The `getRecipe()` from the library CraftingRecipes returns the amount required for
        ///only one piece of equipment to be crafted. So we multiply the respective amounts by the number of equipment the user has
        ///chosen to mint.
        recipe.main_material_amount = recipe.main_material_amount * item_count;
        recipe.indirect_material_amount = recipe.indirect_material_amount * item_count;
        recipe.catalyst_amount = recipe.catalyst_amount * item_count;

        ///We fetch the balances of the user for the required materials and also the corresponding contract instance.
        (uint256 main_material_balance, ERC20Burnable main_material_contract) = checkMaterialBalance(recipe.main_material);
        (uint256 indirect_material_balance, ERC20Burnable indirect_material_contract) = checkMaterialBalance(recipe.indirect_material);
        (uint256 catalyst_balance, ERC20Burnable catalyst_contract) = checkCatalystBalance(recipe.catalyst);

        ///We compare the user's token balances with the required amounts.
        if(main_material_balance < recipe.main_material_amount){enough = false;}
        if(indirect_material_balance < recipe.indirect_material_amount){enough = false;}
        if(catalyst_balance < recipe.catalyst_amount){enough = false;}

        ///If the user's token balances are indeed enough for the required materials, we then burn it from the user's balance.
        ///Make sure to prompt the user to set enough token allowances before initiating an equipment request transaction.
        if(enough == true){
            main_material_contract.burnFrom(msg.sender, recipe.main_material_amount);
            indirect_material_contract.burnFrom(msg.sender, recipe.indirect_material_amount);
            catalyst_contract.burnFrom(msg.sender, recipe.catalyst_amount);
        }
    }

    ///@notice This function checks the user's balance and returns the corresponding token contract instance.
    function checkMaterialBalance(uint256 material_index) internal view returns (uint256 balance, ERC20Burnable material_contract){
            address material_address = materials_addresses[material_index];
            material_contract = ERC20Burnable(material_address);
            balance = material_contract.balanceOf(msg.sender);
    }

    ///@notice This function checks the user's balance and returns the corresponding token contract instance.
    function checkCatalystBalance(uint256 catalyst_index) internal view returns (uint256 balance, ERC20Burnable catalyst_contract){
        address catalyst_address = catalysts_addresses[catalyst_index];
        catalyst_contract = ERC20Burnable(catalyst_address);
        balance = catalyst_contract.balanceOf(msg.sender);
    }

    ///Once the random numbers requested has been fulfilled in the VRF contract, this function shall be called by the user
    ///to complete the mint process.
    function mintEquipments() public{
        equipment_request memory _request = request[msg.sender];

        ///Check if there is a pending/fulfilled request previously made by the caller using requestEquipment().
        require(_request.request_id > 0, "eMNTR: No request to mint.");

        ///Fetch the request status from the VRF contract.
        (bool fulfilled, uint256[] memory randomNumberRequested) = randomizer.getRequestStatus(_request.request_id);

        ///Verify if the random number request has been indeed fulfilled, revert if not.
        require(fulfilled, "eMNTR: Request is not yet fulfilled or invalid request id.");

        ///Loop thru the number of items requested to be minted.
        for(uint256 i=0; i < _request.number_of_items; i++){
            mintEquipment(msg.sender, randomNumberRequested[i], _request.equipment_type, _request.free);
        }
        ///Reset the sender's request property values to 0
        request[msg.sender] = equipment_request({
            request_id: 0,
            equipment_type: 0,
            number_of_items: 0,
            time_requested: block.timestamp,
            free: false
        });
    }

    ///@notice This function is flagged as EXPERIMENTAL. There is a risk for a loss of material tokens if the call to this
    ///function by the VRF reverts.
    ///Once the random numbers requested has been fulfilled in the VRF contract, this function is called by the VRF contract
    ///to complete the mint process.
    function mintEquipmentsExperimental(address user, uint256[] memory randomNumberRequested) public onlyVRF{
        equipment_request memory _request = request[user];
        ///@notice Removing the immediate following external SLOAD since the VRF already knows the randomNumberRequested, 
        ///we simply pass it from the VRF's external call to this function
            // (/** bool fulfilled */, uint256[] memory randomNumberRequested) = randomizer.getRequestStatus(_request.request_id);

        ///@notice We are removing the immediate following requirements since we have shifted the minting responsibility to the VRF.
        ///When the fulfillRandomWords() is executed, there is no more need to check if the request has been fulfilled.
            ///Check if there is a pending/fulfilled request previously made by the caller using requestEquipment().
            // require(_request.request_id > 0, "eMNTR: No request to mint.");

            ///Verify if the random number request has been indeed fulfilled, revert if not.
            // require(fulfilled, "eMNTR: Request is not yet fulfilled or invalid request id.");

        ///Loop thru the number of items requested to be minted.
        for(uint256 i=0; i < _request.number_of_items; i++){
            mintEquipment(user, randomNumberRequested[i], _request.equipment_type, _request.free);
        }
        ///Reset the sender's request property values to 0
        request[user] = equipment_request({
            request_id: 0,
            equipment_type: 0,
            number_of_items: 0,
            time_requested: block.timestamp,
            free: false
        });
    }

    ///@notice This includes external call to the Equipment NFT Contract or the EnerLink Contract to actually mint the tokens.
    function mintEquipment(address user, uint256 randomNumberRequested, uint64 equipment_type, bool _free) internal {
        ///If the item being minted is a consumable / EnerLink token
        if(equipment_type == 4){
            uint256 consumable_minted = (randomNumberRequested % 3) + 1;
            enerlink.mint(user, consumable_minted * 1 ether);
        }
        ///If the item being minted is an equipment
        if(equipment_type != 4){
            (equipment_properties memory equipment_props, battle_stats memory _equipment_stats) = getResult(randomNumberRequested, equipment_type, _free);
            equipmentsNft._mintEquipment(user, equipment_props, _equipment_stats);
        }
    }

    function getResult(uint256 randomNumber, uint64 _equipment_type, bool _free) internal pure returns (equipment_properties memory equipment_props, battle_stats memory _equipment_stats){
        ///To save on LINK tokens for our VRF contract, we are breaking a single random word into 16 uint16s.
        ///The reason for this is we will need a lot(9) of random numbers for a single equipment mint.
        ///It is given that the chainlink VRF generates verifiable, truly random numbers that it is safe to assume that breaking this
        ///truly random number poses no exploitable risk as far as the mint is concerned.
        ///However, there is a theoretical risk that the VRF generates a number with an extremely low number so that the first few uint16s would
        ///have their value at 0. In that case, it can be argued that it simply is not a blessing from the RNG Gods for the user.
        ///Still, our workaround if such thing occurs anyway is to start using the last numbers in the uint16s array which probably contains
        ///values greater than 0.
        uint16[] memory randomNumbers = BreakdownUint256.break256BitsIntegerIntoBytesArrayOf16Bits(randomNumber);

        ///Get the rarity of the equipment using the last item in the uint16[]. The rarity also determines how much stat points the equipment has.
        ///The rarer the item, the higher the stat points it holds.
        (uint64 _rarity, uint256 stat_sum) = getRarity(randomNumbers[15]);

        ///If the mint request is a free one, limit the rarity to the lowest tier
        if(_free){_rarity = 0;}

        ///Get the stat allocation of the equipment using the next 8 items from the last in the uint16[]. The stat points determined from
        ///rarity of the item from the getRarity() is allocated this way.
        uint16[8] memory random_stats = [randomNumbers[14], randomNumbers[13], randomNumbers[12], randomNumbers[11], randomNumbers[10], randomNumbers[9], randomNumbers[8], randomNumbers[7]];
        
        ///Here we check what stat {atk, def, eva, ... } the equipment has the highest allocation. This determines the item's dominant stat.
        ///In case of weapons, it determine's the weapon's type (hammer, dagger, bombard,...)
        ///Also, we check the extremity of the item's dominant stat (weak, minor, good, great, intense,...)
        uint64 _dominant_stat; uint64 _extremity;
        (_equipment_stats, _dominant_stat, _extremity) = getStats(random_stats, stat_sum, _equipment_type);
        equipment_props = equipment_properties({
            equipment_type: _equipment_type,
            rarity: _rarity,
            dominant_stat: _dominant_stat,
            extremity: _extremity
        });
    }

    function getRarity(uint16 number) internal pure returns (uint64 rarity, uint256 stat_sum){
        uint256 roll_value = number % 1000;
        if(roll_value > 994){rarity = 4; stat_sum = 100;} //.5% chance. If you ever get one, you might as well try the lottery.
        if(roll_value > 984 && roll_value <= 994){rarity = 3; stat_sum = 60;} //1%
        if(roll_value > 944 && roll_value <= 984){rarity = 2; stat_sum = 40;} //4%
        if(roll_value > 744 && roll_value <= 944){rarity = 1; stat_sum = 25;} //20%
        if(roll_value >= 0 && roll_value <= 748){rarity = 0; stat_sum = 15;} //75%
    }

    function getStats(uint16[8] memory random_stats, uint256 stat_sum, uint256 _equipment_type) internal pure returns (battle_stats memory _equipment_stats, uint64 dominant_stat, uint64 extremity){
        uint256 total_roll_value;
        uint256 dominant_roll_value;
        uint256[8] memory roll_values;
        uint256[8] memory _stats;
        for(uint256 i = 0; i < random_stats.length; i++){
            uint256 roll_value = random_stats[i] % 1000;
            roll_values[i] = roll_value;
            total_roll_value += roll_values[i];
        }
        for(uint256 i = 0; i < roll_values.length; i++){
            _stats[i] = (roll_values[i] * stat_sum) / total_roll_value;
        }

        (uint256 base_stat_index, uint256 base_stat_value) = getBaseStat(_equipment_type, stat_sum);
        _stats[base_stat_index] += base_stat_value;

        _equipment_stats = battle_stats({
            atk: uint32(_stats[0]),
            def: uint32(_stats[1]),
            eva: uint32(_stats[2]),
            hp: uint32(_stats[3]),
            pen: uint32(_stats[4]),
            crit: uint32(_stats[5]),
            luck: uint32(_stats[6]),
            energy_restoration: uint32(_stats[7])
        });

        (dominant_stat, dominant_roll_value)  = getDominantStat(roll_values);
        extremity = getExtremity(dominant_roll_value, total_roll_value, stat_sum);
    }

    ///@notice This function calculates the equipment's base stat value. We determine the type of the equipment first to know what
    ///particular stat it has as its primary stat. Then we calculate for its value using the stat_sum that is derived from the 
    ///equipment's rarity. 
    
    ///For example, a weapon has ATK as its primary stat. Then we calculate for the value using the stat_sum.
    function getBaseStat(uint256 _equipment_type, uint256 stat_sum) internal pure returns (uint256 stat_index, uint256 stat_value){
        if(_equipment_type == 0){
            stat_index = 0;
            ///@notice We have arbitrarily set the MAX stat effect of any equipment here at 300 for simplicity purposes.
            ///If further game balance should be desired, this library should be revised. We have also added a +50 bonus
            ///multiplier & denominator to all kinds of equipment to dilute the effects of the rarity a bit to achieve reasonable game balance.
            stat_value = (300 * (stat_sum + 50)) / 150;
        }
        if(_equipment_type == 1){
            stat_index = 1;
            stat_value = ((225 * (stat_sum + 50)) / 150) / 2;
        }
        if(_equipment_type == 2){
            stat_index = 1;
            stat_value = ((75 * (stat_sum + 50)) / 150) / 2;
        }
        if(_equipment_type == 3){
            stat_index = 2;
            stat_value = ((300 * (stat_sum + 50)) / 150) / 2;
        }
    }

    function getDominantStat(uint256[8] memory roll_values) internal pure returns (uint64 dominant_stat, uint256 dominant_roll_value){
        uint256[8] memory stat_index = [uint256(0),1,2,3,4,5,6,7];
        uint256 l = roll_values.length;
        for (uint256 i = 0; i < l; i++) {
            for (uint256 j = i + 1; j < l; j++) {
                if (roll_values[i] < roll_values[j]) {
                    uint256 temp = roll_values[i];
                    uint256 temp2 = stat_index[i];
                    roll_values[i] = roll_values[j];
                    stat_index[i] = stat_index[j];
                    roll_values[j] = temp;
                    stat_index[j] = temp2;
                }
            }
        }
        dominant_stat = uint64(stat_index[0]);
        dominant_roll_value = roll_values[0];
    }

    function getExtremity(uint256 dominant_roll_value, uint256 total_roll_value, uint256 stat_sum) internal pure returns (uint64 extremity){
        uint256 stat_value = (dominant_roll_value * stat_sum) / total_roll_value;
        if(stat_value > 5 && stat_value <= 10){extremity = 1;} //good
        if(stat_value > 10 && stat_value <= 15){extremity = 2;} //great
        if(stat_value > 15 && stat_value <= 20){extremity = 3;} //intense
        if(stat_value > 20 && stat_value <= 30){extremity = 4;} //extraordinary
        if(stat_value > 30 && stat_value <= 45){extremity = 5;} //ethereal
        if(stat_value > 45 && stat_value <= 65){extremity = 6;} //astronomical
        if(stat_value > 65){extremity = 7;} //divine
    }

    ///@notice This is just a view function to show if the user has enough balance of the materials required.
    function userMaterialsEnough(uint256 equipment_type, uint256 item_count) public view returns (bool enough){
        ///We will assume at first that the user has enough balances for the materials required. Then we will check each materials
        ///one by one. If we determine that the user in fact DOES NOT have enough balance in any one of the materials, then we will
        ///set this to false and the transaction will revert.
        enough = true;

        ///We determine the recipe by equipment type.
        item_recipe memory recipe = CraftingRecipes.getRecipe(equipment_type);

        ///Determine the total amounts required. The `getRecipe()` from the library CraftingRecipes returns the amount required for
        ///only one piece of equipment to be crafted. So we multiply the respective amounts by the number of equipment the user has
        ///chosen to mint.
        recipe.main_material_amount = recipe.main_material_amount * item_count;
        recipe.indirect_material_amount = recipe.indirect_material_amount * item_count;
        recipe.catalyst_amount = recipe.catalyst_amount * item_count;

        ///We fetch the balances of the user for the required materials and also the corresponding contract instance.
        (uint256 main_material_balance, ) = checkMaterialBalance(recipe.main_material);
        (uint256 indirect_material_balance, ) = checkMaterialBalance(recipe.indirect_material);
        (uint256 catalyst_balance, ) = checkCatalystBalance(recipe.catalyst);

        ///We compare the user's token balances with the required amounts.
        if(main_material_balance < recipe.main_material_amount){enough = false;}
        if(indirect_material_balance < recipe.indirect_material_amount){enough = false;}
        if(catalyst_balance < recipe.catalyst_amount){enough = false;}
    }

    ///@notice This function is just an easy way to get the recipe of a certain equipment
    function getEquipmentRecipe(uint256 equipment_type) public pure returns (item_recipe memory recipe){
        recipe = CraftingRecipes.getRecipe(equipment_type);
    }

    ///@notice Admin Functions
    function setRandomizationContract(address _vrfContract) public onlyOwner {
        vrfContract = _vrfContract;
        randomizer = _RandomizationContract(_vrfContract);
    }

    function setMintFee(uint256 amount) public onlyOwner {
        mint_fee = amount * 1 gwei;
    }

    modifier onlyVRF(){
        require(msg.sender == vrfContract, "eMNTR: Can only be called by the VRF Contract for equipment crafting.");
        _;
    }

    function withdraw() public onlyOwner{
        (bool succeed, ) = vrf_refunder.call{value: address(this).balance}("");
        require(succeed, "Failed to withdraw matics.");
    }
}

//SPDX-License-Identifier: MIT
///@author https://ethereum.stackexchange.com/users/102976/jeremy-then
///@notice This is a modified code snippet from his stack overflow answer here: https://ethereum.stackexchange.com/a/133983

pragma solidity ^0.8.7;

library BreakdownUint256 {
    function break256BitsIntegerIntoBytesArrayOf8Bits(uint256 n) internal pure returns(uint8[] memory) {

        uint8[] memory _8BitNumbers = new uint8[](32);

        uint256 mask = 0x00000000000000000000000000000000000000000000000000000000000000ff;
        uint256 shiftBy = 0;

        for(int256 i = 31; i >= 0; i--) { 
            uint256 v = n & mask;
            mask <<= 8;
            v >>= shiftBy;
            _8BitNumbers[uint(i)] = uint8(v);
            shiftBy += 8;
        }
        return _8BitNumbers;
    }

    function break256BitsIntegerIntoBytesArrayOf16Bits(uint256 n) internal pure returns(uint16[] memory) {

        uint16[] memory _16BitNumbers = new uint16[](16);

        uint256 mask = 0x000000000000000000000000000000000000000000000000000000000000ffff;
        uint256 shiftBy = 0;

        for(int256 i = 15; i >= 0; i--) { 
            uint256 v = n & mask;
            mask <<= 16;
            v >>= shiftBy;
            _16BitNumbers[uint(i)] = uint16(v);
            shiftBy += 16;
        }
        return _16BitNumbers;
    }

    function break256BitsIntegerIntoBytesArrayOf32Bits(uint256 n) internal pure returns(uint32[] memory) {

        uint32[] memory _32BitNumbers = new uint32[](8);

        uint256 mask = 0x00000000000000000000000000000000000000000000000000000000ffffffff;
        uint256 shiftBy = 0;

        for(int256 i = 7; i >= 0; i--) { 
            uint256 v = n & mask;
            mask <<= 32;
            v >>= shiftBy;
            _32BitNumbers[uint(i)] = uint32(v);
            shiftBy += 32;
        }
        return _32BitNumbers;
    }
}

//SPDX-License-Identifier: MIT
//CraftingRecipes.sol

/**
    @title Crafting Recipes
    @author Eman @SgtChiliPapi
    @notice This library specifies what kind of materials (ERC20 tokens) are required to craft a particular equipment type.
            
 */

pragma solidity ^0.8.7;

import "../../libraries/structs/EquipmentStructs.sol";

library CraftingRecipes {
    function getRecipe(uint256 item_type) internal pure returns (item_recipe memory recipe){
        (uint256 main_m, uint256 main_a) = getMainMaterial(item_type);
        (uint256 indirect_m, uint256 indirect_a) = getIndirectMaterial(item_type);
        (uint256 catalyst_m, uint256 catalyst_a) = getCatalyst(item_type);

        recipe = item_recipe({
            main_material: main_m,
            indirect_material: indirect_m,
            catalyst: catalyst_m,
            main_material_amount: main_a,
            indirect_material_amount: indirect_a,
            catalyst_amount: catalyst_a
        });
    }

    function getMainMaterial(uint256 item_type) internal pure returns (uint256 material, uint256 amount){
        if(item_type == 0){material = 0; amount = 12 ether;} //WEAPONS: BOOMSTEEL
        if(item_type == 1){material = 1; amount = 9 ether;} //ARMORS: THUMPIRON
        if(item_type == 2){material = 1; amount = 3 ether;} //HELMS: THUMPIRON
        if(item_type == 3){material = 2; amount = 12 ether;} //ACCESSORIES: CLINKGLASS
        if(item_type == 4){material = 3; amount = 1 ether;} //CONSUMABLES: SNAPLINK
    }

    function getIndirectMaterial(uint256 item_type) internal pure returns (uint256 material, uint256 amount){
        if(item_type == 0){material = 1; amount = 4 ether;} //WEAPONS: THUMPIRON
        if(item_type == 1){material = 0; amount = 3 ether;} //ARMORS: BOOMSTEEL
        if(item_type == 2){material = 0; amount = 1 ether;} //HELMS: BOOMSTEEL
        if(item_type == 3){material = 0; amount = 4 ether;} //ACCESSORIES: BOOMSTEEL
        if(item_type == 4){material = 2; amount = 1 ether;} //CONSUMABLES: CLINKGLASS
    }

    function getCatalyst(uint256 item_type) internal pure returns (uint256 catalyst, uint256 amount){
        if(item_type == 0){catalyst = 0; amount = 1 ether;} //WEAPONS: YELLOW SPARKSTONE
        if(item_type == 1){catalyst = 1; amount = 1 ether;} //ARMORS: WHITE SPARKSTONE
        if(item_type == 2){catalyst = 1; amount = 1 ether;} //HELMS: WHITE SPARKSTONE
        if(item_type == 3){catalyst = 2; amount = 1 ether;} //ACCESSORIES: RED SPARKSTONE
        if(item_type == 4){catalyst = 3; amount = 250000000000000000 wei;} //CONSUMABLES: BLUE SPARKSTONE (1/4 bSPARK)
    }
}

//SPDX-License-Identifier: MIT
/**
    @title Struct Library
    @author Eman @SgtChiliPapi
    @notice: Reference for global structs across contracts. 
    Originally created for CHAINLINK HACKATHON FALL 2022
*/

pragma solidity =0.8.17;

struct battle_stats {
    uint256 atk;
    uint256 def;
    uint256 eva;
    uint256 hp;
    uint256 pen;
    uint256 crit;
    uint256 luck;
    uint256 energy_restoration;
}







// struct attack_event {
//     uint256 attack_index;
//     uint256 challenger_hp;
//     uint256 defender_hp;
//     uint256 evaded;
//     uint256 critical_hit;
//     uint256 penetrated;
//     uint256 damage_to_challenger;
//     uint256 damage_to_defender;  
// }

///SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

struct character_properties { //SSTORED
    uint32 character_class;
    uint32 element;
    uint32 str;
    uint32 vit;
    uint32 dex;
    uint32 talent;
    uint32 mood;
    uint32 exp;
}

struct character_uri_details {
    string name;
    string image;
    string mood;
    string bonus;
    string bonus_value;
    string talent_value;
}

struct character_request { //SSTORED
    uint256 request_id;
    uint32 character_class;
    string _name;
    uint256 time_requested;
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
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

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
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
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
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
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
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/extensions/ERC20Burnable.sol)

pragma solidity ^0.8.0;

import "../ERC20.sol";
import "../../../utils/Context.sol";

/**
 * @dev Extension of {ERC20} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
abstract contract ERC20Burnable is Context, ERC20 {
    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }
}

///SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

struct equipment_details {
    bytes name;
    bytes image;
    bytes type_tag;
    bytes rarity_tag;
    bytes dominant_stat_tag;
    bytes extremity_tag;
}

struct equipment_properties { //SSTORED
    uint64 equipment_type; //0-3
    uint64 rarity;
    uint64 dominant_stat;
    uint64 extremity;
}

struct item_recipe {
    uint256 main_material;
    uint256 indirect_material;
    uint256 catalyst;
    uint256 main_material_amount;
    uint256 indirect_material_amount;
    uint256 catalyst_amount;
}

struct equipment_request { //SSTORED
    uint256 request_id;
    uint64 equipment_type;
    uint32 number_of_items;
    uint256 time_requested;
    bool free;
}

struct character_equipments {
    uint64 headgear;
    uint64 armor;
    uint64 weapon;
    uint64 accessory;
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
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

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
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
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
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
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
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
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
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
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
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
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
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
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

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
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
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}