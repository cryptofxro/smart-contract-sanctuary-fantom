/**
 *Submitted for verification at FtmScan.com on 2022-02-19
*/

/**
 *Submitted for verification at snowtrace.io on 2021-11-06
*/

/**
 *Submitted for verification at BscScan.com on 2021-08-29
*/

// SPDX-License-Identifier: AGPL-3.0-or-later

// Copyright (C) 2021 Dai Foundation

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// VoteDelegateFactory - create and keep record of delegats
pragma solidity 0.6.12;

contract DSNote {
    event LogNote(
        bytes4   indexed  sig,
        address  indexed  guy,
        bytes32  indexed  foo,
        bytes32  indexed  bar,
        uint256           wad,
        bytes             fax
    ) anonymous;

    modifier note {
        bytes32 foo;
        bytes32 bar;
        uint256 wad;

        assembly {
            foo := calldataload(4)
            bar := calldataload(36)
            wad := callvalue()
        }

        _;

        emit LogNote(msg.sig, msg.sender, foo, bar, wad, msg.data);
    }
}

interface DSAuthority {
    function canCall(
        address src, address dst, bytes4 sig
    ) external view returns (bool);
}

contract DSAuthEvents {
    event LogSetAuthority (address indexed authority);
    event LogSetOwner     (address indexed owner);
}

contract DSAuth is DSAuthEvents {
    DSAuthority  public  authority;
    address      public  owner;

    constructor() public {
        owner = msg.sender;
        emit LogSetOwner(msg.sender);
    }

    function setOwner(address owner_)
        public
        virtual
        auth
    {
        owner = owner_;
        emit LogSetOwner(owner);
    }

    function setAuthority(DSAuthority authority_)
        public
        virtual
        auth
    {
        authority = authority_;
        emit LogSetAuthority(address(authority));
    }

    modifier auth {
        require(isAuthorized(msg.sender, msg.sig), "ds-auth-unauthorized");
        _;
    }

    function isAuthorized(address src, bytes4 sig) internal view returns (bool) {
        if (src == address(this)) {
            return true;
        } else if (src == owner) {
            return true;
        } else if (authority == DSAuthority(address(0))) {
            return false;
        } else {
            return authority.canCall(src, address(this), sig);
        }
    }
}

contract DSMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "ds-math-add-overflow");
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "ds-math-mul-overflow");
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }
    function max(uint x, uint y) internal pure returns (uint z) {
        return x >= y ? x : y;
    }
    function imin(int x, int y) internal pure returns (int z) {
        return x <= y ? x : y;
    }
    function imax(int x, int y) internal pure returns (int z) {
        return x >= y ? x : y;
    }

    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;

    //rounds to zero if x*y < WAD / 2
    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }
    //rounds to zero if x*y < WAD / 2
    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }
    //rounds to zero if x*y < WAD / 2
    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }
    //rounds to zero if x*y < RAY / 2
    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, RAY), y / 2) / y;
    }

    // This famous algorithm is called "exponentiation by squaring"
    // and calculates x^n with x as fixed-point and n as regular unsigned.
    //
    // It's O(log n), instead of O(n) for naive repeated multiplication.
    //
    // These facts are why it works:
    //
    //  If n is even, then x^n = (x^2)^(n/2).
    //  If n is odd,  then x^n = x * x^(n-1),
    //   and applying the equation for even x gives
    //    x^n = x * (x^2)^((n-1) / 2).
    //
    //  Also, EVM division is flooring and
    //    floor[(n-1) / 2] = floor[n / 2].
    //
    function rpow(uint x, uint n) internal pure returns (uint z) {
        z = n % 2 != 0 ? x : RAY;

        for (n /= 2; n != 0; n /= 2) {
            x = rmul(x, x);

            if (n % 2 != 0) {
                z = rmul(z, x);
            }
        }
    }
}

