/**
 *Submitted for verification at FtmScan.com on 2022-08-10
*/

// SPDX-License-Identifier: GPL-3.0

// File: @chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol


pragma solidity ^0.8.4;

/** ****************************************************************************
 * @notice Interface for contracts using VRF randomness
 * *****************************************************************************
 * @dev PURPOSE
 *
 * @dev Reggie the Random Oracle (not his real job) wants to provide randomness
 * @dev to Vera the verifier in such a way that Vera can be sure he's not
 * @dev making his output up to suit himself. Reggie provides Vera a public key
 * @dev to which he knows the secret key. Each time Vera provides a seed to
 * @dev Reggie, he gives back a value which is computed completely
 * @dev deterministically from the seed and the secret key.
 *
 * @dev Reggie provides a proof by which Vera can verify that the output was
 * @dev correctly computed once Reggie tells it to her, but without that proof,
 * @dev the output is indistinguishable to her from a uniform random sample
 * @dev from the output space.
 *
 * @dev The purpose of this contract is to make it easy for unrelated contracts
 * @dev to talk to Vera the verifier about the work Reggie is doing, to provide
 * @dev simple access to a verifiable source of randomness. It ensures 2 things:
 * @dev 1. The fulfillment came from the VRFCoordinator
 * @dev 2. The consumer contract implements fulfillRandomWords.
 * *****************************************************************************
 * @dev USAGE
 *
 * @dev Calling contracts must inherit from VRFConsumerBase, and can
 * @dev initialize VRFConsumerBase's attributes in their constructor as
 * @dev shown:
 *
 * @dev   contract VRFConsumer {
 * @dev     constructor(<other arguments>, address _vrfCoordinator, address _link)
 * @dev       VRFConsumerBase(_vrfCoordinator) public {
 * @dev         <initialization with other arguments goes here>
 * @dev       }
 * @dev   }
 *
 * @dev The oracle will have given you an ID for the VRF keypair they have
 * @dev committed to (let's call it keyHash). Create subscription, fund it
 * @dev and your consumer contract as a consumer of it (see VRFCoordinatorInterface
 * @dev subscription management functions).
 * @dev Call requestRandomWords(keyHash, subId, minimumRequestConfirmations,
 * @dev callbackGasLimit, numWords),
 * @dev see (VRFCoordinatorInterface for a description of the arguments).
 *
 * @dev Once the VRFCoordinator has received and validated the oracle's response
 * @dev to your request, it will call your contract's fulfillRandomWords method.
 *
 * @dev The randomness argument to fulfillRandomWords is a set of random words
 * @dev generated from your requestId and the blockHash of the request.
 *
 * @dev If your contract could have concurrent requests open, you can use the
 * @dev requestId returned from requestRandomWords to track which response is associated
 * @dev with which randomness request.
 * @dev See "SECURITY CONSIDERATIONS" for principles to keep in mind,
 * @dev if your contract could have multiple requests in flight simultaneously.
 *
 * @dev Colliding `requestId`s are cryptographically impossible as long as seeds
 * @dev differ.
 *
 * *****************************************************************************
 * @dev SECURITY CONSIDERATIONS
 *
 * @dev A method with the ability to call your fulfillRandomness method directly
 * @dev could spoof a VRF response with any random value, so it's critical that
 * @dev it cannot be directly called by anything other than this base contract
 * @dev (specifically, by the VRFConsumerBase.rawFulfillRandomness method).
 *
 * @dev For your users to trust that your contract's random behavior is free
 * @dev from malicious interference, it's best if you can write it so that all
 * @dev behaviors implied by a VRF response are executed *during* your
 * @dev fulfillRandomness method. If your contract must store the response (or
 * @dev anything derived from it) and use it later, you must ensure that any
 * @dev user-significant behavior which depends on that stored value cannot be
 * @dev manipulated by a subsequent VRF request.
 *
 * @dev Similarly, both miners and the VRF oracle itself have some influence
 * @dev over the order in which VRF responses appear on the blockchain, so if
 * @dev your contract could have multiple VRF requests in flight simultaneously,
 * @dev you must ensure that the order in which the VRF responses arrive cannot
 * @dev be used to manipulate your contract's user-significant behavior.
 *
 * @dev Since the block hash of the block which contains the requestRandomness
 * @dev call is mixed into the input to the VRF *last*, a sufficiently powerful
 * @dev miner could, in principle, fork the blockchain to evict the block
 * @dev containing the request, forcing the request to be included in a
 * @dev different block with a different hash, and therefore a different input
 * @dev to the VRF. However, such an attack would incur a substantial economic
 * @dev cost. This cost scales with the number of blocks the VRF oracle waits
 * @dev until it calls responds to a request. It is for this reason that
 * @dev that you can signal to an oracle you'd like them to wait longer before
 * @dev responding to the request (however this is not enforced in the contract
 * @dev and so remains effective only in the case of unmodified oracle software).
 */
