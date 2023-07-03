/**
 *Submitted for verification at FtmScan.com on 2023-07-03
*/

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// File: contracts/RECEIVER.sol


pragma solidity ^0.8.7;


contract NEKO_TEST_TOKEN_RECEIVER {

    address owner;
    mapping(address => bool) public receiverAuth;
    mapping(address => uint256) public tokensWithdrawn;

    address[] public knownTokens;

    constructor(){
        owner = msg.sender;
    }

    struct donated {
        address token;
        uint256 amount;
    }

    modifier onlyReceiver() {
        require(receiverAuth[msg.sender] || msg.sender == owner, "only receivers can receive tokens");
        _;
    }

    function withdrawToken(address _token) onlyReceiver public {
        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(msg.sender, IERC20(_token).balanceOf(address(this)));
        tokensWithdrawn[_token] += amount;
    }

    function addReceiver(address _receiver) onlyReceiver public {
        receiverAuth[_receiver] = true;
    }

    function addTokens(address _token) public onlyReceiver {
        knownTokens.push(_token);
    }

    function withdrawKnown() public onlyReceiver{
        address[] memory knownTokens_ = knownTokens;
        uint256 length = knownTokens_.length;
        for(uint i; i < length; i++){
            address token = knownTokens_[i];
            uint256 amount = IERC20(token).balanceOf(address(this));
        if (amount > 0){
            IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
            tokensWithdrawn[token] += amount;
            }
        }
    }

    function getKnownTokensDonated() public view returns (donated[] memory) {
        address[] memory knownTokens_ = knownTokens;
        uint256 length = knownTokens_.length;
        donated[] memory donated_ = new donated[](length); 
        for(uint i; i < length; i++){
            address token = knownTokens_[i];
            uint amount = tokensWithdrawn[token];
            donated_[i] = (donated(token,amount));
        }
        return donated_;
    }

}