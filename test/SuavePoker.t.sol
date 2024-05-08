// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "suave-std/Test.sol";
import "suave-std/suavelib/Suave.sol";
import "forge-std/console.sol";
import "suave-std/Context.sol";

import {SuavePokerTable} from "../src/SuavePoker.sol";
import {ISuavePokerTable} from "../src/interfaces/ISuavePoker.sol";

// Contract with all internal methods exposed
contract SuavePokerTableHarness is SuavePokerTable {
    constructor(
        uint _smallBlind,
        uint _bigBlind,
        uint _minBuyin,
        uint _maxBuyin
    ) SuavePokerTable(_smallBlind, _bigBlind, _minBuyin, _maxBuyin) {}
    // Deploy this contract then call this method to test `myInternalMethod`.
    function exposed_validTurn(address sender) external pure returns (bool) {
        return _validTurn(sender);
    }

    function exposed_getPlayer(uint8 seat) external returns (address) {
        return _getPlayer(seat);
    }

    function exposed_getHandState() external returns (HandState memory) {
        return _getHandState();
    }

    function exposed_transitionHandState(
        HandState memory handStateCurr,
        PlayerState memory playerStateCurr,
        Action memory action
    ) external pure returns (HandState memory, PlayerState memory) {
        return _transitionHandState(handStateCurr, playerStateCurr, action);
    }
}