abstract contract VRFConsumerBaseV2 {
  error OnlyCoordinatorCanFulfill(address have, address want);
  address private immutable vrfCoordinator;

  /**
   * @param _vrfCoordinator address of VRFCoordinator contract
   */
  constructor(address _vrfCoordinator) {
    vrfCoordinator = _vrfCoordinator;
  }

  /**
   * @notice fulfillRandomness handles the VRF response. Your contract must
   * @notice implement it. See "SECURITY CONSIDERATIONS" above for important
   * @notice principles to keep in mind when implementing your fulfillRandomness
   * @notice method.
   *
   * @dev VRFConsumerBaseV2 expects its subcontracts to have a method with this
   * @dev signature, and will call it once it has verified the proof
   * @dev associated with the randomness. (It is triggered via a call to
   * @dev rawFulfillRandomness, below.)
   *
   * @param requestId The Id initially returned by requestRandomness
   * @param randomWords the VRF output expanded to the requested number of words
   */
  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual;

  // rawFulfillRandomness is called by VRFCoordinator when it receives a valid VRF
  // proof. rawFulfillRandomness then calls fulfillRandomness, after validating
  // the origin of the call
  function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
    if (msg.sender != vrfCoordinator) {
      revert OnlyCoordinatorCanFulfill(msg.sender, vrfCoordinator);
    }
    fulfillRandomWords(requestId, randomWords);
  }
}

// File: @chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol


pragma solidity ^0.8.0;

interface VRFCoordinatorV2Interface {
  /**
   * @notice Get configuration relevant for making requests
   * @return minimumRequestConfirmations global min for request confirmations
   * @return maxGasLimit global max for request gas limit
   * @return s_provingKeyHashes list of registered key hashes
   */
  function getRequestConfig()
    external
    view
    returns (
      uint16,
      uint32,
      bytes32[] memory
    );

  /**
   * @notice Request a set of random words.
   * @param keyHash - Corresponds to a particular oracle job which uses
   * that key for generating the VRF proof. Different keyHash's have different gas price
   * ceilings, so you can select a specific one to bound your maximum per request cost.
   * @param subId  - The ID of the VRF subscription. Must be funded
   * with the minimum subscription balance required for the selected keyHash.
   * @param minimumRequestConfirmations - How many blocks you'd like the
   * oracle to wait before responding to the request. See SECURITY CONSIDERATIONS
   * for why you may want to request more. The acceptable range is
   * [minimumRequestBlockConfirmations, 200].
   * @param callbackGasLimit - How much gas you'd like to receive in your
   * fulfillRandomWords callback. Note that gasleft() inside fulfillRandomWords
   * may be slightly less than this amount because of gas used calling the function
   * (argument decoding etc.), so you may need to request slightly more than you expect
   * to have inside fulfillRandomWords. The acceptable range is
   * [0, maxGasLimit]
   * @param numWords - The number of uint256 random values you'd like to receive
   * in your fulfillRandomWords callback. Note these numbers are expanded in a
   * secure way by the VRFCoordinator from a single random value supplied by the oracle.
   * @return requestId - A unique identifier of the request. Can be used to match
   * a request to a response in fulfillRandomWords.
   */
  function requestRandomWords(
    bytes32 keyHash,
    uint64 subId,
    uint16 minimumRequestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
  ) external returns (uint256 requestId);

  /**
   * @notice Create a VRF subscription.
   * @return subId - A unique subscription id.
   * @dev You can manage the consumer set dynamically with addConsumer/removeConsumer.
   * @dev Note to fund the subscription, use transferAndCall. For example
   * @dev  LINKTOKEN.transferAndCall(
   * @dev    address(COORDINATOR),
   * @dev    amount,
   * @dev    abi.encode(subId));
   */
  function createSubscription() external returns (uint64 subId);

