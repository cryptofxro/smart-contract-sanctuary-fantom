// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "../OpenOraclePriceData.sol";
import "./UniswapConfig.sol";
import "./UniswapLib.sol";
import "../../VelodromePairPriceOracle/VelodromePairPriceOracle.sol";

interface RegistryForUAV {
    function getPriceForAsset(address cToken) external view returns (uint256);
}

interface IVelodromeLikePairForUAV {
    // gives the current twap price measured from amountIn * tokenIn gives amountOut
    function current(address tokenIn, uint amountIn) external view returns (uint amountOut);
}

struct Observation {
    uint timestamp;
    uint acc;
}

contract UniswapAnchoredView is UniswapConfig, VelodromePairPriceOracle {
    using FixedPoint for *;

    string[] public autoPokingSymbols;

    /// @notice The Open Oracle Price Data contract
    OpenOraclePriceData public immutable priceData;

    /// @notice The number of wei in 1 ETH
    uint public constant ethBaseUnit = 1e18;

    /// @notice A common scaling factor to maintain precision
    uint public constant expScale = 1e18;

    /// @notice The Open Oracle Reporter
    address public immutable reporter;

    /// @notice The highest ratio of the new price to the anchor price that will still trigger the price to be updated
    uint public immutable upperBoundAnchorRatio;

    /// @notice The lowest ratio of the new price to the anchor price that will still trigger the price to be updated
    uint public immutable lowerBoundAnchorRatio;

    /// @notice The minimum amount of time in seconds required for the old uniswap price accumulator to be replaced
    uint public immutable anchorPeriod;

    /// @notice Official prices by symbol hash
    mapping(bytes32 => uint) public prices;

    /// @notice Last 'Official price' update timestamp
    /// OLA_ADDITIONS : This field
    mapping(bytes32 => uint) public pricesLastUpdate;

    /// @notice Circuit breaker for using anchor price oracle directly, ignoring reporter
    bool public reporterInvalidated;

    /// @notice The old observation for each symbolHash
    mapping(bytes32 => Observation) public oldObservations;

    /// @notice The new observation for each symbolHash
    mapping(bytes32 => Observation) public newObservations;

    /// @notice The event emitted when new prices are posted but the stored price is not updated due to the anchor
    event PriceGuarded(string symbol, uint reporter, uint anchor);

    /// @notice The event emitted when the stored price is updated
    event PriceUpdated(string symbol, uint price);

    /// @notice The event emitted when anchor price is updated
    event AnchorPriceUpdated(string symbol, uint anchorPrice, uint oldTimestamp, uint newTimestamp);

    /// @notice The event emitted when the uniswap window changes
    event UniswapWindowUpdated(bytes32 indexed symbolHash, uint oldTimestamp, uint newTimestamp, uint oldPrice, uint newPrice);

    /// @notice The event emitted when reporter invalidates itself
    event ReporterInvalidated(address reporter);

    bytes32 constant ethHash = keccak256(abi.encodePacked("ETH"));
    bytes32 constant rotateHash = keccak256(abi.encodePacked("rotate"));
    string public referenceAssetSymbol;
    bytes32 public referenceAssetHash;
    uint public usdBaseUnit;
    address public registry;

    /**
     * @notice Construct a uniswap anchored view for a set of token configurations
     * @dev Note that to avoid immature TWAPs, the system must run for at least a single anchorPeriod before using.
     * @param reporter_ The reporter whose prices are to be used
     * @param referenceAssetSymbol_ The asset('s symbol) to measure the prices of all other (non fixed) assets against.
     * @param usdBaseUnit_ Amount that equal to 1 scaled by the base USD token decimals.
     * @param anchorToleranceMantissa_ The percentage tolerance that the reporter may deviate from the uniswap anchor
     * @param anchorPeriod_ The minimum amount of time required for the old uniswap price accumulator to be replaced
     * @param configs The static token configurations which define what prices are supported and how
     */
    constructor(OpenOraclePriceData priceData_,
                address reporter_,
                string memory referenceAssetSymbol_,
                uint usdBaseUnit_,
                uint anchorToleranceMantissa_,
                uint anchorPeriod_,
                address registry_,
                TokenConfig[] memory configs,
                string[] memory _autoPokingSymbols) UniswapConfig(configs) public {
        priceData = priceData_;
        reporter = reporter_;
        anchorPeriod = anchorPeriod_;
        registry = registry_;
        autoPokingSymbols = _autoPokingSymbols;

        referenceAssetSymbol = referenceAssetSymbol_;
        referenceAssetHash = keccak256(abi.encodePacked(referenceAssetSymbol));
        usdBaseUnit = usdBaseUnit_;

        // Allow the tolerance to be whatever the deployer chooses, but prevent under/overflow (and prices from being 0)
        upperBoundAnchorRatio = anchorToleranceMantissa_ > uint(-1) - 100e16 ? uint(-1) : 100e16 + anchorToleranceMantissa_;
        lowerBoundAnchorRatio = anchorToleranceMantissa_ < 100e16 ? 100e16 - anchorToleranceMantissa_ : 1;

        for (uint i = 0; i < configs.length; i++) {
            TokenConfig memory config = configs[i];
            require(config.baseUnit > 0, "baseUnit must be greater than zero");
            address uniswapMarket = config.uniswapMarket;
            if (config.priceSource == PriceSource.REPORTER || config.priceSource == PriceSource.UNISWAP) {
                require(uniswapMarket != address(0), "reported prices must have an anchor");

                if (config.pairType == PairType.UniV2Like) {
                    bytes32 symbolHash = config.symbolHash;
                    uint cumulativePrice = currentCumulativePrice(config);
                    oldObservations[symbolHash].timestamp = block.timestamp;
                    newObservations[symbolHash].timestamp = block.timestamp;
                    oldObservations[symbolHash].acc = cumulativePrice;
                    newObservations[symbolHash].acc = cumulativePrice;
                    emit UniswapWindowUpdated(symbolHash, block.timestamp, block.timestamp, cumulativePrice, cumulativePrice);
                } else if (config.pairType == PairType.VelodromeLike) {
                    initializeVelodromePair(config.uniswapMarket);
                }
            } else {
                require(uniswapMarket == address(0), "only reported prices utilize an anchor");
            }

            require(PriceSource.ORACLE != config.priceSource || address(0) != registry_, "Registry address required for using oracle asset");
        }
    }

    /**
     * @notice Get the array of symbols that can be auto poked.
     */
    function getAllAutoPokingSymbols() external view returns (string[] memory) {
        return autoPokingSymbols;
    }

    /**
     * @notice Get the official price for a symbol
     * @param symbol The symbol to fetch the price of
     * @return Price denominated in USD, with 6 decimals
     */
    function price(string memory symbol) external view returns (uint) {
        TokenConfig memory config = getTokenConfigBySymbol(symbol);
        return priceInternal(config);
    }

    function priceInternal(TokenConfig memory config) internal view returns (uint) {
        if (config.priceSource == PriceSource.REPORTER || config.priceSource == PriceSource.UNISWAP || config.priceSource == PriceSource.SIGNED_ONLY || config.priceSource == PriceSource.ORACLE) return prices[config.symbolHash];
        if (config.priceSource == PriceSource.FIXED_USD) return config.fixedPrice;
        if (config.priceSource == PriceSource.FIXED_ETH) {
            uint usdPerEth = prices[ethHash];
            require(usdPerEth > 0, "ETH price not set, cannot convert to dollars");
            return mul(usdPerEth, config.fixedPrice) / ethBaseUnit;
        }
    }

    /**
     * @notice Get the price an asset
     * @param asset The asset to get the price of
     * @return The asset price mantissa (scaled by 1e18).
     *  Zero means the price is unavailable.
     */
    function getAssetPrice(address asset) external view returns (uint) {
        return getAssetPriceInternal(asset);
    }

    /**
     * @notice Get the price update timestamp for the asset
     * @param asset The asset address for price update timestamp retrieval.
     * @return Last price update timestamp for the asset
     */
    function getAssetPriceUpdateTimestamp(address asset) external view returns (uint) {
        return getAssetPriceUpdateTimestampInternal(asset);
    }

    /**
     * @notice Get the underlying price of a cToken
     * @dev Implements the PriceOracle interface for Compound v2.
     * @param cToken The cToken address for price retrieval
     * @return Price denominated in USD, with 18 decimals, for the given cToken address
     */
    function getUnderlyingPrice(address cToken) external view returns (uint) {
        return getAssetPriceInternal(CErc20ForUniswapConfig(cToken).underlying());
    }

    /**
     * OLA_ADDITIONS : This function
     * @notice Get the price update timestamp for the cToken underlying
     * @dev Implements the PriceOracle interface for Compound v2.
     * @param cToken The cToken address for price update timestamp retrieval.
     * @return Last price update timestamp for the cToken underlying asset
     */
    function getUnderlyingPriceUpdateTimestamp(address cToken) external view returns (uint) {
        return getAssetPriceUpdateTimestampInternal(CErc20ForUniswapConfig(cToken).underlying());
    }

    /**
     * @notice Post open oracle reporter prices, and recalculate stored price by comparing to anchor
     * @dev We let anyone pay to post anything, but only prices from configured reporter will be stored in the view.
     * @param messages The messages to post to the oracle
     * @param signatures The signatures for the corresponding messages
     * @param symbols The symbols to compare to anchor for authoritative reading
     */
    function postPrices(bytes[] calldata messages, bytes[] calldata signatures, string[] calldata symbols) external {
        require(messages.length == signatures.length, "messages and signatures must be 1:1");

        // Save the prices
        for (uint i = 0; i < messages.length; i++) {
            TokenConfig memory config = getTokenConfigBySymbol(symbols[i]);
            if (config.priceSource == PriceSource.REPORTER || config.priceSource == PriceSource.SIGNED_ONLY) {
                priceData.put(messages[i], signatures[i]);
            }
        }

        // OLA_ADDITIONS : Using 'core asset price' instead of 'ethPrice
        uint referenceAssetPrice = fetchReferenceAssetPrice();

        // Try to update the view storage
        for (uint i = 0; i < symbols.length; i++) {
            postPriceInternal(symbols[i], referenceAssetPrice);
        }
    }

    /**
     * @notice Post open oracle reporter prices, and recalculate stored price by comparing to anchor
     * @dev We let anyone pay to post anything, but only prices from configured reporter will be stored in the view.
     * @param symbols The symbols to compare to anchor for authoritative reading
     */
    function freshenPrices(string[] calldata symbols) external {
        // OLA_ADDITIONS : Using 'core asset price' instead of 'ethPrice
        uint referenceAssetPrice = fetchReferenceAssetPrice();

        // Try to update the view storage
        for (uint i = 0; i < symbols.length; i++) {
            postPriceInternal(symbols[i], referenceAssetPrice);
        }
    }

    /**
     * @notice Recalculates stored prices for all by comparing to anchor
     * @dev Only prices from configured UNISWAP will be recalculated in the view.
     */
    function freshensAllPrices() external {
        string[] memory symbols = autoPokingSymbols;
        // OLA_ADDITIONS : Using 'core asset price' instead of 'ethPrice
        uint referenceAssetPrice = fetchReferenceAssetPrice();

        // Try to update the view storage
        for (uint i = 0; i < symbols.length; i++) {
            postPriceInternal(symbols[i], referenceAssetPrice);
        }
    }

    function getAssetPriceInternal(address asset) internal view returns (uint) {
        TokenConfig memory config;

        config = getTokenConfigByUnderlying(asset);

        // Comptroller needs prices in the format: ${raw price} * 1e(36 - baseUnit)
        // Since the prices in this view have 6 decimals, we must scale them by 1e(36 - 6 - baseUnit)
        return mul(1e30, priceInternal(config)) / config.baseUnit;
    }

    function getAssetPriceUpdateTimestampInternal(address asset) internal view returns (uint) {
        TokenConfig memory config;

        config = getTokenConfigByUnderlying(asset);

        return pricesLastUpdate[config.symbolHash];
    }

    // OLA_ADDITIONS : Using 'referenceAssetPrice' instead of 'ethPrice'
    function postPriceInternal(string memory symbol, uint referenceAssetPrice) internal {
        TokenConfig memory config = getTokenConfigBySymbol(symbol);
        require(config.priceSource == PriceSource.REPORTER ||
                config.priceSource == PriceSource.UNISWAP ||
                config.priceSource == PriceSource.SIGNED_ONLY ||
                config.priceSource == PriceSource.ORACLE, "only reporter, uniswap, oracle or signed-only prices get posted");

        // OLA_ADDITIONS : Updating 'last price update timestamp' together with the prices
        uint lastUpdateTimestamp = block.timestamp;
        bytes32 symbolHash = keccak256(abi.encodePacked(symbol));

        if (referenceAssetHash == symbolHash) {
            prices[referenceAssetHash] = referenceAssetPrice;
            pricesLastUpdate[referenceAssetHash] = lastUpdateTimestamp;
        }

        // OLA_ADDITIONS : Support of 'signed-only' price posting
        // Signed-Only prices do not require 'anchorPrice' (which is taken from a pair)
        if (config.priceSource == PriceSource.SIGNED_ONLY) {
            uint reporterPrice = priceData.getPrice(reporter, symbol);

            prices[symbolHash] = reporterPrice;
            // OLA_ADDITIONS : Updating price timestamp
            pricesLastUpdate[symbolHash] = lastUpdateTimestamp;

            emit PriceUpdated(symbol, reporterPrice);

            return;
        }

        if (config.priceSource == PriceSource.ORACLE) {
            uint oraclePrice = getPriceFromOracle(config);
            prices[symbolHash] = oraclePrice;
            pricesLastUpdate[symbolHash] = lastUpdateTimestamp;
            emit PriceUpdated(symbol, oraclePrice);
        }


        uint anchorPrice;
        if (symbolHash == referenceAssetHash) {
            anchorPrice = referenceAssetPrice;
        } else {
            uint256 conversionFactor = config.isDirectMarket? config.priceScale: referenceAssetPrice;

            anchorPrice = fetchAnchorPrice(symbol, config, conversionFactor);
        }


        if (config.priceSource == PriceSource.UNISWAP || reporterInvalidated) {
            prices[symbolHash] = anchorPrice;
            // OLA_ADDITIONS : Updating price timestamp
            pricesLastUpdate[symbolHash] = lastUpdateTimestamp;
            emit PriceUpdated(symbol, anchorPrice);
        } else {
            // OLA_ADDITIONS : Moves 'priceData.getPrice' inside to save gas on swap based asses
            uint reporterPrice = priceData.getPrice(reporter, symbol);
            if (isWithinAnchor(reporterPrice, anchorPrice)) {
                prices[symbolHash] = reporterPrice;
                // OLA_ADDITIONS : Updating price timestamp
                pricesLastUpdate[symbolHash] = lastUpdateTimestamp;
                emit PriceUpdated(symbol, reporterPrice);
            } else {
                emit PriceGuarded(symbol, reporterPrice, anchorPrice);
            }
        }
    }

    function isWithinAnchor(uint reporterPrice, uint anchorPrice) internal view returns (bool) {
        if (reporterPrice > 0) {
            uint anchorRatio = mul(anchorPrice, 100e16) / reporterPrice;
            return anchorRatio <= upperBoundAnchorRatio && anchorRatio >= lowerBoundAnchorRatio;
        }
        return false;
    }

    /**
     * @dev Fetches the current token/eth price accumulator from uniswap.
     */
    function currentCumulativePrice(TokenConfig memory config) internal view returns (uint) {
        (uint cumulativePrice0, uint cumulativePrice1,) = UniswapV2OracleLibrary.currentCumulativePrices(config.uniswapMarket);
        if (config.isUniswapReversed) {
            return cumulativePrice1;
        } else {
            return cumulativePrice0;
        }
    }

    /**
     * @dev Fetches the current eth/usd price from uniswap, with 6 decimals of precision.
     *  Conversion factor is 1e18 for eth/usdc market, since we decode uniswap price statically with 18 decimals.
     */
//    function fetchEthPrice() internal returns (uint) {
//        return fetchAnchorPrice("ETH", getTokenConfigBySymbolHash(ethHash), ethBaseUnit);
//    }

    function getPriceFromOracle(TokenConfig memory config) internal view returns (uint256 price) {
        price = RegistryForUAV(registry).getPriceForAsset(config.underlying);
        price = mul(price, 1e6);
        price = mul(price, config.baseUnit);
        price = price / 1e36;
    }

    /**
     * @dev Fetches the current core/usd price from uniswap, with 6 decimals of precision.
     *  Conversion factor is 1e18 for core/usdc market, since we decode uniswap price statically with 18 decimals.
     */
    function fetchReferenceAssetPrice() internal returns (uint) {
        uint256 price;
        TokenConfig memory config = getTokenConfigBySymbolHash(referenceAssetHash);

        if (PriceSource.REPORTER == config.priceSource || PriceSource.UNISWAP == config.priceSource) {
            price = fetchAnchorPrice(referenceAssetSymbol, config, ethBaseUnit);
        } else if (PriceSource.ORACLE == config.priceSource) {
            price = getPriceFromOracle(config);
        } else {
            price = priceData.getPrice(reporter, referenceAssetSymbol);
        }
        require(price != 0, "Reference asset price unavailable");
        
        return price;
    }

    /**
     * @dev Fetches the current token/usd price from uniswap, with 6 decimals of precision.
     * @param conversionFactor 1e18 if seeking the ETH price, and a 6 decimal ETH-USDC price in the case of other assets
     */
    function fetchAnchorPrice(string memory symbol, TokenConfig memory config, uint conversionFactor) internal virtual returns (uint) {
        require(config.pairType != PairType.NoPair, "must have pair type");

        if (config.pairType == PairType.UniV2Like) {
            return fetchAnchorPriceUniV2LikePair(symbol, config, conversionFactor);
        } else if (config.pairType == PairType.VelodromeLike) {
            return fetchAnchorPriceVelodromeLikePair(symbol, config, conversionFactor);
        } else {
            revert("support pair type");
        }
    }

    function fetchAnchorPriceUniV2LikePair(string memory symbol, TokenConfig memory config, uint conversionFactor) internal virtual returns (uint) {
        (uint nowCumulativePrice, uint oldCumulativePrice, uint oldTimestamp) = pokeWindowValues(config);

        // This should be impossible, but better safe than sorry
        require(block.timestamp > oldTimestamp, "now must come after before");
        uint timeElapsed = block.timestamp - oldTimestamp;

        // Calculate uniswap time-weighted average price
        // Underflow is a property of the accumulators: https://uniswap.org/audit.html#orgc9b3190
        FixedPoint.uq112x112 memory priceAverage = FixedPoint.uq112x112(uint224((nowCumulativePrice - oldCumulativePrice) / timeElapsed));
        uint rawUniswapPriceMantissa = priceAverage.decode112with18();
        uint unscaledPriceMantissa = mul(rawUniswapPriceMantissa, conversionFactor);
        uint anchorPrice;

        // Adjust rawUniswapPrice according to the units of the non-ETH asset
        // In the case of ETH, we would have to scale by 1e6 / USDC_UNITS, but since baseUnit2 is 1e6 (USDC), it cancels

        // In the case of non-ETH tokens
        // a. pokeWindowValues already handled uniswap reversed cases, so priceAverage will always be Token/ETH TWAP price.
        // b. conversionFactor Scale = 1e(18 + 6 - tokenDecimals)). We assume that tokenDecimals is 18. If not, than probably there is a mistake here.
        // unscaledPriceMantissa = priceAverage(token/ETH TWAP price) * expScale * conversionFactor
        // so ->
        // anchorPrice = priceAverage * tokenBaseUnit / ethBaseUnit * ETH_price * 1e6
        //             = priceAverage * conversionFactor * tokenBaseUnit / ethBaseUnit
        //             = unscaledPriceMantissa / expScale * tokenBaseUnit / ethBaseUnit
        anchorPrice = mul(unscaledPriceMantissa, config.baseUnit) / ethBaseUnit / expScale;

        if (keccak256(abi.encodePacked(symbol)) == referenceAssetHash) {
            anchorPrice = mul(anchorPrice, 1e6) / usdBaseUnit;
        }

        //        emit AnchorPriceUpdated(symbol, anchorPrice, oldTimestamp, block.timestamp);

        return anchorPrice;
    }


    /**
     * @dev support only velodrome like pairs with wNative as one of the tokens
     */
    function fetchAnchorPriceVelodromeLikePair(string memory symbol, TokenConfig memory config, uint nativePrice) internal virtual returns (uint) {
        require(config.pairType == PairType.VelodromeLike,"only velodrome");

        (uint224 anchorPriceRaw, uint T) = getResultForVelodromePair(config.uniswapMarket);

        uint decodedPriceInReferenceUnits = UQ112x112.decode224with18(anchorPriceRaw);

        // Asking for the price in reference asset units
//        uint priceInReferenceUnits = IVelodromeLikePairForUAV(config.uniswapMarket).current(config.underlying, config.baseUnit);
        uint anchorPrice = mul(decodedPriceInReferenceUnits, nativePrice) / ethBaseUnit;
        return anchorPrice;
    }


    /**
     * @dev Get time-weighted average prices for a token at the current timestamp.
     *  Update new and old observations of lagging window if period elapsed.
     */
    function pokeWindowValues(TokenConfig memory config) internal returns (uint, uint, uint) {
        bytes32 symbolHash = config.symbolHash;
        uint cumulativePrice = currentCumulativePrice(config);

        Observation memory newObservation = newObservations[symbolHash];

        // Update new and old observations if elapsed time is greater than or equal to anchor period
        uint timeElapsed = block.timestamp - newObservation.timestamp;
        if (timeElapsed >= anchorPeriod) {
            oldObservations[symbolHash].timestamp = newObservation.timestamp;
            oldObservations[symbolHash].acc = newObservation.acc;

            newObservations[symbolHash].timestamp = block.timestamp;
            newObservations[symbolHash].acc = cumulativePrice;
            emit UniswapWindowUpdated(config.symbolHash, newObservation.timestamp, block.timestamp, newObservation.acc, cumulativePrice);
        }
        return (cumulativePrice, oldObservations[symbolHash].acc, oldObservations[symbolHash].timestamp);
    }

    /**
     * @notice Invalidate the reporter, and fall back to using anchor directly in all cases
     * @dev Only the reporter may sign a message which allows it to invalidate itself.
     *  To be used in cases of emergency, if the reporter thinks their key may be compromised.
     * @param message The data that was presumably signed
     * @param signature The fingerprint of the data + private key
     */
    function invalidateReporter(bytes memory message, bytes memory signature) external {
        (string memory decodedMessage, ) = abi.decode(message, (string, address));
        require(keccak256(abi.encodePacked(decodedMessage)) == rotateHash, "invalid message must be 'rotate'");
        require(source(message, signature) == reporter, "invalidation message must come from the reporter");
        reporterInvalidated = true;
        emit ReporterInvalidated(reporter);
    }

    /**
     * @notice Recovers the source address which signed a message
     * @dev Comparing to a claimed address would add nothing,
     *  as the caller could simply perform the recover and claim that address.
     * @param message The data that was presumably signed
     * @param signature The fingerprint of the data + private key
     * @return The source address which signed the message, presumably
     */
    function source(bytes memory message, bytes memory signature) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = abi.decode(signature, (bytes32, bytes32, uint8));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(message)));
        return ecrecover(hash, v, r, s);
    }

    /// @dev Overflow proof multiplication
    function mul(uint a, uint b) internal pure returns (uint) {
        if (a == 0) return 0;
        uint c = a * b;
        require(c / a == b, "multiplication overflow");
        return c;
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.7.6;

import "./OpenOracleData.sol";

/**
 * @title The Open Oracle Price Data Contract
 * @notice Values stored in this contract should represent a USD price with 6 decimals precision
 * @author Compound Labs, Inc.
 */
contract OpenOraclePriceData is OpenOracleData {
    ///@notice The event emitted when a source writes to its storage
    event Write(address indexed source, string key, uint64 timestamp, uint64 value);
    ///@notice The event emitted when the timestamp on a price is invalid and it is not written to storage
    event NotWritten(uint64 priorTimestamp, uint256 messageTimestamp, uint256 blockTimestamp);

    ///@notice The fundamental unit of storage for a reporter source
    struct Datum {
        uint64 timestamp;
        uint64 value;
    }

    /**
     * @dev The most recent authenticated data from all sources.
     *  This is private because dynamic mapping keys preclude auto-generated getters.
     */
    mapping(address => mapping(string => Datum)) private data;

    /**
     * @notice Write a bunch of signed datum to the authenticated storage mapping
     * @param message The payload containing the timestamp, and (key, value) pairs
     * @param signature The cryptographic signature of the message payload, authorizing the source to write
     * @return The keys that were written
     */
    function put(bytes calldata message, bytes calldata signature) external returns (string memory) {
        (address source, uint64 timestamp, string memory key, uint64 value) = decodeMessage(message, signature);
        return putInternal(source, timestamp, key, value);
    }

    function putInternal(address source, uint64 timestamp, string memory key, uint64 value) internal returns (string memory) {
        // Only update if newer than stored, according to source
        Datum storage prior = data[source][key];
        if (timestamp > prior.timestamp && timestamp < block.timestamp + 60 minutes && source != address(0)) {
            data[source][key] = Datum(timestamp, value);
            emit Write(source, key, timestamp, value);
        } else {
            emit NotWritten(prior.timestamp, timestamp, block.timestamp);
        }
        return key;
    }

    function decodeMessage(bytes calldata message, bytes calldata signature) internal returns (address, uint64, string memory, uint64) {
        // Recover the source address
        address source = source(message, signature);

        // Decode the message and check the kind
        (string memory kind, uint64 timestamp, string memory key, uint64 value) = abi.decode(message, (string, uint64, string, uint64));
        require(keccak256(abi.encodePacked(kind)) == keccak256(abi.encodePacked("prices")), "Kind of data must be 'prices'");
        return (source, timestamp, key, value);
    }

    /**
     * @notice Read a single key from an authenticated source
     * @param source The verifiable author of the data
     * @param key The selector for the value to return
     * @return The claimed Unix timestamp for the data and the price value (defaults to (0, 0))
     */
    function get(address source, string calldata key) external view returns (uint64, uint64) {
        Datum storage datum = data[source][key];
        return (datum.timestamp, datum.value);
    }

    /**
     * @notice Read only the value for a single key from an authenticated source
     * @param source The verifiable author of the data
     * @param key The selector for the value to return
     * @return The price value (defaults to 0)
     */
    function getPrice(address source, string calldata key) external view returns (uint64) {
        return data[source][key].value;
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

interface CErc20ForUniswapConfig {
    function underlying() external view returns (address);
}

contract UniswapConfig {
    /// @dev Describe how to interpret the fixedPrice in the TokenConfig.
    enum PriceSource {
        FIXED_ETH, /// implies the fixedPrice is a constant multiple of the ETH price (which varies)
        FIXED_USD, /// implies the fixedPrice is a constant multiple of the USD price (which is 1)
        REPORTER,   /// implies the price is set by the reporter
        UNISWAP,     /// implies the price is set by uniswap
        SIGNED_ONLY, /// implies the price is set by a reporter without a matching pair
        ORACLE       /// implies the price is being fetched from an oracle
    }

    enum PairType {
        NoPair, // implies this config price calculation is not based on a pair
        UniV2Like, // implies a UniSwap V2 like pair (using 'UniswapV2OracleLibrary.currentCumulativePrices(address pair))
        VelodromeLike // implies a Velodrome like pair (using 'current(address tokenIn, uint amountIn)')
    }

    /// @dev Describe how the USD price should be determined for an asset.
    ///  There should be 1 TokenConfig object for each supported asset, passed in the constructor.
    struct TokenConfig {
        address underlying;
        bytes32 symbolHash;
        uint256 baseUnit;
        PriceSource priceSource;
        uint256 fixedPrice;
        address uniswapMarket;
        bool isUniswapReversed;
        bool isDirectMarket; // Indicated that the market is with a stable coin
        uint256 priceScale; // Should be (18 + 6 - ScaleTokenDecimals) - ScaleTokenDecimals is the decimals of the token we want the price in. (Ex. BNB in USDC, this value will be (18 + 6 - [USDC's decimals]))
        PairType pairType;
    }

    /// @notice The max number of tokens this contract is hardcoded to support
    /// @dev Do not change this variable without updating all the fields throughout the contract.
    uint public constant maxTokens = 15;

    /// @notice The number of tokens this contract actually supports
    uint public immutable numTokens;

    address internal immutable underlying00;
    address internal immutable underlying01;
    address internal immutable underlying02;
    address internal immutable underlying03;
    address internal immutable underlying04;
    address internal immutable underlying05;
    address internal immutable underlying06;
    address internal immutable underlying07;
    address internal immutable underlying08;
    address internal immutable underlying09;
    address internal immutable underlying10;
    address internal immutable underlying11;
    address internal immutable underlying12;
    address internal immutable underlying13;
    address internal immutable underlying14;
    // address internal immutable underlying15;
    // address internal immutable underlying16;
    // address internal immutable underlying17;
    // address internal immutable underlying18;
    // address internal immutable underlying19;
    // address internal immutable underlying20;
    // address internal immutable underlying21;
    // address internal immutable underlying22;
    // address internal immutable underlying23;
    // address internal immutable underlying24;
    // address internal immutable underlying25;
    // address internal immutable underlying26;
    // address internal immutable underlying27;
    // address internal immutable underlying28;
    // address internal immutable underlying29;

    bytes32 internal immutable symbolHash00;
    bytes32 internal immutable symbolHash01;
    bytes32 internal immutable symbolHash02;
    bytes32 internal immutable symbolHash03;
    bytes32 internal immutable symbolHash04;
    bytes32 internal immutable symbolHash05;
    bytes32 internal immutable symbolHash06;
    bytes32 internal immutable symbolHash07;
    bytes32 internal immutable symbolHash08;
    bytes32 internal immutable symbolHash09;
    bytes32 internal immutable symbolHash10;
    bytes32 internal immutable symbolHash11;
    bytes32 internal immutable symbolHash12;
    bytes32 internal immutable symbolHash13;
    bytes32 internal immutable symbolHash14;
    // bytes32 internal immutable symbolHash15;
    // bytes32 internal immutable symbolHash16;
    // bytes32 internal immutable symbolHash17;
    // bytes32 internal immutable symbolHash18;
    // bytes32 internal immutable symbolHash19;
    // bytes32 internal immutable symbolHash20;
    // bytes32 internal immutable symbolHash21;
    // bytes32 internal immutable symbolHash22;
    // bytes32 internal immutable symbolHash23;
    // bytes32 internal immutable symbolHash24;
    // bytes32 internal immutable symbolHash25;
    // bytes32 internal immutable symbolHash26;
    // bytes32 internal immutable symbolHash27;
    // bytes32 internal immutable symbolHash28;
    // bytes32 internal immutable symbolHash29;

    uint256 internal immutable baseUnit00;
    uint256 internal immutable baseUnit01;
    uint256 internal immutable baseUnit02;
    uint256 internal immutable baseUnit03;
    uint256 internal immutable baseUnit04;
    uint256 internal immutable baseUnit05;
    uint256 internal immutable baseUnit06;
    uint256 internal immutable baseUnit07;
    uint256 internal immutable baseUnit08;
    uint256 internal immutable baseUnit09;
    uint256 internal immutable baseUnit10;
    uint256 internal immutable baseUnit11;
    uint256 internal immutable baseUnit12;
    uint256 internal immutable baseUnit13;
    uint256 internal immutable baseUnit14;
    // uint256 internal immutable baseUnit15;
    // uint256 internal immutable baseUnit16;
    // uint256 internal immutable baseUnit17;
    // uint256 internal immutable baseUnit18;
    // uint256 internal immutable baseUnit19;
    // uint256 internal immutable baseUnit20;
    // uint256 internal immutable baseUnit21;
    // uint256 internal immutable baseUnit22;
    // uint256 internal immutable baseUnit23;
    // uint256 internal immutable baseUnit24;
    // uint256 internal immutable baseUnit25;
    // uint256 internal immutable baseUnit26;
    // uint256 internal immutable baseUnit27;
    // uint256 internal immutable baseUnit28;
    // uint256 internal immutable baseUnit29;

    PriceSource internal immutable priceSource00;
    PriceSource internal immutable priceSource01;
    PriceSource internal immutable priceSource02;
    PriceSource internal immutable priceSource03;
    PriceSource internal immutable priceSource04;
    PriceSource internal immutable priceSource05;
    PriceSource internal immutable priceSource06;
    PriceSource internal immutable priceSource07;
    PriceSource internal immutable priceSource08;
    PriceSource internal immutable priceSource09;
    PriceSource internal immutable priceSource10;
    PriceSource internal immutable priceSource11;
    PriceSource internal immutable priceSource12;
    PriceSource internal immutable priceSource13;
    PriceSource internal immutable priceSource14;
    // PriceSource internal immutable priceSource15;
    // PriceSource internal immutable priceSource16;
    // PriceSource internal immutable priceSource17;
    // PriceSource internal immutable priceSource18;
    // PriceSource internal immutable priceSource19;
    // PriceSource internal immutable priceSource20;
    // PriceSource internal immutable priceSource21;
    // PriceSource internal immutable priceSource22;
    // PriceSource internal immutable priceSource23;
    // PriceSource internal immutable priceSource24;
    // PriceSource internal immutable priceSource25;
    // PriceSource internal immutable priceSource26;
    // PriceSource internal immutable priceSource27;
    // PriceSource internal immutable priceSource28;
    // PriceSource internal immutable priceSource29;

    uint256 internal immutable fixedPrice00;
    uint256 internal immutable fixedPrice01;
    uint256 internal immutable fixedPrice02;
    uint256 internal immutable fixedPrice03;
    uint256 internal immutable fixedPrice04;
    uint256 internal immutable fixedPrice05;
    uint256 internal immutable fixedPrice06;
    uint256 internal immutable fixedPrice07;
    uint256 internal immutable fixedPrice08;
    uint256 internal immutable fixedPrice09;
    uint256 internal immutable fixedPrice10;
    uint256 internal immutable fixedPrice11;
    uint256 internal immutable fixedPrice12;
    uint256 internal immutable fixedPrice13;
    uint256 internal immutable fixedPrice14;
    // uint256 internal immutable fixedPrice15;
    // uint256 internal immutable fixedPrice16;
    // uint256 internal immutable fixedPrice17;
    // uint256 internal immutable fixedPrice18;
    // uint256 internal immutable fixedPrice19;
    // uint256 internal immutable fixedPrice20;
    // uint256 internal immutable fixedPrice21;
    // uint256 internal immutable fixedPrice22;
    // uint256 internal immutable fixedPrice23;
    // uint256 internal immutable fixedPrice24;
    // uint256 internal immutable fixedPrice25;
    // uint256 internal immutable fixedPrice26;
    // uint256 internal immutable fixedPrice27;
    // uint256 internal immutable fixedPrice28;
    // uint256 internal immutable fixedPrice29;

    address internal immutable uniswapMarket00;
    address internal immutable uniswapMarket01;
    address internal immutable uniswapMarket02;
    address internal immutable uniswapMarket03;
    address internal immutable uniswapMarket04;
    address internal immutable uniswapMarket05;
    address internal immutable uniswapMarket06;
    address internal immutable uniswapMarket07;
    address internal immutable uniswapMarket08;
    address internal immutable uniswapMarket09;
    address internal immutable uniswapMarket10;
    address internal immutable uniswapMarket11;
    address internal immutable uniswapMarket12;
    address internal immutable uniswapMarket13;
    address internal immutable uniswapMarket14;
    // address internal immutable uniswapMarket15;
    // address internal immutable uniswapMarket16;
    // address internal immutable uniswapMarket17;
    // address internal immutable uniswapMarket18;
    // address internal immutable uniswapMarket19;
    // address internal immutable uniswapMarket20;
    // address internal immutable uniswapMarket21;
    // address internal immutable uniswapMarket22;
    // address internal immutable uniswapMarket23;
    // address internal immutable uniswapMarket24;
    // address internal immutable uniswapMarket25;
    // address internal immutable uniswapMarket26;
    // address internal immutable uniswapMarket27;
    // address internal immutable uniswapMarket28;
    // address internal immutable uniswapMarket29;

    bool internal immutable isUniswapReversed00;
    bool internal immutable isUniswapReversed01;
    bool internal immutable isUniswapReversed02;
    bool internal immutable isUniswapReversed03;
    bool internal immutable isUniswapReversed04;
    bool internal immutable isUniswapReversed05;
    bool internal immutable isUniswapReversed06;
    bool internal immutable isUniswapReversed07;
    bool internal immutable isUniswapReversed08;
    bool internal immutable isUniswapReversed09;
    bool internal immutable isUniswapReversed10;
    bool internal immutable isUniswapReversed11;
    bool internal immutable isUniswapReversed12;
    bool internal immutable isUniswapReversed13;
    bool internal immutable isUniswapReversed14;
    // bool internal immutable isUniswapReversed15;
    // bool internal immutable isUniswapReversed16;
    // bool internal immutable isUniswapReversed17;
    // bool internal immutable isUniswapReversed18;
    // bool internal immutable isUniswapReversed19;
    // bool internal immutable isUniswapReversed20;
    // bool internal immutable isUniswapReversed21;
    // bool internal immutable isUniswapReversed22;
    // bool internal immutable isUniswapReversed23;
    // bool internal immutable isUniswapReversed24;
    // bool internal immutable isUniswapReversed25;
    // bool internal immutable isUniswapReversed26;
    // bool internal immutable isUniswapReversed27;
    // bool internal immutable isUniswapReversed28;
    // bool internal immutable isUniswapReversed29;

    bool[30] internal isDirectMarkets;

    bool internal immutable isDirectMarket00;
    bool internal immutable isDirectMarket01;
    bool internal immutable isDirectMarket02;
    bool internal immutable isDirectMarket03;
    bool internal immutable isDirectMarket04;
    bool internal immutable isDirectMarket05;
    bool internal immutable isDirectMarket06;
    bool internal immutable isDirectMarket07;
    bool internal immutable isDirectMarket08;
    bool internal immutable isDirectMarket09;
    bool internal immutable isDirectMarket10;
    bool internal immutable isDirectMarket11;
    bool internal immutable isDirectMarket12;
    bool internal immutable isDirectMarket13;
    bool internal immutable isDirectMarket14;
    // bool internal immutable isDirectMarket15;
    // bool internal immutable isDirectMarket16;
    // bool internal immutable isDirectMarket17;
    // bool internal immutable isDirectMarket18;
    // bool internal immutable isDirectMarket19;
    // bool internal immutable isDirectMarket20;
    // bool internal immutable isDirectMarket21;
    // bool internal immutable isDirectMarket22;
    // bool internal immutable isDirectMarket23;
    // bool internal immutable isDirectMarket24;
    // bool internal immutable isDirectMarket25;
    // bool internal immutable isDirectMarket26;
    // bool internal immutable isDirectMarket27;
    // bool internal immutable isDirectMarket28;
    // bool internal immutable isDirectMarket29;

    uint256 internal immutable priceScale00;
    uint256 internal immutable priceScale01;
    uint256 internal immutable priceScale02;
    uint256 internal immutable priceScale03;
    uint256 internal immutable priceScale04;
    uint256 internal immutable priceScale05;
    uint256 internal immutable priceScale06;
    uint256 internal immutable priceScale07;
    uint256 internal immutable priceScale08;
    uint256 internal immutable priceScale09;
    uint256 internal immutable priceScale10;
    uint256 internal immutable priceScale11;
    uint256 internal immutable priceScale12;
    uint256 internal immutable priceScale13;
    uint256 internal immutable priceScale14;

    PairType internal immutable pairType00;
    PairType internal immutable pairType01;
    PairType internal immutable pairType02;
    PairType internal immutable pairType03;
    PairType internal immutable pairType04;
    PairType internal immutable pairType05;
    PairType internal immutable pairType06;
    PairType internal immutable pairType07;
    PairType internal immutable pairType08;
    PairType internal immutable pairType09;
    PairType internal immutable pairType10;
    PairType internal immutable pairType11;
    PairType internal immutable pairType12;
    PairType internal immutable pairType13;
    PairType internal immutable pairType14;

    /**
     * @notice Construct an immutable store of configs into the contract data
     * @param configs The configs for the supported assets
     */
    constructor(TokenConfig[] memory configs) public {
        require(configs.length <= maxTokens, "too many configs");
        numTokens = configs.length;

        underlying00 = get(configs, 0).underlying;
        underlying01 = get(configs, 1).underlying;
        underlying02 = get(configs, 2).underlying;
        underlying03 = get(configs, 3).underlying;
        underlying04 = get(configs, 4).underlying;
        underlying05 = get(configs, 5).underlying;
        underlying06 = get(configs, 6).underlying;
        underlying07 = get(configs, 7).underlying;
        underlying08 = get(configs, 8).underlying;
        underlying09 = get(configs, 9).underlying;
        underlying10 = get(configs, 10).underlying;
        underlying11 = get(configs, 11).underlying;
        underlying12 = get(configs, 12).underlying;
        underlying13 = get(configs, 13).underlying;
        underlying14 = get(configs, 14).underlying;
        // underlying15 = get(configs, 15).underlying;
        // underlying16 = get(configs, 16).underlying;
        // underlying17 = get(configs, 17).underlying;
        // underlying18 = get(configs, 18).underlying;
        // underlying19 = get(configs, 19).underlying;
        // underlying20 = get(configs, 20).underlying;
        // underlying21 = get(configs, 21).underlying;
        // underlying22 = get(configs, 22).underlying;
        // underlying23 = get(configs, 23).underlying;
        // underlying24 = get(configs, 24).underlying;
        // underlying25 = get(configs, 25).underlying;
        // underlying26 = get(configs, 26).underlying;
        // underlying27 = get(configs, 27).underlying;
        // underlying28 = get(configs, 28).underlying;
        // underlying29 = get(configs, 29).underlying;

        symbolHash00 = get(configs, 0).symbolHash;
        symbolHash01 = get(configs, 1).symbolHash;
        symbolHash02 = get(configs, 2).symbolHash;
        symbolHash03 = get(configs, 3).symbolHash;
        symbolHash04 = get(configs, 4).symbolHash;
        symbolHash05 = get(configs, 5).symbolHash;
        symbolHash06 = get(configs, 6).symbolHash;
        symbolHash07 = get(configs, 7).symbolHash;
        symbolHash08 = get(configs, 8).symbolHash;
        symbolHash09 = get(configs, 9).symbolHash;
        symbolHash10 = get(configs, 10).symbolHash;
        symbolHash11 = get(configs, 11).symbolHash;
        symbolHash12 = get(configs, 12).symbolHash;
        symbolHash13 = get(configs, 13).symbolHash;
        symbolHash14 = get(configs, 14).symbolHash;
        // symbolHash15 = get(configs, 15).symbolHash;
        // symbolHash16 = get(configs, 16).symbolHash;
        // symbolHash17 = get(configs, 17).symbolHash;
        // symbolHash18 = get(configs, 18).symbolHash;
        // symbolHash19 = get(configs, 19).symbolHash;
        // symbolHash20 = get(configs, 20).symbolHash;
        // symbolHash21 = get(configs, 21).symbolHash;
        // symbolHash22 = get(configs, 22).symbolHash;
        // symbolHash23 = get(configs, 23).symbolHash;
        // symbolHash24 = get(configs, 24).symbolHash;
        // symbolHash25 = get(configs, 25).symbolHash;
        // symbolHash26 = get(configs, 26).symbolHash;
        // symbolHash27 = get(configs, 27).symbolHash;
        // symbolHash28 = get(configs, 28).symbolHash;
        // symbolHash29 = get(configs, 29).symbolHash;

        baseUnit00 = get(configs, 0).baseUnit;
        baseUnit01 = get(configs, 1).baseUnit;
        baseUnit02 = get(configs, 2).baseUnit;
        baseUnit03 = get(configs, 3).baseUnit;
        baseUnit04 = get(configs, 4).baseUnit;
        baseUnit05 = get(configs, 5).baseUnit;
        baseUnit06 = get(configs, 6).baseUnit;
        baseUnit07 = get(configs, 7).baseUnit;
        baseUnit08 = get(configs, 8).baseUnit;
        baseUnit09 = get(configs, 9).baseUnit;
        baseUnit10 = get(configs, 10).baseUnit;
        baseUnit11 = get(configs, 11).baseUnit;
        baseUnit12 = get(configs, 12).baseUnit;
        baseUnit13 = get(configs, 13).baseUnit;
        baseUnit14 = get(configs, 14).baseUnit;
        // baseUnit15 = get(configs, 15).baseUnit;
        // baseUnit16 = get(configs, 16).baseUnit;
        // baseUnit17 = get(configs, 17).baseUnit;
        // baseUnit18 = get(configs, 18).baseUnit;
        // baseUnit19 = get(configs, 19).baseUnit;
        // baseUnit20 = get(configs, 20).baseUnit;
        // baseUnit21 = get(configs, 21).baseUnit;
        // baseUnit22 = get(configs, 22).baseUnit;
        // baseUnit23 = get(configs, 23).baseUnit;
        // baseUnit24 = get(configs, 24).baseUnit;
        // baseUnit25 = get(configs, 25).baseUnit;
        // baseUnit26 = get(configs, 26).baseUnit;
        // baseUnit27 = get(configs, 27).baseUnit;
        // baseUnit28 = get(configs, 28).baseUnit;
        // baseUnit29 = get(configs, 29).baseUnit;

        priceSource00 = get(configs, 0).priceSource;
        priceSource01 = get(configs, 1).priceSource;
        priceSource02 = get(configs, 2).priceSource;
        priceSource03 = get(configs, 3).priceSource;
        priceSource04 = get(configs, 4).priceSource;
        priceSource05 = get(configs, 5).priceSource;
        priceSource06 = get(configs, 6).priceSource;
        priceSource07 = get(configs, 7).priceSource;
        priceSource08 = get(configs, 8).priceSource;
        priceSource09 = get(configs, 9).priceSource;
        priceSource10 = get(configs, 10).priceSource;
        priceSource11 = get(configs, 11).priceSource;
        priceSource12 = get(configs, 12).priceSource;
        priceSource13 = get(configs, 13).priceSource;
        priceSource14 = get(configs, 14).priceSource;
        // priceSource15 = get(configs, 15).priceSource;
        // priceSource16 = get(configs, 16).priceSource;
        // priceSource17 = get(configs, 17).priceSource;
        // priceSource18 = get(configs, 18).priceSource;
        // priceSource19 = get(configs, 19).priceSource;
        // priceSource20 = get(configs, 20).priceSource;
        // priceSource21 = get(configs, 21).priceSource;
        // priceSource22 = get(configs, 22).priceSource;
        // priceSource23 = get(configs, 23).priceSource;
        // priceSource24 = get(configs, 24).priceSource;
        // priceSource25 = get(configs, 25).priceSource;
        // priceSource26 = get(configs, 26).priceSource;
        // priceSource27 = get(configs, 27).priceSource;
        // priceSource28 = get(configs, 28).priceSource;
        // priceSource29 = get(configs, 29).priceSource;

        fixedPrice00 = get(configs, 0).fixedPrice;
        fixedPrice01 = get(configs, 1).fixedPrice;
        fixedPrice02 = get(configs, 2).fixedPrice;
        fixedPrice03 = get(configs, 3).fixedPrice;
        fixedPrice04 = get(configs, 4).fixedPrice;
        fixedPrice05 = get(configs, 5).fixedPrice;
        fixedPrice06 = get(configs, 6).fixedPrice;
        fixedPrice07 = get(configs, 7).fixedPrice;
        fixedPrice08 = get(configs, 8).fixedPrice;
        fixedPrice09 = get(configs, 9).fixedPrice;
        fixedPrice10 = get(configs, 10).fixedPrice;
        fixedPrice11 = get(configs, 11).fixedPrice;
        fixedPrice12 = get(configs, 12).fixedPrice;
        fixedPrice13 = get(configs, 13).fixedPrice;
        fixedPrice14 = get(configs, 14).fixedPrice;
        // fixedPrice15 = get(configs, 15).fixedPrice;
        // fixedPrice16 = get(configs, 16).fixedPrice;
        // fixedPrice17 = get(configs, 17).fixedPrice;
        // fixedPrice18 = get(configs, 18).fixedPrice;
        // fixedPrice19 = get(configs, 19).fixedPrice;
        // fixedPrice20 = get(configs, 20).fixedPrice;
        // fixedPrice21 = get(configs, 21).fixedPrice;
        // fixedPrice22 = get(configs, 22).fixedPrice;
        // fixedPrice23 = get(configs, 23).fixedPrice;
        // fixedPrice24 = get(configs, 24).fixedPrice;
        // fixedPrice25 = get(configs, 25).fixedPrice;
        // fixedPrice26 = get(configs, 26).fixedPrice;
        // fixedPrice27 = get(configs, 27).fixedPrice;
        // fixedPrice28 = get(configs, 28).fixedPrice;
        // fixedPrice29 = get(configs, 29).fixedPrice;

        uniswapMarket00 = get(configs, 0).uniswapMarket;
        uniswapMarket01 = get(configs, 1).uniswapMarket;
        uniswapMarket02 = get(configs, 2).uniswapMarket;
        uniswapMarket03 = get(configs, 3).uniswapMarket;
        uniswapMarket04 = get(configs, 4).uniswapMarket;
        uniswapMarket05 = get(configs, 5).uniswapMarket;
        uniswapMarket06 = get(configs, 6).uniswapMarket;
        uniswapMarket07 = get(configs, 7).uniswapMarket;
        uniswapMarket08 = get(configs, 8).uniswapMarket;
        uniswapMarket09 = get(configs, 9).uniswapMarket;
        uniswapMarket10 = get(configs, 10).uniswapMarket;
        uniswapMarket11 = get(configs, 11).uniswapMarket;
        uniswapMarket12 = get(configs, 12).uniswapMarket;
        uniswapMarket13 = get(configs, 13).uniswapMarket;
        uniswapMarket14 = get(configs, 14).uniswapMarket;
        // uniswapMarket15 = get(configs, 15).uniswapMarket;
        // uniswapMarket16 = get(configs, 16).uniswapMarket;
        // uniswapMarket17 = get(configs, 17).uniswapMarket;
        // uniswapMarket18 = get(configs, 18).uniswapMarket;
        // uniswapMarket19 = get(configs, 19).uniswapMarket;
        // uniswapMarket20 = get(configs, 20).uniswapMarket;
        // uniswapMarket21 = get(configs, 21).uniswapMarket;
        // uniswapMarket22 = get(configs, 22).uniswapMarket;
        // uniswapMarket23 = get(configs, 23).uniswapMarket;
        // uniswapMarket24 = get(configs, 24).uniswapMarket;
        // uniswapMarket25 = get(configs, 25).uniswapMarket;
        // uniswapMarket26 = get(configs, 26).uniswapMarket;
        // uniswapMarket27 = get(configs, 27).uniswapMarket;
        // uniswapMarket28 = get(configs, 28).uniswapMarket;
        // uniswapMarket29 = get(configs, 29).uniswapMarket;

        isUniswapReversed00 = get(configs, 0).isUniswapReversed;
        isUniswapReversed01 = get(configs, 1).isUniswapReversed;
        isUniswapReversed02 = get(configs, 2).isUniswapReversed;
        isUniswapReversed03 = get(configs, 3).isUniswapReversed;
        isUniswapReversed04 = get(configs, 4).isUniswapReversed;
        isUniswapReversed05 = get(configs, 5).isUniswapReversed;
        isUniswapReversed06 = get(configs, 6).isUniswapReversed;
        isUniswapReversed07 = get(configs, 7).isUniswapReversed;
        isUniswapReversed08 = get(configs, 8).isUniswapReversed;
        isUniswapReversed09 = get(configs, 9).isUniswapReversed;
        isUniswapReversed10 = get(configs, 10).isUniswapReversed;
        isUniswapReversed11 = get(configs, 11).isUniswapReversed;
        isUniswapReversed12 = get(configs, 12).isUniswapReversed;
        isUniswapReversed13 = get(configs, 13).isUniswapReversed;
        isUniswapReversed14 = get(configs, 14).isUniswapReversed;
        // isUniswapReversed15 = get(configs, 15).isUniswapReversed;
        // isUniswapReversed16 = get(configs, 16).isUniswapReversed;
        // isUniswapReversed17 = get(configs, 17).isUniswapReversed;
        // isUniswapReversed18 = get(configs, 18).isUniswapReversed;
        // isUniswapReversed19 = get(configs, 19).isUniswapReversed;
        // isUniswapReversed20 = get(configs, 20).isUniswapReversed;
        // isUniswapReversed21 = get(configs, 21).isUniswapReversed;
        // isUniswapReversed22 = get(configs, 22).isUniswapReversed;
        // isUniswapReversed23 = get(configs, 23).isUniswapReversed;
        // isUniswapReversed24 = get(configs, 24).isUniswapReversed;
        // isUniswapReversed25 = get(configs, 25).isUniswapReversed;
        // isUniswapReversed26 = get(configs, 26).isUniswapReversed;
        // isUniswapReversed27 = get(configs, 27).isUniswapReversed;
        // isUniswapReversed28 = get(configs, 28).isUniswapReversed;
        // isUniswapReversed29 = get(configs, 29).isUniswapReversed;

        isDirectMarket00 = get(configs, 0).isDirectMarket;
        isDirectMarket01 = get(configs, 1).isDirectMarket;
        isDirectMarket02 = get(configs, 2).isDirectMarket;
        isDirectMarket03 = get(configs, 3).isDirectMarket;
        isDirectMarket04 = get(configs, 4).isDirectMarket;
        isDirectMarket05 = get(configs, 5).isDirectMarket;
        isDirectMarket06 = get(configs, 6).isDirectMarket;
        isDirectMarket07 = get(configs, 7).isDirectMarket;
        isDirectMarket08 = get(configs, 8).isDirectMarket;
        isDirectMarket09 = get(configs, 9).isDirectMarket;
        isDirectMarket10 = get(configs, 10).isDirectMarket;
        isDirectMarket11 = get(configs, 11).isDirectMarket;
        isDirectMarket12 = get(configs, 12).isDirectMarket;
        isDirectMarket13 = get(configs, 13).isDirectMarket;
        isDirectMarket14 = get(configs, 14).isDirectMarket;
        // isDirectMarket15 = get(configs, 15).isDirectMarket;
        // isDirectMarket16 = get(configs, 16).isDirectMarket;
        // isDirectMarket17 = get(configs, 17).isDirectMarket;
        // isDirectMarket18 = get(configs, 18).isDirectMarket;
        // isDirectMarket19 = get(configs, 19).isDirectMarket;
        // isDirectMarket20 = get(configs, 20).isDirectMarket;
        // isDirectMarket21 = get(configs, 21).isDirectMarket;
        // isDirectMarket22 = get(configs, 22).isDirectMarket;
        // isDirectMarket23 = get(configs, 23).isDirectMarket;
        // isDirectMarket24 = get(configs, 24).isDirectMarket;
        // isDirectMarket25 = get(configs, 25).isDirectMarket;
        // isDirectMarket26 = get(configs, 26).isDirectMarket;
        // isDirectMarket27 = get(configs, 27).isDirectMarket;
        // isDirectMarket28 = get(configs, 28).isDirectMarket;
        // isDirectMarket29 = get(configs, 29).isDirectMarket;

        priceScale00 = get(configs, 0).priceScale;
        priceScale01 = get(configs, 1).priceScale;
        priceScale02 = get(configs, 2).priceScale;
        priceScale03 = get(configs, 3).priceScale;
        priceScale04 = get(configs, 4).priceScale;
        priceScale05 = get(configs, 5).priceScale;
        priceScale06 = get(configs, 6).priceScale;
        priceScale07 = get(configs, 7).priceScale;
        priceScale08 = get(configs, 8).priceScale;
        priceScale09 = get(configs, 9).priceScale;
        priceScale10 = get(configs, 10).priceScale;
        priceScale11 = get(configs, 11).priceScale;
        priceScale12 = get(configs, 12).priceScale;
        priceScale13 = get(configs, 13).priceScale;
        priceScale14 = get(configs, 14).priceScale;

        pairType00 = get(configs, 0).pairType;
        pairType01 = get(configs, 1).pairType;
        pairType02 = get(configs, 2).pairType;
        pairType03 = get(configs, 3).pairType;
        pairType04 = get(configs, 4).pairType;
        pairType05 = get(configs, 5).pairType;
        pairType06 = get(configs, 6).pairType;
        pairType07 = get(configs, 7).pairType;
        pairType08 = get(configs, 8).pairType;
        pairType09 = get(configs, 9).pairType;
        pairType10 = get(configs, 10).pairType;
        pairType11 = get(configs, 11).pairType;
        pairType12 = get(configs, 12).pairType;
        pairType13 = get(configs, 13).pairType;
        pairType14 = get(configs, 14).pairType;
    }

    function get(TokenConfig[] memory configs, uint i) internal pure returns (TokenConfig memory) {
        if (i < configs.length)
            return configs[i];
        return TokenConfig({
            underlying: address(0),
            symbolHash: bytes32(0),
            baseUnit: uint256(0),
            priceSource: PriceSource(0),
            fixedPrice: uint256(0),
            uniswapMarket: address(0),
            isUniswapReversed: false,
            isDirectMarket: false,
            priceScale: uint256(0),
            pairType: PairType.NoPair
        });
    }

    function getUnderlyingIndex(address underlying) internal view returns (uint) {
        if (underlying == underlying00) return 0;
        if (underlying == underlying01) return 1;
        if (underlying == underlying02) return 2;
        if (underlying == underlying03) return 3;
        if (underlying == underlying04) return 4;
        if (underlying == underlying05) return 5;
        if (underlying == underlying06) return 6;
        if (underlying == underlying07) return 7;
        if (underlying == underlying08) return 8;
        if (underlying == underlying09) return 9;
        if (underlying == underlying10) return 10;
        if (underlying == underlying11) return 11;
        if (underlying == underlying12) return 12;
        if (underlying == underlying13) return 13;
        if (underlying == underlying14) return 14;
        // if (underlying == underlying15) return 15;
        // if (underlying == underlying16) return 16;
        // if (underlying == underlying17) return 17;
        // if (underlying == underlying18) return 18;
        // if (underlying == underlying19) return 19;
        // if (underlying == underlying20) return 20;
        // if (underlying == underlying21) return 21;
        // if (underlying == underlying22) return 22;
        // if (underlying == underlying23) return 23;
        // if (underlying == underlying24) return 24;
        // if (underlying == underlying25) return 25;
        // if (underlying == underlying26) return 26;
        // if (underlying == underlying27) return 27;
        // if (underlying == underlying28) return 28;
        // if (underlying == underlying29) return 29;

        return uint(-1);
    }

    function getSymbolHashIndex(bytes32 symbolHash) internal view returns (uint) {
        if (symbolHash == symbolHash00) return 0;
        if (symbolHash == symbolHash01) return 1;
        if (symbolHash == symbolHash02) return 2;
        if (symbolHash == symbolHash03) return 3;
        if (symbolHash == symbolHash04) return 4;
        if (symbolHash == symbolHash05) return 5;
        if (symbolHash == symbolHash06) return 6;
        if (symbolHash == symbolHash07) return 7;
        if (symbolHash == symbolHash08) return 8;
        if (symbolHash == symbolHash09) return 9;
        if (symbolHash == symbolHash10) return 10;
        if (symbolHash == symbolHash11) return 11;
        if (symbolHash == symbolHash12) return 12;
        if (symbolHash == symbolHash13) return 13;
        if (symbolHash == symbolHash14) return 14;
        // if (symbolHash == symbolHash15) return 15;
        // if (symbolHash == symbolHash16) return 16;
        // if (symbolHash == symbolHash17) return 17;
        // if (symbolHash == symbolHash18) return 18;
        // if (symbolHash == symbolHash19) return 19;
        // if (symbolHash == symbolHash20) return 20;
        // if (symbolHash == symbolHash21) return 21;
        // if (symbolHash == symbolHash22) return 22;
        // if (symbolHash == symbolHash23) return 23;
        // if (symbolHash == symbolHash24) return 24;
        // if (symbolHash == symbolHash25) return 25;
        // if (symbolHash == symbolHash26) return 26;
        // if (symbolHash == symbolHash27) return 27;
        // if (symbolHash == symbolHash28) return 28;
        // if (symbolHash == symbolHash29) return 29;

        return uint(-1);
    }

    /**
     * @notice Get the i-th config, according to the order they were passed in originally
     * @param i The index of the config to get
     * @return The config object
     */
    function getTokenConfig(uint i) public view returns (TokenConfig memory) {
        require(i < numTokens, "token config not found");

        if (i == 1) return TokenConfig({underlying: underlying01, symbolHash: symbolHash01, baseUnit: baseUnit01, priceSource: priceSource01, fixedPrice: fixedPrice01, uniswapMarket: uniswapMarket01, isUniswapReversed: isUniswapReversed01, isDirectMarket: isDirectMarket01, priceScale: priceScale01, pairType: pairType01});
        if (i == 0) return TokenConfig({underlying: underlying00, symbolHash: symbolHash00, baseUnit: baseUnit00, priceSource: priceSource00, fixedPrice: fixedPrice00, uniswapMarket: uniswapMarket00, isUniswapReversed: isUniswapReversed00, isDirectMarket: isDirectMarket00, priceScale: priceScale00, pairType: pairType00});
        if (i == 2) return TokenConfig({underlying: underlying02, symbolHash: symbolHash02, baseUnit: baseUnit02, priceSource: priceSource02, fixedPrice: fixedPrice02, uniswapMarket: uniswapMarket02, isUniswapReversed: isUniswapReversed02, isDirectMarket: isDirectMarket02, priceScale: priceScale02, pairType: pairType02});
        if (i == 3) return TokenConfig({underlying: underlying03, symbolHash: symbolHash03, baseUnit: baseUnit03, priceSource: priceSource03, fixedPrice: fixedPrice03, uniswapMarket: uniswapMarket03, isUniswapReversed: isUniswapReversed03, isDirectMarket: isDirectMarket03, priceScale: priceScale03, pairType: pairType03});
        if (i == 4) return TokenConfig({underlying: underlying04, symbolHash: symbolHash04, baseUnit: baseUnit04, priceSource: priceSource04, fixedPrice: fixedPrice04, uniswapMarket: uniswapMarket04, isUniswapReversed: isUniswapReversed04, isDirectMarket: isDirectMarket04, priceScale: priceScale04, pairType: pairType04});
        if (i == 5) return TokenConfig({underlying: underlying05, symbolHash: symbolHash05, baseUnit: baseUnit05, priceSource: priceSource05, fixedPrice: fixedPrice05, uniswapMarket: uniswapMarket05, isUniswapReversed: isUniswapReversed05, isDirectMarket: isDirectMarket05, priceScale: priceScale05, pairType: pairType05});
        if (i == 6) return TokenConfig({underlying: underlying06, symbolHash: symbolHash06, baseUnit: baseUnit06, priceSource: priceSource06, fixedPrice: fixedPrice06, uniswapMarket: uniswapMarket06, isUniswapReversed: isUniswapReversed06, isDirectMarket: isDirectMarket06, priceScale: priceScale06, pairType: pairType06});
        if (i == 7) return TokenConfig({underlying: underlying07, symbolHash: symbolHash07, baseUnit: baseUnit07, priceSource: priceSource07, fixedPrice: fixedPrice07, uniswapMarket: uniswapMarket07, isUniswapReversed: isUniswapReversed07, isDirectMarket: isDirectMarket07, priceScale: priceScale07, pairType: pairType07});
        if (i == 8) return TokenConfig({underlying: underlying08, symbolHash: symbolHash08, baseUnit: baseUnit08, priceSource: priceSource08, fixedPrice: fixedPrice08, uniswapMarket: uniswapMarket08, isUniswapReversed: isUniswapReversed08, isDirectMarket: isDirectMarket08, priceScale: priceScale08, pairType: pairType08});
        if (i == 9) return TokenConfig({underlying: underlying09, symbolHash: symbolHash09, baseUnit: baseUnit09, priceSource: priceSource09, fixedPrice: fixedPrice09, uniswapMarket: uniswapMarket09, isUniswapReversed: isUniswapReversed09, isDirectMarket: isDirectMarket09, priceScale: priceScale09, pairType: pairType09});
        if (i == 10) return TokenConfig({underlying: underlying10, symbolHash: symbolHash10, baseUnit: baseUnit10, priceSource: priceSource10, fixedPrice: fixedPrice10, uniswapMarket: uniswapMarket10, isUniswapReversed: isUniswapReversed10, isDirectMarket: isDirectMarket10, priceScale: priceScale10, pairType: pairType10});
        if (i == 11) return TokenConfig({underlying: underlying11, symbolHash: symbolHash11, baseUnit: baseUnit11, priceSource: priceSource11, fixedPrice: fixedPrice11, uniswapMarket: uniswapMarket11, isUniswapReversed: isUniswapReversed11, isDirectMarket: isDirectMarket11, priceScale: priceScale11, pairType: pairType11});
        if (i == 12) return TokenConfig({underlying: underlying12, symbolHash: symbolHash12, baseUnit: baseUnit12, priceSource: priceSource12, fixedPrice: fixedPrice12, uniswapMarket: uniswapMarket12, isUniswapReversed: isUniswapReversed12, isDirectMarket: isDirectMarket12, priceScale: priceScale12, pairType: pairType12});
        if (i == 13) return TokenConfig({underlying: underlying13, symbolHash: symbolHash13, baseUnit: baseUnit13, priceSource: priceSource13, fixedPrice: fixedPrice13, uniswapMarket: uniswapMarket13, isUniswapReversed: isUniswapReversed13, isDirectMarket: isDirectMarket13, priceScale: priceScale13, pairType: pairType13});
        if (i == 14) return TokenConfig({underlying: underlying14, symbolHash: symbolHash14, baseUnit: baseUnit14, priceSource: priceSource14, fixedPrice: fixedPrice14, uniswapMarket: uniswapMarket14, isUniswapReversed: isUniswapReversed14, isDirectMarket: isDirectMarket14, priceScale: priceScale14, pairType: pairType14});
        // if (i == 15) return TokenConfig({underlying: underlying15, symbolHash: symbolHash15, baseUnit: baseUnit15, priceSource: priceSource15, fixedPrice: fixedPrice15, uniswapMarket: uniswapMarket15, isUniswapReversed: isUniswapReversed15, isDirectMarket: isDirectMarkets[i]});
        // if (i == 16) return TokenConfig({underlying: underlying16, symbolHash: symbolHash16, baseUnit: baseUnit16, priceSource: priceSource16, fixedPrice: fixedPrice16, uniswapMarket: uniswapMarket16, isUniswapReversed: isUniswapReversed16, isDirectMarket: isDirectMarkets[i]});
        // if (i == 17) return TokenConfig({underlying: underlying17, symbolHash: symbolHash17, baseUnit: baseUnit17, priceSource: priceSource17, fixedPrice: fixedPrice17, uniswapMarket: uniswapMarket17, isUniswapReversed: isUniswapReversed17, isDirectMarket: isDirectMarkets[i]});
        // if (i == 18) return TokenConfig({underlying: underlying18, symbolHash: symbolHash18, baseUnit: baseUnit18, priceSource: priceSource18, fixedPrice: fixedPrice18, uniswapMarket: uniswapMarket18, isUniswapReversed: isUniswapReversed18, isDirectMarket: isDirectMarkets[i]});
        // if (i == 19) return TokenConfig({underlying: underlying19, symbolHash: symbolHash19, baseUnit: baseUnit19, priceSource: priceSource19, fixedPrice: fixedPrice19, uniswapMarket: uniswapMarket19, isUniswapReversed: isUniswapReversed19, isDirectMarket: isDirectMarkets[i]});

        // if (i == 20) return TokenConfig({underlying: underlying20, symbolHash: symbolHash20, baseUnit: baseUnit20, priceSource: priceSource20, fixedPrice: fixedPrice20, uniswapMarket: uniswapMarket20, isUniswapReversed: isUniswapReversed20, isDirectMarket: isDirectMarkets[i]});
        // if (i == 21) return TokenConfig({underlying: underlying21, symbolHash: symbolHash21, baseUnit: baseUnit21, priceSource: priceSource21, fixedPrice: fixedPrice21, uniswapMarket: uniswapMarket21, isUniswapReversed: isUniswapReversed21, isDirectMarket: isDirectMarkets[i]});
        // if (i == 22) return TokenConfig({underlying: underlying22, symbolHash: symbolHash22, baseUnit: baseUnit22, priceSource: priceSource22, fixedPrice: fixedPrice22, uniswapMarket: uniswapMarket22, isUniswapReversed: isUniswapReversed22, isDirectMarket: isDirectMarkets[i]});
        // if (i == 23) return TokenConfig({underlying: underlying23, symbolHash: symbolHash23, baseUnit: baseUnit23, priceSource: priceSource23, fixedPrice: fixedPrice23, uniswapMarket: uniswapMarket23, isUniswapReversed: isUniswapReversed23, isDirectMarket: isDirectMarkets[i]});
        // if (i == 24) return TokenConfig({underlying: underlying24, symbolHash: symbolHash24, baseUnit: baseUnit24, priceSource: priceSource24, fixedPrice: fixedPrice24, uniswapMarket: uniswapMarket24, isUniswapReversed: isUniswapReversed24, isDirectMarket: isDirectMarkets[i]});
        // if (i == 25) return TokenConfig({underlying: underlying25, symbolHash: symbolHash25, baseUnit: baseUnit25, priceSource: priceSource25, fixedPrice: fixedPrice25, uniswapMarket: uniswapMarket25, isUniswapReversed: isUniswapReversed25, isDirectMarket: isDirectMarkets[i]});
        // if (i == 26) return TokenConfig({underlying: underlying26, symbolHash: symbolHash26, baseUnit: baseUnit26, priceSource: priceSource26, fixedPrice: fixedPrice26, uniswapMarket: uniswapMarket26, isUniswapReversed: isUniswapReversed26, isDirectMarket: isDirectMarkets[i]});
        // if (i == 27) return TokenConfig({underlying: underlying27, symbolHash: symbolHash27, baseUnit: baseUnit27, priceSource: priceSource27, fixedPrice: fixedPrice27, uniswapMarket: uniswapMarket27, isUniswapReversed: isUniswapReversed27, isDirectMarket: isDirectMarkets[i]});
        // if (i == 28) return TokenConfig({underlying: underlying28, symbolHash: symbolHash28, baseUnit: baseUnit28, priceSource: priceSource28, fixedPrice: fixedPrice28, uniswapMarket: uniswapMarket28, isUniswapReversed: isUniswapReversed28, isDirectMarket: isDirectMarkets[i]});
        // if (i == 29) return TokenConfig({underlying: underlying29, symbolHash: symbolHash29, baseUnit: baseUnit29, priceSource: priceSource29, fixedPrice: fixedPrice29, uniswapMarket: uniswapMarket29, isUniswapReversed: isUniswapReversed29, isDirectMarket: isDirectMarkets[i]});
    }

    /**
     * @notice Get the config for symbol
     * @param symbol The symbol of the config to get
     * @return The config object
     */
    function getTokenConfigBySymbol(string memory symbol) public view returns (TokenConfig memory) {
        return getTokenConfigBySymbolHash(keccak256(abi.encodePacked(symbol)));
    }

    /**
     * @notice Get the config for the symbolHash
     * @param symbolHash The keccack256 of the symbol of the config to get
     * @return The config object
     */
    function getTokenConfigBySymbolHash(bytes32 symbolHash) public view returns (TokenConfig memory) {
        uint index = getSymbolHashIndex(symbolHash);
        if (index != uint(-1)) {
            return getTokenConfig(index);
        }

        revert("token config by symbol hash not found");
    }

    /**
     * @notice Get the config for an underlying asset
     * @param underlying The address of the underlying asset of the config to get
     * @return The config object
     */
    function getTokenConfigByUnderlying(address underlying) public view returns (TokenConfig memory) {
        uint index = getUnderlyingIndex(underlying);
        if (index != uint(-1)) {
            return getTokenConfig(index);
        }

        revert("token config by underlying not found");
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.7.6;

// Based on code from https://github.com/Uniswap/uniswap-v2-periphery

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))
library FixedPoint {
    // range: [0, 2**112 - 1]
    // resolution: 1 / 2**112
    struct uq112x112 {
        uint224 _x;
    }

    // returns a uq112x112 which represents the ratio of the numerator to the denominator
    // equivalent to encode(numerator).div(denominator)
    function fraction(uint112 numerator, uint112 denominator) internal pure returns (uq112x112 memory) {
        require(denominator > 0, "FixedPoint: DIV_BY_ZERO");
        return uq112x112((uint224(numerator) << 112) / denominator);
    }

    // decode a uq112x112 into a uint with 18 decimals of precision
    function decode112with18(uq112x112 memory self) internal pure returns (uint) {
        // we only have 256 - 224 = 32 bits to spare, so scaling up by ~60 bits is dangerous
        // instead, get close to:
        //  (x * 1e18) >> 112
        // without risk of overflowing, e.g.:
        //  (x) / 2 ** (112 - lg(1e18))
        return uint(self._x) / 5192296858534827;
    }
}

// library with helper methods for oracles that are concerned with computing average prices
library UniswapV2OracleLibrary {
    using FixedPoint for *;

    // helper function that returns the current block timestamp within the range of uint32, i.e. [0, 2**32 - 1]
    function currentBlockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp % 2 ** 32);
    }

    // produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
    function currentCumulativePrices(
        address pair
    ) internal view returns (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) {
        blockTimestamp = currentBlockTimestamp();
        price0Cumulative = IUniswapV2PairForStateReading(pair).price0CumulativeLast();
        price1Cumulative = IUniswapV2PairForStateReading(pair).price1CumulativeLast();

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IUniswapV2PairForStateReading(pair).getReserves();
        if (blockTimestampLast != blockTimestamp) {
            // subtraction overflow is desired
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            // addition overflow is desired
            // counterfactual
            price0Cumulative += uint(FixedPoint.fraction(reserve1, reserve0)._x) * timeElapsed;
            // counterfactual
            price1Cumulative += uint(FixedPoint.fraction(reserve0, reserve1)._x) * timeElapsed;
        }
    }
}

interface IUniswapV2PairForStateReading {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
}

//pragma solidity =0.5.16;
pragma solidity ^0.7.6;

//import "./libraries/UQ112x112.sol";
//import "./interfaces/ISolidlyBaseV1Pair.sol";
//import "./interfaces/ITarotSolidlyPriceOracle.sol";

interface ITarotSolidlyPriceOracle {
//    function MIN_T() external pure returns (uint32);

//    function getReserveInfo(address pair)
//    external
//    view
//    returns (
//        uint256 reserve0CumulativeSlotA,
//        uint256 reserve1CumulativeSlotA,
//        uint256 reserve0CumulativeSlotB,
//        uint256 reserve1CumulativeSlotB,
//        uint32 lastUpdateSlotA,
//        uint32 lastUpdateSlotB,
//        bool latestIsSlotA,
//        bool initialized
//    );

//    function initialize(address pair) external;

//    function getResultForVelodromePair(address pair) external returns (uint224 price, uint32 T);

    function getBlockTimestamp() external view returns (uint32);

    event ReserveInfoUpdate(address indexed pair, uint256 reserve0Cumulative, uint256 reserve1Cumulative, uint32 blockTimestamp, bool latestIsSlotA);
}

interface ISolidlyBaseV1Pair {
    function getReserves()
    external
    view
    returns (
        uint112 _reserve0,
        uint112 _reserve1,
        uint32 _blockTimestampLast
    );

    function reserve0CumulativeLast() external view returns (uint256);

    function reserve1CumulativeLast() external view returns (uint256);

    function currentCumulativePrices()
    external
    view
    returns (
        uint256 reserve0Cumulative,
        uint256 reserve1Cumulative,
        uint256 blockTimestamp
    );

    function stable() external view returns (bool);
}

contract VelodromePairPriceOracle is ITarotSolidlyPriceOracle {
    using UQ112x112 for uint224;

    uint32 public constant MIN_T = 1200;

    struct ReserveInfo {
        uint256 reserve0CumulativeSlotA;
        uint256 reserve1CumulativeSlotA;
        uint256 reserve0CumulativeSlotB;
        uint256 reserve1CumulativeSlotB;
        uint32 lastUpdateSlotA;
        uint32 lastUpdateSlotB;
        bool latestIsSlotA;
        bool initialized;
    }
    mapping(address => ReserveInfo) public getReserveInfo;

    function getPair(address pair)
    external
    view
    returns (
        uint256 priceCumulativeSlotA,
        uint256 priceCumulativeSlotB,
        uint32 lastUpdateSlotA,
        uint32 lastUpdateSlotB,
        bool latestIsSlotA,
        bool initialized
    )
    {
        priceCumulativeSlotA;
        priceCumulativeSlotB;
        ReserveInfo storage reserveInfoStorage = getReserveInfo[pair];
        (lastUpdateSlotA, lastUpdateSlotB, latestIsSlotA, initialized) = (
        reserveInfoStorage.lastUpdateSlotA,
        reserveInfoStorage.lastUpdateSlotB,
        reserveInfoStorage.latestIsSlotA,
        reserveInfoStorage.initialized
        );
    }

    function safe112(uint256 n) internal pure returns (uint112) {
        require(n < 2**112, "TarotPriceOracle: SAFE112");
        return uint112(n);
    }

    function initializeVelodromePair(address pair) internal {
        ReserveInfo storage reserveInfoStorage = getReserveInfo[pair];
        require(!reserveInfoStorage.initialized, "TarotPriceOracle: ALREADY_INITIALIZED");

        require(!ISolidlyBaseV1Pair(pair).stable(), "TarotPriceOracle: VAMM_ONLY");
        (uint256 reserve0Cumulative, uint256 reserve1Cumulative, ) = ISolidlyBaseV1Pair(pair).currentCumulativePrices();
        uint32 blockTimestamp = getBlockTimestamp();

        reserveInfoStorage.reserve0CumulativeSlotA = reserve0Cumulative;
        reserveInfoStorage.reserve1CumulativeSlotA = reserve1Cumulative;
        reserveInfoStorage.reserve0CumulativeSlotB = reserve0Cumulative;
        reserveInfoStorage.reserve1CumulativeSlotB = reserve1Cumulative;
        reserveInfoStorage.lastUpdateSlotA = blockTimestamp;
        reserveInfoStorage.lastUpdateSlotB = blockTimestamp;
        reserveInfoStorage.latestIsSlotA = true;
        reserveInfoStorage.initialized = true;

        emit ReserveInfoUpdate(pair, reserve0Cumulative, reserve1Cumulative, blockTimestamp, true);
    }

    function getResultForVelodromePair(address pair) internal returns (uint224 price, uint32 T) {
        ReserveInfo memory reserveInfo = getReserveInfo[pair];
        require(reserveInfo.initialized, "TarotPriceOracle: NOT_INITIALIZED");
        ReserveInfo storage reserveInfoStorage = getReserveInfo[pair];

        uint32 blockTimestamp = getBlockTimestamp();
        uint32 lastUpdateTimestamp = reserveInfo.latestIsSlotA ? reserveInfo.lastUpdateSlotA : reserveInfo.lastUpdateSlotB;
        (uint256 reserve0CumulativeCurrent, uint256 reserve1CumulativeCurrent, ) = ISolidlyBaseV1Pair(pair).currentCumulativePrices();

        uint256 reserve0CumulativeLast;
        uint256 reserve1CumulativeLast;

        if (blockTimestamp - lastUpdateTimestamp >= MIN_T) {
            // update price
            if (reserveInfo.latestIsSlotA) {
                reserve0CumulativeLast = reserveInfo.reserve0CumulativeSlotA;
                reserve1CumulativeLast = reserveInfo.reserve1CumulativeSlotA;

                reserveInfoStorage.reserve0CumulativeSlotB = reserve0CumulativeCurrent;
                reserveInfoStorage.reserve1CumulativeSlotB = reserve1CumulativeCurrent;
                reserveInfoStorage.lastUpdateSlotB = blockTimestamp;
                reserveInfoStorage.latestIsSlotA = false;
                emit ReserveInfoUpdate(pair, reserve0CumulativeCurrent, reserve1CumulativeCurrent, blockTimestamp, false);
            } else {
                reserve0CumulativeLast = reserveInfo.reserve0CumulativeSlotB;
                reserve1CumulativeLast = reserveInfo.reserve1CumulativeSlotB;

                reserveInfoStorage.reserve0CumulativeSlotA = reserve0CumulativeCurrent;
                reserveInfoStorage.reserve1CumulativeSlotA = reserve1CumulativeCurrent;
                reserveInfoStorage.lastUpdateSlotA = blockTimestamp;
                reserveInfoStorage.latestIsSlotA = true;
                emit ReserveInfoUpdate(pair, reserve0CumulativeCurrent, reserve1CumulativeCurrent, blockTimestamp, true);
            }
        } else {
            // don't update; return price using previous priceCumulative
            if (reserveInfo.latestIsSlotA) {
                lastUpdateTimestamp = reserveInfo.lastUpdateSlotB;
                reserve0CumulativeLast = reserveInfo.reserve0CumulativeSlotB;
                reserve1CumulativeLast = reserveInfo.reserve1CumulativeSlotB;
            } else {
                lastUpdateTimestamp = reserveInfo.lastUpdateSlotA;
                reserve0CumulativeLast = reserveInfo.reserve0CumulativeSlotA;
                reserve1CumulativeLast = reserveInfo.reserve1CumulativeSlotA;
            }
        }

        T = blockTimestamp - lastUpdateTimestamp; // overflow is desired
        require(T >= MIN_T, "TarotPriceOracle: NOT_READY"); //reverts only if the pair has just been initialized
        // / is safe, and - overflow is desired
        uint112 twapReserve0 = safe112((reserve0CumulativeCurrent - reserve0CumulativeLast) / T);
        uint112 twapReserve1 = safe112((reserve1CumulativeCurrent - reserve1CumulativeLast) / T);

        // Note : Reversed to support assets paired with wNative
//        price = UQ112x112.encode(twapReserve1).uqdiv(twapReserve0);
        price = UQ112x112.encode(twapReserve0).uqdiv(twapReserve1);
    }

    /*** Utilities ***/

    function getBlockTimestamp() public view override returns (uint32) {
        return uint32(block.timestamp % 2**32);
    }
}

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))

