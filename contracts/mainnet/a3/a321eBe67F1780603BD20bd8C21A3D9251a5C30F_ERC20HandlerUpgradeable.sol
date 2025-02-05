// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IDepositExecute.sol";
import "../interfaces/ILiquidityPool.sol";
import "../interfaces/IOneSplitWrap.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/IERC20Upgradeable.sol";
import "./HandlerHelpersUpgradeable.sol";

/**
    @title Handles ERC20 deposits and deposit executions.
    @author Router Protocol.
    @notice This contract is intended to be used with the Bridge contract.
 */
contract ERC20HandlerUpgradeable is
    Initializable,
    ContextUpgradeable,
    IDepositExecute,
    HandlerHelpersUpgradeable,
    ILiquidityPool
{
    using SafeMathUpgradeable for uint256;

    struct DepositRecord {
        uint8 _destinationChainID;
        address _srcTokenAddress;
        address _stableTokenAddress;
        uint256 _stableTokenAmount;
        address _destStableTokenAddress;
        uint256 _destStableTokenAmount;
        address _destinationTokenAdress;
        uint256 _destinationTokenAmount;
        bytes32 _resourceID;
        address _destinationRecipientAddress;
        address _depositer;
        uint256 _srcTokenAmount;
        address _feeTokenAddress;
        uint256 _feeAmount;
        uint256 _isDestNative;
    }

    // destId => depositNonce => Deposit Record
    mapping(uint8 => mapping(uint64 => DepositRecord)) private _depositRecords;

    // token contract address => chainId => decimals
    mapping(address => mapping(uint8 => uint8)) public tokenDecimals;

    mapping(uint256 => mapping(uint64 => uint256)) public executeRecord;

    // token to USD * 10**9
    mapping(address => uint256) public _tokenToUSDx10e9;

    //Unsupported chains map
    mapping(uint8 => bool) public _unsupportedChains;

    struct FeeBreakdown {
        uint256 totalFee;
        uint256 lpFee;
        uint256 validatorFee;
        uint256 protocolFee;
        uint256 widgetFee;
    }

    // destId => depositNonce => FeeBreakdown
    mapping(uint8 => mapping(uint64 => FeeBreakdown)) private _feeBreakdown;



    modifier isSupportedChain(uint8 chainId) {
        require(!_unsupportedChains[chainId], "ERC20Handler: Unsupported chain");
        _;
    }

    function __ERC20HandlerUpgradeable_init(
        address bridgeAddress,
        address ETH,
        address WETH,
        bytes32[] memory initialResourceIDs,
        address[] memory initialContractAddresses,
        address[] memory burnableContractAddresses
    ) internal initializer {
        __Context_init_unchained();
        __HandlerHelpersUpgradeable_init();

        require(
            initialResourceIDs.length == initialContractAddresses.length,
            "initialResourceIDs & initialContractAddresses len mismatch"
        );

        _bridgeAddress = bridgeAddress;
        _ETH = ETH;
        _WETH = WETH;

        uint256 initialResourceCount = initialResourceIDs.length;
        for (uint256 i = 0; i < initialResourceCount; i++) {
            _setResource(initialResourceIDs[i], initialContractAddresses[i]);
        }

        uint256 burnableCount = burnableContractAddresses.length;
        for (uint256 i = 0; i < burnableCount; i++) {
            _setBurnable(burnableContractAddresses[i], true);
        }
    }

    function __ERC20HandlerUpgradeable_init_unchained() internal initializer {}

    /**
        @param bridgeAddress Contract address of previously deployed Bridge.
        // Resource IDs are used to identify a specific contract address.
        // These are the Resource IDs this contract will initially support.
        // These are the addresses the {initialResourceIDs} will point to,
        // and are the contracts that will be called to perform various deposit calls.
        @param burnableContractAddresses These addresses will be set as burnable and when {deposit} is called,
        the deposited token will be burned.
        When {executeProposal} is called, new tokens will be minted.

        @dev {initialResourceIDs} and {initialContractAddresses} must have the same length
        (one resourceID for every address).
        Also, these arrays must be ordered in the way that {initialResourceIDs}[0] is the
        intended resourceID for {initialContractAddresses}[0].
     */
    function initialize(
        address bridgeAddress,
        address ETH,
        address WETH,
        bytes32[] memory initialResourceIDs,
        address[] memory initialContractAddresses,
        address[] memory burnableContractAddresses
    ) external initializer {
        __ERC20HandlerUpgradeable_init(
            bridgeAddress,
            ETH,
            WETH,
            initialResourceIDs,
            initialContractAddresses,
            burnableContractAddresses
        );
    }

    receive() external payable {}

    /**
        @notice Used to get fee token price in USD * 10**9. 
        @param  token Address of the token.
     */
    function getTokenToUSDx10e9(address token) public view returns (uint256) {
        return _tokenToUSDx10e9[token];
    }

    /**
        @notice Used to set support for a chain
        @param  destChainId the chain id of destination chain
        @param  isUnsupported true to remove support and false to start supporting again
    */

    function setUnsupportedChain(uint8 destChainId, bool isUnsupported) public virtual onlyRole(BRIDGE_ROLE) {
        _unsupportedChains[destChainId] = isUnsupported;
        emit UnsupportedChain(destChainId, isUnsupported);
    }

    /**
        @notice Used to set fee token price in USD * 10**9 manually. 
        @notice Only callable by Bridge.
        @param  token Address of the tokens.
        @param  priceInUSDx10e9 Prices in USD * 10**9.
     */
    function setTokenToUSDx10e9(address[] calldata token, uint256[] calldata priceInUSDx10e9)
        external
        virtual
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(token.length == priceInUSDx10e9.length, "ERC20Handler: Array length mismatch");
        for (uint256 i = 0; i < token.length; i++) {
            _tokenToUSDx10e9[token[i]] = priceInUSDx10e9[i];
        }
        feeManager.setFeeTokenToPriceX10e9(token, priceInUSDx10e9);
    }

    function setTokenDecimals(
        address[] calldata tokenAddress,
        uint8[] calldata destinationChainID,
        uint8[] calldata decimals
    ) public onlyRole(BRIDGE_ROLE) {
        require(
            tokenAddress.length == destinationChainID.length && tokenAddress.length == decimals.length,
            "ERC20Handler: Array size mismatch"
        );

        for (uint256 i = 0; i < tokenAddress.length; i++) {
            require(_contractWhitelist[tokenAddress[i]], "ERC20Handler: provided contract is not whitelisted");
            tokenDecimals[tokenAddress[i]][destinationChainID[i]] = decimals[i];
        }
    }

    function changePrecision(
        address token,
        uint8 chainId,
        uint256 tokenAmount
    ) public view returns (uint256) {
        IERC20Upgradeable srcToken = IERC20Upgradeable(token);
        require(tokenDecimals[token][chainId] > 0, "Decimals not set for token and chain id");
        uint8 srcDecimal = srcToken.decimals();
        uint8 destDecimal = tokenDecimals[token][chainId];
        if (srcDecimal == destDecimal) return tokenAmount;
        if (srcDecimal > destDecimal) {
            uint256 factor = (10**(srcDecimal - destDecimal));
            return tokenAmount / factor;
        } else {
            uint256 factor = (10**(destDecimal - srcDecimal));
            return tokenAmount * factor;
        }
    }

    function setExecuteRecord(uint256 chainId, uint64 nonce) internal {
        executeRecord[chainId][nonce] = block.number;
    }

    /**
        @param depositNonce This ID will have been generated by the Bridge contract.
        @param destId ID of chain deposit will be bridged to.
        @return DepositRecord
    */
    function getDepositRecord(uint64 depositNonce, uint8 destId) public view virtual returns (DepositRecord memory) {
        return _depositRecords[destId][depositNonce];
    }

    function setReserve(IHandlerReserve reserve) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _reserve = reserve;
    }

    /**
        @notice A deposit is initiatied by making a deposit in the Bridge contract.
        @param destinationChainID Chain ID of chain tokens are expected to be bridged to.
        @param depositNonce This value is generated as an ID by the Bridge contract.
        @dev Depending if the corresponding {tokenAddress} for the parsed {resourceID} is
        marked true in {_burnList}, deposited tokens will be burned, if not, they will be locked.
     */
    function deposit(
        bytes32 resourceID,
        uint8 destinationChainID,
        uint64 depositNonce,
        SwapInfo memory swapDetails,
        address sender
    ) public virtual override isSupportedChain(destinationChainID) onlyRole(BRIDGE_ROLE) {
        uint256[] memory feeAmount;
        swapDetails.srcStableTokenAddress = _resourceIDToTokenContractAddress[resourceID];

        require(_contractWhitelist[swapDetails.srcStableTokenAddress], "provided tokenAddress is not whitelisted");

        require(sender != address(0), "ERC20 Handler: sender is address(0)");

        require(
            getTokenToUSDx10e9(address(swapDetails.srcStableTokenAddress)) != 0,
            "ERC20 Handler: price not set for this token"
        );

        uint256 destStableTokenAmount = changePrecision(
            address(swapDetails.srcStableTokenAddress),
            destinationChainID,
            swapDetails.srcStableTokenAmount
        );
        require(destStableTokenAmount > 0, "Transfer amount too low");

        uint256 priceInUSDx10e9 = getTokenToUSDx10e9(address(swapDetails.srcStableTokenAddress));
        uint8 decimals = tokenDecimals[address(swapDetails.srcStableTokenAddress)][destinationChainID];

        uint256 txVolInUSDx1000 = (swapDetails.srcStableTokenAmount * priceInUSDx10e9) / (10**(decimals + 6));

        if (address(swapDetails.srcTokenAddress) == swapDetails.srcStableTokenAddress) {
            require(swapDetails.srcStableTokenAmount == swapDetails.srcTokenAmount, "Invalid token amount");
            if (swapDetails.feeTokenAddress == address(0)) {
                swapDetails.feeTokenAddress = swapDetails.srcStableTokenAddress;
            }
            uint256[] memory transferFee = getBridgeFee(
                destinationChainID,
                address(swapDetails.srcTokenAddress),
                address(swapDetails.destTokenAddress),
                swapDetails.feeTokenAddress,
                swapDetails.widgetID,
                txVolInUSDx1000,
                sender
            );

            feeAmount = transferFee;
            // Fees of stable token address
            _reserve.deductFee(
                swapDetails.feeTokenAddress,
                swapDetails.depositer,
                // swapDetails.providedFee,
                transferFee[0],
                // _ETH,
                _isFeeEnabled,
                address(feeManager)
            );
            // just deposit
            handleDepositForReserveToken(swapDetails);
        } else if (_reserve._contractToLP(swapDetails.srcStableTokenAddress) == address(swapDetails.srcTokenAddress)) {
            require(swapDetails.srcStableTokenAmount == swapDetails.srcTokenAmount, "Invalid token amount");
            feeAmount = deductFeeAndHandleDepositForLPToken(swapDetails, destinationChainID, txVolInUSDx1000, sender);
        } else {
            if (swapDetails.feeTokenAddress != address(0)) {
                uint256[] memory exchangeFee = getBridgeFeeWithSwap(
                    destinationChainID,
                    address(swapDetails.srcTokenAddress),
                    address(swapDetails.destTokenAddress),
                    swapDetails.feeTokenAddress,
                    swapDetails.widgetID,
                    txVolInUSDx1000,
                    sender
                );
                feeAmount = exchangeFee;
                // Fees of stable token address

                _reserve.deductFee(
                    swapDetails.feeTokenAddress,
                    swapDetails.depositer,
                    // swapDetails.providedFee,
                    exchangeFee[0],
                    // _ETH,
                    _isFeeEnabled,
                    address(feeManager)
                );
            }

            _reserve.lockERC20(
                address(swapDetails.srcTokenAddress),
                swapDetails.depositer,
                _oneSplitAddress,
                swapDetails.srcTokenAmount
            );
            handleDepositForNonReserveToken(swapDetails);
            if (swapDetails.feeTokenAddress == address(0)) {
                swapDetails.feeTokenAddress = swapDetails.srcStableTokenAddress;

                uint256[] memory exchangeFee = getBridgeFeeWithSwap(
                    destinationChainID,
                    address(swapDetails.srcTokenAddress),
                    address(swapDetails.destTokenAddress),
                    swapDetails.srcStableTokenAddress,
                    swapDetails.widgetID,
                    txVolInUSDx1000,
                    sender
                );
                feeAmount = exchangeFee;

                require(
                    swapDetails.srcStableTokenAmount >= exchangeFee[0],
                    "ERC20handler : provided fee is less than the amount"
                );

                swapDetails.srcStableTokenAmount = swapDetails.srcStableTokenAmount - exchangeFee[0];
                _reserve.releaseERC20(swapDetails.feeTokenAddress, address(feeManager), exchangeFee[0]);
            }
            if (_burnList[address(swapDetails.srcStableTokenAddress)]) {
                _reserve.burnERC20(
                    address(swapDetails.srcStableTokenAddress),
                    address(_reserve),
                    swapDetails.srcStableTokenAmount
                );
            }
        }

        _depositRecords[destinationChainID][depositNonce] = DepositRecord(
            destinationChainID,
            address(swapDetails.srcTokenAddress),
            swapDetails.srcStableTokenAddress,
            swapDetails.srcStableTokenAmount,
            address(swapDetails.destStableTokenAddress),
            destStableTokenAmount,
            address(swapDetails.destTokenAddress),
            swapDetails.destTokenAmount,
            resourceID,
            swapDetails.recipient,
            swapDetails.depositer,
            swapDetails.srcTokenAmount,
            swapDetails.feeTokenAddress,
            feeAmount[0],
            swapDetails.isDestNative ? 1 : 0
        );

        _feeBreakdown[destinationChainID][depositNonce] = FeeBreakdown(
                feeAmount[0],
                feeAmount[1],
                feeAmount[2],
                feeAmount[3],
                feeAmount[4]
            );
    }

    /**
        @notice Proposal execution should be initiated when a proposal is finalized in the Bridge contract.
        by a relayer on the deposit's destination chain.
        @notice Data passed into the function should be constructed as follows:
        amount                                 uint256     bytes  0 - 32
        destinationRecipientAddress length     uint256     bytes  32 - 64
        destinationRecipientAddress            bytes       bytes  64 - END
     */
    function executeProposal(SwapInfo memory swapDetails, bytes32 resourceID)
        public
        virtual
        override
        onlyRole(BRIDGE_ROLE)
        returns (address settlementToken, uint256 settlementAmount)
    {
        swapDetails.destStableTokenAddress = _resourceIDToTokenContractAddress[resourceID];
        require(_contractWhitelist[swapDetails.destStableTokenAddress], "provided tokenAddress is not whitelisted");

        if (address(swapDetails.destTokenAddress) == swapDetails.destStableTokenAddress) {
            // just release destStable tokens
            (settlementToken, settlementAmount) = handleExecuteForReserveToken(swapDetails);
            setExecuteRecord(swapDetails.index, swapDetails.depositNonce);
        } else if (
            _reserve._contractToLP(swapDetails.destStableTokenAddress) == address(swapDetails.destTokenAddress)
        ) {
            // release LP is destToken is LP of destStableToken
            handleExecuteForLPToken(swapDetails);
            settlementToken = address(swapDetails.destTokenAddress);
            settlementAmount = swapDetails.destStableTokenAmount;
            setExecuteRecord(swapDetails.index, swapDetails.depositNonce);
        } else {
            // exchange destStable to destToken and release tokens
            (settlementToken, settlementAmount) = handleExecuteForNonReserveToken(swapDetails);
            setExecuteRecord(swapDetails.index, swapDetails.depositNonce);
        }
    }

    /**
        @notice Used to manually release ERC20 tokens from ERC20Safe.
        @param tokenAddress Address of token contract to release.
        @param recipient Address to release tokens to.
        @param amount The amount of ERC20 tokens to release.
     */
    function withdraw(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) public virtual override onlyRole(BRIDGE_ROLE) {
        _reserve.releaseERC20(tokenAddress, recipient, amount);
    }

    /**
        @notice Used to manually release ERC20 tokens from FeeManager.
        @param tokenAddress Address of token contract to release.
        @param recipient Address to release tokens to.
        @param amount The amount of ERC20 tokens to release.
     */
    function withdrawFees(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) public virtual override onlyRole(BRIDGE_ROLE) {
        feeManager.withdrawFee(tokenAddress, recipient, amount);
    }

    function stake(
        address depositor,
        address tokenAddress,
        uint256 amount
    ) public virtual override onlyRole(BRIDGE_ROLE) {
        _reserve.stake(depositor, tokenAddress, amount);
    }

    function stakeETH(
        address depositor,
        address tokenAddress,
        uint256 amount
    ) public virtual override onlyRole(BRIDGE_ROLE) {
        assert(IWETH(_WETH).transfer(address(_reserve), amount));
        _reserve.stakeETH(depositor, tokenAddress, amount);
    }

    /**
        @notice Staking should be done by using bridge contract.
        @param unstaker removes liquidity from the pool.
        @param tokenAddress staking token of which liquidity needs to be removed.
        @param amount Amount that needs to be unstaked.
     */

    function unstake(
        address unstaker,
        address tokenAddress,
        uint256 amount
    ) public virtual override onlyRole(BRIDGE_ROLE) {
        _reserve.unstake(unstaker, tokenAddress, amount);
    }

    function unstakeETH(
        address unstaker,
        address tokenAddress,
        uint256 amount
    ) public virtual override onlyRole(BRIDGE_ROLE) {
        _reserve.unstakeETH(unstaker, tokenAddress, amount, _WETH);
    }

    function getStakedRecord(address account, address tokenAddress) public view virtual returns (uint256) {
        return _reserve.getStakedRecord(account, tokenAddress);
    }

    function handleDepositForReserveToken(SwapInfo memory swapDetails) internal {
        if (_burnList[address(swapDetails.srcTokenAddress)]) {
            _reserve.burnERC20(address(swapDetails.srcTokenAddress), swapDetails.depositer, swapDetails.srcTokenAmount);
        } else {
            _reserve.lockERC20(
                address(swapDetails.srcTokenAddress),
                swapDetails.depositer,
                address(_reserve),
                swapDetails.srcTokenAmount
            );
        }
    }

    function deductFeeAndHandleDepositForLPToken(
        SwapInfo memory swapDetails,
        uint8 destinationChainID,
        uint256 txVolInUSDx1000,
        address sender
    ) internal returns (uint256[] memory transferFee) {
        if (swapDetails.feeTokenAddress == address(0)) {
            swapDetails.feeTokenAddress = address(swapDetails.srcTokenAddress);
            transferFee = getBridgeFee(
                destinationChainID,
                address(swapDetails.srcTokenAddress),
                address(swapDetails.destTokenAddress),
                swapDetails.srcStableTokenAddress,
                swapDetails.widgetID,
                txVolInUSDx1000,
                sender
            );
        } else {
            transferFee = getBridgeFee(
                destinationChainID,
                address(swapDetails.srcTokenAddress),
                address(swapDetails.destTokenAddress),
                swapDetails.feeTokenAddress,
                swapDetails.widgetID,
                txVolInUSDx1000,
                sender
            );
        }
        // Fees of stable token address
        _reserve.deductFee(
            swapDetails.feeTokenAddress,
            swapDetails.depositer,
            // swapDetails.providedFee,
            transferFee[0],
            // _ETH,
            _isFeeEnabled,
            address(feeManager)
        );
        _reserve.burnERC20(address(swapDetails.srcTokenAddress), swapDetails.depositer, swapDetails.srcTokenAmount);
    }

    function handleDepositForNonReserveToken(SwapInfo memory swapDetails) internal {
        uint256 pathLength = swapDetails.path.length;
        if (pathLength > 2) {
            //swapMulti
            require(swapDetails.path[pathLength - 1] == swapDetails.srcStableTokenAddress);
            swapDetails.srcStableTokenAmount = _reserve.swapMulti(
                _oneSplitAddress,
                swapDetails.path,
                swapDetails.srcTokenAmount,
                swapDetails.srcStableTokenAmount,
                swapDetails.flags,
                swapDetails.dataTx
            );
        } else {
            swapDetails.srcStableTokenAmount = _reserve.swap(
                _oneSplitAddress,
                address(swapDetails.srcTokenAddress),
                swapDetails.srcStableTokenAddress,
                swapDetails.srcTokenAmount,
                swapDetails.srcStableTokenAmount,
                swapDetails.flags[0],
                swapDetails.dataTx[0]
            );
        }
    }

    function handleExecuteForReserveToken(SwapInfo memory swapDetails) internal returns (address, uint256) {
        if (_burnList[address(swapDetails.destTokenAddress)]) {
            _reserve.mintERC20(
                address(swapDetails.destTokenAddress),
                swapDetails.recipient,
                swapDetails.destStableTokenAmount
            );
        } else {
            uint256 reserveBalance = IERC20(address(swapDetails.destStableTokenAddress)).balanceOf(address(_reserve));
            if (reserveBalance < swapDetails.destStableTokenAmount) {
                _reserve.mintWrappedERC20(
                    address(swapDetails.destStableTokenAddress),
                    swapDetails.recipient,
                    swapDetails.destStableTokenAmount
                );
                return (
                    _reserve._contractToLP(address(swapDetails.destStableTokenAddress)),
                    swapDetails.destStableTokenAmount
                );
            } else {
                if (address(swapDetails.destStableTokenAddress) == _WETH && swapDetails.isDestNative) {
                    _reserve.withdrawWETH(_WETH, swapDetails.destStableTokenAmount);
                    _reserve.safeTransferETH(swapDetails.recipient, swapDetails.destStableTokenAmount);
                } else {
                    _reserve.releaseERC20(
                        address(swapDetails.destStableTokenAddress),
                        swapDetails.recipient,
                        swapDetails.destStableTokenAmount
                    );
                }
            }
        }
        return (address(swapDetails.destStableTokenAddress), swapDetails.destStableTokenAmount);
    }

    function handleExecuteForLPToken(SwapInfo memory swapDetails) internal {
        _reserve.mintWrappedERC20(
            address(swapDetails.destStableTokenAddress),
            swapDetails.recipient,
            swapDetails.destStableTokenAmount
        );
    }

    function handleExecuteForNonReserveToken(SwapInfo memory swapDetails) internal returns (address, uint256) {
        if (_burnList[swapDetails.destStableTokenAddress]) {
            if (
                (swapDetails.path.length > 2) &&
                (swapDetails.path[swapDetails.path.length - 1] != address(swapDetails.destTokenAddress))
            ) {
                _reserve.mintERC20(
                    swapDetails.destStableTokenAddress,
                    swapDetails.recipient,
                    swapDetails.destStableTokenAmount
                );
                return (swapDetails.destStableTokenAddress, swapDetails.destStableTokenAmount);
            }
            _reserve.mintERC20(swapDetails.destStableTokenAddress, _oneSplitAddress, swapDetails.destStableTokenAmount);
        } else {
            uint256 reserveBalance = IERC20(address(swapDetails.destStableTokenAddress)).balanceOf(address(_reserve));
            if (reserveBalance < swapDetails.destStableTokenAmount) {
                _reserve.mintWrappedERC20(
                    address(swapDetails.destStableTokenAddress),
                    swapDetails.recipient,
                    swapDetails.destStableTokenAmount
                );
                return (
                    _reserve._contractToLP(address(swapDetails.destStableTokenAddress)),
                    swapDetails.destStableTokenAmount
                );
            } else {
                if (
                    (swapDetails.path.length > 2) &&
                    (swapDetails.path[swapDetails.path.length - 1] != address(swapDetails.destTokenAddress))
                ) {
                    _reserve.releaseERC20(
                        swapDetails.destStableTokenAddress,
                        swapDetails.recipient,
                        swapDetails.destStableTokenAmount
                    );
                    return (swapDetails.destStableTokenAddress, swapDetails.destStableTokenAmount);
                }
                _reserve.releaseERC20(
                    swapDetails.destStableTokenAddress,
                    _oneSplitAddress,
                    swapDetails.destStableTokenAmount
                );
            }
        }
        if (swapDetails.path.length > 2) {
            //solhint-disable avoid-low-level-calls
            (bool success, bytes memory returnData) = address(_reserve).call(
                abi.encodeWithSelector(
                    0x2214e13b, // swapMulti(address,address[],uint256,uint256,uint256[],bytes[])
                    _oneSplitAddress,
                    swapDetails.path,
                    swapDetails.destStableTokenAmount,
                    swapDetails.destTokenAmount,
                    swapDetails.flags,
                    swapDetails.dataTx
                )
            );
            if (success) {
                swapDetails.returnAmount = abi.decode(returnData, (uint256));
            } else {
                require(
                    IOneSplitWrap(_oneSplitAddress).withdraw(
                        swapDetails.destStableTokenAddress,
                        swapDetails.recipient,
                        swapDetails.destStableTokenAmount
                    )
                );
                return (address(swapDetails.destStableTokenAddress), swapDetails.destStableTokenAmount);
            }
        } else {
            (bool success, bytes memory returnData) = address(_reserve).call(
                abi.encodeWithSelector(
                    0xda041a85, //swap(address,address,address,uint256,uint256,uint256,bytes)
                    _oneSplitAddress,
                    swapDetails.destStableTokenAddress,
                    address(swapDetails.destTokenAddress),
                    swapDetails.destStableTokenAmount,
                    swapDetails.destTokenAmount,
                    swapDetails.flags[0],
                    swapDetails.dataTx[0]
                )
            );
            if (success) {
                swapDetails.returnAmount = abi.decode(returnData, (uint256));
            } else {
                require(
                    IOneSplitWrap(_oneSplitAddress).withdraw(
                        swapDetails.destStableTokenAddress,
                        swapDetails.recipient,
                        swapDetails.destStableTokenAmount
                    )
                );
                return (address(swapDetails.destStableTokenAddress), swapDetails.destStableTokenAmount);
            }
        }
        if (address(swapDetails.destTokenAddress) == _WETH && swapDetails.isDestNative) {
            _reserve.withdrawWETH(_WETH, swapDetails.returnAmount);
            _reserve.safeTransferETH(swapDetails.recipient, swapDetails.returnAmount);
        } else {
            _reserve.releaseERC20(
                address(swapDetails.destTokenAddress),
                swapDetails.recipient,
                swapDetails.returnAmount
            );
        }
        return (address(swapDetails.destTokenAddress), swapDetails.returnAmount);
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
// OpenZeppelin Contracts v4.4.0 (utils/Context.sol)

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
pragma solidity 0.8.2;

/**
    @title Interface for handler contracts that support deposits and deposit executions.
    @author Router Protocol.
 */
interface IDepositExecute {
    struct SwapInfo {
        address feeTokenAddress;
        uint64 depositNonce;
        uint256 index;
        uint256 returnAmount;
        address recipient;
        address stableTokenAddress;
        address handler;
        uint256 srcTokenAmount;
        uint256 srcStableTokenAmount;
        uint256 destStableTokenAmount;
        uint256 destTokenAmount;
        uint256 lenRecipientAddress;
        uint256 lenSrcTokenAddress;
        uint256 lenDestTokenAddress;
        bytes20 srcTokenAddress;
        address srcStableTokenAddress;
        bytes20 destTokenAddress;
        address destStableTokenAddress;
        bytes[] dataTx;
        uint256[] flags;
        address[] path;
        address depositer;
        bool isDestNative;
        uint256 widgetID;
    }

    /**
        @notice It is intended that deposit are made using the Bridge contract.
        @param destinationChainID Chain ID deposit is expected to be bridged to.
        @param depositNonce This value is generated as an ID by the Bridge contract.
        @param swapDetails Swap details

     */
    function deposit(
        bytes32 resourceID,
        uint8 destinationChainID,
        uint64 depositNonce,
        SwapInfo calldata swapDetails,
        address sender
    ) external;

    /**
        @notice It is intended that proposals are executed by the Bridge contract.
     */
    function executeProposal(SwapInfo calldata swapDetails, bytes32 resourceID) external returns (address, uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

/**
    @title Interface for handler contracts that support deposits and deposit executions.
    @author Router Protocol.
 */
interface ILiquidityPool {
    /**
        @notice Staking should be done by using bridge contract.
        @param depositor stakes liquidity in the pool .
        @param tokenAddress staking token for which liquidity needs to be added.
        @param amount Amount that needs to be staked.
     */
    function stake(
        address depositor,
        address tokenAddress,
        uint256 amount
    ) external;

    /**
        @notice Staking should be done by using bridge contract.
        @param depositor stakes liquidity in the pool .
        @param tokenAddress staking token for which liquidity needs to be added.
        @param amount Amount that needs to be staked.
     */
    function stakeETH(
        address depositor,
        address tokenAddress,
        uint256 amount
    ) external;

    /**
        @notice Staking should be done by using bridge contract.
        @param unstaker removes liquidity from the pool.
        @param tokenAddress staking token of which liquidity needs to be removed.
        @param amount Amount that needs to be unstaked.
     */
    function unstake(
        address unstaker,
        address tokenAddress,
        uint256 amount
    ) external;

    /**
        @notice Staking should be done by using bridge contract.
        @param unstaker removes liquidity from the pool.
        @param tokenAddress staking token of which liquidity needs to be removed.
        @param amount Amount that needs to be unstaked.
     */
    function unstakeETH(
        address unstaker,
        address tokenAddress,
        uint256 amount
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

interface IOneSplitWrap {
    function withdraw(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function getExpectedReturn(
        address fromToken,
        address destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) external view returns (uint256 returnAmount, uint256[] memory distribution);

    function getExpectedReturnWithGas(
        address fromToken,
        address destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags,
        uint256 destTokenEthPriceTimesGasPrice
    )
        external
        view
        returns (
            uint256 returnAmount,
            uint256 estimateGasAmount,
            uint256[] memory distribution
        );

    function getExpectedReturnWithGasMulti(
        address[] memory tokens,
        uint256 amount,
        uint256[] memory parts,
        uint256[] memory flags,
        uint256[] memory destTokenEthPriceTimesGasPrices
    )
        external
        view
        returns (
            uint256[] memory returnAmounts,
            uint256 estimateGasAmount,
            uint256[] memory distribution
        );

    function swap(
        address fromToken,
        address destToken,
        uint256 amount,
        uint256 minReturn,
        uint256 flags,
        bytes memory dataTx,
        bool isWrapper
    ) external payable returns (uint256 returnAmount);

    function swapMulti(
        address[] memory tokens,
        uint256 amount,
        uint256 minReturn,
        uint256[] memory flags,
        bytes[] memory dataTx,
        bool isWrapper
    ) external payable returns (uint256 returnAmount);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);

    function approve(address guy, uint256 wad) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

/**
    @title Interface to be used with handlers that support ERC20s and ERC721s.
    @author Router Protocol.
 */
interface IERC20Upgradeable {

    function transfer( address, uint256) external;
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "../interfaces/IERCHandler.sol";
import "../interfaces/IFeeManagerUpgradeable.sol";
import "../interfaces/IHandlerReserve.sol";

/**
    @title Function used across handler contracts.
    @author Router Protocol.
    @notice This contract is intended to be used with the Bridge contract.
 */
contract HandlerHelpersUpgradeable is Initializable, ContextUpgradeable, AccessControlUpgradeable, IERCHandler {
    address public _bridgeAddress;
    address public _oneSplitAddress;
    address public override _ETH;
    address public override _WETH;
    bool public _isFeeEnabled;
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    IFeeManagerUpgradeable public feeManager;
    IHandlerReserve public _reserve;

    // resourceID => token contract address
    mapping(bytes32 => address) internal _resourceIDToTokenContractAddress;

    // token contract address => resourceID
    mapping(address => bytes32) public _tokenContractAddressToResourceID;

    // token contract address => is whitelisted
    mapping(address => bool) public _contractWhitelist;

    // token contract address => is burnable
    mapping(address => bool) public _burnList;

    event UnsupportedChain(uint8 destChainId, bool isUnsupported);

    function __HandlerHelpersUpgradeable_init() internal initializer {
        __Context_init_unchained();
        __AccessControl_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(BRIDGE_ROLE, _msgSender());
        _isFeeEnabled = false;
    }

    function __HandlerHelpersUpgradeable_init_unchained() internal initializer {}

    // function grantFeeRole(address account) public virtual override onlyRole(BRIDGE_ROLE) {
    //     grantRole(FEE_SETTER_ROLE, account);
    //     totalFeeSetters = totalFeeSetters + 1;
    // }

    // function revokeFeeRole(address account) public virtual override onlyRole(BRIDGE_ROLE) {
    //     revokeRole(FEE_SETTER_ROLE, account);
    //     totalFeeSetters = totalFeeSetters - 1;
    // }

    function setFeeManager(IFeeManagerUpgradeable _feeManager) public onlyRole(DEFAULT_ADMIN_ROLE) {
        feeManager = _feeManager;
    }

    /**
        @notice Used to get fee.
        @param  destinationChainID id of the destination chain.
        @param  srcTokenAddress address of the source token. Put address(0) if not configuring.
        @param  destTokenAddress address of the destination token. Put address(0) if not configuring.
        @param  feeTokenAddress address of the fee token. 
        @param  widgetID Widget id. Put 0 if not configuring.
        @param  transactionVolumeInUSDx1000 transaction volume in USD * 1000.
        @param  sender Address of sender of tx
        @return totalFee, abi.encode(lpFee, validatorFee, protocolFee, widgetFee) in tokens
    */
    function getBridgeFee(
        uint8 destinationChainID,
        address srcTokenAddress,
        address destTokenAddress,
        address feeTokenAddress,
        uint256 widgetID,
        uint256 transactionVolumeInUSDx1000,
        address sender
    ) public view virtual override returns (uint256[] memory) {
        (uint256 totalFee, bytes memory data) = feeManager.getFee(
            destinationChainID,
            srcTokenAddress,
            destTokenAddress,
            feeTokenAddress,
            widgetID,
            transactionVolumeInUSDx1000,
            sender
        );

        (uint256 lpFee, uint256 validatorFee, uint256 protocolFee, uint256 widgetFee) = abi.decode(
            data,
            (uint256, uint256, uint256, uint256)
        );

        uint256[] memory result = getResult(totalFee, lpFee, validatorFee, protocolFee, widgetFee);
        return result;
    }

    /**
        @notice Used to get fee for swap functionality.
        @param  destinationChainId id of the destination chain.
        @param  srcTokenAddress address of the source token. Put address(0) if not configuring.
        @param  destTokenAddress address of the destination token. Put address(0) if not configuring.
        @param  feeTokenAddress address of the fee token. 
        @param  widgetID Widget id. Put 0 if not configuring.
        @param  transactionVolumeInUSDx1000 transaction volume in USD * 1000.
        @param  sender Address of sender of tx
        @return totalFee, abi.encode(lpFee, validatorFee, protocolFee, widgetFee) in tokens
    */
    function getBridgeFeeWithSwap(
        uint8 destinationChainId,
        address srcTokenAddress,
        address destTokenAddress,
        address feeTokenAddress,
        uint256 widgetID,
        uint256 transactionVolumeInUSDx1000,
        address sender
    ) public view virtual override returns (uint256[] memory) {
        (uint256 totalFee, bytes memory data) = feeManager.getFeeWithSwap(
            destinationChainId,
            srcTokenAddress,
            destTokenAddress,
            feeTokenAddress,
            widgetID,
            transactionVolumeInUSDx1000,
            sender
        );

        (uint256 lpFee, uint256 validatorFee, uint256 protocolFee, uint256 widgetFee) = abi.decode(
            data,
            (uint256, uint256, uint256, uint256)
        );

        uint256[] memory result = getResult(totalFee, lpFee, validatorFee, protocolFee, widgetFee);
        return result;
    }

    function getResult(
        uint256 totalFee,
        uint256 lpFee,
        uint256 validatorFee,
        uint256 protocolFee,
        uint256 widgetFee
    ) internal pure returns (uint256[] memory) {
        uint256[] memory result = new uint256[](5);
        result[0] = totalFee;
        result[1] = lpFee;
        result[2] = validatorFee;
        result[3] = protocolFee;
        result[4] = widgetFee;
        return result;
    }

    /**
        @notice Used to set fee.
        @notice Only callable by Bridge.
        @param  destinationChainID id of the destination chain.
        @param  srcTokenAddress address of the source token. Put address(0) if not configuring.
        @param  destTokenAddress address of the destination token. Put address(0) if not configuring.
        @param  feeTokenAddress address of the fee token.
        @param  feeTokenDecimals decimals for fee token.
        @param  data Contains an array of [lpFee, validatorFee, protocolFee] 
                along with baseFeeInUSD, swapFeeInUSD and maxFeeInUSD.
        @param  isDefault true if it is a default fee token
    */
    function setBridgeFee(
        uint8 destinationChainID,
        address srcTokenAddress,
        address destTokenAddress,
        address feeTokenAddress,
        uint8 feeTokenDecimals,
        bytes memory data,
        bool isDefault
    ) public virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        feeManager.setFee(
            destinationChainID,
            srcTokenAddress,
            destTokenAddress,
            feeTokenAddress,
            feeTokenDecimals,
            data,
            isDefault
        );
    }

    /**
        @notice Used to setup Widget fee in bps.
        @notice Only callable by Bridge.
        @param  widgetID widget ID for the widget.
        @param  widgetFeeInBpsX1000 New Protocol fee in bps.
     */
    function setWidgetFeeInBps(uint256 widgetID, uint256 widgetFeeInBpsX1000)
        external
        virtual
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        feeManager.setWidgetFeeInBps(widgetID, widgetFeeInBpsX1000);
    }

    function toggleFeeStatus(bool status) public virtual override onlyRole(BRIDGE_ROLE) {
        _isFeeEnabled = status;
    }

    function getFeeStatus() public view virtual override returns (bool) {
        return _isFeeEnabled;
    }

    function resourceIDToTokenContractAddress(bytes32 resourceID) public view virtual override returns (address) {
        return _resourceIDToTokenContractAddress[resourceID];
    }

    /**
        @notice First verifies {_resourceIDToContractAddress}[{resourceID}] and
        {_contractAddressToResourceID}[{contractAddress}] are not already set,
        then sets {_resourceIDToContractAddress} with {contractAddress},
        {_contractAddressToResourceID} with {resourceID},
        and {_contractWhitelist} to true for {contractAddress}.
        @param resourceID ResourceID to be used when making deposits.
        @param contractAddress Address of contract to be called when a deposit is made and a deposited is executed.
     */
    function setResource(bytes32 resourceID, address contractAddress) public virtual override onlyRole(BRIDGE_ROLE) {
        _setResource(resourceID, contractAddress);
    }

    /**
        @notice First verifies {contractAddress} is whitelisted, then sets {_burnList}[{contractAddress}]
        to true.
        @param contractAddress Address of contract to be used when making or executing deposits.
        @param status Boolean flag to change burnable status.
     */
    function setBurnable(address contractAddress, bool status) public virtual override onlyRole(BRIDGE_ROLE) {
        _setBurnable(contractAddress, status);
    }

    /**
        @notice Used to manually release funds from ERC safes.
        @param tokenAddress Address of token contract to release.
        @param recipient Address to release tokens to.
        @param amount the amount of ERC20 tokens to release.
     */
    function withdraw(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) public virtual override {}

    function withdrawFees(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) public virtual override {}

    /**
        @notice Sets oneSplitAddress for the handler
        @param contractAddress Address of oneSplit contract
     */
    function setOneSplitAddress(address contractAddress) public virtual override onlyRole(BRIDGE_ROLE) {
        _setOneSplitAddress(contractAddress);
    }

    /**
        @notice Sets liquidity pool for given ERC20 address. These pools will be used to
        stake and unstake liqudity.
        @param contractAddress Address of contract for which LP contract should be created.
     */
    function setLiquidityPool(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address contractAddress,
        address lpAddress
    ) public virtual override onlyRole(BRIDGE_ROLE) {
        address newLPAddress = _reserve._setLiquidityPool(name, symbol, decimals, contractAddress, lpAddress);
        _contractWhitelist[newLPAddress] = true;
        _setBurnable(newLPAddress, true);
    }

    function setLiquidityPoolOwner(
        address newOwner,
        address tokenAddress,
        address lpAddress
    ) public virtual override onlyRole(BRIDGE_ROLE) {
        _reserve._setLiquidityPoolOwner(newOwner, tokenAddress, lpAddress);
    }

    function _setResource(bytes32 resourceID, address contractAddress) internal virtual {
        require(contractAddress != address(0), "contract address can't be zero");
        _resourceIDToTokenContractAddress[resourceID] = contractAddress;
        _tokenContractAddressToResourceID[contractAddress] = resourceID;
        _contractWhitelist[contractAddress] = true;
    }

    function _setBurnable(address contractAddress, bool status) internal virtual {
        require(_contractWhitelist[contractAddress], "provided contract is not whitelisted");
        _burnList[contractAddress] = status;
    }

    function _setOneSplitAddress(address contractAddress) internal virtual {
        require(contractAddress != address(0), "ERC20Handler: contractAddress cannot be null");
        _oneSplitAddress = address(contractAddress);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (access/AccessControl.sol)

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
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
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
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
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

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

/**
    @title Interface to be used with handlers that support ERC20s and ERC721s.
    @author Router Protocol.
 */
interface IERCHandler {
    function withdrawFees(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) external;

    /**
        @notice Used to get fee.
        @param  destinationChainId id of the destination chain.
        @param  srcTokenAddress address of the source token. Put address(0) if not configuring.
        @param  destTokenAddress address of the destination token. Put address(0) if not configuring.
        @param  feeTokenAddress address of the fee token. 
        @param  widgetID Widget id. Put 0 if not configuring.
        @param  transactionVolumeInUSDx1000 transaction volume in USD * 1000.
        @param  sender Address of sender of tx
        @return totalFee, abi.encode(lpFee, validatorFee, protocolFee, widgetFee) in tokens
    */
    function getBridgeFee(
        uint8 destinationChainId,
        address srcTokenAddress,
        address destTokenAddress,
        address feeTokenAddress,
        uint256 widgetID,
        uint256 transactionVolumeInUSDx1000,
        address sender
    ) external view returns (uint256[] memory);

    /**
        @notice Used to get fee for swap functionality.
        @param  destinationChainId id of the destination chain.
        @param  srcTokenAddress address of the source token. Put address(0) if not configuring.
        @param  destTokenAddress address of the destination token. Put address(0) if not configuring.
        @param  feeTokenAddress address of the fee token. 
        @param  widgetID Widget id. Put 0 if not configuring.
        @param  transactionVolumeInUSDx1000 transaction volume in USD * 1000.
        @param  sender Address of sender of tx
        @return totalFee, abi.encode(lpFee, validatorFee, protocolFee, widgetFee) in tokens
    */
    function getBridgeFeeWithSwap(
        uint8 destinationChainId,
        address srcTokenAddress,
        address destTokenAddress,
        address feeTokenAddress,
        uint256 widgetID,
        uint256 transactionVolumeInUSDx1000,
        address sender
    ) external view returns (uint256[] memory);

    /**
        @notice Used to set fee.
        @notice Only callable by Bridge.
        @param  destinationChainId id of the destination chain.
        @param  srcTokenAddress address of the source token. Put address(0) if not configuring.
        @param  destTokenAddress address of the destination token. Put address(0) if not configuring.
        @param  feeTokenAddress address of the fee token.
        @param  feeTokenDecimals decimals for fee token.
        @param  data Contains an array of [lpFee, validatorFee, protocolFee] 
                along with baseFeeInUSD, swapFeeInUSD and maxFeeInUSD.
        @param  isDefault true if it is a default fee token    
    */
    function setBridgeFee(
        uint8 destinationChainId,
        address srcTokenAddress,
        address destTokenAddress,
        address feeTokenAddress,
        uint8 feeTokenDecimals,
        bytes memory data,
        bool isDefault
    ) external;

    /**
        @notice Used to setup Widget fee in bps.
        @notice Only callable by Bridge.
        @param  widgetID widget ID for the widget.
        @param  widgetFeeInBpsX1000 New Protocol fee in bps.
     */
    function setWidgetFeeInBps(uint256 widgetID, uint256 widgetFeeInBpsX1000) external;

    function toggleFeeStatus(bool status) external;

    function getFeeStatus() external view returns (bool);

    function _ETH() external view returns (address);

    function _WETH() external view returns (address);

    function resourceIDToTokenContractAddress(bytes32 resourceID) external view returns (address);

    /**
        @notice Correlates {resourceID} with {contractAddress}.
        @param resourceID ResourceID to be used when making deposits.
        @param contractAddress Address of contract to be called when a deposit is made and a deposited is executed.
     */
    function setResource(bytes32 resourceID, address contractAddress) external;

    // function setTokenDecimals(address tokenAddress, uint8 destinationChainID, uint8 decimals) external;

    /**
        @notice Sets oneSplitAddress for the handler
        @param contractAddress Address of oneSplit contract
     */
    function setOneSplitAddress(address contractAddress) external;

    /**
        @notice Correlates {resourceID} with {contractAddress}.
        @param contractAddress Address of contract for qhich liquidity pool needs to be created.
     */
    function setLiquidityPool(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address contractAddress,
        address lpAddress
    ) external;

    function setLiquidityPoolOwner(
        address newOwner,
        address tokenAddress,
        address lpAddress
    ) external;

    /**
        @notice Marks {contractAddress} as mintable/burnable.
        @param contractAddress Address of contract to be used when making or executing deposits.
        @param status Boolean flag for burnanble status.
     */
    function setBurnable(address contractAddress, bool status) external;

    /**
        @notice Used to manually release funds from ERC safes.
        @param tokenAddress Address of token contract to release.
        @param recipient Address to release tokens to.
        @param amountOrTokenID Either the amount of ERC20 tokens or the ERC721 token ID to release.
     */
    function withdraw(
        address tokenAddress,
        address recipient,
        uint256 amountOrTokenID
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

interface IFeeManagerUpgradeable {
    struct Fees {
        bytes32 configId;
        uint8 destChainId;
        address srcToken;
        address destToken;
        address feeToken;
        uint8 feeTokenDecimals;
        uint256[3] lpValidatorAndProtocolFeeInBps;
        uint256 baseFeeInUSD;
        uint256 swapFeeInUSD;
        uint256 maxFeeInUSD;
    }

    /**
        @notice Used to fetch handler address.
        @notice Only callable by admin or Fee Setter.
     */
    function fetchHandler() external view returns (address);

    /**
        @notice Used to fetch if an address is whitelisted
    */
    function isWhitelisted(address target) external view returns (bool);

    /**
        @notice Used to get listed fee tokens for given chain.
        @param  destChainId id of the destination chain.
    */
    function getChainFeeTokens(uint8 destChainId) external view returns (address[] memory);

    /**
        @notice Used to fetch the fee struct using the fee config ID.
     */
    function getFeeStruct(bytes32 feeConfigID) external view returns (Fees memory);

    /**
        @notice Used to fetch the LP fee in bps.
     */
    function getLpFeeInBps(bytes32 feeConfigID) external view returns (uint256);

    /**
        @notice Used to fetch the Validator fee in bps.
     */
    function getValidatorFeeInBps(bytes32 feeConfigID) external view returns (uint256);

    /**
        @notice Used to fetch the Protocol fee in bps.
     */
    function getProtocolFeeInBps(bytes32 feeConfigID) external view returns (uint256);

    /**
        @notice Used to fetch the widget fee in bps for widgetID and fee token address.
     */
    function getWidgetFeeInBps(uint256 widgetID) external view returns (uint256);

    /**
        @notice Used to fetch the base fee in tokens.
     */
    function getBaseFee(bytes32 feeConfigID) external view returns (uint256);

    /**
        @notice Used to fetch the swap fee in tokens.
     */
    function getSwapFee(bytes32 feeConfigID) external view returns (uint256);

    /**
        @notice Used to fetch fee config ID.
        @param  destChainId id of the destination chain.
        @param  srcToken address of the source token. Put address(0) if not configuring.
        @param  destToken address of the destination token. Put address(0) if not configuring.
        @param  feeToken address of the fee token. 
        @param  widgetID widgetId.
        @return baseFeeInUSD, swapFeeInUSD, maxFeeInUSD, totalBpsFee
     */
    function fetchFeeVars(
        uint8 destChainId,
        address srcToken,
        address destToken,
        address feeToken,
        uint256 widgetID
    )
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    /**
        @notice Used to fetch fee config ID.
        @param  destChainId id of the destination chain.
        @param  srcToken address of the source token. Put address(0) if not configuring.
        @param  destToken address of the destination token. Put address(0) if not configuring.
        @param  feeToken address of the fee token. 
     */
    function getFeeConfigID(
        uint8 destChainId,
        address srcToken,
        address destToken,
        address feeToken
    ) external pure returns (bytes32);

    /**
        @notice Used to fetch the manually set price of tokens.
        @param  feeToken address of the fee token.      
    */
    function getFeeTokenToPrice(address feeToken) external view returns (uint256 price);

    /**
        @notice Used to setup handler address.
        @notice Only callable by admin or Fee Setter.
        @param  handler Address of the new handler.
     */
    function setHandler(address handler) external;

    /**
        @notice Used to add addresses to whitelist.
        @notice Only callable by admin or Fee Setter.
        @param  addresses List of addresses to add to whitelist.
        @param  whitelistStatus  Status of the whitelist to be set in boolean value.
    */
    function whitelist(address[] calldata addresses, bool[] calldata whitelistStatus) external;

    /**
        @notice Used to setup LP, Validator and Protocol fees for a fee token.
        @notice Only callable by Fee Setter.
        @param  feeConfigID Config ID for the fees.
        @param  lpFeeInBpsX1000 LP fee in bps * 1000.
        @param  validatorFeeInBpsX1000 Validator fee in bps * 1000.
        @param  protocolFeeInBpsX1000 Protocol fee in bps * 1000.
     */
    function setLpValidatorAndProtocolFeeInBps(
        bytes32 feeConfigID,
        uint256 lpFeeInBpsX1000,
        uint256 validatorFeeInBpsX1000,
        uint256 protocolFeeInBpsX1000
    ) external;

    /**
        @notice Used to setup LP fee in bps.
        @notice Only callable by admin or Fee Setter.
        @param  lpFeeInBpsX1000 New LP fee in bps * 1000.
        @param  feeConfigID Config ID for the fees.
     */
    function setLpFeeInBps(bytes32 feeConfigID, uint256 lpFeeInBpsX1000) external;

    /**
        @notice Used to setup Validator fee in bps.
        @notice Only callable by admin or Fee Setter.
        @param  validatorFeeInBpsX1000 New Validator fee in bps * 1000.
        @param  feeConfigID Address of the fee token.
     */
    function setValidatorFeeInBps(bytes32 feeConfigID, uint256 validatorFeeInBpsX1000) external;

    /**
        @notice Used to setup Protocol fee in bps.
        @notice Only callable by admin or Fee Setter.
        @param  protocolFeeInBpsX1000 New Protocol fee in bps * 1000.
        @param  feeConfigID Config ID for the fees.
     */
    function setProtocolFeeInBps(bytes32 feeConfigID, uint256 protocolFeeInBpsX1000) external;

    /**
        @notice Used to setup Widget fee in bps.
        @notice Only callable by admin or Fee Setter.
        @param  widgetID widget ID for the widget.
        @param  widgetFeeInBpsX1000 New Protocol fee in bps.
     */
    function setWidgetFeeInBps(uint256 widgetID, uint256 widgetFeeInBpsX1000) external;

    /**
        @notice Used to set base fee.
        @notice Only callable by admin or Fee Setter.
        @param  feeConfigID id of the fee configuration.
        @param  baseFeeInUSDx1000 Base fee in USD for the config.
     */
    function setBaseFee(bytes32 feeConfigID, uint256 baseFeeInUSDx1000) external;

    /**
        @notice Used to set swap fee.
        @notice Only callable by admin or Fee Setter.
        @param  feeConfigID id of the fee configuration.
        @param  swapFeeInUSDx1000 Swap fee in USD for the config.
     */
    function setSwapFee(bytes32 feeConfigID, uint256 swapFeeInUSDx1000) external;

    /**
        @notice Used to set fee token price in USD * 10**9 manually. 
        @notice Only callable by admin or Fee Setter.
        @param  feeToken Address of the fee tokens.
        @param  priceInUSDx10e9 Prices in USD * 10**9.
     */
    function setFeeTokenToPriceX10e9(address[] calldata feeToken, uint256[] calldata priceInUSDx10e9) external;

    /**
        @notice Used to set fee.
        @notice Only callable by Fee Setter.
        @param  destChainId id of the destination chain.
        @param  srcToken address of the source token. Put address(0) if not configuring.
        @param  destToken address of the destination token. Put address(0) if not configuring.
        @param  feeToken address of the fee token.
        @param  feeTokenDecimals decimals for fee token.
        @param  data Contains an array of [lpFee, validatorFee, protocolFee] 
                along with baseFeeInUSD, swapFeeInUSD and maxFeeInUSD.
        @param  isDefault true if it is a default fee token
    */

    function setFee(
        uint8 destChainId,
        address srcToken,
        address destToken,
        address feeToken,
        uint8 feeTokenDecimals,
        bytes memory data,
        bool isDefault
    ) external;

    /**
        @notice Used to get fee.
        @param  destChainId id of the destination chain.
        @param  srcToken address of the source token. Put address(0) if not configuring.
        @param  destToken address of the destination token. Put address(0) if not configuring.
        @param  feeToken address of the fee token. 
        @param  widgetID Widget id. Put 0 if not configuring.
        @param  transactionVolumeInUSDx1000 transaction volume in USD * 1000.
        @param  sender Address of sender of tx
        @return totalFee, abi.encode(lpFee, validatorFee, protocolFee, widgetFee) in tokens
    */
    function getFee(
        uint8 destChainId,
        address srcToken,
        address destToken,
        address feeToken,
        uint256 widgetID,
        uint256 transactionVolumeInUSDx1000,
        address sender
    ) external view returns (uint256, bytes memory);

    /**
        @notice Used to get fee for swap functionality.
        @param  destChainId id of the destination chain.
        @param  srcToken address of the source token. Put address(0) if not configuring.
        @param  destToken address of the destination token. Put address(0) if not configuring.
        @param  feeToken address of the fee token. 
        @param  widgetID Widget id. Put 0 if not configuring.
        @param  transactionVolumeInUSDx1000 transaction volume in USD * 1000.
        @param  sender Address of sender of tx
        @return totalFee, abi.encode(lpFee, validatorFee, protocolFee, widgetFee) in tokens
    */
    function getFeeWithSwap(
        uint8 destChainId,
        address srcToken,
        address destToken,
        address feeToken,
        uint256 widgetID,
        uint256 transactionVolumeInUSDx1000,
        address sender
    ) external view returns (uint256, bytes memory);

    /**
        @notice  Withdraws the fee from the contract
        Only callable by the DEFAULT_ADMIN
        @param   tokenAddress  The fee token to withdraw
        @param   recipient     The address of the recepient
        @param   amount        The amount of fee tokens to withdraw
    */
    function withdrawFee(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) external;

    /**
        @notice Used to manually withdraw native tokens from FeeManager.
        @param  recipient Address of the recepient.
        @param  amount Amount of native tokens to withdraw
     */
    function withdrawNativeTokens(address recipient, uint256 amount) external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

interface IHandlerReserve {
    function fundERC20(
        address tokenAddress,
        address owner,
        uint256 amount
    ) external;

    function lockERC20(
        address tokenAddress,
        address owner,
        address recipient,
        uint256 amount
    ) external;

    function releaseERC20(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) external;

    function mintERC20(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) external;

    function burnERC20(
        address tokenAddress,
        address owner,
        uint256 amount
    ) external;

    function safeTransferETH(address to, uint256 value) external;

    function deductFee(
        address feeTokenAddress,
        address depositor,
        // uint256 providedFee,
        uint256 requiredFee,
        // address _ETH,
        bool _isFeeEnabled,
        address _feeManager
    ) external;

    function mintWrappedERC20(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) external;

    function stake(
        address depositor,
        address tokenAddress,
        uint256 amount
    ) external;

    function stakeETH(
        address depositor,
        address tokenAddress,
        uint256 amount
    ) external;

    function unstake(
        address unstaker,
        address tokenAddress,
        uint256 amount
    ) external;

    function unstakeETH(
        address unstaker,
        address tokenAddress,
        uint256 amount,
        address WETH
    ) external;

    function getStakedRecord(address account, address tokenAddress) external view returns (uint256);

    function withdrawWETH(address WETH, uint256 amount) external;

    function _setLiquidityPoolOwner(
        address newOwner,
        address tokenAddress,
        address lpAddress
    ) external;

    function _setLiquidityPool(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address contractAddress,
        address lpAddress
    ) external returns (address);

    function swapMulti(
        address oneSplitAddress,
        address[] memory tokens,
        uint256 amount,
        uint256 minReturn,
        uint256[] memory flags,
        bytes[] memory dataTx
    ) external returns (uint256 returnAmount);

    function swap(
        address oneSplitAddress,
        address fromToken,
        address destToken,
        uint256 amount,
        uint256 minReturn,
        uint256 flags,
        bytes memory dataTx
    ) external returns (uint256 returnAmount);

    function feeManager() external returns (address);
    function _lpToContract(address token) external returns (address);
    function _contractToLP(address token) external returns (address);

    
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (access/IAccessControl.sol)

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
// OpenZeppelin Contracts v4.4.0 (utils/Strings.sol)

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
// OpenZeppelin Contracts v4.4.0 (utils/introspection/ERC165.sol)

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