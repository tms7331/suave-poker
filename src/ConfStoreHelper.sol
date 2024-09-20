// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "suave-std/suavelib/Suave.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract ConfStoreHelper {

    enum HandStage {
        SBPostStage,
        BBPostStage,
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
        Null,
        SBPost,
        BBPost,
        Bet,
        Fold,
        Call,
        Check
    }

    struct Pot {
        uint256 amount;
        uint8[] players;
    }

    struct Action {
        uint256 amount;
        ActionType act;
    }

    struct HandState {
        uint256 playerStack;
        uint256 playerBetStreet;
        HandStage handStage;
        ActionType lastActionType;
        uint256 lastActionAmount;
        bool transitionNextStreet;
        uint256 facingBet;
        uint256 lastRaise;
        uint256 button;
    }

    function _setPlrAddr(Suave.DataId plrDataId, address playerAddr) internal {
        Suave.confidentialStore(plrDataId, "plrAddrId", abi.encode(playerAddr));
    }

    function _getPlrAddr(
        Suave.DataId plrDataId
    ) internal returns (address playerAddr) {
        bytes memory val = Suave.confidentialRetrieve(plrDataId, "plrAddrId");
        return abi.decode(val, (address));
    }

    function _setPlrStack(Suave.DataId plrDataId, uint stack) internal {
        Suave.confidentialStore(plrDataId, "plrStackId", abi.encode(stack));
    }

    function _getPlrStack(
        Suave.DataId plrDataId
    ) internal returns (uint stack) {
        bytes memory val = Suave.confidentialRetrieve(plrDataId, "plrStackId");
        return abi.decode(val, (uint));
    }

    function _setPlrInHand(Suave.DataId plrDataId, bool inHand) internal {
        Suave.confidentialStore(plrDataId, "plrInHandId", abi.encode(inHand));
    }

    function _getPlrInHand(
        Suave.DataId plrDataId
    ) internal returns (bool inHand) {
        bytes memory val = Suave.confidentialRetrieve(plrDataId, "plrInHand");
        return abi.decode(val, (bool));
    }

    function _setPlrCards(Suave.DataId plrDataId, uint cards) internal {
        Suave.confidentialStore(plrDataId, "plrCards", abi.encode(cards));
    }

    function _getPlrCards(
        Suave.DataId plrDataId
    ) internal returns (uint cards) {
        bytes memory val = Suave.confidentialRetrieve(plrDataId, "plrCards");
        return abi.decode(val, (uint));
    }

    function _setPlrAutoPost(Suave.DataId plrDataId, bool autoPost) internal {
        Suave.confidentialStore(plrDataId, "plrAutoPost", abi.encode(autoPost));
    }

    function _getPlrAutoPost(
        Suave.DataId plrDataId
    ) internal returns (bool autoPost) {
        bytes memory val = Suave.confidentialRetrieve(plrDataId, "plrAutoPost");
        return abi.decode(val, (bool));
    }

    function _setPlrSittingOut(
        Suave.DataId plrDataId,
        bool sittingOut
    ) internal {
        Suave.confidentialStore(
            plrDataId,
            "plrSittingOut",
            abi.encode(sittingOut)
        );
    }

    function _getPlrSittingOut(
        Suave.DataId plrDataId
    ) internal returns (bool sittingOut) {
        bytes memory val = Suave.confidentialRetrieve(
            plrDataId,
            "plrSittingOut"
        );
        return abi.decode(val, (bool));
    }

    function _setPlrBetStreet(Suave.DataId plrDataId, uint betStreet) internal {
        Suave.confidentialStore(
            plrDataId,
            "plrBetStreet",
            abi.encode(betStreet)
        );
    }

    function _getPlrBetStreet(
        Suave.DataId plrDataId
    ) internal returns (uint betStreet) {
        bytes memory val = Suave.confidentialRetrieve(
            plrDataId,
            "plrBetStreet"
        );
        return abi.decode(val, (uint));
    }

    function _setPlrShowdownVal(
        Suave.DataId plrDataId,
        uint showdownVal
    ) internal {
        Suave.confidentialStore(
            plrDataId,
            "plrShowdownVal",
            abi.encode(showdownVal)
        );
    }

    function _getPlrShowdownVal(
        Suave.DataId plrDataId
    ) internal returns (uint showdownVal) {
        bytes memory val = Suave.confidentialRetrieve(
            plrDataId,
            "plrShowdownVal"
        );
        return abi.decode(val, (uint));
    }

    function _setPlrLastActionType(
        Suave.DataId plrDataId,
        ActionType lastActionType
    ) internal {
        Suave.confidentialStore(
            plrDataId,
            "plrLastActionType",
            abi.encode(lastActionType)
        );
    }

    function _getPlrLastActionType(
        Suave.DataId plrDataId
    ) internal returns (ActionType lastActionType) {
        bytes memory val = Suave.confidentialRetrieve(
            plrDataId,
            "plrLastActionType"
        );
        return abi.decode(val, (ActionType));
    }

    function _setPlrLastAmount(
        Suave.DataId plrDataId,
        uint lastAmount
    ) internal {
        Suave.confidentialStore(
            plrDataId,
            "plrLastAmount",
            abi.encode(lastAmount)
        );
    }

    function _getPlrLastAmount(
        Suave.DataId plrDataId
    ) internal returns (uint lastAmount) {
        bytes memory val = Suave.confidentialRetrieve(
            plrDataId,
            "plrLastAmount"
        );
        return abi.decode(val, (uint));
    }

    function _setTblHandStage(
        Suave.DataId tblDataId,
        HandStage handStage
    ) internal {
        Suave.confidentialStore(
            tblDataId,
            "tblHandState",
            abi.encode(handStage)
        );
    }

    function _getTblHandStage(
        Suave.DataId tblDataId
    ) internal returns (HandStage) {
        bytes memory val = Suave.confidentialRetrieve(
            tblDataId,
            "tblHandStage"
        );
        return abi.decode(val, (HandStage));
    }

    function _setTblButton(Suave.DataId tblDataId, uint8 button) internal {
        Suave.confidentialStore(tblDataId, "tblButton", abi.encode(button));
    }

    function _getTblButton(Suave.DataId tblDataId) internal returns (uint8) {
        bytes memory val = Suave.confidentialRetrieve(tblDataId, "tblButtonId");
        return abi.decode(val, (uint8));
    }

    function _setTblWhoseTurn(
        Suave.DataId tblDataId,
        uint8 whoseTurn
    ) internal {
        Suave.confidentialStore(
            tblDataId,
            "tblWhoseTurn",
            abi.encode(whoseTurn)
        );
    }

    function _getTblWhoseTurn(Suave.DataId tblDataId) internal returns (uint8) {
        bytes memory val = Suave.confidentialRetrieve(
            tblDataId,
            "tblWhoseTurn"
        );
        return abi.decode(val, (uint8));
    }

    function _setTblFacingBet(Suave.DataId tblDataId, uint facingBet) internal {
        Suave.confidentialStore(
            tblDataId,
            "tblFacingBetId",
            abi.encode(facingBet)
        );
    }

    function _getTblFacingBet(Suave.DataId tblDataId) internal returns (uint) {
        bytes memory val = Suave.confidentialRetrieve(
            tblDataId,
            "tblFacingBetId"
        );
        return abi.decode(val, (uint));
    }

    function _setTblLastRaise(Suave.DataId tblDataId, uint lastRaise) internal {
        Suave.confidentialStore(
            tblDataId,
            "tblLastRaiseId",
            abi.encode(lastRaise)
        );
    }

    function _getTblLastRaise(Suave.DataId tblDataId) internal returns (uint) {
        bytes memory val = Suave.confidentialRetrieve(
            tblDataId,
            "tblLastRaiseId"
        );
        return abi.decode(val, (uint));
    }

    function _setTblPotInitial(
        Suave.DataId tblDataId,
        uint potInitial
    ) internal {
        Suave.confidentialStore(tblDataId, "tblPotId", abi.encode(potInitial));
    }

    function _getTblPotInitial(Suave.DataId tblDataId) internal returns (uint) {
        bytes memory val = Suave.confidentialRetrieve(tblDataId, "tblPotId");
        return abi.decode(val, (uint));
    }

    function _setTblClosingActionCount(
        Suave.DataId tblDataId,
        int closingActionCount
    ) internal {
        Suave.confidentialStore(
            tblDataId,
            "tblClosingActionCountId",
            abi.encode(closingActionCount)
        );
    }

    function _getTblClosingActionCount(
        Suave.DataId tblDataId
    ) internal returns (uint) {
        bytes memory val = Suave.confidentialRetrieve(
            tblDataId,
            "tblClosingActionCountId"
        );
        return abi.decode(val, (uint));
    }

    function _setTblLastActionType(
        Suave.DataId tblDataId,
        ActionType lastActionType
    ) internal {
        Suave.confidentialStore(
            tblDataId,
            "tblHandStageId",
            abi.encode(lastActionType)
        );
    }

    function _getTblLastActionType(
        Suave.DataId tblDataId
    ) internal returns (ActionType) {
        bytes memory val = Suave.confidentialRetrieve(
            tblDataId,
            "tblHandStageId"
        );
        return abi.decode(val, (ActionType));
    }

    function _setTblLastAmount(
        Suave.DataId tblDataId,
        uint lastAmount
    ) internal {
        Suave.confidentialStore(
            tblDataId,
            "tblBettingOverId",
            abi.encode(lastAmount)
        );
    }

    function _getTblLastAmount(Suave.DataId tblDataId) internal returns (uint) {
        bytes memory val = Suave.confidentialRetrieve(
            tblDataId,
            "tblBettingOverId"
        );
        return abi.decode(val, (uint));
    }
    function _setTblPotsComplete(
        Suave.DataId tblDataId,
        uint potsComplete
    ) internal {
        Suave.confidentialStore(
            tblDataId,
            "tblPotsComplete",
            abi.encode(potsComplete)
        );
    }

    function _getTblPotsComplete(
        Suave.DataId tblDataId
    ) internal returns (uint) {
        bytes memory val = Suave.confidentialRetrieve(
            tblDataId,
            "tblPotsComplete"
        );
        return abi.decode(val, (uint));
    }

    function _setPlrHolecards(Suave.DataId tblDataId, uint8 playerI, uint8 hc0, uint8 hc1) internal {
        string memory key = string.concat("holecards", Strings.toString(playerI));
        Suave.confidentialStore(tblDataId, key, abi.encode(hc0, hc1));
    }

    function _getPlrHolecards(Suave.DataId tblDataId, uint8 playerI) internal returns (uint8, uint8) {
        string memory key = string.concat("holecards", Strings.toString(playerI));
        bytes memory val = Suave.confidentialRetrieve(tblDataId, key);
        return abi.decode(val, (uint8, uint8));
    }

    function _setFlop(Suave.DataId tblDataId, uint8 c0, uint8 c1, uint8 c2) internal {
        Suave.confidentialStore(tblDataId, "flop", abi.encode(c0, c1, c2));
    }

    function _getFlop(Suave.DataId tblDataId) internal returns (uint8, uint8, uint8) {
        bytes memory val = Suave.confidentialRetrieve(tblDataId, "flop");
        return abi.decode(val, (uint8, uint8, uint8));
    }

    function _setTurn(Suave.DataId tblDataId, uint8 c0) internal {
        Suave.confidentialStore(tblDataId, "turn", abi.encode(c0));
    }

    function _getTurn(Suave.DataId tblDataId) internal returns (uint8) {
        bytes memory val = Suave.confidentialRetrieve(tblDataId, "turn");
        return abi.decode(val, (uint8));
    }

    function _setRiver(Suave.DataId tblDataId, uint8 c0) internal {
        Suave.confidentialStore(tblDataId, "river", abi.encode(c0));
    }

    function _getRiver(Suave.DataId tblDataId) internal returns (uint8) {
        bytes memory val = Suave.confidentialRetrieve(tblDataId, "river");
        return abi.decode(val, (uint8));
    }

    function _setCardBits(Suave.DataId tblDataId, uint64 bits) internal {
        Suave.confidentialStore(tblDataId, "cardBits", abi.encode(bits));
    }

    function _getCardBits(Suave.DataId tblDataId) internal returns (uint64) {
        bytes memory val = Suave.confidentialRetrieve(tblDataId, "cardBits");
        return abi.decode(val, (uint64));
    }


    function _setHandId(Suave.DataId tblDataId, uint handId) internal {
        Suave.confidentialStore(tblDataId, "handId", abi.encode(handId));
    }

    function _getHandId(Suave.DataId tblDataId) internal returns (uint) {
        bytes memory val = Suave.confidentialRetrieve(tblDataId, "handId");
        return abi.decode(val, (uint));
    }

}
