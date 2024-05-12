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
    function deploy() internal returns (SuavePokerTableHarness) {
        // Deploys a contract and posts blinds for both players
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

        // For initialization - we have to initialize both players and table
        address(spt).call(spt.initPlayer(0));
        address(spt).call(spt.initPlayer(1));
        address(spt).call(spt.initTable());
        address(spt).call(spt.initTableB());

        uint seed = 123;
        bytes memory input = abi.encode(seed);
        ctx.setConfidentialInputs(input);

        // Join as two different players
        vm.prank(address(1));
        address(spt).call(spt.joinTable(0, 100));

        seed = 456;
        input = abi.encode(seed);
        ctx.setConfidentialInputs(input);

        vm.prank(address(2));
        address(spt).call(spt.joinTable(1, 100));

        Action memory a0 = Action(1, ActionType.SBPost);
        Action memory a1 = Action(2, ActionType.BBPost);

        vm.prank(address(1));
        address(spt).call(spt.takeAction(a0));

        vm.prank(address(2));
        address(spt).call(spt.takeAction(a1));
        return spt;
    }

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
        address(spt).call(spt.initTableB());
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
        address(spt).call(spt.initTableB());
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
        address(spt).call(spt.initTableB());
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

    function test_transitionHandState_Bet() public {
        SuavePokerTableHarness spt = new SuavePokerTableHarness(1, 2, 20, 200);
        // Don't need to do any initialization as _transitionHandState is a pure function

        HandState memory hs = HandState({
            handStage: HandStage.PreflopBetting,
            lastAction: Action(15, ActionType.Bet),
            pot: 17,
            bettingOver: false,
            transitionNextStreet: false,
            closingActionCount: 1,
            facingBet: 15,
            lastRaise: 0,
            button: 0
        });
        PlayerState memory ps = PlayerState({
            whoseTurn: 1,
            stack: 100,
            inHand: true,
            playerBetStreet: 2
        });
        Action memory action = Action(30, ActionType.Bet);

        HandState memory hsNew;
        PlayerState memory psNew;
        (hsNew, psNew) = spt.exposed_transitionHandState(hs, ps, action);

        // We bet 30, so result should be:
        assertTrue(hsNew.handStage == HandStage.PreflopBetting);
        assertTrue(hsNew.lastAction.act == ActionType.Bet);
        assertTrue(hsNew.lastAction.amount == 30);
        // ???
        assertEq(hsNew.pot, 45);
        assertTrue(hsNew.bettingOver == false);
        assertEq(hsNew.facingBet, 30);
        // assertEq(handStateNew.lastRaise, 15);
        assertEq(hsNew.button, 0);

        assertEq(psNew.whoseTurn, 0);
        assertEq(psNew.stack, 72);
        assertTrue(psNew.inHand == true);
        assertEq(psNew.playerBetStreet, 30);
    }

    function test_transitionHandState_Fold() public {
        SuavePokerTableHarness spt = new SuavePokerTableHarness(1, 2, 20, 200);

        HandState memory hs = HandState({
            handStage: HandStage.PreflopBetting,
            lastAction: Action(0, ActionType.Null),
            pot: 2,
            bettingOver: false,
            transitionNextStreet: false,
            closingActionCount: 1,
            facingBet: 0,
            lastRaise: 0,
            button: 0
        });
        PlayerState memory ps = PlayerState({
            whoseTurn: 0,
            stack: 10,
            inHand: true,
            playerBetStreet: 0
        });
        Action memory action = Action(0, ActionType.Fold);

        HandState memory handStateNew;
        PlayerState memory playerStateNew;
        (handStateNew, playerStateNew) = spt.exposed_transitionHandState(
            hs,
            ps,
            action
        );
    }
    function test_transitionHandState_Call() public {
        SuavePokerTableHarness spt = new SuavePokerTableHarness(1, 2, 20, 200);

        HandState memory hs = HandState({
            handStage: HandStage.PreflopBetting,
            lastAction: Action(0, ActionType.Null),
            pot: 2,
            bettingOver: false,
            transitionNextStreet: false,
            closingActionCount: 1,
            facingBet: 0,
            lastRaise: 0,
            button: 0
        });
        PlayerState memory ps = PlayerState({
            whoseTurn: 0,
            stack: 10,
            inHand: true,
            playerBetStreet: 0
        });
        Action memory action = Action(1, ActionType.Call);

        HandState memory handStateNew;
        PlayerState memory playerStateNew;
        (handStateNew, playerStateNew) = spt.exposed_transitionHandState(
            hs,
            ps,
            action
        );
    }
    function test_transitionHandState_Check() public {
        SuavePokerTableHarness spt = new SuavePokerTableHarness(1, 2, 20, 200);

        HandState memory hs = HandState({
            handStage: HandStage.PreflopBetting,
            lastAction: Action(0, ActionType.Null),
            pot: 2,
            bettingOver: false,
            transitionNextStreet: false,
            closingActionCount: 1,
            facingBet: 0,
            lastRaise: 0,
            button: 0
        });
        PlayerState memory ps = PlayerState({
            whoseTurn: 0,
            stack: 10,
            inHand: true,
            playerBetStreet: 0
        });
        Action memory action = Action(5, ActionType.Check);

        HandState memory handStateNew;
        PlayerState memory playerStateNew;
        (handStateNew, playerStateNew) = spt.exposed_transitionHandState(
            hs,
            ps,
            action
        );
    }

    function test_getNewCards() public pure {
        // Hard to test function because pulling random numbers is integrated
        // So just check core logic for confirming cards are valid

        uint64 bitsOld = 2 ** 5;
        uint64 randNum0 = 5;
        uint64 randNum1 = 10;
        uint64 randNum2 = 15;
        uint64 bitsNew0 = uint64(2 ** (randNum0));
        uint64 bitsNew1 = uint64(2 ** (randNum1));
        uint64 bitsNew2 = uint64(2 ** (randNum2));

        // Step 1 - make sure randNum0 fails, but randNum1 and randNum2 pass
        uint64 bitsAnded0_A = bitsNew0 & bitsOld;
        uint64 bitsAnded1_A = bitsNew1 & bitsOld;
        uint64 bitsAnded2_A = bitsNew2 & bitsOld;
        assertNotEq(bitsAnded0_A, 0);
        assertEq(bitsAnded1_A, 0);
        assertEq(bitsAnded2_A, 0);

        // After updating 'bitsOld', only 2 should pass...
        bitsOld = bitsNew1 | bitsOld;

        uint64 bitsAnded0_B = bitsNew0 & bitsOld;
        uint64 bitsAnded1_B = bitsNew1 & bitsOld;
        uint64 bitsAnded2_B = bitsNew2 & bitsOld;
        assertNotEq(bitsAnded0_B, 0);
        assertNotEq(bitsAnded1_B, 0);
        assertEq(bitsAnded2_B, 0);
    }
}
