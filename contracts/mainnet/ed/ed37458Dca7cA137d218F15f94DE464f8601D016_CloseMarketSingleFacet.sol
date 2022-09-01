// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.16;

import { AppStorage, LibAppStorage, Position, Fill } from "../../../libraries/LibAppStorage.sol";
import { LibMaster } from "../../../libraries/LibMaster.sol";
import { C } from "../../../C.sol";
import "../../../libraries/LibEnums.sol";

/**
 * Close a Position through a Market order.
 * @dev Can only be done via the original partyB (hedgerMode=Single).
 */
contract CloseMarketSingleFacet {
    AppStorage internal s;

    function requestCloseMarket(uint256 positionId) external {
        Position storage position = s.ma._allPositionsMap[positionId];

        require(position.partyA == msg.sender, "Invalid party");
        require(position.state == PositionState.OPEN, "Invalid position state");

        position.state = PositionState.MARKET_CLOSE_REQUESTED;
        position.mutableTimestamp = block.timestamp;

        // TODO: emit event
    }

    function cancelCloseMarket(uint256 positionId) external {
        Position storage position = s.ma._allPositionsMap[positionId];

        require(position.partyA == msg.sender, "Invalid party");
        require(position.state == PositionState.MARKET_CLOSE_REQUESTED, "Invalid position state");

        position.state = PositionState.MARKET_CLOSE_CANCELATION_REQUESTED;
        position.mutableTimestamp = block.timestamp;

        // TODO: emit event
    }

    function forceCancelCloseMarket(uint256 positionId) public {
        Position storage position = s.ma._allPositionsMap[positionId];

        require(position.partyA == msg.sender, "Invalid party");
        require(position.state == PositionState.MARKET_CLOSE_CANCELATION_REQUESTED, "Invalid position state");
        require(position.mutableTimestamp + C.getRequestTimeout() < block.timestamp, "Request Timeout");

        position.state = PositionState.OPEN;
        position.mutableTimestamp = block.timestamp;

        // TODO: emit event
    }

    function acceptCancelCloseMarket(uint256 positionId) external {
        Position storage position = s.ma._allPositionsMap[positionId];

        require(position.partyB == msg.sender, "Invalid party");
        require(position.state == PositionState.MARKET_CLOSE_CANCELATION_REQUESTED, "Invalid position state");

        position.state = PositionState.OPEN;
        position.mutableTimestamp = block.timestamp;

        // TODO: emit event
    }

    function rejectCloseMarket(uint256 positionId) external {
        Position storage position = s.ma._allPositionsMap[positionId];

        require(position.partyB == msg.sender, "Invalid party");
        require(position.state == PositionState.MARKET_CLOSE_REQUESTED, "Invalid position state");

        position.state = PositionState.OPEN;
        position.mutableTimestamp = block.timestamp;

        // TODO: emit event
    }

    function fillCloseMarket(uint256 positionId, uint256 avgPriceUsd) external {
        Position storage position = s.ma._allPositionsMap[positionId];

        require(position.partyB == msg.sender, "Invalid party");
        require(position.state == PositionState.MARKET_CLOSE_REQUESTED, "Invalid position state");

        // Add the Fill
        Fill memory fill = LibMaster.createFill(position.side, position.currentBalanceUnits, avgPriceUsd);
        s.ma._positionFills[positionId].push(fill);

        // Calculate the PnL of PartyA
        (int256 pnlA, ) = LibMaster.calculateUPnLIsolated(
            position.side,
            position.currentBalanceUnits,
            position.initialNotionalUsd,
            avgPriceUsd,
            avgPriceUsd
        );

        // Distribute the PnL accordingly
        LibMaster.distributePnL(position.partyA, position.partyB, pnlA);

        // Update Position
        position.state = PositionState.CLOSED;
        position.currentBalanceUnits = 0;
        position.mutableTimestamp = block.timestamp;

        // Update mappings
        LibMaster.removeOpenPosition(position.partyA, positionId);
        LibMaster.removeOpenPosition(position.partyB, positionId);

        // TODO: emit event
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.16;
import "./LibEnums.sol";

struct Hedger {
    address addr;
    string[] pricingWssURLs;
    string[] marketsHttpsURLs;
    bool slippageControl;
}

struct Market {
    uint256 _marketId;
    string identifier;
    MarketType marketType;
    TradingSession tradingSession;
    bool active;
    string baseCurrency;
    string quoteCurrency;
    string symbol;
}

struct RequestForQuote {
    uint256 rfqId;
    RequestForQuoteState state;
    OrderType orderType;
    address partyA;
    address partyB;
    HedgerMode hedgerMode;
    uint256 marketId;
    Side side;
    uint256 notionalUsd;
    uint16 leverageUsed;
    uint256 marginRequiredPercentage;
    uint256 lockedMarginA;
    uint256 lockedMarginB;
    uint256 creationTimestamp;
    uint256 mutableTimestamp;
}

struct Fill {
    Side side;
    uint256 filledAmountUnits;
    uint256 avgPriceUsd;
    uint256 timestamp;
}

struct Position {
    uint256 positionId;
    PositionState state;
    uint256 marketId;
    address partyA;
    address partyB;
    uint256 lockedMarginA;
    uint256 lockedMarginB;
    uint16 leverageUsed;
    Side side;
    uint256 currentBalanceUnits;
    uint256 initialNotionalUsd;
    uint256 creationTimestamp;
    uint256 mutableTimestamp;
}

struct HedgersState {
    mapping(address => Hedger) _hedgerMap;
    Hedger[] _hedgerList;
}

struct MarketsState {
    mapping(uint256 => Market) _marketMap;
    Market[] _marketList;
}

struct MAState {
    mapping(address => mapping(uint256 => RequestForQuote)) _requestForQuoteMap;
    mapping(address => uint256) _requestForQuotesLength;
    mapping(address => uint256) _accountBalances;
    mapping(address => uint256) _marginBalances;
    mapping(address => uint256) _lockedMargin;
    mapping(address => uint256) _lockedMarginReserved;
    mapping(uint256 => Position) _allPositionsMap;
    uint256 _allPositionsLength;
    mapping(address => uint256[]) _openPositionsList;
    mapping(uint256 => Fill[]) _positionFills;
}

struct AppStorage {
    bool paused;
    uint128 pausedAt;
    uint256 reentrantStatus;
    address ownerCandidate;
    HedgersState hedgers;
    MarketsState markets;
    MAState ma;
}

library LibAppStorage {
    function diamondStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.16;

import { AppStorage, LibAppStorage, RequestForQuote, Position, Fill } from "../libraries/LibAppStorage.sol";
import { Decimal } from "../libraries/LibDecimal.sol";
import { SchnorrSign } from "../interfaces/IMuonV02.sol";
import { LibOracle } from "../libraries/LibOracle.sol";
import { MarketPrice } from "../interfaces/IOracle.sol";
import { C } from "../C.sol";
import "../libraries/LibEnums.sol";

library LibMaster {
    using Decimal for Decimal.D256;

    // --------------------------------//
    //---- INTERNAL WRITE FUNCTIONS ---//
    // --------------------------------//

    function onRequestForQuote(
        address partyA,
        address partyB,
        uint256 marketId,
        OrderType orderType,
        HedgerMode hedgerMode,
        Side side,
        uint256 usdAmount,
        uint16 leverage,
        uint8 marginRequiredPercentage,
        MarketPrice[] calldata marketPrices,
        bytes calldata reqId,
        SchnorrSign[] calldata sigs
    ) internal returns (RequestForQuote memory rfq) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 lockedMarginA = calculateLockedMargin(usdAmount * leverage, marginRequiredPercentage, false);
        uint256 lockedMarginB = calculateLockedMargin(usdAmount * leverage, marginRequiredPercentage, true);
        require(lockedMarginA <= s.ma._marginBalances[partyA], "Insufficient margin balance");

        // Validate raw oracle signatures. Can be bypassed if a user has no open positions.
        if (s.ma._openPositionsList[partyA].length > 0) {
            bool valid = LibOracle.isValidMarketPrices(marketPrices, reqId, sigs);
            require(valid, "Invalid oracle inputs");
        }
        /**
         * Note: We don't have to guesstimate the solvency post-trade,
         * because the isolated marginHealth will be 100% at T=0. Thus,
         * it will have no effect on the cross margin health.
         */
        (int256 uPnLCrossA, ) = LibMaster.calculateUPnLCross(marketPrices, partyA);
        require(
            LibMaster.solvencySafeguardToTrade(s.ma._lockedMargin[partyA], uPnLCrossA, false),
            "PartyA fails solvency safeguard"
        );

        uint256 currentRfqId = s.ma._requestForQuotesLength[partyA];

        rfq = RequestForQuote(
            currentRfqId,
            RequestForQuoteState.ORPHAN,
            orderType,
            partyA,
            partyB,
            hedgerMode,
            marketId,
            side,
            usdAmount * leverage,
            leverage,
            marginRequiredPercentage,
            lockedMarginA,
            lockedMarginB,
            block.timestamp,
            block.timestamp
        );

        s.ma._requestForQuoteMap[partyA][currentRfqId] = rfq;
        s.ma._requestForQuotesLength[partyA]++;

        /// @notice We will only lock partyB's margin once he accepts the RFQ.
        s.ma._marginBalances[partyA] -= lockedMarginA;
        s.ma._lockedMarginReserved[partyA] += lockedMarginA;
    }

    function createFill(
        Side side,
        uint256 amountUnits,
        uint256 avgPriceUsd
    ) internal view returns (Fill memory fill) {
        fill = Fill(side == Side.BUY ? Side.SELL : Side.BUY, amountUnits, avgPriceUsd, block.timestamp);
    }

    function distributePnL(
        address partyA,
        address partyB,
        int256 pnlA
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        /**
         * Winning party receives the PNL.
         * Losing party pays for the PNL using his lockedMargin.
         *
         * Note: the winning party will NOT receive his lockedMargin back,
         * he'll have to withdraw it manually. This has to do with the
         * risk of liquidation + the fact that his initially lockedMargin
         * could be greater than what he currently has locked.
         */
        if (pnlA >= 0) {
            s.ma._marginBalances[partyA] += uint256(pnlA);
            s.ma._lockedMargin[partyB] -= uint256(pnlA);
        } else {
            s.ma._marginBalances[partyB] += uint256(pnlA);
            s.ma._lockedMargin[partyA] -= uint256(pnlA);
        }
    }

    function removeOpenPosition(address party, uint256 positionId) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        int256 index = -1;
        for (uint256 i = 0; i < s.ma._openPositionsList[party].length; i++) {
            if (s.ma._openPositionsList[party][i] == positionId) {
                index = int256(i);
                break;
            }
        }
        require(index != -1, "Position not found");

        s.ma._openPositionsList[party][uint256(index)] = s.ma._openPositionsList[party][
            s.ma._openPositionsList[party].length - 1
        ];
        s.ma._openPositionsList[party].pop();
    }

    // --------------------------------//
    //---- INTERNAL VIEW FUNCTIONS ----//
    // --------------------------------//

    function getOpenPositions(address party) internal view returns (Position[] memory positions) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256[] memory positionIds = s.ma._openPositionsList[party];

        positions = new Position[](positionIds.length);
        for (uint256 i = 0; i < positionIds.length; i++) {
            positions[i] = s.ma._allPositionsMap[positionIds[i]];
        }
    }

    // TODO: upgrade to new 'realLeverage' system
    function calculateLockedMargin(
        uint256 notionalUsd,
        uint8 marginRequiredPercentage,
        bool isHedger // TODO: give this meaning
    ) internal pure returns (uint256) {
        Decimal.D256 memory multiplier = Decimal.one().add(C.getMarginOverhead()).add(C.getLiquidationFee());
        return Decimal.from(notionalUsd).mul(Decimal.ratio(marginRequiredPercentage, 100)).mul(multiplier).asUint256();
    }

    function calculateUPnLCross(MarketPrice[] memory marketPrices, address party)
        internal
        view
        returns (int256 uPnLCross, int256 notionalCross)
    {
        (uPnLCross, notionalCross) = _calculateUPnLCross(marketPrices, getOpenPositions(party));
    }

    /**
        Initial Units: 2
        Initial Price: 5
        Initial Notional: 2 * 5 = 10
        Current Price: 6

        Long: 
            Current Notional: 2 * 6 = 12
            PNL = CurrentNotional - InitialNotional 
                = 12 - 10 = +2 PROFIT
        Short:
            TEMP Current notional: 2 * 6 = 12
            PNL = InitialNotional - CurrentNotional
                = 10 - 12 = -2 LOSS
            Current Notional: VirtualNotional + (PNL * 2)
                = 12 + (-2 * 2) = 8
    */
    function calculateUPnLIsolated(
        Side side,
        uint256 currentBalanceUnits,
        uint256 initialNotionalUsd,
        uint256 bidPrice,
        uint256 askPrice
    ) internal pure returns (int256 uPnL, int256 notionalIsolated) {
        if (currentBalanceUnits == 0) return (0, 0);

        uint256 precision = C.getPrecision();

        if (side == Side.BUY) {
            require(bidPrice != 0, "Oracle bidPrice is invalid");
            notionalIsolated = int256((currentBalanceUnits * bidPrice) / precision);
            uPnL = notionalIsolated - int256(initialNotionalUsd);
        } else {
            require(askPrice != 0, "Oracle askPrice is invalid");
            int256 tempNotionalIsolated = int256((currentBalanceUnits * askPrice) / precision);
            uPnL = int256(initialNotionalUsd) - tempNotionalIsolated;
            notionalIsolated = tempNotionalIsolated + (uPnL * 2);
        }
    }

    function calculateCrossMarginHealth(uint256 _lockedMargin, int256 uPnLCross)
        internal
        pure
        returns (Decimal.D256 memory ratio)
    {
        int256 lockedMargin = int256(_lockedMargin);

        if (lockedMargin == 0) {
            return Decimal.ratio(1, 1);
        } else if (lockedMargin + uPnLCross <= 0) {
            return Decimal.zero();
        }

        ratio = Decimal.ratio(uint256(lockedMargin + uPnLCross), uint256(lockedMargin));
    }

    /**
     * A party (user and/or hedger) isn't allowed to open a trade if he's near insolvency.
     * This restriction is put in place to protect the hedger against concurrency
     * problematics. Instead, the party is encouraged to top-up his locked margin via addFreeMargin.
     */
    function solvencySafeguardToTrade(
        uint256 lockedMargin,
        int256 uPnLCross,
        bool isHedger
    ) internal pure returns (bool) {
        Decimal.D256 memory ratio = calculateCrossMarginHealth(lockedMargin, uPnLCross);
        Decimal.D256 memory threshold = C.getSolvencyThresholdToTrade(isHedger);
        return ratio.greaterThanOrEqualTo(threshold);
    }

    function solvencySafeguardToRemoveLockedMargin(
        uint256 lockedMargin,
        int256 uPnLCross,
        bool isHedger
    ) internal pure returns (bool) {
        Decimal.D256 memory ratio = calculateCrossMarginHealth(lockedMargin, uPnLCross);
        Decimal.D256 memory threshold = C.getSolvencyThresholdToRemoveLockedMargin(isHedger);
        return ratio.greaterThanOrEqualTo(threshold);
    }

    function isValidLeverage(uint16 leverage) internal pure returns (bool) {
        return leverage > 0 && leverage <= C.getMaxLeverage();
    }

    // --------------------------------//
    //----- PRIVATE VIEW FUNCTIONS ----//
    // --------------------------------//

    /**
     * Returns the UPnL of a party across all his open positions.
     *
     * @notice This function consumes a lot of gas, so make sure to limit `marketPrices`
     * strictly to the markets that the party has open positions with.
     *
     * @dev We assume the signature of `marketPrices` is already validated by parent caller.
     */
    function _calculateUPnLCross(MarketPrice[] memory marketPrices, Position[] memory positions)
        private
        pure
        returns (int256 uPnLCross, int256 notionalCross)
    {
        require(marketPrices.length <= positions.length, "Redundant marketPrices");
        if (positions.length == 0) {
            return (0, 0);
        }

        uint256 count;
        for (uint256 i = 0; i < marketPrices.length; i++) {
            uint256 marketId = marketPrices[i].marketId;
            uint256 bidPrice = marketPrices[i].bidPrice;
            uint256 askPrice = marketPrices[i].askPrice;

            for (uint256 j = 0; j < positions.length; j++) {
                if (positions[j].marketId == marketId) {
                    (int256 _uPnLIsolated, int256 _notionalIsolated) = calculateUPnLIsolated(
                        positions[j].side,
                        positions[j].currentBalanceUnits,
                        positions[j].initialNotionalUsd,
                        bidPrice,
                        askPrice
                    );
                    uPnLCross += _uPnLIsolated;
                    notionalCross += _notionalIsolated;
                    count++;
                }
            }
        }

        require(count == positions.length, "Incomplete price feeds");
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.16;

import { Decimal } from "./libraries/LibDecimal.sol";

library C {
    using Decimal for Decimal.D256;

    // Collateral
    address private constant COLLATERAL = 0x63618c1aB39a848a789b88599f88186A11F785A2; // TODO

    // System
    uint256 private constant PERCENT_BASE = 1e18;
    uint256 private constant PRECISION = 1e18;

    // Oracle
    address private constant MUON = 0xE4F8d9A30936a6F8b17a73dC6fEb51a3BBABD51A;
    uint16 private constant MUON_APP_ID = 0; // TODO
    uint8 private constant MIN_REQUIRED_SIGNATURES = 0; // TODO

    // Configuration
    uint256 private constant MARGIN_OVERHEAD = 0.5e18; // 50%
    uint256 private constant LIQUIDATION_FEE = 0.1e18; // 10%

    uint16 private constant MAX_LEVERAGE = 1000;

    uint256 private constant SOLVENCY_THRESHOLD_TRADE_USER = 0.3e18; // 30%
    uint256 private constant SOLVENCY_THRESHOLD_TRADE_HEDGER = 0; // 0%

    uint256 private constant SOLVENCY_THRESHOLD_REMOVE_USER = 1e18; // 30%
    uint256 private constant SOLVENCY_THRESHOLD_REMOVE_HEDGER = 0.5e18; // 0%

    uint256 private constant REQUEST_TIMEOUT = 1 minutes;

    function getCollateral() internal pure returns (address) {
        return COLLATERAL;
    }

    function getPrecision() internal pure returns (uint256) {
        return PRECISION;
    }

    function getMuon() internal pure returns (address) {
        return MUON;
    }

    function getMuonAppId() internal pure returns (uint16) {
        return MUON_APP_ID;
    }

    function getMinimumRequiredSignatures() internal pure returns (uint8) {
        return MIN_REQUIRED_SIGNATURES;
    }

    function getMaxLeverage() internal pure returns (uint16) {
        return MAX_LEVERAGE;
    }

    function getMarginOverhead() internal pure returns (Decimal.D256 memory) {
        return Decimal.ratio(MARGIN_OVERHEAD, PERCENT_BASE);
    }

    function getLiquidationFee() internal pure returns (Decimal.D256 memory) {
        return Decimal.ratio(LIQUIDATION_FEE, PERCENT_BASE);
    }

    function getSolvencyThresholdToTrade(bool isHedger) internal pure returns (Decimal.D256 memory) {
        return
            isHedger
                ? Decimal.ratio(SOLVENCY_THRESHOLD_TRADE_HEDGER, PERCENT_BASE)
                : Decimal.ratio(SOLVENCY_THRESHOLD_TRADE_USER, PERCENT_BASE);
    }

    function getSolvencyThresholdToRemoveLockedMargin(bool isHedger) internal pure returns (Decimal.D256 memory) {
        return
            isHedger
                ? Decimal.ratio(SOLVENCY_THRESHOLD_REMOVE_HEDGER, PERCENT_BASE)
                : Decimal.ratio(SOLVENCY_THRESHOLD_REMOVE_USER, PERCENT_BASE);
    }

    function getRequestTimeout() internal pure returns (uint256) {
        return REQUEST_TIMEOUT;
    }

    function getChainId() internal view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.16;

enum MarketType {
    FOREX,
    CRYPTO,
    STOCK
}

enum TradingSession {
    _24_7,
    _24_5
}

enum Side {
    BUY,
    SELL
}

enum HedgerMode {
    SINGLE,
    HYBRID,
    AUTO
}

enum OrderType {
    LIMIT,
    MARKET
}

enum RequestForQuoteState {
    ORPHAN,
    CANCELATION_REQUESTED,
    CANCELED,
    REJECTED,
    ACCEPTED
}

enum PositionState {
    OPEN,
    MARKET_CLOSE_REQUESTED,
    MARKET_CLOSE_CANCELATION_REQUESTED,
    LIMIT_CLOSE_REQUESTED,
    LIMIT_CLOSE_CANCELATION_REQUESTED,
    LIMIT_CLOSE_ACTIVE,
    CLOSED,
    LIQUIDATED
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title Decimal
 * @author dYdX
 *
 * Library that defines a fixed-point number with 18 decimal places.
 */
library Decimal {
    using SafeMath for uint256;

    // ============ Constants ============

    uint256 constant BASE = 10**18;

    // ============ Structs ============

    struct D256 {
        uint256 value;
    }

    // ============ Static Functions ============

    function zero() internal pure returns (D256 memory) {
        return D256({ value: 0 });
    }

    function one() internal pure returns (D256 memory) {
        return D256({ value: BASE });
    }

    function from(uint256 a) internal pure returns (D256 memory) {
        return D256({ value: a.mul(BASE) });
    }

    function ratio(uint256 a, uint256 b) internal pure returns (D256 memory) {
        return D256({ value: getPartial(a, BASE, b) });
    }

    // ============ Self Functions ============

    function add(D256 memory self, uint256 b) internal pure returns (D256 memory) {
        return D256({ value: self.value.add(b.mul(BASE)) });
    }

    function sub(D256 memory self, uint256 b) internal pure returns (D256 memory) {
        return D256({ value: self.value.sub(b.mul(BASE)) });
    }

    function sub(
        D256 memory self,
        uint256 b,
        string memory reason
    ) internal pure returns (D256 memory) {
        return D256({ value: self.value.sub(b.mul(BASE), reason) });
    }

    function mul(D256 memory self, uint256 b) internal pure returns (D256 memory) {
        return D256({ value: self.value.mul(b) });
    }

    function div(D256 memory self, uint256 b) internal pure returns (D256 memory) {
        return D256({ value: self.value.div(b) });
    }

    function pow(D256 memory self, uint256 b) internal pure returns (D256 memory) {
        if (b == 0) {
            return one();
        }

        D256 memory temp = D256({ value: self.value });
        for (uint256 i = 1; i < b; ++i) {
            temp = mul(temp, self);
        }

        return temp;
    }

    function add(D256 memory self, D256 memory b) internal pure returns (D256 memory) {
        return D256({ value: self.value.add(b.value) });
    }

    function sub(D256 memory self, D256 memory b) internal pure returns (D256 memory) {
        return D256({ value: self.value.sub(b.value) });
    }

    function sub(
        D256 memory self,
        D256 memory b,
        string memory reason
    ) internal pure returns (D256 memory) {
        return D256({ value: self.value.sub(b.value, reason) });
    }

    function mul(D256 memory self, D256 memory b) internal pure returns (D256 memory) {
        return D256({ value: getPartial(self.value, b.value, BASE) });
    }

    function div(D256 memory self, D256 memory b) internal pure returns (D256 memory) {
        return D256({ value: getPartial(self.value, BASE, b.value) });
    }

    function equals(D256 memory self, D256 memory b) internal pure returns (bool) {
        return self.value == b.value;
    }

    function greaterThan(D256 memory self, D256 memory b) internal pure returns (bool) {
        return compareTo(self, b) == 2;
    }

    function lessThan(D256 memory self, D256 memory b) internal pure returns (bool) {
        return compareTo(self, b) == 0;
    }

    function greaterThanOrEqualTo(D256 memory self, D256 memory b) internal pure returns (bool) {
        return compareTo(self, b) > 0;
    }

    function lessThanOrEqualTo(D256 memory self, D256 memory b) internal pure returns (bool) {
        return compareTo(self, b) < 2;
    }

    function isZero(D256 memory self) internal pure returns (bool) {
        return self.value == 0;
    }

    function asUint256(D256 memory self) internal pure returns (uint256) {
        return self.value.div(BASE);
    }

    // ============ Core Methods ============

    function getPartial(
        uint256 target,
        uint256 numerator,
        uint256 denominator
    ) private pure returns (uint256) {
        return target.mul(numerator).div(denominator);
    }

    function compareTo(D256 memory a, D256 memory b) private pure returns (uint256) {
        if (a.value == b.value) {
            return 1;
        }
        return a.value > b.value ? 2 : 0;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.16;

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

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.16;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MarketPrice } from "../interfaces/IOracle.sol";
import { SchnorrSign, IMuonV02 } from "../interfaces/IMuonV02.sol";
import { C } from "../C.sol";

library LibOracle {
    using ECDSA for bytes32;

    function isValidMarketPrices(
        MarketPrice[] calldata marketPrices,
        bytes calldata reqId,
        SchnorrSign[] calldata sigs
    ) internal returns (bool) {
        require(sigs.length >= C.getMinimumRequiredSignatures(), "Insufficient signatures");

        bytes32 hash = keccak256(abi.encode(marketPrices, C.getChainId(), C.getMuonAppId()));
        IMuonV02 _muon = IMuonV02(C.getMuon());

        // bool valid = _muon.verify(reqId, uint256(hash), sigs);
        // TODO: return `valid` once we've integrated Muon.
        return true;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.16;

struct MarketPrice {
    uint256 marketId;
    uint256 bidPrice;
    uint256 askPrice;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

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
library SafeMath {
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
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
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
// OpenZeppelin Contracts (last updated v4.7.3) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "../Strings.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
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