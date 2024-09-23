// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "suave-std/suavelib/Suave.sol";

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
        bool[] players;
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
        Suave.confidentialStore(plrDataId, "plrAddr", abi.encode(playerAddr));
    }

    function _getPlrAddr(
        Suave.DataId plrDataId
    ) internal returns (address playerAddr) {
        bytes memory val = Suave.confidentialRetrieve(plrDataId, "plrAddr");
        return abi.decode(val, (address));
    }

    function _setPlrStack(Suave.DataId plrDataId, uint stack) internal {
        Suave.confidentialStore(plrDataId, "plrStack", abi.encode(stack));
    }

    function _getPlrStack(
        Suave.DataId plrDataId
    ) internal returns (uint stack) {
        bytes memory val = Suave.confidentialRetrieve(plrDataId, "plrStack");
        return abi.decode(val, (uint));
    }

    function _setPlrInHand(Suave.DataId plrDataId, bool inHand) internal {
        Suave.confidentialStore(plrDataId, "plrInHand", abi.encode(inHand));
    }

    function _getPlrInHand(
        Suave.DataId plrDataId
    ) internal returns (bool inHand) {
        bytes memory val = Suave.confidentialRetrieve(plrDataId, "plrInHand");
        return abi.decode(val, (bool));
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

    function _setPlrHolecards(
        Suave.DataId plrDataId,
        uint8 hc0,
        uint8 hc1
    ) internal {
        // Remember - tblDataId is unique to each player
        Suave.confidentialStore(
            plrDataId,
            "plrHolecards",
            abi.encode(hc0, hc1)
        );
    }

    function _getPlrHolecards(
        Suave.DataId plrDataId
    ) internal returns (uint8, uint8) {
        bytes memory val = Suave.confidentialRetrieve(
            plrDataId,
            "plrHolecards"
        );
        return abi.decode(val, (uint8, uint8));
    }

    function _setTblHandStage(
        Suave.DataId tblDataId,
        HandStage handStage
    ) internal {
        Suave.confidentialStore(
            tblDataId,
            "tblHandStage",
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
        bytes memory val = Suave.confidentialRetrieve(tblDataId, "tblButton");
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
            "tblFacingBet",
            abi.encode(facingBet)
        );
    }

    function _getTblFacingBet(Suave.DataId tblDataId) internal returns (uint) {
        bytes memory val = Suave.confidentialRetrieve(
            tblDataId,
            "tblFacingBet"
        );
        return abi.decode(val, (uint));
    }

    function _setTblLastRaise(Suave.DataId tblDataId, uint lastRaise) internal {
        Suave.confidentialStore(
            tblDataId,
            "tblLastRaise",
            abi.encode(lastRaise)
        );
    }

    function _getTblLastRaise(Suave.DataId tblDataId) internal returns (uint) {
        bytes memory val = Suave.confidentialRetrieve(
            tblDataId,
            "tblLastRaise"
        );
        return abi.decode(val, (uint));
    }

    function _setTblPotInitial(
        Suave.DataId tblDataId,
        uint potInitial
    ) internal {
        Suave.confidentialStore(tblDataId, "tblPot", abi.encode(potInitial));
    }

    function _getTblPotInitial(Suave.DataId tblDataId) internal returns (uint) {
        bytes memory val = Suave.confidentialRetrieve(tblDataId, "tblPot");
        return abi.decode(val, (uint));
    }

    function _setTblClosingActionCount(
        Suave.DataId tblDataId,
        int closingActionCount
    ) internal {
        Suave.confidentialStore(
            tblDataId,
            "tblClosingActionCount",
            abi.encode(closingActionCount)
        );
    }

    function _getTblClosingActionCount(
        Suave.DataId tblDataId
    ) internal returns (int) {
        bytes memory val = Suave.confidentialRetrieve(
            tblDataId,
            "tblClosingActionCount"
        );
        return abi.decode(val, (int));
    }

    function _setTblLastActionType(
        Suave.DataId tblDataId,
        ActionType lastActionType
    ) internal {
        Suave.confidentialStore(
            tblDataId,
            "tblLastActionType",
            abi.encode(lastActionType)
        );
    }

    function _getTblLastActionType(
        Suave.DataId tblDataId
    ) internal returns (ActionType) {
        bytes memory val = Suave.confidentialRetrieve(
            tblDataId,
            "tblLastActionType"
        );
        return abi.decode(val, (ActionType));
    }

    function _setTblLastAmount(
        Suave.DataId tblDataId,
        uint lastAmount
    ) internal {
        Suave.confidentialStore(
            tblDataId,
            "tblLastAmount",
            abi.encode(lastAmount)
        );
    }

    function _getTblLastAmount(Suave.DataId tblDataId) internal returns (uint) {
        bytes memory val = Suave.confidentialRetrieve(
            tblDataId,
            "tblLastAmount"
        );
        return abi.decode(val, (uint));
    }

    function _setTblPotsComplete(
        Suave.DataId tblDataId,
        Pot memory pot
    ) internal {
        Suave.confidentialStore(tblDataId, "tblPotsComplete", abi.encode(pot));
    }

    function _getTblPotsComplete(
        Suave.DataId tblDataId
    ) internal returns (Pot memory) {
        bytes memory val = Suave.confidentialRetrieve(
            tblDataId,
            "tblPotsComplete"
        );
        return abi.decode(val, (Pot));
    }

    function _setTblFlop(
        Suave.DataId tblDataId,
        uint8 c0,
        uint8 c1,
        uint8 c2
    ) internal {
        Suave.confidentialStore(tblDataId, "tblFlop", abi.encode(c0, c1, c2));
    }

    function _getTblFlop(
        Suave.DataId tblDataId
    ) internal returns (uint8, uint8, uint8) {
        bytes memory val = Suave.confidentialRetrieve(tblDataId, "tblFlop");
        return abi.decode(val, (uint8, uint8, uint8));
    }

    function _setTblTurn(Suave.DataId tblDataId, uint8 c0) internal {
        Suave.confidentialStore(tblDataId, "tblTurn", abi.encode(c0));
    }

    function _getTblTurn(Suave.DataId tblDataId) internal returns (uint8) {
        bytes memory val = Suave.confidentialRetrieve(tblDataId, "tblTurn");
        return abi.decode(val, (uint8));
    }

    function _setTblRiver(Suave.DataId tblDataId, uint8 c0) internal {
        Suave.confidentialStore(tblDataId, "tblRiver", abi.encode(c0));
    }

    function _getTblRiver(Suave.DataId tblDataId) internal returns (uint8) {
        bytes memory val = Suave.confidentialRetrieve(tblDataId, "tblRiver");
        return abi.decode(val, (uint8));
    }

    function _setCardBits(Suave.DataId rngDataId, uint64 bits) internal {
        Suave.confidentialStore(rngDataId, "rngCardBits", abi.encode(bits));
    }

    function _getCardBits(Suave.DataId rngDataId) internal returns (uint64) {
        bytes memory val = Suave.confidentialRetrieve(rngDataId, "rngCardBits");
        return abi.decode(val, (uint64));
    }

    function _setHandId(Suave.DataId tblDataId, uint handId) internal {
        Suave.confidentialStore(tblDataId, "tblHandId", abi.encode(handId));
    }

    function _getHandId(Suave.DataId tblDataId) internal returns (uint) {
        bytes memory val = Suave.confidentialRetrieve(tblDataId, "tblHandId");
        return abi.decode(val, (uint));
    }
}
