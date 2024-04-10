// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "suave-std/suavelib/Suave.sol";
import "forge-std/console.sol";
import "suave-std/Context.sol";
import {RNG} from "./RNG.sol";

contract SuavePokerTable {
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
    Suave.DataId private playerAddr0;
    Suave.DataId private stack0;
    Suave.DataId private inHand0;
    Suave.DataId private cards0;
    Suave.DataId private autoPost0;
    Suave.DataId private sittingOut0;
    // P2
    Suave.DataId private playerAddr1; // address
    Suave.DataId private stack1; // uint
    Suave.DataId private inHand1; // bool
    Suave.DataId private cards1; // len 2 array of cards (uint 0 to 51)
    Suave.DataId private autoPost1; // bool
    Suave.DataId private sittingOut1; // bool

    // TableState
    Suave.DataId private button; // uint8

    // HandState
    Suave.DataId private handStage; // HandStage enum
    Suave.DataId private whoseTurn; // uint8 - really 0 or 1
    Suave.DataId private actionList; // Array of Actions
    Suave.DataId private boardCards; // len 5 array of cards (uint 0 to 51)
    Suave.DataId private pot; // uint
    Suave.DataId private gameOver; // bool

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
        Bet,
        Raise,
        Fold,
        Call,
        Check
    }
    struct Action {
        uint256 amount;
        ActionType act;
    }

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
        Suave.DataId _button,
        Suave.DataId _handStage,
        Suave.DataId _whoseTurn,
        Suave.DataId _actionList,
        Suave.DataId _pot,
        Suave.DataId _gameOver
    ) public payable {
        initComplete = true;
        console.log("initTableCallback called...");
        rngRef = _rngRef;
        button = _button;
        handStage = _handStage;
        whoseTurn = _whoseTurn;
        actionList = _actionList;
        pot = _pot;
        gameOver = _gameOver;
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
        Suave.DataId _sittingOut
    ) public payable {
        console.log("initPlayerCallback called...");

        if (whichPlayer == 0) {
            playerAddr0 = _playerAddr;
            stack0 = _stack;
            inHand0 = _inHand;
            cards0 = _cards;
            autoPost0 = _autoPost;
            sittingOut0 = _sittingOut;
        } else if (whichPlayer == 1) {
            playerAddr1 = _playerAddr;
            stack1 = _stack;
            inHand1 = _inHand;
            cards1 = _cards;
            autoPost1 = _autoPost;
            sittingOut1 = _sittingOut;
        }
    }

    function initTable() external returns (bytes memory) {
        Suave.DataRecord memory rng = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        // As part of initialization - have to initialize seed to some value
        bytes memory seed = abi.encode(123456);
        RNG.storeSeed(rng.id, seed);

        Suave.DataRecord memory button = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        Suave.DataRecord memory handStage = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        Suave.DataRecord memory whoseTurn = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        Suave.DataRecord memory actionList = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        Suave.DataRecord memory pot = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        Suave.DataRecord memory gameOver = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        return
            abi.encodeWithSelector(
                this.initTableCallback.selector,
                rng.id,
                button.id,
                handStage.id,
                whoseTurn.id,
                actionList.id,
                pot.id,
                gameOver.id
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

        return
            abi.encodeWithSelector(
                this.initPlayerCallback.selector,
                whichPlayer,
                playerAddr.id,
                stack.id,
                inHand.id,
                cards.id,
                autoPost.id,
                sittingOut.id
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
            playerAddrId = playerAddr0;
        } else if (seat == 1) {
            playerAddrId = playerAddr1;
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
            playerAddr = playerAddr0;
            stack = stack0;
            inHand = inHand0;
            cards = cards0;
            autoPost = autoPost0;
            sittingOut = sittingOut0;
        } else if (seat == 1) {
            playerAddr = playerAddr1;
            stack = stack1;
            inHand = inHand1;
            cards = cards1;
            autoPost = autoPost1;
            sittingOut = sittingOut1;
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
            playerAddr = playerAddr0;
            stack = stack0;
            inHand = inHand0;
            cards = cards0;
            autoPost = autoPost0;
            sittingOut = sittingOut0;
        } else if (seat == 1) {
            playerAddr = playerAddr1;
            stack = stack1;
            inHand = inHand1;
            cards = cards1;
            autoPost = autoPost1;
            sittingOut = sittingOut1;
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

    function getCard() internal returns (uint8) {
        return 1;
    }

    function _validAmount() internal returns (bool) {
        return true;
    }

    function _validAction(Action calldata action) internal returns (bool) {
        return true;
    }

    function _validTurn(address sender) internal pure returns (bool) {
        // Player should be in hand and it should be their turn
        return true;
    }

    function _setStack(Suave.DataId stackId, uint amount) private {
        Suave.confidentialStore(stackId, "stack", abi.encode(amount));
    }

    function transitionGamestate(
        uint8 whichPlayer,
        uint playerStack,
        Action memory action
    ) internal {
        Suave.DataId stackId;
        if (whichPlayer == 0) {
            stackId = stack0; // uint
        } else if (whichPlayer == 1) {
            stackId = stack1; // uint
        }

        // action consists of amount and act...
        if (action.act == ActionType.Bet) {
            uint newAmount = playerStack - action.amount;
            _setStack(stackId, newAmount);
        } else if (action.act == ActionType.Raise) {
            uint newAmount = playerStack - action.amount;
            _setStack(stackId, newAmount);
        } else if (action.act == ActionType.Fold) {
            uint pot = 43;
            address winner = address(0);
            _settle(pot, winner);
        } else if (action.act == ActionType.Call) {
            uint newAmount = playerStack - action.amount;
            _setStack(stackId, newAmount);
        } else if (action.act == ActionType.Check) {
            // Stack stays the same, other player's turn...
        }
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
        uint8 whichPlayer = 0;
        uint playerStack = 3;
        transitionGamestate(whichPlayer, playerStack, action);

        // Check to see if hand is over after each action?
        _showdown();
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
        // Suave.DataId private handStage; // HandStage enum
        // Suave.DataId private whoseTurn; // uint8 - really 0 or 1
        // Suave.DataId private actionList; // Array of Actions
        // Suave.DataId private pot; // uint
        // Suave.DataId private gameOver; // bool
    }
}
