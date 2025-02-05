/**
 *Submitted for verification at FtmScan.com on 2022-10-08
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IClown {
    function harvest() external;
}

interface ERC20 {
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract Spug {
    address _donatoor;

    constructor(address donatoor) {
        _donatoor = donatoor;
    }

    function getDonator() external view returns (address) {
        return _donatoor;
    }

    ERC20 private constant usdc =
        ERC20(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75);

    address[2] spugetti = [
        0x61fdd6e96581cEdA2Dd5Ec6E4F61E2E89f97Bd44,
        0x935e97FBc9173e8Ec332411EA0e2C3594fb89e01
    ];

    function ayyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy()
        external
    {
        IClown(spugetti[0]).harvest();
        IClown(spugetti[1]).harvest();
        usdc.transfer(this.getDonator(), usdc.balanceOf(address(this)));
    }
}