// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "suave-std/Test.sol";
import "suave-std/suavelib/Suave.sol";
import "forge-std/console.sol";
import "suave-std/Context.sol";

import {SuavePokerTable} from "../src/SuavePoker.sol";
import {ConfStoreHelper} from "../src/ConfStoreHelper.sol";

// Contract with all internal methods exposed
contract SuavePokerTableHarness is SuavePokerTable {
    constructor(
        uint _smallBlind,
        uint _bigBlind,
        uint _minBuyin,
        uint _maxBuyin,
        uint _numSeats
    )
        SuavePokerTable(_smallBlind, _bigBlind, _minBuyin, _maxBuyin, _numSeats)
    {}

    function exposed_getPlrAddr(
        Suave.DataId plrDataId
    ) external returns (address) {
        return _getPlrAddr(plrDataId);
    }

    function exposed_getPlrStack(
        Suave.DataId plrDataId
    ) external returns (uint) {
        return _getPlrStack(plrDataId);
    }

    function exposed_getTblHandStage(
        Suave.DataId tblDataId
    ) external returns (HandStage) {
        return _getTblHandStage(tblDataId);
    }

    function exposed_getPlrBetStreet(
        Suave.DataId plrDataId
    ) external returns (uint) {
        return _getPlrBetStreet(plrDataId);
    }

    function exposed_getPlrHolecards(
        Suave.DataId plrDataId
    ) external returns (uint8, uint8) {
        return _getPlrHolecards(plrDataId);
    }

    function exposed_getTblFlop(
        Suave.DataId tblDataId
    ) external returns (uint8, uint8, uint8) {
        return _getTblFlop(tblDataId);
    }
    function exposed_getTblTurn(
        Suave.DataId tblDataId
    ) external returns (uint8) {
        return _getTblTurn(tblDataId);
    }
    function exposed_getTblRiver(
        Suave.DataId tblDataId
    ) external returns (uint8) {
        return _getTblRiver(tblDataId);
    }
}

