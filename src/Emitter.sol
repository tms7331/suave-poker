// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "forge-std/console.sol";
import "suave-std/suavelib/Suave.sol";
import "suave-std/Suapp.sol";
import "suave-std/Context.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {RNG} from "./RNG.sol";
import {ConfStoreHelper} from "./ConfStoreHelper.sol";

contract Emitter {
    event JoinTable(address indexed player, uint256 seat, uint256 amountStack);

    // Ok to not emit this?
    // event TableInitialized(uint256 tableId, uint256 numPlayers);

    event TakeAction(
        address indexed player,
        uint256 seat,
        uint256 actionType,
        uint256 amount
    );

    event LeaveTable(address indexed player, uint256 seat);
    event Rebuy(address indexed player, uint256 seat, uint256 amountStack);

    event Settle(uint8 potI, uint256 amount, uint8 seatI);

    event Showdown(uint8 seatI, uint8 card0, uint8 card1);
    event HoleCards(uint8 seatI, bytes32 card0, bytes32 card1);
    event Flop(uint8 card0, uint8 card1, uint8 card2);
    event Turn(uint8 card);
    event River(uint8 card);

    function emitToWS(bytes memory body) internal virtual {}

    function emitInitialized(uint256 tableId, uint256 numPlayers) internal {
        // tag_in = {"tag": "initTable", "tableId": table_id, "numPlayers": num_players}
        bytes memory body = abi.encodePacked(
            '{"tag": "initTable", "tableId":',
            Strings.toString(tableId),
            ',"numPlayers":',
            Strings.toString(numPlayers),
            "}"
        );
        emitToWS(body);
    }

    function emitJoinTable(
        uint256 tableId,
        address player,
        uint256 seatI,
        uint256 amountStack
    ) internal {
        // tag_jt = {"tag": "joinTable", "tableId": table_id, "player": address, "seat": seat_i, "amountStack": amount_stack}
        bytes memory body = abi.encodePacked(
            '{"tag": "joinTable", "tableId":',
            Strings.toString(tableId),
            ',"player":"',
            Strings.toHexString(uint160(player), 20),
            '","seat":',
            Strings.toString(seatI),
            ',"amountStack":',
            Strings.toString(amountStack),
            "}"
        );
        emitToWS(body);
        emit JoinTable(player, seatI, amountStack);
    }

    function emitTakeAction(
        uint256 tableId,
        address player,
        uint256 seat,
        uint256 actionType,
        uint256 amount,
        uint256 betThisStreet,
        uint256 pot
    ) public {
        // tag_ta = {"tag": "takeAction", "tableId": table_id, "player": address, "seat": seat_i, "actionType": action_type, "amount": amount, "betThisStreet": bet_this_street, "pot": pot}
        bytes memory body = abi.encodePacked(
            '{"tag": "takeAction", "tableId":',
            Strings.toString(tableId),
            ',"player":"',
            Strings.toHexString(uint160(player), 20),
            '","seat":',
            Strings.toString(seat),
            ',"actionType":',
            Strings.toString(actionType),
            ',"amount":',
            Strings.toString(amount),
            ',"betThisStreet":',
            Strings.toString(betThisStreet),
            ',"pot":',
            Strings.toString(pot),
            "}"
        );
        emitToWS(body);
        emit TakeAction(player, seat, actionType, amount);
    }

    function emitLeaveTable(
        uint256 tableId,
        address player,
        uint256 seat
    ) public {
        // tag_lt = {"tag": "leaveTable", "tableId": table_id, "player": address, "seat": seat_i}
        bytes memory body = abi.encodePacked(
            '{"tag": "leaveTable", "tableId":',
            Strings.toString(tableId),
            ',"player":"',
            Strings.toHexString(uint160(player), 20),
            '","seat":',
            Strings.toString(seat),
            "}"
        );
        emitToWS(body);
        emit LeaveTable(player, seat);
    }

    function emitRebuy(
        uint256 tableId,
        address player,
        uint256 seat,
        uint256 amountStack
    ) public {
        // tag_rb = {"tag": "rebuy", "tableId": table_id, "player": address, "seat": seat_i, "rebuyAmount": rebuy_amount}
        bytes memory body = abi.encodePacked(
            '{"tag": "rebuy", "tableId":',
            Strings.toString(tableId),
            ',"player":"',
            Strings.toHexString(uint160(player), 20),
            '","seat":',
            Strings.toString(seat),
            ',"amountStack":',
            Strings.toString(amountStack),
            "}"
        );
        emitToWS(body);
        emit Rebuy(player, seat, amountStack);
    }

    function emitGameState(
        uint256 potInitial,
        uint256 potTotal,
        address[] players,
        uint256 button,
        uint256 whoseTurn,
        bytes board,
        uint256 handStage,
        uint256 facingBet,
        uint256 lastRaise,
        uint256 amount,
        string actionType
    ) public {
        // Not using?
        // tag_action = {"tag": "gameState", "potInitial": self.pot_initial, "pot": self.pot_total, "players": players, "button": self.button, "whoseTurn": self.whose_turn, "board": self.board, "handStage": self.hand_stage, "facingBet": self.facing_bet, "lastRaise": self.last_raise, "action": { "type": action_type, "amount": amount, }, }
        // tag_action = {
        // "tag": "gameState",
        // "potInitial": self.pot_initial,
        // "pot": self.pot_total,
        // "players": players,
        // "button": self.button,
        // "whoseTurn": self.whose_turn,
        // "board": self.board,
        // "handStage": self.hand_stage,
        // "facingBet": self.facing_bet,
        // "lastRaise": self.last_raise,
        // "action": {
        //     "type": action_type,
        //     "amount": amount,
        // },
        // }
        // emit GameState(
        //     potInitial,
        //     potTotal,
        //     players,
        //     button,
        //     whoseTurn,
        //     board,
        //     handStage,
        //     facingBet,
        //     lastRaise,
        //     amount,
        //     actionType
        // );
    }

    function emitSettle(
        uint256 tableId,
        uint8 potI,
        uint256 amount,
        uint8 seatI
    ) public {
        // action = {"tag": "settle", "tableId": tableId, "pot": pot_i, "amount": amount, "seat": seat_i}
        bytes memory body = abi.encodePacked(
            '{"tag": "settle", "tableId":',
            Strings.toString(tableId),
            ',"pot":',
            Strings.toString(potI),
            ',"amount":',
            Strings.toString(amount),
            ',"seat":',
            Strings.toString(seatI),
            "}"
        );
        emitToWS(body);
        emit Settle(potI, amount, seatI);
    }

    function emitShowdown(
        uint256 tableId,
        uint8 seatI,
        uint8 card0,
        uint8 card1
    ) public {
        // action = {"tag": "showdown", "cards": [], "handStrs": []}
        bytes memory body = abi.encodePacked(
            '{"tag": "showdown", "tableId":',
            Strings.toString(tableId),
            ',"seat":',
            Strings.toString(seatI),
            ',"cards": [',
            Strings.toString(card0),
            ",",
            Strings.toString(card1),
            "]}"
        );
        emitToWS(body);
        emit Showdown(seatI, card0, card1);
    }

    function emitHolecards(
        uint256 tableId,
        uint8 seatI,
        bytes32 card0,
        bytes32 card1
    ) public {
        // tag_hc = {"tag": "cards", "cardType": "holecards", "seat": seat_i, "cards": cards}
        bytes memory body = abi.encodePacked(
            '{"tag": "cards", "cardType": "holecards", "tableId":',
            Strings.toString(tableId),
            ',"seat":',
            Strings.toString(seatI),
            ',"cards": [',
            card0,
            ",",
            card1,
            "]}"
        );
        emitToWS(body);
        emit HoleCards(seatI, card0, card1);
    }

    function emitFlop(
        uint256 tableId,
        uint8 card0,
        uint8 card1,
        uint8 card2
    ) public {
        // tag_flop = {"tag": "cards", "cardType": "flop", "cards": self.deck[0:3]}
        bytes memory body = abi.encodePacked(
            '{"tag": "cards", "cardType": "flop", "tableId":',
            Strings.toString(tableId),
            ',"cards": [',
            Strings.toString(card0),
            ",",
            Strings.toString(card1),
            ",",
            Strings.toString(card2),
            "]}"
        );
        emitToWS(body);
        emit Flop(card0, card1, card2);
    }

    function emitTurn(uint256 tableId, uint8 card) public {
        // tag_turn = {"tag": "cards", "cardType": "turn", "cards": self.deck[0:3]}
        bytes memory body = abi.encodePacked(
            '{"tag": "cards", "cardType": "turn", "tableId":',
            Strings.toString(tableId),
            ',"cards": [',
            Strings.toString(card),
            "]}"
        );
        emitToWS(body);
        emit Turn(card);
    }

    function emitRiver(uint256 tableId, uint8 card) public {
        // tag_river = {"tag": "cards", "cardType": "river", "tableId": table_id, "cards": self.deck[0:3]}
        bytes memory body = abi.encodePacked(
            '{"tag": "cards", "cardType": "river", "tableId":',
            Strings.toString(tableId),
            ',"cards": [',
            Strings.toString(card),
            "]}"
        );
        emitToWS(body);
        emit River(card);
    }
}