contract DSToken is DSMath, DSAuth {
    bool                                              public  stopped;
    uint256                                           public  totalSupply;
    mapping (address => uint256)                      public  balanceOf;
    mapping (address => mapping (address => uint256)) public  allowance;
    string                                            public  symbol;
    uint8                                             public  decimals = 18; // standard token precision. override to customize
    string                                            public  name = "";     // Optional token name


    constructor(string memory symbol_) public {
        symbol = symbol_;
    }

    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);
    event Mint(address indexed guy, uint wad);
    event Burn(address indexed guy, uint wad);
    event Stop();
    event Start();

    modifier stoppable {
        require(!stopped, "ds-stop-is-stopped");
        _;
    }

    function approve(address guy) external returns (bool) {
        return approve(guy, uint(-1));
    }

    function approve(address guy, uint wad) public stoppable returns (bool) {
        allowance[msg.sender][guy] = wad;

        emit Approval(msg.sender, guy, wad);

        return true;
    }

    function transfer(address dst, uint wad) external returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad)
        public
        stoppable
        returns (bool)
    {
        if (src != msg.sender && allowance[src][msg.sender] != uint(-1)) {
            require(allowance[src][msg.sender] >= wad, "ds-token-insufficient-approval");
            allowance[src][msg.sender] = sub(allowance[src][msg.sender], wad);
        }

        require(balanceOf[src] >= wad, "ds-token-insufficient-balance");
        balanceOf[src] = sub(balanceOf[src], wad);
        balanceOf[dst] = add(balanceOf[dst], wad);

        emit Transfer(src, dst, wad);

        return true;
    }

    /*
    function push(address dst, uint wad) external {
        transferFrom(msg.sender, dst, wad);
    }

    function pull(address src, uint wad) external {
        transferFrom(src, msg.sender, wad);
    }

    function move(address src, address dst, uint wad) external {
        transferFrom(src, dst, wad);
    }
    */


    function mint(uint wad) external {
        mint(msg.sender, wad);
    }

    function burn(uint wad) external {
        burn(msg.sender, wad);
    }

    function mint(address guy, uint wad) public auth stoppable {
        balanceOf[guy] = add(balanceOf[guy], wad);
        totalSupply = add(totalSupply, wad);
        emit Mint(guy, wad);
    }

    function burn(address guy, uint wad) public auth stoppable {
        if (guy != msg.sender && allowance[guy][msg.sender] != uint(-1)) {
            require(allowance[guy][msg.sender] >= wad, "ds-token-insufficient-approval");
            allowance[guy][msg.sender] = sub(allowance[guy][msg.sender], wad);
        }

        require(balanceOf[guy] >= wad, "ds-token-insufficient-balance");
        balanceOf[guy] = sub(balanceOf[guy], wad);
        totalSupply = sub(totalSupply, wad);
        emit Burn(guy, wad);
    }

    function stop() public auth {
        stopped = true;
        emit Stop();
    }

    function start() public auth {
        stopped = false;
        emit Start();
    }


    function setName(string memory name_) public auth {
        name = name_;
    }
}

contract DSThing is DSAuth, DSNote, DSMath {
    function S(string memory s) internal pure returns (bytes4) {
        return bytes4(keccak256(abi.encodePacked(s)));
    }

}

