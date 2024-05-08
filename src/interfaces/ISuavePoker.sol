// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ISuavePokerTable {
    event PlayerJoined(address player, uint8 seat, uint stack);

    enum HandStage {
        SBPost,
        BBPost,
        HolecardsDeal,
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
        Null, // Means no betting on current street - NOT an action players can take
        SBPost,
        BBPost,
        Bet, // Bet will include Raise - should be total amount bet on that street
        Fold,
        Call,
        Check
    }

    struct Action {
        uint256 amount;
        ActionType act;
    }

    // General state of the hand
    struct HandState {
        HandStage handStage;
        Action lastAction;
        uint pot;
        bool handOver;
        // These will be more important for multiway
        uint facingBet;
        uint lastRaise;
        uint8 button;
    }

    // State specific to the player whose turn it is
    struct PlayerState {
        uint8 whoseTurn;
        uint stack;
        bool inHand;
        uint playerBetStreet;
        uint oppBetStreet;
    }
}
