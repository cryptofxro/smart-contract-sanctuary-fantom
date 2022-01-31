// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

library Constants {
  bytes4 public constant ERC165_INTERFACE_ID_ERC165 = 0x01ffc9a7;
  bytes4 public constant ERC165_INTERFACE_ID_ERC721 = 0x80ac58cd;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "./PeriodicPrizeStrategyListenerInterface.sol";
import "./PeriodicPrizeStrategyListenerLibrary.sol";
import "../Constants.sol";

abstract contract PeriodicPrizeStrategyListener is PeriodicPrizeStrategyListenerInterface {
  function supportsInterface(bytes4 interfaceId) external override view returns (bool) {
    return (
      interfaceId == Constants.ERC165_INTERFACE_ID_ERC165 || 
      interfaceId == PeriodicPrizeStrategyListenerLibrary.ERC165_INTERFACE_ID_PERIODIC_PRIZE_STRATEGY_LISTENER
    );
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/introspection/IERC165Upgradeable.sol";

/* solium-disable security/no-block-members */
interface PeriodicPrizeStrategyListenerInterface is IERC165Upgradeable {
  function afterPrizePoolAwarded(uint256 randomNumber, uint256 prizePeriodStartedAt) external;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

library PeriodicPrizeStrategyListenerLibrary {
  /*
    *     bytes4(keccak256('afterPrizePoolAwarded(uint256,uint256)')) == 0x575072c6
    */
  bytes4 public constant ERC165_INTERFACE_ID_PERIODIC_PRIZE_STRATEGY_LISTENER = 0x575072c6;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/introspection/ERC165CheckerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@pooltogether/pooltogether-rng-contracts/contracts/RNGInterface.sol";
import "@pooltogether/fixed-point/contracts/FixedPoint.sol";

import "../token/TokenListener.sol";
import "../token/TokenControllerInterface.sol";
import "../token/ControlledToken.sol";
import "../token/TicketInterface.sol";
import "../prize-pool/PrizePool.sol";
import "../utils/UInt256Array.sol";
import "../Constants.sol";
import "./PeriodicPrizeStrategyListenerInterface.sol";
import "./PeriodicPrizeStrategyListenerLibrary.sol";
import "./BeforeAwardListener.sol";

/* solium-disable security/no-block-members */
abstract contract PeriodicPrizeStrategy is
    Initializable,
    OwnableUpgradeable,
    TokenListener
{
    using SafeMathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MappedSinglyLinkedList for MappedSinglyLinkedList.Mapping;
    using AddressUpgradeable for address;
    using ERC165CheckerUpgradeable for address;
    using UInt256Array for uint256[];

    uint256 internal constant ETHEREUM_BLOCK_TIME_ESTIMATE_MANTISSA =
        13.4 ether;

    event PrizePoolOpened(
        address indexed operator,
        uint256 indexed prizePeriodStartedAt
    );

    event RngRequestFailed();

    event PrizePoolAwardStarted(
        address indexed operator,
        address indexed prizePool,
        uint32 indexed rngRequestId,
        uint32 rngLockBlock
    );

    event PrizePoolAwardCancelled(
        address indexed operator,
        address indexed prizePool,
        uint32 indexed rngRequestId,
        uint32 rngLockBlock
    );

    event PrizePoolAwarded(address indexed operator, uint256 randomNumber);

    event RngServiceUpdated(RNGInterface indexed rngService);

    event TokenListenerUpdated(TokenListenerInterface indexed tokenListener);

    event RngRequestTimeoutSet(uint32 rngRequestTimeout);

    event PrizePeriodSecondsUpdated(uint256 prizePeriodSeconds);

    event BeforeAwardListenerSet(
        BeforeAwardListenerInterface indexed beforeAwardListener
    );

    event PeriodicPrizeStrategyListenerSet(
        PeriodicPrizeStrategyListenerInterface indexed periodicPrizeStrategyListener
    );

    event ExternalErc721AwardAdded(
        IERC721Upgradeable indexed externalErc721,
        uint256[] tokenIds
    );

    event ExternalErc20AwardAdded(IERC20Upgradeable indexed externalErc20);

    event ExternalErc721AwardRemoved(
        IERC721Upgradeable indexed externalErc721Award
    );

    event ExternalErc20AwardRemoved(
        IERC20Upgradeable indexed externalErc20Award
    );

    event Initialized(
        uint256 prizePeriodStart,
        uint256 prizePeriodSeconds,
        PrizePool indexed prizePool,
        TicketInterface ticket,
        IERC20Upgradeable sponsorship,
        RNGInterface rng,
        IERC20Upgradeable[] externalErc20Awards
    );

    struct RngRequest {
        uint32 id;
        uint32 lockBlock;
        uint32 requestedAt;
    }

    // Comptroller
    TokenListenerInterface public tokenListener;

    // Contract Interfaces
    PrizePool public prizePool;
    TicketInterface public ticket;
    IERC20Upgradeable public sponsorship;
    RNGInterface public rng;

    // Current RNG Request
    RngRequest internal rngRequest;

    /// @notice RNG Request Timeout.  In fact, this is really a "complete award" timeout.
    /// If the rng completes the award can still be cancelled.
    uint32 public rngRequestTimeout;

    // Prize period
    uint256 public prizePeriodSeconds;
    uint256 public prizePeriodStartedAt;

    // External tokens awarded as part of prize
    MappedSinglyLinkedList.Mapping internal externalErc20s;
    MappedSinglyLinkedList.Mapping internal externalErc721s;

    // External NFT token IDs to be awarded
    //   NFT Address => TokenIds
    mapping(IERC721Upgradeable => uint256[]) internal externalErc721TokenIds;

    /// @notice A listener that is called before the prize is awarded
    BeforeAwardListenerInterface public beforeAwardListener;

    /// @notice A listener that is called after the prize is awarded
    PeriodicPrizeStrategyListenerInterface public periodicPrizeStrategyListener;

    /// @notice Initializes a new strategy
    /// @param _prizePeriodStart The starting timestamp of the prize period.
    /// @param _prizePeriodSeconds The duration of the prize period in seconds
    /// @param _prizePool The prize pool to award
    /// @param _ticket The ticket to use to draw winners
    /// @param _sponsorship The sponsorship token
    /// @param _rng The RNG service to use
    function initialize(
        uint256 _prizePeriodStart,
        uint256 _prizePeriodSeconds,
        PrizePool _prizePool,
        TicketInterface _ticket,
        IERC20Upgradeable _sponsorship,
        RNGInterface _rng,
        IERC20Upgradeable[] memory externalErc20Awards
    ) public initializer {
        require(
            address(_prizePool) != address(0),
            "PeriodicPrizeStrategy/prize-pool-not-zero"
        );
        require(
            address(_ticket) != address(0),
            "PeriodicPrizeStrategy/ticket-not-zero"
        );
        require(
            address(_sponsorship) != address(0),
            "PeriodicPrizeStrategy/sponsorship-not-zero"
        );
        require(
            address(_rng) != address(0),
            "PeriodicPrizeStrategy/rng-not-zero"
        );
        prizePool = _prizePool;
        ticket = _ticket;
        rng = _rng;
        sponsorship = _sponsorship;
        _setPrizePeriodSeconds(_prizePeriodSeconds);

        __Ownable_init();

        externalErc20s.initialize();
        for (uint256 i = 0; i < externalErc20Awards.length; i++) {
            _addExternalErc20Award(externalErc20Awards[i]);
        }

        prizePeriodSeconds = _prizePeriodSeconds;
        prizePeriodStartedAt = _prizePeriodStart;

        externalErc721s.initialize();

        // 30 min timeout
        _setRngRequestTimeout(1800);

        emit Initialized(
            _prizePeriodStart,
            _prizePeriodSeconds,
            _prizePool,
            _ticket,
            _sponsorship,
            _rng,
            externalErc20Awards
        );
        emit PrizePoolOpened(_msgSender(), prizePeriodStartedAt);
    }

    function _distribute(uint256 randomNumber) internal virtual;

    /// @notice Calculates and returns the currently accrued prize
    /// @return The current prize size
    function currentPrize() public view returns (uint256) {
        return prizePool.awardBalance();
    }

    /// @notice Allows the owner to set the token listener
    /// @param _tokenListener A contract that implements the token listener interface.
    function setTokenListener(TokenListenerInterface _tokenListener)
        external
        onlyOwner
        requireAwardNotInProgress
    {
        require(
            address(0) == address(_tokenListener) ||
                address(_tokenListener).supportsInterface(
                    TokenListenerLibrary.ERC165_INTERFACE_ID_TOKEN_LISTENER
                ),
            "PeriodicPrizeStrategy/token-listener-invalid"
        );

        tokenListener = _tokenListener;

        emit TokenListenerUpdated(tokenListener);
    }

    /// @notice Estimates the remaining blocks until the prize given a number of seconds per block
    /// @param secondsPerBlockMantissa The number of seconds per block to use for the calculation.  Should be a fixed point 18 number like Ether.
    /// @return The estimated number of blocks remaining until the prize can be awarded.
    function estimateRemainingBlocksToPrize(uint256 secondsPerBlockMantissa)
        public
        view
        returns (uint256)
    {
        return
            FixedPoint.divideUintByMantissa(
                _prizePeriodRemainingSeconds(),
                secondsPerBlockMantissa
            );
    }

    /// @notice Returns the number of seconds remaining until the prize can be awarded.
    /// @return The number of seconds remaining until the prize can be awarded.
    function prizePeriodRemainingSeconds() external view returns (uint256) {
        return _prizePeriodRemainingSeconds();
    }

    /// @notice Returns the number of seconds remaining until the prize can be awarded.
    /// @return The number of seconds remaining until the prize can be awarded.
    function _prizePeriodRemainingSeconds() internal view returns (uint256) {
        uint256 endAt = _prizePeriodEndAt();
        uint256 time = _currentTime();
        if (time > endAt) {
            return 0;
        }
        return endAt.sub(time);
    }

    /// @notice Returns whether the prize period is over
    /// @return True if the prize period is over, false otherwise
    function isPrizePeriodOver() external view returns (bool) {
        return _isPrizePeriodOver();
    }

    /// @notice Returns whether the prize period is over
    /// @return True if the prize period is over, false otherwise
    function _isPrizePeriodOver() internal view returns (bool) {
        return _currentTime() >= _prizePeriodEndAt();
    }

    /// @notice Awards collateral as tickets to a user
    /// @param user The user to whom the tickets are minted
    /// @param amount The amount of interest to mint as tickets.
    function _awardTickets(address user, uint256 amount) internal {
        prizePool.award(user, amount, address(ticket));
    }

    /// @notice Awards all external tokens with non-zero balances to the given user.  The external tokens must be held by the PrizePool contract.
    /// @param winner The user to transfer the tokens to
    function _awardAllExternalTokens(address winner) internal {
        _awardExternalErc20s(winner);
        _awardExternalErc721s(winner);
    }

    /// @notice Awards all external ERC20 tokens with non-zero balances to the given user.
    /// The external tokens must be held by the PrizePool contract.
    /// @param winner The user to transfer the tokens to
    function _awardExternalErc20s(address winner) internal {
        address currentToken = externalErc20s.start();
        while (
            currentToken != address(0) && currentToken != externalErc20s.end()
        ) {
            uint256 balance = IERC20Upgradeable(currentToken).balanceOf(
                address(prizePool)
            );
            if (balance > 0) {
                prizePool.awardExternalERC20(winner, currentToken, balance);
            }
            currentToken = externalErc20s.next(currentToken);
        }
    }

    /// @notice Awards all external ERC721 tokens to the given user.
    /// The external tokens must be held by the PrizePool contract.
    /// @dev The list of ERC721s is reset after every award
    /// @param winner The user to transfer the tokens to
    function _awardExternalErc721s(address winner) internal {
        address currentToken = externalErc721s.start();
        while (
            currentToken != address(0) && currentToken != externalErc721s.end()
        ) {
            uint256 balance = IERC721Upgradeable(currentToken).balanceOf(
                address(prizePool)
            );
            if (balance > 0) {
                prizePool.awardExternalERC721(
                    winner,
                    currentToken,
                    externalErc721TokenIds[IERC721Upgradeable(currentToken)]
                );
                _removeExternalErc721AwardTokens(
                    IERC721Upgradeable(currentToken)
                );
            }
            currentToken = externalErc721s.next(currentToken);
        }
        externalErc721s.clearAll();
    }

    /// @notice Returns the timestamp at which the prize period ends
    /// @return The timestamp at which the prize period ends.
    function prizePeriodEndAt() external view returns (uint256) {
        // current prize started at is non-inclusive, so add one
        return _prizePeriodEndAt();
    }

    /// @notice Returns the timestamp at which the prize period ends
    /// @return The timestamp at which the prize period ends.
    function _prizePeriodEndAt() internal view returns (uint256) {
        // current prize started at is non-inclusive, so add one
        return prizePeriodStartedAt.add(prizePeriodSeconds);
    }

    /// @notice Called by the PrizePool for transfers of controlled tokens
    /// @dev Note that this is only for *transfers*, not mints or burns
    /// @param controlledToken The type of collateral that is being sent
    function beforeTokenTransfer(
        address from,
        address to,
        uint256 amount,
        address controlledToken
    ) external override onlyPrizePool {
        require(from != to, "PeriodicPrizeStrategy/transfer-to-self");

        if (controlledToken == address(ticket)) {
            _requireAwardNotInProgress();
        }

        if (address(tokenListener) != address(0)) {
            tokenListener.beforeTokenTransfer(
                from,
                to,
                amount,
                controlledToken
            );
        }
    }

    /// @notice Called by the PrizePool when minting controlled tokens
    /// @param controlledToken The type of collateral that is being minted
    function beforeTokenMint(
        address to,
        uint256 amount,
        address controlledToken,
        address referrer
    ) external override onlyPrizePool {
        if (controlledToken == address(ticket)) {
            _requireAwardNotInProgress();
        }
        if (address(tokenListener) != address(0)) {
            tokenListener.beforeTokenMint(
                to,
                amount,
                controlledToken,
                referrer
            );
        }
    }

    /// @notice returns the current time.  Used for testing.
    /// @return The current time (block.timestamp)
    function _currentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    /// @notice returns the current time.  Used for testing.
    /// @return The current time (block.timestamp)
    function _currentBlock() internal view virtual returns (uint256) {
        return block.number;
    }

    /// @notice Starts the award process by starting random number request.  The prize period must have ended.
    /// @dev The RNG-Request-Fee is expected to be held within this contract before calling this function
    function startAward() external requireCanStartAward {
        (address feeToken, uint256 requestFee) = rng.getRequestFee();
        if (feeToken != address(0) && requestFee > 0) {
            IERC20Upgradeable(feeToken).safeApprove(address(rng), requestFee);
        }

        (uint32 requestId, uint32 lockBlock) = rng.requestRandomNumber();
        rngRequest.id = requestId;
        rngRequest.lockBlock = lockBlock;
        rngRequest.requestedAt = _currentTime().toUint32();

        emit PrizePoolAwardStarted(
            _msgSender(),
            address(prizePool),
            requestId,
            lockBlock
        );
    }

    /// @notice Can be called by anyone to unlock the tickets if the RNG has timed out.
    function cancelAward() public {
        require(isRngTimedOut(), "PeriodicPrizeStrategy/rng-not-timedout");
        uint32 requestId = rngRequest.id;
        uint32 lockBlock = rngRequest.lockBlock;
        delete rngRequest;
        emit RngRequestFailed();
        emit PrizePoolAwardCancelled(
            msg.sender,
            address(prizePool),
            requestId,
            lockBlock
        );
    }

    /// @notice Completes the award process and awards the winners.  The random number must have been requested and is now available.
    function completeAward() external requireCanCompleteAward {
        uint256 randomNumber = rng.randomNumber(rngRequest.id);
        delete rngRequest;

        if (address(beforeAwardListener) != address(0)) {
            beforeAwardListener.beforePrizePoolAwarded(
                randomNumber,
                prizePeriodStartedAt
            );
        }
        _distribute(randomNumber);
        if (address(periodicPrizeStrategyListener) != address(0)) {
            periodicPrizeStrategyListener.afterPrizePoolAwarded(
                randomNumber,
                prizePeriodStartedAt
            );
        }

        // to avoid clock drift, we should calculate the start time based on the previous period start time.
        prizePeriodStartedAt = _calculateNextPrizePeriodStartTime(
            _currentTime()
        );

        emit PrizePoolAwarded(_msgSender(), randomNumber);
        emit PrizePoolOpened(_msgSender(), prizePeriodStartedAt);
    }

    /// @notice Allows the owner to set a listener that is triggered immediately before the award is distributed
    /// @dev The listener must implement ERC165 and the BeforeAwardListenerInterface
    /// @param _beforeAwardListener The address of the listener contract
    function setBeforeAwardListener(
        BeforeAwardListenerInterface _beforeAwardListener
    ) external onlyOwner requireAwardNotInProgress {
        require(
            address(0) == address(_beforeAwardListener) ||
                address(_beforeAwardListener).supportsInterface(
                    BeforeAwardListenerLibrary
                        .ERC165_INTERFACE_ID_BEFORE_AWARD_LISTENER
                ),
            "PeriodicPrizeStrategy/beforeAwardListener-invalid"
        );

        beforeAwardListener = _beforeAwardListener;

        emit BeforeAwardListenerSet(_beforeAwardListener);
    }

    /// @notice Allows the owner to set a listener for prize strategy callbacks.
    /// @param _periodicPrizeStrategyListener The address of the listener contract
    function setPeriodicPrizeStrategyListener(
        PeriodicPrizeStrategyListenerInterface _periodicPrizeStrategyListener
    ) external onlyOwner requireAwardNotInProgress {
        require(
            address(0) == address(_periodicPrizeStrategyListener) ||
                address(_periodicPrizeStrategyListener).supportsInterface(
                    PeriodicPrizeStrategyListenerLibrary
                        .ERC165_INTERFACE_ID_PERIODIC_PRIZE_STRATEGY_LISTENER
                ),
            "PeriodicPrizeStrategy/prizeStrategyListener-invalid"
        );

        periodicPrizeStrategyListener = _periodicPrizeStrategyListener;

        emit PeriodicPrizeStrategyListenerSet(_periodicPrizeStrategyListener);
    }

    function _calculateNextPrizePeriodStartTime(uint256 currentTime)
        internal
        view
        returns (uint256)
    {
        uint256 elapsedPeriods = currentTime.sub(prizePeriodStartedAt).div(
            prizePeriodSeconds
        );
        return prizePeriodStartedAt.add(elapsedPeriods.mul(prizePeriodSeconds));
    }

    /// @notice Calculates when the next prize period will start
    /// @param currentTime The timestamp to use as the current time
    /// @return The timestamp at which the next prize period would start
    function calculateNextPrizePeriodStartTime(uint256 currentTime)
        external
        view
        returns (uint256)
    {
        return _calculateNextPrizePeriodStartTime(currentTime);
    }

    /// @notice Returns whether an award process can be started
    /// @return True if an award can be started, false otherwise.
    function canStartAward() external view returns (bool) {
        return _isPrizePeriodOver() && !isRngRequested();
    }

    /// @notice Returns whether an award process can be completed
    /// @return True if an award can be completed, false otherwise.
    function canCompleteAward() external view returns (bool) {
        return isRngRequested() && isRngCompleted();
    }

    /// @notice Returns whether a random number has been requested
    /// @return True if a random number has been requested, false otherwise.
    function isRngRequested() public view returns (bool) {
        return rngRequest.id != 0;
    }

    /// @notice Returns whether the random number request has completed.
    /// @return True if a random number request has completed, false otherwise.
    function isRngCompleted() public view returns (bool) {
        return rng.isRequestComplete(rngRequest.id);
    }

    /// @notice Returns the block number that the current RNG request has been locked to
    /// @return The block number that the RNG request is locked to
    function getLastRngLockBlock() external view returns (uint32) {
        return rngRequest.lockBlock;
    }

    /// @notice Returns the current RNG Request ID
    /// @return The current Request ID
    function getLastRngRequestId() external view returns (uint32) {
        return rngRequest.id;
    }

    /// @notice Sets the RNG service that the Prize Strategy is connected to
    /// @param rngService The address of the new RNG service interface
    function setRngService(RNGInterface rngService)
        external
        onlyOwner
        requireAwardNotInProgress
    {
        require(!isRngRequested(), "PeriodicPrizeStrategy/rng-in-flight");

        rng = rngService;
        emit RngServiceUpdated(rngService);
    }

    /// @notice Allows the owner to set the RNG request timeout in seconds.  This is the time that must elapsed before the RNG request can be cancelled and the pool unlocked.
    /// @param _rngRequestTimeout The RNG request timeout in seconds.
    function setRngRequestTimeout(uint32 _rngRequestTimeout)
        external
        onlyOwner
        requireAwardNotInProgress
    {
        _setRngRequestTimeout(_rngRequestTimeout);
    }

    /// @notice Sets the RNG request timeout in seconds.  This is the time that must elapsed before the RNG request can be cancelled and the pool unlocked.
    /// @param _rngRequestTimeout The RNG request timeout in seconds.
    function _setRngRequestTimeout(uint32 _rngRequestTimeout) internal {
        require(
            _rngRequestTimeout > 60,
            "PeriodicPrizeStrategy/rng-timeout-gt-60-secs"
        );
        rngRequestTimeout = _rngRequestTimeout;
        emit RngRequestTimeoutSet(rngRequestTimeout);
    }

    /// @notice Allows the owner to set the prize period in seconds.
    /// @param _prizePeriodSeconds The new prize period in seconds.  Must be greater than zero.
    function setPrizePeriodSeconds(uint256 _prizePeriodSeconds)
        external
        onlyOwner
        requireAwardNotInProgress
    {
        _setPrizePeriodSeconds(_prizePeriodSeconds);
    }

    /// @notice Sets the prize period in seconds.
    /// @param _prizePeriodSeconds The new prize period in seconds.  Must be greater than zero.
    function _setPrizePeriodSeconds(uint256 _prizePeriodSeconds) internal {
        require(
            _prizePeriodSeconds > 0,
            "PeriodicPrizeStrategy/prize-period-greater-than-zero"
        );
        prizePeriodSeconds = _prizePeriodSeconds;

        emit PrizePeriodSecondsUpdated(prizePeriodSeconds);
    }

    /// @notice Gets the current list of External ERC20 tokens that will be awarded with the current prize
    /// @return An array of External ERC20 token addresses
    function getExternalErc20Awards() external view returns (address[] memory) {
        return externalErc20s.addressArray();
    }

    /// @notice Adds an external ERC20 token type as an additional prize that can be awarded
    /// @dev Only the Prize-Strategy owner/creator can assign external tokens,
    /// and they must be approved by the Prize-Pool
    /// @param _externalErc20 The address of an ERC20 token to be awarded
    function addExternalErc20Award(IERC20Upgradeable _externalErc20)
        external
        onlyOwnerOrListener
        requireAwardNotInProgress
    {
        _addExternalErc20Award(_externalErc20);
    }

    function _addExternalErc20Award(IERC20Upgradeable _externalErc20) internal {
        require(
            address(_externalErc20).isContract(),
            "PeriodicPrizeStrategy/erc20-null"
        );
        require(
            prizePool.canAwardExternal(address(_externalErc20)),
            "PeriodicPrizeStrategy/cannot-award-external"
        );
        (bool succeeded, ) = address(_externalErc20).staticcall(
            abi.encodeWithSignature("totalSupply()")
        );
        require(succeeded, "PeriodicPrizeStrategy/erc20-invalid");
        externalErc20s.addAddress(address(_externalErc20));
        emit ExternalErc20AwardAdded(_externalErc20);
    }

    function addExternalErc20Awards(
        IERC20Upgradeable[] calldata _externalErc20s
    ) external onlyOwnerOrListener requireAwardNotInProgress {
        for (uint256 i = 0; i < _externalErc20s.length; i++) {
            _addExternalErc20Award(_externalErc20s[i]);
        }
    }

    /// @notice Removes an external ERC20 token type as an additional prize that can be awarded
    /// @dev Only the Prize-Strategy owner/creator can remove external tokens
    /// @param _externalErc20 The address of an ERC20 token to be removed
    /// @param _prevExternalErc20 The address of the previous ERC20 token in the `externalErc20s` list.
    /// If the ERC20 is the first address, then the previous address is the SENTINEL address: 0x0000000000000000000000000000000000000001
    function removeExternalErc20Award(
        IERC20Upgradeable _externalErc20,
        IERC20Upgradeable _prevExternalErc20
    ) external onlyOwner requireAwardNotInProgress {
        externalErc20s.removeAddress(
            address(_prevExternalErc20),
            address(_externalErc20)
        );
        emit ExternalErc20AwardRemoved(_externalErc20);
    }

    /// @notice Gets the current list of External ERC721 tokens that will be awarded with the current prize
    /// @return An array of External ERC721 token addresses
    function getExternalErc721Awards()
        external
        view
        returns (address[] memory)
    {
        return externalErc721s.addressArray();
    }

    /// @notice Gets the current list of External ERC721 tokens that will be awarded with the current prize
    /// @return An array of External ERC721 token addresses
    function getExternalErc721AwardTokenIds(IERC721Upgradeable _externalErc721)
        external
        view
        returns (uint256[] memory)
    {
        return externalErc721TokenIds[_externalErc721];
    }

    /// @notice Adds an external ERC721 token as an additional prize that can be awarded
    /// @dev Only the Prize-Strategy owner/creator can assign external tokens,
    /// and they must be approved by the Prize-Pool
    /// NOTE: The NFT must already be owned by the Prize-Pool
    /// @param _externalErc721 The address of an ERC721 token to be awarded
    /// @param _tokenIds An array of token IDs of the ERC721 to be awarded
    function addExternalErc721Award(
        IERC721Upgradeable _externalErc721,
        uint256[] calldata _tokenIds
    ) external onlyOwnerOrListener requireAwardNotInProgress {
        require(
            prizePool.canAwardExternal(address(_externalErc721)),
            "PeriodicPrizeStrategy/cannot-award-external"
        );
        require(
            address(_externalErc721).supportsInterface(
                Constants.ERC165_INTERFACE_ID_ERC721
            ),
            "PeriodicPrizeStrategy/erc721-invalid"
        );

        if (!externalErc721s.contains(address(_externalErc721))) {
            externalErc721s.addAddress(address(_externalErc721));
        }

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            _addExternalErc721Award(_externalErc721, _tokenIds[i]);
        }

        emit ExternalErc721AwardAdded(_externalErc721, _tokenIds);
    }

    function _addExternalErc721Award(
        IERC721Upgradeable _externalErc721,
        uint256 _tokenId
    ) internal {
        require(
            IERC721Upgradeable(_externalErc721).ownerOf(_tokenId) ==
                address(prizePool),
            "PeriodicPrizeStrategy/unavailable-token"
        );
        for (
            uint256 i = 0;
            i < externalErc721TokenIds[_externalErc721].length;
            i++
        ) {
            if (externalErc721TokenIds[_externalErc721][i] == _tokenId) {
                revert("PeriodicPrizeStrategy/erc721-duplicate");
            }
        }
        externalErc721TokenIds[_externalErc721].push(_tokenId);
    }

    /// @notice Removes an external ERC721 token as an additional prize that can be awarded
    /// @dev Only the Prize-Strategy owner/creator can remove external tokens
    /// @param _externalErc721 The address of an ERC721 token to be removed
    /// @param _prevExternalErc721 The address of the previous ERC721 token in the list.
    /// If no previous, then pass the SENTINEL address: 0x0000000000000000000000000000000000000001
    function removeExternalErc721Award(
        IERC721Upgradeable _externalErc721,
        IERC721Upgradeable _prevExternalErc721
    ) external onlyOwner requireAwardNotInProgress {
        externalErc721s.removeAddress(
            address(_prevExternalErc721),
            address(_externalErc721)
        );
        _removeExternalErc721AwardTokens(_externalErc721);
    }

    function _removeExternalErc721AwardTokens(
        IERC721Upgradeable _externalErc721
    ) internal {
        delete externalErc721TokenIds[_externalErc721];
        emit ExternalErc721AwardRemoved(_externalErc721);
    }

    function removeExternalErc721AwardTokenIdByIndex(
        IERC721Upgradeable _externalErc721,
        uint256 _tokenIndex
    ) external onlyOwner requireAwardNotInProgress {
        _removeExternalErc721AwardTokenIdByIndex(_externalErc721, _tokenIndex);
    }

    function _removeExternalErc721AwardTokenIdByIndex(
        IERC721Upgradeable _externalErc721,
        uint256 _tokenIndex
    ) internal {
        externalErc721TokenIds[_externalErc721].remove(_tokenIndex);
    }

    function recoverErc721(address _externalErc721, uint256[] calldata tokenIds)
        external
        onlyOwner
        requireAwardNotInProgress
    {
        prizePool.transferExternalERC721(msg.sender, _externalErc721, tokenIds);
    }

    function recoverErc20(address _externalErc20, uint256 _amount)
        external
        onlyOwner
        requireAwardNotInProgress
    {
        prizePool.transferExternalERC20(msg.sender, _externalErc20, _amount);
    }

    function _requireAwardNotInProgress() internal view {
        uint256 currentBlock = _currentBlock();
        require(
            rngRequest.lockBlock == 0 || currentBlock < rngRequest.lockBlock,
            "PeriodicPrizeStrategy/rng-in-flight"
        );
    }

    function isRngTimedOut() public view returns (bool) {
        if (rngRequest.requestedAt == 0) {
            return false;
        } else {
            return
                _currentTime() >
                uint256(rngRequestTimeout).add(rngRequest.requestedAt);
        }
    }

    modifier onlyOwnerOrListener() {
        require(
            _msgSender() == owner() ||
                _msgSender() == address(periodicPrizeStrategyListener) ||
                _msgSender() == address(beforeAwardListener),
            "PeriodicPrizeStrategy/only-owner-or-listener"
        );
        _;
    }

    modifier requireAwardNotInProgress() {
        _requireAwardNotInProgress();
        _;
    }

    modifier requireCanStartAward() {
        require(
            _isPrizePeriodOver(),
            "PeriodicPrizeStrategy/prize-period-not-over"
        );
        require(
            !isRngRequested(),
            "PeriodicPrizeStrategy/rng-already-requested"
        );
        _;
    }

    modifier requireCanCompleteAward() {
        require(isRngRequested(), "PeriodicPrizeStrategy/rng-not-requested");
        require(isRngCompleted(), "PeriodicPrizeStrategy/rng-not-complete");
        _;
    }

    modifier onlyPrizePool() {
        require(
            _msgSender() == address(prizePool),
            "PeriodicPrizeStrategy/only-prize-pool"
        );
        _;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/Initializable.sol";
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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
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
    uint256[49] private __gap;
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
library SafeMathUpgradeable {
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


/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCastUpgradeable {

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value < 2**128, "SafeCast: value doesn\'t fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value < 2**64, "SafeCast: value doesn\'t fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value < 2**32, "SafeCast: value doesn\'t fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value < 2**16, "SafeCast: value doesn\'t fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value < 2**8, "SafeCast: value doesn\'t fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128) {
        require(value >= -2**127 && value < 2**127, "SafeCast: value doesn\'t fit in 128 bits");
        return int128(value);
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64) {
        require(value >= -2**63 && value < 2**63, "SafeCast: value doesn\'t fit in 64 bits");
        return int64(value);
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32) {
        require(value >= -2**31 && value < 2**31, "SafeCast: value doesn\'t fit in 32 bits");
        return int32(value);
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16) {
        require(value >= -2**15 && value < 2**15, "SafeCast: value doesn\'t fit in 16 bits");
        return int16(value);
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8) {
        require(value >= -2**7 && value < 2**7, "SafeCast: value doesn\'t fit in 8 bits");
        return int8(value);
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        require(value < 2**255, "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

/**
 * @dev Library used to query support of an interface declared via {IERC165}.
 *
 * Note that these functions return the actual result of the query: they do not
 * `revert` if an interface is not supported. It is up to the caller to decide
 * what to do in these cases.
 */
library ERC165CheckerUpgradeable {
    // As per the EIP-165 spec, no interface should ever match 0xffffffff
    bytes4 private constant _INTERFACE_ID_INVALID = 0xffffffff;

    /*
     * bytes4(keccak256('supportsInterface(bytes4)')) == 0x01ffc9a7
     */
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;

    /**
     * @dev Returns true if `account` supports the {IERC165} interface,
     */
    function supportsERC165(address account) internal view returns (bool) {
        // Any contract that implements ERC165 must explicitly indicate support of
        // InterfaceId_ERC165 and explicitly indicate non-support of InterfaceId_Invalid
        return _supportsERC165Interface(account, _INTERFACE_ID_ERC165) &&
            !_supportsERC165Interface(account, _INTERFACE_ID_INVALID);
    }

    /**
     * @dev Returns true if `account` supports the interface defined by
     * `interfaceId`. Support for {IERC165} itself is queried automatically.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsInterface(address account, bytes4 interfaceId) internal view returns (bool) {
        // query support of both ERC165 as per the spec and support of _interfaceId
        return supportsERC165(account) &&
            _supportsERC165Interface(account, interfaceId);
    }

    /**
     * @dev Returns a boolean array where each value corresponds to the
     * interfaces passed in and whether they're supported or not. This allows
     * you to batch check interfaces for a contract where your expectation
     * is that some interfaces may not be supported.
     *
     * See {IERC165-supportsInterface}.
     *
     * _Available since v3.4._
     */
    function getSupportedInterfaces(address account, bytes4[] memory interfaceIds) internal view returns (bool[] memory) {
        // an array of booleans corresponding to interfaceIds and whether they're supported or not
        bool[] memory interfaceIdsSupported = new bool[](interfaceIds.length);

        // query support of ERC165 itself
        if (supportsERC165(account)) {
            // query support of each interface in interfaceIds
            for (uint256 i = 0; i < interfaceIds.length; i++) {
                interfaceIdsSupported[i] = _supportsERC165Interface(account, interfaceIds[i]);
            }
        }

        return interfaceIdsSupported;
    }

    /**
     * @dev Returns true if `account` supports all the interfaces defined in
     * `interfaceIds`. Support for {IERC165} itself is queried automatically.
     *
     * Batch-querying can lead to gas savings by skipping repeated checks for
     * {IERC165} support.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsAllInterfaces(address account, bytes4[] memory interfaceIds) internal view returns (bool) {
        // query support of ERC165 itself
        if (!supportsERC165(account)) {
            return false;
        }

        // query support of each interface in _interfaceIds
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            if (!_supportsERC165Interface(account, interfaceIds[i])) {
                return false;
            }
        }

        // all interfaces supported
        return true;
    }

    /**
     * @notice Query if a contract implements an interface, does not check ERC165 support
     * @param account The address of the contract to query for support of an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return true if the contract at account indicates support of the interface with
     * identifier interfaceId, false otherwise
     * @dev Assumes that account contains a contract that supports ERC165, otherwise
     * the behavior of this method is undefined. This precondition can be checked
     * with {supportsERC165}.
     * Interface identification is specified in ERC-165.
     */
    function _supportsERC165Interface(address account, bytes4 interfaceId) private view returns (bool) {
        // success determines whether the staticcall succeeded and result determines
        // whether the contract at account indicates support of _interfaceId
        (bool success, bool result) = _callERC165SupportsInterface(account, interfaceId);

        return (success && result);
    }

    /**
     * @notice Calls the function with selector 0x01ffc9a7 (ERC165) and suppresses throw
     * @param account The address of the contract to query for support of an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return success true if the STATICCALL succeeded, false otherwise
     * @return result true if the STATICCALL succeeded and the contract at account
     * indicates support of the interface with identifier interfaceId, false otherwise
     */
    function _callERC165SupportsInterface(address account, bytes4 interfaceId)
        private
        view
        returns (bool, bool)
    {
        bytes memory encodedParams = abi.encodeWithSelector(_INTERFACE_ID_ERC165, interfaceId);
        (bool success, bytes memory result) = account.staticcall{ gas: 30000 }(encodedParams);
        if (result.length < 32) return (false, false);
        return (success, abi.decode(result, (bool)));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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

import "./IERC20Upgradeable.sol";
import "../../math/SafeMathUpgradeable.sol";
import "../../utils/AddressUpgradeable.sol";

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
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    function safeTransfer(IERC20Upgradeable token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20Upgradeable token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
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

pragma solidity >=0.6.2 <0.8.0;

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

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0;

/// @title Random Number Generator Interface
/// @notice Provides an interface for requesting random numbers from 3rd-party RNG services (Chainlink VRF, Starkware VDF, etc..)
interface RNGInterface {

  /// @notice Emitted when a new request for a random number has been submitted
  /// @param requestId The indexed ID of the request used to get the results of the RNG service
  /// @param sender The indexed address of the sender of the request
  event RandomNumberRequested(uint32 indexed requestId, address indexed sender);

  /// @notice Emitted when an existing request for a random number has been completed
  /// @param requestId The indexed ID of the request used to get the results of the RNG service
  /// @param randomNumber The random number produced by the 3rd-party service
  event RandomNumberCompleted(uint32 indexed requestId, uint256 randomNumber);

  /// @notice Gets the last request id used by the RNG service
  /// @return requestId The last request id used in the last request
  function getLastRequestId() external view returns (uint32 requestId);

  /// @notice Gets the Fee for making a Request against an RNG service
  /// @return feeToken The address of the token that is used to pay fees
  /// @return requestFee The fee required to be paid to make a request
  function getRequestFee() external view returns (address feeToken, uint256 requestFee);

  /// @notice Sends a request for a random number to the 3rd-party service
  /// @dev Some services will complete the request immediately, others may have a time-delay
  /// @dev Some services require payment in the form of a token, such as $LINK for Chainlink VRF
  /// @return requestId The ID of the request used to get the results of the RNG service
  /// @return lockBlock The block number at which the RNG service will start generating time-delayed randomness.  The calling contract
  /// should "lock" all activity until the result is available via the `requestId`
  function requestRandomNumber() external returns (uint32 requestId, uint32 lockBlock);

  /// @notice Checks if the request for randomness from the 3rd-party service has completed
  /// @dev For time-delayed requests, this function is used to check/confirm completion
  /// @param requestId The ID of the request used to get the results of the RNG service
  /// @return isCompleted True if the request has completed and a random number is available, false otherwise
  function isRequestComplete(uint32 requestId) external view returns (bool isCompleted);

  /// @notice Gets the random number produced by the 3rd-party service
  /// @param requestId The ID of the request used to get the results of the RNG service
  /// @return randomNum The random number
  function randomNumber(uint32 requestId) external returns (uint256 randomNum);
}

/**
Copyright 2020 PoolTogether Inc.

This file is part of PoolTogether.

PoolTogether is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation under version 3 of the License.

PoolTogether is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with PoolTogether.  If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity >=0.6.0 <0.8.0;

import "./external/openzeppelin/OpenZeppelinSafeMath_V3_3_0.sol";

/**
 * @author Brendan Asselstine
 * @notice Provides basic fixed point math calculations.
 *
 * This library calculates integer fractions by scaling values by 1e18 then performing standard integer math.
 */
library FixedPoint {
    using OpenZeppelinSafeMath_V3_3_0 for uint256;

    // The scale to use for fixed point numbers.  Same as Ether for simplicity.
    uint256 internal constant SCALE = 1e18;

    /**
        * Calculates a Fixed18 mantissa given the numerator and denominator
        *
        * The mantissa = (numerator * 1e18) / denominator
        *
        * @param numerator The mantissa numerator
        * @param denominator The mantissa denominator
        * @return The mantissa of the fraction
        */
    function calculateMantissa(uint256 numerator, uint256 denominator) internal pure returns (uint256) {
        uint256 mantissa = numerator.mul(SCALE);
        mantissa = mantissa.div(denominator);
        return mantissa;
    }

    /**
        * Multiplies a Fixed18 number by an integer.
        *
        * @param b The whole integer to multiply
        * @param mantissa The Fixed18 number
        * @return An integer that is the result of multiplying the params.
        */
    function multiplyUintByMantissa(uint256 b, uint256 mantissa) internal pure returns (uint256) {
        uint256 result = mantissa.mul(b);
        result = result.div(SCALE);
        return result;
    }

    /**
    * Divides an integer by a fixed point 18 mantissa
    *
    * @param dividend The integer to divide
    * @param mantissa The fixed point 18 number to serve as the divisor
    * @return An integer that is the result of dividing an integer by a fixed point 18 mantissa
    */
    function divideUintByMantissa(uint256 dividend, uint256 mantissa) internal pure returns (uint256) {
        uint256 result = SCALE.mul(dividend);
        result = result.div(mantissa);
        return result;
    }
}

pragma solidity ^0.6.4;

import "./TokenListenerInterface.sol";
import "./TokenListenerLibrary.sol";
import "../Constants.sol";

abstract contract TokenListener is TokenListenerInterface {
    function supportsInterface(bytes4 interfaceId)
        external
        view
        override
        returns (bool)
    {
        return (interfaceId == Constants.ERC165_INTERFACE_ID_ERC165 ||
            interfaceId ==
            TokenListenerLibrary.ERC165_INTERFACE_ID_TOKEN_LISTENER);
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.7.0;

/// @title Controlled ERC20 Token Interface
/// @notice Required interface for Controlled ERC20 Tokens linked to a Prize Pool
/// @dev Defines the spec required to be implemented by a Controlled ERC20 Token
interface TokenControllerInterface {
    /// @dev Controller hook to provide notifications & rule validations on token transfers to the controller.
    /// This includes minting and burning.
    /// @param from Address of the account sending the tokens (address(0x0) on minting)
    /// @param to Address of the account receiving the tokens (address(0x0) on burning)
    /// @param amount Amount of tokens being transferred
    function beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) external;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/drafts/ERC20PermitUpgradeable.sol";

import "./TokenControllerInterface.sol";
import "./ControlledTokenInterface.sol";

/// @title Controlled ERC20 Token
/// @notice ERC20 Tokens with a controller for minting & burning
contract ControlledToken is ERC20PermitUpgradeable, ControlledTokenInterface {
    /// @notice Interface to the contract responsible for controlling mint/burn
    TokenControllerInterface public override controller;

    /// @notice Initializes the Controlled Token with Token Details and the Controller
    /// @param _name The name of the Token
    /// @param _symbol The symbol for the Token
    /// @param _decimals The number of decimals for the Token
    /// @param _controller Address of the Controller contract for minting & burning
    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        TokenControllerInterface _controller
    ) public virtual initializer {
        __ERC20_init(_name, _symbol);
        __ERC20Permit_init("MoonPot ControlledToken");
        controller = _controller;
        _setupDecimals(_decimals);
    }

    /// @notice Allows the controller to mint tokens for a user account
    /// @dev May be overridden to provide more granular control over minting
    /// @param _user Address of the receiver of the minted tokens
    /// @param _amount Amount of tokens to mint
    function controllerMint(address _user, uint256 _amount)
        external
        virtual
        override
        onlyController
    {
        _mint(_user, _amount);
    }

    /// @notice Allows the controller to burn tokens from a user account
    /// @dev May be overridden to provide more granular control over burning
    /// @param _user Address of the holder account to burn tokens from
    /// @param _amount Amount of tokens to burn
    function controllerBurn(address _user, uint256 _amount)
        external
        virtual
        override
        onlyController
    {
        _burn(_user, _amount);
    }

    /// @notice Allows an operator via the controller to burn tokens on behalf of a user account
    /// @dev May be overridden to provide more granular control over operator-burning
    /// @param _operator Address of the operator performing the burn action via the controller contract
    /// @param _user Address of the holder account to burn tokens from
    /// @param _amount Amount of tokens to burn
    function controllerBurnFrom(
        address _operator,
        address _user,
        uint256 _amount
    ) external virtual override onlyController {
        if (_operator != _user) {
            uint256 decreasedAllowance = allowance(_user, _operator).sub(
                _amount,
                "ControlledToken/exceeds-allowance"
            );
            _approve(_user, _operator, decreasedAllowance);
        }
        _burn(_user, _amount);
    }

    /// @dev Function modifier to ensure that the caller is the controller contract
    modifier onlyController() {
        require(
            _msgSender() == address(controller),
            "ControlledToken/only-controller"
        );
        _;
    }

    /// @dev Controller hook to provide notifications & rule validations on token transfers to the controller.
    /// This includes minting and burning.
    /// May be overridden to provide more granular control over operator-burning
    /// @param from Address of the account sending the tokens (address(0x0) on minting)
    /// @param to Address of the account receiving the tokens (address(0x0) on burning)
    /// @param amount Amount of tokens being transferred
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        controller.beforeTokenTransfer(from, to, amount);
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.7.0;

/// @title Interface that allows a user to draw an address using an index
interface TicketInterface {
    /// @notice Selects a user using a random number.  The random number will be uniformly bounded to the ticket totalSupply.
    /// @param randomNumber The random number to use to select a user.
    /// @return The winner
    function draw(uint256 randomNumber) external view returns (address);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/introspection/ERC165CheckerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@pooltogether/fixed-point/contracts/FixedPoint.sol";

import "../external/compound/ICompLike.sol";
import "../registry/RegistryInterface.sol";
import "../reserve/ReserveInterface.sol";
import "../token/TokenListenerInterface.sol";
import "../token/TokenListenerLibrary.sol";
import "../token/ControlledToken.sol";
import "../token/TokenControllerInterface.sol";
import "../utils/MappedSinglyLinkedList.sol";
import "./PrizePoolInterface.sol";

/// @title Escrows assets and deposits them into a yield source.  Exposes interest to Prize Strategy.  Users deposit and withdraw from this contract to participate in Prize Pool.
/// @notice Accounting is managed using Controlled Tokens, whose mint and burn functions can only be called by this contract.
/// @dev Must be inherited to provide specific yield-bearing asset control, such as Compound cTokens
abstract contract PrizePool is
    PrizePoolInterface,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    TokenControllerInterface,
    IERC721ReceiverUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MappedSinglyLinkedList for MappedSinglyLinkedList.Mapping;
    using ERC165CheckerUpgradeable for address;

    /// @dev Emitted when an instance is initialized
    event Initialized(
        address reserveRegistry,
        uint256 maxExitFeeMantissa,
        address gateManager
    );

    /// @dev Event emitted when controlled token is added
    event ControlledTokenAdded(ControlledTokenInterface indexed token);

    /// @dev Emitted when reserve is captured.
    event ReserveFeeCaptured(uint256 amount);

    event AwardCaptured(uint256 amount);

    /// @dev Event emitted when assets are deposited
    event Deposited(
        address indexed operator,
        address indexed to,
        address indexed token,
        uint256 amount,
        address referrer
    );

    /// @dev Event emitted when interest is awarded to a winner
    event Awarded(
        address indexed winner,
        address indexed token,
        uint256 amount
    );

    /// @dev Event emitted when external ERC20s are awarded to a winner
    event AwardedExternalERC20(
        address indexed winner,
        address indexed token,
        uint256 amount
    );

    /// @dev Event emitted when external ERC20s are transferred out
    event TransferredExternalERC20(
        address indexed to,
        address indexed token,
        uint256 amount
    );

    /// @dev Event emitted when external ERC721s are awarded to a winner
    event AwardedExternalERC721(
        address indexed winner,
        address indexed token,
        uint256[] tokenIds
    );

    /// @dev Event emitted when assets are withdrawn instantly
    event InstantWithdrawal(
        address indexed operator,
        address indexed from,
        address indexed token,
        uint256 amount,
        uint256 redeemed,
        uint256 exitFee
    );

    event ReserveWithdrawal(address indexed to, uint256 amount);

    /// @dev Event emitted when the Liquidity Cap is set
    event LiquidityCapSet(uint256 liquidityCap);

    /// @dev Event emitted when the Credit plan is set
    event CreditPlanSet(
        address token,
        uint128 creditLimitMantissa,
        uint128 creditRateMantissa
    );

    /// @dev Event emitted when the Prize Strategy is set
    event PrizeStrategySet(address indexed prizeStrategy);

    /// @dev Emitted when credit is minted
    event CreditMinted(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    /// @dev Emitted when credit is burned
    event CreditBurned(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    /// @dev Emitted when there was an error thrown awarding an External ERC721
    event ErrorAwardingExternalERC721(bytes error);

    struct CreditPlan {
        uint128 creditLimitMantissa;
        uint128 creditRateMantissa;
    }

    struct CreditBalance {
        uint192 balance;
        uint32 timestamp;
        bool initialized;
    }

    /// @dev Reserve to which reserve fees are sent
    RegistryInterface public reserveRegistry;

    /// @dev A linked list of all the controlled tokens
    MappedSinglyLinkedList.Mapping internal _tokens;

    /// @dev The Prize Strategy that this Prize Pool is bound to.
    TokenListenerInterface public prizeStrategy;

    /// Gate Manager
    address public gateManager;

    /// @dev The maximum possible exit fee fraction as a fixed point 18 number.
    /// For example, if the maxExitFeeMantissa is "0.1 ether", then the maximum exit fee for a withdrawal of 100 Dai will be 10 Dai
    uint256 public maxExitFeeMantissa;

    /// @dev The total funds that have been allocated to the reserve
    uint256 public reserveTotalSupply;

    /// @dev The total amount of funds that the prize pool can hold.
    uint256 public liquidityCap;

    /// @dev the The awardable balance
    uint256 internal _currentAwardBalance;

    /// @dev Stores the credit plan for each token.
    mapping(address => CreditPlan) internal _tokenCreditPlans;

    /// @dev Stores each users balance of credit per token.
    mapping(address => mapping(address => CreditBalance))
        internal _tokenCreditBalances;

    /// @notice Initializes the Prize Pool
    /// @param _controlledTokens Array of ControlledTokens that are controlled by this Prize Pool.
    /// @param _maxExitFeeMantissa The maximum exit fee size
    function initialize(
        RegistryInterface _reserveRegistry,
        ControlledTokenInterface[] memory _controlledTokens,
        uint256 _maxExitFeeMantissa,
        address _gateManager
    ) public initializer {
        require(
            address(_reserveRegistry) != address(0),
            "PrizePool/reserveRegistry-not-zero"
        );
        _tokens.initialize();
        for (uint256 i = 0; i < _controlledTokens.length; i++) {
            _addControlledToken(_controlledTokens[i]);
        }
        __Ownable_init();
        __ReentrancyGuard_init();
        _setLiquidityCap(uint256(-1));

        reserveRegistry = _reserveRegistry;
        maxExitFeeMantissa = _maxExitFeeMantissa;
        gateManager = _gateManager;

        emit Initialized(
            address(_reserveRegistry),
            maxExitFeeMantissa,
            gateManager
        );
    }

    /// @dev Returns the address of the underlying ERC20 asset
    /// @return The address of the asset
    function token() external view override returns (address) {
        return address(_token());
    }

    /// @dev Returns the total underlying balance of all assets. This includes both principal and interest.
    /// @return The underlying balance of assets
    function balance() external returns (uint256) {
        return _balance();
    }

    /// @dev Checks with the Prize Pool if a specific token type may be awarded as an external prize
    /// @param _externalToken The address of the token to check
    /// @return True if the token may be awarded, false otherwise
    function canAwardExternal(address _externalToken)
        external
        view
        returns (bool)
    {
        return _canAwardExternal(_externalToken);
    }

    /// @notice Deposit assets into the Prize Pool in exchange for tokens
    /// @param to The address receiving the newly minted tokens
    /// @param amount The amount of assets to deposit
    /// @param controlledToken The address of the type of token the user is minting
    /// @param referrer The referrer of the deposit
    function depositTo(
        address to,
        uint256 amount,
        address controlledToken,
        address referrer
    )
        external
        override
        onlyControlledToken(controlledToken)
        canAddLiquidity(amount)
        nonReentrant
    {
        if (gateManager != address(0)) {
            require(msg.sender == gateManager, "Gate Manager must deposit");
        }

        address operator = _msgSender();

        _mint(to, amount, controlledToken, referrer);

        _token().safeTransferFrom(operator, address(this), amount);
        _supply(amount);

        emit Deposited(operator, to, controlledToken, amount, referrer);
    }

    /// @notice Withdraw assets from the Prize Pool instantly.  A fairness fee may be charged for an early exit.
    /// @param from The address to redeem tokens from.
    /// @param amount The amount of tokens to redeem for assets.
    /// @param controlledToken The address of the token to redeem (i.e. ticket or sponsorship)
    /// @param maximumExitFee The maximum exit fee the caller is willing to pay.  This should be pre-calculated by the calculateExitFee() fxn.
    /// @return The actual exit fee paid
    function withdrawInstantlyFrom(
        address from,
        uint256 amount,
        address controlledToken,
        uint256 maximumExitFee
    )
        external
        override
        nonReentrant
        onlyControlledToken(controlledToken)
        returns (uint256)
    {
        (
            uint256 exitFee,
            uint256 burnedCredit
        ) = _calculateEarlyExitFeeLessBurnedCredit(
                from,
                controlledToken,
                amount
            );
        require(
            exitFee <= maximumExitFee,
            "PrizePool/exit-fee-exceeds-user-maximum"
        );

        // burn the credit
        _burnCredit(from, controlledToken, burnedCredit);

        // burn the tickets
        ControlledToken(controlledToken).controllerBurnFrom(
            _msgSender(),
            from,
            amount
        );

        // redeem the tickets less the fee
        uint256 amountLessFee = amount.sub(exitFee);
        uint256 redeemed = _redeem(amountLessFee);

        _token().safeTransfer(from, redeemed);

        emit InstantWithdrawal(
            _msgSender(),
            from,
            controlledToken,
            amount,
            redeemed,
            exitFee
        );

        return exitFee;
    }

    /// @notice Limits the exit fee to the maximum as hard-coded into the contract
    /// @param withdrawalAmount The amount that is attempting to be withdrawn
    /// @param exitFee The exit fee to check against the limit
    /// @return The passed exit fee if it is less than the maximum, otherwise the maximum fee is returned.
    function _limitExitFee(uint256 withdrawalAmount, uint256 exitFee)
        internal
        view
        returns (uint256)
    {
        uint256 maxFee = FixedPoint.multiplyUintByMantissa(
            withdrawalAmount,
            maxExitFeeMantissa
        );
        if (exitFee > maxFee) {
            exitFee = maxFee;
        }
        return exitFee;
    }

    /// @notice Updates the Prize Strategy when tokens are transferred between holders.
    /// @param from The address the tokens are being transferred from (0 if minting)
    /// @param to The address the tokens are being transferred to (0 if burning)
    /// @param amount The amount of tokens being trasferred
    function beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) external override onlyControlledToken(msg.sender) {
        if (from != address(0)) {
            uint256 fromBeforeBalance = IERC20Upgradeable(msg.sender).balanceOf(
                from
            );
            // first accrue credit for their old balance
            uint256 newCreditBalance = _calculateCreditBalance(
                from,
                msg.sender,
                fromBeforeBalance,
                0
            );

            if (from != to) {
                // if they are sending funds to someone else, we need to limit their accrued credit to their new balance
                newCreditBalance = _applyCreditLimit(
                    msg.sender,
                    fromBeforeBalance.sub(amount),
                    newCreditBalance
                );
            }

            _updateCreditBalance(from, msg.sender, newCreditBalance);
        }
        if (to != address(0) && to != from) {
            _accrueCredit(
                to,
                msg.sender,
                IERC20Upgradeable(msg.sender).balanceOf(to),
                0
            );
        }
        // if we aren't minting
        if (from != address(0) && address(prizeStrategy) != address(0)) {
            prizeStrategy.beforeTokenTransfer(from, to, amount, msg.sender);
        }
    }

    /// @notice Returns the balance that is available to award.
    /// @dev captureAwardBalance() should be called first
    /// @return The total amount of assets to be awarded for the current prize
    function awardBalance() external view override returns (uint256) {
        return _currentAwardBalance;
    }

    /// @notice Captures any available interest as award balance.
    /// @dev This function also captures the reserve fees.
    /// @return The total amount of assets to be awarded for the current prize
    function captureAwardBalance()
        external
        override
        nonReentrant
        returns (uint256)
    {
        uint256 tokenTotalSupply = _tokenTotalSupply();

        // it's possible for the balance to be slightly less due to rounding errors in the underlying yield source
        uint256 currentBalance = _balance();
        uint256 totalInterest = (currentBalance > tokenTotalSupply)
            ? currentBalance.sub(tokenTotalSupply)
            : 0;
        uint256 unaccountedPrizeBalance = (totalInterest > _currentAwardBalance)
            ? totalInterest.sub(_currentAwardBalance)
            : 0;

        if (unaccountedPrizeBalance > 0) {
            // uint256 reserveFee = calculateReserveFee(unaccountedPrizeBalance);
            // if (reserveFee > 0) {
            //     reserveTotalSupply = reserveTotalSupply.add(reserveFee);
            //     unaccountedPrizeBalance = unaccountedPrizeBalance.sub(
            //         reserveFee
            //     );
            //     emit ReserveFeeCaptured(reserveFee);
            // }
            _currentAwardBalance = _currentAwardBalance.add(
                unaccountedPrizeBalance
            );

            emit AwardCaptured(unaccountedPrizeBalance);
        }

        return _currentAwardBalance;
    }

    function withdrawReserve(address to)
        external
        override
        onlyReserve
        returns (uint256)
    {
        uint256 amount = reserveTotalSupply;
        reserveTotalSupply = 0;
        uint256 redeemed = _redeem(amount);

        _token().safeTransfer(address(to), redeemed);

        emit ReserveWithdrawal(to, amount);

        return redeemed;
    }

    /// @notice Called by the prize strategy to award prizes.
    /// @dev The amount awarded must be less than the awardBalance()
    /// @param to The address of the winner that receives the award
    /// @param amount The amount of assets to be awarded
    /// @param controlledToken The address of the asset token being awarded
    function award(
        address to,
        uint256 amount,
        address controlledToken
    ) external override onlyPrizeStrategy onlyControlledToken(controlledToken) {
        if (amount == 0) {
            return;
        }

        require(
            amount <= _currentAwardBalance,
            "PrizePool/award-exceeds-avail"
        );
        _currentAwardBalance = _currentAwardBalance.sub(amount);

        _mint(to, amount, controlledToken, address(0));

        uint256 extraCredit = _calculateEarlyExitFeeNoCredit(
            controlledToken,
            amount
        );
        _accrueCredit(
            to,
            controlledToken,
            IERC20Upgradeable(controlledToken).balanceOf(to),
            extraCredit
        );

        emit Awarded(to, controlledToken, amount);
    }

    /// @notice Called by the Prize-Strategy to transfer out external ERC20 tokens
    /// @dev Used to transfer out tokens held by the Prize Pool.  Could be liquidated, or anything.
    /// @param to The address of the winner that receives the award
    /// @param amount The amount of external assets to be awarded
    /// @param externalToken The address of the external asset token being awarded
    function transferExternalERC20(
        address to,
        address externalToken,
        uint256 amount
    ) external override onlyPrizeStrategy {
        if (_transferOut(to, externalToken, amount)) {
            emit TransferredExternalERC20(to, externalToken, amount);
        }
    }

    /// @notice Called by the Prize-Strategy to award external ERC20 prizes
    /// @dev Used to award any arbitrary tokens held by the Prize Pool
    /// @param to The address of the winner that receives the award
    /// @param amount The amount of external assets to be awarded
    /// @param externalToken The address of the external asset token being awarded
    function awardExternalERC20(
        address to,
        address externalToken,
        uint256 amount
    ) external override onlyPrizeStrategy {
        if (_transferOut(to, externalToken, amount)) {
            emit AwardedExternalERC20(to, externalToken, amount);
        }
    }

    function _transferOut(
        address to,
        address externalToken,
        uint256 amount
    ) internal returns (bool) {
        require(
            _canAwardExternal(externalToken),
            "PrizePool/invalid-external-token"
        );

        if (amount == 0) {
            return false;
        }

        IERC20Upgradeable(externalToken).safeTransfer(to, amount);

        return true;
    }

    /// @notice Called to mint controlled tokens.  Ensures that token listener callbacks are fired.
    /// @param to The user who is receiving the tokens
    /// @param amount The amount of tokens they are receiving
    /// @param controlledToken The token that is going to be minted
    /// @param referrer The user who referred the minting
    function _mint(
        address to,
        uint256 amount,
        address controlledToken,
        address referrer
    ) internal {
        if (address(prizeStrategy) != address(0)) {
            prizeStrategy.beforeTokenMint(
                to,
                amount,
                controlledToken,
                referrer
            );
        }
        ControlledToken(controlledToken).controllerMint(to, amount);
    }

    /// @notice Called by the prize strategy to award external ERC721 prizes
    /// @dev Used to award any arbitrary NFTs held by the Prize Pool
    /// @param to The address of the winner that receives the award
    /// @param externalToken The address of the external NFT token being awarded
    /// @param tokenIds An array of NFT Token IDs to be transferred
    function awardExternalERC721(
        address to,
        address externalToken,
        uint256[] calldata tokenIds
    ) external override onlyPrizeStrategy {
        require(
            _canAwardExternal(externalToken),
            "PrizePool/invalid-external-token"
        );

        if (tokenIds.length == 0) {
            return;
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            try
                IERC721Upgradeable(externalToken).safeTransferFrom(
                    address(this),
                    to,
                    tokenIds[i]
                )
            {} catch (bytes memory error) {
                emit ErrorAwardingExternalERC721(error);
            }
        }

        emit AwardedExternalERC721(to, externalToken, tokenIds);
    }

    /// @notice Calculates the reserve portion of the given amount of funds.  If there is no reserve address, the portion will be zero.
    /// @param amount The prize amount
    /// @return The size of the reserve portion of the prize
    function calculateReserveFee(uint256 amount) public view returns (uint256) {
        ReserveInterface reserve = ReserveInterface(reserveRegistry.lookup());
        if (address(reserve) == address(0)) {
            return 0;
        }
        uint256 reserveRateMantissa = reserve.reserveRateMantissa(
            address(this)
        );
        if (reserveRateMantissa == 0) {
            return 0;
        }
        return FixedPoint.multiplyUintByMantissa(amount, reserveRateMantissa);
    }

    /// @notice Calculates the early exit fee for the given amount
    /// @param from The user who is withdrawing
    /// @param controlledToken The type of collateral being withdrawn
    /// @param amount The amount of collateral to be withdrawn
    /// @return exitFee The exit fee
    /// @return burnedCredit The user's credit that was burned
    function calculateEarlyExitFee(
        address from,
        address controlledToken,
        uint256 amount
    ) external override returns (uint256 exitFee, uint256 burnedCredit) {
        return
            _calculateEarlyExitFeeLessBurnedCredit(
                from,
                controlledToken,
                amount
            );
    }

    /// @dev Calculates the early exit fee for the given amount
    /// @param amount The amount of collateral to be withdrawn
    /// @return Exit fee
    function _calculateEarlyExitFeeNoCredit(
        address controlledToken,
        uint256 amount
    ) internal view returns (uint256) {
        return
            _limitExitFee(
                amount,
                FixedPoint.multiplyUintByMantissa(
                    amount,
                    _tokenCreditPlans[controlledToken].creditLimitMantissa
                )
            );
    }

    /// @notice Estimates the amount of time it will take for a given amount of funds to accrue the given amount of credit.
    /// @param _principal The principal amount on which interest is accruing
    /// @param _interest The amount of interest that must accrue
    /// @return durationSeconds The duration of time it will take to accrue the given amount of interest, in seconds.
    function estimateCreditAccrualTime(
        address _controlledToken,
        uint256 _principal,
        uint256 _interest
    ) external view override returns (uint256 durationSeconds) {
        return
            _estimateCreditAccrualTime(_controlledToken, _principal, _interest);
    }

    /// @notice Estimates the amount of time it will take for a given amount of funds to accrue the given amount of credit
    /// @param _principal The principal amount on which interest is accruing
    /// @param _interest The amount of interest that must accrue
    /// @return durationSeconds The duration of time it will take to accrue the given amount of interest, in seconds.
    function _estimateCreditAccrualTime(
        address _controlledToken,
        uint256 _principal,
        uint256 _interest
    ) internal view returns (uint256 durationSeconds) {
        // interest = credit rate * principal * time
        // => time = interest / (credit rate * principal)
        uint256 accruedPerSecond = FixedPoint.multiplyUintByMantissa(
            _principal,
            _tokenCreditPlans[_controlledToken].creditRateMantissa
        );
        if (accruedPerSecond == 0) {
            return 0;
        }
        return _interest.div(accruedPerSecond);
    }

    /// @notice Burns a users credit.
    /// @param user The user whose credit should be burned
    /// @param credit The amount of credit to burn
    function _burnCredit(
        address user,
        address controlledToken,
        uint256 credit
    ) internal {
        _tokenCreditBalances[controlledToken][user].balance = uint256(
            _tokenCreditBalances[controlledToken][user].balance
        ).sub(credit).toUint128();

        emit CreditBurned(user, controlledToken, credit);
    }

    /// @notice Accrues ticket credit for a user assuming their current balance is the passed balance.  May burn credit if they exceed their limit.
    /// @param user The user for whom to accrue credit
    /// @param controlledToken The controlled token whose balance we are checking
    /// @param controlledTokenBalance The balance to use for the user
    /// @param extra Additional credit to be added
    function _accrueCredit(
        address user,
        address controlledToken,
        uint256 controlledTokenBalance,
        uint256 extra
    ) internal {
        _updateCreditBalance(
            user,
            controlledToken,
            _calculateCreditBalance(
                user,
                controlledToken,
                controlledTokenBalance,
                extra
            )
        );
    }

    function _calculateCreditBalance(
        address user,
        address controlledToken,
        uint256 controlledTokenBalance,
        uint256 extra
    ) internal view returns (uint256) {
        uint256 newBalance;
        CreditBalance storage creditBalance = _tokenCreditBalances[
            controlledToken
        ][user];
        if (!creditBalance.initialized) {
            newBalance = 0;
        } else {
            uint256 credit = _calculateAccruedCredit(
                user,
                controlledToken,
                controlledTokenBalance
            );
            newBalance = _applyCreditLimit(
                controlledToken,
                controlledTokenBalance,
                uint256(creditBalance.balance).add(credit).add(extra)
            );
        }
        return newBalance;
    }

    function _updateCreditBalance(
        address user,
        address controlledToken,
        uint256 newBalance
    ) internal {
        uint256 oldBalance = _tokenCreditBalances[controlledToken][user]
            .balance;

        _tokenCreditBalances[controlledToken][user] = CreditBalance({
            balance: newBalance.toUint128(),
            timestamp: _currentTime().toUint32(),
            initialized: true
        });

        if (oldBalance < newBalance) {
            emit CreditMinted(
                user,
                controlledToken,
                newBalance.sub(oldBalance)
            );
        } else {
            emit CreditBurned(
                user,
                controlledToken,
                oldBalance.sub(newBalance)
            );
        }
    }

    /// @notice Applies the credit limit to a credit balance.  The balance cannot exceed the credit limit.
    /// @param controlledToken The controlled token that the user holds
    /// @param controlledTokenBalance The users ticket balance (used to calculate credit limit)
    /// @param creditBalance The new credit balance to be checked
    /// @return The users new credit balance.  Will not exceed the credit limit.
    function _applyCreditLimit(
        address controlledToken,
        uint256 controlledTokenBalance,
        uint256 creditBalance
    ) internal view returns (uint256) {
        uint256 creditLimit = FixedPoint.multiplyUintByMantissa(
            controlledTokenBalance,
            _tokenCreditPlans[controlledToken].creditLimitMantissa
        );
        if (creditBalance > creditLimit) {
            creditBalance = creditLimit;
        }

        return creditBalance;
    }

    /// @notice Calculates the accrued interest for a user
    /// @param user The user whose credit should be calculated.
    /// @param controlledToken The controlled token that the user holds
    /// @param controlledTokenBalance The user's current balance of the controlled tokens.
    /// @return The credit that has accrued since the last credit update.
    function _calculateAccruedCredit(
        address user,
        address controlledToken,
        uint256 controlledTokenBalance
    ) internal view returns (uint256) {
        uint256 userTimestamp = _tokenCreditBalances[controlledToken][user]
            .timestamp;

        if (!_tokenCreditBalances[controlledToken][user].initialized) {
            return 0;
        }

        uint256 deltaTime = _currentTime().sub(userTimestamp);
        uint256 creditPerSecond = FixedPoint.multiplyUintByMantissa(
            controlledTokenBalance,
            _tokenCreditPlans[controlledToken].creditRateMantissa
        );
        return deltaTime.mul(creditPerSecond);
    }

    /// @notice Returns the seconds remaining for fairplay timelock for a given user.  Note that this includes both minted credit and pending credit.
    /// @param user The user whose credit balance should be returned
    /// @return The balance of the seconds remaining
    function userFairPlayLockRemaining(address user, address controlledToken)
        external
        view
        returns (uint256)
    {
        uint256 controlledTokenBalance = IERC20Upgradeable(controlledToken)
            .balanceOf(user);

        uint256 accruedCredit = _calculateAccruedCredit(
            user,
            controlledToken,
            controlledTokenBalance
        );

        uint256 currentCredit = _tokenCreditBalances[controlledToken][user]
            .balance;
        uint256 userCredit = currentCredit.add(accruedCredit);
        (uint256 limitMantissa, uint256 rateMantissa) = creditPlanOf(
            controlledToken
        );

        uint256 userLimitBalance = FixedPoint.multiplyUintByMantissa(
            controlledTokenBalance,
            limitMantissa
        );

        uint256 fairplayRemaining;
        if (userLimitBalance > userCredit) {
            uint256 creditLeftToAccrue = userLimitBalance.sub(userCredit);

            uint256 userCreditRate = FixedPoint.multiplyUintByMantissa(
                controlledTokenBalance,
                rateMantissa
            );

            fairplayRemaining = creditLeftToAccrue.div(userCreditRate);
        } else {
            fairplayRemaining = 0;
        }

        return fairplayRemaining;
    }

    /// @notice Returns the credit balance for a given user.  Note that this includes both minted credit and pending credit.
    /// @param user The user whose credit balance should be returned
    /// @return The balance of the users credit
    function balanceOfCredit(address user, address controlledToken)
        external
        override
        onlyControlledToken(controlledToken)
        returns (uint256)
    {
        _accrueCredit(
            user,
            controlledToken,
            IERC20Upgradeable(controlledToken).balanceOf(user),
            0
        );
        return _tokenCreditBalances[controlledToken][user].balance;
    }

    /// @notice Sets the rate at which credit accrues per second.  The credit rate is a fixed point 18 number (like Ether).
    /// @param _controlledToken The controlled token for whom to set the credit plan
    /// @param _creditRateMantissa The credit rate to set.  Is a fixed point 18 decimal (like Ether).
    /// @param _creditLimitMantissa The credit limit to set.  Is a fixed point 18 decimal (like Ether).
    function setCreditPlanOf(
        address _controlledToken,
        uint128 _creditRateMantissa,
        uint128 _creditLimitMantissa
    ) external override onlyControlledToken(_controlledToken) onlyOwner {
        _tokenCreditPlans[_controlledToken] = CreditPlan({
            creditLimitMantissa: _creditLimitMantissa,
            creditRateMantissa: _creditRateMantissa
        });

        emit CreditPlanSet(
            _controlledToken,
            _creditLimitMantissa,
            _creditRateMantissa
        );
    }

    /// @notice Returns the credit rate of a controlled token
    /// @param controlledToken The controlled token to retrieve the credit rates for
    /// @return creditLimitMantissa The credit limit fraction.  This number is used to calculate both the credit limit and early exit fee.
    /// @return creditRateMantissa The credit rate. This is the amount of tokens that accrue per second.
    function creditPlanOf(address controlledToken)
        public
        view
        override
        returns (uint128 creditLimitMantissa, uint128 creditRateMantissa)
    {
        creditLimitMantissa = _tokenCreditPlans[controlledToken]
            .creditLimitMantissa;
        creditRateMantissa = _tokenCreditPlans[controlledToken]
            .creditRateMantissa;
    }

    /// @notice Calculate the early exit for a user given a withdrawal amount.  The user's credit is taken into account.
    /// @param from The user who is withdrawing
    /// @param controlledToken The token they are withdrawing
    /// @param amount The amount of funds they are withdrawing
    /// @return earlyExitFee The additional exit fee that should be charged.
    /// @return creditBurned The amount of credit that will be burned
    function _calculateEarlyExitFeeLessBurnedCredit(
        address from,
        address controlledToken,
        uint256 amount
    ) internal returns (uint256 earlyExitFee, uint256 creditBurned) {
        uint256 controlledTokenBalance = IERC20Upgradeable(controlledToken)
            .balanceOf(from);
        require(controlledTokenBalance >= amount, "PrizePool/insuff-funds");
        _accrueCredit(from, controlledToken, controlledTokenBalance, 0);
        /*
    The credit is used *last*.  Always charge the fees up-front.

    How to calculate:

    Calculate their remaining exit fee.  I.e. full exit fee of their balance less their credit.

    If the exit fee on their withdrawal is greater than the remaining exit fee, then they'll have to pay the difference.
    */

        // Determine available usable credit based on withdraw amount
        uint256 remainingExitFee = _calculateEarlyExitFeeNoCredit(
            controlledToken,
            controlledTokenBalance.sub(amount)
        );

        uint256 availableCredit;
        if (
            _tokenCreditBalances[controlledToken][from].balance >=
            remainingExitFee
        ) {
            availableCredit = uint256(
                _tokenCreditBalances[controlledToken][from].balance
            ).sub(remainingExitFee);
        }

        // Determine amount of credit to burn and amount of fees required
        uint256 totalExitFee = _calculateEarlyExitFeeNoCredit(
            controlledToken,
            amount
        );
        creditBurned = (availableCredit > totalExitFee)
            ? totalExitFee
            : availableCredit;
        earlyExitFee = totalExitFee.sub(creditBurned);
        return (earlyExitFee, creditBurned);
    }

    /// @notice Allows the Governor to set a cap on the amount of liquidity that he pool can hold
    /// @param _liquidityCap The new liquidity cap for the prize pool
    function setLiquidityCap(uint256 _liquidityCap)
        external
        override
        onlyOwner
    {
        _setLiquidityCap(_liquidityCap);
    }

    function _setLiquidityCap(uint256 _liquidityCap) internal {
        liquidityCap = _liquidityCap;
        emit LiquidityCapSet(_liquidityCap);
    }

    /// @notice Adds a new controlled token
    /// @param _controlledToken The controlled token to add.  Cannot be a duplicate.
    function _addControlledToken(ControlledTokenInterface _controlledToken)
        internal
    {
        require(
            _controlledToken.controller() == this,
            "PrizePool/token-ctrlr-mismatch"
        );
        _tokens.addAddress(address(_controlledToken));

        emit ControlledTokenAdded(_controlledToken);
    }

    /// @notice Sets the prize strategy of the prize pool.  Only callable by the owner.
    /// @param _prizeStrategy The new prize strategy
    function setPrizeStrategy(TokenListenerInterface _prizeStrategy)
        external
        override
        onlyOwner
    {
        _setPrizeStrategy(_prizeStrategy);
    }

    /// @notice Sets the prize strategy of the prize pool.  Only callable by the owner.
    /// @param _prizeStrategy The new prize strategy
    function _setPrizeStrategy(TokenListenerInterface _prizeStrategy) internal {
        require(
            address(_prizeStrategy) != address(0),
            "PrizePool/prizeStrategy-not-zero"
        );
        require(
            address(_prizeStrategy).supportsInterface(
                TokenListenerLibrary.ERC165_INTERFACE_ID_TOKEN_LISTENER
            ),
            "PrizePool/prizeStrategy-invalid"
        );
        prizeStrategy = _prizeStrategy;

        emit PrizeStrategySet(address(_prizeStrategy));
    }

    /// @notice An array of the Tokens controlled by the Prize Pool (ie. Tickets, Sponsorship)
    /// @return An array of controlled token addresses
    function tokens() external view override returns (address[] memory) {
        return _tokens.addressArray();
    }

    /// @dev Gets the current time as represented by the current block
    /// @return The timestamp of the current block
    function _currentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    /// @notice The total of all controlled tokens and timelock.
    /// @return The current total of all tokens and timelock.
    function accountedBalance() external view override returns (uint256) {
        return _tokenTotalSupply();
    }

    /// @notice Delegate the votes for a Compound COMP-like token held by the prize pool
    /// @param compLike The COMP-like token held by the prize pool that should be delegated
    /// @param to The address to delegate to
    function compLikeDelegate(ICompLike compLike, address to)
        external
        onlyOwner
    {
        if (compLike.balanceOf(address(this)) > 0) {
            compLike.delegate(to);
        }
    }

    /// @notice Required for ERC721 safe token transfers from smart contracts.
    /// @param operator The address that acts on behalf of the owner
    /// @param from The current owner of the NFT
    /// @param tokenId The NFT to transfer
    /// @param data Additional data with no specified format, sent in call to `_to`.
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return IERC721ReceiverUpgradeable.onERC721Received.selector;
    }

    function transferExternalERC721(
        address to,
        address externalToken,
        uint256[] calldata tokenIds
    ) external onlyPrizeStrategy {
        require(
            _canAwardExternal(externalToken),
            "PrizePool/invalid-external-token"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            IERC721Upgradeable(externalToken).transferFrom(
                address(this),
                to,
                tokenIds[i]
            );
        }
    }

    /// @notice The total of all controlled tokens.
    /// @return The current total of all tokens.
    function _tokenTotalSupply() internal view returns (uint256) {
        uint256 total = reserveTotalSupply;
        address currentToken = _tokens.start();
        while (currentToken != address(0) && currentToken != _tokens.end()) {
            total = total.add(IERC20Upgradeable(currentToken).totalSupply());
            currentToken = _tokens.next(currentToken);
        }
        return total;
    }

    /// @dev Checks if the Prize Pool can receive liquidity based on the current cap
    /// @param _amount The amount of liquidity to be added to the Prize Pool
    /// @return True if the Prize Pool can receive the specified amount of liquidity
    function _canAddLiquidity(uint256 _amount) internal view returns (bool) {
        uint256 tokenTotalSupply = _tokenTotalSupply();
        return (tokenTotalSupply.add(_amount) <= liquidityCap);
    }

    /// @dev Checks if a specific token is controlled by the Prize Pool
    /// @param controlledToken The address of the token to check
    /// @return True if the token is a controlled token, false otherwise
    function _isControlled(address controlledToken)
        internal
        view
        returns (bool)
    {
        return _tokens.contains(controlledToken);
    }

    /// @notice Determines whether the passed token can be transferred out as an external award.
    /// @dev Different yield sources will hold the deposits as another kind of token: such a Compound's cToken.  The
    /// prize strategy should not be allowed to move those tokens.
    /// @param _externalToken The address of the token to check
    /// @return True if the token may be awarded, false otherwise
    function _canAwardExternal(address _externalToken)
        internal
        view
        virtual
        returns (bool);

    /// @notice Returns the ERC20 asset token used for deposits.
    /// @return The ERC20 asset token
    function _token() internal view virtual returns (IERC20Upgradeable);

    /// @notice Returns the total balance (in asset tokens).  This includes the deposits and interest.
    /// @return The underlying balance of asset tokens
    function _balance() internal virtual returns (uint256);

    /// @notice Supplies asset tokens to the yield source.
    /// @param mintAmount The amount of asset tokens to be supplied
    function _supply(uint256 mintAmount) internal virtual;

    /// @notice Redeems asset tokens from the yield source.
    /// @param redeemAmount The amount of yield-bearing tokens to be redeemed
    /// @return The actual amount of tokens that were redeemed.
    function _redeem(uint256 redeemAmount) internal virtual returns (uint256);

    /// @dev Function modifier to ensure usage of tokens controlled by the Prize Pool
    /// @param controlledToken The address of the token to check
    modifier onlyControlledToken(address controlledToken) {
        require(_isControlled(controlledToken), "PrizePool/unknown-token");
        _;
    }

    /// @dev Function modifier to ensure caller is the prize-strategy
    modifier onlyPrizeStrategy() {
        require(
            _msgSender() == address(prizeStrategy),
            "PrizePool/only-prizeStrategy"
        );
        _;
    }

    /// @dev Function modifier to ensure the deposit amount does not exceed the liquidity cap (if set)
    modifier canAddLiquidity(uint256 _amount) {
        require(_canAddLiquidity(_amount), "PrizePool/exceeds-liquidity-cap");
        _;
    }

    modifier onlyReserve() {
        ReserveInterface reserve = ReserveInterface(reserveRegistry.lookup());
        require(address(reserve) == msg.sender, "PrizePool/only-reserve");
        _;
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

library UInt256Array {
  function remove(uint256[] storage self, uint256 index) internal {
    require(index < self.length, "UInt256Array/unknown-index");
    self[index] = self[self.length-1];
    delete self[self.length-1];
    self.pop();
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "./BeforeAwardListenerInterface.sol";
import "../Constants.sol";
import "./BeforeAwardListenerLibrary.sol";

abstract contract BeforeAwardListener is BeforeAwardListenerInterface {
    function supportsInterface(bytes4 interfaceId)
        external
        view
        override
        returns (bool)
    {
        return (interfaceId == Constants.ERC165_INTERFACE_ID_ERC165 ||
            interfaceId ==
            BeforeAwardListenerLibrary
                .ERC165_INTERFACE_ID_BEFORE_AWARD_LISTENER);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
import "../proxy/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

// solhint-disable-next-line compiler-version
pragma solidity >=0.4.24 <0.8.0;

import "../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
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
        require(_initializing || _isConstructor() || !_initialized, "Initializable: contract is already initialized");

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

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT

// NOTE: Copied from OpenZeppelin Contracts version 3.3.0

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
library OpenZeppelinSafeMath_V3_3_0 {
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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
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
     * @dev Returns the integer division of two unsigned integers. Reverts on
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
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
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
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
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
     *
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
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.7.0;

import "@openzeppelin/contracts-upgradeable/introspection/IERC165Upgradeable.sol";

/// @title An interface that allows a contract to listen to token mint, transfer and burn events.
interface TokenListenerInterface is IERC165Upgradeable {
    /// @notice Called when tokens are minted.
    /// @param to The address of the receiver of the minted tokens.
    /// @param amount The amount of tokens being minted
    /// @param controlledToken The address of the token that is being minted
    /// @param referrer The address that referred the minting.
    function beforeTokenMint(
        address to,
        uint256 amount,
        address controlledToken,
        address referrer
    ) external;

    /// @notice Called when tokens are transferred or burned.
    /// @param from The address of the sender of the token transfer
    /// @param to The address of the receiver of the token transfer.  Will be the zero address if burning.
    /// @param amount The amount of tokens transferred
    /// @param controlledToken The address of the token that was transferred
    function beforeTokenTransfer(
        address from,
        address to,
        uint256 amount,
        address controlledToken
    ) external;
}

pragma solidity 0.6.12;

library TokenListenerLibrary {
    /*
     *     bytes4(keccak256('beforeTokenMint(address,uint256,address,address)')) == 0x4d7f3db0
     *     bytes4(keccak256('beforeTokenTransfer(address,address,uint256,address)')) == 0xb2210957
     *
     *     => 0x4d7f3db0 ^ 0xb2210957 == 0xff5e34e7
     */
    bytes4 public constant ERC165_INTERFACE_ID_TOKEN_LISTENER = 0xff5e34e7;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.5 <0.8.0;

import "../token/ERC20/ERC20Upgradeable.sol";
import "./IERC20PermitUpgradeable.sol";
import "../cryptography/ECDSAUpgradeable.sol";
import "../utils/CountersUpgradeable.sol";
import "./EIP712Upgradeable.sol";
import "../proxy/Initializable.sol";

/**
 * @dev Implementation of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * _Available since v3.4._
 */
abstract contract ERC20PermitUpgradeable is Initializable, ERC20Upgradeable, IERC20PermitUpgradeable, EIP712Upgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    mapping (address => CountersUpgradeable.Counter) private _nonces;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private _PERMIT_TYPEHASH;

    /**
     * @dev Initializes the {EIP712} domain separator using the `name` parameter, and setting `version` to `"1"`.
     *
     * It's a good idea to use the same `name` that is defined as the ERC20 token name.
     */
    function __ERC20Permit_init(string memory name) internal initializer {
        __Context_init_unchained();
        __EIP712_init_unchained(name, "1");
        __ERC20Permit_init_unchained(name);
    }

    function __ERC20Permit_init_unchained(string memory name) internal initializer {
        _PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    }

    /**
     * @dev See {IERC20Permit-permit}.
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public virtual override {
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp <= deadline, "ERC20Permit: expired deadline");

        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                _nonces[owner].current(),
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSAUpgradeable.recover(hash, v, r, s);
        require(signer == owner, "ERC20Permit: invalid signature");

        _nonces[owner].increment();
        _approve(owner, spender, value);
    }

    /**
     * @dev See {IERC20Permit-nonces}.
     */
    function nonces(address owner) public view override returns (uint256) {
        return _nonces[owner].current();
    }

    /**
     * @dev See {IERC20Permit-DOMAIN_SEPARATOR}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "./TokenControllerInterface.sol";

/// @title Controlled ERC20 Token
/// @notice ERC20 Tokens with a controller for minting & burning
interface ControlledTokenInterface is IERC20Upgradeable {
    /// @notice Interface to the contract responsible for controlling mint/burn
    function controller() external view returns (TokenControllerInterface);

    /// @notice Allows the controller to mint tokens for a user account
    /// @dev May be overridden to provide more granular control over minting
    /// @param _user Address of the receiver of the minted tokens
    /// @param _amount Amount of tokens to mint
    function controllerMint(address _user, uint256 _amount) external;

    /// @notice Allows the controller to burn tokens from a user account
    /// @dev May be overridden to provide more granular control over burning
    /// @param _user Address of the holder account to burn tokens from
    /// @param _amount Amount of tokens to burn
    function controllerBurn(address _user, uint256 _amount) external;

    /// @notice Allows an operator via the controller to burn tokens on behalf of a user account
    /// @dev May be overridden to provide more granular control over operator-burning
    /// @param _operator Address of the operator performing the burn action via the controller contract
    /// @param _user Address of the holder account to burn tokens from
    /// @param _amount Amount of tokens to burn
    function controllerBurnFrom(
        address _operator,
        address _user,
        uint256 _amount
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../utils/ContextUpgradeable.sol";
import "./IERC20Upgradeable.sol";
import "../../math/SafeMathUpgradeable.sol";
import "../../proxy/Initializable.sol";

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
contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20Upgradeable {
    using SafeMathUpgradeable for uint256;

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
    function __ERC20_init(string memory name_, string memory symbol_) internal initializer {
        __Context_init_unchained();
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal initializer {
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
    uint256[44] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20PermitUpgradeable {
    /**
     * @dev Sets `value` as the allowance of `spender` over `owner`'s tokens,
     * given `owner`'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for `permit`, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSAUpgradeable {
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
        // Check the signature length
        if (signature.length != 65) {
            revert("ECDSA: invalid signature length");
        }

        // Divide the signature in r, s and v variables
        bytes32 r;
        bytes32 s;
        uint8 v;

        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        return recover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover-bytes32-bytes-} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (281): 0 < s < secp256k1n ÷ 2 + 1, and for v in (282): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "ECDSA: invalid signature 's' value");
        require(v == 27 || v == 28, "ECDSA: invalid signature 'v' value");

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0), "ECDSA: invalid signature");

        return signer;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * replicates the behavior of the
     * https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_sign[`eth_sign`]
     * JSON-RPC method.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../math/SafeMathUpgradeable.sol";

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
library CountersUpgradeable {
    using SafeMathUpgradeable for uint256;

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
import "../proxy/Initializable.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP 712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding specified in the EIP is very generic, and such a generic implementation in Solidity is not feasible,
 * thus this contract does not implement the encoding itself. Protocols need to implement the type-specific encoding
 * they need in their contracts using a combination of `abi.encode` and `keccak256`.
 *
 * This contract implements the EIP 712 domain separator ({_domainSeparatorV4}) that is used as part of the encoding
 * scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA
 * ({_hashTypedDataV4}).
 *
 * The implementation of the domain separator was designed to be as efficient as possible while still properly updating
 * the chain id to protect against replay attacks on an eventual fork of the chain.
 *
 * NOTE: This contract implements the version of the encoding known as "v4", as implemented by the JSON RPC method
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
 *
 * _Available since v3.4._
 */
abstract contract EIP712Upgradeable is Initializable {
    /* solhint-disable var-name-mixedcase */
    bytes32 private _HASHED_NAME;
    bytes32 private _HASHED_VERSION;
    bytes32 private constant _TYPE_HASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    /* solhint-enable var-name-mixedcase */

    /**
     * @dev Initializes the domain separator and parameter caches.
     *
     * The meaning of `name` and `version` is specified in
     * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP 712]:
     *
     * - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
     * - `version`: the current major version of the signing domain.
     *
     * NOTE: These parameters cannot be changed except through a xref:learn::upgrading-smart-contracts.adoc[smart
     * contract upgrade].
     */
    function __EIP712_init(string memory name, string memory version) internal initializer {
        __EIP712_init_unchained(name, version);
    }

    function __EIP712_init_unchained(string memory name, string memory version) internal initializer {
        bytes32 hashedName = keccak256(bytes(name));
        bytes32 hashedVersion = keccak256(bytes(version));
        _HASHED_NAME = hashedName;
        _HASHED_VERSION = hashedVersion;
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        return _buildDomainSeparator(_TYPE_HASH, _EIP712NameHash(), _EIP712VersionHash());
    }

    function _buildDomainSeparator(bytes32 typeHash, bytes32 name, bytes32 version) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                typeHash,
                name,
                version,
                _getChainId(),
                address(this)
            )
        );
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
     *
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     */
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparatorV4(), structHash));
    }

    function _getChainId() private view returns (uint256 chainId) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        // solhint-disable-next-line no-inline-assembly
        assembly {
            chainId := chainid()
        }
    }

    /**
     * @dev The hash of the name parameter for the EIP712 domain.
     *
     * NOTE: This function reads from storage by default, but can be redefined to return a constant value if gas costs
     * are a concern.
     */
    function _EIP712NameHash() internal virtual view returns (bytes32) {
        return _HASHED_NAME;
    }

    /**
     * @dev The hash of the version parameter for the EIP712 domain.
     *
     * NOTE: This function reads from storage by default, but can be redefined to return a constant value if gas costs
     * are a concern.
     */
    function _EIP712VersionHash() internal virtual view returns (bytes32) {
        return _HASHED_VERSION;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
import "../proxy/Initializable.sol";

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
     * by making the `nonReentrant` function external, and make it call a
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

pragma solidity >=0.6.0 <0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721ReceiverUpgradeable {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

import "../../introspection/IERC165Upgradeable.sol";

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
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

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
    function transferFrom(address from, address to, uint256 tokenId) external;

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
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface ICompLike is IERC20Upgradeable {
    function getCurrentVotes(address account) external view returns (uint96);

    function delegate(address delegatee) external;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.7.0;

/// @title Interface that allows a user to draw an address using an index
interface RegistryInterface {
  function lookup() external view returns (address);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.7.0;

/// @title Interface that allows a user to draw an address using an index
interface ReserveInterface {
    function reserveRateMantissa(address prizePool)
        external
        view
        returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

/// @notice An efficient implementation of a singly linked list of addresses
/// @dev A mapping(address => address) tracks the 'next' pointer.  A special address called the SENTINEL is used to denote the beginning and end of the list.
library MappedSinglyLinkedList {
    /// @notice The special value address used to denote the end of the list
    address public constant SENTINEL = address(0x1);

    /// @notice The data structure to use for the list.
    struct Mapping {
        uint256 count;
        mapping(address => address) addressMap;
    }

    /// @notice Initializes the list.
    /// @dev It is important that this is called so that the SENTINEL is correctly setup.
    function initialize(Mapping storage self) internal {
        require(self.count == 0, "Already init");
        self.addressMap[SENTINEL] = SENTINEL;
    }

    function start(Mapping storage self) internal view returns (address) {
        return self.addressMap[SENTINEL];
    }

    function next(Mapping storage self, address current)
        internal
        view
        returns (address)
    {
        return self.addressMap[current];
    }

    function end(Mapping storage) internal pure returns (address) {
        return SENTINEL;
    }

    function addAddresses(Mapping storage self, address[] memory addresses)
        internal
    {
        for (uint256 i = 0; i < addresses.length; i++) {
            addAddress(self, addresses[i]);
        }
    }

    /// @notice Adds an address to the front of the list.
    /// @param self The Mapping struct that this function is attached to
    /// @param newAddress The address to shift to the front of the list
    function addAddress(Mapping storage self, address newAddress) internal {
        require(
            newAddress != SENTINEL && newAddress != address(0),
            "Invalid address"
        );
        require(self.addressMap[newAddress] == address(0), "Already added");
        self.addressMap[newAddress] = self.addressMap[SENTINEL];
        self.addressMap[SENTINEL] = newAddress;
        self.count = self.count + 1;
    }

    /// @notice Removes an address from the list
    /// @param self The Mapping struct that this function is attached to
    /// @param prevAddress The address that precedes the address to be removed.  This may be the SENTINEL if at the start.
    /// @param addr The address to remove from the list.
    function removeAddress(
        Mapping storage self,
        address prevAddress,
        address addr
    ) internal {
        require(addr != SENTINEL && addr != address(0), "Invalid address");
        require(self.addressMap[prevAddress] == addr, "Invalid prevAddress");
        self.addressMap[prevAddress] = self.addressMap[addr];
        delete self.addressMap[addr];
        self.count = self.count - 1;
    }

    /// @notice Determines whether the list contains the given address
    /// @param self The Mapping struct that this function is attached to
    /// @param addr The address to check
    /// @return True if the address is contained, false otherwise.
    function contains(Mapping storage self, address addr)
        internal
        view
        returns (bool)
    {
        return
            addr != SENTINEL &&
            addr != address(0) &&
            self.addressMap[addr] != address(0);
    }

    /// @notice Returns an address array of all the addresses in this list
    /// @dev Contains a for loop, so complexity is O(n) wrt the list size
    /// @param self The Mapping struct that this function is attached to
    /// @return An array of all the addresses
    function addressArray(Mapping storage self)
        internal
        view
        returns (address[] memory)
    {
        address[] memory array = new address[](self.count);
        uint256 count;
        address currentAddress = self.addressMap[SENTINEL];
        while (currentAddress != address(0) && currentAddress != SENTINEL) {
            array[count] = currentAddress;
            currentAddress = self.addressMap[currentAddress];
            count++;
        }
        return array;
    }

    /// @notice Removes every address from the list
    /// @param self The Mapping struct that this function is attached to
    function clearAll(Mapping storage self) internal {
        address currentAddress = self.addressMap[SENTINEL];
        while (currentAddress != address(0) && currentAddress != SENTINEL) {
            address nextAddress = self.addressMap[currentAddress];
            delete self.addressMap[currentAddress];
            currentAddress = nextAddress;
        }
        self.addressMap[SENTINEL] = SENTINEL;
        self.count = 0;
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "../token/TokenListenerInterface.sol";
import "../token/ControlledTokenInterface.sol";

/// @title Escrows assets and deposits them into a yield source.  Exposes interest to Prize Strategy.  Users deposit and withdraw from this contract to participate in Prize Pool.
/// @notice Accounting is managed using Controlled Tokens, whose mint and burn functions can only be called by this contract.
/// @dev Must be inherited to provide specific yield-bearing asset control, such as Compound cTokens
interface PrizePoolInterface {
    /// @notice Deposit assets into the Prize Pool in exchange for tokens
    /// @param to The address receiving the newly minted tokens
    /// @param amount The amount of assets to deposit
    /// @param controlledToken The address of the type of token the user is minting
    /// @param referrer The referrer of the deposit
    function depositTo(
        address to,
        uint256 amount,
        address controlledToken,
        address referrer
    ) external;

    /// @notice Withdraw assets from the Prize Pool instantly.  A fairness fee may be charged for an early exit.
    /// @param from The address to redeem tokens from.
    /// @param amount The amount of tokens to redeem for assets.
    /// @param controlledToken The address of the token to redeem (i.e. ticket or sponsorship)
    /// @param maximumExitFee The maximum exit fee the caller is willing to pay.  This should be pre-calculated by the calculateExitFee() fxn.
    /// @return The actual exit fee paid
    function withdrawInstantlyFrom(
        address from,
        uint256 amount,
        address controlledToken,
        uint256 maximumExitFee
    ) external returns (uint256);

    function withdrawReserve(address to) external returns (uint256);

    /// @notice Returns the balance that is available to award.
    /// @dev captureAwardBalance() should be called first
    /// @return The total amount of assets to be awarded for the current prize
    function awardBalance() external view returns (uint256);

    /// @notice Captures any available interest as award balance.
    /// @dev This function also captures the reserve fees.
    /// @return The total amount of assets to be awarded for the current prize
    function captureAwardBalance() external returns (uint256);

    /// @notice Called by the prize strategy to award prizes.
    /// @dev The amount awarded must be less than the awardBalance()
    /// @param to The address of the winner that receives the award
    /// @param amount The amount of assets to be awarded
    /// @param controlledToken The address of the asset token being awarded
    function award(
        address to,
        uint256 amount,
        address controlledToken
    ) external;

    /// @notice Called by the Prize-Strategy to transfer out external ERC20 tokens
    /// @dev Used to transfer out tokens held by the Prize Pool.  Could be liquidated, or anything.
    /// @param to The address of the winner that receives the award
    /// @param amount The amount of external assets to be awarded
    /// @param externalToken The address of the external asset token being awarded
    function transferExternalERC20(
        address to,
        address externalToken,
        uint256 amount
    ) external;

    /// @notice Called by the Prize-Strategy to award external ERC20 prizes
    /// @dev Used to award any arbitrary tokens held by the Prize Pool
    /// @param to The address of the winner that receives the award
    /// @param amount The amount of external assets to be awarded
    /// @param externalToken The address of the external asset token being awarded
    function awardExternalERC20(
        address to,
        address externalToken,
        uint256 amount
    ) external;

    /// @notice Called by the prize strategy to award external ERC721 prizes
    /// @dev Used to award any arbitrary NFTs held by the Prize Pool
    /// @param to The address of the winner that receives the award
    /// @param externalToken The address of the external NFT token being awarded
    /// @param tokenIds An array of NFT Token IDs to be transferred
    function awardExternalERC721(
        address to,
        address externalToken,
        uint256[] calldata tokenIds
    ) external;

    /// @notice Calculates the early exit fee for the given amount
    /// @param from The user who is withdrawing
    /// @param controlledToken The type of collateral being withdrawn
    /// @param amount The amount of collateral to be withdrawn
    /// @return exitFee The exit fee
    /// @return burnedCredit The user's credit that was burned
    function calculateEarlyExitFee(
        address from,
        address controlledToken,
        uint256 amount
    ) external returns (uint256 exitFee, uint256 burnedCredit);

    /// @notice Estimates the amount of time it will take for a given amount of funds to accrue the given amount of credit.
    /// @param _principal The principal amount on which interest is accruing
    /// @param _interest The amount of interest that must accrue
    /// @return durationSeconds The duration of time it will take to accrue the given amount of interest, in seconds.
    function estimateCreditAccrualTime(
        address _controlledToken,
        uint256 _principal,
        uint256 _interest
    ) external view returns (uint256 durationSeconds);

    /// @notice Returns the credit balance for a given user.  Not that this includes both minted credit and pending credit.
    /// @param user The user whose credit balance should be returned
    /// @return The balance of the users credit
    function balanceOfCredit(address user, address controlledToken)
        external
        returns (uint256);

    /// @notice Sets the rate at which credit accrues per second.  The credit rate is a fixed point 18 number (like Ether).
    /// @param _controlledToken The controlled token for whom to set the credit plan
    /// @param _creditRateMantissa The credit rate to set.  Is a fixed point 18 decimal (like Ether).
    /// @param _creditLimitMantissa The credit limit to set.  Is a fixed point 18 decimal (like Ether).
    function setCreditPlanOf(
        address _controlledToken,
        uint128 _creditRateMantissa,
        uint128 _creditLimitMantissa
    ) external;

    /// @notice Returns the credit rate of a controlled token
    /// @param controlledToken The controlled token to retrieve the credit rates for
    /// @return creditLimitMantissa The credit limit fraction.  This number is used to calculate both the credit limit and early exit fee.
    /// @return creditRateMantissa The credit rate. This is the amount of tokens that accrue per second.
    function creditPlanOf(address controlledToken)
        external
        view
        returns (uint128 creditLimitMantissa, uint128 creditRateMantissa);

    /// @notice Allows the Governor to set a cap on the amount of liquidity that he pool can hold
    /// @param _liquidityCap The new liquidity cap for the prize pool
    function setLiquidityCap(uint256 _liquidityCap) external;

    /// @notice Sets the prize strategy of the prize pool.  Only callable by the owner.
    /// @param _prizeStrategy The new prize strategy.  Must implement TokenListenerInterface
    function setPrizeStrategy(TokenListenerInterface _prizeStrategy) external;

    /// @dev Returns the address of the underlying ERC20 asset
    /// @return The address of the asset
    function token() external view returns (address);

    /// @notice An array of the Tokens controlled by the Prize Pool (ie. Tickets, Sponsorship)
    /// @return An array of controlled token addresses
    function tokens() external view returns (address[] memory);

    /// @notice The total of all controlled tokens and timelock.
    /// @return The current total of all tokens and timelock.
    function accountedBalance() external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/introspection/IERC165Upgradeable.sol";

/// @notice The interface for the Periodic Prize Strategy before award listener.  This listener will be called immediately before the award is distributed.
interface BeforeAwardListenerInterface is IERC165Upgradeable {
  /// @notice Called immediately before the award is distributed
  function beforePrizePoolAwarded(uint256 randomNumber, uint256 prizePeriodStartedAt) external;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

library BeforeAwardListenerLibrary {
  /*
    *     bytes4(keccak256('beforePrizePoolAwarded(uint256,uint256)')) == 0x4cdf9c3e
    */
  bytes4 public constant ERC165_INTERFACE_ID_BEFORE_AWARD_LISTENER = 0x4cdf9c3e;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "@pooltogether/yield-source-interface/contracts/IYieldSource.sol";

import "../PrizePool.sol";

contract YieldSourcePrizePool is PrizePool {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;

    IYieldSource public yieldSource;

    event YieldSourcePrizePoolInitialized(address indexed yieldSource);

    /// @notice Initializes the Prize Pool and Yield Service with the required contract connections
    /// @param _controlledTokens Array of addresses for the Ticket and Sponsorship Tokens controlled by the Prize Pool
    /// @param _maxExitFeeMantissa The maximum exit fee size, relative to the withdrawal amount
    /// @param _yieldSource Address of the yield source
    function initializeYieldSourcePrizePool(
        RegistryInterface _reserveRegistry,
        ControlledTokenInterface[] memory _controlledTokens,
        uint256 _maxExitFeeMantissa,
        IYieldSource _yieldSource,
        address _gateManager
    ) public initializer {
        require(
            address(_yieldSource).isContract(),
            "YieldSourcePrizePool/yield-source-not-contract-address"
        );
        PrizePool.initialize(
            _reserveRegistry,
            _controlledTokens,
            _maxExitFeeMantissa,
            _gateManager
        );
        yieldSource = _yieldSource;

        // A hack to determine whether it's an actual yield source
        (bool succeeded, ) = address(_yieldSource).staticcall(
            abi.encode(_yieldSource.depositToken.selector)
        );
        require(succeeded, "YieldSourcePrizePool/invalid-yield-source");

        emit YieldSourcePrizePoolInitialized(address(_yieldSource));
    }

    /// @notice Determines whether the passed token can be transferred out as an external award.
    /// @dev Different yield sources will hold the deposits as another kind of token: such a Compound's cToken.  The
    /// prize strategy should not be allowed to move those tokens.
    /// @param _externalToken The address of the token to check
    /// @return True if the token may be awarded, false otherwise
    function _canAwardExternal(address _externalToken)
        internal
        view
        override
        returns (bool)
    {
        return _externalToken != address(yieldSource);
    }

    /// @notice Returns the total balance (in asset tokens).  This includes the deposits and interest.
    /// @return The underlying balance of asset tokens
    function _balance() internal override returns (uint256) {
        return yieldSource.balanceOfToken(address(this));
    }

    function _token() internal view override returns (IERC20Upgradeable) {
        return IERC20Upgradeable(yieldSource.depositToken());
    }

    /// @notice Supplies asset tokens to the yield source.
    /// @param mintAmount The amount of asset tokens to be supplied
    function _supply(uint256 mintAmount) internal override {
        _token().safeApprove(address(yieldSource), mintAmount);
        yieldSource.supplyTokenTo(mintAmount, address(this));
    }

    /// @notice Redeems asset tokens from the yield source.
    /// @param redeemAmount The amount of yield-bearing tokens to be redeemed
    /// @return The actual amount of tokens that were redeemed.
    function _redeem(uint256 redeemAmount) internal override returns (uint256) {
        return yieldSource.redeemToken(redeemAmount);
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0;

/// @title Defines the functions used to interact with a yield source.  The Prize Pool inherits this contract.
/// @notice Prize Pools subclasses need to implement this interface so that yield can be generated.
interface IYieldSource {
    /// @notice Returns the ERC20 asset token used for deposits.
    /// @return The ERC20 asset token address.
    function depositToken() external view returns (address);

    /// @notice Returns the total balance (in asset tokens).  This includes the deposits and interest.
    /// @return The underlying balance of asset tokens.
    function balanceOfToken(address addr) external returns (uint256);

    /// @notice Supplies tokens to the yield source.  Allows assets to be supplied on other user's behalf using the `to` param.
    /// @param amount The amount of asset tokens to be supplied.  Denominated in `depositToken()` as above.
    /// @param to The user whose balance will receive the tokens
    function supplyTokenTo(uint256 amount, address to) external;

    /// @notice Redeems tokens from the yield source.
    /// @param amount The amount of asset tokens to withdraw.  Denominated in `depositToken()` as above.
    /// @return The actual amount of interst bearing tokens that were redeemed.
    function redeemToken(uint256 amount) external returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "./RNGInterface.sol";

contract RNGBlockhash is RNGInterface, Ownable {
    using SafeMathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;

    /// @dev A counter for the number of requests made used for request ids
    uint32 internal requestCount;

    /// @dev A list of random numbers from past requests mapped by request id
    mapping(uint32 => uint256) internal randomNumbers;

    /// @dev A list of blocks to be locked at based on past requests mapped by request id
    mapping(uint32 => uint32) internal requestLockBlock;

    /// @notice Public constructor
    constructor() public {}

    /// @notice Gets the last request id used by the RNG service
    /// @return requestId The last request id used in the last request
    function getLastRequestId()
        external
        view
        override
        returns (uint32 requestId)
    {
        return requestCount;
    }

    /// @notice Gets the Fee for making a Request against an RNG service
    /// @return feeToken The address of the token that is used to pay fees
    /// @return requestFee The fee required to be paid to make a request
    function getRequestFee()
        external
        view
        override
        returns (address feeToken, uint256 requestFee)
    {
        return (address(0), 0);
    }

    /// @notice Sends a request for a random number to the 3rd-party service
    /// @dev Some services will complete the request immediately, others may have a time-delay
    /// @dev Some services require payment in the form of a token, such as $LINK for Chainlink VRF
    /// @return requestId The ID of the request used to get the results of the RNG service
    /// @return lockBlock The block number at which the RNG service will start generating time-delayed randomness.  The calling contract
    /// should "lock" all activity until the result is available via the `requestId`
    function requestRandomNumber()
        external
        virtual
        override
        returns (uint32 requestId, uint32 lockBlock)
    {
        requestId = _getNextRequestId();
        lockBlock = uint32(block.number);

        requestLockBlock[requestId] = lockBlock;

        emit RandomNumberRequested(requestId, msg.sender);
    }

    /// @notice Checks if the request for randomness from the 3rd-party service has completed
    /// @dev For time-delayed requests, this function is used to check/confirm completion
    /// @param requestId The ID of the request used to get the results of the RNG service
    /// @return isCompleted True if the request has completed and a random number is available, false otherwise
    function isRequestComplete(uint32 requestId)
        external
        view
        virtual
        override
        returns (bool isCompleted)
    {
        return _isRequestComplete(requestId);
    }

    /// @notice Gets the random number produced by the 3rd-party service
    /// @param requestId The ID of the request used to get the results of the RNG service
    /// @return randomNum The random number
    function randomNumber(uint32 requestId)
        external
        virtual
        override
        returns (uint256 randomNum)
    {
        require(
            _isRequestComplete(requestId),
            "RNGBlockhash/request-incomplete"
        );

        if (randomNumbers[requestId] == 0) {
            _storeResult(requestId, _getSeed());
        }

        return randomNumbers[requestId];
    }

    /// @dev Checks if the request for randomness from the 3rd-party service has completed
    /// @param requestId The ID of the request used to get the results of the RNG service
    /// @return True if the request has completed and a random number is available, false otherwise
    function _isRequestComplete(uint32 requestId) internal view returns (bool) {
        return block.number > (requestLockBlock[requestId] + 1);
    }

    /// @dev Gets the next consecutive request ID to be used
    /// @return requestId The ID to be used for the next request
    function _getNextRequestId() internal returns (uint32 requestId) {
        requestCount = uint256(requestCount).add(1).toUint32();
        requestId = requestCount;
    }

    /// @dev Gets a seed for a random number from the latest available blockhash
    /// @return seed The seed to be used for generating a random number
    function _getSeed() internal view virtual returns (uint256 seed) {
        return uint256(blockhash(block.number - 1));
    }

    /// @dev Stores the latest random number by request ID and logs the event
    /// @param requestId The ID of the request to store the random number
    /// @param result The random number for the request ID
    function _storeResult(uint32 requestId, uint256 result) internal {
        // Store random value
        randomNumbers[requestId] = result;

        emit RandomNumberCompleted(requestId, result);
    }
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

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

/// @title Random Number Generator Interface
/// @notice Provides an interface for requesting random numbers from 3rd-party RNG services (Chainlink VRF, Starkware VDF, etc..)
interface RNGInterface {
    /// @notice Emitted when a new request for a random number has been submitted
    /// @param requestId The indexed ID of the request used to get the results of the RNG service
    /// @param sender The indexed address of the sender of the request
    event RandomNumberRequested(
        uint32 indexed requestId,
        address indexed sender
    );

    /// @notice Emitted when an existing request for a random number has been completed
    /// @param requestId The indexed ID of the request used to get the results of the RNG service
    /// @param randomNumber The random number produced by the 3rd-party service
    event RandomNumberCompleted(uint32 indexed requestId, uint256 randomNumber);

    /// @notice Gets the last request id used by the RNG service
    /// @return requestId The last request id used in the last request
    function getLastRequestId() external view returns (uint32 requestId);

    /// @notice Gets the Fee for making a Request against an RNG service
    /// @return feeToken The address of the token that is used to pay fees
    /// @return requestFee The fee required to be paid to make a request
    function getRequestFee()
        external
        view
        returns (address feeToken, uint256 requestFee);

    /// @notice Sends a request for a random number to the 3rd-party service
    /// @dev Some services will complete the request immediately, others may have a time-delay
    /// @dev Some services require payment in the form of a token, such as $LINK for Chainlink VRF
    /// @return requestId The ID of the request used to get the results of the RNG service
    /// @return lockBlock The block number at which the RNG service will start generating time-delayed randomness.  The calling contract
    /// should "lock" all activity until the result is available via the `requestId`
    function requestRandomNumber()
        external
        returns (uint32 requestId, uint32 lockBlock);

    /// @notice Checks if the request for randomness from the 3rd-party service has completed
    /// @dev For time-delayed requests, this function is used to check/confirm completion
    /// @param requestId The ID of the request used to get the results of the RNG service
    /// @return isCompleted True if the request has completed and a random number is available, false otherwise
    function isRequestComplete(uint32 requestId)
        external
        view
        returns (bool isCompleted);

    /// @notice Gets the random number produced by the 3rd-party service
    /// @param requestId The ID of the request used to get the results of the RNG service
    /// @return randomNum The random number
    function randomNumber(uint32 requestId)
        external
        returns (uint256 randomNum);
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
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Abstract prize split contract for adding unique award distribution to static addresses.
 * @author Kames Geraghty (PoolTogether Inc)
 */
abstract contract PrizeSplit is OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    PrizeSplitConfig[] internal _prizeSplits;

    /**
     * @notice The prize split configuration struct.
     * @dev The prize split configuration struct used to award prize splits during distribution.
     * @param target Address of recipient receiving the prize split distribution
     * @param percentage Percentage of prize split using a 0-1000 range for single decimal precision i.e. 125 = 12.5%
     * @param token Position of controlled token in prizePool.tokens (i.e. ticket or sponsorship)
     */
    struct PrizeSplitConfig {
        address target;
        uint16 percentage;
        uint8 token;
    }

    /**
     * @notice Emitted when a PrizeSplitConfig config is added or updated.
     * @dev Emitted when aPrizeSplitConfig config is added or updated in setPrizeSplits or setPrizeSplit.
     * @param target Address of prize split recipient
     * @param percentage Percentage of prize split. Must be between 0 and 1000 for single decimal precision
     * @param token Index (0 or 1) of token in the prizePool.tokens mapping
     * @param index Index of prize split in the prizeSplts array
     */
    event PrizeSplitSet(
        address indexed target,
        uint16 percentage,
        uint8 token,
        uint256 index
    );

    /**
     * @notice Emitted when a PrizeSplitConfig config is removed.
     * @dev Emitted when a PrizeSplitConfig config is removed from the _prizeSplits array.
     * @param target Index of a previously active prize split config
     */
    event PrizeSplitRemoved(uint256 indexed target);

    /**
     * @notice Mints ticket or sponsorship tokens to prize split recipient.
     * @dev Mints ticket or sponsorship tokens to prize split recipient via the linked PrizePool contract.
     * @param target Recipient of minted tokens
     * @param amount Amount of minted tokens
     * @param tokenIndex Index (0 or 1) of a token in the prizePool.tokens mapping
     */
    function _awardPrizeSplitAmount(
        address target,
        uint256 amount,
        uint8 tokenIndex
    ) internal virtual;

    /**
     * @notice Read all prize splits configs.
     * @dev Read all PrizeSplitConfig structs stored in _prizeSplits.
     * @return _prizeSplits Array of PrizeSplitConfig structs
     */
    function prizeSplits() external view returns (PrizeSplitConfig[] memory) {
        return _prizeSplits;
    }

    /**
     * @notice Read prize split config from active PrizeSplits.
     * @dev Read PrizeSplitConfig struct from _prizeSplits array.
     * @param prizeSplitIndex Index position of PrizeSplitConfig
     * @return PrizeSplitConfig Single prize split config
     */
    function prizeSplit(uint256 prizeSplitIndex)
        external
        view
        returns (PrizeSplitConfig memory)
    {
        return _prizeSplits[prizeSplitIndex];
    }

    /**
     * @notice Set and remove prize split(s) configs.
     * @dev Set and remove prize split configs by passing a new PrizeSplitConfig structs array. Will remove existing PrizeSplitConfig(s) if passed array length is less than existing _prizeSplits length.
     * @param newPrizeSplits Array of PrizeSplitConfig structs
     */
    function setPrizeSplits(PrizeSplitConfig[] calldata newPrizeSplits)
        external
        onlyOwner
    {
        uint256 newPrizeSplitsLength = newPrizeSplits.length;

        // Add and/or update prize split configs using newPrizeSplits PrizeSplitConfig structs array.
        for (uint256 index = 0; index < newPrizeSplitsLength; index++) {
            PrizeSplitConfig memory split = newPrizeSplits[index];
            require(
                split.token <= 1,
                "MultipleWinners/invalid-prizesplit-token"
            );
            require(
                split.target != address(0),
                "MultipleWinners/invalid-prizesplit-target"
            );

            if (_prizeSplits.length <= index) {
                _prizeSplits.push(split);
            } else {
                PrizeSplitConfig memory currentSplit = _prizeSplits[index];
                if (
                    split.target != currentSplit.target ||
                    split.percentage != currentSplit.percentage ||
                    split.token != currentSplit.token
                ) {
                    _prizeSplits[index] = split;
                } else {
                    continue;
                }
            }

            // Emit the added/updated prize split config.
            emit PrizeSplitSet(
                split.target,
                split.percentage,
                split.token,
                index
            );
        }

        // Remove old prize splits configs. Match storage _prizesSplits.length with the passed newPrizeSplits.length
        while (_prizeSplits.length > newPrizeSplitsLength) {
            uint256 _index = _prizeSplits.length.sub(1);
            _prizeSplits.pop();
            emit PrizeSplitRemoved(_index);
        }

        // Total prize split do not exceed 100%
        uint256 totalPercentage = _totalPrizeSplitPercentageAmount();
        require(
            totalPercentage <= 1000,
            "MultipleWinners/invalid-prizesplit-percentage-total"
        );
    }

    /**
     * @notice Updates a previously set prize split config.
     * @dev Updates a prize split config by passing a new PrizeSplitConfig struct and current index position. Limited to contract owner.
     * @param prizeStrategySplit PrizeSplitConfig config struct
     * @param prizeSplitIndex Index position of PrizeSplitConfig to update
     */
    function setPrizeSplit(
        PrizeSplitConfig memory prizeStrategySplit,
        uint8 prizeSplitIndex
    ) external onlyOwner {
        require(
            prizeSplitIndex < _prizeSplits.length,
            "MultipleWinners/nonexistent-prizesplit"
        );
        require(
            prizeStrategySplit.token <= 1,
            "MultipleWinners/invalid-prizesplit-token"
        );
        require(
            prizeStrategySplit.target != address(0),
            "MultipleWinners/invalid-prizesplit-target"
        );

        // Update the prize split config
        _prizeSplits[prizeSplitIndex] = prizeStrategySplit;

        // Total prize split do not exceed 100%
        uint256 totalPercentage = _totalPrizeSplitPercentageAmount();
        require(
            totalPercentage <= 1000,
            "MultipleWinners/invalid-prizesplit-percentage-total"
        );

        // Emit updated prize split config
        emit PrizeSplitSet(
            prizeStrategySplit.target,
            prizeStrategySplit.percentage,
            prizeStrategySplit.token,
            prizeSplitIndex
        );
    }

    /**
     * @notice Calculate single prize split distribution amount.
     * @dev Calculate single prize split distribution amount using the total prize amount and prize split percentage.
     * @param amount Total prize award distribution amount
     * @param percentage Percentage with single decimal precision using 0-1000 ranges
     */
    function _getPrizeSplitAmount(uint256 amount, uint16 percentage)
        internal
        pure
        returns (uint256)
    {
        return (amount * percentage).div(1000);
    }

    /**
     * @notice Calculates total prize split percentage amount.
     * @dev Calculates total PrizeSplitConfig percentage(s) amount. Used to check the total does not exceed 100% of award distribution.
     * @return Total prize split(s) percentage amount
     */
    function _totalPrizeSplitPercentageAmount()
        internal
        view
        returns (uint256)
    {
        uint256 _tempTotalPercentage;
        uint256 prizeSplitsLength = _prizeSplits.length;
        for (uint8 index = 0; index < prizeSplitsLength; index++) {
            PrizeSplitConfig memory split = _prizeSplits[index];
            _tempTotalPercentage = _tempTotalPercentage.add(split.percentage);
        }
        return _tempTotalPercentage;
    }

    /**
     * @notice Distributes prize split(s).
     * @dev Distributes prize split(s) by awarding ticket or sponsorship tokens.
     * @param prize Starting prize award amount
     * @return Total prize award distribution amount exlcuding the awarded prize split(s)
     */
    function _distributePrizeSplits(uint256 prize) internal returns (uint256) {
        // Store temporary total prize amount for multiple calculations using initial prize amount.
        uint256 _prizeTemp = prize;
        uint256 prizeSplitsLength = _prizeSplits.length;
        for (uint256 index = 0; index < prizeSplitsLength; index++) {
            PrizeSplitConfig memory split = _prizeSplits[index];
            uint256 _splitAmount = _getPrizeSplitAmount(
                _prizeTemp,
                split.percentage
            );

            // Award the prize split distribution amount.
            _awardPrizeSplitAmount(split.target, _splitAmount, split.token);

            // Update the remaining prize amount after distributing the prize split percentage.
            prize = prize.sub(_splitAmount);
        }

        return prize;
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.7.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./ReserveInterface.sol";
import "../prize-pool/PrizePoolInterface.sol";

/// @title Interface that allows a user to draw an address using an index
contract Reserve is OwnableUpgradeable, ReserveInterface {

  event ReserveRateMantissaSet(uint256 rateMantissa);

  uint256 public rateMantissa;

  constructor () public {
    __Ownable_init();
  }

  function setRateMantissa(
    uint256 _rateMantissa
  )
    external
    onlyOwner
  {
    rateMantissa = _rateMantissa;

    emit ReserveRateMantissaSet(rateMantissa);
  }

  function withdrawReserve(address prizePool, address to) external onlyOwner returns (uint256) {
    return PrizePoolInterface(prizePool).withdrawReserve(to);
  }

  function reserveRateMantissa(address) external view override returns (uint256) {
    return rateMantissa;
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "sortition-sum-tree-factory/contracts/SortitionSumTreeFactory.sol";
import "@pooltogether/uniform-random-number/contracts/UniformRandomNumber.sol";

import "./ControlledToken.sol";
import "./TicketInterface.sol";

contract Ticket is ControlledToken, TicketInterface {
  using SortitionSumTreeFactory for SortitionSumTreeFactory.SortitionSumTrees;

  bytes32 constant private TREE_KEY = keccak256("PoolTogether/Ticket");
  uint256 constant private MAX_TREE_LEAVES = 5;

  /// @dev Emitted when an instance is initialized
  event Initialized(
    string _name,
    string _symbol,
    uint8 _decimals,
    TokenControllerInterface _controller
  );

  // Ticket-weighted odds
  SortitionSumTreeFactory.SortitionSumTrees internal sortitionSumTrees;

  /// @notice Initializes the Controlled Token with Token Details and the Controller
  /// @param _name The name of the Token
  /// @param _symbol The symbol for the Token
  /// @param _decimals The number of decimals for the Token
  /// @param _controller Address of the Controller contract for minting & burning
  function initialize(
    string memory _name,
    string memory _symbol,
    uint8 _decimals,
    TokenControllerInterface _controller
  )
    public
    virtual
    override
    initializer
  {
    require(address(_controller) != address(0), "Ticket/controller-not-zero");
    ControlledToken.initialize(_name, _symbol, _decimals, _controller);
    sortitionSumTrees.createTree(TREE_KEY, MAX_TREE_LEAVES);
    emit Initialized(
      _name,
      _symbol,
      _decimals,
      _controller
    );
  }

  /// @notice Returns the user's chance of winning.
  function chanceOf(address user) external view returns (uint256) {
    return sortitionSumTrees.stakeOf(TREE_KEY, bytes32(uint256(user)));
  }

  /// @notice Selects a user using a random number.  The random number will be uniformly bounded to the ticket totalSupply.
  /// @param randomNumber The random number to use to select a user.
  /// @return The winner
  function draw(uint256 randomNumber) external view override returns (address) {
    uint256 bound = totalSupply();
    address selected;
    if (bound == 0) {
      selected = address(0);
    } else {
      uint256 token = UniformRandomNumber.uniform(randomNumber, bound);
      selected = address(uint256(sortitionSumTrees.draw(TREE_KEY, token)));
    }
    return selected;
  }

  /// @dev Controller hook to provide notifications & rule validations on token transfers to the controller.
  /// This includes minting and burning.
  /// May be overridden to provide more granular control over operator-burning
  /// @param from Address of the account sending the tokens (address(0x0) on minting)
  /// @param to Address of the account receiving the tokens (address(0x0) on burning)
  /// @param amount Amount of tokens being transferred
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
    super._beforeTokenTransfer(from, to, amount);

    // optimize: ignore transfers to self
    if (from == to) {
      return;
    }

    if (from != address(0)) {
      uint256 fromBalance = balanceOf(from).sub(amount);
      sortitionSumTrees.set(TREE_KEY, fromBalance, bytes32(uint256(from)));
    }

    if (to != address(0)) {
      uint256 toBalance = balanceOf(to).add(amount);
      sortitionSumTrees.set(TREE_KEY, toBalance, bytes32(uint256(to)));
    }
  }

}

/**
 *  @reviewers: [@clesaege, @unknownunknown1, @ferittuncer]
 *  @auditors: []
 *  @bounties: [<14 days 10 ETH max payout>]
 *  @deployments: []
 */

pragma solidity ^0.6.0;

/**
 *  @title SortitionSumTreeFactory
 *  @author Enrique Piqueras - <[email protected]>
 *  @dev A factory of trees that keep track of staked values for sortition.
 */
library SortitionSumTreeFactory {
    /* Structs */

    struct SortitionSumTree {
        uint K; // The maximum number of childs per node.
        // We use this to keep track of vacant positions in the tree after removing a leaf. This is for keeping the tree as balanced as possible without spending gas on moving nodes around.
        uint[] stack;
        uint[] nodes;
        // Two-way mapping of IDs to node indexes. Note that node index 0 is reserved for the root node, and means the ID does not have a node.
        mapping(bytes32 => uint) IDsToNodeIndexes;
        mapping(uint => bytes32) nodeIndexesToIDs;
    }

    /* Storage */

    struct SortitionSumTrees {
        mapping(bytes32 => SortitionSumTree) sortitionSumTrees;
    }

    /* internal */

    /**
     *  @dev Create a sortition sum tree at the specified key.
     *  @param _key The key of the new tree.
     *  @param _K The number of children each node in the tree should have.
     */
    function createTree(SortitionSumTrees storage self, bytes32 _key, uint _K) internal {
        SortitionSumTree storage tree = self.sortitionSumTrees[_key];
        require(tree.K == 0, "Tree already exists.");
        require(_K > 1, "K must be greater than one.");
        tree.K = _K;
        tree.stack = new uint[](0);
        tree.nodes = new uint[](0);
        tree.nodes.push(0);
    }

    /**
     *  @dev Set a value of a tree.
     *  @param _key The key of the tree.
     *  @param _value The new value.
     *  @param _ID The ID of the value.
     *  `O(log_k(n))` where
     *  `k` is the maximum number of childs per node in the tree,
     *   and `n` is the maximum number of nodes ever appended.
     */
    function set(SortitionSumTrees storage self, bytes32 _key, uint _value, bytes32 _ID) internal {
        SortitionSumTree storage tree = self.sortitionSumTrees[_key];
        uint treeIndex = tree.IDsToNodeIndexes[_ID];

        if (treeIndex == 0) { // No existing node.
            if (_value != 0) { // Non zero value.
                // Append.
                // Add node.
                if (tree.stack.length == 0) { // No vacant spots.
                    // Get the index and append the value.
                    treeIndex = tree.nodes.length;
                    tree.nodes.push(_value);

                    // Potentially append a new node and make the parent a sum node.
                    if (treeIndex != 1 && (treeIndex - 1) % tree.K == 0) { // Is first child.
                        uint parentIndex = treeIndex / tree.K;
                        bytes32 parentID = tree.nodeIndexesToIDs[parentIndex];
                        uint newIndex = treeIndex + 1;
                        tree.nodes.push(tree.nodes[parentIndex]);
                        delete tree.nodeIndexesToIDs[parentIndex];
                        tree.IDsToNodeIndexes[parentID] = newIndex;
                        tree.nodeIndexesToIDs[newIndex] = parentID;
                    }
                } else { // Some vacant spot.
                    // Pop the stack and append the value.
                    treeIndex = tree.stack[tree.stack.length - 1];
                    tree.stack.pop();
                    tree.nodes[treeIndex] = _value;
                }

                // Add label.
                tree.IDsToNodeIndexes[_ID] = treeIndex;
                tree.nodeIndexesToIDs[treeIndex] = _ID;

                updateParents(self, _key, treeIndex, true, _value);
            }
        } else { // Existing node.
            if (_value == 0) { // Zero value.
                // Remove.
                // Remember value and set to 0.
                uint value = tree.nodes[treeIndex];
                tree.nodes[treeIndex] = 0;

                // Push to stack.
                tree.stack.push(treeIndex);

                // Clear label.
                delete tree.IDsToNodeIndexes[_ID];
                delete tree.nodeIndexesToIDs[treeIndex];

                updateParents(self, _key, treeIndex, false, value);
            } else if (_value != tree.nodes[treeIndex]) { // New, non zero value.
                // Set.
                bool plusOrMinus = tree.nodes[treeIndex] <= _value;
                uint plusOrMinusValue = plusOrMinus ? _value - tree.nodes[treeIndex] : tree.nodes[treeIndex] - _value;
                tree.nodes[treeIndex] = _value;

                updateParents(self, _key, treeIndex, plusOrMinus, plusOrMinusValue);
            }
        }
    }

    /* internal Views */

    /**
     *  @dev Query the leaves of a tree. Note that if `startIndex == 0`, the tree is empty and the root node will be returned.
     *  @param _key The key of the tree to get the leaves from.
     *  @param _cursor The pagination cursor.
     *  @param _count The number of items to return.
     *  @return startIndex The index at which leaves start
     *  @return values The values of the returned leaves
     *  @return hasMore Whether there are more for pagination.
     *  `O(n)` where
     *  `n` is the maximum number of nodes ever appended.
     */
    function queryLeafs(
        SortitionSumTrees storage self,
        bytes32 _key,
        uint _cursor,
        uint _count
    ) internal view returns(uint startIndex, uint[] memory values, bool hasMore) {
        SortitionSumTree storage tree = self.sortitionSumTrees[_key];

        // Find the start index.
        for (uint i = 0; i < tree.nodes.length; i++) {
            if ((tree.K * i) + 1 >= tree.nodes.length) {
                startIndex = i;
                break;
            }
        }

        // Get the values.
        uint loopStartIndex = startIndex + _cursor;
        values = new uint[](loopStartIndex + _count > tree.nodes.length ? tree.nodes.length - loopStartIndex : _count);
        uint valuesIndex = 0;
        for (uint j = loopStartIndex; j < tree.nodes.length; j++) {
            if (valuesIndex < _count) {
                values[valuesIndex] = tree.nodes[j];
                valuesIndex++;
            } else {
                hasMore = true;
                break;
            }
        }
    }

    /**
     *  @dev Draw an ID from a tree using a number. Note that this function reverts if the sum of all values in the tree is 0.
     *  @param _key The key of the tree.
     *  @param _drawnNumber The drawn number.
     *  @return ID The drawn ID.
     *  `O(k * log_k(n))` where
     *  `k` is the maximum number of childs per node in the tree,
     *   and `n` is the maximum number of nodes ever appended.
     */
    function draw(SortitionSumTrees storage self, bytes32 _key, uint _drawnNumber) internal view returns(bytes32 ID) {
        SortitionSumTree storage tree = self.sortitionSumTrees[_key];
        uint treeIndex = 0;
        uint currentDrawnNumber = _drawnNumber % tree.nodes[0];

        while ((tree.K * treeIndex) + 1 < tree.nodes.length)  // While it still has children.
            for (uint i = 1; i <= tree.K; i++) { // Loop over children.
                uint nodeIndex = (tree.K * treeIndex) + i;
                uint nodeValue = tree.nodes[nodeIndex];

                if (currentDrawnNumber >= nodeValue) currentDrawnNumber -= nodeValue; // Go to the next child.
                else { // Pick this child.
                    treeIndex = nodeIndex;
                    break;
                }
            }
        
        ID = tree.nodeIndexesToIDs[treeIndex];
    }

    /** @dev Gets a specified ID's associated value.
     *  @param _key The key of the tree.
     *  @param _ID The ID of the value.
     *  @return value The associated value.
     */
    function stakeOf(SortitionSumTrees storage self, bytes32 _key, bytes32 _ID) internal view returns(uint value) {
        SortitionSumTree storage tree = self.sortitionSumTrees[_key];
        uint treeIndex = tree.IDsToNodeIndexes[_ID];

        if (treeIndex == 0) value = 0;
        else value = tree.nodes[treeIndex];
    }

    function total(SortitionSumTrees storage self, bytes32 _key) internal view returns (uint) {
        SortitionSumTree storage tree = self.sortitionSumTrees[_key];
        if (tree.nodes.length == 0) {
            return 0;
        } else {
            return tree.nodes[0];
        }
    }

    /* Private */

    /**
     *  @dev Update all the parents of a node.
     *  @param _key The key of the tree to update.
     *  @param _treeIndex The index of the node to start from.
     *  @param _plusOrMinus Wether to add (true) or substract (false).
     *  @param _value The value to add or substract.
     *  `O(log_k(n))` where
     *  `k` is the maximum number of childs per node in the tree,
     *   and `n` is the maximum number of nodes ever appended.
     */
    function updateParents(SortitionSumTrees storage self, bytes32 _key, uint _treeIndex, bool _plusOrMinus, uint _value) private {
        SortitionSumTree storage tree = self.sortitionSumTrees[_key];

        uint parentIndex = _treeIndex;
        while (parentIndex != 0) {
            parentIndex = (parentIndex - 1) / tree.K;
            tree.nodes[parentIndex] = _plusOrMinus ? tree.nodes[parentIndex] + _value : tree.nodes[parentIndex] - _value;
        }
    }
}

/**
Copyright 2019 PoolTogether LLC

This file is part of PoolTogether.

PoolTogether is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation under version 3 of the License.

PoolTogether is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with PoolTogether.  If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity >=0.6.0 <0.8.0;

/**
 * @author Brendan Asselstine
 * @notice A library that uses entropy to select a random number within a bound.  Compensates for modulo bias.
 * @dev Thanks to https://medium.com/hownetworks/dont-waste-cycles-with-modulo-bias-35b6fdafcf94
 */
library UniformRandomNumber {
  /// @notice Select a random number without modulo bias using a random seed and upper bound
  /// @param _entropy The seed for randomness
  /// @param _upperBound The upper bound of the desired number
  /// @return A random number less than the _upperBound
  function uniform(uint256 _entropy, uint256 _upperBound) internal pure returns (uint256) {
    require(_upperBound > 0, "UniformRand/min-bound");
    uint256 min = -_upperBound % _upperBound;
    uint256 random = _entropy;
    while (true) {
      if (random >= min) {
        break;
      }
      random = uint256(keccak256(abi.encodePacked(random)));
    }
    return random % _upperBound;
  }
}

pragma solidity >=0.4.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/// @title Defines the functions used to interact with GrimToken from Beefy finance.
interface IGrimToken is IERC20Upgradeable {
    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    /**
     * @dev The entrypoint of funds into the system. People deposit with this function
     * into the vault. The vault is then in charge of sending funds into the strategy.
     */
    function deposit(uint256 _amount) external;

    /**
     * @dev Function to exit the system. The vault will withdraw the required tokens
     * from the strategy and pay up the token holder. A proportional number of IOU
     * tokens are burned in the process.
     */
    function withdraw(uint256 _shares) external;

    /**
     * @dev Function for various UIs to display the current value of one of our yield tokens.
     * Returns an uint256 with 18 decimals of how much underlying asset one vault share represents.
     */
    function getPricePerFullShare() external view returns (uint256);

    function balance() external view returns (uint256);
}

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";

import "../prize-pool/IPrizePool.sol";
import "../prize-pool/grim/IGrimToken.sol";
import "../prize-pool/grim/IYieldSource.sol";

/// @title Manager of user's funds entering PodTogether
/// @notice Manages divying up assets into prize pool and yield farming
contract GateManagerMultiRewardsUpgradeable is
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Interface for PodTogether prize pool
    IPrizePool public prizePool;

    // prize pool lottery token
    address public prizePoolControlledToken;

    // Interface for the Yield-bearing grimToken by Beefy, empty if isGrimToken == false
    IGrimToken public grimToken;

    // deposit token, converted to grimToken if isGrimToken == true
    address public underlying;
    address public pots;
    address public ziggy;

    // if true underlying will be converted to grimToken during deposit
    bool public isGrimToken;

    // total mooTokens or underlying held by gate manager
    uint256 private _totalSupply;

    // mooTokens or underlying balances per user
    mapping(address => uint256) public balances;
    mapping(address => bool) public isPrizeToken;

    // Staking Rewards
    struct RewardInfo {
        address rewardToken;
        uint256 duration;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        uint256 rewardBalance;
    }

    RewardInfo[] public rewardInfo;

    // rewardToken => user => rewardPaid
    mapping(address => mapping(address => uint256))
        public userRewardPerTokenPaid;

    // rewardToken => user => rewardEarned
    mapping(address => mapping(address => uint256)) public rewards;

    // address which can notifyRewards
    address public notifier;

    // address zap contract
    address public zap;

    event RewardAdded(address indexed rewardToken, uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(
        address indexed user,
        address indexed rewardToken,
        uint256 reward
    );
    event NewNotifier(address NewNotifier, address oldNotifier);
    event NewZap(address NewZap, address OldZap);
    event NewZiggy(address NewZiggy, address oldZiggy);

    /// @notice set up GateManger
    /// @param _grimToken Address of the Beefy grimToken interface
    /// @param _prizePool Address of the PodTogether prize pool
    /// @param _underlying Address of the token to add to the pools
    /// @param _prizePoolControlledToken Address of prize pool token aka lottery tickets
    function initialize(
        IGrimToken _grimToken,
        IPrizePool _prizePool,
        address _underlying,
        address _prizePoolControlledToken,
        uint256 _stakingRewardsDuration,
        bool _isGrimToken,
        address _notifier,
        address _zap
    ) public initializer {
        grimToken = _grimToken;
        prizePool = _prizePool;
        underlying = _underlying;
        prizePoolControlledToken = _prizePoolControlledToken;
        isGrimToken = _isGrimToken;
        notifier = _notifier;
        zap = _zap;

        rewardInfo.push(
            RewardInfo({
                rewardToken: _underlying,
                duration: _stakingRewardsDuration,
                periodFinish: 0,
                rewardRate: 0,
                lastUpdateTime: 0,
                rewardPerTokenStored: 0,
                rewardBalance: 0
            })
        );

        isPrizeToken[_underlying] = true;

        __Ownable_init();
    }

    // checks that caller is either owner or notifier.
    modifier onlyNotifier() {
        require(msg.sender == owner() || msg.sender == notifier, "!notifier");
        _;
    }

    // checks that caller is either owner or notifier.
    modifier onlyZap() {
        require(msg.sender == zap, "!Only Zap");
        _;
    }

    // Updates state and is called on deposit, withdraw & claim
    modifier updateReward(address account) {
        for (uint256 i; i < rewardInfo.length; i++) {
            rewardInfo[i].rewardPerTokenStored = rewardPerToken(i);
            rewardInfo[i].lastUpdateTime = lastTimeRewardApplicable(i);
            if (account != address(0)) {
                rewards[rewardInfo[i].rewardToken][account] = earned(
                    account,
                    i
                );
                userRewardPerTokenPaid[rewardInfo[i].rewardToken][
                    account
                ] = rewardInfo[i].rewardPerTokenStored;
            }
        }
        _;
    }

    // Total supply for math to pay the reward pool users
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    // Returns number of reward tokens in the contract
    function rewardTokenLength() external view returns (uint256) {
        return rewardInfo.length;
    }

    // Last time rewards will be paid per reward id
    function lastTimeRewardApplicable(uint256 id)
        public
        view
        returns (uint256)
    {
        return
            MathUpgradeable.min(block.timestamp, rewardInfo[id].periodFinish);
    }

    // Rewards per token based on reward id
    function rewardPerToken(uint256 id) public view returns (uint256) {
        RewardInfo storage info = rewardInfo[id];
        if (totalSupply() == 0) {
            return info.rewardPerTokenStored;
        }
        return
            info.rewardPerTokenStored.add(
                lastTimeRewardApplicable(id)
                    .sub(info.lastUpdateTime)
                    .mul(info.rewardRate)
                    .mul(1e18)
                    .div(totalSupply())
            );
    }

    // returns earned amount based on user and reward id
    function earned(address account, uint256 id) public view returns (uint256) {
        RewardInfo storage info = rewardInfo[id];
        return
            balances[account]
                .mul(
                    rewardPerToken(id).sub(
                        userRewardPerTokenPaid[info.rewardToken][account]
                    )
                )
                .div(1e18)
                .add(rewards[info.rewardToken][account]);
    }

    // Converts mooTokens to underlying if isGrimToken == true
    function convertToUnderlying(uint256 amount) public view returns (uint256) {
        uint256 underlyingAmount;
        if (isGrimToken == false || grimToken.totalSupply() == 0) {
            underlyingAmount = amount;
        } else {
            underlyingAmount = amount.mul(grimToken.balance()).div(
                grimToken.totalSupply()
            );
        }
        return underlyingAmount;
    }

    // Returns TVL, PrizePool + GateManager totalSupply
    function TVL() external view returns (uint256) {
        uint256 totalYieldSourceBal = IYieldSource(prizePool.yieldSource())
            .totalYieldTokenAmount();
        uint256 underlyingAmountYS = convertToUnderlying(totalYieldSourceBal);
        uint256 underlyingAmountGM = convertToUnderlying(totalSupply());
        return underlyingAmountYS.add(underlyingAmountGM);
    }

    // Returns total award balance, PrizePool - tickets
    function awardBalance() external view returns (uint256) {
        uint256 ticketTotalSupply = IERC20Upgradeable(prizePoolControlledToken)
            .totalSupply();
        uint256 totalYieldBal = IYieldSource(prizePool.yieldSource())
            .totalYieldTokenAmount();
        uint256 underlyingAmount = convertToUnderlying(totalYieldBal);
        return underlyingAmount.sub(ticketTotalSupply);
    }

    /// Returns user total balance
    function userTotalBalance(address user) external view returns (uint256) {
        uint256 ticketBal = IERC20Upgradeable(prizePoolControlledToken)
            .balanceOf(user);
        uint256 yieldBal = balances[user];
        uint256 underlyingAmount = convertToUnderlying(yieldBal);
        return ticketBal.add(underlyingAmount);
    }

    /// Deposit all want tokens in a user address
    function depositAll(address referrer) external {
        uint256 tokenBal = IERC20Upgradeable(underlying).balanceOf(msg.sender);
        depositPodTogether(tokenBal, referrer);
    }

    /// Deposit amount of want tokens in a user address
    function depositPodTogether(uint256 amount, address referrer) public {
        depositPodTogether(msg.sender, amount, referrer);
    }

    /// @notice Supplies underlying token. 1/2 to PodTogether prize pool and 1/2 to Moo vault.
    /// @param user The address where to account deposit
    /// @param amount The amount of `underlying` to be supplied
    /// @param referrer Partners may receive commission from ticket referral
    function depositPodTogether(
        address user,
        uint256 amount,
        address referrer
    ) public nonReentrant updateReward(user) {
        require(amount > 0, "Cannot stake 0");
        uint256 balBefore = IERC20Upgradeable(underlying).balanceOf(
            address(this)
        );
        IERC20Upgradeable(underlying).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        uint256 halvedAmount = amount.div(2);

        // deposit to PodTogether prize pool
        IERC20Upgradeable(underlying).safeApprove(
            address(prizePool),
            amount - halvedAmount
        );
        prizePool.depositTo(
            user,
            amount - halvedAmount,
            prizePoolControlledToken,
            referrer
        );

        if (isGrimToken) {
            // deposit yield farming
            IERC20Upgradeable(underlying).safeApprove(
                address(grimToken),
                halvedAmount
            );
            uint256 mooTokenBalBefore = grimToken.balanceOf(address(this));
            grimToken.deposit(halvedAmount);
            uint256 mooTokenDiff = grimToken.balanceOf(address(this)).sub(
                mooTokenBalBefore
            );
            _totalSupply = _totalSupply.add(mooTokenDiff);
            balances[user] = balances[user].add(mooTokenDiff);
            emit Staked(user, mooTokenDiff);
        } else {
            uint256 balAfter = IERC20Upgradeable(underlying).balanceOf(
                address(this)
            );
            uint256 balDiff = balAfter.sub(balBefore);
            _totalSupply = _totalSupply.add(balDiff);
            balances[user] = balances[user].add(balDiff);
            emit Staked(user, balDiff);
        }
    }

    /// Withdraw all sender funds with possible exit fee & claim rewards
    function exitInstantly() external {
        getReward();
        withdrawAllInstantly();
    }

    /// Withdraw all sender funds with possible exit fee
    function withdrawAllInstantly() public {
        uint256 ticketBal = IERC20Upgradeable(prizePoolControlledToken)
            .balanceOf(msg.sender);
        if (ticketBal > 0) {
            withdrawInstantlyFromPodTogetherPrizePool(ticketBal);
        }

        uint256 yieldBal = balances[msg.sender];
        if (yieldBal > 0) {
            _withdrawPodTogetherYieldShares(msg.sender, yieldBal);
        }
    }

    /// @notice withdraw underlying from yield earning vault
    /// @param amount The amount of `underlying` to withdraw.
    function withdrawPodTogetherYield(uint256 amount) public {
        uint256 sharesAmount;
        if (isGrimToken == false || grimToken.totalSupply() == 0) {
            sharesAmount = amount;
        } else {
            // Beefy Vault's withdraw function is looking for a "share amount".
            sharesAmount = amount.mul(grimToken.totalSupply()).div(
                grimToken.balance()
            );
        }
        _withdrawPodTogetherYieldShares(msg.sender, sharesAmount);
    }

    /// @notice withdraw a users shares from yield earning vault
    /// @param shares The amount of shares to withdraw.
    /// if isGrimToken == false, shares == underlyingAmount
    function withdrawPodTogetherYieldShares(address user, uint256 shares)
        external
        onlyZap
    {
        _withdrawPodTogetherYieldShares(user, shares);
    }

    /// @notice withdraw shares from yield earning vault
    /// @param shares The amount of shares to withdraw.
    /// if isGrimToken == false, shares == underlyingAmount
    function _withdrawPodTogetherYieldShares(address user, uint256 shares)
        internal
        nonReentrant
        updateReward(user)
    {
        if (isGrimToken) {
            uint256 mooTokenBalanceBefore = grimToken.balanceOf(address(this));
            uint256 balanceBefore = IERC20Upgradeable(underlying).balanceOf(
                address(this)
            );

            grimToken.withdraw(shares);

            uint256 mooTokenDiff = mooTokenBalanceBefore.sub(
                grimToken.balanceOf(address(this))
            );
            uint256 diff = IERC20Upgradeable(underlying)
                .balanceOf(address(this))
                .sub(balanceBefore);

            balances[user] = balances[user].sub(mooTokenDiff);
            _totalSupply = _totalSupply.sub(mooTokenDiff);
            IERC20Upgradeable(underlying).safeTransfer(user, diff);
            emit Withdrawn(user, diff);
        } else {
            balances[user] = balances[user].sub(shares);
            _totalSupply = _totalSupply.sub(shares);
            IERC20Upgradeable(underlying).safeTransfer(user, shares);
            emit Withdrawn(user, shares);
        }
    }

    /// @notice withdraw from prize pool with possible exit fee.
    /// @param amount The amount of controlled prize pool token to redeem for underlying.
    function withdrawInstantlyFromPodTogetherPrizePool(uint256 amount)
        public
        nonReentrant
    {
        require(
            IERC20Upgradeable(prizePoolControlledToken).allowance(
                msg.sender,
                address(this)
            ) >= amount,
            "GateManager: approve contract to withdraw for you"
        );

        (uint256 exitFee, ) = prizePool.calculateEarlyExitFee(
            msg.sender,
            prizePoolControlledToken,
            amount
        );

        uint256 actualFee = prizePool.withdrawInstantlyFrom(
            msg.sender,
            amount,
            prizePoolControlledToken,
            exitFee
        );
        require(actualFee <= exitFee, "!fee");
    }

    // Compound user stake reward if extra is give, will extend users fair play
    function compound() external updateReward(msg.sender) {
        uint256 earnedAmt = earned(msg.sender, 0);
        getReward(0);
        depositPodTogether(earnedAmt, address(0));
    }

    // User claims rewards from individual reward pool
    function getReward(uint256 id) public {
        getReward(msg.sender, id);
    }

    // User claims rewards from individual reward pool
    function getReward(address user, uint256 id) public updateReward(user) {
        uint256 reward = earned(user, id);
        if (reward > 0) {
            address token = rewardInfo[id].rewardToken;
            rewards[token][user] = 0;
            rewardInfo[id].rewardBalance = rewardInfo[id].rewardBalance.sub(
                reward
            );
            IERC20Upgradeable(token).safeTransfer(user, reward);
            emit RewardPaid(user, token, reward);
        }
    }

    // User claims all available rewards
    function getReward() public {
        getReward(msg.sender);
    }

    // User claims all available rewards
    function getReward(address user) public updateReward(user) {
        for (uint256 i; i < rewardInfo.length; i++) {
            uint256 reward = earned(user, i);
            if (reward > 0) {
                address token = rewardInfo[i].rewardToken;
                rewards[token][user] = 0;
                rewardInfo[i].rewardBalance = rewardInfo[i].rewardBalance.sub(
                    reward
                );
                IERC20Upgradeable(token).safeTransfer(user, reward);
                emit RewardPaid(user, token, reward);
            }
        }
    }

    // Adds new reward token to the gate manager
    function addRewardToken(address _rewardToken, uint256 _duration)
        external
        onlyNotifier
    {
        require(_rewardToken != address(grimToken), "Can't reward grimToken");
        require(
            isPrizeToken[_rewardToken] == false,
            "Can't add exisiting prize token"
        );
        rewardInfo.push(
            RewardInfo({
                rewardToken: _rewardToken,
                duration: _duration,
                periodFinish: 0,
                rewardRate: 0,
                lastUpdateTime: 0,
                rewardPerTokenStored: 0,
                rewardBalance: 0
            })
        );
        isPrizeToken[_rewardToken] = true;
    }

    // Sets notifier
    function setNotifier(address newNotifier) external onlyOwner {
        emit NewNotifier(newNotifier, notifier);
        notifier = newNotifier;
    }

    // Upgrade Zap
    function setZap(address newZap) external onlyOwner {
        emit NewZap(newZap, zap);
        zap = newZap;
    }

    // Sets new reward duration for existing reward token
    function setRewardDuration(uint256 id, uint256 rewardDuration)
        external
        onlyOwner
    {
        require(block.timestamp >= rewardInfo[id].periodFinish);
        rewardInfo[id].duration = rewardDuration;
    }

    // Set Ziggy Prize Pool in case of upgrade
    function setZiggy(address newZiggy) external onlyOwner {
        emit NewZiggy(ziggy, newZiggy);
        IERC20Upgradeable(pots).safeApprove(address(ziggy), 0);
        ziggy = newZiggy;
        IERC20Upgradeable(pots).safeApprove(
            address(newZiggy),
            type(uint256).max
        );
    }

    // Tells gate manager the reward amount per each reward token
    function notifyRewardAmount(uint256 id, uint256 reward)
        external
        onlyNotifier
        updateReward(address(0))
    {
        RewardInfo storage info = rewardInfo[id];

        uint256 balance = IERC20Upgradeable(info.rewardToken).balanceOf(
            address(this)
        );
        uint256 userRewards = info.rewardBalance;
        if (info.rewardToken == address(underlying) && isGrimToken == false) {
            userRewards = userRewards.add(totalSupply());
        }
        require(reward <= balance.sub(userRewards), "!too many rewards");

        if (block.timestamp >= info.periodFinish) {
            info.rewardRate = reward.div(info.duration);
        } else {
            uint256 remaining = info.periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(info.rewardRate);
            info.rewardRate = reward.add(leftover).div(info.duration);
        }
        info.rewardBalance = info.rewardBalance.add(reward);
        info.lastUpdateTime = block.timestamp;
        info.periodFinish = block.timestamp.add(info.duration);
        emit RewardAdded(info.rewardToken, reward);
    }

    // In case of airdrops or wrong tokens sent to gate manager
    function inCaseTokensGetStuck(address _token) external onlyOwner {
        require(_token != address(grimToken), "!staked");
        require(_token != address(underlying), "!underlying");
        require(_token != address(prizePoolControlledToken), "!ticket");

        uint256 amount = IERC20Upgradeable(_token).balanceOf(address(this));
        IERC20Upgradeable(_token).safeTransfer(msg.sender, amount);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library MathUpgradeable {
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

pragma solidity >=0.6.0 <0.8.0;

import "../token/TokenListenerInterface.sol";

/// @title Escrows assets and deposits them into a yield source.  Exposes interest to Prize Strategy.  Users deposit and withdraw from this contract to participate in Prize Pool.
/// @notice Accounting is managed using Controlled Tokens, whose mint and burn functions can only be called by this contract.
/// @dev Must be inherited to provide specific yield-bearing asset control, such as Compound cTokens
interface IPrizePool {
    /// @notice Deposit assets into the Prize Pool in exchange for tokens
    /// @param to The address receiving the newly minted tokens
    /// @param amount The amount of assets to deposit
    /// @param controlledToken The address of the type of token the user is minting
    /// @param referrer The referrer of the deposit
    function depositTo(
        address to,
        uint256 amount,
        address controlledToken,
        address referrer
    ) external;

    /// @notice Withdraw assets from the Prize Pool instantly.  A fairness fee may be charged for an early exit.
    /// @param from The address to redeem tokens from.
    /// @param amount The amount of tokens to redeem for assets.
    /// @param controlledToken The address of the token to redeem (i.e. ticket or sponsorship)
    /// @param maximumExitFee The maximum exit fee the caller is willing to pay.  This should be pre-calculated by the calculateExitFee() fxn.
    /// @return The actual exit fee paid
    function withdrawInstantlyFrom(
        address from,
        uint256 amount,
        address controlledToken,
        uint256 maximumExitFee
    ) external returns (uint256);

    function withdrawReserve(address to) external returns (uint256);

    /// @notice Returns the balance that is available to award.
    /// @dev captureAwardBalance() should be called first
    /// @return The total amount of assets to be awarded for the current prize
    function awardBalance() external view returns (uint256);

    /// @notice Captures any available interest as award balance.
    /// @dev This function also captures the reserve fees.
    /// @return The total amount of assets to be awarded for the current prize
    function captureAwardBalance() external returns (uint256);

    /// @notice Called by the prize strategy to award prizes.
    /// @dev The amount awarded must be less than the awardBalance()
    /// @param to The address of the winner that receives the award
    /// @param amount The amount of assets to be awarded
    /// @param controlledToken The address of the asset token being awarded
    function award(
        address to,
        uint256 amount,
        address controlledToken
    ) external;

    /// @notice Called by the Prize-Strategy to transfer out external ERC20 tokens
    /// @dev Used to transfer out tokens held by the Prize Pool.  Could be liquidated, or anything.
    /// @param to The address of the winner that receives the award
    /// @param amount The amount of external assets to be awarded
    /// @param externalToken The address of the external asset token being awarded
    function transferExternalERC20(
        address to,
        address externalToken,
        uint256 amount
    ) external;

    /// @notice Called by the Prize-Strategy to award external ERC20 prizes
    /// @dev Used to award any arbitrary tokens held by the Prize Pool
    /// @param to The address of the winner that receives the award
    /// @param amount The amount of external assets to be awarded
    /// @param externalToken The address of the external asset token being awarded
    function awardExternalERC20(
        address to,
        address externalToken,
        uint256 amount
    ) external;

    /// @notice Called by the prize strategy to award external ERC721 prizes
    /// @dev Used to award any arbitrary NFTs held by the Prize Pool
    /// @param to The address of the winner that receives the award
    /// @param externalToken The address of the external NFT token being awarded
    /// @param tokenIds An array of NFT Token IDs to be transferred
    function awardExternalERC721(
        address to,
        address externalToken,
        uint256[] calldata tokenIds
    ) external;

    /// @notice Sweep all timelocked balances and transfer unlocked assets to owner accounts
    /// @param users An array of account addresses to sweep balances for
    /// @return The total amount of assets swept from the Prize Pool
    function sweepTimelockBalances(address[] calldata users)
        external
        returns (uint256);

    /// @notice Calculates a timelocked withdrawal duration and credit consumption.
    /// @param from The user who is withdrawing
    /// @param amount The amount the user is withdrawing
    /// @param controlledToken The type of collateral the user is withdrawing (i.e. ticket or sponsorship)
    /// @return durationSeconds The duration of the timelock in seconds
    function calculateTimelockDuration(
        address from,
        address controlledToken,
        uint256 amount
    ) external returns (uint256 durationSeconds, uint256 burnedCredit);

    /// @notice Calculates the early exit fee for the given amount
    /// @param from The user who is withdrawing
    /// @param controlledToken The type of collateral being withdrawn
    /// @param amount The amount of collateral to be withdrawn
    /// @return exitFee The exit fee
    /// @return burnedCredit The user's credit that was burned
    function calculateEarlyExitFee(
        address from,
        address controlledToken,
        uint256 amount
    ) external returns (uint256 exitFee, uint256 burnedCredit);

    /// @notice Estimates the amount of time it will take for a given amount of funds to accrue the given amount of credit.
    /// @param _principal The principal amount on which interest is accruing
    /// @param _interest The amount of interest that must accrue
    /// @return durationSeconds The duration of time it will take to accrue the given amount of interest, in seconds.
    function estimateCreditAccrualTime(
        address _controlledToken,
        uint256 _principal,
        uint256 _interest
    ) external view returns (uint256 durationSeconds);

    /// @notice Returns the credit balance for a given user.  Not that this includes both minted credit and pending credit.
    /// @param user The user whose credit balance should be returned
    /// @return The balance of the users credit
    function balanceOfCredit(address user, address controlledToken)
        external
        returns (uint256);

    /// @notice Sets the rate at which credit accrues per second.  The credit rate is a fixed point 18 number (like Ether).
    /// @param _controlledToken The controlled token for whom to set the credit plan
    /// @param _creditRateMantissa The credit rate to set.  Is a fixed point 18 decimal (like Ether).
    /// @param _creditLimitMantissa The credit limit to set.  Is a fixed point 18 decimal (like Ether).
    function setCreditPlanOf(
        address _controlledToken,
        uint128 _creditRateMantissa,
        uint128 _creditLimitMantissa
    ) external;

    /// @notice Returns the credit rate of a controlled token
    /// @param controlledToken The controlled token to retrieve the credit rates for
    /// @return creditLimitMantissa The credit limit fraction.  This number is used to calculate both the credit limit and early exit fee.
    /// @return creditRateMantissa The credit rate. This is the amount of tokens that accrue per second.
    function creditPlanOf(address controlledToken)
        external
        view
        returns (uint128 creditLimitMantissa, uint128 creditRateMantissa);

    /// @notice Allows the Governor to set a cap on the amount of liquidity that he pool can hold
    /// @param _liquidityCap The new liquidity cap for the prize pool
    function setLiquidityCap(uint256 _liquidityCap) external;

    /// @notice Sets the prize strategy of the prize pool.  Only callable by the owner.
    /// @param _prizeStrategy The new prize strategy.  Must implement TokenListenerInterface
    function setPrizeStrategy(TokenListenerInterface _prizeStrategy) external;

    /// @dev Returns the address of the underlying ERC20 asset
    /// @return The address of the asset
    function token() external view returns (address);

    /// @notice An array of the Tokens controlled by the Prize Pool (ie. Tickets, Sponsorship)
    /// @return An array of controlled token addresses
    function tokens() external view returns (address[] memory);

    /// @notice The total of all controlled tokens and timelock.
    /// @return The current total of all tokens and timelock.
    function accountedBalance() external view returns (uint256);

    function yieldSource() external view returns (address);
}

pragma solidity >=0.4.0 <0.8.0;

/// @title Defines the functions used to interact with MooToken from Beefy finance.
interface IYieldSource {
    function totalYieldTokenAmount() external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.7.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./RegistryInterface.sol";

/// @title Interface that allows a user to draw an address using an index
contract Registry is OwnableUpgradeable, RegistryInterface {
  address private pointer;

  event Registered(address indexed pointer);

  constructor () public {
    __Ownable_init();
  }

  function register(address _pointer) external onlyOwner {
    pointer = _pointer;

    emit Registered(pointer);
  }

  function lookup() external override view returns (address) {
    return pointer;
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../PrizeSplit.sol";
import "../PeriodicPrizeStrategy.sol";
import "../../external/lib/UniformRandom.sol";

contract MultipleWinners is PeriodicPrizeStrategy {
    uint256 internal __numberOfWinners;

    bool public splitExternalErc20Awards;
    bool public splitExternalErc721Awards;

    uint256 public fee = 200;
    uint256 public scale = 1000;

    event SplitExternalErc20AwardsSet(bool splitExternalErc20Awards);
    event SplitExternalErc721AwardsSet(bool splitExternalErc721Awards);

    event NumberOfWinnersSet(uint256 numberOfWinners);

    event NoWinners();

    function initializeMultipleWinners(
        uint256 _prizePeriodStart,
        uint256 _prizePeriodSeconds,
        PrizePool _prizePool,
        TicketInterface _ticket,
        IERC20Upgradeable _sponsorship,
        RNGInterface _rng,
        uint256 _numberOfWinners
    ) public initializer {
        IERC20Upgradeable[] memory _externalErc20Awards;

        PeriodicPrizeStrategy.initialize(
            _prizePeriodStart,
            _prizePeriodSeconds,
            _prizePool,
            _ticket,
            _sponsorship,
            _rng,
            _externalErc20Awards
        );

        _setNumberOfWinners(_numberOfWinners);
    }

    function setSplitExternalErc20Awards(bool _splitExternalErc20Awards)
        external
        onlyOwner
        requireAwardNotInProgress
    {
        splitExternalErc20Awards = _splitExternalErc20Awards;

        emit SplitExternalErc20AwardsSet(splitExternalErc20Awards);
    }

    function setSplitExternalErc721Awards(bool _splitExternalErc721Awards)
        external
        onlyOwner
        requireAwardNotInProgress
    {
        splitExternalErc721Awards = _splitExternalErc721Awards;

        emit SplitExternalErc20AwardsSet(splitExternalErc721Awards);
    }

    function setNumberOfWinners(uint256 count)
        external
        onlyOwner
        requireAwardNotInProgress
    {
        _setNumberOfWinners(count);
    }

    function _setNumberOfWinners(uint256 count) internal {
        require(count > 0, "MultipleWinners/winners-gte-one");

        __numberOfWinners = count;
        emit NumberOfWinnersSet(count);
    }

    function numberOfWinners() external view returns (uint256) {
        return __numberOfWinners;
    }

    function _distribute(uint256 randomNumber) internal override {
        uint256 prize = prizePool.captureAwardBalance();

        // uint256 f = prize.mul(fee).div(scale);
        // _awardTickets(owner(), f);
        // prize = prize.sub(f);

        // main winner is simply the first that is drawn
        address mainWinner = ticket.draw(randomNumber);

        // If drawing yields no winner, then there is no one to pick
        if (mainWinner == address(0)) {
            emit NoWinners();
            return;
        }

        address[] memory winners = new address[](__numberOfWinners);
        winners[0] = mainWinner;

        uint256 nextRandom = randomNumber;
        for (
            uint256 winnerCount = 1;
            winnerCount < __numberOfWinners;
            winnerCount++
        ) {
            // add some arbitrary numbers to the previous random number to ensure no matches with the UniformRandomNumber lib
            bytes32 nextRandomHash = keccak256(
                abi.encodePacked(nextRandom + 499 + winnerCount * 521)
            );
            nextRandom = uint256(nextRandomHash);
            winners[winnerCount] = ticket.draw(nextRandom);
        }

        // yield prize is split up among all winners
        uint256 prizeShare = prize.div(winners.length);
        if (prizeShare > 0) {
            for (uint256 i = 0; i < winners.length; i++) {
                _awardTickets(winners[i], prizeShare);
            }
        }

        if (splitExternalErc721Awards) {
            address currentToken = externalErc721s.start();
            while (
                currentToken != address(0) &&
                currentToken != externalErc721s.end()
            ) {
                for (uint256 i = 0; i < winners.length; i++) {
                    uint256[] memory allTokenIds = externalErc721TokenIds[
                        IERC721Upgradeable(currentToken)
                    ];
                    uint256 bound = allTokenIds.length;
                    if (bound > 0) {
                        uint256 selectedIndex = UniformRandomNumber.uniform(
                            randomNumber,
                            bound
                        );
                        uint256[] memory tokenIds = new uint256[](1);
                        tokenIds[0] = allTokenIds[selectedIndex];
                        prizePool.awardExternalERC721(
                            winners[i],
                            currentToken,
                            tokenIds
                        );
                        _removeExternalErc721AwardTokenIdByIndex(
                            IERC721Upgradeable(currentToken),
                            selectedIndex
                        );
                    }
                }
                currentToken = externalErc721s.next(currentToken);
            }
        } else {
            // main winner gets all external ERC721 tokens
            _awardExternalErc721s(mainWinner);
        }

        if (splitExternalErc20Awards) {
            address currentToken = externalErc20s.start();
            while (
                currentToken != address(0) &&
                currentToken != externalErc20s.end()
            ) {
                uint256 balance = IERC20Upgradeable(currentToken).balanceOf(
                    address(prizePool)
                );
                uint256 split = balance.div(__numberOfWinners);
                if (split > 0) {
                    for (uint256 i = 0; i < winners.length; i++) {
                        prizePool.awardExternalERC20(
                            winners[i],
                            currentToken,
                            split
                        );
                    }
                }
                currentToken = externalErc20s.next(currentToken);
            }
        } else {
            _awardExternalErc20s(mainWinner);
        }
    }
}

pragma solidity >=0.6.0 <0.8.0;

/**
 * @author Brendan Asselstine
 * @notice A library that uses entropy to select a random number within a bound.  Compensates for modulo bias.
 * @dev Thanks to https://medium.com/hownetworks/dont-waste-cycles-with-modulo-bias-35b6fdafcf94
 */
library UniformRandomNumber {
    /// @notice Select a random number without modulo bias using a random seed and upper bound
    /// @param _entropy The seed for randomness
    /// @param _upperBound The upper bound of the desired number
    /// @return A random number less than the _upperBound
    function uniform(uint256 _entropy, uint256 _upperBound)
        internal
        pure
        returns (uint256)
    {
        require(_upperBound > 0, "UniformRand/min-bound");
        uint256 min = -_upperBound % _upperBound;
        uint256 random = _entropy;
        while (true) {
            if (random >= min) {
                break;
            }
            random = uint256(keccak256(abi.encodePacked(random)));
        }
        return random % _upperBound;
    }
}