// range: [0, 2**112 - 1]
// resolution: 1 / 2**112

library UQ112x112 {
    uint224 constant Q112 = 2**112;

    // encode a uint112 as a UQ112x112
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }

    // decode a uq112x112 into a uint with 18 decimals of precision
    function decode224with18(uint224 x) internal pure returns (uint) {
        // we only have 256 - 224 = 32 bits to spare, so scaling up by ~60 bits is dangerous
        // instead, get close to:
        //  (x * 1e18) >> 112
        // without risk of overflowing, e.g.:
        //  (x) / 2 ** (112 - lg(1e18))
        return uint(x) / 5192296858534827;
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

/**
 * @title The Open Oracle Data Base Contract
 * @author Compound Labs, Inc.
 */
contract OpenOracleData {
    /**
     * @notice The event emitted when a source writes to its storage
     */
    //event Write(address indexed source, <Key> indexed key, string kind, uint64 timestamp, <Value> value);

    /**
     * @notice Write a bunch of signed datum to the authenticated storage mapping
     * @param message The payload containing the timestamp, and (key, value) pairs
     * @param signature The cryptographic signature of the message payload, authorizing the source to write
     * @return The keys that were written
     */
    //function put(bytes calldata message, bytes calldata signature) external returns (<Key> memory);

    /**
     * @notice Read a single key with a pre-defined type signature from an authenticated source
     * @param source The verifiable author of the data
     * @param key The selector for the value to return
     * @return The claimed Unix timestamp for the data and the encoded value (defaults to (0, 0x))
     */
    //function get(address source, <Key> key) external view returns (uint, <Value>);

    /**
     * @notice Recovers the source address which signed a message
     * @dev Comparing to a claimed address would add nothing,
     *  as the caller could simply perform the recover and claim that address.
     * @param message The data that was presumably signed
     * @param signature The fingerprint of the data + private key
     * @return The source address which signed the message, presumably
     */
    function source(bytes memory message, bytes memory signature) public view returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = abi.decode(signature, (bytes32, bytes32, uint8));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(message)));
        return ecrecover(hash, v, r, s);
    }
}