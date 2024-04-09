// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "suave-std/suavelib/Suave.sol";

library RNG {
    function storeSeed(Suave.DataId ref, uint seed) internal {
        Suave.confidentialStore(ref, "suaverng:v0:seed", abi.encode(seed));
    }

    function getSeed(Suave.DataId ref) internal returns (uint seed) {
        bytes memory val = Suave.confidentialRetrieve(ref, "suaverng:v0:seed");
        seed = abi.decode(val, (uint));
    }

    function generateRandomNumber(
        Suave.DataId ref,
        uint256 maxValue
    ) internal returns (uint256) {
        uint256 seed = getSeed(ref);
        // By combining seed with some other value and hashing it, we get a random number
        // And it should not be possible to reverse engineeer the seed because it changes each call?
        uint256 randomNumber = uint256(
            keccak256(abi.encodePacked(seed, msg.sender))
        );

        // Keep updating seed for next random number generation
        uint newSeed = uint256(keccak256(abi.encodePacked(seed)));
        storeSeed(ref, newSeed);
        return randomNumber % maxValue;
    }

    function addNoise(Suave.DataId ref, uint256 noise) internal {
        uint256 seed = getSeed(ref);
        uint newSeed = uint256(keccak256(abi.encodePacked(seed, noise)));
        storeSeed(ref, newSeed);
    }
}
