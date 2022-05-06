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

// Openzeppelin
import '@openzeppelin/contracts/utils/Strings.sol';

// Helpers
import './helpers/WarpBase.sol';

// interfaces
import './interfaces/IStarshipParts.sol';
import './interfaces/IStarshipPartsControl.sol';
import './interfaces/IPlanets.sol';
import './interfaces/IStarshipControl.sol';
import './interfaces/IStarship.sol';
import './interfaces/ISelector.sol';

/* note Struct information can be found in the Interface ======== */
contract StarshipControl is IStarshipControl, WarpBase {
    using Strings for uint256;

    /** ========= Structs ======= */
    struct GiftBuidl {
        address to;
        string archetype;
        string brand;
        string ipfs;
        uint256 strength;
        string name;
    }

    //** ======== Events ======== */
    event Buidl(address account, uint256[3] ids, uint256 shipId);
    event DrainFuel(address account, uint256 shipId, uint256 previousFuel);
    event FuelUp(address account, uint256 shipId, uint256 fuelTokenId, uint256 amount);
    event UpgradeParts(uint256 shipId, uint256 hull, uint256 bridge, uint256 engine);
    event Damage(uint256 shipId, uint256 hull, uint256 bridge, uint256 engine);
    event Repair(uint256 shipId, uint256 hull, uint256 bridge, uint256 engine);
    event Gift(address account, address to, uint256 shipId);
    event ShipNamed(address account, uint256 shipId, string name);
    event ShipUpdated(uint256 shipId, uint256 timestamp);

    //** ======== Variables ======== */
    uint256 current;
    uint256 giftCurrent;
    address starships;
    address starshipParts;
    address starshipPartsControl;
    address planets;
    mapping(uint256 => Ship) shipInfo;

    // Random selection upgrade
    address selector;

    // Battlezone upgrade
    mapping(address => bool) callers;

    // Multichain ugprade
    string origin;
    string baseUri;

    /** ======== Init ======== */
    function initialize(
        string memory _origin,
        string memory _baseUri,
        uint256 _giftCurrent
    ) public initializer {
        giftCurrent = _giftCurrent;
        __WarpBase_init(); // also inits ownable

        origin = _origin;
        baseUri = _baseUri;
    }

    /** Gift Build
        @dev Allow owner to gift ships for give aways. Gifts start at 1billion.
        @param gifts {GiftBuidl}
     */
    function giftBuidl(GiftBuidl[] memory gifts) external onlyOwner {
        for (uint256 i = 0; i < gifts.length; i++) {
            giftCurrent += 1;

            shipInfo[giftCurrent].name = gifts[i].name;
            shipInfo[giftCurrent].ipfs = gifts[i].ipfs;
            shipInfo[giftCurrent].archetype = gifts[i].archetype;
            shipInfo[giftCurrent].brand = gifts[i].brand;
            shipInfo[giftCurrent].bridgeIntegrity = gifts[i].strength;
            shipInfo[giftCurrent].hullIntegrity = gifts[i].strength;
            shipInfo[giftCurrent].engineIntegrity = gifts[i].strength;

            shipInfo[giftCurrent].fuel = gifts[i].strength;
            shipInfo[giftCurrent].origin = origin;

            IStarship(starships).mint(gifts[i].to, giftCurrent);
            IPlanets(planets).notifyEarthShipCreated();

            emit Gift(msg.sender, gifts[i].to, giftCurrent);
        }
    }

    /** Only owner can update ship */
    function updateShip(
        uint256 shipId,
        string memory _ipfs,
        string memory _archetype,
        string memory _brand,
        string memory _origin
    ) external onlyOwner {
        if (bytes(_ipfs).length > 0) shipInfo[shipId].ipfs = _ipfs;
        if (bytes(_archetype).length > 0) shipInfo[shipId].archetype = _archetype;
        if (bytes(_brand).length > 0) shipInfo[shipId].brand = _brand;
        if (bytes(_origin).length > 0) shipInfo[shipId].origin = _origin;

        emit ShipUpdated(shipId, block.timestamp);
    }

    function bridged(
        address _to,
        uint256 _shipId,
        Ship memory _ship
    ) external override {
        require(callers[msg.sender], 'Must be a caller');

        shipInfo[_shipId] = _ship;

        /** if the ship id does not exist on this chain, we must mint it */
        if (!IStarship(starships).exists(_shipId)) {
            IStarship(starships).mint(_to, _shipId);
            IPlanets(planets).notifyEarthShipCreated();
        }

        emit ShipUpdated(_shipId, block.timestamp);
    }

    /** Setup Ships
        @dev Allow to change ipfs for specific ships, this will only be used for gifts. Non gift ships use the baseURI set in starship.sol
        @param ids {uint256[]}
        @param archetype {string[]}
     */
    function setupShips(uint256[] calldata ids, string[] memory archetype) external onlyOwner {
        for (uint256 i = 0; i < ids.length; i++) {
            shipInfo[ids[i]].archetype = archetype[i];
        }
    }

    /** Buidl
        @dev Build starship using starship parts
        @param _ids {uint256}
     */
    function buidl(uint256[3] calldata _ids) external whenNotPaused {
        current = ISelector(selector).select();

        bool hull;
        bool bridge;
        bool engine;

        for (uint256 i = 0; i < 3; i++) {
            PartInfo memory partInfo = IStarshipPartsControl(starshipPartsControl).getPartInfo(
                _ids[i]
            );

            if (partInfo.typeOf == PartType.HULL) {
                hull = true;
                shipInfo[current].hullIntegrity = partInfo.strength;
            } else if (partInfo.typeOf == PartType.BRIDGE) {
                bridge = true;
                shipInfo[current].bridgeIntegrity = partInfo.strength;
            } else if (partInfo.typeOf == PartType.ENGINE) {
                engine = true;
                shipInfo[current].engineIntegrity = partInfo.strength;
            }

            IStarshipPartsControl(starshipPartsControl).usePart(_ids[i]);
        }

        require(hull && bridge && engine, 'buidl: Hull & Bridge & Engine required');

        shipInfo[current].name = string(bytes(abi.encodePacked('Ship #', current.toString())));
        shipInfo[current].ipfs = string(
            bytes(abi.encodePacked(baseUri, current.toString(), '.jpg'))
        );
        shipInfo[current].brand = 'Warp';
        shipInfo[current].origin = 'Polygon';

        IStarship(starships).mint(msg.sender, current);
        IPlanets(planets).notifyEarthShipCreated();

        emit Buidl(msg.sender, _ids, current);
    }

    /** Fuel up
        @dev Fuel up a starship that is owned by the user
        @param _shipId {uint256}
        @param _fuelTokenId {uint256}
        @param _amount {uint256}
     */
    function fuelUp(
        uint256 _shipId,
        uint256 _fuelTokenId,
        uint256 _amount
    ) external whenNotPaused {
        // Ensure starship exist, msg.sender is owner, and msg.sender owns the fuelToken
        require(
            IStarship(starships).ownerOf(_shipId) == msg.sender,
            'FuelUp: Can not fuel up anothers ship!'
        );
        require(
            IStarshipParts(starshipParts).ownerOf(_fuelTokenId) == msg.sender,
            'FuelUp: You are not the owner of this fuel'
        );

        // Ensure part type is fuel, and it has enough strength
        PartInfo memory partInfo = IStarshipPartsControl(starshipPartsControl).getPartInfo(
            _fuelTokenId
        );
        require(partInfo.typeOf == PartType.FUEL, 'FuelUp: Token type must be fuel');
        require(_amount <= partInfo.strength, 'FuelUp: not enough fuel');

        // use Fuel will burn the NFT if it's fully expended
        IStarshipPartsControl(starshipPartsControl).useFuel(_fuelTokenId, _amount);
        shipInfo[_shipId].fuel += _amount;

        // Emit
        emit FuelUp(msg.sender, _shipId, _fuelTokenId, _amount);
        emit ShipUpdated(_shipId, block.timestamp);
    }

    function experience(
        uint256 _shipId,
        uint256 _amount,
        bool _add
    ) external override {
        require(callers[msg.sender], 'Only caller');

        if (_add) shipInfo[_shipId].experience += _amount;
        else if (!_add) shipInfo[_shipId].experience -= _amount;

        emit ShipUpdated(_shipId, block.timestamp);
    }

    function damage(
        uint256 _shipId,
        uint256 _valueHull,
        uint256 _valueBridge,
        uint256 _valueEngine,
        bool _repair
    ) external override whenNotPaused {
        require(callers[msg.sender], 'Only caller');
        require(IStarship(starships).exists(_shipId), 'Cannot damage an invisible ship!');

        if (_repair) {
            // Hull
            if (_valueHull > shipInfo[_shipId].hullDmg) shipInfo[_shipId].hullDmg = 0;
            else shipInfo[_shipId].hullDmg -= _valueHull;

            // Bridge
            if (_valueEngine > shipInfo[_shipId].bridgeDmg) shipInfo[_shipId].bridgeDmg = 0;
            else shipInfo[_shipId].bridgeDmg -= _valueBridge;

            // Engine
            if (_valueBridge > shipInfo[_shipId].engineDmg) shipInfo[_shipId].engineDmg = 0;
            else shipInfo[_shipId].engineDmg -= _valueEngine;

            emit Damage(_shipId, _valueHull, _valueBridge, _valueEngine);
        } else {
            shipInfo[_shipId].hullDmg += _valueHull;
            shipInfo[_shipId].bridgeDmg += _valueBridge;
            shipInfo[_shipId].engineDmg += _valueEngine;

            // If dmg is > then integrity revert.
            require(
                shipInfo[_shipId].hullDmg <= shipInfo[_shipId].hullIntegrity &&
                    shipInfo[_shipId].engineDmg <= shipInfo[_shipId].engineIntegrity &&
                    shipInfo[_shipId].bridgeDmg <= shipInfo[_shipId].bridgeIntegrity,
                'Can not repair more then integrity value.'
            );

            emit Repair(_shipId, _valueHull, _valueBridge, _valueEngine);
        }

        emit ShipUpdated(_shipId, block.timestamp);
    }

    function upgradePartInfo(
        uint256 _shipId,
        uint256 _valueHull,
        uint256 _valueBridge,
        uint256 _valueEngine
    ) external {
        require(callers[msg.sender], 'Not a caller');
        shipInfo[_shipId].hullIntegrity += _valueHull;
        shipInfo[_shipId].bridgeIntegrity += _valueBridge;
        shipInfo[_shipId].engineIntegrity += _valueEngine;

        emit UpgradeParts(_shipId, _valueHull, _valueBridge, _valueEngine);
        emit ShipUpdated(_shipId, block.timestamp);
    }

    function isDamaged(uint256 _shipId) external view override returns (bool) {
        Ship memory ship = shipInfo[_shipId];

        uint256 hull = ship.hullIntegrity - ship.hullDmg;
        uint256 bridge = ship.bridgeIntegrity - ship.bridgeDmg;
        uint256 engine = ship.engineIntegrity - ship.engineDmg;

        /** 250 magic number = minimum always. */
        if ((hull < 250) || (bridge < 250) || (engine < 250)) {
            return true;
        } else return false;
    }

    /** Drain fuel
        @dev When traveling from planet X to planet Y, the fuel is drained on a starship
        @param _shipId {uint256}
     */
    function drainFuel(uint256 _shipId) external override {
        require(msg.sender == planets, 'Can not drain fuel of ship');

        emit DrainFuel(IStarship(starships).ownerOf(_shipId), _shipId, shipInfo[_shipId].fuel);

        shipInfo[_shipId].fuel = 0;

        emit ShipUpdated(_shipId, block.timestamp);
    }

    /** Name ship (EXTRA FUNCTION FOR FUN :)
        @dev Allow a user to name their starship. The starship name stays with it until
        @param _shipId {uint256}
        @param _name {string}
     */
    function name(uint256 _shipId, string memory _name) external {
        require(IStarship(starships).ownerOf(_shipId) == msg.sender, 'You are not the token owner');

        shipInfo[_shipId].name = _name;

        emit ShipNamed(msg.sender, _shipId, _name);
        emit ShipUpdated(_shipId, block.timestamp);
    }

    /** === Owner Functions === */

    /** @notice setStarshipPart */
    function setStarshipPart(address _address) external onlyOwner {
        starshipParts = _address;
    }

    /** @notice setStarshipPartsControl */
    function setStarshipPartsControl(address _address) external onlyOwner {
        starshipPartsControl = _address;
    }

    /** @notice setPlanets */
    function setPlanets(address _address) external onlyOwner {
        planets = _address;
    }

    /** @notice setStarships */
    function setStarships(address _address) external onlyOwner {
        starships = _address;
    }

    /** @notice setSelector */
    function setSelector(address _address) external onlyOwner {
        selector = _address;
    }

    /** @notice setCallers for repair upgrades and damages. */
    function setCaller(address _address, bool caller) external onlyOwner {
        callers[_address] = caller;
    }

    /** @notice change origin */
    function setOrigin(string calldata _origin) external onlyOwner {
        origin = _origin;
    }

    /** @notice change origin */
    function setBaseUri(string calldata _baseUri) external onlyOwner {
        baseUri = _baseUri;
    }

    /** @notice change origin */
    function setGiftCurrent(uint256 _giftCurrent) external onlyOwner {
        giftCurrent = _giftCurrent;
    }

    /** === GETTERS === */

    /** @notice get details about ship */
    function getShip(uint256 _shipId) external view override returns (Ship memory) {
        return shipInfo[_shipId];
    }

    /** @notice gets planet id and name of where ship is currently docked */
    function getShipPlanet(uint256 _shipId)
        external
        view
        override
        returns (uint256, string memory)
    {
        Docked memory info = IPlanets(planets).getDockedInfo(_shipId);
        PlanetInfo memory planet = IPlanets(planets).getPlanetInfo(info.planetId);
        return (info.planetId, planet.name);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Strings.sol)

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

// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >0.8.0;

import '@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol';

interface IStarshipParts is IERC721EnumerableUpgradeable {
    function tokenURI(uint256 tokenId) external view returns (string memory);

    function mint(address _to, uint256 _tokenId) external;

    function burn(uint256 _tokenId) external;

    function exists(uint256 _tokenId) external view returns (bool);
}

// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >0.8.0;

/* ======== Structs ======== */
enum PartType {
    BRIDGE,
    HULL,
    ENGINE,
    FUEL
}

struct PartInfo {
    uint256 strength;
    PartType typeOf;
}

interface IStarshipPartsControl {
    function buildPart(address _to, uint256 _paid) external returns (uint256);

    function usePart(uint256 _tokenId) external;

    function getPartInfo(uint256 _tokenId) external view returns (PartInfo memory);

    function useFuel(uint256 _tokenId, uint256 _amount) external;

    function getMinimumValue() external view returns (uint256);

    function getStringPartType(PartType typeOf) external view returns (string memory);

    function getCounter() external view returns (uint256);

    function getPartCount(PartType typeOf) external view returns (uint256);

    function buildFuel(address _to, uint256 _strength) external;

    function buildSpecificPart(
        address _to,
        uint256 _paid,
        PartType _part
    ) external returns (uint256);

    function buildMultipleSpecificParts(
        address[] calldata _to,
        uint256[] calldata _paid,
        PartType[] calldata _part
    ) external returns (uint256[] calldata);
}

// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >0.8.0;

/* ======== Structs ======== */
struct PlanetInfo {
    string name;
    string ipfs;
    string galaxy;
    address staking;
    address sWarp;
    uint256 shipCount;
    bool exists;
}

struct Docked {
    uint256 arrivalTime;
    uint256 planetId;
    uint256 fuelUsed;
}

interface IPlanets {
    function onPlanet(address _owner, uint256 _planetId) external view returns (bool);

    function numberOfPlanets() external view returns (uint256);

    function getPlanetInfo(uint256 planetId) external view returns (PlanetInfo memory);

    function getDockedInfo(uint256 shipId) external view returns (Docked memory);

    function notifyEarthShipCreated() external;
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

interface ISelector {
    function select() external returns (uint256);
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