  /**
   * @notice Get a VRF subscription.
   * @param subId - ID of the subscription
   * @return balance - LINK balance of the subscription in juels.
   * @return reqCount - number of requests for this subscription, determines fee tier.
   * @return owner - owner of the subscription.
   * @return consumers - list of consumer address which are able to use this subscription.
   */
  function getSubscription(uint64 subId)
    external
    view
    returns (
      uint96 balance,
      uint64 reqCount,
      address owner,
      address[] memory consumers
    );

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @param newOwner - proposed new owner of the subscription
   */
  function requestSubscriptionOwnerTransfer(uint64 subId, address newOwner) external;

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @dev will revert if original owner of subId has
   * not requested that msg.sender become the new owner.
   */
  function acceptSubscriptionOwnerTransfer(uint64 subId) external;

  /**
   * @notice Add a consumer to a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - New consumer which can use the subscription
   */
  function addConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Remove a consumer from a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - Consumer to remove from the subscription
   */
  function removeConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Cancel a subscription
   * @param subId - ID of the subscription
   * @param to - Where to send the remaining LINK to
   */
  function cancelSubscription(uint64 subId, address to) external;
}

// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: contracts/GameWithVRF_RandomResults.sol



pragma solidity ^0.8.7;





interface NFT {
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract StonkGame is Ownable, VRFConsumerBaseV2 {

    struct Stonk {
        address player;
        uint256 tokenId;
        string rarity;
        uint256 invPowerLvl;
    }

    struct Results {
        address player1;
        uint player1ListingId;
        address player2;
        uint player2ListingId;
        address winner;
        address loser;
        uint256 matchResultTime;
        string comparisionType;
    }
    VRFCoordinatorV2Interface COORDINATOR;

    uint64 s_subscriptionId;

    address vrfCoordinator = address(0xd5D517aBE5cF79B7e95eC98dB0f0277788aFF634); //address(0xbd13f08b8352A3635218ab9418E340c60d6Eb418);

    bytes32 keyHash = 0x64ae04e5dba58bc08ba2d53eb33fe95bf71f5002789692fe78fb3778f16121c9;//0x121a143066e0f2f08b620784af77cccb35c6242460b4a8ee251b4b416abaebd4;

    uint32 callbackGasLimit = 2000000; //100000;

    uint16 requestConfirmations = 3;

    uint32 numRandom =  1;

    uint256[] public s_randomWords;

    address s_owner;

    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
    }

    mapping(uint256 => Results) public resultHistory;

    mapping(uint256 => Stonk) public stonkGameQueue;

    mapping(uint256 => bool) public tokenTracker;

    mapping(uint => uint256) public requestMapping;

    //mapping(address => bool) public walletTracker;

    address stonkNft = address(0x2f604079aFf2A11883736d189eF823e39abd6316);

    address stonkCommunityWallet = address(0x35128c4263aA0213c59A897Fd31d8C837E8B71C8);

    address stonkDevWallet = address(0x9D6c09Dba41f796B9163343f8B595380EcCD4E78);

    string[10] private compareArray = ["greater", "lesser", "greater", "lesser", "greater", "lesser", "greater", "lesser", "lesser", "greater"];

    uint256 public totalListings = 0;

    uint256 public matches = 0;

    uint256 public queueLength = 0;

    uint256 cost = 100000000000000000;

    uint private lastRandom;

    //uint256[6][] private queuePossibilities = [[1,2], [1,3], [1,4], [2,3], [2,4], [3,4]];

    


