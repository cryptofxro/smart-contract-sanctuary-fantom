// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0;

interface IBridge {
    // AnySwap
    function anySwapOut(address token, address to, uint amount, uint toChainID) external;

    function anySwapOutUnderlying(address token, address to, uint amount, uint toChainID) external;

    // CBridge
    function send(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage // slippage * 1M, eg. 0.5% -> 5000
    ) external;

    // GateBridge
    function deposit(uint8 destinationChainID, bytes32 resourceID, bytes calldata data) external payable;

    function _resourceIDToHandlerAddress(bytes32 resourceID) external view returns (address);

    function getFee(uint chainIdIn, uint chainIdOut) external view returns (uint);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0;

interface IMessageReceiverApp {
    enum ExecutionStatus {
        Fail, // execution failed, finalized
        Success, // execution succeeded, finalized
        Retry // execution rejected, can retry later
    }

    /**
     * @notice Called by MessageBus (MessageBusReceiver) if the process is originated from MessageBus (MessageBusSender)'s
     *         sendMessageWithTransfer it is only called when the tokens are checked to be arrived at this contract's address.
     * @param _sender The address of the source app contract
     * @param _token The address of the token that comes out of the bridge
     * @param _amount The amount of tokens received at this contract through the cross-chain bridge.
     *        the contract that implements this contract can safely assume that the tokens will arrive before this
     *        function is called.
     * @param _srcChainId The source chain ID where the transfer is originated from
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _executor Address who called the MessageBus execution function
     */
    function executeMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external payable returns (ExecutionStatus);

