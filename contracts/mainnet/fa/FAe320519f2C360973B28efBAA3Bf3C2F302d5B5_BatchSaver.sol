// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.0;


interface IEverscale {
    struct EverscaleAddress {
        int8 wid;
        uint256 addr;
    }

    struct EverscaleEvent {
        uint64 eventTransactionLt;
        uint32 eventTimestamp;
        bytes eventData;
        int8 configurationWid;
        uint256 configurationAddress;
        int8 eventContractWid;
        uint256 eventContractAddress;
        address proxy;
        uint32 round;
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.0;


import "./../IEverscale.sol";


interface IMultiVaultFacetTokens {
    enum TokenType { Native, Alien }

    struct TokenPrefix {
        uint activation;
        string name;
        string symbol;
    }

    struct TokenMeta {
        string name;
        string symbol;
        uint8 decimals;
    }

    struct Token {
        uint activation;
        bool blacklisted;
        uint depositFee;
        uint withdrawFee;
        bool isNative;
        address custom;
    }

    function prefixes(address _token) external view returns (TokenPrefix memory);
    function tokens(address _token) external view returns (Token memory);
    function natives(address _token) external view returns (IEverscale.EverscaleAddress memory);

    function setPrefix(
        address token,
        string memory name_prefix,
        string memory symbol_prefix
    ) external;

    function setTokenBlacklist(
        address token,
        bool blacklisted
    ) external;

    function getNativeToken(
        IEverscale.EverscaleAddress memory native
    ) external view returns (address);
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.0;


import "./IMultiVaultFacetTokens.sol";
import "../IEverscale.sol";


interface IMultiVaultFacetWithdraw {
    struct Callback {
        address recipient;
        bytes payload;
        bool strict;
    }

    struct NativeWithdrawalParams {
        IEverscale.EverscaleAddress native;
        IMultiVaultFacetTokens.TokenMeta meta;
        uint256 amount;
        address recipient;
        uint256 chainId;
        Callback callback;
    }

    struct AlienWithdrawalParams {
        address token;
        uint256 amount;
        address recipient;
        uint256 chainId;
        Callback callback;
    }

    function withdrawalIds(bytes32) external view returns (bool);

    function saveWithdrawNative(
        bytes memory payload,
        bytes[] memory signatures
    ) external;

    function saveWithdrawAlien(
        bytes memory payload,
        bytes[] memory signatures
    ) external;

    function saveWithdrawAlien(
        bytes memory payload,
        bytes[] memory signatures,
        uint bounty
    ) external;
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.0;


import "../multivault/interfaces/multivault/IMultiVaultFacetWithdraw.sol";


contract BatchSaver {
    address immutable public multivault;

    constructor(
        address _multivault
    ) {
        multivault = _multivault;
    }

    event WithdrawalAlreadyUsed(bytes32 indexed withdrawalId);
    event WithdrawalSaved(bytes32 indexed withdrawalId);

    struct Withdraw {
        bool isNative;
        bytes payload;
        bytes[] signatures;
    }

    function checkWithdrawalAlreadySeen(bytes32 withdrawalId) public view returns (bool) {
        return IMultiVaultFacetWithdraw(multivault).withdrawalIds(withdrawalId);
    }

    function saveWithdrawals(
        Withdraw[] memory withdrawals
    ) external {
        for (uint i = 0; i < withdrawals.length; i++) {
            Withdraw memory withdraw = withdrawals[i];

            bytes32 withdrawalId = keccak256(withdraw.payload);

            if (checkWithdrawalAlreadySeen(withdrawalId)) {
                emit WithdrawalAlreadyUsed(withdrawalId);

                continue;
            }

            if (withdraw.isNative) {
                IMultiVaultFacetWithdraw(multivault).saveWithdrawNative(
                    withdraw.payload,
                    withdraw.signatures
                );
            } else {
                IMultiVaultFacetWithdraw(multivault).saveWithdrawAlien(
                    withdraw.payload,
                    withdraw.signatures
                );
            }

            emit WithdrawalSaved(withdrawalId);
        }
    }
}