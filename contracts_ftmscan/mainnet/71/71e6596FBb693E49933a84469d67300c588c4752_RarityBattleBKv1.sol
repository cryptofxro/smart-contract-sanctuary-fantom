//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IRarity.sol";
import "./interfaces/IRarityBattleScar.sol";
import "./interfaces/IRarityBattleKey.sol";

contract RarityBattleBKv1 is Ownable {
    using Strings for uint256;

    IRarity constant rm = IRarity(0xce761D788DF608BD21bdd59d6f4B54b2e27F25Bb);
    IRarityBattleKey rbk;
    IRarityBattleScar rbs;

    uint256 constant LEVEL_REQ = 3;
    uint256 public constant SUMMONER_CAP = 1000;

    uint256 private constant SECONDS_BETWEEN_TAUNTS = 60;
    uint256 private constant ENTRY_FEE = 1e18;
    uint256 private constant _firstReward = 100e18;
    uint256 private constant _secondReward = 10e18;
    uint256 private constant _thirdReward = 1e18;

    uint256 private constant _secondRewardLevel = 10;
    uint256 private constant _thirdRewardLevel = 100;

    string private scarType = "Bare Knuckle Round 1";
    uint256 private _lastTauntTime;

    uint256 public enteredCount;
    uint256 public remainingCount = SUMMONER_CAP;

    mapping(uint256 => uint256) private _summonerHp;
    mapping(uint256 => uint256) public arenaIndex;

    event BattleEntered(uint256 indexed summonerId);

    constructor(address rbkAddress, address rbsAddress) {
        rbk = IRarityBattleKey(rbkAddress);
        rbs = IRarityBattleScar(rbsAddress);
    }

    function _isApprovedOrOwnerOfSummoner(uint256 _summonerId)
        internal
        view
        returns (bool)
    {
        return
            rm.getApproved(_summonerId) == msg.sender ||
            rm.ownerOf(_summonerId) == msg.sender ||
            rm.isApprovedForAll(rm.ownerOf(_summonerId), msg.sender);
    }

    function gameState() public view returns (string memory) {
        if (enteredCount < SUMMONER_CAP) {
            return "Waiting for summoners";
        } else if (remainingCount > 1) {
            return "Battle in progress";
        } else {
            return "Battle finished";
        }
    }

    function healthCheck(uint256 _summonerId) public view returns (uint256) {
        return _summonerHp[_summonerId];
    }

    function enter(uint256[] calldata _summonerIds) public payable {
        require(
            msg.value >= (ENTRY_FEE * _summonerIds.length),
            "You must pay the entry fee."
        );
        for (uint256 i; i < _summonerIds.length; i++) {
            uint256 _sId = _summonerIds[i];
            require(_summonerHp[_sId] == 0, "Summoner already entered."); // Don't be evil
            (, , , uint256 level) = rm.summoner(_sId);
            require(
                level >= LEVEL_REQ,
                "This summoner is not experienced enough to enter this battle."
            );
            require(enteredCount < SUMMONER_CAP, "The battle is full.");

            _summonerHp[_sId] = 100;
            arenaIndex[enteredCount] = _sId;
            enteredCount++;
            emit BattleEntered(_sId);
        }
    }

    function randomSummonerIndex(uint256 seed) internal view returns (uint256) {
        uint256 val = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    msg.sender,
                    remainingCount,
                    seed
                )
            )
        ) % remainingCount;

        return val;
    }

    function canTaunt(uint256 _summonerIdAsSeed) internal view returns (bool) {
        if (_lastTauntTime == 0) {
            return true;
        }

        uint256 _randomTimeId = uint256(
            keccak256(
                abi.encodePacked(
                    (block.timestamp + _summonerIdAsSeed).toString()
                )
            )
        );

        uint256 _tauntTime = (_randomTimeId % 10) +
            _lastTauntTime +
            SECONDS_BETWEEN_TAUNTS;

        if (block.timestamp > _tauntTime) {
            return true;
        }
        return false;
    }

    function taunt(uint256 summonerId) public returns (bool) {
        require(
            _isApprovedOrOwnerOfSummoner(summonerId),
            "You are not allowed to taunt with this summoner."
        );
        require(enteredCount == SUMMONER_CAP, "The battle is not started.");
        require(
            _summonerHp[summonerId] > 0,
            "The summoner is not in the battle."
        );
        require(remainingCount > 1, "The battle has ended.");
        require(canTaunt(summonerId), "You cannot taunt now.");

        uint256 _s1idx = randomSummonerIndex(summonerId);
        uint256 _s2idx = randomSummonerIndex(summonerId + 1);
        uint8 j = 2;
        while (_s1idx == _s2idx) {
            _s2idx = randomSummonerIndex(summonerId + j);
            j++;
        }

        if (_s1idx != _s2idx) {
            _lastTauntTime = block.timestamp;
            uint256 _s1Id = arenaIndex[_s1idx];
            uint256 _s2Id = arenaIndex[_s2idx];
            uint256 _s1Scars = rbs.balanceOf(_s1Id);
            uint256 _s2Scars = rbs.balanceOf(_s2Id);
            if (_s1Scars > _s2Scars) {
                battleImpact(_s1Id, _s2Id, _s2idx, summonerId);
            } else {
                battleImpact(_s2Id, _s1Id, _s1idx, summonerId);
            }
            return true;
        }
        return false;
    }

    function battleImpact(
        uint256 _winnerId,
        uint256 _loserId,
        uint256 _loserArenaIndex,
        uint256 _summonerId
    ) internal {
        _summonerHp[_loserId] -= 99;
        rbs.mintScar(_loserId, _winnerId, scarType);
        rbs.mintScar(_winnerId, _loserId, scarType);
        rbs.mintScar(_winnerId, _summonerId, scarType);
        uint256 _endSummonerId = arenaIndex[remainingCount - 1];
        arenaIndex[_loserArenaIndex] = _endSummonerId;
        remainingCount--;
        if (remainingCount == 1) {
            rbk.mint(rm.ownerOf(_winnerId), _firstReward);
            rbk.mint(rm.ownerOf(_loserId), _secondReward);
        } else if (remainingCount < _secondRewardLevel) {
            rbk.mint(rm.ownerOf(_loserId), _secondReward);
        } else if (remainingCount < _thirdRewardLevel) {
            rbk.mint(rm.ownerOf(_loserId), _thirdReward);
        }
    }

    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success);
    }
}

