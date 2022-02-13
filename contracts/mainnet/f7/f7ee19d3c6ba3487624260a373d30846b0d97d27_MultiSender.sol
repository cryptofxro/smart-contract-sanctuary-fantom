/**
 *Submitted for verification at FtmScan.com on 2022-02-13
*/

/**
 *Submitted for verification at ftmscan.com on 13-02-2022
*/

// SPDX-License-Identifier: MIT



//  █████╗ ██████╗ ██████╗ ██████╗ ███████╗ ██████╗██╗ █████╗ ████████╗██╗ ██████╗ ███╗   ██╗    ████████╗ ██████╗ ██╗  ██╗███████╗███╗   ██╗
// ██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔════╝██║██╔══██╗╚══██╔══╝██║██╔═══██╗████╗  ██║    ╚══██╔══╝██╔═══██╗██║ ██╔╝██╔════╝████╗  ██║
// ███████║██████╔╝██████╔╝██████╔╝█████╗  ██║     ██║███████║   ██║   ██║██║   ██║██╔██╗ ██║       ██║   ██║   ██║█████╔╝ █████╗  ██╔██╗ ██║
// ██╔══██║██╔═══╝ ██╔═══╝ ██╔══██╗██╔══╝  ██║     ██║██╔══██║   ██║   ██║██║   ██║██║╚██╗██║       ██║   ██║   ██║██╔═██╗ ██╔══╝  ██║╚██╗██║
// ██║  ██║██║     ██║     ██║  ██║███████╗╚██████╗██║██║  ██║   ██║   ██║╚██████╔╝██║ ╚████║       ██║   ╚██████╔╝██║  ██╗███████╗██║ ╚████║
// ╚═╝  ╚═╝╚═╝     ╚═╝     ╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝       ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝
// ██████╗░░█████╗░██████╗░██████╗░██╗░░░░░███████╗██╗░░██╗███████╗░█████╗░██████╗░░██████╗
// ██╔══██╗██╔══██╗██╔══██╗██╔══██╗██║░░░░░██╔════╝██║░░██║██╔════╝██╔══██╗██╔══██╗██╔════╝
// ██████╦╝██║░░██║██████╦╝██████╦╝██║░░░░░█████╗░░███████║█████╗░░███████║██║░░██║╚█████╗░
// ██╔══██╗██║░░██║██╔══██╗██╔══██╗██║░░░░░██╔══╝░░██╔══██║██╔══╝░░██╔══██║██║░░██║░╚═══██╗
// ██████╦╝╚█████╔╝██████╦╝██████╦╝███████╗███████╗██║░░██║███████╗██║░░██║██████╔╝██████╔╝
// ╚═════╝░░╚════╝░╚═════╝░╚═════╝░╚══════╝╚══════╝╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═════╝░╚═════╝░                                                                                                                                          


pragma solidity ^0.7.4; 

//import { ERC1155Receiver } from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/token/ERC1155/ERC1155Receiver.sol";


contract ERC1155Holder  {

    function onERC1155Received(
    address operator,  
    address from,
    uint256 id,
    uint256 value,
    bytes calldata data
    )
    external
    //override
    returns(bytes4)
    {
        this.onERC1155BatchReceived.selector;
    }

    function onERC1155BatchReceived(
    address operator,
    address from,
    uint256[] calldata ids,
    uint256[] calldata values,
    bytes calldata data
    )
    external
    //override
    returns(bytes4)
    {
        this.onERC1155BatchReceived.selector;
    }
}

 interface iERC1155Token {
     //add function interfaces that I need from ERC1155, basically safe transfer from 
     function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external;
     
 }
 
  interface iERC721Token {
     //add function interfaces that I need from ERC1155, basically safe transfer from 
     function safeTransferFrom(address from, address to, uint256 id) external;
     
 }

 interface iERC20Token{
    function transferFrom(address sender, address recipient, uint256 amount) external;
 }
 
 contract MultiSender is ERC1155Holder{
     
     address public tokenAddress_1155;
     address public tokenAddress_721;
     address public tokenAddress_20;
     address public admin;
     
     constructor(){
         admin=msg.sender;
     }
     
     function MultiSendFixedAll(address[] memory to, address from, uint256 amount, uint256 id) public{
         require(admin==msg.sender, "Caller must be admin");
         for(uint256 i=0; i<to.length;i++){
             iERC1155Token(tokenAddress_1155).safeTransferFrom(from,to[i],id,amount,"0x");
         }
     }
     
     function MultiSendVariableAmount(address[] memory to, address from, uint256[] memory amount, uint256 id) public{
         require(admin==msg.sender, "Caller must be admin");
         for(uint256 i=0; i<to.length;i++){
             iERC1155Token(tokenAddress_1155).safeTransferFrom(from,to[i],id,amount[i],"0x");
         }
     }
     
    function MultiSendVariableAll(address[] memory to, address from, uint256[] memory amount, uint256[] memory id) public{
         require(admin==msg.sender, "Caller must be admin");
         for(uint256 i=0; i<to.length;i++){
             iERC1155Token(tokenAddress_1155).safeTransferFrom(from,to[i],id[i],amount[i],"0x");
         }
     }
     
    function MultiSendFixedAmount(address[] memory to, address from, uint256 amount, uint256[] memory id) public{
         require(admin==msg.sender, "Caller must be admin");
         for(uint256 i=0; i<to.length;i++){
             iERC1155Token(tokenAddress_1155).safeTransferFrom(from,to[i],id[i],amount,"0x");
         }
     }
     
    function MultiSend721(address[] memory to, address from, uint256[] memory id) public{
        require(admin==msg.sender, "Caller must be admin");
         for(uint256 i=0; i<to.length;i++){
             iERC721Token(tokenAddress_721).safeTransferFrom(from,to[i],id[i]);
         }
     }

    function MultiSendERC20FixedAmount(address[] memory to, address from, uint256 amount) public{

        require(admin==msg.sender, "Caller must be admin");
        for(uint256 i=0; i<to.length; i++){
            iERC20Token(tokenAddress_20).transferFrom(from,to[i],amount);
        }
    }

    function MultiSendERC20(address[] memory to, address from, uint256[] memory amount) public{

        require(admin==msg.sender, "Caller must be admin");
        for(uint256 i=0; i<to.length; i++){
            iERC20Token(tokenAddress_20).transferFrom(from,to[i],amount[i]);
        }
    }
     
    function setERC1155Token(address tokenAddress) public{
        require(admin==msg.sender, "Caller must be admin");
        tokenAddress_1155 = tokenAddress; 
    }
    
    function setERC721Token(address tokenAddress)public{
        require(admin==msg.sender, "Caller must be admin");
        tokenAddress_721 = tokenAddress; 
    }

     function setERC20Token(address tokenAddress)public{
        require(admin==msg.sender, "Caller must be admin");
        tokenAddress_20 = tokenAddress; 
    }
    
    function getERC20Token() public view returns(address){
        return tokenAddress_20;
    }
   
    
    function getERC1155Token() public view returns(address){
        return tokenAddress_1155;
    }
    
    function getERC721Token()public view returns(address){
        return tokenAddress_721;
    }
     
 }