contract DSRoles is DSAuth, DSAuthority
{
    mapping(address=>bool) _root_users;
    mapping(address=>bytes32) _user_roles;
    mapping(address=>mapping(bytes4=>bytes32)) _capability_roles;
    mapping(address=>mapping(bytes4=>bool)) _public_capabilities;

    function getUserRoles(address who)
        public
        view
        returns (bytes32)
    {
        return _user_roles[who];
    }

    function getCapabilityRoles(address code, bytes4 sig)
        public
        view
        returns (bytes32)
    {
        return _capability_roles[code][sig];
    }

    function isUserRoot(address who)
        public
        view virtual
        returns (bool)
    {
        return _root_users[who];
    }

    function isCapabilityPublic(address code, bytes4 sig)
        public
        view
        returns (bool)
    {
        return _public_capabilities[code][sig];
    }

    function hasUserRole(address who, uint8 role)
        public
        view
        returns (bool)
    {
        bytes32 roles = getUserRoles(who);
        bytes32 shifted = bytes32(uint256(uint256(2) ** uint256(role)));
        return bytes32(0) != roles & shifted;
    }

    function canCall(address caller, address code, bytes4 sig)
        public override
        view
        returns (bool)
    {
        if( isUserRoot(caller) || isCapabilityPublic(code, sig) ) {
            return true;
        } else {
            bytes32 has_roles = getUserRoles(caller);
            bytes32 needs_one_of = getCapabilityRoles(code, sig);
            return bytes32(0) != has_roles & needs_one_of;
        }
    }

    function BITNOT(bytes32 input) internal pure returns (bytes32 output) {
        return (input ^ bytes32(uint(-1)));
    }

    function setRootUser(address who, bool enabled)
        public virtual
        auth
    {
        _root_users[who] = enabled;
    }

    function setUserRole(address who, uint8 role, bool enabled)
        public
        auth
    {
        bytes32 last_roles = _user_roles[who];
        bytes32 shifted = bytes32(uint256(uint256(2) ** uint256(role)));
        if( enabled ) {
            _user_roles[who] = last_roles | shifted;
        } else {
            _user_roles[who] = last_roles & BITNOT(shifted);
        }
    }

    function setPublicCapability(address code, bytes4 sig, bool enabled)
        public
        auth
    {
        _public_capabilities[code][sig] = enabled;
    }

    function setRoleCapability(uint8 role, address code, bytes4 sig, bool enabled)
        public
        auth
    {
        bytes32 last_roles = _capability_roles[code][sig];
        bytes32 shifted = bytes32(uint256(uint256(2) ** uint256(role)));
        if( enabled ) {
            _capability_roles[code][sig] = last_roles | shifted;
        } else {
            _capability_roles[code][sig] = last_roles & BITNOT(shifted);
        }

    }

}

// The right way to use this contract is probably to mix it with some kind
// of `DSAuthority`, like with `ds-roles`.
//   SEE DSChief
contract DSChiefApprovals is DSThing {
    mapping(bytes32=>address[]) public slates;
    mapping(address=>bytes32) public votes;
    mapping(address=>uint256) public approvals;
    mapping(address=>uint256) public deposits;
    DSToken public GOV; // voting token that gets locked up
    DSToken public IOU; // non-voting representation of a token, for e.g. secondary voting mechanisms
    address public hat; // the chieftain's hat

    uint256 public MAX_YAYS;

    mapping(address=>uint256) public last;

    bool public live;

    uint256 constant LAUNCH_THRESHOLD = 50_000 * 10 ** 18; // 50K GRO launch threshold

    event Etch(bytes32 indexed slate);

    // IOU constructed outside this contract reduces deployment costs significantly
    // lock/free/vote are quite sensitive to token invariants. Caution is advised.
    constructor(DSToken GOV_, DSToken IOU_, uint MAX_YAYS_) public
    {
        GOV = GOV_;
        IOU = IOU_;
        MAX_YAYS = MAX_YAYS_;
    }

    function launch()
        public
        note
    {
        require(!live);
        require(hat == address(0) && approvals[address(0)] >= LAUNCH_THRESHOLD);
        live = true;
    }

    function lock(uint wad)
        public
        note
    {
        last[msg.sender] = block.number;
        GOV.transferFrom(msg.sender, address(this), wad);
        IOU.mint(msg.sender, wad);
        deposits[msg.sender] = add(deposits[msg.sender], wad);
        addWeight(wad, votes[msg.sender]);
    }

    function free(uint wad)
        public
        note
    {
        require(block.number > last[msg.sender]);
        deposits[msg.sender] = sub(deposits[msg.sender], wad);
        subWeight(wad, votes[msg.sender]);
        IOU.burn(msg.sender, wad);
        GOV.transfer(msg.sender, wad);
    }

    function etch(address[] memory yays)
        public
        note
        returns (bytes32 slate)
    {
        require( yays.length <= MAX_YAYS );
        requireByteOrderedSet(yays);

        bytes32 hash = keccak256(abi.encodePacked(yays));
        slates[hash] = yays;
        emit Etch(hash);
        return hash;
    }

    function vote(address[] memory yays) public returns (bytes32)
        // note  both sub-calls note
    {
        bytes32 slate = etch(yays);
        vote(slate);
        return slate;
    }

    function vote(bytes32 slate)
        public
        note
    {
        require(slates[slate].length > 0 ||
            slate == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470, "ds-chief-invalid-slate");
        uint weight = deposits[msg.sender];
        subWeight(weight, votes[msg.sender]);
        votes[msg.sender] = slate;
        addWeight(weight, votes[msg.sender]);
    }

    // like `drop`/`swap` except simply "elect this address if it is higher than current hat"
    function lift(address whom)
        public
        note
    {
        require(approvals[whom] > approvals[hat]);
        hat = whom;
    }

    function addWeight(uint weight, bytes32 slate)
        internal
    {
        address[] storage yays = slates[slate];
        for( uint i = 0; i < yays.length; i++) {
            approvals[yays[i]] = add(approvals[yays[i]], weight);
        }
    }

    function subWeight(uint weight, bytes32 slate)
        internal
    {
        address[] storage yays = slates[slate];
        for( uint i = 0; i < yays.length; i++) {
            approvals[yays[i]] = sub(approvals[yays[i]], weight);
        }
    }

    // Throws unless the array of addresses is a ordered set.
    function requireByteOrderedSet(address[] memory yays)
        internal
        pure
    {
        if( yays.length == 0 || yays.length == 1 ) {
            return;
        }
        for( uint i = 0; i < yays.length - 1; i++ ) {
            // strict inequality ensures both ordering and uniqueness
            require(uint(yays[i]) < uint(yays[i+1]));
        }
    }
}


