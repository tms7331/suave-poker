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
        uint _maxBuyin,
        uint _numSeats
    )
        SuavePokerTable(
            _smallBlind,
            _bigBlind,
            _minBuyin,
            _maxBuyin,
            _numSeats
        )
    {}

    function exposed_getPlrAddr(Suave.DataId plrDataId) external returns (address) {
        return _getPlrAddr(plrDataId);
    }

    function exposed_getPlrStack(Suave.DataId plrDataId) external returns (uint) {
        return _getPlrStack(plrDataId);
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
        bytes memory o1 = spt.joinTable(seatI, plrAddr, depositAmount, autoPost);
        address(spt).call(o1);

        // Check that seat 2 is now occupied by the new player
        player = spt.exposed_getPlrAddr(plrDataId);
        assertEq(player, plrAddr, "Seat 2 should be occupied by the new player");
    }

}
