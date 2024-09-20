// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "forge-std/console.sol";
import "suave-std/suavelib/Suave.sol";
import "suave-std/Context.sol";
import {RNG} from "./RNG.sol";
import {ConfStoreHelper} from "./ConfStoreHelper.sol";

contract SuavePokerTable is ConfStoreHelper {
    // Core table values...
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

    event PlayerJoined(address player, uint8 seat, uint stack);

    event JoinTable(
        address indexed player,
        uint256 seat,
        uint256 depositAmount
    );
    event LeaveTable(address indexed player, uint256 seat);
    event Rebuy(address indexed player, uint256 seat, uint256 rebuyAmount);
    event FlopDealt(uint8[3] cards);
    event TurnDealt(uint8 card);
    event RiverDealt(uint8 card);
    event CardsDealt();
    event GameStateUpdated(
        uint256 potInitial,
        uint256 potTotal,
        uint256 whoseTurn,
        uint8[] board,
        uint8 handStage,
        uint256 facingBet,
        uint256 lastRaise
    );


    constructor(
        uint _smallBlind,
        uint _bigBlind,
        uint _minBuyin,
        uint _maxBuyin,
        uint _numSeats
    ) {
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

    function joinTableCallback(
        address player,
        uint8 seatI,
        uint stack,
        Suave.DataId _plrDataId
    ) public payable {
        // First time this will initialize seat,
        // after that we'll always return the same value
        plrDataIdArr[seatI] = _plrDataId;
        emit PlayerJoined(player, seatI, stack);
    }

    function nullCallback() public payable {}

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

        // Suave.confidentialStore(tblRec.id, "tblHandStateId", abi.encode(0));
        // Suave.confidentialStore(tblRec.id, "tblButtonId", abi.encode(0));
        // Suave.confidentialStore(tblRec.id, "tblWhoseTurnId", abi.encode(0));
        // Suave.confidentialStore(tblRec.id, "tblFacingBetId", abi.encode(0));
        // Suave.confidentialStore(tblRec.id, "tblLastRaiseId", abi.encode(0));
        // Suave.confidentialStore(tblRec.id, "tblPotInitialId", abi.encode(0));
        // Suave.confidentialStore(
        //     tblRec.id,
        //     "tblClosingActionCountId",
        //     abi.encode(0)
        // );
        // Suave.confidentialStore(
        //     tblRec.id,
        //     "tblLastActionTypeId",
        //     abi.encode(0)
        // );
        // Suave.confidentialStore(tblRec.id, "tblLastAmountId", abi.encode(0));
        // Suave.confidentialStore(tblRec.id, "tblPotsCompleteId", abi.encode(0));

        
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
        _setTblPotsComplete(tblRec.id, 0);
        _setFlop(tblRec.id, 53, 53, 53);
        _setTurn(tblRec.id, 53);
        _setRiver(tblRec.id, 53);
        _setCardBits(tblRec.id, 0);
        _setHandId(tblRec.id, 0);

        Suave.DataId[] memory plrDataIdArr = new Suave.DataId[](numSeats);
        // Initialize all players too
        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = _initializeSeat();
            plrDataIdArr[i] = plrDataId;
        }

        return
            abi.encodeWithSelector(
                this.initTableCallback.selector,
                rngRec.id,
                tblRec.id,
                plrDataIdArr
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

    function joinTable(
        uint8 seatI,
        address plrAddr,
        uint depositAmount,
        bool autoPost
    ) external returns (bytes memory) {
        require(seatI >= 0 && seatI < numSeats, "Invalid seat!");
        require(initComplete, "Table not initialized");
        // If they havent jointed the table we need to initialize
        Suave.DataId plrDataId = plrDataIdArr[seatI];

        // Make sure it's ok for them to join (seat available)
        require(_getPlrAddr(plrDataId) == address(0));
        // TODO - we need to prevent player from joining multiple times...
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

        _setPlrAddr(plrDataId, plrAddr);

        _setPlrStack(plrDataId, 0);
        _setPlrHolecards(plrDataId, 53, 53);
        _setPlrAutoPost(plrDataId, autoPost);
        _setPlrSittingOut(plrDataId, true);
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

        // For now - play money, just give them the deposit amount they want
        // _deposit(depositAmount);
        return
            abi.encodeWithSelector(
                this.joinTableCallback.selector,
                msg.sender,
                seatI,
                depositAmount
            );
    }

    function leaveTable(uint256 seatI) public {
        Suave.DataId plrDataId = plrDataIdArr[seatI];
        require(_getPlrAddr(plrDataId) == msg.sender, "Player not at seat!");

        _setPlrAddr(plrDataId, address(0));

        // TODO - this needs a callback
        emit LeaveTable(msg.sender, seatI);
    }

    function rebuy(uint256 seatI, uint256 rebuyAmount) public {
        Suave.DataId plrDataId = plrDataIdArr[seatI];
        require(_getPlrAddr(plrDataId) == msg.sender, "Player not at seat!");
        uint stack = _getPlrStack(plrDataId);
        uint256 newStack = stack + rebuyAmount;
        require(
            newStack >= minBuyin && newStack <= maxBuyin,
            "Invalid rebuy amount!"
        );

        _setPlrStack(plrDataId, newStack);

        // TODO - this needs a callback
        emit Rebuy(msg.sender, seatI, rebuyAmount);
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
        address player,
        uint seatI,
        uint256 amount,
        bool externalAction
    ) external {
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

        // Update player data
        _setPlrStack(plrDataId, hsNew.playerStack);
        _setPlrBetStreet(plrDataId, hsNew.playerBetStreet);
        _setPlrLastAmount(plrDataId, amount);
        _setPlrLastActionType(plrDataId, actionType);

        if (actionType == ActionType.Fold) {
            _setPlrInHand(plrDataId, false);
        }

        if (
            actionType == ActionType.SBPost || actionType == ActionType.BBPost
        ) {
            _setTblClosingActionCount(tblDataId, -1);
        } else if (actionType == ActionType.Bet) {
            _setTblClosingActionCount(tblDataId, 0);
        }

        _incrementWhoseTurn();

        // Transition hand stage if necessary
        if (externalAction) {
            _transitionHandStage(
                actionType == ActionType.SBPost ||
                    actionType == ActionType.BBPost
            );
        }
    }

    function _transitionHandState(
        HandState memory handState,
        ActionType actionType,
        uint amount
    ) internal pure returns (HandState memory) {
        HandState memory newHandState = handState;

        if (actionType == ActionType.SBPost) {
            newHandState.facingBet = amount;
            newHandState.lastRaise = amount;
            newHandState.playerStack -= amount;
            newHandState.playerBetStreet = amount;
            newHandState.lastActionAmount = amount;
        } else if (actionType == ActionType.BBPost) {
            newHandState.facingBet = amount;
            newHandState.lastRaise = amount;
            newHandState.playerStack -= amount;
            newHandState.playerBetStreet = amount;
            newHandState.lastActionAmount = amount;
        } else if (actionType == ActionType.Bet) {
            require(amount > handState.facingBet, "Invalid bet amount");
            uint newBetAmount = amount - handState.playerBetStreet;
            newHandState.playerStack -= newBetAmount;
            newHandState.playerBetStreet = amount;
            newHandState.facingBet = amount;
            newHandState.lastRaise = amount - handState.facingBet;
            newHandState.lastActionAmount = newBetAmount;
        } else if (actionType == ActionType.Fold) {
            newHandState.lastActionAmount = 0;
        } else if (actionType == ActionType.Call) {
            uint newCallAmount = handState.facingBet -
                handState.playerBetStreet;
            if (newCallAmount > handState.playerStack) {
                newCallAmount = handState.playerStack;
            }
            newHandState.playerStack -= newCallAmount;
            newHandState.playerBetStreet += newCallAmount;
            newHandState.lastActionAmount = newCallAmount;
        } else if (actionType == ActionType.Check) {
            newHandState.lastActionAmount = 0;
        }

        require(newHandState.playerStack >= 0, "Insufficient funds");
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
        for (uint256 seat_i = 0; seat_i < numSeats; seat_i++) {
            Suave.DataId plrDataId = plrDataIdArr[seat_i];
            if (_getPlrInHand(plrDataId)) {
                 cards = _getNewCards(2);
                _setPlrHolecards(tblDataId, cards[0], cards[1]);
            }
        }
    }

    function _dealFlop() internal {
        if (!allFolded()) {
            uint8[] memory cards = _getNewCards(3);
            _setFlop(tblDataId, cards[0], cards[1], cards[2]);
        }
    }

    function _dealTurn() internal {
        if (!allFolded()) {
            uint8[] memory cards = _getNewCards(1);
            _setTurn(tblDataId, cards[0]);
        }
    }

    function _dealRiver() internal {
        if (!allFolded()) {
            uint8[] memory cards = _getNewCards(1);
            _setRiver(tblDataId, cards[0]);
        }
    }

    function _handStageOverCheck() internal returns (bool) {
        uint closingActionCount = _getTblClosingActionCount(tblDataId);
        return closingActionCount >= numSeats;
    }

    function _transitionHandStage(bool posted) internal {
        // TODO - need to emit events for updates

        HandStage handStage = _getTblHandStage(tblDataId);

        // Deal Holecards
        if (handStage == HandStage.HolecardsDeal) {
            _dealHolecards();
            handStage = HandStage.PreflopBetting;
            _transitionHandStage(false);
            return;
        }
        // Preflop Betting
        else if (handStage == HandStage.PreflopBetting) {
            if (_handStageOverCheck() || allFolded() || allIn()) {
                handStage = HandStage.FlopDeal;
                _nextStreet();
                _transitionHandStage(false);
            }
            return;
        }
        // Deal Flop
        else if (handStage == HandStage.FlopDeal) {
            _dealFlop();
            handStage = HandStage.FlopBetting;
            _transitionHandStage(false);
            return;
        }
        // Flop Betting
        else if (handStage == HandStage.FlopBetting) {
            if (_handStageOverCheck() || allFolded() || allIn()) {
                handStage = HandStage.TurnDeal;
                _nextStreet();
                _transitionHandStage(false);
            }
            return;
        }
        // Deal Turn
        else if (handStage == HandStage.TurnDeal) {
            _dealTurn();
            handStage = HandStage.TurnBetting;
            _transitionHandStage(false);
            return;
        }
        // Turn Betting
        else if (handStage == HandStage.TurnBetting) {
            if (_handStageOverCheck() || allFolded() || allIn()) {
                handStage = HandStage.RiverDeal;
                _nextStreet();
                _transitionHandStage(false);
            }
            return;
        }
        // Deal River
        else if (handStage == HandStage.RiverDeal) {
            _dealRiver();
            handStage = HandStage.RiverBetting;
            _transitionHandStage(false);
            return;
        }
        // River Betting
        else if (handStage == HandStage.RiverBetting) {
            if (_handStageOverCheck() || allFolded() || allIn()) {
                handStage = HandStage.Showdown;
                _nextStreet();
                _calculateFinalPot();
                _transitionHandStage(false);
            }
            return;
        }
        // Showdown
        else if (handStage == HandStage.Showdown) {
            _showdown();
            handStage = HandStage.Settle;
            _transitionHandStage(false);
            return;
        }
        // Settle Stage
        else if (handStage == HandStage.Settle) {
            // TODO - how are we settling?
            // _settle();
            _nextHand();
            // Reset to post blinds stage
            handStage = HandStage.SBPostStage;
            _transitionHandStage(false);
            return;
        }
    }

    function _incrementButton() internal {
        // Count active players
        uint256 activePlayers = 0;
        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
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
        uint closingActionCount = _getTblClosingActionCount(tblDataId);

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
                _setTblWhoseTurn(tblDataId, uint8(i));
                incremented = true;
                break;
            }
        }

        // Optionally assert checks for debugging
        // require(closingActionCount <= (numSeats + 1), "Too high closingActionCount!");
        // require(incremented, "Failed to increment whoseTurn!");
    }

    function _nextHand() internal {
        _setTblPotInitial(tblDataId, 0);
        _setTblClosingActionCount(tblDataId, 0);
        _setTblFacingBet(tblDataId, 0);
        _setTblLastRaise(tblDataId, 0);
        _setTblLastActionType(tblDataId, ActionType.Check);
        _setTblLastAmount(tblDataId, 0);

        // Reset players
        for (uint i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
            if (_getPlrAddr(plrDataId) != address(0)) {
                _setPlrBetStreet(plrDataId, 0);
                _setPlrShowdownVal(plrDataId, 8000);
                // TODO - handle holecards...
                // delete seats[seat_i].holecards;

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
        // whoseTurn = button;
        uint8 button = _getTblButton(tblDataId);
        _setTblWhoseTurn(tblDataId, button);
        _incrementHandHistory();
    }

    function _calculateFinalPot() internal {
        bool[] memory streetPlayers = new bool[](numSeats);
        uint256 playerCount = 0;

        // Identify players still in hand and with positive stack
        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
            if (_getPlrInHand(plrDataId) && _getPlrStack(plrDataId) > 0) {
                streetPlayers[i] = true;
            }
        }

        // TODO - we need to calculate this...
        // Calculate the main pot amount
        // uint256 mainPotAmount = potInitial;
        // for (uint256 i = 0; i < potsComplete.length; i++) {
        //     mainPotAmount -= potsComplete[i].amount;
        // }

        // Create the main pot and push to potsComplete
        // main_pot = {"players": street_players, "amount": main_pot_amount}
        Pot memory mainPot;
        // TODO - fix here too...
        // mainPot.amount = mainPotAmount;
        // mainPot.players = new uint256[](playerCount);
        // for (uint256 i = 0; i < playerCount; i++) {
        //     mainPot.players[i] = streetPlayers[i];
        // }

        // potsComplete.push(mainPot);
    }

    function _nextStreet() internal {
        uint256 potInitialNew = _getTblPotInitial(tblDataId);

        // Calculate remaining pot after previous side pots
        uint256 potInitialLeft = potInitialNew;
        // TODO - need handling for side pots...
        // for (uint256 i = 0; i < potsComplete.length; i++) {
        //     potInitialLeft -= potsComplete[i].amount;
        // }

        // Track the amounts each player bet on this street
        uint256[] memory betThisStreetAmounts = new uint256[](numSeats);

        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
            if (_getPlrInHand(plrDataId)) {
                betThisStreetAmounts[i] = _getPlrBetStreet(plrDataId);
            }
        }

        // Set the turn to the next player
        // whoseTurn = (button - 1) % numSeats;
        _incrementWhoseTurn();

        // Reset relevant betting state
        _setTblFacingBet(tblDataId, 0);
        _setTblLastRaise(tblDataId, 0);
        _setTblLastActionType(tblDataId, ActionType.Null);
        _setTblLastAmount(tblDataId, 0);
        _setTblClosingActionCount(tblDataId, 0);

        // Determine street players and handle all-ins
        uint256[] memory streetPlayers = new uint256[](numSeats);
        uint256 playerCount = 0;
        Pot[] memory sidePots = new Pot[](numSeats); // Temporary storage for side pots

        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
            if (_getPlrInHand(plrDataId) && _getPlrBetStreet(plrDataId) > 0) {
                streetPlayers[playerCount++] = i;
            }

            // Handle all-in players
            if (
                _getPlrStack(plrDataId) == 0 && _getPlrBetStreet(plrDataId) > 0
            ) {
                sidePots[i].amount = _getPlrBetStreet(plrDataId);
                // sidePots;
                // TODO - figure out handling
                // sidePots[i].players[0] = i;
            }

            // Reset player action
            _setPlrBetStreet(plrDataId, 0);
            _setPlrLastActionType(plrDataId, ActionType.Null);
            _setPlrLastAmount(plrDataId, 0);
        }

        // Sort all-ins by the amount they bet
        for (uint256 i = 0; i < playerCount; i++) {
            for (uint256 j = i + 1; j < playerCount; j++) {
                if (sidePots[i].amount > sidePots[j].amount) {
                    Pot memory temp = sidePots[i];
                    sidePots[i] = sidePots[j];
                    sidePots[j] = temp;
                }
            }
        }

        // Allocate side pots
        for (uint256 i = 0; i < playerCount; i++) {
            uint256 minBetAmount = sidePots[i].amount;
            uint256 sidePotAmount = 0;

            for (uint256 j = 0; j < playerCount; j++) {
                sidePotAmount += betThisStreetAmounts[j] > minBetAmount
                    ? minBetAmount
                    : betThisStreetAmounts[j];
                betThisStreetAmounts[j] -= minBetAmount;
            }

            if (i == 0) {
                sidePotAmount += potInitialLeft;
            }

            sidePots[i].amount = sidePotAmount;
            // TODO - how are we tracking side pots...
            // potsComplete.push(sidePots[i]);

            // Remove the all-in player from street players
            for (uint256 j = 0; j < playerCount; j++) {
                if (streetPlayers[j] == sidePots[i].players[0]) {
                    streetPlayers[j] = streetPlayers[playerCount - 1];
                    playerCount--;
                    break;
                }
            }
        }

        // Update pot initial for next round
        _setTblPotInitial(tblDataId, potInitialNew);
    }

    function _incrementHandHistory() internal {
        uint handId = _getHandId(tblDataId);
        _setHandId(tblDataId, handId + 1);
    }

    function _getShowdownVal(
        uint8[] memory cards
    ) internal view returns (uint) {
        require(cards.length == 7, "Must provide 7 cards.");

        // TODO - make API call here to start...
        uint lookupVal = 33;

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
            (cards[0], cards[1], cards[2]) = _getFlop(tblDataId);
            cards[3] = _getTurn(tblDataId);
            cards[4] = _getRiver(tblDataId);
            for (uint256 i = 0; i < numSeats; i++) {
                Suave.DataId plrDataId = plrDataIdArr[i];
                if (_getPlrInHand(plrDataId)) {
                    (cards[5], cards[6]) = _getPlrHolecards(plrDataId);
                    // TODO - make API call to get SD value?
                    //showdownVal = ???
                }
            }
        }
    }
}
