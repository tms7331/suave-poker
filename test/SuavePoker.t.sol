// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "suave-std/Test.sol";
import "suave-std/suavelib/Suave.sol";
import "forge-std/console.sol";
import "suave-std/Context.sol";

import {SuavePokerTable} from "../src/SuavePoker.sol";

// Contract with all internal methods exposed
contract SuavePokerTableHarness is SuavePokerTable {
    constructor(
        uint _smallBlind,
        uint _bigBlind,
        uint _minBuyin,
        uint _maxBuyin
    ) SuavePokerTable(_smallBlind, _bigBlind, _minBuyin, _maxBuyin) {}
    // Deploy this contract then call this method to test `myInternalMethod`.
    function exposed_validTurn(address sender) external returns (bool) {
        return _validTurn(sender);
    }

    function exposed_getPlayer(uint8 seat) external returns (address) {
        return _getPlayer(seat);
    }
}

contract TestSuavePoker is Test, SuaveEnabled {
    event PlayerJoined(address player, uint8 seat, uint stack);

    function testInsertOrder() public {
        // Initializing library
        // No contract, just test library functionality
        address[] memory addressList;
        addressList = new address[](1);
        addressList[0] = 0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829;

        // --------------------

        uint _smallBlind = 1;
        uint _bigBlind = 2;
        uint _minBuyin = 20;
        uint _maxBuyin = 200;

        SuavePokerTableHarness spt = new SuavePokerTableHarness(
            _smallBlind,
            _bigBlind,
            _minBuyin,
            _maxBuyin
        );

        assertFalse(spt.initComplete());

        // For initialization - we have to initialize both players and table
        bytes memory o0 = spt.initPlayer(0);
        address(spt).call(o0);

        bytes memory o1 = spt.initPlayer(1);
        address(spt).call(o1);

        bytes memory o2 = spt.initTable();
        address(spt).call(o2);

        assertTrue(spt.initComplete());
        assertEq(spt.smallBlind(), _smallBlind);
        assertEq(spt.bigBlind(), _bigBlind);

        uint seed = 123;
        bytes memory input = abi.encode(seed);
        ctx.setConfidentialInputs(input);

        // Join as two different players
        vm.prank(address(1));
        bytes memory o3 = spt.joinTable(0, 100);
        vm.expectEmit(true, true, true, true);
        emit PlayerJoined(address(1), 0, 100);
        address(spt).call(o3);

        seed = 456;
        input = abi.encode(seed);
        ctx.setConfidentialInputs(input);

        vm.prank(address(2));
        bytes memory o4 = spt.joinTable(1, 100);
        vm.expectEmit(true, true, true, true);
        emit PlayerJoined(address(2), 1, 100);
        address(spt).call(o4);

        // Also will make sure we get the correct value from confidential store
        address p0 = spt.exposed_getPlayer(0);
        address p1 = spt.exposed_getPlayer(1);
        assertEq(p0, address(1));
        assertEq(p1, address(2));
    }

    function testValidTurn() public {
        // Initializing library
        // No contract, just test library functionality
        address[] memory addressList;
        addressList = new address[](1);
        addressList[0] = 0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829;

        // --------------------

        uint _smallBlind = 1;
        uint _bigBlind = 2;
        uint _minBuyin = 20;
        uint _maxBuyin = 200;

        SuavePokerTableHarness spt = new SuavePokerTableHarness(
            _smallBlind,
            _bigBlind,
            _minBuyin,
            _maxBuyin
        );

        bool success = spt.exposed_validTurn(address(0));
        assertTrue(success);
    }
}