    function pseudoRandomNum(uint256 _mod, uint256 _seed, uint _salt) public view returns(uint256) {
      uint256 num = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, _seed, _salt))) % _mod;
      return num;
    }

    function getRandomNumberRequestId() internal returns (uint s_requestId) {
        s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numRandom
        );

        return s_requestId;
    }
  
    function fulfillRandomWords(uint requestId, uint[] memory randomWords) internal override {
        uint randomWord = randomWords[0];
        lastRandom = randomWords[0];
        uint randomNum;

        if(stonkGameQueue[requestMapping[requestId]].invPowerLvl >= 22) {
            randomNum = randomWord % 12;
        } else if((stonkGameQueue[requestMapping[requestId]].invPowerLvl < 22) && (stonkGameQueue[requestMapping[requestId]].invPowerLvl >= 19)) {
            randomNum = randomWord % 10;
        } else if((stonkGameQueue[requestMapping[requestId]].invPowerLvl < 19) && (stonkGameQueue[requestMapping[requestId]].invPowerLvl >= 15)) {
            randomNum = randomWord % 7;
        } else if((stonkGameQueue[requestMapping[requestId]].invPowerLvl < 15) && (stonkGameQueue[requestMapping[requestId]].invPowerLvl >= 7)) {
            randomNum = randomWord % 3;
        }

        stonkGameQueue[requestMapping[requestId]].invPowerLvl -= randomNum;

        
    }

    function getMatches() internal view returns (uint8[4] memory matchUps) {
        uint modulo = lastRandom % 6;
        if(modulo==0 || modulo==5) {
            matchUps = [1,2,3,4];
        } else if(modulo==1 || modulo==4) {
            matchUps = [1,3,2,4];
        } else if(modulo==2 || modulo==3) {
            matchUps = [1,4,2,3];
        }

        return matchUps;

    }

    function addToQueue(uint256 _tokenId, string memory _rarity, uint256 _invPowerLvl) public payable {
        require(msg.value >= cost);
        //require(NFT(stonkNft).ownerOf(_tokenId) == msg.sender, "You don't own the token");
        require(!tokenTracker[_tokenId], "Token already listed");
        //require(!walletTracker[msg.sender], "You have already listed one token for this cycle!");
        //require(queue <= 300, "Max cap reached");


        uint s_requestId = getRandomNumberRequestId();
        requestMapping[s_requestId] = totalListings;

        if(queueLength!= 0 && queueLength%6 == 0) {
            uint8[4] memory matchUps = getMatches();
            uint matchCountAtPoint = matches;
            for(uint i=0; i<=2; i+=2){
                if(keccak256(bytes(compareArray[lastRandom%10])) == keccak256(bytes("greater"))) {
                    computeResultsGreaterThan(matchCountAtPoint, matchUps[i], matchUps[i+1]);
                } else {
                    computeResultsLesserThan(matchCountAtPoint, matchUps[i], matchUps[i+1]);
                }
            }
            
            //computeResults();
            //queueLength = 1;
        }

                
        stonkGameQueue[totalListings] = Stonk(msg.sender, _tokenId, _rarity, _invPowerLvl);

        totalListings += 1;
        queueLength += 1;

        tokenTracker[_tokenId] = true;

    }

    function computeResultsLesserThan(uint matchCountAtPoint, uint pq1, uint pq2) internal {
        uint p1 = (matchCountAtPoint)*2 + pq1 - 1;
        uint p2 = (matchCountAtPoint)*2 + pq2 - 1;
        uint256 stonk1PowLvl = stonkGameQueue[p1].invPowerLvl;
        uint256 stonk2PowLvl = stonkGameQueue[p2].invPowerLvl;
        uint256 amount = cost*2;

        //uint num = randomNum(361, block.difficulty, 100);

        resultHistory[matches].player1 = stonkGameQueue[p1].player;
        resultHistory[matches].player2 = stonkGameQueue[p2].player;
        resultHistory[matches].matchResultTime = block.timestamp;
        resultHistory[matches].comparisionType = "Lesser Inverse Power Won!";
        resultHistory[matches].player1ListingId = p1;
        resultHistory[matches].player2ListingId = p2;

        if(stonk1PowLvl < stonk2PowLvl) {
            resultHistory[matches].winner = stonkGameQueue[p1].player;
            resultHistory[matches].loser = stonkGameQueue[p2].player;

            if(keccak256(bytes(stonkGameQueue[p1].rarity)) == keccak256(bytes("Legendary"))) {
                payable(stonkGameQueue[p1].player).transfer(amount);
            } else {
                payable(stonkCommunityWallet).transfer(amount*10/100);
                payable(stonkDevWallet).transfer(amount*10/100);
                payable(stonkGameQueue[p1].player).transfer(amount*80/100);
            }
            
        } else if(stonk1PowLvl > stonk2PowLvl) {
            resultHistory[matches].winner = stonkGameQueue[p2].player;
            resultHistory[matches].loser = stonkGameQueue[p1].player;
            if(keccak256(bytes(stonkGameQueue[p2].rarity)) == keccak256(bytes("Legendary"))) {
                payable(stonkGameQueue[p2].player).transfer(amount);
            } else {
                payable(stonkCommunityWallet).transfer(amount*10/100);
                payable(stonkDevWallet).transfer(amount*10/100);
                payable(stonkGameQueue[p2].player).transfer(amount*80/100);
            }
        } else {
            resultHistory[matches].winner = address(0);
            resultHistory[matches].loser = address(0);

            payable(stonkGameQueue[p1].player).transfer(amount*40/100);
            payable(stonkGameQueue[p2].player).transfer(amount*40/100);
        }

        tokenTracker[stonkGameQueue[p1].tokenId] = false;
        tokenTracker[stonkGameQueue[p2].tokenId] = false;
        matches += 1;
    }

    function computeResultsGreaterThan(uint matchCountAtPoint, uint8 pq1, uint8 pq2) internal {
        uint p1 = (matchCountAtPoint)*2 + pq1 - 1;
        uint p2 = (matchCountAtPoint)*2 + pq2 - 1;
        uint256 stonk1PowLvl = stonkGameQueue[p1].invPowerLvl;
        uint256 stonk2PowLvl = stonkGameQueue[p2].invPowerLvl;
        uint256 amount = cost*2;

        //uint num = randomNum(361, block.difficulty, 100);

        resultHistory[matches].player1 = stonkGameQueue[p1].player;
        resultHistory[matches].player2 = stonkGameQueue[p2].player;
        resultHistory[matches].matchResultTime = block.timestamp;
        resultHistory[matches].comparisionType = "Greater Inverse Power Won!";

        

        if(stonk1PowLvl < stonk2PowLvl) {
            resultHistory[matches].winner = stonkGameQueue[p2].player;
            resultHistory[matches].loser = stonkGameQueue[p1].player;

            if(keccak256(bytes(stonkGameQueue[p2].rarity)) == keccak256(bytes("Legendary"))) {
                payable(stonkGameQueue[p2].player).transfer(amount);
            } else {
                payable(stonkCommunityWallet).transfer(amount*10/100);
                payable(stonkDevWallet).transfer(amount*10/100);
                payable(stonkGameQueue[p2].player).transfer(amount*80/100);
            }
            
        } else if(stonk1PowLvl > stonk2PowLvl) {
            resultHistory[matches].winner = stonkGameQueue[p1].player;
            resultHistory[matches].loser = stonkGameQueue[p2].player;
            if(keccak256(bytes(stonkGameQueue[p1].rarity)) == keccak256(bytes("Legendary"))) {
                payable(stonkGameQueue[p1].player).transfer(amount);
            } else {
                payable(stonkCommunityWallet).transfer(amount*10/100);
                payable(stonkDevWallet).transfer(amount*10/100);
                payable(stonkGameQueue[p1].player).transfer(amount*80/100);
            }
        } else {
            resultHistory[matches].winner = address(0);
            resultHistory[matches].loser = address(0);

            payable(stonkGameQueue[p1].player).transfer(amount*40/100);
            payable(stonkGameQueue[p2].player).transfer(amount*40/100);
        }

        tokenTracker[stonkGameQueue[p1].tokenId] = false;
        tokenTracker[stonkGameQueue[p2].tokenId] = false;
        matches += 1;
    }


    function getLastTenResults(address _player) public view returns (Results[] memory) {
        Results[] memory results = new Results[](10);

        //uint256 resultsPerAddress = 0;
        for(uint256 i = totalListings; i >= 0; i-= 1) {
            if(resultHistory[i].player1 == _player || resultHistory[i].player2 == _player) {
                Results storage acceptedResult = resultHistory[i];
                results[i] = acceptedResult;
            }
        }

        return results;
    }

    function setCost(uint256 _cost) public onlyOwner {
        cost = _cost;
    }

    function setCommunityWallet(address _wallet) public onlyOwner {
        stonkCommunityWallet = _wallet;
    }

    function setDevWallet(address _wallet) public onlyOwner {
        stonkDevWallet = _wallet;
    }
}