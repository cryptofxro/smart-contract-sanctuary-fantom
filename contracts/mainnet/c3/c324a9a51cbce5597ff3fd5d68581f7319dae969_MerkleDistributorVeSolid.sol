/**
 *Submitted for verification at FtmScan.com on 2023-04-22
*/

/**
 *Submitted for verification at Etherscan.io on 2022-12-31
*/

/**
 *Submitted for verification at Arbiscan on 2022-11-29
*/

// File: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.1.0/contracts/cryptography/MerkleProof.sol



pragma solidity ^0.6.0;

/**
 * @dev These functions deal with verification of Merkle trees (hash trees),
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}

// File: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.1.0/contracts/token/ERC20/IERC20.sol



pragma solidity ^0.6.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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
}

// File: contracts/MerkleVeSolid.sol


pragma solidity =0.6.11;



// Allows anyone to claim a token if they exist in a merkle root.
interface IMerkleDistributor {
    // Returns the address of the token distributed by this contract.
    function token() external view returns (address);

    // Returns the merkle root of the merkle tree containing account balances available to claim.
    function merkleRoot() external view returns (bytes32);

    // Returns true if the index has been marked claimed.
    function isClaimed(uint256 index) external view returns (bool);

    // Claim the given amount of the token to the given address. Reverts if the inputs are invalid.
    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external;

    // Claim the given amount of the token to the given address. Reverts if the inputs are invalid.
    function claimFor(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof,
        address recipient
    ) external;

    // This event is triggered whenever a call to #claim succeeds.
    event Claimed(uint256 index, address account, uint256 tokenId, uint256 amount);
}


interface IVe {
    function split(uint256 tokenId, uint256 sendAmount)
        external
        returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function increase_unlock_time(
        uint256 tokenId,
        uint256 lockDuration
    ) external;
}

contract MerkleDistributorVeSolid is IMerkleDistributor {
    address public immutable override token;
    bytes32 public immutable override merkleRoot;
    uint256 public immutable rootTokenId;
    uint256 private constant MAX_LOCK = 4 * 52 * 1 weeks;

    // This is a packed array of booleans.
    mapping(uint256 => uint256) private claimedBitMap;
    address public governance;

    constructor(
        address token_,
        bytes32 merkleRoot_,
        uint256 rootTokenId_
    ) public {
        token = token_;
        merkleRoot = merkleRoot_;
        governance = msg.sender;
        rootTokenId = rootTokenId_;
    }

    function isClaimed(uint256 index) public view override returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] =
            claimedBitMap[claimedWordIndex] |
            (1 << claimedBitIndex);
    }

    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external override {
        require(!isClaimed(index), "MerkleDistributor: Drop already claimed.");
        require(msg.sender == account, "!account");
        
        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "MerkleDistributor: Invalid proof."
        );

        // Mark it claimed and send the token.
        _setClaimed(index);

        // Split NFT
        uint256 tokenId = IVe(token).split(rootTokenId, amount);

        // Transfer NFT (intentionally use transferFrom instead of safeTransferFrom)
        IVe(token).transferFrom(address(this), account, tokenId);

        emit Claimed(index, account, tokenId, amount);
    }

    function claimFor(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof,
        address recipient
    ) external override {
        require(msg.sender == governance, "!governance");
        require(!isClaimed(index), "MerkleDistributor: Drop already claimed.");

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "MerkleDistributor: Invalid proof."
        );

        // Mark it claimed and send the token.
        _setClaimed(index);

        // Split NFT
        uint256 tokenId = IVe(token).split(rootTokenId, amount);

        // Transfer NFT (intentionally use transferFrom instead of safeTransferFrom)
        IVe(token).transferFrom(address(this), recipient, tokenId);

        emit Claimed(index, account, tokenId, amount);
    }

    function transferGovernance(address governance_) external {
        require(msg.sender == governance, "!governance");
        governance = governance_;
    }

    function collectDust(address _token, uint256 _amount) external {
        require(msg.sender == governance, "!governance");
        require(_token != token, "!token");
        if (_token == address(0)) {
            // token address(0) = ETH
            payable(governance).transfer(_amount);
        } else {
            IERC20(_token).transfer(governance, _amount);
        }
    }

    function recoverNft() external {
        require(msg.sender == governance, "!governance");
        IVe(token).transferFrom(address(this), governance, rootTokenId);
    }

    function maxLockNft() public {
        require(msg.sender == governance, "!governance");
        IVe(token).increase_unlock_time(rootTokenId, MAX_LOCK);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return this.onERC721Received.selector;
    }
}