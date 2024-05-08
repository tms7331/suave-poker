// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "suave-std/suavelib/Suave.sol";
import "forge-std/console.sol";
import "suave-std/Context.sol";
import {RNG} from "./RNG.sol";
import {ISuavePokerTable} from "./interfaces/ISuavePoker.sol";

contract SuavePokerTable is ISuavePokerTable {
    uint public smallBlind;
    uint public bigBlind;
    uint public minBuyin;
    uint public maxBuyin;
    bool public initComplete;
    address[] addressList;

    // For the RNG
    Suave.DataId private rngRef;

    // Full PlayerState - put into some kind of array of structs?
    // P1
    Suave.DataId private playerAddrId0;
    Suave.DataId private stackId0;
    Suave.DataId private inHandId0;
    Suave.DataId private cardsId0;
    Suave.DataId private autoPostId0;
    Suave.DataId private sittingOutId0;
    Suave.DataId private playerBetStreetId0; // uint - total amount player put into pot on this street
    // P2
    Suave.DataId private playerAddrId1; // address
    Suave.DataId private stackId1; // uint
    Suave.DataId private inHandId1; // bool
    Suave.DataId private cardsId1; // len 2 array of cards (uint 0 to 51)
    Suave.DataId private autoPostId1; // bool
    Suave.DataId private sittingOutId1; // bool
    Suave.DataId private playerBetStreetId1; // uint - total amount player put into pot on this street

    // TableState
    Suave.DataId private buttonId; // uint8
    Suave.DataId private whoseTurnId; // uint8

    // HandState
    Suave.DataId private handStageId; // HandStage enum
    Suave.DataId private lastActionId; // uint
    Suave.DataId private potId; // uint
    Suave.DataId private handOverId; // bool
    // these two should be reset every street
    Suave.DataId private facingBetId; // uint - biggest bet size (total bet amount) on a street
    Suave.DataId private lastRaiseId; // uint - last difference between bets
    // Extra state for cards - should reset every hand
    Suave.DataId private cardBitsId; // uint8
    // Not using these currently - do we need them?
    Suave.DataId private actionListId; // Array of Actions
    Suave.DataId private boardCardsId; // len 5 array of cards (uint 0 to 51)

    event CardEvent(uint8 cardI);

    constructor(
        uint _smallBlind,
        uint _bigBlind,
        uint _minBuyin,
        uint _maxBuyin
    ) {
        smallBlind = _smallBlind;
        bigBlind = _bigBlind;
        // TODO - add assertions for min/max buyins
        minBuyin = _minBuyin;
        maxBuyin = _maxBuyin;
        addressList = new address[](1);
        // from Suave.sol: address public constant ANYALLOWED = 0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829;
        addressList[0] = 0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829;
    }

    function initTableCallback(
        Suave.DataId _rngRef,
        Suave.DataId _buttonId,
        Suave.DataId _handStageId,
        Suave.DataId _lastActionId,
        Suave.DataId _whoseTurnId,
        Suave.DataId _actionListId,
        Suave.DataId _potId,
        Suave.DataId _handOverId,
        Suave.DataId _facingBetId,
        Suave.DataId _lastRaiseId,
        Suave.DataId _cardBitsId
    ) public payable {
        initComplete = true;
        console.log("initTableCallback called...");
        rngRef = _rngRef;
        buttonId = _buttonId;
        handStageId = _handStageId;
        lastActionId = _lastActionId;
        whoseTurnId = _whoseTurnId;
        actionListId = _actionListId;
        potId = _potId;
        handOverId = _handOverId;
        facingBetId = _facingBetId;
        lastRaiseId = _lastRaiseId;
        cardBitsId = _cardBitsId;
        console.log("initTableCallback done...");
    }

    function joinTableCallback(
        address player,
        uint8 seat,
        uint stack
    ) public payable {
        emit PlayerJoined(player, seat, stack);
    }

    function initPlayerCallback(
        uint playerI,
        Suave.DataId _playerAddr,
        Suave.DataId _stack,
        Suave.DataId _inHand,
        Suave.DataId _cards,
        Suave.DataId _autoPost,
        Suave.DataId _sittingOut,
        Suave.DataId _playerBetStreet
    ) public payable {
        console.log("initPlayerCallback called...");

        if (playerI == 0) {
            playerAddrId0 = _playerAddr;
            stackId0 = _stack;
            inHandId0 = _inHand;
            cardsId0 = _cards;
            autoPostId0 = _autoPost;
            sittingOutId0 = _sittingOut;
            playerBetStreetId0 = _playerBetStreet;
        } else if (playerI == 1) {
            playerAddrId1 = _playerAddr;
            stackId1 = _stack;
            inHandId1 = _inHand;
            cardsId1 = _cards;
            autoPostId1 = _autoPost;
            sittingOutId1 = _sittingOut;
            playerBetStreetId1 = _playerBetStreet;
        }
    }

    function initTable() external returns (bytes memory) {
        Suave.DataRecord memory rngRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        // As part of initialization - have to initialize seed to some value
        bytes memory seed = abi.encode(123456);
        RNG.storeSeed(rngRec.id, seed);

        Suave.DataRecord memory buttonIdRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        _setUint8(buttonIdRec.id, "button", 0);

        Suave.DataRecord memory handStageRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        _setHandStage(handStageRec.id, "handStage", HandStage.SBPost);

        Suave.DataRecord memory lastActionRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        Action memory lastAction = Action(0, ActionType.Null);
        _setLastAction(lastActionRec.id, "lastAction", lastAction);

        Suave.DataRecord memory whoseTurnRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        _setUint8(whoseTurnRec.id, "whoseTurn", 0);

        Suave.DataRecord memory actionListRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        // TODO - are we using the actionList?  If yes, initialize!
        console.log("WARNING - not initializing actionList!");

        Suave.DataRecord memory potRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        _setUint(potRec.id, "pot", 0);

        Suave.DataRecord memory handOverRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        _setBool(handOverRec.id, "handOver", false);

        Suave.DataRecord memory facingBetRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        _setUint(facingBetRec.id, "facingBet", 0);

        Suave.DataRecord memory lastRaiseRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        _setUint(lastRaiseRec.id, "lastRaise", 0);

        Suave.DataRecord memory cardBitsRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        _setUint64(cardBitsRec.id, "cardBits", 0);

        return
            abi.encodeWithSelector(
                this.initTableCallback.selector,
                rngRec.id,
                buttonIdRec.id,
                handStageRec.id,
                lastActionRec.id,
                whoseTurnRec.id,
                actionListRec.id,
                potRec.id,
                handOverRec.id,
                facingBetRec.id,
                lastRaiseRec.id,
                cardBitsRec.id
            );
    }

    function initPlayer(uint playerI) external returns (bytes memory) {
        // Have to call this for each player
        require(!initComplete, "Table already initialized");
        // We have to initailize private store with variables
        // Make sure we only init once...
        // For the array

        Suave.DataRecord memory playerAddrRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        // This is just initialization, not joining, so set address to 0
        _setAddr(playerAddrRec.id, "playerAddr", address(0));

        Suave.DataRecord memory stackRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        _setUint(stackRec.id, "stack", 0);

        Suave.DataRecord memory inHandRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        _setBool(inHandRec.id, "inHand", false);

        Suave.DataRecord memory cardsRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        // TODO - if we're going to use this we need to set i...
        console.log("WARNING - not initializing player cards!");

        // TODO - well need an array for this...
        Suave.DataRecord memory autoPostRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        _setBool(autoPostRec.id, "autoPost", false);

        Suave.DataRecord memory sittingOutRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        _setBool(sittingOutRec.id, "sittingOut", false);

        Suave.DataRecord memory playerBetStreetRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        _setUint(playerBetStreetRec.id, "playerBetStreet", 0);

        return
            abi.encodeWithSelector(
                this.initPlayerCallback.selector,
                playerI,
                playerAddrRec.id,
                stackRec.id,
                inHandRec.id,
                cardsRec.id,
                autoPostRec.id,
                sittingOutRec.id,
                playerBetStreetRec.id
            );
    }

    function nullCallback() public payable {
        console.log("nullCallback...");
    }

    function _depositOk(uint depositAmount) internal returns (bool) {
        return true;
    }

    function _getPlayer(uint8 seat) internal returns (address playerAddr) {
        Suave.DataId playerAddrId;
        if (seat == 0) {
            playerAddrId = playerAddrId0;
        } else if (seat == 1) {
            playerAddrId = playerAddrId1;
        }
        bytes memory val = Suave.confidentialRetrieve(
            playerAddrId,
            "playerAddr"
        );
        playerAddr = abi.decode(val, (address));
    }

    function joinTable(
        uint8 seat,
        uint depositAmount
    ) external returns (bytes memory) {
        require(initComplete, "Table not initialized");
        // Make sure it's ok for them to join (seat available)
        require(_getPlayer(seat) == address(0));
        // Make sure their deposit amount is in bounds
        require(_depositOk(depositAmount));

        // They must also to pass in a random number to seed the RNG
        bytes memory noise = Context.confidentialInputs();
        RNG.addNoise(rngRef, noise);

        Suave.DataId playerAddr;
        Suave.DataId stack;
        Suave.DataId inHand;
        Suave.DataId cards;
        Suave.DataId autoPost;
        Suave.DataId sittingOut;

        if (seat == 0) {
            playerAddr = playerAddrId0;
            stack = stackId0;
            inHand = inHandId0;
            cards = cardsId0;
            autoPost = autoPostId0;
            sittingOut = sittingOutId0;
        } else if (seat == 1) {
            playerAddr = playerAddrId1;
            stack = stackId1;
            inHand = inHandId1;
            cards = cardsId1;
            autoPost = autoPostId1;
            sittingOut = sittingOutId1;
        }

        Suave.confidentialStore(
            playerAddr,
            "playerAddr",
            abi.encode(msg.sender)
        );
        Suave.confidentialStore(stack, "stack", abi.encode(depositAmount));
        Suave.confidentialStore(inHand, "inHand", abi.encode(true));
        Suave.confidentialStore(cards, "cards", abi.encode(0));
        Suave.confidentialStore(autoPost, "autoPost", abi.encode(false));
        Suave.confidentialStore(sittingOut, "sittingOut", abi.encode(false));

        // For now - play money, just give them the deposit amount they want
        // _deposit(depositAmount);
        return
            abi.encodeWithSelector(
                this.joinTableCallback.selector,
                msg.sender,
                seat,
                depositAmount
            );
    }

    function leaveTable(uint8 seat) external returns (bytes memory) {
        // Force players to pass in seat?  Or should we scan for it?
        require(_getPlayer(seat) == msg.sender);

        Suave.DataId playerAddr;
        Suave.DataId stack;
        Suave.DataId inHand;
        Suave.DataId cards;
        Suave.DataId autoPost;
        Suave.DataId sittingOut;

        if (seat == 0) {
            playerAddr = playerAddrId0;
            stack = stackId0;
            inHand = inHandId0;
            cards = cardsId0;
            autoPost = autoPostId0;
            sittingOut = sittingOutId0;
        } else if (seat == 1) {
            playerAddr = playerAddrId1;
            stack = stackId1;
            inHand = inHandId1;
            cards = cardsId1;
            autoPost = autoPostId1;
            sittingOut = sittingOutId1;
        }

        Suave.confidentialStore(
            playerAddr,
            "playerAddr",
            abi.encode(address(0))
        );
        Suave.confidentialStore(stack, "stack", abi.encode(0));
        Suave.confidentialStore(inHand, "inHand", abi.encode(false));
        Suave.confidentialStore(cards, "cards", abi.encode(0));
        Suave.confidentialStore(autoPost, "autoPost", abi.encode(false));
        Suave.confidentialStore(sittingOut, "sittingOut", abi.encode(false));

        return abi.encodeWithSelector(this.nullCallback.selector);
    }

    function rebuy(uint depositAmount) external {
        // TODO -
        // Issue is we need to process rebuys in between hands
        // This is NOT the same as an initial deposit...
        require(initComplete, "Table not initialized");
        // Make sure it's ok for them to rebuy (player is in game)
        // Make sure their deposit amount is in bounds
        // For now - play money, just give them the deposit amount they want
        // _deposit(depositAmount);
    }

    function _deposit(uint depositAmount) internal {
        address player = msg.sender;
        // balances[player] += depositAMount;
    }

    function _withdraw() internal {
        require(initComplete, "Table not initialized");
        // Force them to withdraw whole stack
        // TODO - should we also prevent ratholing?  Track when they left game?
        address player = msg.sender;
    }

    function _validAmount() internal pure returns (bool) {
        return true;
    }

    function _validAction(Action calldata action) internal pure returns (bool) {
        return true;
    }

    function _validTurn(address sender) internal pure returns (bool) {
        // Player should be in hand and it should be their turn
        return true;
    }

    function _transitionHandState(
        HandState memory hs,
        PlayerState memory ps,
        Action memory action
    ) internal pure returns (HandState memory, PlayerState memory) {
        // Is it safe to overwrite them as we go?
        PlayerState memory playerStateNew = ps;
        HandState memory handStateNew = hs;

        // action consists of amount and act...
        if (action.act == ActionType.SBPost) {
            // When a player posts the SB, it should affect:
            // -- HandState values:
            // HandStage handStage;
            // Action lastAction;
            // uint pot;
            // uint facingBet;
            // uint lastRaise;
            // -- PlayerState values:
            // uint8 whoseTurn;
            // uint stack;
            // uint playerBetStreet;
            hs.handStage = HandStage.BBPost;
            hs.lastAction = action;
            hs.pot = hs.pot + action.amount;
            hs.facingBet = action.amount;
            hs.lastRaise = action.amount;
            // TODO - hardcoded for 2 players...
            ps.whoseTurn = ps.whoseTurn == 0 ? 1 : 0;
            ps.stack = ps.stack - action.amount;
            ps.playerBetStreet = action.amount;
        } else if (action.act == ActionType.BBPost) {
            // When a player posts the BB, it should affect:
            // -- HandState values:
            // HandStage handStage;
            // Action lastAction;
            // uint pot;
            // uint facingBet;
            // uint lastRaise;
            // -- PlayerState values:
            // uint8 whoseTurn;
            // uint stack;
            // uint playerBetStreet;
            hs.handStage = HandStage.HolecardsDeal;
            hs.lastAction = action;
            hs.pot = hs.pot + action.amount;
            hs.facingBet = action.amount;
            hs.lastRaise = action.amount;
            // -- PlayerState values:
            ps.whoseTurn = ps.whoseTurn == 0 ? 1 : 0;
            ps.stack = ps.stack - action.amount;
            ps.playerBetStreet = action.amount;
        } else if (action.act == ActionType.Bet) {
            // When a player bets, it should affect:
            // -- HandState values:
            // Action lastAction;
            // uint pot;
            // uint facingBet;
            // uint lastRaise;
            // -- PlayerState values:
            // uint8 whoseTurn;
            // uint stack;
            // uint playerBetStreet;

            // TODO - make this more general, currently hardcoded for 2 players
            ps.whoseTurn = ps.whoseTurn == 0 ? 1 : 0;
            uint betAmountNew = action.amount - ps.playerBetStreet;
            ps.stack = ps.stack - betAmountNew;
            ps.playerBetStreet = action.amount;

            hs.lastAction = action;
            hs.pot = hs.pot + betAmountNew;
            hs.facingBet = action.amount;
            hs.lastRaise = ps.playerBetStreet - hs.facingBet;
        } else if (action.act == ActionType.Fold) {
            // When a player folds, it should affect:
            // -- HandState values:
            // HandStage handStage;
            // Action lastAction;
            // -- PlayerState values:
            // bool handOver;
            // bool inHand;
            hs.handStage = HandStage.Showdown;
            hs.lastAction = action;
            ps.inHand = false;
            hs.handOver = true;
        } else if (action.act == ActionType.Call) {
            // When a player calls, it should affect:
            // -- HandState values:
            // HandStage handStage - possibly;
            // Action lastAction
            // uint pot;
            // bool handOver - if it was a call all-in...;
            // -- PlayerState values:
            // uint8 whoseTurn;
            // uint stack;
            // uint playerBetStreet;

            // Just the call amount
            uint callAmountNew = hs.facingBet - ps.playerBetStreet;
            // Total bet amount
            // uint betAmountNew = hs.facingBet;

            // TODO - think this is wrong...
            hs.pot = hs.pot + callAmountNew;
            ps.stack = ps.stack - callAmountNew;
            ps.playerBetStreet = ps.playerBetStreet + callAmountNew;

            bool streetOver = ps.whoseTurn != hs.button;
            if (streetOver) {
                if (hs.handStage == HandStage.PreflopBetting) {
                    hs.handStage = HandStage.FlopDeal;
                } else if (hs.handStage == HandStage.FlopBetting) {
                    hs.handStage = HandStage.TurnDeal;
                } else if (hs.handStage == HandStage.TurnBetting) {
                    hs.handStage = HandStage.RiverDeal;
                } else if (hs.handStage == HandStage.RiverBetting) {
                    hs.handStage = HandStage.Showdown;
                }

                // Need to reset this for the next street!
                Action memory lastAction = Action(0, ActionType.Null);
                hs.lastAction = lastAction;
                // TODO - this is hardcoded for two players, this should actually
                // be the UTG player
                ps.whoseTurn = hs.button;
            } else {
                hs.lastAction = action;
                uint8 numPlayers = 2;
                ps.whoseTurn = (ps.whoseTurn + 1) % numPlayers;
            }
        } else if (action.act == ActionType.Check) {
            // When a player checks, it should affect:
            // -- HandState values:
            // HandStage handStage - possibly!
            // Action lastAction;
            // bool handOver - possibly!;
            // -- PlayerState values:
            // uint8 whoseTurn;

            // If it's the last player to act (check based on button)
            // and they check, onto next street...
            bool streetOver = ps.whoseTurn != hs.button;

            if (streetOver) {
                // Is there not any way to increment the enum by 1?
                // hs.handStage = hs.handStage + 1;
                if (hs.handStage == HandStage.PreflopBetting) {
                    hs.handStage = HandStage.FlopDeal;
                } else if (hs.handStage == HandStage.FlopBetting) {
                    hs.handStage = HandStage.TurnDeal;
                } else if (hs.handStage == HandStage.TurnBetting) {
                    hs.handStage = HandStage.RiverDeal;
                } else if (hs.handStage == HandStage.RiverBetting) {
                    hs.handStage = HandStage.Showdown;
                }

                // Seems kind of pointless?  Why do we need handOver
                // if we have 'Showdown' handStage?
                if (hs.handStage == HandStage.Showdown) {
                    hs.handOver = true;
                }
                // TODO - this is hardcoded for two players, this should actually
                // be the UTG player
                ps.whoseTurn = hs.button;
            } else {
                uint8 numPlayers = 2;
                ps.whoseTurn = (ps.whoseTurn + 1) % numPlayers;
            }
            hs.lastAction = action;
        }

        return (handStateNew, playerStateNew);
    }

    function _getNewCards(uint numCards) internal returns (uint8[] memory) {
        // Return cards between 1 and 52 -
        // Avoid zero indexing because the Solidity default is 0 so it can cause
        // issues with non-ambiguous representation
        uint8[] memory retCards = new uint8[](numCards);
        uint64 oldBits = _getUint64(cardBitsId, "cardBits");
        uint64 newBits = 0;
        while (newBits == 0) {
            uint randNum = RNG.generateRandomNumber(rngRef, 52) + 1;
            uint64 bits = uint64(2 ** (randNum));
            newBits = bits | oldBits;
        }
        _setUint64(cardBitsId, "cardBits", newBits);
        return retCards;
    }

    function showCardsCallback(uint8[] memory retCards) public payable {
        for (uint256 i = 0; i < retCards.length; i++) {
            // console.log(_fills[i].amount, _fills[i].price);
            emit CardEvent(retCards[i]);
        }
    }

    function takeAction(
        Action calldata action
    ) external returns (bytes memory) {
        console.log("Taking action!");
        require(initComplete, "Table not initialized");
        // Ensure validitity of action
        require(_validAction(action), "Invalid action");
        require(_validAmount(), "Invalid bet amount");

        // If we've made it here the action is valid - transition to next gamestate
        // Now determine gamestate transition... what happens next?
        console.log("Getting hand state...");
        HandState memory handStateCurr = _getHandState();
        console.log("Getting player state...");
        PlayerState memory playerStateCurr = _getPlayerState();

        uint playerI = playerStateCurr.whoseTurn;
        require(_validTurn(msg.sender), "Invalid Turn");

        HandState memory handStateNew;
        PlayerState memory playerStateNew;
        console.log("Making state transition");
        (handStateNew, playerStateNew) = _transitionHandState(
            handStateCurr,
            playerStateCurr,
            action
        );

        // Temporary - in future cards will be emitted via API precompile
        uint8[] memory retCards = new uint8[](4);

        if (handStateNew.handStage == HandStage.HolecardsDeal) {
            uint8[] memory p0Cards = _getNewCards(2);
            uint8[] memory p1Cards = _getNewCards(2);
            retCards[0] = p0Cards[0];
            retCards[1] = p0Cards[1];
            retCards[2] = p1Cards[0];
            retCards[3] = p1Cards[1];

            // And we need to progress handstate
            handStateNew.handStage = HandStage.PreflopBetting;

            // Deal cards
            // Deal cards to players
            // Deal cards to board
            // Update hand state
        } else if (handStateNew.handStage == HandStage.FlopDeal) {
            uint8[] memory flop = _getNewCards(3);
            retCards[0] = flop[0];
            retCards[1] = flop[1];
            retCards[2] = flop[2];
            // And we need to progress handstate
            handStateNew.handStage = HandStage.FlopBetting;
        } else if (handStateNew.handStage == HandStage.TurnDeal) {
            uint8[] memory turn = _getNewCards(1);
            retCards[0] = turn[0];
            // And we need to progress handstate
            handStateNew.handStage = HandStage.TurnBetting;
        } else if (handStateNew.handStage == HandStage.RiverDeal) {
            uint8[] memory river = _getNewCards(1);
            retCards[0] = river[0];
            // And we need to progress handstate
            handStateNew.handStage = HandStage.RiverBetting;
        }

        _updateHandState(handStateNew);
        _updatePlayerState(playerI, playerStateNew);

        // Check to see if hand is over after each action?
        if (handStateNew.handOver) {
            // So if player folded - other player wins
            uint lookup0;
            uint lookup1;
            if (action.act == ActionType.Fold) {
                // Lower is better, so give player who folded high number
                lookup0 = playerI == 0 ? 1 : 0;
                lookup1 = playerI == 1 ? 1 : 0;
            } else {
                lookup0 = _getLookupVals(0);
                lookup1 = _getLookupVals(1);
            }
            _showdown(handStateNew, lookup0, lookup1);
        }

        return
            abi.encodeWithSelector(this.showCardsCallback.selector, retCards);
    }

    function _showdown(
        HandState memory hs,
        uint lookup0,
        uint lookup1
    ) internal {
        // Should be called automatically when hand is over

        // Calling 'settle' will update player stacks
        if (lookup0 > lookup1) {
            _settle(hs.pot, 0);
        } else if (lookup1 > lookup0) {
            _settle(hs.pot, 1);
        } else {
            _settle(hs.pot / 2, 0);
            _settle(hs.pot / 2, 1);
        }
        // Update state so next hand can start
        _nextHand(hs.button);
    }

    function _getLookupVals(uint8 playerI) internal returns (uint) {
        // Emit them?
        return 33;
    }

    function _settle(uint pot, uint8 playerI) internal {
        // Credit pot to winner
        // Pass in values instead to avoid multiple calls?
        if (playerI == 0) {
            uint stack = _getUint(stackId0, "stack");
            uint stackNew = stack + pot;
            _setUint(stackId0, "stack", stackNew);
        } else if (playerI == 1) {
            uint stack = _getUint(stackId1, "stack");
            uint stackNew = stack + pot;
            _setUint(stackId1, "stack", stackNew);
        }
    }

    function _nextHand(uint8 buttonCurr) internal {
        // Set logic so when we extend to more players, logic will still work
        uint8 numPlayers = 2;

        // button should move around table
        uint8 buttonNew = (buttonCurr + 1) % numPlayers;
        // TODO - review this logic
        // player to act should be UTG... button, SB, BB, UTG
        // but if there are only 2 players, it's also SB?
        uint8 utgNew = buttonNew; // (buttonNew + 2) % numPlayers;
        _setUint8(buttonId, "button", buttonNew);
        _setUint8(whoseTurnId, "whoseTurn", utgNew);

        _setHandStage(handStageId, "handStage", HandStage.SBPost);
        Action memory lastAction = Action(0, ActionType.Null);
        _setLastAction(lastActionId, "lastAction", lastAction);
        _setUint(potId, "pot", 0);
        _setBool(handOverId, "handOver", false);
        _setUint(facingBetId, "facingBet", 0);
        _setUint(lastRaiseId, "lastRaise", 0);
        _setUint64(cardBitsId, "cardBits", 0);

        _setUint64(playerBetStreetId0, "playerBetStreet", 0);
        _setUint64(playerBetStreetId1, "playerBetStreet", 0);
    }

    // Helper functions for setting values

    function _setAddr(
        Suave.DataId key,
        string memory keyStr,
        address addr
    ) internal {
        Suave.confidentialStore(key, keyStr, abi.encode(addr));
    }

    function _setUint(
        Suave.DataId key,
        string memory keyStr,
        uint newAmount
    ) internal {
        Suave.confidentialStore(key, keyStr, abi.encode(newAmount));
    }

    function _setUint8(
        Suave.DataId key,
        string memory keyStr,
        uint8 newAmount
    ) internal {
        Suave.confidentialStore(key, keyStr, abi.encode(newAmount));
    }

    function _setUint64(
        Suave.DataId key,
        string memory keyStr,
        uint64 newAmount
    ) internal {
        Suave.confidentialStore(key, keyStr, abi.encode(newAmount));
    }

    function _setBool(
        Suave.DataId key,
        string memory keyStr,
        bool newBool
    ) internal {
        Suave.confidentialStore(key, keyStr, abi.encode(newBool));
    }

    function _setHandStage(
        Suave.DataId key,
        string memory keyStr,
        HandStage newHandStage
    ) internal {
        Suave.confidentialStore(key, keyStr, abi.encode(newHandStage));
    }

    function _setLastAction(
        Suave.DataId key,
        string memory keyStr,
        Action memory lastAction
    ) internal {
        Suave.confidentialStore(key, keyStr, abi.encode(lastAction));
    }

    // Helper functions for getting values

    function _getUint(
        Suave.DataId key,
        string memory keyStr
    ) internal returns (uint) {
        bytes memory val = Suave.confidentialRetrieve(key, keyStr);
        uint vald = abi.decode(val, (uint));
        return vald;
    }

    function _getUint8(
        Suave.DataId key,
        string memory keyStr
    ) internal returns (uint8) {
        bytes memory val = Suave.confidentialRetrieve(key, keyStr);
        uint8 vald = abi.decode(val, (uint8));
        return vald;
    }

    function _getUint64(
        Suave.DataId key,
        string memory keyStr
    ) internal returns (uint64) {
        bytes memory val = Suave.confidentialRetrieve(key, keyStr);
        uint64 vald = abi.decode(val, (uint64));
        return vald;
    }

    function _getBool(
        Suave.DataId key,
        string memory keyStr
    ) internal returns (bool) {
        bytes memory val = Suave.confidentialRetrieve(key, keyStr);
        bool vald = abi.decode(val, (bool));
        return vald;
    }

    function _getHandStage(
        Suave.DataId key,
        string memory keyStr
    ) internal returns (HandStage) {
        bytes memory val = Suave.confidentialRetrieve(key, keyStr);
        HandStage vald = abi.decode(val, (HandStage));
        return vald;
    }

    function _getLastAction(
        Suave.DataId key,
        string memory keyStr
    ) internal returns (Action memory) {
        bytes memory val = Suave.confidentialRetrieve(key, keyStr);
        Action memory vald = abi.decode(val, (Action));
        return vald;
    }

    function _getPlayerState() internal returns (PlayerState memory) {
        uint8 whoseTurn = _getUint8(whoseTurnId, "whoseTurn");
        uint stack;
        bool inHand;
        uint playerBetStreet;
        uint oppBetStreet;
        if (whoseTurn == 0) {
            stack = _getUint(stackId0, "stack");
            inHand = _getBool(inHandId0, "inHand");
            playerBetStreet = _getUint(playerBetStreetId0, "playerBetStreet");
            oppBetStreet = _getUint(playerBetStreetId1, "playerBetStreet");
        } else if (whoseTurn == 1) {
            stack = _getUint(stackId1, "stack");
            inHand = _getBool(inHandId1, "inHand");
            playerBetStreet = _getUint(playerBetStreetId1, "playerBetStreet");
            oppBetStreet = _getUint(playerBetStreetId0, "playerBetStreet");
        }

        PlayerState memory playerState = PlayerState({
            whoseTurn: whoseTurn,
            stack: stack,
            inHand: inHand,
            playerBetStreet: playerBetStreet,
            oppBetStreet: oppBetStreet
        });
        return playerState;
    }

    function _updatePlayerState(uint playerI, PlayerState memory ps) internal {
        // We should NOT rely on 'whoseTurn' here for setting basic player values
        _setUint8(whoseTurnId, "whoseTurn", ps.whoseTurn);
        if (playerI == 0) {
            _setUint(stackId0, "stack", ps.stack);
            _setBool(inHandId0, "inHand", ps.inHand);
            _setUint(playerBetStreetId0, "playerBetStreet", ps.playerBetStreet);
            // We also need to update oppBetStreet - because if it's a new street
            // that will go to 0...
            _setUint(playerBetStreetId1, "playerBetStreet", ps.oppBetStreet);
        } else if (playerI == 1) {
            _setUint(stackId1, "stack", ps.stack);
            _setBool(inHandId1, "inHand", ps.inHand);
            _setUint(playerBetStreetId1, "playerBetStreet", ps.playerBetStreet);
            _setUint(playerBetStreetId0, "playerBetStreet", ps.oppBetStreet);
        }
    }

    function _getHandState() internal returns (HandState memory) {
        HandStage handStage = _getHandStage(handStageId, "handStage");
        Action memory lastAction = _getLastAction(lastActionId, "lastAction");
        uint pot = _getUint(potId, "pot");
        bool handOver = _getBool(handOverId, "handOver");
        // Action[] memory actionList = new Action[](1);
        // uint[] memory boardCards = new uint[](1);
        uint facingBet = _getUint(facingBetId, "facingBet");
        uint lastRaise = _getUint(lastRaiseId, "lastRaise");
        uint8 button = _getUint8(buttonId, "button");

        // Return all the hand state variables
        HandState memory handState = HandState({
            handStage: handStage,
            lastAction: lastAction,
            pot: pot,
            handOver: handOver,
            facingBet: facingBet,
            lastRaise: lastRaise,
            button: button
        });
        return handState;
    }

    function _updateHandState(HandState memory hs) internal {
        // HandStage handStage;
        // Action lastAction;
        // uint pot;
        // bool handOver;
        // uint facingBet;
        // uint lastRaise;
        _setHandStage(handStageId, "handStage", hs.handStage);
        _setLastAction(lastActionId, "lastAction", hs.lastAction);
        _setUint(potId, "pot", hs.pot);
        _setBool(handOverId, "handOver", hs.handOver);
        _setUint(facingBetId, "facingBet", hs.facingBet);
        _setUint(lastRaiseId, "lastRaise", hs.lastRaise);
        // We don't need to set this because it only changes between hands...
        _setUint8(buttonId, "button", hs.button);
    }
}