contract TestSuavePoker is Test, SuaveEnabled, ISuavePokerTable {
    function test_joinTable() public {
        // 1/2 game with buyin of 20-200

        uint smallBlind = 1;
        uint bigBlind = 2;
        uint minBuyin = 20;
        uint maxBuyin = 200;
        SuavePokerTableHarness spt = new SuavePokerTableHarness(
            smallBlind,
            bigBlind,
            minBuyin,
            maxBuyin
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
        assertEq(spt.smallBlind(), smallBlind);
        assertEq(spt.bigBlind(), bigBlind);
        assertEq(spt.minBuyin(), minBuyin);
        assertEq(spt.maxBuyin(), maxBuyin);

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

    function test_validTurn() public {
        // 1/2 game with buyin of 20-200
        SuavePokerTableHarness spt = new SuavePokerTableHarness(1, 2, 20, 200);
        assertFalse(spt.initComplete());
        bool success = spt.exposed_validTurn(address(0));
        assertTrue(success);
    }

    function test_transitionHandState() public {
        // 1/2 game with buyin of 20-200
        SuavePokerTableHarness spt = new SuavePokerTableHarness(1, 2, 20, 200);

        ActionType actType = ActionType.Bet;
        Action memory action = Action(100, actType);

        HandStage handStage = HandStage.FlopBetting;
        Action memory lastAction = Action(0, ActionType.Bet);

        HandState memory handStateCurr = HandState({
            handStage: handStage,
            lastAction: lastAction,
            pot: 2,
            handOver: false,
            facingBet: 0,
            lastRaise: 0,
            button: 0
        });

        PlayerState memory playerStateCurr = PlayerState({
            whoseTurn: 0,
            stack: 10,
            inHand: true,
            playerBetStreet: 20,
            oppBetStreet: 20
        });

        HandState memory handStateNew;
        PlayerState memory playerStateNew;

        (handStateNew, playerStateNew) = spt.exposed_transitionHandState(
            handStateCurr,
            playerStateCurr,
            action
        );
    }

    function test_playFullHand() public {
        // Simulate all the actions to play one full basic hand

        uint smallBlind = 1;
        uint bigBlind = 2;
        uint minBuyin = 20;
        uint maxBuyin = 200;
        SuavePokerTableHarness spt = new SuavePokerTableHarness(
            smallBlind,
            bigBlind,
            minBuyin,
            maxBuyin
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
        assertEq(spt.smallBlind(), smallBlind);
        assertEq(spt.bigBlind(), bigBlind);
        assertEq(spt.minBuyin(), minBuyin);
        assertEq(spt.maxBuyin(), maxBuyin);

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

        // Full action list:
        // blinds, raise/call, bet/call on each street
        Action memory a0 = Action(1, ActionType.SBPost);
        Action memory a1 = Action(2, ActionType.BBPost);
        Action memory a2 = Action(5, ActionType.Bet);
        Action memory a3 = Action(0, ActionType.Call);

        bytes memory cb;

        vm.prank(address(1));
        address(spt).call(spt.takeAction(a0));

        vm.prank(address(2));
        address(spt).call(spt.takeAction(a1));

        vm.prank(address(1));
        address(spt).call(spt.takeAction(a2));

        vm.prank(address(2));
        cb = spt.takeAction(a3);
        address(spt).call(cb);

        // Should be on flop at this point
        vm.prank(address(1));
        cb = spt.takeAction(a2);
        address(spt).call(cb);

        vm.prank(address(2));
        cb = spt.takeAction(a3);
        address(spt).call(cb);

        // Should be on turn at this point
        vm.prank(address(1));
        cb = spt.takeAction(a2);
        address(spt).call(cb);

        vm.prank(address(2));
        cb = spt.takeAction(a3);
        address(spt).call(cb);

        // Should be on river at this point
        vm.prank(address(1));
        cb = spt.takeAction(a2);
        address(spt).call(cb);

        vm.prank(address(2));
        cb = spt.takeAction(a3);
        address(spt).call(cb);

        // Now showdown, and hand should reset..
    }

    function test_postBlinds() public {
        // Simulate all the actions to get to the point of posting blinds

        uint smallBlind = 1;
        uint bigBlind = 2;
        uint minBuyin = 20;
        uint maxBuyin = 200;
        SuavePokerTableHarness spt = new SuavePokerTableHarness(
            smallBlind,
            bigBlind,
            minBuyin,
            maxBuyin
        );
        assertFalse(spt.initComplete());

        // For initialization - we have to initialize both players and table
        bytes memory o0 = spt.initPlayer(0);
        address(spt).call(o0);

        bytes memory o1 = spt.initPlayer(1);
        address(spt).call(o1);

        bytes memory o2 = spt.initTable();
        address(spt).call(o2);

        console.log("Init ddone..");

        assertTrue(spt.initComplete());
        assertEq(spt.smallBlind(), smallBlind);
        assertEq(spt.bigBlind(), bigBlind);
        assertEq(spt.minBuyin(), minBuyin);
        assertEq(spt.maxBuyin(), maxBuyin);

        uint seed = 123;
        bytes memory input = abi.encode(seed);
        ctx.setConfidentialInputs(input);

        // Join as two different players
        vm.prank(address(1));
        bytes memory o3 = spt.joinTable(0, 100);
        console.log("p1 joined");
        vm.expectEmit(true, true, true, true);
        emit PlayerJoined(address(1), 0, 100);
        address(spt).call(o3);

        seed = 456;
        input = abi.encode(seed);
        ctx.setConfidentialInputs(input);

        vm.prank(address(2));
        bytes memory o4 = spt.joinTable(1, 100);
        console.log("p2 joined");
        vm.expectEmit(true, true, true, true);
        emit PlayerJoined(address(2), 1, 100);
        address(spt).call(o4);

        // Full action list:
        // blinds, raise/call, bet/call on each street
        Action memory a0 = Action(1, ActionType.SBPost);
        Action memory a1 = Action(2, ActionType.BBPost);

        console.log("Now takinga ction...");

        vm.prank(address(1));
        address(spt).call(spt.takeAction(a0));

        // At this stage - handState should be BBPost
        HandState memory hs = spt.exposed_getHandState();
        assertTrue(hs.handStage == HandStage.BBPost);

        vm.prank(address(2));
        address(spt).call(spt.takeAction(a1));
        // At this stage - handState should be PreflopBet
        hs = spt.exposed_getHandState();
        assertTrue(hs.handStage == HandStage.PreflopBetting);
    }
}
