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

    // PlayerState - put into some kind of array of structs?
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

    // HandState
    Suave.DataId private handStageId; // HandStage enum
    Suave.DataId private whoseTurnId; // uint8 - really 0 or 1
    Suave.DataId private actionListId; // Array of Actions
    Suave.DataId private boardCardsId; // len 5 array of cards (uint 0 to 51)
    Suave.DataId private potId; // uint
    Suave.DataId private handOverId; // bool
    // these two should be reset every street
    Suave.DataId private facingBetId; // uint - biggest bet size (total bet amount) on a street
    Suave.DataId private lastRaiseId; // uint - last difference between bets

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
        Suave.DataId _whoseTurnId,
        Suave.DataId _actionListId,
        Suave.DataId _potId,
        Suave.DataId _handOverId,
        Suave.DataId _facingBetId,
        Suave.DataId _lastRaiseId
    ) public payable {
        initComplete = true;
        console.log("initTableCallback called...");
        rngRef = _rngRef;
        buttonId = _buttonId;
        handStageId = _handStageId;
        whoseTurnId = _whoseTurnId;
        actionListId = _actionListId;
        potId = _potId;
        handOverId = _handOverId;
        facingBetId = _facingBetId;
        lastRaiseId = _lastRaiseId;
    }

    function joinTableCallback(
        address player,
        uint8 seat,
        uint stack
    ) public payable {
        emit PlayerJoined(player, seat, stack);
    }

    function initPlayerCallback(
        uint whichPlayer,
        Suave.DataId _playerAddr,
        Suave.DataId _stack,
        Suave.DataId _inHand,
        Suave.DataId _cards,
        Suave.DataId _autoPost,
        Suave.DataId _sittingOut,
        Suave.DataId _playerBetStreet
    ) public payable {
        console.log("initPlayerCallback called...");

        if (whichPlayer == 0) {
            playerAddrId0 = _playerAddr;
            stackId0 = _stack;
            inHandId0 = _inHand;
            cardsId0 = _cards;
            autoPostId0 = _autoPost;
            sittingOutId0 = _sittingOut;
            playerBetStreetId0 = _playerBetStreet;
        } else if (whichPlayer == 1) {
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

        Suave.DataRecord memory handStageRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        Suave.DataRecord memory whoseTurnRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        Suave.DataRecord memory actionListRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        Suave.DataRecord memory potRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        Suave.DataRecord memory handOverRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        Suave.DataRecord memory facingBetRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        Suave.DataRecord memory lastRaiseRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        return
            abi.encodeWithSelector(
                this.initTableCallback.selector,
                rngRec.id,
                buttonIdRec.id,
                handStageRec.id,
                whoseTurnRec.id,
                actionListRec.id,
                potRec.id,
                handOverRec.id,
                facingBetRec.id,
                lastRaiseRec.id
            );
    }

    function initPlayer(uint whichPlayer) external returns (bytes memory) {
        // Have to call this for each player
        require(!initComplete, "Table already initialized");
        // We have to initailize private store with variables
        // Make sure we only init once...
        // For the array

        Suave.DataRecord memory playerAddr = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        Suave.DataRecord memory stack = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        Suave.DataRecord memory inHand = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        Suave.DataRecord memory cards = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        // TODO - well need an array for this...
        Suave.DataRecord memory autoPost = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        Suave.DataRecord memory sittingOut = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        Suave.confidentialStore(
            playerAddr.id,
            "playerAddr",
            abi.encode(address(0))
        );

        Suave.DataRecord memory playerBetStreet = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        return
            abi.encodeWithSelector(
                this.initPlayerCallback.selector,
                whichPlayer,
                playerAddr.id,
                stack.id,
                inHand.id,
                cards.id,
                autoPost.id,
                sittingOut.id,
                playerBetStreet.id
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

    function leaveGame(uint8 seat) external returns (bytes memory) {
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

    function rebuy(uint depositAmount) public {
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

    function withdraw() public {
        require(initComplete, "Table not initialized");
        // Force them to withdraw whole stack
        // TODO - should we also prevent ratholing?  Track when they left game?
        address player = msg.sender;
    }

    function getCard() internal pure returns (uint8) {
        return 1;
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
        Action memory action
    ) internal pure returns (HandState memory) {
        HandState memory handStateNew;

        // Stack too deep, need to refactor this
        /*
        // We'll need to set all of these values
        // Player values
        uint stackNew;
        bool inHandNew = true; // always true unless they fold
        uint playerBetStreetNew;
        // HandState values
        HandStage handStageNew = hs.handStage;
        uint8 whoseTurnNew;
        // TODO - just append action here?
        Action[] memory actionListNew = new Action[](2); // .append(action);
        uint[] memory boardCardsNew = new uint[](2); // .append(action);

        uint potNew = hs.pot;
        bool handOverNew = false; // only true if fold or hand ends
        uint facingBetNew = 0;
        uint lastRaiseNew = 0;

        // action consists of amount and act...
        if (action.act == ActionType.Bet) {
            uint betAmountNew = action.amount - hs.playerBetStreet;
            stackNew = hs.stack - betAmountNew;
            playerBetStreetNew = action.amount;
            // handStageNew = handStageCurr;  // Betting cannot end street action
            potNew = hs.pot + betAmountNew;
            facingBetNew = action.amount;
            lastRaiseNew = hs.playerBetStreet - hs.facingBet;
        } else if (action.act == ActionType.Fold) {
            // stackNew =
            inHandNew = false;
            // playerBetStreetNew = 0;  // this will be reset?
            handStageNew = HandStage.Settle;
            // potNew =
            handOverNew = true;
            facingBetNew = 0;
            lastRaiseNew = 0;
        } else if (action.act == ActionType.Call) {
            // Just the call amount
            uint callAmountNew = facingBetNew - hs.playerBetStreet;
            // Total bet amount
            uint betAmountNew = facingBetNew;

            stackNew = hs.stack - callAmountNew;
            playerBetStreetNew = hs.stack - callAmountNew;
            // TODO - some subtleties because preflop it won't close action
            // handStageNew = ??? depends on action!!!
            potNew = hs.pot + callAmountNew;
            facingBetNew = hs.facingBet;
            // TODO - Think this is wrong in multiplayer
            lastRaiseNew = 0;
        } else if (action.act == ActionType.Check) {
            // Stack stays the same, other player's turn...
            // TODO - again subtleties with preflop...
            // stackNew = stackCurr;
            // playerBetStreetNew =
            // handStageNew =
            // potNew =
            // facingBet = 0;
            // lastRaise = 0;
            // streetOver = ???????
        }

        // TODO - add logic
        // These are dependent on whether the betting round is complete
        whoseTurnNew = 1;
        whoseTurnNew = 0;

        HandState memory handStateNew = HandState({
            handStage: handStageNew,
            whoseTurn: whoseTurnNew,
            actionList: actionListNew,
            boardCards: boardCardsNew,
            pot: potNew,
            handOver: handOverNew,
            facingBet: facingBetNew,
            lastRaise: lastRaiseNew,
            stack: stackNew,
            inHand: inHandNew,
            playerBetStreet: playerBetStreetNew
        });
        */
        return handStateNew;
    }

    function takeAction(Action calldata action) public {
        require(initComplete, "Table not initialized");
        // Ensure validitity of action
        require(_validTurn(msg.sender), "Invalid Turn");
        require(_validAction(action), "Invalid action");
        require(_validAmount(), "Invalid bet amount");
        // require(_validStreet(), "Game is over");

        // If we've made it here the action is valid - transition to next gamestate
        // Now determine gamestate transition... what happens next?
        HandState memory handStateCurr = getHandState();
        HandState memory handStateNew = _transitionHandState(
            handStateCurr,
            action
        );
        updateHandState(handStateNew);

        // Check to see if hand is over after each action?
        if (handStateNew.handOver) {
            _showdown();
        }
    }

    function _showdown() internal {
        // Should be called automatically when hand is over
    }
    function _showCards() internal {
        // Emit them?
    }

    function _settle(uint pot, address winner) internal {
        // Credit pot to winner...
    }

    function _resetHand() internal {
        // Alternate button
        // And reset all HandState params...
        // Suave.DataId private handStageId; // HandStage enum
        // Suave.DataId private whoseTurnId; // uint8 - really 0 or 1
        // Suave.DataId private actionListId; // Array of Actions
        // Suave.DataId private potId; // uint
        // Suave.DataId private handOverId; // bool
    }

    // Helper functions for setting values
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

    function getHandState() internal returns (HandState memory) {
        HandStage handStage = _getHandStage(handStageId, "handStage");
        uint8 whoseTurn = _getUint8(whoseTurnId, "whoseTurn");
        Action[] memory actionList = new Action[](1);
        uint[] memory boardCards = new uint[](1);
        uint pot = _getUint(potId, "pot");
        bool handOver = _getBool(handOverId, "handOver");
        uint facingBet = _getUint(facingBetId, "facingBet");
        uint lastRaise = _getUint(lastRaiseId, "lastRaise");

        uint stack;
        bool inHand;
        uint playerBetStreet;
        if (whoseTurn == 0) {
            stack = _getUint(stackId0, "stack");
            inHand = _getBool(inHandId0, "inHand");
            playerBetStreet = _getUint(playerBetStreetId0, "playerBetStreet");
        } else if (whoseTurn == 1) {
            stack = _getUint(stackId1, "stack");
            inHand = _getBool(inHandId1, "inHand");
            playerBetStreet = _getUint(playerBetStreetId1, "playerBetStreet");
        }

        // Return all the hand state variables
        HandState memory handState = HandState({
            handStage: handStage,
            whoseTurn: whoseTurn,
            actionList: actionList,
            boardCards: boardCards,
            pot: pot,
            handOver: handOver,
            facingBet: facingBet,
            lastRaise: lastRaise,
            stack: stack,
            inHand: inHand,
            playerBetStreet: playerBetStreet
        });
        return handState;
    }

    function updateHandState(HandState memory hs) internal {
        _setHandStage(handStageId, "handStage", hs.handStage);
        _setUint8(whoseTurnId, "whoseTurn", hs.whoseTurn);
        Action[] memory actionList = new Action[](1);
        uint[] memory boardCards = new uint[](1);
        _setUint(potId, "pot", hs.pot);
        _setBool(handOverId, "handOver", hs.handOver);
        _setUint(facingBetId, "facingBet", hs.facingBet);
        _setUint(lastRaiseId, "lastRaise", hs.lastRaise);

        // TODO - have to conditionally set the other values
        if (hs.whoseTurn == 0) {
            // stack = _getUint(stackId0, "stack");
            // inHand = _getBool(inHandId0, "inHand");
            // playerBetStreet = _getUint(playerBetStreetId0, "playerBetStreet");
        } else if (hs.whoseTurn == 1) {
            // stack = _getUint(stackId1, "stack");
            // inHand = _getBool(inHandId1, "inHand");
            // playerBetStreet = _getUint(playerBetStreetId1, "playerBetStreet");
        }
    }
}
