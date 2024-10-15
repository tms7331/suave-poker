// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "forge-std/console.sol";
import "suave-std/suavelib/Suave.sol";
import "suave-std/Suapp.sol";
import "suave-std/Context.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {RNG} from "./RNG.sol";
import {ConfStoreHelper} from "./ConfStoreHelper.sol";
import {Emitter} from "./Emitter.sol";

contract SuavePokerTable is ConfStoreHelper, Emitter, Suapp {
    // Core table values...
    uint public tableId;
    uint public smallBlind;
    uint public bigBlind;
    uint public minBuyin;
    uint public maxBuyin;
    uint public numSeats;
    bool public initComplete;
    address[] addressList;

    Suave.DataId[] public plrDataIdArr;
    Suave.DataId public tblDataId;
    // For the RNG
    Suave.DataId private rngDataId;

    struct PlayerState {
        address addr;
        bool inHand;
        uint stack;
        uint betStreet;
        ActionType lastActionType;
        uint lastAmount;
    }

    struct TableState {
        HandStage handStage;
        uint8 button;
        uint facingBet;
        uint lastRaise;
    }

    constructor(
        uint _tableId,
        uint _smallBlind,
        uint _bigBlind,
        uint _minBuyin,
        uint _maxBuyin,
        uint _numSeats
    ) {
        // Issue is - tableId must be unique
        tableId = _tableId;
        smallBlind = _smallBlind;
        bigBlind = _bigBlind;
        // TODO - add assertions for min/max buyins
        minBuyin = _minBuyin;
        maxBuyin = _maxBuyin;
        numSeats = _numSeats;
        addressList = new address[](1);
        // from Suave.sol: address public constant ANYALLOWED = 0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829;
        addressList[0] = 0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829;

        plrDataIdArr = new Suave.DataId[](_numSeats);
    }

    // constructor() {
    //     smallBlind = 1;
    //     bigBlind = 2;
    //     // TODO - add assertions for min/max buyins
    //     minBuyin = 1;
    //     maxBuyin = 1000;
    //     numSeats = 6;
    //     addressList = new address[](1);
    //     // from Suave.sol: address public constant ANYALLOWED = 0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829;
    //     addressList[0] = 0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829;

    //     plrDataIdArr = new Suave.DataId[](6);
    // }

    function initTableCallback(
        Suave.DataId _rngDataId,
        Suave.DataId _tblDataId,
        Suave.DataId[] calldata _plrDataIdArr
    ) public payable {
        initComplete = true;
        rngDataId = _rngDataId;
        tblDataId = _tblDataId;
        for (uint256 i = 0; i < _plrDataIdArr.length; i++) {
            plrDataIdArr[i] = _plrDataIdArr[i];
        }
    }

    // Will let us publicly emit logs
    function onchain() public emitOffchainLogs {}

    function initTable() external returns (bytes memory) {
        Suave.DataRecord memory rngRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        // As part of initialization - initialize seed to some value
        bytes memory seed = abi.encode(123456);
        RNG.storeSeed(rngRec.id, seed);

        Suave.DataRecord memory tblRec = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );

        // Set initial values for all table variables
        _setTblHandStage(tblRec.id, HandStage.SBPostStage);
        _setTblButton(tblRec.id, 0);
        _setTblWhoseTurn(tblRec.id, 0);
        _setTblFacingBet(tblRec.id, 0);
        _setTblLastRaise(tblRec.id, 0);
        _setTblPotInitial(tblRec.id, 0);
        _setTblClosingActionCount(tblRec.id, 0);
        _setTblLastActionType(tblRec.id, ActionType.Null);
        _setTblLastAmount(tblRec.id, 0);
        _setNumPots(tblRec.id, 0);
        _setTblFlop(tblRec.id, 53, 53, 53);
        _setTblTurn(tblRec.id, 53);
        _setTblRiver(tblRec.id, 53);
        _setCardBits(rngRec.id, 0);
        _setHandId(tblRec.id, 0);

        Suave.DataId[] memory _plrDataIdArr = new Suave.DataId[](numSeats);
        // Initialize all players too
        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = _initializeSeat();
            _plrDataIdArr[i] = plrDataId;
        }

        emitInitialized(tableId, numSeats);

        return
            abi.encodeWithSelector(
                this.initTableCallback.selector,
                rngRec.id,
                tblRec.id,
                _plrDataIdArr
            );
    }

    function _initializeSeat() internal returns (Suave.DataId) {
        Suave.DataRecord memory seatRef = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suavePoker:v0:dataId"
        );
        Suave.DataId playerNewId = seatRef.id;

        ActionType lastActionType = ActionType.Null;

        _setPlrAddr(playerNewId, address(0));
        _setPlrStack(playerNewId, 0);
        _setPlrInHand(playerNewId, false);
        _setPlrHolecards(playerNewId, 53, 53);
        _setPlrAutoPost(playerNewId, false);
        _setPlrSittingOut(playerNewId, true);
        _setPlrBetStreet(playerNewId, 0);
        _setPlrShowdownVal(playerNewId, 0);
        _setPlrLastActionType(playerNewId, lastActionType);
        _setPlrLastAmount(playerNewId, 0);

        return playerNewId;
    }

    function _depositOk(
        uint stackCurr,
        uint depositAmount
    ) internal view returns (bool) {
        // As long as deposit keeps player's stack in range [minBuyin, maxBuyin] it's ok
        uint stackNew = stackCurr = depositAmount;
        return stackNew >= minBuyin && stackNew <= maxBuyin;
    }

    function joinTableB() external returns (bytes memory) {
        uint8 seatI = 0;
        address plrAddr = msg.sender;
        uint depositAmount = 100;
        bool autoPost = false;
        // TODOTODO - check these...
        // assert 0 <= seat_i <= self.num_seats - 1, "Invalid seat_i!"
        //   assert self.seats[seat_i] == None, "seat_i taken!"
        //   assert address not in self.player_to_seat, "Player already joined!"
        //   assert (
        //       self.min_buyin <= deposit_amount <= self.max_buyin
        //   ), "Invalid deposit amount!"

        require(seatI >= 0 && seatI < numSeats, "Invalid seat!");
        require(initComplete, "Table not initialized");
        // If they havent jointed the table we need to initialize
        Suave.DataId plrDataId = plrDataIdArr[seatI];

        // Make sure it's ok for them to join (seat available)
        require(_getPlrAddr(plrDataId) == address(0));
        // Prevent player from joining multiple times - more efficient way to do this?
        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId_ = plrDataIdArr[i];
            require(
                _getPlrAddr(plrDataId_) != plrAddr,
                "Player already joined!"
            );
        }

        // require(playerToSeat[addr] == 0, "Player already joined!");
        require(
            depositAmount >= minBuyin && depositAmount <= maxBuyin,
            "Invalid deposit amount!"
        );

        // Make sure their deposit amount is in bounds
        require(_depositOk(0, depositAmount));

        // They must also to pass in a random number to seed the RNG
        bytes memory noise = Context.confidentialInputs();
        RNG.addNoise(rngDataId, noise);
        // And we'll also use it as their secret for this table...
        bytes32 secret = bytes32(noise);
        console.log("setting secret", uint256(secret));
        _setPlrSecret(plrDataId, secret);

        _setPlrAddr(plrDataId, plrAddr);

        _setPlrStack(plrDataId, depositAmount);
        _setPlrHolecards(plrDataId, 53, 53);
        _setPlrAutoPost(plrDataId, autoPost);
        _setPlrSittingOut(plrDataId, false);
        _setPlrBetStreet(plrDataId, 0);
        _setPlrShowdownVal(plrDataId, 0);
        _setPlrLastActionType(plrDataId, ActionType.Null);
        _setPlrLastAmount(plrDataId, 0);

        HandStage handStage = _getTblHandStage(tblDataId);

        if (handStage != HandStage.SBPostStage) {
            _setPlrInHand(plrDataId, false);
        } else {
            _setPlrInHand(plrDataId, true);
        }

        // Assign button if it's the first player
        if (getPlayerCount() == 1) {
            _setTblButton(tblDataId, seatI);
            _setTblWhoseTurn(tblDataId, seatI);
        }
        emitJoinTable(tableId, plrAddr, seatI, depositAmount);

        return abi.encodeWithSelector(this.onchain.selector);
    }

    function joinTable(
        uint8 seatI,
        address plrAddr,
        uint depositAmount,
        bool autoPost
    ) external returns (bytes memory) {
        // TODOTODO - check these...
        // assert 0 <= seat_i <= self.num_seats - 1, "Invalid seat_i!"
        //   assert self.seats[seat_i] == None, "seat_i taken!"
        //   assert address not in self.player_to_seat, "Player already joined!"
        //   assert (
        //       self.min_buyin <= deposit_amount <= self.max_buyin
        //   ), "Invalid deposit amount!"

        require(seatI >= 0 && seatI < numSeats, "Invalid seat!");
        require(initComplete, "Table not initialized");
        // If they havent jointed the table we need to initialize
        Suave.DataId plrDataId = plrDataIdArr[seatI];

        // Make sure it's ok for them to join (seat available)
        require(_getPlrAddr(plrDataId) == address(0));
        // Prevent player from joining multiple times - more efficient way to do this?
        // TODO - reenable this, have to figure out play...
        /*
        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId_ = plrDataIdArr[i];
            require(
                _getPlrAddr(plrDataId_) != plrAddr,
                "Player already joined!"
            );
        }
        */

        // require(playerToSeat[addr] == 0, "Player already joined!");
        require(
            depositAmount >= minBuyin && depositAmount <= maxBuyin,
            "Invalid deposit amount!"
        );

        // Make sure their deposit amount is in bounds
        require(_depositOk(0, depositAmount));

        // They must also to pass in a random number to seed the RNG
        bytes memory noise = Context.confidentialInputs();
        RNG.addNoise(rngDataId, noise);

        bytes32 secret = bytes32(noise);
        console.log("setting secret", uint256(secret));
        _setPlrSecret(plrDataId, secret);

        _setPlrAddr(plrDataId, plrAddr);

        _setPlrStack(plrDataId, depositAmount);
        _setPlrHolecards(plrDataId, 53, 53);
        _setPlrAutoPost(plrDataId, autoPost);
        _setPlrSittingOut(plrDataId, false);
        _setPlrBetStreet(plrDataId, 0);
        _setPlrShowdownVal(plrDataId, 0);
        _setPlrLastActionType(plrDataId, ActionType.Null);
        _setPlrLastAmount(plrDataId, 0);

        HandStage handStage = _getTblHandStage(tblDataId);

        if (handStage != HandStage.SBPostStage) {
            _setPlrInHand(plrDataId, false);
        } else {
            _setPlrInHand(plrDataId, true);
        }

        // Assign button if it's the first player
        if (getPlayerCount() == 1) {
            _setTblButton(tblDataId, seatI);
            _setTblWhoseTurn(tblDataId, seatI);
        }
        emitJoinTable(tableId, plrAddr, seatI, depositAmount);

        return abi.encodeWithSelector(this.onchain.selector);
    }

    function leaveTable(uint256 seatI) public returns (bytes memory) {
        Suave.DataId plrDataId = plrDataIdArr[seatI];
        require(_getPlrAddr(plrDataId) == msg.sender, "Player not at seat!");

        _setPlrAddr(plrDataId, address(0));

        // TODO - send them their funds
        uint256 amountStack = _getPlrStack(plrDataId);
        emitLeaveTable(tableId, msg.sender, seatI);
        return abi.encodeWithSelector(this.onchain.selector);
    }

    function rebuy(
        uint256 seatI,
        uint256 rebuyAmount
    ) public returns (bytes memory) {
        Suave.DataId plrDataId = plrDataIdArr[seatI];
        require(_getPlrAddr(plrDataId) == msg.sender, "Player not at seat!");
        uint stack = _getPlrStack(plrDataId);
        uint256 newStack = stack + rebuyAmount;
        require(
            newStack >= minBuyin && newStack <= maxBuyin,
            "Invalid rebuy amount!"
        );

        _setPlrStack(plrDataId, newStack);

        emitRebuy(tableId, msg.sender, seatI, newStack);
        return abi.encodeWithSelector(this.onchain.selector);
    }

    function getPlayerCount() internal returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
            if (_getPlrAddr(plrDataId) == address(0)) {
                count++;
            }
        }
        return count;
    }

    function takeAction(
        ActionType actionType,
        uint8 seatI,
        uint256 amount,
        bool externalAction
    ) external returns (bytes memory) {
        address player = msg.sender;

        uint8 whoseTurn = _getTblWhoseTurn(tblDataId);
        require(whoseTurn == seatI, "Not your turn!");
        Suave.DataId plrDataId = plrDataIdArr[seatI];

        // Group player-related variables into a struct
        PlayerState memory playerState = PlayerState({
            addr: _getPlrAddr(plrDataId),
            inHand: _getPlrInHand(plrDataId),
            stack: _getPlrStack(plrDataId),
            betStreet: _getPlrBetStreet(plrDataId),
            lastActionType: _getPlrLastActionType(plrDataId),
            lastAmount: _getPlrLastAmount(plrDataId)
        });

        require(playerState.addr == player, "Player not at seat!");
        require(playerState.inHand, "Player not in hand!");

        // Group table-related variables into a struct
        TableState memory tableState = TableState({
            handStage: _getTblHandStage(tblDataId),
            button: _getTblButton(tblDataId),
            facingBet: _getTblFacingBet(tblDataId),
            lastRaise: _getTblFacingBet(tblDataId) // Assuming lastRaise comes from the same source
        });

        // Create a HandState struct to manage hand transitions
        HandState memory hs = HandState({
            playerStack: playerState.stack,
            playerBetStreet: playerState.betStreet,
            handStage: tableState.handStage,
            lastActionType: playerState.lastActionType,
            lastActionAmount: playerState.lastAmount,
            transitionNextStreet: false,
            facingBet: tableState.facingBet,
            lastRaise: tableState.lastRaise,
            button: tableState.button
        });

        // Transition the hand state
        HandState memory hsNew = _transitionHandState(hs, actionType, amount);

        _setPlrStack(plrDataId, hsNew.playerStack);
        _setPlrBetStreet(plrDataId, hsNew.playerBetStreet);
        _setPlrLastAmount(plrDataId, amount);
        _setPlrLastActionType(plrDataId, actionType);
        if (actionType == ActionType.Fold) {
            _setPlrInHand(plrDataId, false);
        }

        _setTblFacingBet(tblDataId, hsNew.facingBet);

        // Should either be reset or incremented
        if (
            actionType == ActionType.SBPost || actionType == ActionType.BBPost
        ) {
            _setTblClosingActionCount(tblDataId, -1);
        } else if (actionType == ActionType.Bet) {
            _setTblClosingActionCount(tblDataId, 0);
        }

        _incrementWhoseTurn();
        _setTblLastRaise(tblDataId, hsNew.lastRaise);
        _setTblLastActionType(tblDataId, hsNew.lastActionType);
        _setTblLastAmount(tblDataId, hsNew.lastActionAmount);

        _transitionHandStage(
            actionType == ActionType.SBPost || actionType == ActionType.BBPost
        );

        uint pot = _getTblPotInitial(tblDataId);
        emitTakeAction(
            tableId,
            player,
            seatI,
            uint256(actionType),
            amount,
            hsNew.playerBetStreet,
            pot
        );

        return abi.encodeWithSelector(this.onchain.selector);
    }

    function _transitionHandState(
        HandState memory handState,
        ActionType actionType,
        uint amount
    ) internal view returns (HandState memory) {
        HandState memory newHandState = handState;

        if (actionType == ActionType.SBPost) {
            // CHECKS:
            // we're at the proper stage
            newHandState.facingBet = amount;
            newHandState.lastRaise = amount;
            newHandState.playerStack -= amount;
            newHandState.playerBetStreet = amount;
            newHandState.lastActionAmount = amount;
        } else if (actionType == ActionType.BBPost) {
            // CHECKS:
            // we're at the proper stage
            newHandState.facingBet = amount;
            newHandState.lastRaise = amount;
            newHandState.playerStack -= amount;
            newHandState.playerBetStreet = amount;
            newHandState.lastActionAmount = amount;
        } else if (actionType == ActionType.Bet) {
            // CHECKS:
            // facing action is valid
            // bet amount is valid
            require(amount > handState.facingBet, "Invalid bet amount");
            uint newBetAmount = amount - handState.playerBetStreet;
            newHandState.playerStack -= newBetAmount;
            newHandState.playerBetStreet = amount;
            newHandState.facingBet = amount;
            newHandState.lastRaise = amount - handState.facingBet;
            newHandState.lastActionAmount = newBetAmount;
        } else if (actionType == ActionType.Fold) {
            // CHECKS:
            // None?  But what if someone folds before they post SB/BB?
            newHandState.lastActionAmount = 0;
        } else if (actionType == ActionType.Call) {
            // CHECKS:
            // facing action is valid (bet, call, fold?)
            uint newCallAmount = handState.facingBet -
                handState.playerBetStreet;
            if (newCallAmount > handState.playerStack) {
                newCallAmount = handState.playerStack;
            }
            newHandState.playerStack -= newCallAmount;
            newHandState.playerBetStreet += newCallAmount;
            newHandState.lastActionAmount = newCallAmount;
        } else if (actionType == ActionType.Check) {
            // CHECKS:
            // facing action is valid (check, None)
            newHandState.lastActionAmount = 0;
        }

        // We'll get an underflow if they don't have enough funds
        // require(newHandState.playerStack >= 0, "Insufficient funds");
        newHandState.lastActionType = actionType;

        return newHandState;
    }

    function allIn() internal returns (bool) {
        // TODO - definitely cleaner logic for this, look to refactor
        uint count = 0;
        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
            bool cond1 = _getPlrAddr(plrDataId) != address(0);
            bool cond2 = _getPlrInHand(plrDataId) == true;
            bool cond3 = _getPlrStack(plrDataId) > 0;
            if (cond1 && cond2 && cond3) {
                count++;
            }
        }
        return count <= 1 && _getTblClosingActionCount(tblDataId) == 0;
    }

    function allFolded() internal returns (bool) {
        // TODO - definitely cleaner logic for this, look to refactor
        uint count = 0;
        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
            if (_getPlrAddr(plrDataId) != address(0)) {
                if (_getPlrInHand(plrDataId) == true) {
                    count++;
                }
            }
        }
        return count == 1;
    }

    function _getNewCards(uint numCards) internal returns (uint8[] memory) {
        // Return a cards, 0 <= card <= 51
        uint8[] memory retCards = new uint8[](numCards);
        uint64 bitsOld = _getCardBits(rngDataId);
        for (uint i = 0; i < numCards; i++) {
            // If bitsOld is 0010
            // If our bitsNew is 0010, the bitsOld & bitsNew will be 0010, keep looping
            // But if bitsNew is anything else, 'and' will be 0000, so we can break
            uint64 bitsAnded = 1;
            uint randNum;
            uint64 bitsNew;
            while (bitsAnded != 0) {
                randNum = RNG.generateRandomNumber(rngDataId, 52);
                bitsNew = uint64(2 ** (randNum));
                bitsAnded = bitsNew & bitsOld;
            }
            retCards[i] = uint8(randNum);
            bitsOld = bitsNew | bitsOld;
        }
        _setCardBits(rngDataId, bitsOld);
        return retCards;
    }

    function _dealHolecards() internal {
        uint8[] memory cards;
        uint handId = _getHandId(tblDataId);
        for (uint8 seatI = 0; seatI < numSeats; seatI++) {
            Suave.DataId plrDataId = plrDataIdArr[seatI];
            if (_getPlrInHand(plrDataId)) {
                cards = _getNewCards(2);
                _setPlrHolecards(tblDataId, cards[0], cards[1]);
                // We need to encrypt the cards!
                // We need a fresh secret for each hand...

                bytes32 secret = _getPlrSecret(plrDataId);

                bytes32 handSecret = keccak256(
                    abi.encodePacked(handId, secret)
                );

                bytes32 card0 = bytes32(uint256(cards[0])) ^ handSecret;
                bytes32 card1 = bytes32(uint256(cards[1])) ^ handSecret;
                emitHolecards(tableId, seatI, card0, card1);
            }
        }
    }

    function _dealFlop() internal {
        if (!allFolded()) {
            uint8[] memory cards = _getNewCards(3);
            _setTblFlop(tblDataId, cards[0], cards[1], cards[2]);
            emitFlop(tableId, cards[0], cards[1], cards[2]);
        }
    }

    function _dealTurn() internal {
        if (!allFolded()) {
            uint8[] memory cards = _getNewCards(1);
            _setTblTurn(tblDataId, cards[0]);
            emitTurn(tableId, cards[0]);
        }
    }

    function _dealRiver() internal {
        if (!allFolded()) {
            uint8[] memory cards = _getNewCards(1);
            _setTblRiver(tblDataId, cards[0]);
            emitRiver(tableId, cards[0]);
        }
    }

    function _handStageOverCheck() internal returns (bool) {
        int closingActionCount = _getTblClosingActionCount(tblDataId);
        return (closingActionCount > 0) && uint(closingActionCount) >= numSeats;
    }

    function _transitionHandStage(bool posted) internal {
        HandStage handStage = _getTblHandStage(tblDataId);

        // Blinds
        if (handStage == HandStage.SBPostStage) {
            _setTblHandStage(tblDataId, HandStage.BBPostStage);
            return;
        } else if (handStage == HandStage.BBPostStage) {
            _setTblHandStage(tblDataId, HandStage.HolecardsDeal);
            _transitionHandStage(false);
            return;
        }
        // Deal Holecards
        else if (handStage == HandStage.HolecardsDeal) {
            _dealHolecards();
            _setTblHandStage(tblDataId, HandStage.PreflopBetting);
            _transitionHandStage(false);
            return;
        }
        // Preflop Betting
        else if (handStage == HandStage.PreflopBetting) {
            if (_handStageOverCheck() || allFolded() || allIn()) {
                _nextStreet();
                _setTblHandStage(tblDataId, HandStage.FlopDeal);
                _transitionHandStage(false);
            }
            return;
        }
        // Deal Flop
        else if (handStage == HandStage.FlopDeal) {
            _dealFlop();
            _setTblHandStage(tblDataId, HandStage.FlopBetting);
            _transitionHandStage(false);
            return;
        }
        // Flop Betting
        else if (handStage == HandStage.FlopBetting) {
            if (_handStageOverCheck() || allFolded() || allIn()) {
                _nextStreet();
                _setTblHandStage(tblDataId, HandStage.TurnDeal);
                _transitionHandStage(false);
            }
            return;
        }
        // Deal Turn
        else if (handStage == HandStage.TurnDeal) {
            _dealTurn();
            _setTblHandStage(tblDataId, HandStage.TurnBetting);
            _transitionHandStage(false);
            return;
        }
        // Turn Betting
        else if (handStage == HandStage.TurnBetting) {
            if (_handStageOverCheck() || allFolded() || allIn()) {
                _nextStreet();
                _setTblHandStage(tblDataId, HandStage.RiverDeal);
                _transitionHandStage(false);
            }
            return;
        }
        // Deal River
        else if (handStage == HandStage.RiverDeal) {
            _dealRiver();
            _setTblHandStage(tblDataId, HandStage.RiverBetting);
            _transitionHandStage(false);
            return;
        }
        // River Betting
        else if (handStage == HandStage.RiverBetting) {
            if (_handStageOverCheck() || allFolded() || allIn()) {
                _setTblHandStage(tblDataId, HandStage.Showdown);
                _calculateFinalPot();
                _transitionHandStage(false);
            }
            return;
        }
        // Showdown
        else if (handStage == HandStage.Showdown) {
            _showdown();
            _setTblHandStage(tblDataId, HandStage.Settle);
            _transitionHandStage(false);
            return;
        }
        // Settle Stage
        else if (handStage == HandStage.Settle) {
            _settle();
            _nextHand();
            // Reset to post blinds stage
            _setTblHandStage(tblDataId, HandStage.SBPostStage);
            return;
        }
    }

    function _incrementButton() internal {
        // Count active players
        uint256 activePlayers = 0;
        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
            bool cond1 = _getPlrAddr(plrDataId) != address(0);
            bool cond2 = _getPlrSittingOut(plrDataId) == false;
            uint cond1u = cond1 ? 1 : 0;
            uint cond2u = cond2 ? 1 : 0;
            if (
                _getPlrAddr(plrDataId) != address(0) &&
                _getPlrSittingOut(plrDataId) == false
            ) {
                activePlayers++;
            }
        }

        // Ensure at least two active players before moving the button
        if (activePlayers >= 2) {
            while (true) {
                uint8 button = _getTblButton(tblDataId);
                uint8 newButton = (button + 1) % uint8(numSeats);
                _setTblButton(tblDataId, newButton);
                Suave.DataId plrDataId = plrDataIdArr[button];
                if (_getPlrAddr(plrDataId) == address(0)) {
                    continue;
                }
                if (!_getPlrSittingOut(plrDataId)) {
                    break;
                }
            }
            //}
        }
    }

    function _incrementWhoseTurn() internal {
        bool incremented = false;
        uint8 whoseTurn = _getTblWhoseTurn(tblDataId);
        int closingActionCount = _getTblClosingActionCount(tblDataId);

        for (uint256 i = 1; i <= numSeats; i++) {
            // Want to go around the table in order, starting from
            // whoever's turn it is
            uint256 seatI = (whoseTurn + i) % numSeats;
            Suave.DataId plrDataId = plrDataIdArr[seatI];
            closingActionCount++;

            if (_getPlrAddr(plrDataId) == address(0)) {
                continue;
            }

            // The player must be in the hand and have some funds
            if (_getPlrInHand(plrDataId) && _getPlrStack(plrDataId) > 0) {
                _setTblWhoseTurn(tblDataId, uint8(seatI));
                incremented = true;
                break;
            }
        }

        _setTblClosingActionCount(tblDataId, closingActionCount);
        // Optionally assert checks for debugging
        // require(closingActionCount <= (numSeats + 1), "Too high closingActionCount!");
        // require(incremented, "Failed to increment whoseTurn!");
    }

    function _nextHand() internal {
        _setTblPotInitial(tblDataId, 0);
        _setTblClosingActionCount(tblDataId, 0);
        _setTblFacingBet(tblDataId, 0);
        _setTblLastRaise(tblDataId, 0);
        _setTblLastActionType(tblDataId, ActionType.Null);
        _setTblLastAmount(tblDataId, 0);
        _setCardBits(rngDataId, 0);

        _setTblFlop(tblDataId, 53, 53, 53);
        _setTblTurn(tblDataId, 53);
        _setTblRiver(tblDataId, 53);
        _setNumPots(tblDataId, 0);

        // Reset players
        for (uint i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
            if (_getPlrAddr(plrDataId) != address(0)) {
                _setPlrHolecards(plrDataId, 53, 53);
                _setPlrInHand(plrDataId, true);
                _setPlrLastActionType(plrDataId, ActionType.Null);
                _setPlrLastAmount(plrDataId, 0);

                _setPlrBetStreet(plrDataId, 0);
                _setPlrShowdownVal(plrDataId, 8000);

                // Handle bust and sitting out conditions
                if (_getPlrStack(plrDataId) <= smallBlind) {
                    _setPlrSittingOut(plrDataId, true);
                }
                // TODO - what was this logic?  Why can't have both?
                // ) {
                //     seats[seat_i].inHand = false;
                //     seats[seat_i].sittingOut = true;
                // } else {
                //     seats[seat_i].inHand = true;
                //     seats[seat_i].sittingOut = false;
                // }
            }
        }

        _incrementButton();
        uint8 button = _getTblButton(tblDataId);
        _setTblWhoseTurn(tblDataId, button);
        _incrementHandId();
    }

    function _calculateFinalPot() internal {
        bool[] memory streetPlayers = new bool[](numSeats);
        uint256 playerCount = 0;

        // uint8[] memory activePlayers = new bool[](numSeats);

        // Identify players still in hand and with positive stack
        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
            if (_getPlrInHand(plrDataId) && _getPlrStack(plrDataId) > 0) {
                streetPlayers[i] = true;
            }
        }

        uint potAmount = _getTblPotInitial(tblDataId);

        uint numPots = _getNumPots(tblDataId);
        for (uint256 i = 0; i < numPots; i++) {
            Pot memory pot = _getTblPotsComplete(plrDataIdArr[i]);
            potAmount -= pot.amount;
        }
        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
            potAmount += _getPlrBetStreet(plrDataId);
        }

        Pot memory mainPot;
        mainPot.players = streetPlayers;
        mainPot.amount = potAmount;

        uint potI = _getNumPots(tblDataId);
        _setTblPotsComplete(plrDataIdArr[potI], mainPot);
        _setNumPots(tblDataId, potI + 1);
    }

    function _sort(uint[] memory data) internal pure returns (uint[] memory) {
        uint n = data.length;
        for (uint i = 0; i < n; i++) {
            for (uint j = 0; j < n - i - 1; j++) {
                if (data[j] > data[j + 1]) {
                    // Swap the elements
                    uint temp = data[j];
                    data[j] = data[j + 1];
                    data[j + 1] = temp;
                }
            }
        }
        return data;
    }

    function _nextStreet() internal {
        // Set the turn to the next player
        uint8 button = _getTblButton(tblDataId);
        // TODO - can we improve this logic?
        if (button == 0) {
            button = uint8(numSeats - 1);
        } else {
            button = uint8((button - 1) % numSeats);
        }
        _setTblWhoseTurn(tblDataId, button);
        _incrementWhoseTurn();

        uint8 whoseTurn = _getTblWhoseTurn(tblDataId);

        // Reset table betting state
        _setTblFacingBet(tblDataId, 0);
        _setTblLastRaise(tblDataId, 0);
        _setTblLastActionType(tblDataId, ActionType.Null);
        _setTblLastAmount(tblDataId, 0);
        _setTblClosingActionCount(tblDataId, 0);

        uint256 potInitialNew = _getTblPotInitial(tblDataId);

        uint256 potInitialLeft = potInitialNew;
        uint numPots = _getNumPots(tblDataId);
        for (uint256 i = 0; i < numPots; i++) {
            Pot memory pot = _getTblPotsComplete(plrDataIdArr[i]);
            potInitialLeft -= pot.amount;
        }

        // Track the amounts each player bet on this street
        uint256[] memory betThisStreetAmounts = new uint256[](numSeats);
        bool[] memory inHand = new bool[](numSeats);
        uint256[] memory allInAmountsSorted = new uint256[](numSeats);
        bool allIn = false;
        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
            inHand[i] = _getPlrInHand(plrDataId);
            betThisStreetAmounts[i] = _getPlrBetStreet(plrDataId);
            if (betThisStreetAmounts[i] > 0 && _getPlrStack(plrDataId) == 0) {
                allIn = true;
                allInAmountsSorted[i] = betThisStreetAmounts[i];
            }
        }

        if (allIn) {
            // If our scenario was
            // [50, 60, 40, 50] (bet this street)
            // [true, true, true, false] (in hand)
            // [50, 0, 40, 0] (all-in amounts)
            // [0, 19, 0, 50] (stacks remaining)
            // We want to end up with:
            // 120 (40*4) with players 0, 1, 2
            // 30 (10*3) with players 0, 1
            allInAmountsSorted = _sort(allInAmountsSorted);
            // And clean up a arrays, from [0, 0, 40, 50] we want: [0, 0, 40, 10]
            for (uint256 i = 0; i < numSeats; i++) {
                for (uint256 j = i + 1; j < numSeats; j++) {
                    allInAmountsSorted[j] -= allInAmountsSorted[i];
                }
            }

            for (uint256 i = 0; i < numSeats; i++) {
                // With the arrays/sorting lots of the pots will be 0, so skip them
                if (allInAmountsSorted[i] == 0) {
                    continue;
                }

                uint256 amount = allInAmountsSorted[i];
                // Just for the first hand - should include this
                uint256 potAmount = potInitialLeft;
                potInitialLeft = 0;

                Pot memory sidePot;
                // So we have to update -
                sidePot.players = new bool[](numSeats);
                for (uint256 j = 0; j < numSeats; j++) {
                    if (betThisStreetAmounts[j] >= amount) {
                        potAmount += amount;
                        betThisStreetAmounts[j] -= amount;
                        if (inHand[j]) {
                            sidePot.players[j] = true;
                        }
                    } else {
                        potAmount += betThisStreetAmounts[j];
                        betThisStreetAmounts[j] = 0;
                    }
                }
                sidePot.amount = potAmount;

                uint potI = _getNumPots(tblDataId);
                _setTblPotsComplete(plrDataIdArr[potI], sidePot);
                _setNumPots(tblDataId, potI + 1);
            }
        }

        // Reset player betting state
        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
            potInitialNew += _getPlrBetStreet(plrDataId);
            _setPlrBetStreet(plrDataId, 0);
            _setPlrLastActionType(plrDataId, ActionType.Null);
            _setPlrLastAmount(plrDataId, 0);
        }

        _setTblPotInitial(tblDataId, potInitialNew);
    }

    function _incrementHandId() internal {
        uint handId = _getHandId(tblDataId);
        _setHandId(tblDataId, handId + 1);
    }

    function _settle() internal {
        uint256[] memory lookupVals = new uint256[](numSeats);
        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
            uint showdownVal = _getPlrShowdownVal(plrDataId);
            lookupVals[i] = showdownVal;
        }

        uint numPots = _getNumPots(tblDataId);
        for (uint8 potI = 0; potI < numPots; potI++) {
            Pot memory pot = _getTblPotsComplete(plrDataIdArr[potI]);

            uint256 winnerVal = 9000;

            bool[] memory isWinner = new bool[](numSeats);

            uint256 winnerCount = 0;
            for (uint256 i = 0; i < numSeats; i++) {
                if (pot.players[i] && lookupVals[i] <= winnerVal) {
                    if (lookupVals[i] < winnerVal) {
                        // Ugly but we have to clear out previous winners
                        for (uint256 j = 0; j < numSeats; j++) {
                            isWinner[j] = false;
                        }
                        winnerVal = lookupVals[i];
                        isWinner[i] = true;
                        winnerCount = 1;
                    } else {
                        isWinner[i] = true;
                        winnerCount++;
                    }
                }
            }
            // Credit winnings
            for (uint8 i = 0; i < numSeats; i++) {
                if (isWinner[i]) {
                    uint256 amount = pot.amount / winnerCount;

                    _setPlrStack(
                        plrDataIdArr[i],
                        _getPlrStack(plrDataIdArr[i]) + amount
                    );
                    emitSettle(tableId, potI, amount, i);
                    (uint8 card0, uint8 card1) = _getPlrHolecards(
                        plrDataIdArr[i]
                    );
                    emitShowdown(tableId, i, card0, card1);
                }
            }
        }
    }

    function _getShowdownVal(uint8[] memory cards) internal returns (uint) {
        require(cards.length == 7, "Must provide 7 cards.");

        uint lookupVal = getLookupValue(
            cards[0],
            cards[1],
            cards[2],
            cards[3],
            cards[4],
            cards[5],
            cards[6]
        );
        return lookupVal;
    }

    function _showdown() internal {
        // Create action struct for showdown event
        // uint256[] memory showdownCards = new uint256[](numSeats);

        // Find players still in the hand
        uint256[] memory stillInHand = new uint256[](numSeats);
        uint256 count = 0;

        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
            if (_getPlrInHand(plrDataId)) {
                stillInHand[count++] = i;
            }
        }

        // If only one player remains, they win the pot automatically
        if (count == 1) {
            Suave.DataId plrDataId = plrDataIdArr[stillInHand[0]];
            // Best possible SD value
            _setPlrShowdownVal(plrDataId, 0);
        } else {
            uint8[] memory cards = new uint8[](7);
            (cards[0], cards[1], cards[2]) = _getTblFlop(tblDataId);
            cards[3] = _getTblTurn(tblDataId);
            cards[4] = _getTblRiver(tblDataId);
            for (uint256 i = 0; i < numSeats; i++) {
                Suave.DataId plrDataId = plrDataIdArr[i];
                if (_getPlrInHand(plrDataId)) {
                    (cards[5], cards[6]) = _getPlrHolecards(plrDataId);
                    uint showdownVal = _getShowdownVal(cards);
                    _setPlrShowdownVal(plrDataId, showdownVal);
                }
            }
        }
    }

    function asciiBytesToUint(
        bytes memory asciiBytes
    ) public pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < asciiBytes.length; i++) {
            // Subtract '0' (which is 48 in ASCII) from each byte to get the integer value
            uint256 digit = uint256(uint8(asciiBytes[i])) - 48;
            // Ensure that the value is between 0 and 9, inclusive
            require(
                digit <= 9,
                "Invalid ASCII byte, must represent a number between 0 and 9"
            );
            // Shift left and add the current digit
            result = result * 10 + digit;
        }
        return result;
    }
    /*
    // Need this for tests
    function getLookupValue(
        uint8 card0,
        uint8 card1,
        uint8 card2,
        uint8 card3,
        uint8 card4,
        uint8 card5,
        uint8 card6
    ) internal virtual returns (uint) {}
    */

    function getLookupValue(
        uint8 card0,
        uint8 card1,
        uint8 card2,
        uint8 card3,
        uint8 card4,
        uint8 card5,
        uint8 card6
    ) internal returns (uint) {
        Suave.HttpRequest memory request;
        request.method = "GET";
        string memory url = string.concat(
            "https://api.pokertee.xyz/getLookupValue?card0=",
            Strings.toString(card0),
            "&card1=",
            Strings.toString(card1),
            "&card2=",
            Strings.toString(card2),
            "&card3=",
            Strings.toString(card3),
            "&card4=",
            Strings.toString(card4),
            "&card5=",
            Strings.toString(card5),
            "&card6=",
            Strings.toString(card6)
        );
        request.url = url;
        //.url = "http://54.183.159.52:5000/getLookupValue?card0=53&card1=54&card2=55&card3=56&card4=57&card5=58&card6=59";
        request.headers = new string[](1);
        request.headers[0] = "Content-Type: application/json";
        bytes memory output = Suave.doHTTPRequest(request);
        uint val = asciiBytesToUint(output);
        return val;
    }

    function emitToWS(bytes memory body) internal override {
        Suave.HttpRequest memory request;
        request.method = "POST";
        request.url = "https://api.pokertee.xyz/postAction";

        request.headers = new string[](1);
        request.headers[0] = "Content-Type: application/json";

        // bytes memory bodyb = bytes(
        //     '{"title": "My Card Title", "content": "Call from suave contract..."}'
        // );
        request.body = body;
        bytes memory output = Suave.doHTTPRequest(request);
        // TODO: should we confirm output?  What can we do if it fails?
    }

    function apiRequestZ() public returns (bytes memory) {
        Suave.HttpRequest memory request;
        request.method = "POST";
        request.url = "http://54.183.159.52:5000/postCard";
        request.headers = new string[](1);
        request.headers[0] = "Content-Type: application/json";
        request.body = bytes(
            '{"title": "My Card Title", "content": "Call from suave contract..."}'
        );
        bytes memory output = Suave.doHTTPRequest(request);

        // string.concat(s1, s2)

        return abi.encodeWithSelector(this.onchain.selector);
    }

    // function bytesToUint() external pure returns (uint) {
    //     bytes memory resp = hex"3537";
    //     uint256 integerValue = uint256(resp); // cast the bytes32 to uint256
    //     return integerValue;
    // }
}
