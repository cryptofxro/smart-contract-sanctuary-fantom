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

/// DssDeployPauseProxyActions.sol

// Copyright (C) 2019-2020 Maker Ecosystem Growth Holdings, INC.

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

pragma solidity >=0.5.12;

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

contract DSPause is DSAuth, DSNote {

    // --- admin ---

    modifier wait { require(msg.sender == address(proxy), "ds-pause-undelayed-call"); _; }

    function setOwner(address owner_) public override wait {
        owner = owner_;
        emit LogSetOwner(owner);
    }
    function setAuthority(DSAuthority authority_) public override wait {
        authority = authority_;
        emit LogSetAuthority(address(authority));
    }
    function setDelay(uint delay_) public note wait {
        delay = delay_;
    }

    // --- math ---

    function _add(uint x, uint y) internal pure returns (uint z) {
        z = x + y;
        require(z >= x, "ds-pause-addition-overflow");
    }

    // --- data ---

    mapping (bytes32 => bool) public plans;
    DSPauseProxy public proxy;
    uint         public delay;

    // --- init ---

    constructor(uint delay_, address owner_, DSAuthority authority_) public {
        delay = delay_;
        owner = owner_;
        authority = authority_;
        proxy = new DSPauseProxy();
    }

    // --- util ---

    function hash(address usr, bytes32 tag, bytes memory fax, uint eta)
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encode(usr, tag, fax, eta));
    }

    function soul(address usr)
        internal view
        returns (bytes32 tag)
    {
        assembly { tag := extcodehash(usr) }
    }

    // --- operations ---

    function plot(address usr, bytes32 tag, bytes memory fax, uint eta)
        public note auth
    {
        require(eta >= _add(now, delay), "ds-pause-delay-not-respected");
        plans[hash(usr, tag, fax, eta)] = true;
    }

    function drop(address usr, bytes32 tag, bytes memory fax, uint eta)
        public note auth
    {
        plans[hash(usr, tag, fax, eta)] = false;
    }

    function exec(address usr, bytes32 tag, bytes memory fax, uint eta)
        public note
        returns (bytes memory out)
    {
        require(plans[hash(usr, tag, fax, eta)], "ds-pause-unplotted-plan");
        require(soul(usr) == tag,                "ds-pause-wrong-codehash");
        require(now >= eta,                      "ds-pause-premature-exec");

        plans[hash(usr, tag, fax, eta)] = false;

        out = proxy.exec(usr, fax);
        require(proxy.owner() == address(this), "ds-pause-illegal-storage-change");
    }
}

// plans are executed in an isolated storage context to protect the pause from
// malicious storage modification during plan execution
contract DSPauseProxy {
    address public owner;
    modifier auth { require(msg.sender == owner, "ds-pause-proxy-unauthorized"); _; }
    constructor() public { owner = msg.sender; }

    function exec(address usr, bytes memory fax)
        public auth
        returns (bytes memory out)
    {
        bool ok;
        (ok, out) = usr.delegatecall(fax);
        require(ok, "ds-pause-delegatecall-error");
    }
}

contract DssDeployPauseProxyActions {
    function file(address pause, address actions, address who, bytes32 what, uint data) external {
        bytes32 tag;
        assembly { tag := extcodehash(actions) }
        DSPause(pause).plot(
            address(actions),
            tag,
            abi.encodeWithSignature("file(address,bytes32,uint256)", who, what, data),
            now
        );
        DSPause(pause).exec(
            address(actions),
            tag,
            abi.encodeWithSignature("file(address,bytes32,uint256)", who, what, data),
            now
        );
    }

    function file(address pause, address actions, address who, bytes32 ilk, bytes32 what, uint data) external {
        bytes32 tag;
        assembly { tag := extcodehash(actions) }
        DSPause(pause).plot(
            address(actions),
            tag,
            abi.encodeWithSignature("file(address,bytes32,bytes32,uint256)", who, ilk, what, data),
            now
        );
        DSPause(pause).exec(
            address(actions),
            tag,
            abi.encodeWithSignature("file(address,bytes32,bytes32,uint256)", who, ilk, what, data),
            now
        );
    }

    function file(address pause, address actions, address who, bytes32 ilk, bytes32 what, address data) external {
        bytes32 tag;
        assembly { tag := extcodehash(actions) }
        DSPause(pause).plot(
            address(actions),
            tag,
            abi.encodeWithSignature("file(address,bytes32,bytes32,address)", who, ilk, what, data),
            now
        );
        DSPause(pause).exec(
            address(actions),
            tag,
            abi.encodeWithSignature("file(address,bytes32,bytes32,address)", who, ilk, what, data),
            now
        );
    }

    function rely(address pause, address actions, address who, address to) external {
        bytes32 tag;
        assembly { tag := extcodehash(actions) }
        DSPause(pause).plot(
            address(actions),
            tag,
            abi.encodeWithSignature("rely(address,address)", who, to),
            now
        );
        DSPause(pause).exec(
            address(actions),
            tag,
            abi.encodeWithSignature("rely(address,address)", who, to),
            now
        );
    }

    function dripAndFile(address pause, address actions, address who, bytes32 what, uint data) external {
        bytes32 tag;
        assembly { tag := extcodehash(actions) }
        DSPause(pause).plot(
            address(actions),
            tag,
            abi.encodeWithSignature("dripAndFile(address,bytes32,uint256)", who, what, data),
            now
        );
        DSPause(pause).exec(
            address(actions),
            tag,
            abi.encodeWithSignature("dripAndFile(address,bytes32,uint256)", who, what, data),
            now
        );
    }

    function dripAndFile(address pause, address actions, address who, bytes32 ilk, bytes32 what, uint data) external {
        bytes32 tag;
        assembly { tag := extcodehash(actions) }
        DSPause(pause).plot(
            address(actions),
            tag,
            abi.encodeWithSignature("dripAndFile(address,bytes32,bytes32,uint256)", who, ilk, what, data),
            now
        );
        DSPause(pause).exec(
            address(actions),
            tag,
            abi.encodeWithSignature("dripAndFile(address,bytes32,bytes32,uint256)", who, ilk, what, data),
            now
        );
    }

    function setAuthorityAndDelay(address pause, address actions, address newAuthority, uint newDelay) external {
        bytes32 tag;
        assembly { tag := extcodehash(actions) }
        DSPause(pause).plot(
            address(actions),
            tag,
            abi.encodeWithSignature("setAuthorityAndDelay(address,address,uint256)", pause, newAuthority, newDelay),
            now
        );
        DSPause(pause).exec(
            address(actions),
            tag,
            abi.encodeWithSignature("setAuthorityAndDelay(address,address,uint256)", pause, newAuthority, newDelay),
            now
        );
    }
}