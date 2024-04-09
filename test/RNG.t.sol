// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "suave-std/Test.sol";
import "suave-std/suavelib/Suave.sol";
import "forge-std/console.sol";
import {RNG} from "../src/RNG.sol";

contract TestForge is Test, SuaveEnabled {
    function deployRNG() internal returns (Suave.DataId) {
        // Initializing library
        // No contract, just test library functionality
        address[] memory addressList;
        addressList = new address[](1);
        addressList[0] = 0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829;
        // For the array
        Suave.DataRecord memory record1 = Suave.newDataRecord(
            0,
            addressList,
            addressList,
            "suaveLOB:v0:dataId"
        );

        // Part of initialization - have to initialize seed to some value
        RNG.storeSeed(record1.id, 123456);

        return record1.id;
    }

    function testGetRandomNums() public {
        Suave.DataId ref = deployRNG();
        uint256 maxValue = 52;

        // Simulate adding two players' random noise
        // Changing either one should result in output changing
        RNG.addNoise(ref, 383833);
        RNG.addNoise(ref, 567890);

        for (int i = 0; i < 52; i++) {
            uint256 randNum = RNG.generateRandomNumber(ref, maxValue);
            console.log(randNum);
        }
    }
}
