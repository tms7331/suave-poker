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
    function exposed_validTurn(address sender) external returns (bool) {
        return _validTurn(sender);
    }

    function exposed_getPlayer(uint8 seat) external returns (address) {
        return _getPlayer(seat);
    }

    function exposed_transitionHandState(
        HandState memory handStateCurr,
        Action memory action
    ) external returns (HandState memory) {
        return _transitionHandState(handStateCurr, action);
    }
}

contract TestSuavePoker is Test, SuaveEnabled, ISuavePokerTable {
    /*
    event PlayerJoined(address player, uint8 seat, uint stack);

    enum HandStage {
        SBPost,
        BBPost,
        DealHolecards,
        PreflopBetting,
        FlopDeal,
        FlopBetting,
        TurnDeal,
        TurnBetting,
        RiverDeal,
        RiverBetting,
        Showdown,
        Settle
    }
    enum ActionType {
        Bet, // Bet will include Raise - should be total amount bet on that street
        Fold,
        Call,
        Check
    }

    struct Action {
        uint256 amount;
        ActionType act;
    }

    struct HandState {
        HandStage handStage;
        uint8 whoseTurn;
        Action[] actionList;
        uint[] boardCards;
        uint pot;
        bool handOver;
        uint facingBet;
        uint lastRaise;
    }
    */

    function testInsertOrder() public {
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

    function testValidTurn() public {
        // 1/2 game with buyin of 20-200
        SuavePokerTableHarness spt = new SuavePokerTableHarness(1, 2, 20, 200);
        assertFalse(spt.initComplete());
        bool success = spt.exposed_validTurn(address(0));
        assertTrue(success);
    }

    function testTransitionHandState() public {
        // 1/2 game with buyin of 20-200
        SuavePokerTableHarness spt = new SuavePokerTableHarness(1, 2, 20, 200);

        ActionType actType = ActionType.Bet;
        Action memory action = Action(100, actType);

        HandStage handStage = HandStage.FlopBetting;
        Action[] memory actionList = new Action[](1);
        uint[] memory boardCards = new uint[](1);

        HandState memory handStateCurr = HandState({
            handStage: handStage,
            whoseTurn: 0,
            actionList: actionList,
            boardCards: boardCards,
            pot: 2,
            handOver: false,
            facingBet: 0,
            lastRaise: 0,
            stack: 100,
            inHand: true,
            playerBetStreet: 0
        });

        HandState memory handStateNew = spt.exposed_transitionHandState(
            handStateCurr,
            action
        );
    }
}