contract TestSuavePoker is Test, SuaveEnabled {
    function deploy() internal returns (SuavePokerTableHarness) {
        uint smallBlind = 1;
        uint bigBlind = 2;
        uint minBuyin = 20;
        uint maxBuyin = 200;
        uint numPlayers = 6;
        SuavePokerTableHarness spt = new SuavePokerTableHarness(
            smallBlind,
            bigBlind,
            minBuyin,
            maxBuyin,
            numPlayers
        );
        bytes memory o1 = spt.initTable();
        address(spt).call(o1);

        ///////// Just see if it works

        address[] memory allowedList = new address[](1);
        allowedList[0] = address(this);
        Suave.DataRecord memory testRec = Suave.newDataRecord(
            0,
            allowedList,
            allowedList,
            "suavePoker:v0:dataId"
        );
        return spt;
    }

    function test_initTable() public {
        // Just make sure basic contract initialization works
        SuavePokerTableHarness spt = deploy();
    }

    function test_joinTable() public {
        // Deploy the contract
        SuavePokerTableHarness spt = deploy();

        // Check that seat 2 is initially empty
        uint8 seatI = 2;
        Suave.DataId plrDataId = spt.plrDataIdArr(seatI);
        address player = spt.exposed_getPlrAddr(plrDataId);
        assertEq(player, address(0), "Seat 2 should be empty initially");

        // Join the table at seat 2
        address plrAddr = address(0x123);
        uint depositAmount = 100;
        bool autoPost = false;
        vm.prank(plrAddr);
        bytes memory o1 = spt.joinTable(
            seatI,
            plrAddr,
            depositAmount,
            autoPost
        );
        address(spt).call(o1);

        // Stack should be 100
        uint initialStack = spt.exposed_getPlrStack(plrDataId);
        assertEq(initialStack, 100, "Initial stack should be 100");

        // Check that seat 2 is now occupied by the new player
        player = spt.exposed_getPlrAddr(plrDataId);
        assertEq(
            player,
            plrAddr,
            "Seat 2 should be occupied by the new player"
        );
    }

    function test_noBadJoinTables() public {
        // Deploy the contract
        SuavePokerTableHarness spt = deploy();

        // Join at a seat that is not 0
        address player1 = address(0x123);
        uint8 seatI = 2;
        uint depositAmount = 100;
        bool autoPost = false;
        vm.prank(player1);
        bytes memory o1 = spt.joinTable(
            seatI,
            player1,
            depositAmount,
            autoPost
        );
        address(spt).call(o1);

        // Same player Joining at same or different seat should fail
        vm.expectRevert();
        vm.prank(player1);
        spt.joinTable(seatI, player1, depositAmount, autoPost);

        vm.expectRevert();
        vm.prank(player1);
        spt.joinTable(0, player1, depositAmount, autoPost);

        // Different player joining at same seat should fail
        address player2 = address(0x456);
        vm.expectRevert();
        vm.prank(player2);
        spt.joinTable(seatI, player2, depositAmount, autoPost);

        // Joining at an out of bounds index should fail
        vm.expectRevert("Invalid seat!");
        vm.prank(player2);
        spt.joinTable(9, player2, depositAmount, autoPost);

        // Bad buying amount should fail
        vm.expectRevert("Invalid deposit amount!");
        vm.prank(player2);
        spt.joinTable(1, player2, 100000, autoPost);

        vm.expectRevert("Invalid deposit amount!");
        vm.prank(player2);
        spt.joinTable(1, player2, 1, autoPost);
    }

    function test_leaveTable() public {
        // Deploy the contract
        SuavePokerTableHarness spt = deploy();

        // Join the table at seat 0
        address plrAddr = address(0x123);
        uint8 seatI = 0;
        uint depositAmount = 100;
        bool autoPost = false;
        vm.prank(plrAddr);
        bytes memory o1 = spt.joinTable(
            seatI,
            plrAddr,
            depositAmount,
            autoPost
        );
        address(spt).call(o1);

        // Check that seat 0 is occupied by the new player
        Suave.DataId plrDataId = spt.plrDataIdArr(seatI);
        address player = spt.exposed_getPlrAddr(plrDataId);
        assertEq(
            player,
            plrAddr,
            "Seat 0 should be occupied by the new player"
        );

        // Leave the table
        vm.prank(plrAddr);
        spt.leaveTable(seatI);

        // Check that seat 0 is now empty
        player = spt.exposed_getPlrAddr(plrDataId);
        assertEq(player, address(0), "Seat 0 should be empty after leaving");
    }

    function test_rebuy() public {
        // Deploy the contract
        SuavePokerTableHarness spt = deploy();

        // Join the table at seat 0
        address plrAddr = address(0x123);
        uint8 seatI = 0;
        uint depositAmount = 100;
        bool autoPost = false;
        vm.prank(plrAddr);
        bytes memory o1 = spt.joinTable(
            seatI,
            plrAddr,
            depositAmount,
            autoPost
        );
        address(spt).call(o1);

        // Check initial stack
        Suave.DataId plrDataId = spt.plrDataIdArr(seatI);
        uint initialStack = spt.exposed_getPlrStack(plrDataId);
        assertEq(initialStack, 100, "Initial stack should be 100");

        // Rebuy for 100 more
        uint rebuyAmount = 100;
        vm.prank(plrAddr);
        spt.rebuy(seatI, rebuyAmount);

        // Check final stack
        uint finalStack = spt.exposed_getPlrStack(plrDataId);
        assertEq(finalStack, 200, "Final stack should be 200 after rebuy");
    }

    function test_postBlinds() public {
        // Deploy the contract
        SuavePokerTableHarness spt = deploy();

        // Set up players
        address p0 = address(0x123);
        address p1 = address(0x456);

        // Join table
        vm.prank(p0);
        bytes memory o1 = spt.joinTable(0, p0, 100, false);
        address(spt).call(o1);

        vm.prank(p1);
        bytes memory o2 = spt.joinTable(1, p1, 100, false);
        address(spt).call(o2);

        assertEq(
            uint(spt.exposed_getTblHandStage(spt.tblDataId())),
            uint(ConfStoreHelper.HandStage.SBPostStage),
            "Hand stage should be SBPostStage"
        );

        vm.prank(p0);
        spt.takeAction(ConfStoreHelper.ActionType.SBPost, 0, 1, true);

        // Should now be BB's turn
        assertEq(
            uint(spt.exposed_getTblHandStage(spt.tblDataId())),
            uint(ConfStoreHelper.HandStage.BBPostStage),
            "Hand stage should be BBPostStage"
        );

        vm.prank(p1);
        spt.takeAction(ConfStoreHelper.ActionType.BBPost, 1, 2, true);

        // Should now be preflop
        assertEq(
            uint(spt.exposed_getTblHandStage(spt.tblDataId())),
            uint(ConfStoreHelper.HandStage.PreflopBetting),
            "Hand stage should be PreflopBetting"
        );
    }

    function test_integration2pShowdown() public {
        // Deploy the contract
        SuavePokerTableHarness spt = deploy();

        // Set up players
        address p0 = address(0x123);
        address p1 = address(0x456);

        // Join table
        vm.prank(p0);
        bytes memory o1 = spt.joinTable(0, p0, 100, false);
        address(spt).call(o1);

        vm.prank(p1);
        bytes memory o2 = spt.joinTable(1, p1, 100, false);
        address(spt).call(o2);

        // Post blinds
        vm.prank(p0);
        spt.takeAction(ConfStoreHelper.ActionType.SBPost, 0, 1, true);
        vm.prank(p1);
        spt.takeAction(ConfStoreHelper.ActionType.BBPost, 1, 2, true);

        // Check hand stage
        assertEq(
            uint(spt.exposed_getTblHandStage(spt.tblDataId())),
            uint(ConfStoreHelper.HandStage.PreflopBetting),
            "Hand stage should be PreflopBetting"
        );

        // Preflop betting
        vm.prank(p0);
        spt.takeAction(ConfStoreHelper.ActionType.Call, 0, 0, true);
        assertEq(
            uint(spt.exposed_getTblHandStage(spt.tblDataId())),
            uint(ConfStoreHelper.HandStage.PreflopBetting),
            "Hand stage should still be PreflopBetting"
        );
        vm.prank(p1);
        spt.takeAction(ConfStoreHelper.ActionType.Check, 1, 0, true);

        // Check flop
        assertEq(
            uint(spt.exposed_getTblHandStage(spt.tblDataId())),
            uint(ConfStoreHelper.HandStage.FlopBetting),
            "Hand stage should be FlopBetting"
        );
        (uint8 flop1, uint8 flop2, uint8 flop3) = spt.exposed_getTblFlop(
            spt.tblDataId()
        );
        assertTrue(
            flop1 != 53 && flop2 != 53 && flop3 != 53,
            "Flop should be dealt"
        );

        // Flop betting
        vm.prank(p0);
        spt.takeAction(ConfStoreHelper.ActionType.Bet, 0, 5, true);
        vm.prank(p1);
        spt.takeAction(ConfStoreHelper.ActionType.Bet, 1, 10, true);
        vm.prank(p0);
        spt.takeAction(ConfStoreHelper.ActionType.Call, 0, 0, true);

        // Check turn
        assertEq(
            uint(spt.exposed_getTblHandStage(spt.tblDataId())),
            uint(ConfStoreHelper.HandStage.TurnBetting),
            "Hand stage should be TurnBetting"
        );
        uint8 turn = spt.exposed_getTblTurn(spt.tblDataId());
        assertTrue(turn != 53, "Turn should be dealt");

        // Turn betting
        vm.prank(p0);
        spt.takeAction(ConfStoreHelper.ActionType.Check, 0, 0, true);
        vm.prank(p1);
        spt.takeAction(ConfStoreHelper.ActionType.Check, 1, 0, true);

        // Check river
        assertEq(
            uint(spt.exposed_getTblHandStage(spt.tblDataId())),
            uint(ConfStoreHelper.HandStage.RiverBetting),
            "Hand stage should be RiverBetting"
        );
        uint8 river = spt.exposed_getTblRiver(spt.tblDataId());
        assertTrue(river != 53, "River should be dealt");

        // River betting
        vm.prank(p0);
        spt.takeAction(ConfStoreHelper.ActionType.Bet, 0, 5, true);
        vm.prank(p1);
        spt.takeAction(ConfStoreHelper.ActionType.Call, 1, 0, true);

        // Check final state
        assertEq(
            uint(spt.exposed_getTblHandStage(spt.tblDataId())),
            uint(ConfStoreHelper.HandStage.SBPostStage),
            "Hand stage should be SBPostStage"
        );

        // Check final stacks (split pot)
        Suave.DataId plrDataId0 = spt.plrDataIdArr(0);
        Suave.DataId plrDataId1 = spt.plrDataIdArr(1);
        assertEq(
            spt.exposed_getPlrStack(plrDataId0),
            100,
            "Player 0 stack should be 100"
        );
        assertEq(
            spt.exposed_getPlrStack(plrDataId1),
            100,
            "Player 1 stack should be 100"
        );
    }
}
