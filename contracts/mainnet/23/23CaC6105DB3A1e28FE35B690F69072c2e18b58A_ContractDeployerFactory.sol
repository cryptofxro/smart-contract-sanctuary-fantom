// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

contract ContractDeployerFactory {
    event ContractDeployed(bytes32 salt, address addr);

    /**
     * deploy contract by salt, contract bytecode.
     */
    function deployContract(bytes32 salt, bytes memory contractBytecode)
        public
    {
        address addr;
        assembly {
            addr := create2(
                0,
                add(contractBytecode, 0x20),
                mload(contractBytecode),
                salt
            )
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        emit ContractDeployed(salt, addr);
    }

    /**
     * deploy contract by salt, contract bytecode and constructor args.
     */
    function deployContractWithConstructor(
        bytes32 salt,
        bytes memory contractBytecode,
        bytes memory constructorArgs
    ) public {
        // deploy contracts with constructor (address):
        bytes memory payload = abi.encodePacked(
            contractBytecode,
            constructorArgs
        );
        address addr;
        assembly {
            addr := create2(0, add(payload, 0x20), mload(payload), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        emit ContractDeployed(salt, addr);
    }
}