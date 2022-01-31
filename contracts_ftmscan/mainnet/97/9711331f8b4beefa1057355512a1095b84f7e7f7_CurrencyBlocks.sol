// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./helpers/ICurrencyBlocksTokenURIProcessor.sol";
import "../CryptoBlocksERC1155Upgradeable.sol";
import "./lib/CurrencyBlocksConstants.sol";

/** @title CurrencyBlocks
 * @dev Fungible currency (item) blocks such as materials, key items, etc
 */
contract CurrencyBlocks is Initializable, UUPSUpgradeable, CryptoBlocksERC1155Upgradeable {

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __AccessControlEnumerable_init_unchained();
        __ERC1155_init_unchained("");
        __ERC1155Burnable_init_unchained();
        __ERC1155Supply_init_unchained();
        __ERC1155AfterTokenTransfer_init_unchained();
        __CryptoBlocks_init_unchained();
        __CryptoBlocksERC1155_init_unchained("Cryptoblocks: Currencies", "CBLOCK");
        __CurrencyBlocks_init_unchained();
    }

    function __CurrencyBlocks_init_unchained() internal initializer {}

    function _authorizeUpgrade(address) internal override onlyRole(AccessControlConstants.ADMIN_ROLE) {}

    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        string memory _tokenURI = _tokenURIs[tokenId];

        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(baseURI, _tokenURI));
        }

        return ICurrencyBlocksTokenURIProcessor(_addressMapping[CryptoBlocksConstants.ADDR_MAPPING_TOKEN_URI_PROCESSOR]).getCurrencyBlocksTokenURI(tokenId);
    }

    /**
     * @dev Easy add function for new currency with max supply of type(uint256).max
     */
    function setCurrency(uint256 tokenId, uint256 categoryId, uint256 value, uint256 valuePc, uint256 valueId, uint256 element, string calldata name, string calldata description) external onlyRole(AccessControlConstants.ADMIN_ROLE) {
        _attributes[tokenId][CurrencyBlocksConstants.UINT_CATEGORY] = categoryId;
        _attributes[tokenId][CurrencyBlocksConstants.UINT_ELEMENT] = element;
        _attributes[tokenId][CurrencyBlocksConstants.UINT_VALUE] = value;
        _attributes[tokenId][CurrencyBlocksConstants.UINT_VALUE_PC] = valuePc;
        _attributes[tokenId][CurrencyBlocksConstants.UINT_VALUE_ID] = valueId;
        _attributesString[tokenId][CurrencyBlocksConstants.STRING_NAME] = name;
        _attributesString[tokenId][CurrencyBlocksConstants.STRING_DESCRIPTION] = description;
        _attributes[tokenId][CurrencyBlocksConstants.UINT_MAX_SUPPLY] = type(uint256).max;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC2981 {

    /// @notice Called with the sale price to determine how much royalty
    //          is owed and to whom.
    /// @param _tokenId - the NFT asset queried for royalty information
    /// @param _salePrice - the sale price of the NFT asset specified by _tokenId
    /// @return receiver - address of who should be sent the royalty payment
    /// @return royaltyAmount - the royalty payment amount for _salePrice
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (
        address receiver,
        uint256 royaltyAmount
    );
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC1155SupplyUpgradeable {
    function totalSupply(uint256) external view returns(uint256);
    function exists(uint256) external view returns(bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC1155EnumerableUpgradeable {
    function getAccountTokensCount(address) external view returns(uint256);
    function getAccountTokensByIndex(address, uint256) external view returns(uint256);
    function getAccountTokensPaginated(address, uint256, uint256) external view returns(uint256[] memory, uint256[] memory, uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC1155BurnableUpgradeable {
    function burn(address, uint256, uint256) external;
    function burnBatch(address, uint256[] memory, uint256[] memory) external;
}

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "./ERC1155AfterTokenTransferUpgradeable.sol";
import "./IERC1155EnumerableUpgradeable.sol";

abstract contract ERC1155EnumerableUpgradeable is ERC1155AfterTokenTransferUpgradeable, IERC1155EnumerableUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    mapping(address => EnumerableSetUpgradeable.UintSet) internal _accountTokens;

    function __ERC1155Enumerable_init() internal initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __ERC1155AfterTokenTransfer_init_unchained();
        __ERC1155Enumerable_init_unchained();
    }

    function __ERC1155Enumerable_init_unchained() internal initializer {}

    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._afterTokenTransfer(operator, from, to, ids, amounts, data);
        _updateAccountsTokens(from, to, ids);
    }

    /**
     * @dev After any transfer, checks if from and to accountTokens should be updated
     * this function can be very expensive, it reads the storage a lot, be careful why you make use of this.
     *
     * @param from the address that lost tokens
     * @param to the address that gained tokens
     * @param ids the ids that have been transferred
     */
    function _updateAccountsTokens(
        address from,
        address to,
        uint256[] memory ids
    ) internal virtual {
        bool checkAddressFrom = from != address(0);
        bool checkAddressTo = to != address(0);

        for (uint256 i; i < ids.length; i++) {
            // if from has balance 0, remove from accountTokens
            if (checkAddressFrom && balanceOf(from, ids[i]) == 0) {
                _accountTokens[from].remove(ids[i]);
            }

            // here we always have to try to add it if the balance > 0
            // we can not use amounts[i] because a transferBatch could contain
            // twice the same id, and amounts[i] would never match the current balance
            // we still have to check balance though, because transfers can be of 0 (yes...)
            if (checkAddressTo && balanceOf(to, ids[i]) > 0) {
                _accountTokens[to].add(ids[i]);
            }
        }
    }

    /**
     * @dev get the number of different tokens own by an account
     *
     * @param account the account address
     */
    function getAccountTokensCount(address account)
    public
    view
    virtual override
    returns (uint256)
    {
        return _accountTokens[account].length();
    }

    /**
     * @dev get the token owned at index {index} of account
     * This is using EnumerableSet so order can change at any time with inserts and removals     *
     *
     * @param account the account address
     * @param index the index in the list
     */
    function getAccountTokensByIndex(address account, uint256 index)
    public
    view
    virtual override
    returns (uint256)
    {
        return _accountTokens[account].at(index);
    }

    /**
     * @dev Get a paginated list of an account tokens
     * This is a pretty expensive function and SHOULD be only used externally
     * or if you really know what you're doing.
     *
     * @param account The account we want the list of tokens
     * @param cursor Index to start at
     * @param limit how many we want per page
     *
     * @return tokenIds the token Ids
     * @return amounts the token balances
     * @return nextCursor next cursor to use
     */
    function getAccountTokensPaginated(
        address account,
        uint256 cursor,
        uint256 limit
    )
    public
    view
    virtual override
    returns (
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        uint256 nextCursor
    )
    {
        uint256 itemsCount = getAccountTokensCount(account);
        uint256 length = limit;
        if (length > itemsCount - cursor) {
            length = itemsCount - cursor;
        }

        tokenIds = new uint256[](length);
        amounts = new uint256[](length);
        for (uint256 i; i < length; i++) {
            tokenIds[i] = getAccountTokensByIndex(account, cursor + i);
            amounts[i] = balanceOf(account, tokenIds[i]);
        }

        return (tokenIds, amounts, cursor + length);
    }
    uint256[50] private __gap;
}

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract ERC1155AfterTokenTransferUpgradeable is Initializable, ERC1155Upgradeable {
    function __ERC1155AfterTokenTransfer_init() internal initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __ERC1155AfterTokenTransfer_init_unchained();
    }

    function __ERC1155AfterTokenTransfer_init_unchained() internal initializer {
    }
    /**
     * @dev Hook that is called after any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     */
    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    function _mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual override {
        super._mint(account, id, amount, data);
        _afterTokenTransfer(
            _msgSender(),
            address(0),
            account,
            _asSingletonArrayAfterTransfer(id),
            _asSingletonArrayAfterTransfer(amount),
            data
        );
    }

    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._mintBatch(to, ids, amounts, data);
        _afterTokenTransfer(_msgSender(), address(0), to, ids, amounts, data);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        super.safeTransferFrom(from, to, id, amount, data);
        _afterTokenTransfer(
            _msgSender(),
            from,
            to,
            _asSingletonArrayAfterTransfer(id),
            _asSingletonArrayAfterTransfer(amount),
            data
        );
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
        _afterTokenTransfer(_msgSender(), from, to, ids, amounts, data);
    }

    function _burn(
        address account,
        uint256 id,
        uint256 amount
    ) internal virtual override {
        super._burn(account, id, amount);
        _afterTokenTransfer(
            _msgSender(),
            account,
            address(0),
            _asSingletonArrayAfterTransfer(id),
            _asSingletonArrayAfterTransfer(amount),
            ""
        );
    }

    function _burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual override {
        super._burnBatch(account, ids, amounts);
        _afterTokenTransfer(
            _msgSender(),
            account,
            address(0),
            ids,
            amounts,
            ""
        );
    }

    // needs to give this name because solidity compilers thinks
    // I want to override function from parent
    function _asSingletonArrayAfterTransfer(uint256 element)
    private
    pure
    returns (uint256[] memory)
    {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

library CryptoBlocksConstants {
    /**
     * Attribute Integer IDs
     */
    uint256 public constant UINT_ID = 0;
    uint256 public constant UINT_VERSION = 1;       // operators will check what version user has. if update is needed they have to go to update contract
    uint256 public constant UINT_CATEGORY = 2;
    uint256 public constant UINT_SUBCATEGORY = 3;
    uint256 public constant UINT_ORIGIN_TIME = 4;
    // 5, 6, 7, 8, 9
    uint256 public constant UINT_RENEW_TIME = 5;
    uint256 public constant UINT_ORIGIN_CHAIN_ID = 6;
    uint256 public constant UINT_CHAIN_ID = 7;      // current chain id
    uint256 public constant UINT_MASTER_ID = 8;     // master id across all chains
    uint256 public constant UINT_BRIDGE_LOCKED = 9; // wrapped in bridge contract
    uint256 public constant UINT_DBID = 10;
    uint256 public constant UINT_TRANSFER_LOCK = 11;
    uint256 public constant UINT_BOUND = 12;
    uint256 public constant UINT_PRICE = 20;        // for minting
    uint256 public constant UINT_MAX_SUPPLY = 21;   // for minting currency
    uint256 public constant UINT_BUYABLE = 22;      // default is 0 which is false

    /**
     * Address Data IDs
     */
    uint256 public constant ADDR_DATA_WHITELIST = 11;

    /**
     * Address Mapping IDs
     */
    uint256 public constant ADDR_MAPPING_ROYALTY_RECEIVER = 10;
    uint256 public constant ADDR_MAPPING_TOKEN_URI_PROCESSOR = 11;

    /**
     * Uint Mapping IDs
     */
    uint256 public constant UINT_MAPPING_CHAIN_ID = 1;
    uint256 public constant UINT_MAPPING_ROYALTY_AMOUNT = 10;   // royalties amount / 1000. ex: 1 = 0.1%
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

library AccessControlConstants {
    /**
     * Access Control Roles
     */
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR"); // 523a704056dcd17bcf83bed8b68c59416dac1119be77755efe3bde0a64e46e0c
    bytes32 public constant MINTER_ROLE = keccak256("MINTER");     // f0887ba65ee2024ea881d91b74c2450ef19e1557f03bed3ea9f16b037cbe2dc9
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");       // df8b4c520ffe197c5343c6f5aec59570151ef9a492f2c624fd45ddde6135ec42
    bytes32 public constant WITHDRAW_ROLE = keccak256("WITHDRAW"); // 7a8dc26796a1e50e6e190b70259f58f6a4edd5b22280ceecc82b687b8e982869
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

/** @title CurrencyBlocksConstants
 */
library CurrencyBlocksConstants {
    /**
     * Attribute Integer IDs
     */
    uint256 public constant UINT_DBID = 10;         // unused since there is no need for a db
    uint256 public constant UINT_CATEGORY = 2;
    uint256 public constant UINT_ELEMENT = 13;
    uint256 public constant UINT_PRICE = 20;
    uint256 public constant UINT_MAX_SUPPLY = 21;
    uint256 public constant UINT_BUYABLE = 22;
    uint256 public constant UINT_VALUE = 100;       // value of items
    uint256 public constant UINT_VALUE_PC = 101;    // value percent of items
    uint256 public constant UINT_VALUE_ID = 102;    // for items with id as value
    uint256 public constant UINT_STAT_ID = 103;     // for boost items or items that deal with stats
    uint256 public constant UINT_UNIT_ID = 1000;    // unit id associated with unit mint ticket, monster mint ticket, and monster essence
    uint256 public constant UINT_EQUIP_TYPE = 1000; // weapon, helmet, armor, boots, necklace, ring


    /**
     * Attribute String IDs
     */
    uint256 public constant STRING_NAME = 1;
    uint256 public constant STRING_DESCRIPTION = 2;

    /**
     * Category IDs
     */
    uint256 public constant CATEGORY_STAMINA = 1;
    uint256 public constant CATEGORY_MINT_TICKET = 10;           // any unit
    uint256 public constant CATEGORY_HERO_FREE_TICKET = 11;      // free mint ticket. limited attributes
    uint256 public constant CATEGORY_HERO_MINT_TICKET = 12;      // discount ticket. uses value
    uint256 public constant CATEGORY_MONSTER_FREE_TICKET = 13;   // free mint ticket. limited attributes
    uint256 public constant CATEGORY_MONSTER_MINT_TICKET = 14;
    uint256 public constant CATEGORY_HERO_CLASS_TICKET = 20;    // uses value
    uint256 public constant CATEGORY_HERO_ELEMENT_TICKET = 30;  // uses value
    uint256 public constant CATEGORY_HERO_BADGE_TICKET = 50;    // uses value
    uint256 public constant CATEGORY_EXP_ITEM = 60;
    uint256 public constant CATEGORY_MODIFIER_ITEM = 400;       // uses modifier contract which has which stats it increases
    uint256 public constant CATEGORY_DROP_BOOST = 600;          // uses value with 10000 base
    uint256 public constant CATEGORY_UV_ITEM = 700;             // uses statId and value
    uint256 public constant CATEGORY_EQUIP_EXP_ITEM = 1000;
    uint256 public constant CATEGORY_EQUIP_DUST = 1200;
    uint256 public constant CATEGORY_BOND_ITEM = 1300;          // uses value
    uint256 public constant CATEGORY_PROMOTION_ITEM = 1500;     // uses value to identify
    uint256 public constant CATEGORY_ENHANCEMENT_ITEM = 1600;   // uses element to identify
    uint256 public constant CATEGORY_MONSTER_ESSENCE = 3010;
    uint256 public constant CATEGORY_MATERIAL = 10000;          // general crafting material without any other uses
    uint256 public constant CATEGORY_RECIPE = 20000;            // uses value

    /**
     * IDs
     */

    // stamina
    uint256 public constant ID_STAMINA = 1;                 // core currency of game
    uint256 public constant ID_BLOCKS_TOKEN = 2;            // possibly other currency like gold
    // hero int tickets
    uint256 public constant ID_HERO_FREE_TICKET = 11;        // free mint ticket. Limited attributes
    uint256 public constant ID_HERO_MINT_TICKET = 12;        // earned in game. no restrictions
    uint256 public constant ID_HERO_DISCOUNT_10_TICKET = 15; // hero discount ticket 10% off
    uint256 public constant ID_HERO_DISCOUNT_20_TICKET = 16; // hero discount ticket 20% off
    uint256 public constant ID_HERO_DISCOUNT_30_TICKET = 17; // hero discount ticket 30% off
    uint256 public constant ID_HERO_DISCOUNT_40_TICKET = 18; // hero discount ticket 40% off
    uint256 public constant ID_HERO_DISCOUNT_50_TICKET = 19; // hero discount ticket 50% off
    uint256 public constant ID_HERO_WARRIOR_TICKET = 20;    // hero warrior ticket
    uint256 public constant ID_HERO_KNIGHT_TICKET = 21;     // hero knight ticket
    uint256 public constant ID_HERO_ROGUE_TICKET = 22;      // hero rogue ticket
    uint256 public constant ID_HERO_MAGE_TICKET = 23;       // hero mage ticket
    uint256 public constant ID_HERO_RANGER_TICKET = 24;     // hero ranger ticket
    uint256 public constant ID_HERO_HEALER_TICKET = 25;     // hero healer ticket

    // element tickets
    uint256 public constant ID_HERO_NEUTRAL_TICKET = 30;
    uint256 public constant ID_HERO_FIRE_TICKET = 31;
    uint256 public constant ID_HERO_WATER_TICKET = 32;
    uint256 public constant ID_HERO_NATURE_TICKET = 33;
    uint256 public constant ID_HERO_EARTH_TICKET = 34;
    uint256 public constant ID_HERO_WIND_TICKET = 35;
    uint256 public constant ID_HERO_ICE_TICKET = 36;
    uint256 public constant ID_HERO_LIGHTNING_TICKET = 37;
    uint256 public constant ID_HERO_LIGHT_TICKET = 38;
    uint256 public constant ID_HERO_DARK_TICKET = 39;
    uint256 public constant ID_HERO_METAL_TICKET = 40;
    uint256 public constant ID_HERO_NETHER_TICKET = 41;
    uint256 public constant ID_HERO_AETHER_TICKET = 42;

    // badge tickets
    uint256 public constant ID_HERO_BRONZE_BADGE_TICKET = 50;
    uint256 public constant ID_HERO_SILVER_BADGE_TICKET = 51;
    uint256 public constant ID_HERO_GOLD_BADGE_TICKET = 52;
    uint256 public constant ID_HERO_RAINBOW_BADGE_TICKET = 53;

    // exp items - one for each element
    // fire, water, nature, earth, wind, ice, lightning, light, dark, metal, nether, aether
    uint256 public constant ID_EXP_PIECE_COMMON = 60;   // basic exp item. provides 10 exp
    uint256 public constant ID_EXP_PIECE_UNCOMMON = 61;
    uint256 public constant ID_EXP_PIECE_RARE = 62;
    uint256 public constant ID_EXP_PIECE_EPIC = 63;
    uint256 public constant ID_EXP_PIECE_LEGENDARY = 64;
    uint256 public constant ID_EXP_PIECE_MYTHIC = 65;
    uint256 public constant ID_EXP_ITEM_COMMON = 70;    // 300 exp
    uint256 public constant ID_EXP_ITEM_UNCOMMON = 71;  // 900 exp
    uint256 public constant ID_EXP_ITEM_RARE = 72;      // 2700 exp
    uint256 public constant ID_EXP_ITEM_EPIC = 73;      // 8100 exp
    uint256 public constant ID_EXP_ITEM_LEGENDARY = 74; // 24300 exp
    uint256 public constant ID_EXP_ITEM_MYTHIC = 75;    // 72900 exp

    uint256 public constant ID_FIRE_EXP_ITEM_COMMON = 80;
    uint256 public constant ID_FIRE_EXP_ITEM_UNCOMMON= 81;
    uint256 public constant ID_FIRE_EXP_ITEM_RARE = 82;
    uint256 public constant ID_FIRE_EXP_ITEM_EPIC = 83;
    uint256 public constant ID_FIRE_EXP_ITEM_LEGENDARY = 84;
    uint256 public constant ID_FIRE_EXP_ITEM_MYTHIC = 85;

    uint256 public constant ID_WATER_EXP_ITEM_10 = 90;
    uint256 public constant ID_WATER_EXP_ITEM_100 = 91;
    uint256 public constant ID_WATER_EXP_ITEM_1000 = 92;
    uint256 public constant ID_WATER_EXP_ITEM_10000 = 93;
    uint256 public constant ID_WATER_EXP_ITEM_100000 = 94;
    uint256 public constant ID_WATER_EXP_ITEM_1000000 = 95;

    uint256 public constant ID_NATURE_EXP_ITEM_10 = 100;
    uint256 public constant ID_NATURE_EXP_ITEM_100 = 101;
    uint256 public constant ID_NATURE_EXP_ITEM_1000 = 102;
    uint256 public constant ID_NATURE_EXP_ITEM_10000 = 103;
    uint256 public constant ID_NATURE_EXP_ITEM_100000 = 104;
    uint256 public constant ID_NATURE_EXP_ITEM_1000000 = 105;

    uint256 public constant ID_EARTH_EXP_ITEM_10 = 110;
    uint256 public constant ID_EARTH_EXP_ITEM_100 = 111;
    uint256 public constant ID_EARTH_EXP_ITEM_1000 = 112;
    uint256 public constant ID_EARTH_EXP_ITEM_10000 = 113;
    uint256 public constant ID_EARTH_EXP_ITEM_100000 = 114;
    uint256 public constant ID_EARTH_EXP_ITEM_1000000 = 115;

    uint256 public constant ID_WIND_EXP_ITEM_10 = 120;
    uint256 public constant ID_WIND_EXP_ITEM_100 = 121;
    uint256 public constant ID_WIND_EXP_ITEM_1000 = 122;
    uint256 public constant ID_WIND_EXP_ITEM_10000 = 123;
    uint256 public constant ID_WIND_EXP_ITEM_100000 = 124;
    uint256 public constant ID_WIND_EXP_ITEM_1000000 = 125;

    uint256 public constant ID_ICE_EXP_ITEM_10 = 130;
    uint256 public constant ID_ICE_EXP_ITEM_100 = 131;
    uint256 public constant ID_ICE_EXP_ITEM_1000 = 132;
    uint256 public constant ID_ICE_EXP_ITEM_10000 = 133;
    uint256 public constant ID_ICE_EXP_ITEM_100000 = 134;
    uint256 public constant ID_ICE_EXP_ITEM_1000000 = 135;

    uint256 public constant ID_LIGHTNING_EXP_ITEM_10 = 140;
    uint256 public constant ID_LIGHTNING_EXP_ITEM_100 = 141;
    uint256 public constant ID_LIGHTNING_EXP_ITEM_1000 = 142;
    uint256 public constant ID_LIGHTNING_EXP_ITEM_10000 = 143;
    uint256 public constant ID_LIGHTNING_EXP_ITEM_100000 = 144;
    uint256 public constant ID_LIGHTNING_EXP_ITEM_1000000 = 145;

    uint256 public constant ID_LIGHT_EXP_ITEM_10 = 150;
    uint256 public constant ID_LIGHT_EXP_ITEM_100 = 151;
    uint256 public constant ID_LIGHT_EXP_ITEM_1000 = 152;
    uint256 public constant ID_LIGHT_EXP_ITEM_10000 = 153;
    uint256 public constant ID_LIGHT_EXP_ITEM_100000 = 154;
    uint256 public constant ID_LIGHT_EXP_ITEM_1000000 = 155;

    uint256 public constant ID_DARK_EXP_ITEM_10 = 160;
    uint256 public constant ID_DARK_EXP_ITEM_100 = 161;
    uint256 public constant ID_DARK_EXP_ITEM_1000 = 162;
    uint256 public constant ID_DARK_EXP_ITEM_10000 = 163;
    uint256 public constant ID_DARK_EXP_ITEM_100000 = 164;
    uint256 public constant ID_DARK_EXP_ITEM_1000000 = 165;

    uint256 public constant ID_METAL_EXP_ITEM_10 = 170;
    uint256 public constant ID_METAL_EXP_ITEM_100 = 171;
    uint256 public constant ID_METAL_EXP_ITEM_1000 = 172;
    uint256 public constant ID_METAL_EXP_ITEM_10000 = 173;
    uint256 public constant ID_METAL_EXP_ITEM_100000 = 174;
    uint256 public constant ID_METAL_EXP_ITEM_1000000 = 175;

    uint256 public constant ID_NETHER_EXP_ITEM_10 = 180;
    uint256 public constant ID_NETHER_EXP_ITEM_100 = 181;
    uint256 public constant ID_NETHER_EXP_ITEM_1000 = 182;
    uint256 public constant ID_NETHER_EXP_ITEM_10000 = 183;
    uint256 public constant ID_NETHER_EXP_ITEM_100000 = 184;
    uint256 public constant ID_NETHER_EXP_ITEM_1000000 = 185;

    uint256 public constant ID_AETHER_EXP_ITEM_10 = 190;
    uint256 public constant ID_AETHER_EXP_ITEM_100 = 191;
    uint256 public constant ID_AETHER_EXP_ITEM_1000 = 192;
    uint256 public constant ID_AETHER_EXP_ITEM_10000 = 193;
    uint256 public constant ID_AETHER_EXP_ITEM_100000 = 194;
    uint256 public constant ID_AETHER_EXP_ITEM_1000000 = 195;

    // stamina items
    uint256 public constant ID_STAMINA_ITEM_10 = 350;
    uint256 public constant ID_STAMINA_ITEM_20 = 351;
    uint256 public constant ID_STAMINA_ITEM_30 = 352;
    uint256 public constant ID_STAMINA_ITEM_40 = 353;
    uint256 public constant ID_STAMINA_ITEM_50 = 354;
    uint256 public constant ID_STAMINA_ITEM_60 = 355;
    uint256 public constant ID_STAMINA_ITEM_70 = 356;
    uint256 public constant ID_STAMINA_ITEM_80 = 357;
    uint256 public constant ID_STAMINA_ITEM_90 = 358;
    uint256 public constant ID_STAMINA_ITEM_100 = 359;
    uint256 public constant ID_STAMINA_ITEM_110 = 360;
    uint256 public constant ID_STAMINA_ITEM_120 = 361;
    uint256 public constant ID_STAMINA_ITEM_130 = 362;
    uint256 public constant ID_STAMINA_ITEM_140 = 363;
    uint256 public constant ID_STAMINA_ITEM_150 = 364;
    uint256 public constant ID_STAMINA_ITEM_160 = 365;
    uint256 public constant ID_STAMINA_ITEM_170 = 366;
    uint256 public constant ID_STAMINA_ITEM_180 = 367;
    uint256 public constant ID_STAMINA_ITEM_190 = 368;
    uint256 public constant ID_STAMINA_ITEM_200 = 369;

    // stat boost items temporarily for battle
    uint256 public constant ID_HP_BOOST_ITEM_10 = 400;
    uint256 public constant ID_HP_BOOST_ITEM_20 = 401;
    uint256 public constant ID_HP_BOOST_ITEM_30 = 402;
    uint256 public constant ID_HP_BOOST_ITEM_40 = 403;
    uint256 public constant ID_HP_BOOST_ITEM_50 = 404;
    uint256 public constant ID_HP_BOOST_ITEM_60 = 405;
    uint256 public constant ID_HP_BOOST_ITEM_70 = 406;
    uint256 public constant ID_HP_BOOST_ITEM_80 = 407;
    uint256 public constant ID_HP_BOOST_ITEM_90 = 408;
    uint256 public constant ID_HP_BOOST_ITEM_100 = 409;

    uint256 public constant ID_ATK_BOOST_ITEM_10 = 410;
    uint256 public constant ID_ATK_BOOST_ITEM_20 = 411;
    uint256 public constant ID_ATK_BOOST_ITEM_30 = 412;
    uint256 public constant ID_ATK_BOOST_ITEM_40 = 413;
    uint256 public constant ID_ATK_BOOST_ITEM_50 = 414;
    uint256 public constant ID_ATK_BOOST_ITEM_60 = 415;
    uint256 public constant ID_ATK_BOOST_ITEM_70 = 416;
    uint256 public constant ID_ATK_BOOST_ITEM_80 = 417;
    uint256 public constant ID_ATK_BOOST_ITEM_90 = 418;
    uint256 public constant ID_ATK_BOOST_ITEM_100 = 419;

    uint256 public constant ID_MATK_BOOST_ITEM_10 = 420;
    uint256 public constant ID_MATK_BOOST_ITEM_20 = 421;
    uint256 public constant ID_MATK_BOOST_ITEM_30 = 422;
    uint256 public constant ID_MATK_BOOST_ITEM_40 = 423;
    uint256 public constant ID_MATK_BOOST_ITEM_50 = 424;
    uint256 public constant ID_MATK_BOOST_ITEM_60 = 425;
    uint256 public constant ID_MATK_BOOST_ITEM_70 = 426;
    uint256 public constant ID_MATK_BOOST_ITEM_80 = 427;
    uint256 public constant ID_MATK_BOOST_ITEM_90 = 428;
    uint256 public constant ID_MATK_BOOST_ITEM_100 = 429;

    uint256 public constant ID_DEF_BOOST_ITEM_10 = 430;
    uint256 public constant ID_DEF_BOOST_ITEM_20 = 431;
    uint256 public constant ID_DEF_BOOST_ITEM_30 = 432;
    uint256 public constant ID_DEF_BOOST_ITEM_40 = 433;
    uint256 public constant ID_DEF_BOOST_ITEM_50 = 434;
    uint256 public constant ID_DEF_BOOST_ITEM_60 = 435;
    uint256 public constant ID_DEF_BOOST_ITEM_70 = 436;
    uint256 public constant ID_DEF_BOOST_ITEM_80 = 437;
    uint256 public constant ID_DEF_BOOST_ITEM_90 = 438;
    uint256 public constant ID_DEF_BOOST_ITEM_100 = 439;

    uint256 public constant ID_MDEF_BOOST_ITEM_10 = 440;
    uint256 public constant ID_MDEF_BOOST_ITEM_20 = 441;
    uint256 public constant ID_MDEF_BOOST_ITEM_30 = 442;
    uint256 public constant ID_MDEF_BOOST_ITEM_40 = 443;
    uint256 public constant ID_MDEF_BOOST_ITEM_50 = 444;
    uint256 public constant ID_MDEF_BOOST_ITEM_60 = 445;
    uint256 public constant ID_MDEF_BOOST_ITEM_70 = 446;
    uint256 public constant ID_MDEF_BOOST_ITEM_80 = 447;
    uint256 public constant ID_MDEF_BOOST_ITEM_90 = 448;
    uint256 public constant ID_MDEF_BOOST_ITEM_100 = 449;

    uint256 public constant ID_SPD_BOOST_ITEM_10 = 450;
    uint256 public constant ID_SPD_BOOST_ITEM_20 = 451;
    uint256 public constant ID_SPD_BOOST_ITEM_30 = 452;
    uint256 public constant ID_SPD_BOOST_ITEM_40 = 453;
    uint256 public constant ID_SPD_BOOST_ITEM_50 = 454;
    uint256 public constant ID_SPD_BOOST_ITEM_60 = 455;
    uint256 public constant ID_SPD_BOOST_ITEM_70 = 456;
    uint256 public constant ID_SPD_BOOST_ITEM_80 = 457;
    uint256 public constant ID_SPD_BOOST_ITEM_90 = 458;
    uint256 public constant ID_SPD_BOOST_ITEM_100 = 459;

    uint256 public constant ID_ACC_BOOST_ITEM_10 = 460;
    uint256 public constant ID_ACC_BOOST_ITEM_20 = 461;
    uint256 public constant ID_ACC_BOOST_ITEM_30 = 462;
    uint256 public constant ID_ACC_BOOST_ITEM_40 = 463;
    uint256 public constant ID_ACC_BOOST_ITEM_50 = 464;
    uint256 public constant ID_ACC_BOOST_ITEM_60 = 465;
    uint256 public constant ID_ACC_BOOST_ITEM_70 = 466;
    uint256 public constant ID_ACC_BOOST_ITEM_80 = 467;
    uint256 public constant ID_ACC_BOOST_ITEM_90 = 468;
    uint256 public constant ID_ACC_BOOST_ITEM_100 = 469;

    uint256 public constant ID_EVA_BOOST_ITEM_10 = 470;
    uint256 public constant ID_EVA_BOOST_ITEM_20 = 471;
    uint256 public constant ID_EVA_BOOST_ITEM_30 = 472;
    uint256 public constant ID_EVA_BOOST_ITEM_40 = 473;
    uint256 public constant ID_EVA_BOOST_ITEM_50 = 474;
    uint256 public constant ID_EVA_BOOST_ITEM_60 = 475;
    uint256 public constant ID_EVA_BOOST_ITEM_70 = 476;
    uint256 public constant ID_EVA_BOOST_ITEM_80 = 477;
    uint256 public constant ID_EVA_BOOST_ITEM_90 = 478;
    uint256 public constant ID_EVA_BOOST_ITEM_100 = 479;

    uint256 public constant ID_CRIT_BOOST_ITEM_10 = 480;
    uint256 public constant ID_CRIT_BOOST_ITEM_20 = 481;
    uint256 public constant ID_CRIT_BOOST_ITEM_30 = 482;
    uint256 public constant ID_CRIT_BOOST_ITEM_40 = 483;
    uint256 public constant ID_CRIT_BOOST_ITEM_50 = 484;
    uint256 public constant ID_CRIT_BOOST_ITEM_60 = 485;
    uint256 public constant ID_CRIT_BOOST_ITEM_70 = 486;
    uint256 public constant ID_CRIT_BOOST_ITEM_80 = 487;
    uint256 public constant ID_CRIT_BOOST_ITEM_90 = 488;
    uint256 public constant ID_CRIT_BOOST_ITEM_100 = 489;

    uint256 public constant ID_CRIT_DMG_BOOST_ITEM_10 = 490;
    uint256 public constant ID_CRIT_DMG_BOOST_ITEM_20 = 491;
    uint256 public constant ID_CRIT_DMG_BOOST_ITEM_30 = 492;
    uint256 public constant ID_CRIT_DMG_BOOST_ITEM_40 = 493;
    uint256 public constant ID_CRIT_DMG_BOOST_ITEM_50 = 494;
    uint256 public constant ID_CRIT_DMG_BOOST_ITEM_60 = 495;
    uint256 public constant ID_CRIT_DMG_BOOST_ITEM_70 = 496;
    uint256 public constant ID_CRIT_DMG_BOOST_ITEM_80 = 497;
    uint256 public constant ID_CRIT_DMG_BOOST_ITEM_90 = 498;
    uint256 public constant ID_CRIT_DMG_BOOST_ITEM_100 = 499;

    uint256 public constant ID_CRIT_RES_BOOST_ITEM_10 = 500;
    uint256 public constant ID_CRIT_RES_BOOST_ITEM_20 = 501;
    uint256 public constant ID_CRIT_RES_BOOST_ITEM_30 = 502;
    uint256 public constant ID_CRIT_RES_BOOST_ITEM_40 = 503;
    uint256 public constant ID_CRIT_RES_BOOST_ITEM_50 = 504;
    uint256 public constant ID_CRIT_RES_BOOST_ITEM_60 = 505;
    uint256 public constant ID_CRIT_RES_BOOST_ITEM_70 = 506;
    uint256 public constant ID_CRIT_RES_BOOST_ITEM_80 = 507;
    uint256 public constant ID_CRIT_RES_BOOST_ITEM_90 = 508;
    uint256 public constant ID_CRIT_RES_BOOST_ITEM_100 = 509;

    uint256 public constant ID_EFF_BOOST_ITEM_10 = 510;
    uint256 public constant ID_EFF_BOOST_ITEM_20 = 511;
    uint256 public constant ID_EFF_BOOST_ITEM_30 = 512;
    uint256 public constant ID_EFF_BOOST_ITEM_40 = 513;
    uint256 public constant ID_EFF_BOOST_ITEM_50 = 514;
    uint256 public constant ID_EFF_BOOST_ITEM_60 = 515;
    uint256 public constant ID_EFF_BOOST_ITEM_70 = 516;
    uint256 public constant ID_EFF_BOOST_ITEM_80 = 517;
    uint256 public constant ID_EFF_BOOST_ITEM_90 = 518;
    uint256 public constant ID_EFF_BOOST_ITEM_100 = 519;

    uint256 public constant ID_RES_BOOST_ITEM_10 = 520;
    uint256 public constant ID_RES_BOOST_ITEM_20 = 521;
    uint256 public constant ID_RES_BOOST_ITEM_30 = 522;
    uint256 public constant ID_RES_BOOST_ITEM_40 = 523;
    uint256 public constant ID_RES_BOOST_ITEM_50 = 524;
    uint256 public constant ID_RES_BOOST_ITEM_60 = 525;
    uint256 public constant ID_RES_BOOST_ITEM_70 = 526;
    uint256 public constant ID_RES_BOOST_ITEM_80 = 527;
    uint256 public constant ID_RES_BOOST_ITEM_90 = 528;
    uint256 public constant ID_RES_BOOST_ITEM_100 = 529;

    // drop rate - 10-500 - likely won't be used
    uint256 public constant ID_DROP_BOOST_ITEM_10 = 600;
    uint256 public constant ID_DROP_BOOST_ITEM_20 = 601;
    uint256 public constant ID_DROP_BOOST_ITEM_30 = 602;
    uint256 public constant ID_DROP_BOOST_ITEM_40 = 603;
    uint256 public constant ID_DROP_BOOST_ITEM_50 = 604;
    uint256 public constant ID_DROP_BOOST_ITEM_60 = 605;
    uint256 public constant ID_DROP_BOOST_ITEM_70 = 606;
    uint256 public constant ID_DROP_BOOST_ITEM_80 = 607;
    uint256 public constant ID_DROP_BOOST_ITEM_90 = 608;
    uint256 public constant ID_DROP_BOOST_ITEM_100 = 609;
    uint256 public constant ID_DROP_BOOST_ITEM_110 = 610;
    uint256 public constant ID_DROP_BOOST_ITEM_120 = 611;
    uint256 public constant ID_DROP_BOOST_ITEM_130 = 612;
    uint256 public constant ID_DROP_BOOST_ITEM_140 = 613;
    uint256 public constant ID_DROP_BOOST_ITEM_150 = 614;
    uint256 public constant ID_DROP_BOOST_ITEM_160 = 615;
    uint256 public constant ID_DROP_BOOST_ITEM_170 = 616;
    uint256 public constant ID_DROP_BOOST_ITEM_180 = 617;
    uint256 public constant ID_DROP_BOOST_ITEM_190 = 618;
    uint256 public constant ID_DROP_BOOST_ITEM_200 = 619;
    uint256 public constant ID_DROP_BOOST_ITEM_210 = 620;
    uint256 public constant ID_DROP_BOOST_ITEM_220 = 621;
    uint256 public constant ID_DROP_BOOST_ITEM_230 = 622;
    uint256 public constant ID_DROP_BOOST_ITEM_240 = 623;
    uint256 public constant ID_DROP_BOOST_ITEM_250 = 624;
    uint256 public constant ID_DROP_BOOST_ITEM_260 = 625;
    uint256 public constant ID_DROP_BOOST_ITEM_270 = 626;
    uint256 public constant ID_DROP_BOOST_ITEM_280 = 627;
    uint256 public constant ID_DROP_BOOST_ITEM_290 = 628;
    uint256 public constant ID_DROP_BOOST_ITEM_300 = 629;
    uint256 public constant ID_DROP_BOOST_ITEM_310 = 630;
    uint256 public constant ID_DROP_BOOST_ITEM_320 = 631;
    uint256 public constant ID_DROP_BOOST_ITEM_330 = 632;
    uint256 public constant ID_DROP_BOOST_ITEM_340 = 633;
    uint256 public constant ID_DROP_BOOST_ITEM_350 = 634;
    uint256 public constant ID_DROP_BOOST_ITEM_360 = 635;
    uint256 public constant ID_DROP_BOOST_ITEM_370 = 636;
    uint256 public constant ID_DROP_BOOST_ITEM_380 = 637;
    uint256 public constant ID_DROP_BOOST_ITEM_390 = 638;
    uint256 public constant ID_DROP_BOOST_ITEM_400 = 639;
    uint256 public constant ID_DROP_BOOST_ITEM_410 = 640;
    uint256 public constant ID_DROP_BOOST_ITEM_420 = 641;
    uint256 public constant ID_DROP_BOOST_ITEM_430 = 642;
    uint256 public constant ID_DROP_BOOST_ITEM_440 = 643;
    uint256 public constant ID_DROP_BOOST_ITEM_450 = 644;
    uint256 public constant ID_DROP_BOOST_ITEM_460 = 645;
    uint256 public constant ID_DROP_BOOST_ITEM_470 = 646;
    uint256 public constant ID_DROP_BOOST_ITEM_480 = 647;
    uint256 public constant ID_DROP_BOOST_ITEM_490 = 648;
    uint256 public constant ID_DROP_BOOST_ITEM_500 = 649;

    // unique value boost items
    uint256 public constant ID_HP_UV_ITEM = 700;
    uint256 public constant ID_ATK_UV_ITEM = 710;
    uint256 public constant ID_MATK_UV_ITEM = 720;
    uint256 public constant ID_DEF_UV_ITEM = 730;
    uint256 public constant ID_MDEF_UV_ITEM = 740;
    uint256 public constant ID_SPD_UV_ITEM = 750;
    uint256 public constant ID_ACC_UV_ITEM = 760;
    uint256 public constant ID_EVA_UV_ITEM = 770;
    uint256 public constant ID_CRIT_RATE_UV_ITEM = 780;
    uint256 public constant ID_CRIT_DMG_UV_ITEM = 790;
    uint256 public constant ID_CRIT_RES_UV_ITEM = 800;
    uint256 public constant ID_EFF_UV_ITEM = 810;
    uint256 public constant ID_RES_UV_ITEM = 820;

    // equip enhancement items
    // weapon, helmet, armor, necklace, ring, boots, shield, generic equip, generic accessory, artifact
    uint256 public constant ID_EQUIP_WEAPON_EXP_ITEM_COMMON = 1000;
    uint256 public constant ID_EQUIP_WEAPON_EXP_ITEM_100 = 1001;
    uint256 public constant ID_EQUIP_WEAPON_EXP_ITEM_1000 = 1002;
    uint256 public constant ID_EQUIP_WEAPON_EXP_ITEM_10000 = 1003;
    uint256 public constant ID_EQUIP_WEAPON_EXP_ITEM_100000 = 1004;
    uint256 public constant ID_EQUIP_WEAPON_EXP_ITEM_1000000 = 1005;

    uint256 public constant ID_EQUIP_SHIELD_EXP_ITEM_COMMON = 1010;
    uint256 public constant ID_EQUIP_SHIELD_EXP_ITEM_100 = 1011;
    uint256 public constant ID_EQUIP_SHIELD_EXP_ITEM_1000 = 1012;
    uint256 public constant ID_EQUIP_SHIELD_EXP_ITEM_10000 = 1013;
    uint256 public constant ID_EQUIP_SHIELD_EXP_ITEM_100000 = 1014;
    uint256 public constant ID_EQUIP_SHIELD_EXP_ITEM_1000000 = 1015;

    uint256 public constant ID_EQUIP_HELMET_EXP_ITEM_COMMON = 1020;
    uint256 public constant ID_EQUIP_HELMET_EXP_ITEM_100 = 1021;
    uint256 public constant ID_EQUIP_HELMET_EXP_ITEM_1000 = 1022;
    uint256 public constant ID_EQUIP_HELMET_EXP_ITEM_10000 = 1023;
    uint256 public constant ID_EQUIP_HELMET_EXP_ITEM_100000 = 1024;
    uint256 public constant ID_EQUIP_HELMET_EXP_ITEM_1000000 = 1025;

    uint256 public constant ID_EQUIP_ARMOR_EXP_ITEM_COMMON = 1030;
    uint256 public constant ID_EQUIP_ARMOR_EXP_ITEM_100 = 1031;
    uint256 public constant ID_EQUIP_ARMOR_EXP_ITEM_1000 = 1032;
    uint256 public constant ID_EQUIP_ARMOR_EXP_ITEM_10000 = 1033;
    uint256 public constant ID_EQUIP_ARMOR_EXP_ITEM_100000 = 1034;
    uint256 public constant ID_EQUIP_ARMOR_EXP_ITEM_1000000 = 1035;

    uint256 public constant ID_EQUIP_BOOTS_EXP_ITEM_COMMON = 1040;
    uint256 public constant ID_EQUIP_BOOTS_EXP_ITEM_100 = 1041;
    uint256 public constant ID_EQUIP_BOOTS_EXP_ITEM_1000 = 1042;
    uint256 public constant ID_EQUIP_BOOTS_EXP_ITEM_10000 = 1043;
    uint256 public constant ID_EQUIP_BOOTS_EXP_ITEM_100000 = 1044;
    uint256 public constant ID_EQUIP_BOOTS_EXP_ITEM_1000000 = 1045;

    uint256 public constant ID_EQUIP_NECKLACE_EXP_ITEM_COMMON = 1050;
    uint256 public constant ID_EQUIP_NECKLACE_EXP_ITEM_100 = 1051;
    uint256 public constant ID_EQUIP_NECKLACE_EXP_ITEM_1000 = 1052;
    uint256 public constant ID_EQUIP_NECKLACE_EXP_ITEM_10000 = 1053;
    uint256 public constant ID_EQUIP_NECKLACE_EXP_ITEM_100000 = 1054;
    uint256 public constant ID_EQUIP_NECKLACE_EXP_ITEM_1000000 = 1055;

    uint256 public constant ID_EQUIP_RING_EXP_ITEM_COMMON = 1060;
    uint256 public constant ID_EQUIP_RING_EXP_ITEM_100 = 1061;
    uint256 public constant ID_EQUIP_RING_EXP_ITEM_1000 = 1062;
    uint256 public constant ID_EQUIP_RING_EXP_ITEM_10000 = 1063;
    uint256 public constant ID_EQUIP_RING_EXP_ITEM_100000 = 1064;
    uint256 public constant ID_EQUIP_RING_EXP_ITEM_1000000 = 1065;

    uint256 public constant ID_EQUIP_EQUIP_EXP_ITEM_COMMON = 1070;
    uint256 public constant ID_EQUIP_EQUIP_EXP_ITEM_100 = 1071;
    uint256 public constant ID_EQUIP_EQUIP_EXP_ITEM_1000 = 1072;
    uint256 public constant ID_EQUIP_EQUIP_EXP_ITEM_10000 = 1073;
    uint256 public constant ID_EQUIP_EQUIP_EXP_ITEM_100000 = 1074;
    uint256 public constant ID_EQUIP_EQUIP_EXP_ITEM_1000000 = 1075;

    uint256 public constant ID_EQUIP_ACCESSORY_EXP_ITEM_COMMON = 1080;
    uint256 public constant ID_EQUIP_ACCESSORY_EXP_ITEM_100 = 1081;
    uint256 public constant ID_EQUIP_ACCESSORY_EXP_ITEM_1000 = 1082;
    uint256 public constant ID_EQUIP_ACCESSORY_EXP_ITEM_10000 = 1083;
    uint256 public constant ID_EQUIP_ACCESSORY_EXP_ITEM_100000 = 1084;
    uint256 public constant ID_EQUIP_ACCESSORY_EXP_ITEM_1000000 = 1085;

    uint256 public constant ID_EQUIP_ALL_EXP_ITEM_COMMON = 1090;
    uint256 public constant ID_EQUIP_ALL_EXP_ITEM_100 = 1091;
    uint256 public constant ID_EQUIP_ALL_EXP_ITEM_1000 = 1092;
    uint256 public constant ID_EQUIP_ALL_EXP_ITEM_10000 = 1093;
    uint256 public constant ID_EQUIP_ALL_EXP_ITEM_100000 = 1094;
    uint256 public constant ID_EQUIP_ALL_EXP_ITEM_1000000 = 1095;

    uint256 public constant ID_EQUIP_ARTIFACT_EXP_ITEM_COMMON = 1100;
    uint256 public constant ID_EQUIP_ARTIFACT_EXP_ITEM_100 = 1101;
    uint256 public constant ID_EQUIP_ARTIFACT_EXP_ITEM_1000 = 1102;
    uint256 public constant ID_EQUIP_ARTIFACT_EXP_ITEM_10000 = 1103;
    uint256 public constant ID_EQUIP_ARTIFACT_EXP_ITEM_100000 = 1104;
    uint256 public constant ID_EQUIP_ARTIFACT_EXP_ITEM_1000000 = 1105;

    uint256 public constant ID_EQUIP_DUST_COMMON = 1200;
    uint256 public constant ID_EQUIP_DUST_UNCOMMON = 1201;
    uint256 public constant ID_EQUIP_DUST_RARE = 1202;
    uint256 public constant ID_EQUIP_DUST_EPIC = 1203;
    uint256 public constant ID_EQUIP_DUST_LEGENDARY = 1204;
    uint256 public constant ID_EQUIP_DUST_MYTHIC = 1205;

    // bond, promotion, grade
    uint256 public constant ID_BOND_ITEM_COMMON = 1300;
    uint256 public constant ID_BOND_ITEM_100 = 1301;
    uint256 public constant ID_BOND_ITEM_1000 = 1302;
    uint256 public constant ID_BOND_ITEM_10000 = 1303;
    uint256 public constant ID_BOND_ITEM_100000 = 1304;
    uint256 public constant ID_BOND_ITEM_1000000 = 1305;

    // fire, water, nature, earth, wind, ice, lightning, light, dark, metal, nether, aether
    uint256 public constant ID_BOND_FIRE_ITEM_10 = 1310;
    uint256 public constant ID_BOND_FIRE_ITEM_100 = 1311;
    uint256 public constant ID_BOND_FIRE_ITEM_1000 = 1312;
    uint256 public constant ID_BOND_FIRE_ITEM_10000 = 1313;
    uint256 public constant ID_BOND_FIRE_ITEM_100000 = 1314;
    uint256 public constant ID_BOND_FIRE_ITEM_1000000 = 1315;

    uint256 public constant ID_BOND_WATER_ITEM_10 = 1320;
    uint256 public constant ID_BOND_WATER_ITEM_100 = 1321;
    uint256 public constant ID_BOND_WATER_ITEM_1000 = 1322;
    uint256 public constant ID_BOND_WATER_ITEM_10000 = 1323;
    uint256 public constant ID_BOND_WATER_ITEM_100000 = 1324;
    uint256 public constant ID_BOND_WATER_ITEM_1000000 = 1325;

    uint256 public constant ID_BOND_NATURE_ITEM_10 = 1330;
    uint256 public constant ID_BOND_NATURE_ITEM_100 = 1331;
    uint256 public constant ID_BOND_NATURE_ITEM_1000 = 1332;
    uint256 public constant ID_BOND_NATURE_ITEM_10000 = 1333;
    uint256 public constant ID_BOND_NATURE_ITEM_100000 = 1334;
    uint256 public constant ID_BOND_NATURE_ITEM_1000000 = 1335;

    uint256 public constant ID_BOND_EARTH_ITEM_10 = 1340;
    uint256 public constant ID_BOND_EARTH_ITEM_100 = 1341;
    uint256 public constant ID_BOND_EARTH_ITEM_1000 = 1342;
    uint256 public constant ID_BOND_EARTH_ITEM_10000 = 1343;
    uint256 public constant ID_BOND_EARTH_ITEM_100000 = 1344;
    uint256 public constant ID_BOND_EARTH_ITEM_1000000 = 1345;

    uint256 public constant ID_BOND_WIND_ITEM_10 = 1350;
    uint256 public constant ID_BOND_WIND_ITEM_100 = 1351;
    uint256 public constant ID_BOND_WIND_ITEM_1000 = 1352;
    uint256 public constant ID_BOND_WIND_ITEM_10000 = 1353;
    uint256 public constant ID_BOND_WIND_ITEM_100000 = 1354;
    uint256 public constant ID_BOND_WIND_ITEM_1000000 = 1355;

    uint256 public constant ID_BOND_ICE_ITEM_10 = 1360;
    uint256 public constant ID_BOND_ICE_ITEM_100 = 1361;
    uint256 public constant ID_BOND_ICE_ITEM_1000 = 1362;
    uint256 public constant ID_BOND_ICE_ITEM_10000 = 1363;
    uint256 public constant ID_BOND_ICE_ITEM_100000 = 1364;
    uint256 public constant ID_BOND_ICE_ITEM_1000000 = 1365;

    uint256 public constant ID_BOND_LIGHTNING_ITEM_10 = 1370;
    uint256 public constant ID_BOND_LIGHTNING_ITEM_100 = 1371;
    uint256 public constant ID_BOND_LIGHTNING_ITEM_1000 = 1372;
    uint256 public constant ID_BOND_LIGHTNING_ITEM_10000 = 1373;
    uint256 public constant ID_BOND_LIGHTNING_ITEM_100000 = 1374;
    uint256 public constant ID_BOND_LIGHTNING_ITEM_1000000 = 1375;

    uint256 public constant ID_BOND_LIGHT_ITEM_10 = 1380;
    uint256 public constant ID_BOND_LIGHT_ITEM_100 = 1381;
    uint256 public constant ID_BOND_LIGHT_ITEM_1000 = 1382;
    uint256 public constant ID_BOND_LIGHT_ITEM_10000 = 1383;
    uint256 public constant ID_BOND_LIGHT_ITEM_100000 = 1384;
    uint256 public constant ID_BOND_LIGHT_ITEM_1000000 = 1385;

    uint256 public constant ID_BOND_DARK_ITEM_10 = 1390;
    uint256 public constant ID_BOND_DARK_ITEM_100 = 1391;
    uint256 public constant ID_BOND_DARK_ITEM_1000 = 1392;
    uint256 public constant ID_BOND_DARK_ITEM_10000 = 1393;
    uint256 public constant ID_BOND_DARK_ITEM_100000 = 1394;
    uint256 public constant ID_BOND_DARK_ITEM_1000000 = 1395;

    uint256 public constant ID_BOND_METAL_ITEM_10 = 1400;
    uint256 public constant ID_BOND_METAL_ITEM_100 = 1401;
    uint256 public constant ID_BOND_METAL_ITEM_1000 = 1402;
    uint256 public constant ID_BOND_METAL_ITEM_10000 = 1403;
    uint256 public constant ID_BOND_METAL_ITEM_100000 = 1404;
    uint256 public constant ID_BOND_METAL_ITEM_1000000 = 1405;

    uint256 public constant ID_BOND_NETHER_ITEM_10 = 1410;
    uint256 public constant ID_BOND_NETHER_ITEM_100 = 1411;
    uint256 public constant ID_BOND_NETHER_ITEM_1000 = 1412;
    uint256 public constant ID_BOND_NETHER_ITEM_10000 = 1413;
    uint256 public constant ID_BOND_NETHER_ITEM_100000 = 1414;
    uint256 public constant ID_BOND_NETHER_ITEM_1000000 = 1415;

    uint256 public constant ID_BOND_AETHER_ITEM_10 = 1420;
    uint256 public constant ID_BOND_AETHER_ITEM_100 = 1421;
    uint256 public constant ID_BOND_AETHER_ITEM_1000 = 1422;
    uint256 public constant ID_BOND_AETHER_ITEM_10000 = 1423;
    uint256 public constant ID_BOND_AETHER_ITEM_100000 = 1424;
    uint256 public constant ID_BOND_AETHER_ITEM_1000000 = 1425;

    // promotion item - 1*, 2*, 3*, 4*, 5*, 6*
    uint256 public constant ID_PROMOTION_ITEM_1 = 1500;
    uint256 public constant ID_PROMOTION_ITEM_2 = 1501;
    uint256 public constant ID_PROMOTION_ITEM_3 = 1502;
    uint256 public constant ID_PROMOTION_ITEM_4 = 1503;
    uint256 public constant ID_PROMOTION_ITEM_5 = 1504;
    uint256 public constant ID_PROMOTION_ITEM_6 = 1505;

    // enhancement item - one for each element
    uint256 public constant ID_ENHANCEMENT_NEUTRAL_ITEM = 1600;
    uint256 public constant ID_ENHANCEMENT_FIRE_ITEM = 1601;
    uint256 public constant ID_ENHANCEMENT_WATER_ITEM = 1602;
    uint256 public constant ID_ENHANCEMENT_NATURE_ITEM = 1603;
    uint256 public constant ID_ENHANCEMENT_EARTH_ITEM = 1604;
    uint256 public constant ID_ENHANCEMENT_WIND_ITEM = 1605;
    uint256 public constant ID_ENHANCEMENT_ICE_ITEM = 1606;
    uint256 public constant ID_ENHANCEMENT_LIGHTNING_ITEM = 1607;
    uint256 public constant ID_ENHANCEMENT_LIGHT_ITEM = 1608;
    uint256 public constant ID_ENHANCEMENT_DARK_ITEM = 1609;
    uint256 public constant ID_ENHANCEMENT_METAL_ITEM = 1610;
    uint256 public constant ID_ENHANCEMENT_NETHER_ITEM = 1611;
    uint256 public constant ID_ENHANCEMENT_AETHER_ITEM = 1612;
    uint256 public constant ID_ENHANCEMENT_ALL_ITEM = 1620;

    // hero stones - obtained by sacrificing heroes
    uint256 public constant ID_HERO_SOUL_STONE = 1700;

    // awakening materials - 6 materials for each class and element - 2000-3000 - to be added later

    // equipment crafting materials - 10000
    uint256 public constant ID_SKIN = 10000;
    uint256 public constant ID_LEATHER = 10001;
    uint256 public constant ID_STICKS = 10002;
    uint256 public constant ID_WOOD = 10003;
    uint256 public constant ID_COPPER_ORE = 10100;
    uint256 public constant ID_TIN_ORE = 10101;
    uint256 public constant ID_ZINC_ORE = 10102;
    uint256 public constant ID_IRON_ORE = 10103;

    uint256 public constant ID_SILVER_ORE = 10104;
    uint256 public constant ID_MYTHRIL_ORE = 10105;
    uint256 public constant ID_ELECTRUM_ORE = 10106;
    uint256 public constant ID_COBALT_ORE = 10107;
    uint256 public constant ID_GOLD_ORE = 10108;

    uint256 public constant ID_COPPER_INGOT = 10200;    // 3 copper ore
    uint256 public constant ID_BRONZE_INGOT = 10201;    // 2 copper ore + 1 tin ore
    uint256 public constant ID_BRASS_INGOT = 10202;     // 2 copper ore + 1 zinc ore
    uint256 public constant ID_IRON_INGOT = 10203;      // 3 iron ore

    uint256 public constant ID_STEEL_INGOT = 10204;     // 2 iron ore + 1 fire shard
    uint256 public constant ID_SILVER_INGOT = 10205;    // 3 silver ore
    uint256 public constant ID_MYTHRIL_INGOT = 10206;   // 3 mythril ore
    uint256 public constant ID_ELECTRUM_INGOT = 10207;  // 4 electrum ore
    uint256 public constant ID_COBALT_INGOT = 10208;    // 2 cobalt ore + 1 iron ore
    uint256 public constant ID_GOLD_INGOT = 10209;      // 4 gold ore

    // crafting recipes - currency
    uint256 public constant ID_RECIPE_LEATHER = 20000;
    uint256 public constant ID_RECIPE_WOOD = 20001;
    uint256 public constant ID_RECIPE_COPPER_INGOT = 20200;
    uint256 public constant ID_RECIPE_BRONZE_INGOT = 20201;
    uint256 public constant ID_RECIPE_BRASS_INGOT = 20202;
    uint256 public constant ID_RECIPE_IRON_INGOT = 20203;

    uint256 public constant ID_RECIPE_STEEL_INGOT = 20204;
    uint256 public constant ID_RECIPE_SILVER_INGOT = 20205;
    uint256 public constant ID_RECIPE_MYTHRIL_INGOT = 20206;
    uint256 public constant ID_RECIPE_ELECTRUM_INGOT = 20207;
    uint256 public constant ID_RECIPE_COBALT_INGOT = 20208;
    uint256 public constant ID_RECIPE_GOLD_INGOT = 20209;

    // crafting recipes - scrolls 21000
    uint256 public constant ID_RECIPE_EXP_SCROLL_COMMON = 21000;
    uint256 public constant ID_RECIPE_EXP_SCROLL_UNCOMMON = 21001;
    uint256 public constant ID_RECIPE_EXP_SCROLL_RARE = 21002;
    uint256 public constant ID_RECIPE_EXP_SCROLL_EPIC = 21003;
    uint256 public constant ID_RECIPE_EXP_SCROLL_LEGENDARY = 21004;
    uint256 public constant ID_RECIPE_EXP_SCROLL_MYTHIC = 21005;

    // crafting recipes - equip enhancement stones - 22000
    uint256 public constant ID_RECIPE_WEAPON_ENHANCEMENT_STONE_COMMON = 22000;
    uint256 public constant ID_RECIPE_WEAPON_ENHANCEMENT_STONE_UNCOMMON = 22001;
    uint256 public constant ID_RECIPE_WEAPON_ENHANCEMENT_STONE_RARE = 22002;
    uint256 public constant ID_RECIPE_WEAPON_ENHANCEMENT_STONE_EPIC = 22003;
    uint256 public constant ID_RECIPE_WEAPON_ENHANCEMENT_STONE_LEGENDARY = 22004;
    uint256 public constant ID_RECIPE_WEAPON_ENHANCEMENT_STONE_MYTHIC = 22005;

    uint256 public constant ID_RECIPE_SHIELD_ENHANCEMENT_STONE_COMMON = 22010;
    uint256 public constant ID_RECIPE_SHIELD_ENHANCEMENT_STONE_UNCOMMON = 22011;
    uint256 public constant ID_RECIPE_SHIELD_ENHANCEMENT_STONE_RARE = 22012;
    uint256 public constant ID_RECIPE_SHIELD_ENHANCEMENT_STONE_EPIC = 22013;
    uint256 public constant ID_RECIPE_SHIELD_ENHANCEMENT_STONE_LEGENDARY = 22014;
    uint256 public constant ID_RECIPE_SHIELD_ENHANCEMENT_STONE_MYTHIC = 22015;

    uint256 public constant ID_RECIPE_HELMET_ENHANCEMENT_STONE_COMMON = 22020;
    uint256 public constant ID_RECIPE_HELMET_ENHANCEMENT_STONE_UNCOMMON = 22021;
    uint256 public constant ID_RECIPE_HELMET_ENHANCEMENT_STONE_RARE = 22022;
    uint256 public constant ID_RECIPE_HELMET_ENHANCEMENT_STONE_EPIC = 22023;
    uint256 public constant ID_RECIPE_HELMET_ENHANCEMENT_STONE_LEGENDARY = 22024;
    uint256 public constant ID_RECIPE_HELMET_ENHANCEMENT_STONE_MYTHIC = 22025;

    uint256 public constant ID_RECIPE_ARMOR_ENHANCEMENT_STONE_COMMON = 22030;
    uint256 public constant ID_RECIPE_ARMOR_ENHANCEMENT_STONE_UNCOMMON = 22031;
    uint256 public constant ID_RECIPE_ARMOR_ENHANCEMENT_STONE_RARE = 22032;
    uint256 public constant ID_RECIPE_ARMOR_ENHANCEMENT_STONE_EPIC = 22033;
    uint256 public constant ID_RECIPE_ARMOR_ENHANCEMENT_STONE_LEGENDARY = 22034;
    uint256 public constant ID_RECIPE_ARMOR_ENHANCEMENT_STONE_MYTHIC = 22035;

    uint256 public constant ID_RECIPE_BOOTS_ENHANCEMENT_STONE_COMMON = 22040;
    uint256 public constant ID_RECIPE_BOOTS_ENHANCEMENT_STONE_UNCOMMON = 22041;
    uint256 public constant ID_RECIPE_BOOTS_ENHANCEMENT_STONE_RARE = 22042;
    uint256 public constant ID_RECIPE_BOOTS_ENHANCEMENT_STONE_EPIC = 22043;
    uint256 public constant ID_RECIPE_BOOTS_ENHANCEMENT_STONE_LEGENDARY = 22044;
    uint256 public constant ID_RECIPE_BOOTS_ENHANCEMENT_STONE_MYTHIC = 22045;

    uint256 public constant ID_RECIPE_NECKLACE_ENHANCEMENT_STONE_COMMON = 22050;
    uint256 public constant ID_RECIPE_NECKLACE_ENHANCEMENT_STONE_UNCOMMON = 22051;
    uint256 public constant ID_RECIPE_NECKLACE_ENHANCEMENT_STONE_RARE = 22052;
    uint256 public constant ID_RECIPE_NECKLACE_ENHANCEMENT_STONE_EPIC = 22053;
    uint256 public constant ID_RECIPE_NECKLACE_ENHANCEMENT_STONE_LEGENDARY = 22054;
    uint256 public constant ID_RECIPE_NECKLACE_ENHANCEMENT_STONE_MYTHIC = 22055;

    uint256 public constant ID_RECIPE_RING_ENHANCEMENT_STONE_COMMON = 22060;
    uint256 public constant ID_RECIPE_RING_ENHANCEMENT_STONE_UNCOMMON = 22061;
    uint256 public constant ID_RECIPE_RING_ENHANCEMENT_STONE_RARE = 22062;
    uint256 public constant ID_RECIPE_RING_ENHANCEMENT_STONE_EPIC = 22063;
    uint256 public constant ID_RECIPE_RING_ENHANCEMENT_STONE_LEGENDARY = 22064;
    uint256 public constant ID_RECIPE_RING_ENHANCEMENT_STONE_MYTHIC = 22065;

    uint256 public constant ID_RECIPE_EQUIP_ENHANCEMENT_STONE_COMMON = 22070;
    uint256 public constant ID_RECIPE_EQUIP_ENHANCEMENT_STONE_UNCOMMON = 22071;
    uint256 public constant ID_RECIPE_EQUIP_ENHANCEMENT_STONE_RARE = 22072;
    uint256 public constant ID_RECIPE_EQUIP_ENHANCEMENT_STONE_EPIC = 22073;
    uint256 public constant ID_RECIPE_EQUIP_ENHANCEMENT_STONE_LEGENDARY = 22074;
    uint256 public constant ID_RECIPE_EQUIP_ENHANCEMENT_STONE_MYTHIC = 22075;

    uint256 public constant ID_RECIPE_ACCESSORY_ENHANCEMENT_STONE_COMMON = 22080;
    uint256 public constant ID_RECIPE_ACCESSORY_ENHANCEMENT_STONE_UNCOMMON = 22081;
    uint256 public constant ID_RECIPE_ACCESSORY_ENHANCEMENT_STONE_RARE = 22082;
    uint256 public constant ID_RECIPE_ACCESSORY_ENHANCEMENT_STONE_EPIC = 22083;
    uint256 public constant ID_RECIPE_ACCESSORY_ENHANCEMENT_STONE_LEGENDARY = 22084;
    uint256 public constant ID_RECIPE_ACCESSORY_ENHANCEMENT_STONE_MYTHIC = 22085;

    uint256 public constant ID_RECIPE_ALL_ENHANCEMENT_STONE_COMMON = 22090;
    uint256 public constant ID_RECIPE_ALL_ENHANCEMENT_STONE_UNCOMMON = 22091;
    uint256 public constant ID_RECIPE_ALL_ENHANCEMENT_STONE_RARE = 22092;
    uint256 public constant ID_RECIPE_ALL_ENHANCEMENT_STONE_EPIC = 22093;
    uint256 public constant ID_RECIPE_ALL_ENHANCEMENT_STONE_LEGENDARY = 22094;
    uint256 public constant ID_RECIPE_ALL_ENHANCEMENT_STONE_MYTHIC = 22095;

    uint256 public constant ID_RECIPE_ARTIFACT_ENHANCEMENT_STONE_COMMON = 22100;
    uint256 public constant ID_RECIPE_ARTIFACT_ENHANCEMENT_STONE_UNCOMMON = 22101;
    uint256 public constant ID_RECIPE_ARTIFACT_ENHANCEMENT_STONE_RARE = 22102;
    uint256 public constant ID_RECIPE_ARTIFACT_ENHANCEMENT_STONE_EPIC = 22103;
    uint256 public constant ID_RECIPE_ARTIFACT_ENHANCEMENT_STONE_LEGENDARY = 22104;
    uint256 public constant ID_RECIPE_ARTIFACT_ENHANCEMENT_STONE_MYTHIC = 22105;

    // crafting recipes - 30000 - equips
    // wood and leather tier 1
    uint256 public constant ID_RECIPE_WOODEN_SWORD = 30000;
    uint256 public constant ID_RECIPE_WOODEN_SHIELD = 30001;
    uint256 public constant ID_RECIPE_WOODEN_CLUB = 30002;
    uint256 public constant ID_RECIPE_WOODEN_BOW = 30003;
    uint256 public constant ID_RECIPE_WOODEN_STAFF = 30004;
    uint256 public constant ID_RECIPE_LEATHER_HELMET = 30005;
    uint256 public constant ID_RECIPE_LEATHER_ARMOR = 30006;
    uint256 public constant ID_RECIPE_LEATHER_BOOTS = 30007;
    uint256 public constant ID_RECIPE_WOODEN_NECKLACE = 30008;
    uint256 public constant ID_RECIPE_WOODEN_RING = 30009;

    // copper tier 2
    uint256 public constant ID_RECIPE_COPPER_SWORD = 30020;
    uint256 public constant ID_RECIPE_COPPER_SHIELD = 30021;
    uint256 public constant ID_RECIPE_COPPER_DAGGER = 30022;
    uint256 public constant ID_RECIPE_COPPER_BOW = 30023;
    uint256 public constant ID_RECIPE_COPPER_STAFF = 30024;
    uint256 public constant ID_RECIPE_COPPER_MACE = 30025;
    uint256 public constant ID_RECIPE_COPPER_AXE = 30026;
    uint256 public constant ID_RECIPE_COPPER_SPEAR = 30027;
    uint256 public constant ID_RECIPE_COPPER_HELMET = 30028;
    uint256 public constant ID_RECIPE_COPPER_ARMOR = 30029;
    uint256 public constant ID_RECIPE_COPPER_BOOTS = 30030;
    uint256 public constant ID_RECIPE_COPPER_NECKLACE = 30031;
    uint256 public constant ID_RECIPE_COPPER_RING = 30032;
    // bronze tier 3
    uint256 public constant ID_RECIPE_BRONZE_SWORD = 30040;
    uint256 public constant ID_RECIPE_BRONZE_SHIELD = 30041;
    uint256 public constant ID_RECIPE_BRONZE_DAGGER = 30042;
    uint256 public constant ID_RECIPE_BRONZE_BOW = 30043;
    uint256 public constant ID_RECIPE_BRONZE_STAFF = 30044;
    uint256 public constant ID_RECIPE_BRONZE_MACE = 30045;
    uint256 public constant ID_RECIPE_BRONZE_AXE = 30046;
    uint256 public constant ID_RECIPE_BRONZE_SPEAR = 30047;
    uint256 public constant ID_RECIPE_BRONZE_HELMET = 30048;
    uint256 public constant ID_RECIPE_BRONZE_ARMOR = 30049;
    uint256 public constant ID_RECIPE_BRONZE_BOOTS = 30050;
    uint256 public constant ID_RECIPE_BRONZE_NECKLACE = 30051;
    uint256 public constant ID_RECIPE_BRONZE_RING = 30052;
    // brass tier 4
    uint256 public constant ID_RECIPE_BRASS_SWORD = 30060;
    uint256 public constant ID_RECIPE_BRASS_SHIELD = 30061;
    uint256 public constant ID_RECIPE_BRASS_DAGGER = 30062;
    uint256 public constant ID_RECIPE_BRASS_BOW = 30063;
    uint256 public constant ID_RECIPE_BRASS_STAFF = 30064;
    uint256 public constant ID_RECIPE_BRASS_MACE = 30065;
    uint256 public constant ID_RECIPE_BRASS_AXE = 30066;
    uint256 public constant ID_RECIPE_BRASS_SPEAR = 30067;
    uint256 public constant ID_RECIPE_BRASS_HELMET = 30068;
    uint256 public constant ID_RECIPE_BRASS_ARMOR = 30069;
    uint256 public constant ID_RECIPE_BRASS_BOOTS = 30070;
    uint256 public constant ID_RECIPE_BRASS_NECKLACE = 30071;
    uint256 public constant ID_RECIPE_BRASS_RING = 30072;
    // iron tier 5
    uint256 public constant ID_RECIPE_IRON_SWORD = 30080;
    uint256 public constant ID_RECIPE_IRON_SHIELD = 30081;
    uint256 public constant ID_RECIPE_IRON_DAGGER = 30082;
    uint256 public constant ID_RECIPE_IRON_BOW = 30083;
    uint256 public constant ID_RECIPE_IRON_STAFF = 30084;
    uint256 public constant ID_RECIPE_IRON_MACE = 30085;
    uint256 public constant ID_RECIPE_IRON_AXE = 30086;
    uint256 public constant ID_RECIPE_IRON_SPEAR = 30087;
    uint256 public constant ID_RECIPE_IRON_HELMET = 30088;
    uint256 public constant ID_RECIPE_IRON_ARMOR = 30089;
    uint256 public constant ID_RECIPE_IRON_BOOTS = 30090;
    uint256 public constant ID_RECIPE_IRON_NECKLACE = 30091;
    uint256 public constant ID_RECIPE_IRON_RING = 30092;

    // monster essence - 80000 - to be added later



    // fantom matter
    uint256 public constant ID_FANTOM_MATTER = 100000;

    // fantom letter
    uint256 public constant ID_FANTOM_LETTER_TICKET = 100100;
    uint256 public constant ID_FANTOM_LETTER_RED_TICKET = 100110;
    uint256 public constant ID_FANTOM_LETTER_ORANGE_TICKET = 100111;
    uint256 public constant ID_FANTOM_LETTER_YELLOW_TICKET = 100112;
    uint256 public constant ID_FANTOM_LETTER_GREEN_TICKET = 100113;
    uint256 public constant ID_FANTOM_LETTER_BLUE_TICKET = 100114;
    uint256 public constant ID_FANTOM_LETTER_INDIGO_TICKET = 100115;
    uint256 public constant ID_FANTOM_LETTER_PURPLE_TICKET = 100116;
    uint256 public constant ID_FANTOM_LETTER_WHITE_TICKET = 100117;
    uint256 public constant ID_FANTOM_LETTER_BLACK_TICKET = 100118;
    uint256 public constant ID_FANTOM_LETTER_GRAY_TICKET = 100119;

    // 120-150
    uint256 public constant ID_FANTOM_LETTER_RARE_TICKET = 100120;

    uint256 public constant ID_FANTOM_LETTER_EPIC_TICKET = 100200;
    uint256 public constant ID_FANTOM_LETTER_EPIC_FIRE_TICKET = 100201;
    uint256 public constant ID_FANTOM_LETTER_EPIC_WATER_TICKET = 100202;
    uint256 public constant ID_FANTOM_LETTER_EPIC_NATURE_TICKET = 100203;
    uint256 public constant ID_FANTOM_LETTER_EPIC_EARTH_TICKET = 100204;
    uint256 public constant ID_FANTOM_LETTER_EPIC_WIND_TICKET = 100205;
    uint256 public constant ID_FANTOM_LETTER_EPIC_ICE_TICKET = 100206;
    uint256 public constant ID_FANTOM_LETTER_EPIC_LIGHTNING_TICKET = 100207;
    uint256 public constant ID_FANTOM_LETTER_EPIC_LIGHT_TICKET = 100208;
    uint256 public constant ID_FANTOM_LETTER_EPIC_DARK_TICKET = 100209;
    uint256 public constant ID_FANTOM_LETTER_EPIC_METAL_TICKET = 100210;
    uint256 public constant ID_FANTOM_LETTER_EPIC_NETHER_TICKET = 100211;
    uint256 public constant ID_FANTOM_LETTER_EPIC_AETHER_TICKET = 100212;

    uint256 public constant ID_FANTOM_LETTER_LEGENDARY_TICKET = 100220;
    uint256 public constant ID_FANTOM_LETTER_LEGENDARY_GEIST_TICKET = 100220;
    uint256 public constant ID_FANTOM_LETTER_LEGENDARY_GRIM_TICKET = 100221;
    uint256 public constant ID_FANTOM_LETTER_LEGENDARY_PAINT_TICKET = 100222;
    uint256 public constant ID_FANTOM_LETTER_LEGENDARY_POPSICLE_TICKET = 100223;
    uint256 public constant ID_FANTOM_LETTER_LEGENDARY_SCREAM_TICKET = 100224;
    uint256 public constant ID_FANTOM_LETTER_LEGENDARY_SPIRIT_TICKET = 100225;
    uint256 public constant ID_FANTOM_LETTER_LEGENDARY_SPOOKY_TICKET = 100226;
    uint256 public constant ID_FANTOM_LETTER_LEGENDARY_TOMB_TICKET = 100227;
    uint256 public constant ID_FANTOM_LETTER_LEGENDARY_TAROT_TICKET = 100228;
    uint256 public constant ID_FANTOM_LETTER_LEGENDARY_ZOO_TICKET = 100229;

    uint256 public constant ID_FANTOM_LETTER_MYTHIC_TICKET = 100300;

    uint256 public constant ID_FANTOM_LETTER_A_TICKET = 100500;
    uint256 public constant ID_FANTOM_LETTER_B_TICKET = 100501;
    uint256 public constant ID_FANTOM_LETTER_C_TICKET = 100502;
    uint256 public constant ID_FANTOM_LETTER_D_TICKET = 100503;
    uint256 public constant ID_FANTOM_LETTER_E_TICKET = 100504;
    uint256 public constant ID_FANTOM_LETTER_F_TICKET = 100505;
    uint256 public constant ID_FANTOM_LETTER_G_TICKET = 100506;
    uint256 public constant ID_FANTOM_LETTER_H_TICKET = 100507;
    uint256 public constant ID_FANTOM_LETTER_I_TICKET = 100508;
    uint256 public constant ID_FANTOM_LETTER_J_TICKET = 100509;
    uint256 public constant ID_FANTOM_LETTER_K_TICKET = 100510;
    uint256 public constant ID_FANTOM_LETTER_L_TICKET = 100511;
    uint256 public constant ID_FANTOM_LETTER_M_TICKET = 100512;
    uint256 public constant ID_FANTOM_LETTER_N_TICKET = 100513;
    uint256 public constant ID_FANTOM_LETTER_O_TICKET = 100514;
    uint256 public constant ID_FANTOM_LETTER_P_TICKET = 100515;
    uint256 public constant ID_FANTOM_LETTER_Q_TICKET = 100516;
    uint256 public constant ID_FANTOM_LETTER_R_TICKET = 100517;
    uint256 public constant ID_FANTOM_LETTER_S_TICKET = 100518;
    uint256 public constant ID_FANTOM_LETTER_T_TICKET = 100519;
    uint256 public constant ID_FANTOM_LETTER_U_TICKET = 100520;
    uint256 public constant ID_FANTOM_LETTER_V_TICKET = 100521;
    uint256 public constant ID_FANTOM_LETTER_W_TICKET = 100522;
    uint256 public constant ID_FANTOM_LETTER_X_TICKET = 100523;
    uint256 public constant ID_FANTOM_LETTER_Y_TICKET = 100524;
    uint256 public constant ID_FANTOM_LETTER_Z_TICKET = 100525;
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface ICurrencyBlocksTokenURIProcessor {
    function getCurrencyBlocksTokenURI(uint256) external view returns(string memory);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface ICryptoBlocksToken {
    function getTokenIdCounterCurrent() external view returns(uint256);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface ICryptoBlocksMintableERC1155 {
    function mint(address, uint256, uint256) external;
    function mintNFT(address) external returns(uint256);
    function mintBridgeNFT(address, uint256, uint256) external returns(uint256);
    function getTotalSupply(uint256) external returns(uint256);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface ICryptoBlocksCrossChain {
    function getMasterMappingTokenId(uint256, uint256) external view returns(uint256);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface ICryptoBlocksAttributes {
    function setBlockAttribute(uint256, uint256, uint256) external;
    function setBlockAttributeString(uint256, uint256, string calldata) external;
    function setBlockAttributeAddress(uint256, uint256, address) external;
    function setBlockAttributeArray(uint256, uint256, uint256[] calldata) external;
    function setBlockAttributeBytes(uint256, uint256, bytes32[] calldata) external;
    function setBlockTokenAddressData(uint256, address, uint256) external;
    function setBlockAddressData(uint256, address, uint256) external;
    function setBlockAddressMapping(uint256, address) external;
    function setBlockUintMapping(uint256, uint256) external;

    event SetBlockAttribute(uint256 indexed tokenId, uint256 indexed attributeId, uint256 attributeValue);
    event SetBlockAttributeString(uint256 indexed tokenId, uint256 indexed attributeId, string attributeStringValue);
    event SetBlockAttributeAddress(uint256 indexed tokenId, uint256 indexed attributeId, address attributeAddressValue);
    event SetBlockAttributeArray(uint256 indexed tokenId, uint256 indexed attributeId, uint256[] attributeArrayValue);
    event SetBlockAttributeBytes(uint256 indexed tokenId, uint256 indexed attributeId, bytes32[] attributeBytesValue);
    event SetBlockTokenAddressData(uint256 indexed tokenId, address indexed account, uint256 data);
    event SetBlockAddressData(uint256 indexed id, address indexed account, uint256 data);
    event SetBlockAddressMapping(uint256 indexed id, address account);
    event SetBlockUintMapping(uint256 indexed id, uint256 value);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface ICryptoBlocks {
    function getBlockAttribute(uint256, uint256) external view returns(uint256);
    function getBlockAttributeString(uint256, uint256) external view returns(string memory);
    function getBlockAttributeAddress(uint256, uint256) external view returns(address);
    function getBlockAttributeArray(uint256, uint256) external view returns(uint256[] memory);
    function getBlockAttributeBytes(uint256, uint256) external view returns(bytes32[] memory);
    function getBlockTokenAddressData(uint256, address) external view returns(uint256);
    function getBlockAddressData(uint256, address) external returns(uint256);
    function getBlockAddressMapping(uint256) external returns(address);
    function getBlockUintMapping(uint256) external returns(uint256);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./lib/AccessControlConstants.sol";
import "./ICryptoBlocks.sol";
import "./ICryptoBlocksAttributes.sol";
import "./lib/CryptoBlocksConstants.sol";

abstract contract CryptoBlocksUpgradeable is Initializable, AccessControlEnumerableUpgradeable, ICryptoBlocksAttributes, ICryptoBlocks {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using StringsUpgradeable for uint256;
    CountersUpgradeable.Counter internal _tokenIdCounter;                        // id for this chain. Will be incremented with bridged tokens
    CountersUpgradeable.Counter internal _masterIdCounter;                       // master id for this chain. Will not be incremented with bridged tokens
    mapping(uint256 => string) internal _tokenURIs;                              // Optional mapping for token URIs
    mapping(uint256 => mapping(uint256 => uint256)) internal _attributes;        // tokenId => attributeId => attributeValue
    mapping(uint256 => mapping(uint256 => string)) internal _attributesString;   // tokenId => attributeId => attributeString
    mapping(uint256 => mapping(uint256 => address)) internal _attributesAddress; // tokenId => attributeId => attributeAddress
    mapping(uint256 => mapping(uint256 => uint256[])) internal _attributesArray; // tokenId => attributeId => attributeArray
    mapping(uint256 => mapping(uint256 => bytes32[])) internal _attributesBytes; // tokenId => attributeId => attributeBytes
    mapping(uint256 => mapping(uint256 => uint256)) internal _masterMapping;     // chainId => masterId => tokenId
    mapping(uint256 => mapping(address => uint256)) internal _tokenAddressData;  // tokenId => address => data
    mapping(uint256 => mapping(address => uint256)) internal _addressData;       // id => address => data
    mapping(uint256 => address) internal _addressMapping;                        // id => stores contract addresses
    mapping(uint256 => uint256) internal _uintMapping;                           // id => uint256 value
    string public baseURI;

    function __CryptoBlocks_init() internal initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __AccessControlEnumerable_init_unchained();
        __CryptoBlocks_init_unchained();
    }

    function __CryptoBlocks_init_unchained() internal initializer {
        _setupRole(AccessControlConstants.DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(AccessControlConstants.ADMIN_ROLE, _msgSender());
        _setupRole(AccessControlConstants.OPERATOR_ROLE, _msgSender());
        _setupRole(AccessControlConstants.MINTER_ROLE, _msgSender());
        _uintMapping[CryptoBlocksConstants.UINT_MAPPING_CHAIN_ID] = block.chainid;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId) ||
        interfaceId == type(ICryptoBlocksAttributes).interfaceId ||
        interfaceId == type(ICryptoBlocks).interfaceId;
    }

    function setBaseURI(string calldata uri_) external virtual onlyRole(AccessControlConstants.ADMIN_ROLE) {
        baseURI = uri_;
    }

    /**
     * @dev Set specific attribute of block
     */
    function setBlockAttribute(uint256 id_, uint256 attributeId_, uint256 attributeValue_) external virtual override onlyRole(AccessControlConstants.OPERATOR_ROLE) {
        _attributes[id_][attributeId_] = attributeValue_;
        // emit SetBlockAttribute(id_, attributeId_, attributeValue_);
    }

    /**
     * @dev Set specific attribute of block
     */
    function setBlockAttributeString(uint256 id_, uint256 attributeId_, string calldata attributeValue_) external virtual override onlyRole(AccessControlConstants.OPERATOR_ROLE) {
        _attributesString[id_][attributeId_] = attributeValue_;
        // emit SetBlockAttributeString(id_, attributeId_, attributeValue_);
    }

    /**
     * @dev Set specific attributeAddress of block
     */
    function setBlockAttributeAddress(uint256 id_, uint256 attributeId_, address attributeAddressValue_) external virtual override onlyRole(AccessControlConstants.OPERATOR_ROLE) {
        _attributesAddress[id_][attributeId_] = attributeAddressValue_;
        // emit SetBlockAttributeAddress(id_, attributeId_, attributeAddressValue_);
    }

    /**
     * @dev Set specific attributeArray of block
     */
    function setBlockAttributeArray(uint256 id_, uint256 attributeId_, uint256[] calldata attributeArrayValue_) external virtual override onlyRole(AccessControlConstants.OPERATOR_ROLE) {
        _attributesArray[id_][attributeId_] = attributeArrayValue_;
        // emit SetBlockAttributeArray(id_, attributeId_, attributeArrayValue_);
    }

    /**
     * @dev Set specific attributeBytes of block
     */
    function setBlockAttributeBytes(uint256 id_, uint256 attributeId_, bytes32[] calldata attributeBytesValue_) external virtual override onlyRole(AccessControlConstants.OPERATOR_ROLE) {
        _attributesBytes[id_][attributeId_] = attributeBytesValue_;
        // emit SetBlockAttributeBytes(id_, attributeId_, attributeBytesValue_);
    }

    /**
     * @dev Set specific data for addresses of block
     */
    function setBlockTokenAddressData(uint256 id_, address address_, uint256 data_) external virtual override onlyRole(AccessControlConstants.OPERATOR_ROLE) {
        _tokenAddressData[id_][address_] = data_;
        // emit SetBlockTokenAddressData(id_, address_, data_);
    }

    /**
     * @dev Set specific data for addresses of id
     */
    function setBlockAddressData(uint256 id_, address address_, uint256 data_) external virtual override onlyRole(AccessControlConstants.OPERATOR_ROLE) {
        _addressData[id_][address_] = data_;
        // emit SetBlockAddressData(id_, address_, data_);
    }

    /**
     * @dev Set specific addresses of id such as contract addresses
     */
    function setBlockAddressMapping(uint256 id_, address address_) external virtual override onlyRole(AccessControlConstants.OPERATOR_ROLE) {
        _addressMapping[id_] = address_;
        // emit SetBlockAddressMapping(id_, address_);
    }

    /**
     * @dev Set specific uint of id such as royalty amount or chainId
     */
    function setBlockUintMapping(uint256 id_, uint256 value_) external virtual override onlyRole(AccessControlConstants.OPERATOR_ROLE) {
        _uintMapping[id_] = value_;
        // emit SetBlockUintMapping(id_, value_);
    }

    function getBlockAttribute(uint256 id_, uint256 attributeId_) external virtual override view returns(uint256) {
        return _attributes[id_][attributeId_];
    }

    function getBlockAttributeString(uint256 id_, uint256 attributeId_) external virtual override view returns(string memory) {
        return _attributesString[id_][attributeId_];
    }

    function getBlockAttributeAddress(uint256 id_, uint256 attributeId_) external virtual override view returns(address) {
        return _attributesAddress[id_][attributeId_];
    }

    function getBlockAttributeArray(uint256 id_, uint256 attributeId_) external virtual override view returns(uint256[] memory) {
        return _attributesArray[id_][attributeId_];
    }

    function getBlockAttributeBytes(uint256 id_, uint256 attributeId_) external virtual override view returns(bytes32[] memory) {
        return _attributesBytes[id_][attributeId_];
    }

    function getBlockTokenAddressData(uint256 id_, address address_) external virtual override view returns(uint256) {
        return _tokenAddressData[id_][address_];
    }

    function getBlockAddressData(uint256 id_, address address_) external virtual override view returns(uint256) {
        return _addressData[id_][address_];
    }

    function getBlockAddressMapping(uint256 id_) external virtual override view returns(address) {
        return _addressMapping[id_];
    }

    function getBlockUintMapping(uint256 id_) external virtual override view returns(uint256) {
        return _uintMapping[id_];
    }

    uint256[35] private __gap;
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "../token/ERC1155/extensions/IERC1155BurnableUpgradeable.sol";
import "../token/ERC1155/extensions/IERC1155SupplyUpgradeable.sol";
import "../token/ERC1155/extensions/ERC1155EnumerableUpgradeable.sol";
import "../token/ERC2981/IERC2981.sol";
import "./ICryptoBlocksCrossChain.sol";
import "./ICryptoBlocksMintableERC1155.sol";
import "./ICryptoBlocksToken.sol";
import "./CryptoBlocksUpgradeable.sol";

abstract contract CryptoBlocksERC1155Upgradeable is Initializable, CryptoBlocksUpgradeable, IERC1155BurnableUpgradeable, ERC1155BurnableUpgradeable, ERC1155SupplyUpgradeable, ERC1155EnumerableUpgradeable, IERC1155SupplyUpgradeable, IERC2981, ICryptoBlocksCrossChain, ICryptoBlocksMintableERC1155, ICryptoBlocksToken {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using StringsUpgradeable for uint256;
    string internal _name;
    string internal _symbol;

    function __CryptoBlocksERC1155_init(string memory name_, string memory symbol_) internal initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __ERC1155_init_unchained("");
        __ERC1155Burnable_init_unchained();
        __ERC1155Supply_init_unchained();
        __ERC1155AfterTokenTransfer_init_unchained();
        __AccessControl_init_unchained();
        __AccessControlEnumerable_init_unchained();
        __CryptoBlocks_init_unchained();
        __CryptoBlocksERC1155_init_unchained(name_, symbol_);
    }

    function __CryptoBlocksERC1155_init_unchained(string memory name_, string memory symbol_) internal initializer {
        _uintMapping[CryptoBlocksConstants.UINT_MAPPING_ROYALTY_AMOUNT] = 50;
        _addressMapping[CryptoBlocksConstants.ADDR_MAPPING_ROYALTY_RECEIVER] = _msgSender();
        _name = name_;
        _symbol = symbol_;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155Upgradeable, CryptoBlocksUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId) ||
        interfaceId == type(IERC1155BurnableUpgradeable).interfaceId ||
        interfaceId == type(IERC2981).interfaceId ||
        interfaceId == type(ICryptoBlocksCrossChain).interfaceId ||
        interfaceId == type(ICryptoBlocksMintableERC1155).interfaceId ||
        interfaceId == type(ICryptoBlocksToken).interfaceId;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function setName(string calldata name_) external onlyRole(AccessControlConstants.ADMIN_ROLE) {
        _name = name_;
    }

    function setSymbol(string calldata symbol_) external onlyRole(AccessControlConstants.ADMIN_ROLE) {
        _symbol = symbol_;
    }

    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        string memory _tokenURI = _tokenURIs[tokenId];

        // If there is no base URI, return the token URI.
        if (bytes(baseURI).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(baseURI, _tokenURI));
        }

        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, _attributes[tokenId][CryptoBlocksConstants.UINT_ORIGIN_CHAIN_ID].toString(), "/", _attributes[tokenId][CryptoBlocksConstants.UINT_MASTER_ID].toString())) : "";
    }

    function setTokenURI(uint256 tokenId_, string calldata tokenURI_) external onlyRole(AccessControlConstants.ADMIN_ROLE) {
        _tokenURIs[tokenId_] = tokenURI_;
        emit URI(tokenURI_, tokenId_);
    }

    function totalSupply(uint256 id) public view virtual override(IERC1155SupplyUpgradeable, ERC1155SupplyUpgradeable) returns(uint256) {
        return super.totalSupply(id);
    }

    function exists(uint256 id) public view virtual override(IERC1155SupplyUpgradeable, ERC1155SupplyUpgradeable) returns(bool) {
        return super.exists(id);
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal override(ERC1155Upgradeable, ERC1155SupplyUpgradeable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public virtual override(ERC1155Upgradeable, ERC1155AfterTokenTransferUpgradeable) {
        super.safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public virtual override(ERC1155Upgradeable, ERC1155AfterTokenTransferUpgradeable) {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function burn(address account, uint256 tokenId, uint256 amount) public override(IERC1155BurnableUpgradeable, ERC1155BurnableUpgradeable) onlyRole(AccessControlConstants.OPERATOR_ROLE) {
        super.burn(account, tokenId, amount);
    }

    function _burn(address account, uint256 id, uint256 amount) internal virtual override(ERC1155Upgradeable, ERC1155AfterTokenTransferUpgradeable) {
        super._burn(account, id, amount);
    }

    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) public override(IERC1155BurnableUpgradeable, ERC1155BurnableUpgradeable) onlyRole(AccessControlConstants.OPERATOR_ROLE) {
        super.burnBatch(account, ids, values);
    }

    function _burnBatch(address account, uint256[] memory ids, uint256[] memory values) internal virtual override(ERC1155Upgradeable, ERC1155AfterTokenTransferUpgradeable) {
        super._burnBatch(account, ids, values);
    }

    function setBaseURI(string calldata uri_) external override onlyRole(AccessControlConstants.ADMIN_ROLE) {
        baseURI = uri_;
        _setURI(baseURI);
    }

    /**
     * @dev Mint Fungible token
     */
    function mint(address to_, uint256 tokenId_, uint256 amount_) external override onlyRole(AccessControlConstants.MINTER_ROLE) {
        _mint(to_, tokenId_, amount_, "");
    }

    /**
     * @dev Mint Non-fungible token. Shouldn't be used if everything is currency
     */
    function mintNFT(address to_) external override onlyRole(AccessControlConstants.MINTER_ROLE) returns(uint256) {
        addBlock();
        uint256 id_ = _tokenIdCounter.current() - 1; // addBlock incremented it already
        _mint(to_, id_, 1, "");
        return id_;
    }

    function mintBridgeNFT(address to_, uint256 chainId_, uint256 masterId_) external override onlyRole(AccessControlConstants.MINTER_ROLE) returns(uint256) {
        uint256 id_ = _tokenIdCounter.current();
        _mint(to_, id_, 1, "");
        _attributes[id_][CryptoBlocksConstants.UINT_CHAIN_ID] = _uintMapping[CryptoBlocksConstants.UINT_MAPPING_CHAIN_ID];
        _attributes[id_][CryptoBlocksConstants.UINT_ORIGIN_CHAIN_ID] = chainId_;
        _attributes[id_][CryptoBlocksConstants.UINT_MASTER_ID] = masterId_;
        _masterMapping[chainId_][masterId_] = id_;
        _tokenIdCounter.increment();
        return id_;
    }

    function _mint(address account, uint256 id, uint256 amount, bytes memory data) internal virtual override(ERC1155Upgradeable, ERC1155AfterTokenTransferUpgradeable) {
        super._mint(account, id, amount, data);
    }

    /**
     * @dev See {ERC1155-_mintBatch}.
     */
    function _mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal virtual override(ERC1155Upgradeable, ERC1155AfterTokenTransferUpgradeable) {
        super._mintBatch(to, ids, amounts, data);
    }

    function getTotalSupply(uint256 tokenId_) external override view returns(uint256) {
        return totalSupply(tokenId_);
    }

    function royaltyInfo(uint256, uint256 salePrice_) external override view returns (address receiver, uint256 royaltyAmount) {
        uint256 royaltyOwed_ = (salePrice_ * _uintMapping[CryptoBlocksConstants.UINT_MAPPING_ROYALTY_AMOUNT]) / 1000;
        return(_addressMapping[CryptoBlocksConstants.ADDR_MAPPING_ROYALTY_RECEIVER], royaltyOwed_);
    }

    /**
     * @dev Add block without minting
     */
    function addBlock() public virtual onlyRole(AccessControlConstants.MINTER_ROLE) {
        uint256 id_ = _tokenIdCounter.current();
        _attributes[id_][CryptoBlocksConstants.UINT_CHAIN_ID] = _uintMapping[CryptoBlocksConstants.UINT_MAPPING_CHAIN_ID];
        _attributes[id_][CryptoBlocksConstants.UINT_ORIGIN_CHAIN_ID] = _uintMapping[CryptoBlocksConstants.UINT_MAPPING_CHAIN_ID];
        _attributes[id_][CryptoBlocksConstants.UINT_MASTER_ID] = _masterIdCounter.current();
        _masterMapping[_uintMapping[CryptoBlocksConstants.UINT_MAPPING_CHAIN_ID]][_masterIdCounter.current()] = id_;
        _tokenIdCounter.increment();
        _masterIdCounter.increment();

        // set dbId to same as id
        _attributes[id_][CryptoBlocksConstants.UINT_DBID] = id_;
        emit SetBlockAttribute(id_, CryptoBlocksConstants.UINT_DBID, id_);
    }

    /**
     * @dev Set block id which sets chainId and masterId. Doesn't increment tokenId
     */
    function setBlock(uint256 id_) external virtual onlyRole(AccessControlConstants.OPERATOR_ROLE) {
        _attributes[id_][CryptoBlocksConstants.UINT_CHAIN_ID] = _uintMapping[CryptoBlocksConstants.UINT_MAPPING_CHAIN_ID];
        _attributes[id_][CryptoBlocksConstants.UINT_ORIGIN_CHAIN_ID] = _uintMapping[CryptoBlocksConstants.UINT_MAPPING_CHAIN_ID];
        _attributes[id_][CryptoBlocksConstants.UINT_MASTER_ID] = _masterIdCounter.current();
        _masterMapping[_uintMapping[CryptoBlocksConstants.UINT_MAPPING_CHAIN_ID]][_masterIdCounter.current()] = id_;

        // set dbId to same as id
        _attributes[id_][CryptoBlocksConstants.UINT_DBID] = id_;
        emit SetBlockAttribute(id_, CryptoBlocksConstants.UINT_DBID, id_);
    }

    /**
     * @dev Get tokenId of this chain from masterId
     */
    function getMasterMappingTokenId(uint256 chainId_, uint256 masterId_) external override view returns(uint256) {
        return _masterMapping[chainId_][masterId_];
    }

    function getTokenIdCounterCurrent() external override view returns(uint256) {
        return _tokenIdCounter.current();
    }

    uint256[48] private __gap;
}

// SPDX-License-Identifier: MIT

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

// SPDX-License-Identifier: MIT

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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

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
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal initializer {
        __ERC165_init_unchained();
    }

    function __ERC165_init_unchained() internal initializer {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
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

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlotUpgradeable {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly {
            r.slot := slot
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library CountersUpgradeable {
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
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

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

pragma solidity ^0.8.0;

import "../IERC1155Upgradeable.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155MetadataURIUpgradeable is IERC1155Upgradeable {
    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view returns (string memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../ERC1155Upgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @dev Extension of ERC1155 that adds tracking of total supply per id.
 *
 * Useful for scenarios where Fungible and Non-fungible tokens have to be
 * clearly identified. Note: While a totalSupply of 1 might mean the
 * corresponding is an NFT, there is no guarantees that no other token with the
 * same id are not going to be minted.
 */
abstract contract ERC1155SupplyUpgradeable is Initializable, ERC1155Upgradeable {
    function __ERC1155Supply_init() internal initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __ERC1155Supply_init_unchained();
    }

    function __ERC1155Supply_init_unchained() internal initializer {
    }
    mapping(uint256 => uint256) private _totalSupply;

    /**
     * @dev Total amount of tokens in with a given id.
     */
    function totalSupply(uint256 id) public view virtual returns (uint256) {
        return _totalSupply[id];
    }

    /**
     * @dev Indicates weither any token exist with a given id, or not.
     */
    function exists(uint256 id) public view virtual returns (bool) {
        return ERC1155SupplyUpgradeable.totalSupply(id) > 0;
    }

    /**
     * @dev See {ERC1155-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                _totalSupply[ids[i]] += amounts[i];
            }
        }

        if (to == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                _totalSupply[ids[i]] -= amounts[i];
            }
        }
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../ERC1155Upgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @dev Extension of {ERC1155} that allows token holders to destroy both their
 * own tokens and those that they have been approved to use.
 *
 * _Available since v3.1._
 */
abstract contract ERC1155BurnableUpgradeable is Initializable, ERC1155Upgradeable {
    function __ERC1155Burnable_init() internal initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __ERC1155Burnable_init_unchained();
    }

    function __ERC1155Burnable_init_unchained() internal initializer {
    }
    function burn(
        address account,
        uint256 id,
        uint256 value
    ) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );

        _burn(account, id, value);
    }

    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory values
    ) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );

        _burnBatch(account, ids, values);
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155Upgradeable is IERC165Upgradeable {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must be have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev _Available since v3.1._
 */
interface IERC1155ReceiverUpgradeable is IERC165Upgradeable {
    /**
        @dev Handles the receipt of a single ERC1155 token type. This function is
        called at the end of a `safeTransferFrom` after the balance has been updated.
        To accept the transfer, this must return
        `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
        (i.e. 0xf23a6e61, or its own function selector).
        @param operator The address which initiated the transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param id The ID of the token being transferred
        @param value The amount of tokens being transferred
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
    */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
        @dev Handles the receipt of a multiple ERC1155 token types. This function
        is called at the end of a `safeBatchTransferFrom` after the balances have
        been updated. To accept the transfer(s), this must return
        `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
        (i.e. 0xbc197c81, or its own function selector).
        @param operator The address which initiated the batch transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param ids An array containing ids of each token being transferred (order and length must match values array)
        @param values An array containing amounts of each token being transferred (order and length must match ids array)
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
    */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC1155Upgradeable.sol";
import "./IERC1155ReceiverUpgradeable.sol";
import "./extensions/IERC1155MetadataURIUpgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/ContextUpgradeable.sol";
import "../../utils/introspection/ERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155Upgradeable is Initializable, ContextUpgradeable, ERC165Upgradeable, IERC1155Upgradeable, IERC1155MetadataURIUpgradeable {
    using AddressUpgradeable for address;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    string private _uri;

    /**
     * @dev See {_setURI}.
     */
    function __ERC1155_init(string memory uri_) internal initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __ERC1155_init_unchained(uri_);
    }

    function __ERC1155_init_unchained(string memory uri_) internal initializer {
        _setURI(uri_);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
        return
            interfaceId == type(IERC1155Upgradeable).interfaceId ||
            interfaceId == type(IERC1155MetadataURIUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the same URI for *all* token types. It relies
     * on the token type ID substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * Clients calling this function must replace the `\{id\}` substring with the
     * actual token type ID.
     */
    function uri(uint256) public view virtual override returns (string memory) {
        return _uri;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: balance query for the zero address");
        return _balances[id][account];
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(_msgSender() != operator, "ERC1155: setting approval status for self");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, _asSingletonArray(id), _asSingletonArray(amount), data);

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    /**
     * @dev Sets a new URI for all token types, by relying on the token type ID
     * substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * By this mechanism, any occurrence of the `\{id\}` substring in either the
     * URI or any of the amounts in the JSON file at said URI will be replaced by
     * clients with the token type ID.
     *
     * For example, the `https://token-cdn-domain/\{id\}.json` URI would be
     * interpreted by clients as
     * `https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json`
     * for token type ID 0x4cce0.
     *
     * See {uri}.
     *
     * Because these URIs cannot be meaningfully represented by the {URI} event,
     * this function emits no events.
     */
    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }

    /**
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `account`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - If `account` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(account != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), account, _asSingletonArray(id), _asSingletonArray(amount), data);

        _balances[id][account] += amount;
        emit TransferSingle(operator, address(0), account, id, amount);

        _doSafeTransferAcceptanceCheck(operator, address(0), account, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `account`
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens of token type `id`.
     */
    function _burn(
        address account,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(account != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, account, address(0), _asSingletonArray(id), _asSingletonArray(amount), "");

        uint256 accountBalance = _balances[id][account];
        require(accountBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][account] = accountBalance - amount;
        }

        emit TransferSingle(operator, account, address(0), id, amount);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(account != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, account, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 accountBalance = _balances[id][account];
            require(accountBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][account] = accountBalance - amount;
            }
        }

        emit TransferBatch(operator, account, address(0), ids, amounts);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155ReceiverUpgradeable(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155ReceiverUpgradeable.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155ReceiverUpgradeable(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155ReceiverUpgradeable.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
    uint256[47] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../ERC1967/ERC1967UpgradeUpgradeable.sol";
import "./Initializable.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 *
 * _Available since v4.1._
 */
abstract contract UUPSUpgradeable is Initializable, ERC1967UpgradeUpgradeable {
    function __UUPSUpgradeable_init() internal initializer {
        __ERC1967Upgrade_init_unchained();
        __UUPSUpgradeable_init_unchained();
    }

    function __UUPSUpgradeable_init_unchained() internal initializer {
    }
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeTo(address newImplementation) external virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallSecure(newImplementation, new bytes(0), false);
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallSecure(newImplementation, data, true);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal override onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

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

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeaconUpgradeable {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "../beacon/IBeaconUpgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/StorageSlotUpgradeable.sol";
import "../utils/Initializable.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967UpgradeUpgradeable is Initializable {
    function __ERC1967Upgrade_init() internal initializer {
        __ERC1967Upgrade_init_unchained();
    }

    function __ERC1967Upgrade_init_unchained() internal initializer {
    }
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(AddressUpgradeable.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallSecure(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        address oldImplementation = _getImplementation();

        // Initial upgrade and setup call
        _setImplementation(newImplementation);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(newImplementation, data);
        }

        // Perform rollback test if not already in progress
        StorageSlotUpgradeable.BooleanSlot storage rollbackTesting = StorageSlotUpgradeable.getBooleanSlot(_ROLLBACK_SLOT);
        if (!rollbackTesting.value) {
            // Trigger rollback using upgradeTo from the new implementation
            rollbackTesting.value = true;
            _functionDelegateCall(
                newImplementation,
                abi.encodeWithSignature("upgradeTo(address)", oldImplementation)
            );
            rollbackTesting.value = false;
            // Check rollback was effective
            require(oldImplementation == _getImplementation(), "ERC1967Upgrade: upgrade breaks further upgrades");
            // Finally reset to the new implementation and log the upgrade
            _upgradeTo(newImplementation);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Emitted when the beacon is upgraded.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(AddressUpgradeable.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            AddressUpgradeable.isContract(IBeaconUpgradeable(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(IBeaconUpgradeable(newBeacon).implementation(), data);
        }
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
        require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return AddressUpgradeable.verifyCallResult(success, returndata, "Address: low-level delegate call failed");
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
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

pragma solidity ^0.8.0;

import "./IAccessControlUpgradeable.sol";

/**
 * @dev External interface of AccessControlEnumerable declared to support ERC165 detection.
 */
interface IAccessControlEnumerableUpgradeable is IAccessControlUpgradeable {
    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IAccessControlUpgradeable.sol";
import "../utils/ContextUpgradeable.sol";
import "../utils/StringsUpgradeable.sol";
import "../utils/introspection/ERC165Upgradeable.sol";
import "../proxy/utils/Initializable.sol";

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
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControlUpgradeable, ERC165Upgradeable {
    function __AccessControl_init() internal initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
    }

    function __AccessControl_init_unchained() internal initializer {
    }
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
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(uint160(account), 20),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
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
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
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
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
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
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
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

    function _grantRole(bytes32 role, address account) private {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function _revokeRole(bytes32 role, address account) private {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IAccessControlEnumerableUpgradeable.sol";
import "./AccessControlUpgradeable.sol";
import "../utils/structs/EnumerableSetUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Extension of {AccessControl} that allows enumerating the members of each role.
 */
abstract contract AccessControlEnumerableUpgradeable is Initializable, IAccessControlEnumerableUpgradeable, AccessControlUpgradeable {
    function __AccessControlEnumerable_init() internal initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __AccessControlEnumerable_init_unchained();
    }

    function __AccessControlEnumerable_init_unchained() internal initializer {
    }
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    mapping(bytes32 => EnumerableSetUpgradeable.AddressSet) private _roleMembers;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlEnumerableUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) public view override returns (address) {
        return _roleMembers[role].at(index);
    }

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) public view override returns (uint256) {
        return _roleMembers[role].length();
    }

    /**
     * @dev Overload {grantRole} to track enumerable memberships
     */
    function grantRole(bytes32 role, address account) public virtual override(AccessControlUpgradeable, IAccessControlUpgradeable) {
        super.grantRole(role, account);
        _roleMembers[role].add(account);
    }

    /**
     * @dev Overload {revokeRole} to track enumerable memberships
     */
    function revokeRole(bytes32 role, address account) public virtual override(AccessControlUpgradeable, IAccessControlUpgradeable) {
        super.revokeRole(role, account);
        _roleMembers[role].remove(account);
    }

    /**
     * @dev Overload {renounceRole} to track enumerable memberships
     */
    function renounceRole(bytes32 role, address account) public virtual override(AccessControlUpgradeable, IAccessControlUpgradeable) {
        super.renounceRole(role, account);
        _roleMembers[role].remove(account);
    }

    /**
     * @dev Overload {_setupRole} to track enumerable memberships
     */
    function _setupRole(bytes32 role, address account) internal virtual override {
        super._setupRole(role, account);
        _roleMembers[role].add(account);
    }
    uint256[49] private __gap;
}