// `hat` address is unique root user (has every role) and the
// unique owner of role 0 (typically 'sys' or 'internal')
contract DSChief is DSRoles, DSChiefApprovals {

    constructor(DSToken GOV, DSToken IOU, uint MAX_YAYS)
             DSChiefApprovals (GOV, IOU, MAX_YAYS)
        public
    {
        authority = this;
        owner = address(0);
    }

    function setOwner(address owner_) public override {
        owner_;
        revert();
    }

    function setAuthority(DSAuthority authority_) public override {
        authority_;
        revert();
    }

    function isUserRoot(address who)
        public view override
        returns (bool)
    {
        return (live && who == hat);
    }
    function setRootUser(address who, bool enabled) public override {
        who; enabled;
        revert();
    }
}

contract DSChiefFab {
    function newChief(DSToken gov, uint MAX_YAYS) public returns (DSChief chief) {
        DSToken iou = new DSToken('IOU');
        chief = new DSChief(gov, iou, MAX_YAYS);
        iou.setOwner(address(chief));
    }
}

contract PollingEvents {
    event PollCreated(
        address indexed creator,
        uint256 blockCreated,
        uint256 indexed pollId,
        uint256 startDate,
        uint256 endDate,
        string multiHash,
        string url
    );

    event PollWithdrawn(
        address indexed creator,
        uint256 blockWithdrawn,
        uint256 pollId
    );

    event Voted(
        address indexed voter,
        uint256 indexed pollId,
        uint256 indexed optionId
    );
}

