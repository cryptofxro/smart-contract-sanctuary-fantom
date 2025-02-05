/**
 *Submitted for verification at FtmScan.com on 2023-05-28
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract SlotTest {
    address public addr;
    uint256 public num;
    mapping(address => uint256) public numByAddr;
    mapping(uint256 => address) public addByNum;
    mapping(address => mapping(address => uint256)) public allowance;

    function setAddress(address _addr) external {
        addr = _addr;
    }

    function setNum(uint256 _num) external {
        num = _num;
    }

    function setNumByAddr(address _addr, uint256 _num) external {
        numByAddr[_addr] = _num;
    }

    function setAddrByNum(address _num, uint256 _addr) external {
        numByAddr[_num] = _addr;
    }

    function setAllowance(address _spender, address _owner, uint256 _num) external {
        allowance[_spender][_owner] = _num;
    }
}