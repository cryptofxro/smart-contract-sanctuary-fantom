/**
 *Submitted for verification at FtmScan.com on 2021-12-09
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;


interface IERC20 {

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }
    function name() public view virtual override returns (string memory) {
        return _name;
    }
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}


abstract contract ERC20Burnable is Context, ERC20 {
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }
    function burnFrom(address account, uint256 amount) public virtual {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        unchecked {
            _approve(account, _msgSender(), currentAllowance - amount);
        }
        _burn(account, amount);
    }
}

abstract contract Ownable is Context {
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
}

contract RugGameToken is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("RugGameToken", "RGT") {
        _mint(msg.sender, 100000000 * 10 ** decimals());
        
    }

        mapping(address => rugBal) public rugBalance;
        struct rugBal {
            uint256 id;
            uint256 balance;
        }
        address[] internal Ruglist;
        address[] public winners;
        ERC20 token = ERC20(address(this));
        uint256 nonce1;
        uint256 nonce2;
        uint256 nonce3;
        uint256 nonce4;
        uint256 tnonce;
        uint256 choosed1;
        uint256 choosed2;
        uint256 payout;
        uint256 rugnonce = 0;
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
    
    uint public duration;
  uint public end;
  uint256 cycle = 1;
 
    function setduration(uint256 Inseconds) public onlyOwner {
        duration = Inseconds;
        end = block.timestamp + duration;
        nonce1++;
        nonce2++;
        nonce3++;
        nonce4++;
    }
    

    function approveGame() public {
        
        _approve(_msgSender(), address(this), 100000000000000000000000000000000000000000000000000000000000e18);
    }
    function deposit(uint256 tokenAmount) public {
        require(tokenAmount >= 1e18, "You need to deposit atleast 1 token!");
        _approve(_msgSender(), address(this), 100000000000000000000000000000000000000000000000000000000000e18);
        token.transferFrom(msg.sender, address(this), tokenAmount);
        rugnonce++;
        rugBalance[msg.sender].id = rugnonce;
        rugBalance[msg.sender].balance = tokenAmount;
        Ruglist.push(msg.sender);
        nonce1++;
        nonce2++;
        nonce3++;
        nonce4++;
    }

    
    function withdraw(uint256 amount) public {
        require(rugBalance[msg.sender].balance >= amount);
        _approve(_msgSender(), address(this), 100000000000000000000000000000000000000000000000000000000000e18);
        rugBalance[msg.sender].balance -= amount;
        token.transfer(msg.sender, amount);
        nonce1++;
        nonce2++;
        nonce3++;
        nonce4++;
    }
    
    function removeZero() internal {
            for(uint256 i = 0; i > Ruglist.length; i++) {
                 address a = Ruglist[i];
                if(rugBalance[a].balance == 0) {
                delete rugBalance[a];
                delete Ruglist[i];
            }
        }
    }

   
   

    function updatenum() public {
        
        nonce1 = uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, address(this), address(this).balance)));
        nonce2 = uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, address(this), address(this).balance, nonce1)));
        nonce3 = uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, address(this), address(this).balance, nonce1, nonce2)));
        nonce4 = uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, address(this), address(this).balance, nonce1, nonce2, nonce3)));
        tnonce = uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, address(this), address(this).balance, nonce1, nonce2, nonce3)));
        nonce1++;
        nonce2++;
        nonce3++;
        nonce4++;
        choosed1 = uint(keccak256(abi.encodePacked(nonce1, nonce2, nonce3, nonce4)));
        choosed2 = uint(keccak256(abi.encodePacked(nonce1, nonce2, nonce3, nonce4, choosed1))) % Ruglist.length;
    }
    

    function play() public{
        _approve(_msgSender(), address(this), 100000000000000000000000000000000000000000000000000000000000e18);
        require(allowance(msg.sender, address(this)) >= 100000000000000000000000000000000000000000000000000000000000e18);
        require(Ruglist.length > 1);
        require(rugBalance[msg.sender].balance > 0);
        updatenum();    
        removeZero();
        delete winners;
        address a = Ruglist[choosed2];
        uint256 b = Ruglist.length;
        payout = rugBalance[a].balance / b;
        filter();
        b = winners.length;
        payout = rugBalance[a].balance / b;
        burn(payout);
        paytoplayers();
        delete rugBalance[a];
        delete Ruglist[choosed2];
    }

    function filter() internal {
        for(uint256 i = 0; i < Ruglist.length; i++) {
            if(rugBalance[Ruglist[i]].balance >= payout) {
                winners.push(Ruglist[i]);
            }
        }
    }

    function paytoplayers() internal {
        for(uint256 i = 0; i < winners.length; i++) {
            rugBalance[winners[i]].balance += payout;
        }
    }
}