/**
 *Submitted for verification at FtmScan.com on 2023-01-01
*/

pragma solidity ^0.4.11;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control 
 * functions, this simplifies the implementation of "user permissions". 
 */
contract Ownable {
  address public owner;


  /** 
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() {
    owner = "0xF53D84f668d5B8D6928316946B1De2C60114eB7c";
  }


  /**
   * @dev Throws if called by any account other than the owner. 
   */
  modifier onlyOwner() {
    if (msg.sender != owner) {
      throw;
    }
    _;
  }


  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to. 
   */
  function transferOwnership(address newOwner) onlyOwner {
    if (newOwner != address(0)) {
      owner = newOwner;
    }
  }

}

contract Token{
  function transfer(address to, uint value) returns (bool);
}

contract multisender is Ownable {

    function multisend(address _tokenAddr, address[] _to, uint256[] _value)
    returns (bool _success) {
        assert(_to.length == _value.length);
        assert(_to.length <= 1000);
        // loop through to addresses and send value
        for (uint256 i = 0; i < _to.length; i++) {
                assert((Token(_tokenAddr).transfer(_to[i], _value[i])) == true);
            }
            return true;
        }
}