contract PollingEmitter is PollingEvents {
    uint256 public npoll;

    function createPoll(uint256 startDate, uint256 endDate, string calldata multiHash, string calldata url)
        external
    {
        uint256 startDate_ = startDate > now ? startDate : now;
        require(endDate > startDate_, "polling-invalid-poll-window");
        emit PollCreated(
            msg.sender,
            block.number,
            npoll,
            startDate_,
            endDate,
            multiHash,
            url
        );
        require(npoll < uint(-1), "polling-too-many-polls");
        npoll++;
    }

    function withdrawPoll(uint256 pollId)
        external
    {
        emit PollWithdrawn(msg.sender, block.number, pollId);
    }

    function vote(uint256 pollId, uint256 optionId)
        external
    {
        emit Voted(msg.sender, pollId, optionId);
    }

    function withdrawPoll(uint256[] calldata pollIds)
        external
    {
        for (uint i = 0; i < pollIds.length; i++) {
            emit PollWithdrawn(msg.sender, pollIds[i], block.number);
        }
    }

    function vote(uint256[] calldata pollIds, uint256[] calldata optionIds)
        external
    {
        require(pollIds.length == optionIds.length, "non-matching-length");
        for (uint i = 0; i < pollIds.length; i++) {
            emit Voted(msg.sender, pollIds[i], optionIds[i]);
        }
    }
}

contract VoteDelegate {
    mapping(address => uint256) public stake;
    address     public immutable delegate;
    DSToken     public immutable gov;
    DSToken     public immutable iou;
    DSChief     public immutable chief;
    PollingEmitter public immutable polling;
    uint256     public immutable expiration;

    event Lock(address indexed usr, uint256 wad);
    event Free(address indexed usr, uint256 wad);

    constructor(address _chief, address _polling, address _delegate) public {
        chief = DSChief(_chief);
        polling = PollingEmitter(_polling);
        delegate = _delegate;
        expiration = block.timestamp + 365 days;

        DSToken _gov = gov = DSChief(_chief).GOV();
        DSToken _iou = iou = DSChief(_chief).IOU();

        _gov.approve(_chief, type(uint256).max);
        _iou.approve(_chief, type(uint256).max);
    }

    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "VoteDelegate/add-overflow");
    }

    modifier delegate_auth() {
        require(msg.sender == delegate, "VoteDelegate/sender-not-delegate");
        _;
    }

    modifier live() {
        require(block.timestamp < expiration, "VoteDelegate/delegation-contract-expired");
        _;
    }

    function lock(uint256 wad) external live {
        stake[msg.sender] = add(stake[msg.sender], wad);
        gov.transferFrom(msg.sender, address(this), wad);
        chief.lock(wad);
        iou.transfer(msg.sender, wad);

        emit Lock(msg.sender, wad);
    }

    function free(uint256 wad) external {
        require(stake[msg.sender] >= wad, "VoteDelegate/insufficient-stake");

        stake[msg.sender] -= wad;
        iou.transferFrom(msg.sender, address(this), wad);
        chief.free(wad);
        gov.transfer(msg.sender, wad);

        emit Free(msg.sender, wad);
    }

    function vote(address[] memory yays) external delegate_auth live returns (bytes32 result) {
        result = chief.vote(yays);
    }

    function vote(bytes32 slate) external delegate_auth live {
        chief.vote(slate);
    }

    // Polling vote
    function votePoll(uint256 pollId, uint256 optionId) external delegate_auth live {
        polling.vote(pollId, optionId);
    }

    function votePoll(uint256[] calldata pollIds, uint256[] calldata optionIds) external delegate_auth live {
        polling.vote(pollIds, optionIds);
    }
}

contract VoteDelegateFactory {
    address public immutable chief;
    address public immutable polling;
    mapping(address => address) public delegates;

    event CreateVoteDelegate(
        address indexed delegate,
        address indexed voteDelegate
    );

    constructor(address _chief, address _polling) public {
        chief = _chief;
        polling = _polling;
    }

    function isDelegate(address guy) public view returns (bool) {
        return delegates[guy] != address(0);
    }

    function create() external returns (address voteDelegate) {
        require(!isDelegate(msg.sender), "VoteDelegateFactory/sender-is-already-delegate");

        voteDelegate = address(new VoteDelegate(chief, polling, msg.sender));
        delegates[msg.sender] = voteDelegate;
        emit CreateVoteDelegate(msg.sender, voteDelegate);
    }
}