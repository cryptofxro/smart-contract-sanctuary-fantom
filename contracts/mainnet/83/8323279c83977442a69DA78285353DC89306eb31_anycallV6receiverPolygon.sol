/**
 *Submitted for verification at FtmScan.com on 2022-09-02
*/

/**
 *Submitted for verification at polygonscan.com on 2022-05-19
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract anycallV6receiverPolygon{
    event NewMsg(string msg);



    function anyExecute(bytes memory _data) external returns (bool success, bytes memory result){
        (string memory _msg) = abi.decode(_data, (string));  
        emit NewMsg(_msg);
        success=true;
        result='';

    }


    function anyExecuteTest(bytes memory _data) external {
        (string memory _msg) = abi.decode(_data, (string));  
        emit NewMsg(_msg);
    }

}