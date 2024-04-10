// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "suave-std/suavelib/Suave.sol";

library RNG {
    function storeSeed(Suave.DataId ref, bytes memory seed) internal {
        Suave.confidentialStore(ref, "suaverng:v0:seed", seed);
    }

    function getSeed(Suave.DataId ref) internal returns (bytes memory seed) {
        seed = Suave.confidentialRetrieve(ref, "suaverng:v0:seed");
    }

    function generateRandomNumber(
        Suave.DataId ref,
        uint maxValue
    ) internal returns (uint) {
        bytes memory seed = getSeed(ref);
        // By combining seed with some other value and hashing it, we get a random number
        // and it should not be possible to reverse engineeer the seed because it changes each call?
        uint randomNumber = uint256(
            keccak256(abi.encodePacked(seed, msg.sender))
        );

        // Keep updating seed for next random number generation
        bytes32 newSeed = keccak256(seed);
        storeSeed(ref, abi.encode(newSeed));
        return randomNumber % maxValue;
    }

    function addNoise(Suave.DataId ref, bytes memory noise) internal {
        bytes memory seed = getSeed(ref);
        bytes32 newSeed = keccak256(abi.encodePacked(seed, noise));
        storeSeed(ref, abi.encode(newSeed));
    }
}
