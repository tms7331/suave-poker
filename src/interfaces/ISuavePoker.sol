// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ISuavePokerTable {
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
        // Values for the player whose turn it is
        uint stack;
        bool inHand;
        uint playerBetStreet;
    }
}
