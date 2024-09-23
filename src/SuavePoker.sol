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
        Pot memory pot = Pot({players: new bool[](numSeats), amount: 0});
        _setTblPotsComplete(tblRec.id, pot);
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
        // Prevent player from joining multiple times - more efficient way to do this?
        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
            require(
                _getPlrAddr(plrDataId) != plrAddr,
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

        _setPlrAddr(plrDataId, plrAddr);

        _setPlrStack(plrDataId, depositAmount);
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
        uint seatI,
        uint256 amount,
        bool externalAction
    ) external {
        address player = msg.sender;

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
        // else {
        //     _setTblClosingActionCount(
        //         tblDataId,
        //         _getTblClosingActionCount(tblDataId) + 1
        //     );
        // }

        _incrementWhoseTurn();

        // TODOTODO - review all these values... think action should not be fold?
        _setTblLastRaise(tblDataId, hsNew.lastRaise);
        _setTblLastActionType(tblDataId, hsNew.lastActionType);
        _setTblLastAmount(tblDataId, hsNew.lastActionAmount);

        _transitionHandStage(
            actionType == ActionType.SBPost || actionType == ActionType.BBPost
        );
    }

    function _transitionHandState(
        HandState memory handState,
        ActionType actionType,
        uint amount
    ) internal view returns (HandState memory) {
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
            console.log(handState.facingBet);
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
            _setTblFlop(tblDataId, cards[0], cards[1], cards[2]);
        }
    }

    function _dealTurn() internal {
        if (!allFolded()) {
            uint8[] memory cards = _getNewCards(1);
            _setTblTurn(tblDataId, cards[0]);
        }
    }

    function _dealRiver() internal {
        if (!allFolded()) {
            uint8[] memory cards = _getNewCards(1);
            _setTblRiver(tblDataId, cards[0]);
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
                _setTblWhoseTurn(tblDataId, uint8(i));
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

        // TODOTODO - how do we set this?
        // _setTblPotsComplete(tblDataId, 0);

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
        // whoseTurn = button;
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
        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
            potAmount += _getPlrBetStreet(plrDataId);
        }

        Pot memory mainPot;
        mainPot.players = streetPlayers;
        mainPot.amount = potAmount;
        _setTblPotsComplete(tblDataId, mainPot);

        // TODO - we need to calculate this...
        // Calculate the main pot amount
        // uint256 mainPotAmount = potInitial;
        // for (uint256 i = 0; i < potsComplete.length; i++) {
        //     mainPotAmount -= potsComplete[i].amount;
        // }

        // Create the main pot and push to potsComplete
        // main_pot = {"players": street_players, "amount": main_pot_amount}
        //Pot memory mainPot;
        // TODO - fix here too...
        // mainPot.amount = mainPotAmount;
        // mainPot.players = new uint256[](playerCount);
        // for (uint256 i = 0; i < playerCount; i++) {
        //     mainPot.players[i] = streetPlayers[i];
        // }

        // potsComplete.push(mainPot);
    }

    function _nextStreet() internal {
        // TODOTODO - set these, figure out how we're tracking them...
        // tblPotInitial(Suave.DataId tblDataId,uint potInitial)
        // tblPotsComplete(Suave.DataId tblDataId,uint potsComplete)

        // Set the turn to the next player
        uint8 button = _getTblButton(tblDataId);
        // TODO - can we improve this logic?
        if (button == 0) {
            button = uint8(numSeats);
        } else {
            button = uint8((button - 1) % numSeats);
        }
        _setTblWhoseTurn(tblDataId, button);
        _incrementWhoseTurn();

        // Reset table betting state
        _setTblFacingBet(tblDataId, 0);
        _setTblLastRaise(tblDataId, 0);
        _setTblLastActionType(tblDataId, ActionType.Null);
        _setTblLastAmount(tblDataId, 0);
        _setTblClosingActionCount(tblDataId, 0);

        uint256 potInitialNew = _getTblPotInitial(tblDataId);
        // Reset player betting state
        for (uint256 i = 0; i < numSeats; i++) {
            Suave.DataId plrDataId = plrDataIdArr[i];
            potInitialNew += _getPlrBetStreet(plrDataId);
            _setPlrBetStreet(plrDataId, 0);
            _setPlrLastActionType(plrDataId, ActionType.Null);
            _setPlrLastAmount(plrDataId, 0);
        }
        /*

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
        */

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

        Pot memory pot = _getTblPotsComplete(tblDataId);
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
        for (uint256 i = 0; i < numSeats; i++) {
            if (isWinner[i]) {
                _setPlrStack(
                    plrDataIdArr[i],
                    _getPlrStack(plrDataIdArr[i]) + pot.amount / winnerCount
                );
            }
        }

        /*
        for pot in self.pots_complete:
            winner_val = 9000
            winner_i = []
            # Will consist of 'amount' and 'players'
            for seat_i in pot["players"]:
                if self.seats[seat_i]["showdown_val"] < winner_val:
                    winner_val = self.seats[seat_i]["showdown_val"]
                    winner_i = [seat_i]
                elif self.seats[seat_i]["showdown_val"] == winner_val:
                    winner_i.append(seat_i)
            # Credit winnings
            for seat_i in winner_i:
                self.seats[seat_i]["stack"] += pot["amount"] / len(winner_i)
            # And add our event
            # [{ potTotal: 60, winners: { 0: 60 } }];
            # pot_dict = {seat_i: pot["amount"] / len(winner_i) for seat_i in winner_i}
            winner_dict = {seat_i: pot["amount"] / len(winner_i) for seat_i in winner_i}
            pot_dict = {"potTotal": pot["amount"], "winners": winner_dict}
            action["pots"].append(pot_dict)
            */
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
}
