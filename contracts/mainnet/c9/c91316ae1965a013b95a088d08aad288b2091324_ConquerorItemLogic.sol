/**
 *Submitted for verification at FtmScan.com on 2022-06-27
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface ILIQUIDRNG {

	function random1(uint256 mod, uint256 demod) external view returns (uint256);
	function random2(uint256 mod, uint256 demod) external view returns (uint256);
	function random3(uint256 mod, uint256 demod) external view returns (uint256);
	function random4(uint256 mod, uint256 demod) external view returns (uint256);
	function random5(uint256 mod, uint256 demod) external view returns (uint256);
    function random6(uint256 mod, uint256 demod) external view returns (uint256);
	function random7(uint256 mod, uint256 demod) external view returns (uint256);
	function random8(uint256 mod, uint256 demod) external view returns (uint256);
 	function requestMixup() external;
}

interface IERC165 {

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}    

interface IMJOL1155 is IERC165 {

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    event URI(string value, uint256 indexed id);

    function balanceOf(address account, uint256 id) external view returns (uint256);

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    function setApprovalForAll(address operator, bool approved) external;

    function isApprovedForAll(address account, address operator) external view returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;

     function mint(address _to, uint _id, uint _amount) external;
     function mintBatch(address _to, uint[] memory _ids, uint[] memory _amounts) external;
     function burn(address account, uint _id, uint _amount) external;
     function burnBatch(address account, uint[] memory _ids, uint[] memory _amounts) external;
     function burnForMint(address _from, uint[] memory _burnIds, uint[] memory _burnAmounts, uint[] memory _mintIds, uint[] memory _mintAmounts) external;
     function setURI(uint _id, string memory _uri) external;
}

abstract contract MjolnirRBAC {
    mapping(address => bool) internal _thors;

    modifier onlyThor() {
        require(
            _thors[msg.sender] == true || address(this) == msg.sender,
            "Caller cannot wield Mjolnir"
        );
        _;
    }

    function addThor(address _thor)
        external
        onlyOwner
    {
        _thors[_thor] = true;
    }

    function delThor(address _thor)
        external
        onlyOwner
    {
        delete _thors[_thor];
    }

    function disableThor(address _thor)
        external
        onlyOwner
    {
        _thors[_thor] = false;
    }

    function isThor(address _address)
        external
        view
        returns (bool allowed)
    {
        allowed = _thors[_address];
    }

    function toAsgard() external onlyThor {
        delete _thors[msg.sender];
    }
    //Oracle-Role
    mapping(address => bool) internal _oracles;

    modifier onlyOracle() {
        require(
            _oracles[msg.sender] == true || address(this) == msg.sender,
            "Caller is not the Oracle"
        );
        _;
    }

    function addOracle(address _oracle)
        external
        onlyOwner
    {
        _oracles[_oracle] = true;
    }

    function delOracle(address _oracle)
        external
        onlyOwner
    {
        delete _oracles[_oracle];
    }

    function disableOracle(address _oracle)
        external
        onlyOwner
    {
        _oracles[_oracle] = false;
    }

    function isOracle(address _address)
        external
        view
        returns (bool allowed)
    {
        allowed = _oracles[_address];
    }

    function relinquishOracle() external onlyOracle {
        delete _oracles[msg.sender];
    }
    //Ownable-Compatability
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() {
        _transferOwnership(_msgSender());
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    //contextCompatability
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract ConquerorItemLogic is MjolnirRBAC {

    address public base = 0x20230d3905091a16bd9d2Aa379bDdF2C92FbE5aA;
    address public setter = 0x564e9155Ff9268B4B7dA4F7b5fCa000Ea0f46Ebb;
	address private randomizer = 0xb782EF2742611255e3876F91639e9412A36b3Da3;
    IMJOL1155 bs = IMJOL1155(base);
    ILIQUIDRNG rng = ILIQUIDRNG(randomizer);


  function setURI(uint _id, string memory _uri) external onlyThor {
    require(msg.sender == setter);
    bs.setURI(_id, _uri);
  }

  function mintOffensive(address account) external onlyThor {
	rng.requestMixup();
	bs.mint(
		account,
		rng.random1(25,26),
		1
		);
	}
	
  function mintDefensive(address account) external onlyThor {
	rng.requestMixup();
	bs.mint(
		account,
		rng.random6(25,1),
		1
		);
	}

  function batchOffensive(address account) external onlyThor {
        rng.requestMixup();
        uint256 r1 = rng.random1(25,26);
        uint256 r2 = rng.random2(25,26);
        uint256 r3 = rng.random3(25,26);
        uint256 r4 = rng.random4(25,26);
        uint256 r5 = rng.random5(25,26);
        uint256[] memory rs = new uint[](5);
        uint256[] memory qs = new uint[](5);
        rs[0] = r1;
        rs[1] = r2;
        rs[2] = r3;
        rs[3] = r4;
        rs[4] = r5;
        qs[0] = 1;
        qs[1] = 1;
        qs[2] = 1;
        qs[3] = 1;
        qs[4] = 1;
        bs.mintBatch(
            account,
            rs,
            qs
        );       
    }
	
  function batchDefensive(address account) external onlyThor {
        rng.requestMixup();
        uint256 r1 = rng.random6(25,1);
        uint256 r2 = rng.random7(25,1);
        uint256 r3 = rng.random8(25,1);
        uint256 r4 = rng.random1(25,1);
        uint256 r5 = rng.random2(25,1);
        uint256[] memory rs = new uint[](5);
        uint256[] memory qs = new uint[](5);
        rs[0] = r1;
        rs[1] = r2;
        rs[2] = r3;
        rs[3] = r4;
        rs[4] = r5;
        qs[0] = 1;
        qs[1] = 1;
        qs[2] = 1;
        qs[3] = 1;
        qs[4] = 1;
        bs.mintBatch(
            account,
            rs,
            qs
        );       
    }
	
	function tradeWarMonger(uint256 item) external onlyThor {
    rng.requestMixup();
	bs.burn(tx.origin, item, 1);
	if (item <= 25) {
	bs.mint(
		tx.origin,
		rng.random2(25,1),
		1
	  );}
	if (item >= 26) {
	bs.mint(
		tx.origin,
		rng.random7(25,26),
		1
	  );}
	}
	
	function fullRangeRoll(address account) external onlyThor {
	rng.requestMixup();
	bs.mint(
		account,
		rng.random1(50,1),
		1
	  );
	}

    function setSetter(address value) external onlyOwner {
    setter = value;
    }
    function setBase(address value) external onlyOwner {
    base = value;
    }
    function setRNG(address value) external onlyOwner {
    randomizer = value;
    }
}

//     _.-^^---....,,--       
// _--                  --_  
//<                        >)
//|                         | 
// \._                   _./  
//    ```--. . , ; .--'''       
//          | |   |             
//       .-=||  | |=-.   
//       `-=#$%&%$#=-'   
//          | ;  :|     
// _____.,-#%&[email protected]%#&#~,._____

//  ██▓     ▄████▄  ▓█████ 
// ▓██▒    ▒██▀ ▀█  ▓█   ▀ 
// ▒██░    ▒▓█    ▄ ▒███   
// ▒██░    ▒▓▓▄ ▄██▒▒▓█  ▄ 
// ░██████▒▒ ▓███▀ ░░▒████▒
// ░ ▒░▓  ░░ ░▒ ▒  ░░░ ▒░ ░
// ░ ░ ▒  ░  ░  ▒    ░ ░  ░
//   ░ ░   ░           ░   
//     ░  ░░ ░         ░  ░
//         ░