    /**
     * @notice Only called by MessageBus (MessageBusReceiver) if
     *         1. executeMessageWithTransfer reverts, or
     *         2. executeMessageWithTransfer returns ExecutionStatus.Fail
     * @param _sender The address of the source app contract
     * @param _token The address of the token that comes out of the bridge
     * @param _amount The amount of tokens received at this contract through the cross-chain bridge.
     *        the contract that implements this contract can safely assume that the tokens will arrive before this
     *        function is called.
     * @param _srcChainId The source chain ID where the transfer is originated from
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _executor Address who called the MessageBus execution function
     */
    function executeMessageWithTransferFallback(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external payable returns (ExecutionStatus);

    /**
     * @notice Called by MessageBus (MessageBusReceiver) to process refund of the original transfer from this contract
     * @param _token The token address of the original transfer
     * @param _amount The amount of the original transfer
     * @param _message The same message associated with the original transfer
     * @param _executor Address who called the MessageBus execution function
     */
    function executeMessageWithTransferRefund(
        address _token,
        uint256 _amount,
        bytes calldata _message,
        address _executor
    ) external payable returns (ExecutionStatus);

    /**
     * @notice Called by MessageBus (MessageBusReceiver)
     * @param _sender The address of the source app contract
     * @param _srcChainId The source chain ID where the transfer is originated from
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _executor Address who called the MessageBus execution function
     */
    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external payable returns (ExecutionStatus);

    // execute message from non-evm chain with bytes for sender address,
    // otherwise same as above.
    function executeMessage(
        bytes calldata _sender,
        uint64 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external payable returns (ExecutionStatus);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0;

interface ISigsVerifier {
    /**
     * @notice Verifies that a message is signed by a quorum among the signers.
     * @param _msg signed message
     * @param _sigs list of signatures sorted by signer addresses in ascending order
     * @param _signers sorted list of current signers
     * @param _powers powers of current signers
     */
    function verifySigs(
        bytes memory _msg,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external view;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./MsgDataTypes.sol";

contract MainStorage {
    address _owner;

    // ReentrancyGuard status
    uint256 _status;

    /**
     * @dev Indicates that the contract has been initialized.
     */
    uint8 _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool _initializing;

    address public messageBus;

    address payable public ooSwap;

    mapping(MsgDataTypes.BridgeSendType => mapping(address => uint256)) public minBridgeAmounts;

    // erc20 wrap of gas token of this chain, eg. WETH
    address public nativeWrap;

    mapping(MsgDataTypes.BridgeSendType => mapping(address => mapping(uint256 => uint256))) public minBridgeAmountsPerChainId;
    mapping(MsgDataTypes.BridgeSendType => mapping(address => mapping(uint256 => uint256))) public maxBridgeAmountsPerChainId;

    address public nativeTokenHandler;

    mapping(MsgDataTypes.BridgeSendType => mapping(address => uint256)) public maxBridgeAmounts;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0;

library MsgDataTypes {
    // bridge operation type at the sender side (src chain)
    enum BridgeSendType {
        Null,
        MultiChain,
        CBridge,
        GateBridge
    }

    enum MsgType {
        MessageWithTransfer,
        MessageOnly
    }

    enum TxStatus {
        Null,
        Success,
        Fail,
        Fallback,
        Pending // transient state within a transaction
    }

    struct TransferInfo {
        BridgeSendType t;
        address sender;
        address receiver; // the app contract that implements the MessageReceiver abstract contract
        address token;
        uint256 amount;
        uint64 wdseq; // only needed for LqWithdraw (refund)
        uint64 srcChainId;
        bytes32 refId;
        bytes32 srcTxHash; // src chain msg tx hash
    }

    struct RouteInfo {
        address sender;
        address receiver;
        uint64 srcChainId;
        bytes32 srcTxHash; // src chain msg tx hash
    }

    // used for msg from non-evm chains with longer-bytes address
    struct RouteInfo2 {
        bytes sender;
        address receiver;
        uint64 srcChainId;
        bytes32 srcTxHash;
    }

    // combination of RouteInfo and RouteInfo2 for easier processing
    struct Route {
        address sender; // from RouteInfo
        bytes senderBytes; // from RouteInfo2
        address receiver;
        uint64 srcChainId;
        bytes32 srcTxHash;
    }

    struct MsgWithTransferExecutionParams {
        bytes message;
        TransferInfo transfer;
        bytes[] sigs;
        address[] signers;
        uint256[] powers;
    }

    struct BridgeTransferParams {
        bytes request;
        bytes[] sigs;
        address[] signers;
        uint256[] powers;
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./MainStorage.sol";

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
 *
 * This adds a normal func that setOwner if _owner is address(0). So we can't allow
 * renounceOwnership. So we can support Proxy based upgradable contract
 */
abstract contract Ownable is MainStorage{

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(msg.sender);
    }

    /**
     * @dev Only to be called by inherit contracts, in their init func called by Proxy
     * we require _owner == address(0), which is only possible when it's a delegateCall
     * because constructor sets _owner in contract state.
     */
    function initOwner() internal {
        require(_owner == address(0), "owner already set");
        _setOwner(msg.sender);
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
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
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

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "./MessageBusSender.sol";
import "./MessageBusReceiver.sol";

contract MessageBus is MessageBusSender, MessageBusReceiver {
    constructor(
        ISigsVerifier _sigsVerifier,
        address _cBridge,
        address _gateBridge
    )
    MessageBusSender(_sigsVerifier)
    MessageBusReceiver(_cBridge, _gateBridge)
    {}

    // this is only to be called by Proxy via delegateCall as initOwner will require _owner is 0.
    // so calling init on this contract directly will guarantee to fail
    function init(
        address _cBridge,
        address _gateBridge
    ) external {
        // MUST manually call ownable init and must only call once
        initOwner();
        // we don't need sender init as _sigsVerifier is immutable so already in the deployed code
        initReceiver(_cBridge, _gateBridge);
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "../libraries/MsgDataTypes.sol";
import "../interfaces/IMessageReceiverApp.sol";
import "../interfaces/IBridge.sol";
import "../libraries/Ownable.sol";
import "./SigVerifier.sol";

abstract contract MessageBusReceiver is Ownable, SigVerifier {
    mapping(bytes32 => MsgDataTypes.TxStatus) public executedMessages;

    address public cBridge;
    address public gateBridge;

    // minimum amount of gas needed by this contract before it tries to
    // deliver a message to the target contract.
    uint256 public preExecuteMessageGasUsage;

    event Executed(
        MsgDataTypes.MsgType msgType,
        bytes32 msgId,
        MsgDataTypes.TxStatus status,
        address indexed receiver,
        uint64 srcChainId,
        bytes32 srcTxHash
    );
    event NeedRetry(MsgDataTypes.MsgType msgType, bytes32 msgId, uint64 srcChainId, bytes32 srcTxHash);
    event CallReverted(string reason); // help debug

    event CBridgeUpdated(address cBridge);
    event GateBridgeUpdated(address gateBridge);

    constructor(
        address _cBridge,
        address _gateBridge
    ) {
        cBridge = _cBridge;
        gateBridge = _gateBridge;
    }

    function initReceiver(
        address _cBridge,
        address _gateBridge
    ) internal {
        require(_cBridge == address(0) && _gateBridge == address(0), "cBridge/gateBridge already set");
        cBridge = _cBridge;
        gateBridge = _gateBridge;
    }

    // ============== functions called by executor ==============

    /**
     * @notice Execute a message with a successful transfer.
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _transfer The transfer info.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function executeMessageWithTransfer(
        bytes calldata _message,
        MsgDataTypes.TransferInfo calldata _transfer,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) public payable {
        // For message with token transfer, message Id is computed through transfer info
        // in order to guarantee that each transfer can only be used once.
        bytes32 messageId = verifyTransfer(_transfer);
        require(executedMessages[messageId] == MsgDataTypes.TxStatus.Null, "transfer already executed");
        executedMessages[messageId] = MsgDataTypes.TxStatus.Pending;

        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "MessageWithTransfer"));
        SigVerifier.verifySigs(
            abi.encodePacked(domain, messageId, _message, _transfer.srcTxHash),
            _sigs,
            _signers,
            _powers
        );
        MsgDataTypes.TxStatus status;
        IMessageReceiverApp.ExecutionStatus est = executeMessageWithTransfer(_transfer, _message);
        if (est == IMessageReceiverApp.ExecutionStatus.Success) {
            status = MsgDataTypes.TxStatus.Success;
        } else if (est == IMessageReceiverApp.ExecutionStatus.Retry) {
            executedMessages[messageId] = MsgDataTypes.TxStatus.Null;
            emit NeedRetry(
                MsgDataTypes.MsgType.MessageWithTransfer,
                messageId,
                _transfer.srcChainId,
                _transfer.srcTxHash
            );
            return;
        } else {
            est = executeMessageWithTransferFallback(_transfer, _message);
            if (est == IMessageReceiverApp.ExecutionStatus.Success) {
                status = MsgDataTypes.TxStatus.Fallback;
            } else {
                status = MsgDataTypes.TxStatus.Fail;
            }
        }
        executedMessages[messageId] = status;
        emitMessageWithTransferExecutedEvent(messageId, status, _transfer);
    }

    /**
     * @notice Execute a message with a refunded transfer.
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _transfer The transfer info.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function executeMessageWithTransferRefund(
        bytes calldata _message, // the same message associated with the original transfer
        MsgDataTypes.TransferInfo calldata _transfer,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) public payable {
        // similar to executeMessageWithTransfer
        bytes32 messageId = verifyTransfer(_transfer);
        require(executedMessages[messageId] == MsgDataTypes.TxStatus.Null, "transfer already executed");
        executedMessages[messageId] = MsgDataTypes.TxStatus.Pending;

        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "MessageWithTransferRefund"));
        SigVerifier.verifySigs(
            abi.encodePacked(domain, messageId, _message, _transfer.srcTxHash),
            _sigs,
            _signers,
            _powers
        );
        MsgDataTypes.TxStatus status;
        IMessageReceiverApp.ExecutionStatus est = executeMessageWithTransferRefund(_transfer, _message);
        if (est == IMessageReceiverApp.ExecutionStatus.Success) {
            status = MsgDataTypes.TxStatus.Success;
        } else if (est == IMessageReceiverApp.ExecutionStatus.Retry) {
            executedMessages[messageId] = MsgDataTypes.TxStatus.Null;
            emit NeedRetry(
                MsgDataTypes.MsgType.MessageWithTransfer,
                messageId,
                _transfer.srcChainId,
                _transfer.srcTxHash
            );
            return;
        } else {
            status = MsgDataTypes.TxStatus.Fail;
        }
        executedMessages[messageId] = status;
        emitMessageWithTransferExecutedEvent(messageId, status, _transfer);
    }

    /**
     * @notice Execute a message not associated with a transfer.
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _route The info about the sender and the receiver.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function executeMessage(
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external payable {
        MsgDataTypes.Route memory route = getRouteInfo(_route);
        executeMessage(_message, route, _sigs, _signers, _powers, "Message");
    }

    // execute message from non-evm chain with bytes for sender address,
    // otherwise same as above.
    function executeMessage(
        bytes calldata _message,
        MsgDataTypes.RouteInfo2 calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external payable {
        MsgDataTypes.Route memory route = getRouteInfo(_route);
        executeMessage(_message, route, _sigs, _signers, _powers, "Message2");
    }

    function executeMessage(
        bytes calldata _message,
        MsgDataTypes.Route memory _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers,
        string memory domainName
    ) private {
        // For message without associated token transfer, message Id is computed through message info,
        // in order to guarantee that each message can only be applied once
        bytes32 messageId = computeMessageOnlyId(_route, _message);
        require(executedMessages[messageId] == MsgDataTypes.TxStatus.Null, "message already executed");
        executedMessages[messageId] = MsgDataTypes.TxStatus.Pending;

        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), domainName));
        SigVerifier.verifySigs(abi.encodePacked(domain, messageId), _sigs, _signers, _powers);
        MsgDataTypes.TxStatus status;
        IMessageReceiverApp.ExecutionStatus est = executeMessage(_route, _message);
        if (est == IMessageReceiverApp.ExecutionStatus.Success) {
            status = MsgDataTypes.TxStatus.Success;
        } else if (est == IMessageReceiverApp.ExecutionStatus.Retry) {
            executedMessages[messageId] = MsgDataTypes.TxStatus.Null;
            emit NeedRetry(MsgDataTypes.MsgType.MessageOnly, messageId, _route.srcChainId, _route.srcTxHash);
            return;
        } else {
            status = MsgDataTypes.TxStatus.Fail;
        }
        executedMessages[messageId] = status;
        emitMessageOnlyExecutedEvent(messageId, status, _route);
    }

    // ================= utils (to avoid stack too deep) =================

    function emitMessageWithTransferExecutedEvent(
        bytes32 _messageId,
        MsgDataTypes.TxStatus _status,
        MsgDataTypes.TransferInfo calldata _transfer
    ) private {
        emit Executed(
            MsgDataTypes.MsgType.MessageWithTransfer,
            _messageId,
            _status,
            _transfer.receiver,
            _transfer.srcChainId,
            _transfer.srcTxHash
        );
    }

    function emitMessageOnlyExecutedEvent(
        bytes32 _messageId,
        MsgDataTypes.TxStatus _status,
        MsgDataTypes.Route memory _route
    ) private {
        emit Executed(
            MsgDataTypes.MsgType.MessageOnly,
            _messageId,
            _status,
            _route.receiver,
            _route.srcChainId,
            _route.srcTxHash
        );
    }

    function executeMessageWithTransfer(MsgDataTypes.TransferInfo calldata _transfer, bytes calldata _message)
        private
        returns (IMessageReceiverApp.ExecutionStatus)
    {
        uint256 gasLeftBeforeExecution = gasleft();
        (bool ok, bytes memory res) = address(_transfer.receiver).call{value: msg.value}(
            abi.encodeWithSelector(
                IMessageReceiverApp.executeMessageWithTransfer.selector,
                _transfer.sender,
                _transfer.token,
                _transfer.amount,
                _transfer.srcChainId,
                _message,
                msg.sender
            )
        );
        if (ok) {
            return abi.decode((res), (IMessageReceiverApp.ExecutionStatus));
        }
        handleExecutionRevert(gasLeftBeforeExecution, res);
        return IMessageReceiverApp.ExecutionStatus.Fail;
    }

    function executeMessageWithTransferFallback(MsgDataTypes.TransferInfo calldata _transfer, bytes calldata _message)
        private
        returns (IMessageReceiverApp.ExecutionStatus)
    {
        uint256 gasLeftBeforeExecution = gasleft();
        (bool ok, bytes memory res) = address(_transfer.receiver).call{value: msg.value}(
            abi.encodeWithSelector(
                IMessageReceiverApp.executeMessageWithTransferFallback.selector,
                _transfer.sender,
                _transfer.token,
                _transfer.amount,
                _transfer.srcChainId,
                _message,
                msg.sender
            )
        );
        if (ok) {
            return abi.decode((res), (IMessageReceiverApp.ExecutionStatus));
        }
        handleExecutionRevert(gasLeftBeforeExecution, res);
        return IMessageReceiverApp.ExecutionStatus.Fail;
    }

    function executeMessageWithTransferRefund(MsgDataTypes.TransferInfo calldata _transfer, bytes calldata _message)
        private
        returns (IMessageReceiverApp.ExecutionStatus)
    {
        uint256 gasLeftBeforeExecution = gasleft();
        (bool ok, bytes memory res) = address(_transfer.receiver).call{value: msg.value}(
            abi.encodeWithSelector(
                IMessageReceiverApp.executeMessageWithTransferRefund.selector,
                _transfer.token,
                _transfer.amount,
                _message,
                msg.sender
            )
        );
        if (ok) {
            return abi.decode((res), (IMessageReceiverApp.ExecutionStatus));
        }
        handleExecutionRevert(gasLeftBeforeExecution, res);
        return IMessageReceiverApp.ExecutionStatus.Fail;
    }

    function verifyTransfer(MsgDataTypes.TransferInfo calldata _transfer) private view returns (bytes32) {
        bytes32 transferId = keccak256(
            abi.encodePacked(
                _transfer.sender,
                _transfer.receiver,
                _transfer.token,
                _transfer.amount,
                _transfer.srcChainId,
                uint64(block.chainid),
                _transfer.refId
            )
        );
        return keccak256(abi.encodePacked(MsgDataTypes.MsgType.MessageWithTransfer, _transfer.t, transferId));
    }

    function computeMessageOnlyId(MsgDataTypes.Route memory _route, bytes calldata _message)
        private
        view
        returns (bytes32)
    {
        bytes memory sender = _route.senderBytes;
        if (sender.length == 0) {
            sender = abi.encodePacked(_route.sender);
        }
        return
            keccak256(
                abi.encodePacked(
                    MsgDataTypes.MsgType.MessageOnly,
                    sender,
                    _route.receiver,
                    _route.srcChainId,
                    _route.srcTxHash,
                    uint64(block.chainid),
                    _message
                )
            );
    }

    function executeMessage(MsgDataTypes.Route memory _route, bytes calldata _message)
        private
        returns (IMessageReceiverApp.ExecutionStatus)
    {
        uint256 gasLeftBeforeExecution = gasleft();
        bool ok;
        bytes memory res;
        if (_route.senderBytes.length == 0) {
            (ok, res) = address(_route.receiver).call{value: msg.value}(
                abi.encodeWithSelector(
                    bytes4(keccak256(bytes("executeMessage(address,uint64,bytes,address)"))),
                    _route.sender,
                    _route.srcChainId,
                    _message,
                    msg.sender
                )
            );
        } else {
            (ok, res) = address(_route.receiver).call{value: msg.value}(
                abi.encodeWithSelector(
                    bytes4(keccak256(bytes("executeMessage(bytes,uint64,bytes,address)"))),
                    _route.senderBytes,
                    _route.srcChainId,
                    _message,
                    msg.sender
                )
            );
        }
        if (ok) {
            return abi.decode((res), (IMessageReceiverApp.ExecutionStatus));
        }
        handleExecutionRevert(gasLeftBeforeExecution, res);
        return IMessageReceiverApp.ExecutionStatus.Fail;
    }

    function handleExecutionRevert(uint256 _gasLeftBeforeExecution, bytes memory _returnData) private {
        uint256 gasLeftAfterExecution = gasleft();
        uint256 maxTargetGasLimit = block.gaslimit - preExecuteMessageGasUsage;
        if (_gasLeftBeforeExecution < maxTargetGasLimit && gasLeftAfterExecution <= _gasLeftBeforeExecution / 64) {
            // if this happens, the executor must have not provided sufficient gas limit,
            // then the tx should revert instead of recording a non-retryable failure status
            // https://github.com/wolflo/evm-opcodes/blob/main/gas.md#aa-f-gas-to-send-with-call-operations
            assembly {
                invalid()
            }
        }
        emit CallReverted(getRevertMsg(_returnData));
    }

    // https://ethereum.stackexchange.com/a/83577
    // https://github.com/Uniswap/v3-periphery/blob/v1.0.0/contracts/base/Multicall.sol
    function getRevertMsg(bytes memory _returnData) private pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";
        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    function getRouteInfo(MsgDataTypes.RouteInfo calldata _route) private pure returns (MsgDataTypes.Route memory) {
        return MsgDataTypes.Route(_route.sender, "", _route.receiver, _route.srcChainId, _route.srcTxHash);
    }

    function getRouteInfo(MsgDataTypes.RouteInfo2 calldata _route) private pure returns (MsgDataTypes.Route memory) {
        return MsgDataTypes.Route(address(0), _route.sender, _route.receiver, _route.srcChainId, _route.srcTxHash);
    }

    // ================= contract config ==================

    function setCBridge(address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        cBridge = _addr;
        emit CBridgeUpdated(cBridge);
    }

    function setGateBridge(address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        gateBridge = _addr;
        emit GateBridgeUpdated(gateBridge);
    }

    function setPreExecuteMessageGasUsage(uint256 _usage) public onlyOwner {
        preExecuteMessageGasUsage = _usage;
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "../libraries/Ownable.sol";
import "./SigVerifier.sol";

contract MessageBusSender is Ownable, SigVerifier {

    uint256 public feeBase;
    uint256 public feePerByte;
    mapping(address => uint256) public withdrawnFees;

    event Message(address indexed sender, address receiver, uint256 dstChainId, bytes message, uint256 fee);
    // message to non-evm chain with >20 bytes addr
    event Message2(address indexed sender, bytes receiver, uint256 dstChainId, bytes message, uint256 fee);

    event MessageWithTransfer(
        address indexed sender,
        address receiver,
        uint256 dstChainId,
        address bridge,
        bytes32 srcTransferId,
        bytes message,
        uint256 fee
    );

    event FeeWithdrawn(address receiver, uint256 amount);

    event FeeBaseUpdated(uint256 feeBase);
    event FeePerByteUpdated(uint256 feePerByte);

    constructor(ISigsVerifier _sigsVerifier) SigVerifier(_sigsVerifier)  {
    }

    /**
     * @notice Sends a message to a contract on another chain.
     * Sender needs to make sure the uniqueness of the message Id, which is computed as
     * hash(type.MessageOnly, sender, receiver, srcChainId, srcTxHash, dstChainId, message).
     * If messages with the same Id are sent, only one of them will succeed at dst chain.
     * A fee is charged in the native gas token.
     * @param _receiver The address of the destination app contract.
     * @param _dstChainId The destination chain ID.
     * @param _message Arbitrary message bytes to be decoded by the destination app contract.
     */
    function sendMessage(
        address _receiver,
        uint256 _dstChainId,
        bytes calldata _message
    ) external payable {
        _sendMessage(_dstChainId, _message);
        emit Message(msg.sender, _receiver, _dstChainId, _message, msg.value);
    }

    // Send message to non-evm chain with bytes for receiver address,
    // otherwise same as above.
    function sendMessage(
        bytes calldata _receiver,
        uint256 _dstChainId,
        bytes calldata _message
    ) external payable {
        _sendMessage(_dstChainId, _message);
        emit Message2(msg.sender, _receiver, _dstChainId, _message, msg.value);
    }

    function _sendMessage(uint256 _dstChainId, bytes calldata _message) private {
        require(_dstChainId != block.chainid, "Invalid chainId");
        uint256 minFee = calcFee(_message);
        require(msg.value >= minFee, "Insufficient fee");
    }

    /**
     * @notice Sends a message associated with a transfer to a contract on another chain.
     * If messages with the same srcTransferId are sent, only one of them will succeed.
     * A fee is charged in the native token.
     * @param _receiver The address of the destination app contract.
     * @param _dstChainId The destination chain ID.
     * @param _srcBridge The bridge contract to send the transfer with.
     * @param _srcTransferId The transfer ID.
     * @param _dstChainId The destination chain ID.
     * @param _message Arbitrary message bytes to be decoded by the destination app contract.
     */
    function sendMessageWithTransfer(
        address _receiver,
        uint256 _dstChainId,
        address _srcBridge,
        bytes32 _srcTransferId,
        bytes calldata _message
    ) external payable {
        require(_dstChainId != block.chainid, "Invalid chainId");
        uint256 minFee = calcFee(_message);
        require(msg.value >= minFee, "Insufficient fee");
        // SGN needs to verify
        // 1. msg.sender matches sender of the src transfer
        // 2. dstChainId matches dstChainId of the src transfer
        // 3. bridge is either liquidity bridge, peg src vault, or peg dst bridge
        emit MessageWithTransfer(msg.sender, _receiver, _dstChainId, _srcBridge, _srcTransferId, _message, msg.value);
    }

    /**
     * @notice Withdraws message fee in the form of native gas token.
     * @param _account The address receiving the fee.
     * @param _cumulativeFee The cumulative fee credited to the account. Tracked by SGN.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A withdrawal must be
     * signed-off by +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function withdrawFee(
        address _account,
        uint256 _cumulativeFee,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external {
        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "withdrawFee"));
        SigVerifier.verifySigs(abi.encodePacked(domain, _account, _cumulativeFee), _sigs, _signers, _powers);
        uint256 amount = _cumulativeFee - withdrawnFees[_account];
        require(amount > 0, "No new amount to withdraw");
        withdrawnFees[_account] = _cumulativeFee;
        (bool sent, ) = _account.call{value: amount, gas: 50000}("");
        require(sent, "failed to withdraw fee");
        emit FeeWithdrawn(_account, amount);
    }

    /**
     * @notice Calculates the required fee for the message.
     * @param _message Arbitrary message bytes to be decoded by the destination app contract.
     @ @return The required fee.
     */
    function calcFee(bytes calldata _message) public view returns (uint256) {
        return feeBase + _message.length * feePerByte;
    }

    // -------------------- Admin --------------------

    function setFeePerByte(uint256 _fee) external onlyOwner {
        feePerByte = _fee;
        emit FeePerByteUpdated(feePerByte);
    }

    function setFeeBase(uint256 _fee) external onlyOwner {
        feeBase = _fee;
        emit FeeBaseUpdated(feeBase);
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "../interfaces/ISigsVerifier.sol";

contract SigVerifier {
    ISigsVerifier public immutable sigsVerifier;

    constructor(
        ISigsVerifier _sigsVerifier
    ) {
        sigsVerifier = _sigsVerifier;
    }

    function verifySigs(
        bytes memory _msg,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) public view {
        sigsVerifier.verifySigs(_msg, _sigs, _signers, _powers);
    }
}