// SPDX-License-Identifier: MIT

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
        _setOwner(_msgSender());
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
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.10;

interface IRarity {
    // ERC721
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function approve(address to, uint256 tokenId) external;

    function getApproved(uint256 tokenId)
        external
        view
        returns (address operator);

    function setApprovalForAll(address operator, bool _approved) external;

    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    // Rarity
    event summoned(address indexed owner, uint256 _class, uint256 summoner);
    event leveled(address indexed owner, uint256 level, uint256 summoner);

    function next_summoner() external returns (uint256);

    function name() external returns (string memory);

    function symbol() external returns (string memory);

    function xp(uint256) external view returns (uint256);

    function adventurers_log(uint256) external view returns (uint256);

    function class(uint256) external view returns (uint256);

    function level(uint256) external view returns (uint256);

    function adventure(uint256 _summoner) external;

    function spend_xp(uint256 _summoner, uint256 _xp) external;

    function level_up(uint256 _summoner) external;

    function summoner(uint256 _summoner)
        external
        view
        returns (
            uint256 _xp,
            uint256 _log,
            uint256 _class,
            uint256 _level
        );

    function summon(uint256 _class) external;

    function xp_required(uint256 curent_level)
        external
        pure
        returns (uint256 xp_to_next_level);

    function tokenURI(uint256 _summoner) external view returns (string memory);

    function classes(uint256 id)
        external
        pure
        returns (string memory description);
}

// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.10;

interface IRarityBattleScar {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function MINTER_ADMIN_ROLE() external view returns (bytes32);

    function MINTER_ROLE() external view returns (bytes32);

    function approve(
        uint256 from,
        uint256 to,
        uint256 tokenId
    ) external;

    function balanceOf(uint256 owner) external view returns (uint256);

    function getApproved(uint256 tokenId) external view returns (uint256);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function hasRole(bytes32 role, address account)
        external
        view
        returns (bool);

    function isApprovedForAll(uint256 owner, uint256 operator)
        external
        view
        returns (bool);

    function mintScar(
        uint256 inflictorId,
        uint256 receiverId,
        string memory method
    ) external returns (uint256);

    function name() external view returns (string memory);

    function owner() external view returns (address);

    function ownerOf(uint256 tokenId) external view returns (uint256);

    function renounceOwnership() external;

    function renounceRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function rm() external view returns (address);

    function safeTransferFrom(
        uint256 from,
        uint256 to,
        uint256 tokenId
    ) external;

    function scars(uint256)
        external
        view
        returns (
            uint256 inflictor,
            uint256 receiver,
            string memory method,
            uint256 timestamp
        );

    function setApprovalForAll(
        uint256 from,
        uint256 operator,
        bool approved
    ) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function symbol() external view returns (string memory);

    function tokenByIndex(uint256 index) external view returns (uint256);

    function tokenOfOwnerByIndex(uint256 owner, uint256 index)
        external
        view
        returns (uint256);

    function tokenURI(uint256 _tokenId) external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transferFrom(
        uint256 from,
        uint256 to,
        uint256 tokenId
    ) external;

    function transferOwnership(address newOwner) external;
}

// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.10;

interface IRarityBattleKey {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function MINTER_ADMIN_ROLE() external view returns (bytes32);

    function MINTER_ROLE() external view returns (bytes32);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function burn(address _account, uint256 _amount) external;

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function hasRole(bytes32 role, address account)
        external
        view
        returns (bool);

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool);

    function mint(address _to, uint256 _amount) external;

    function name() external view returns (string memory);

    function owner() external view returns (address);

    function renounceOwnership() external;

    function renounceRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferOwnership(address newOwner) external;
}

// SPDX-License-Identifier: MIT

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