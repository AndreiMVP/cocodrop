// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IStrategy } from "./IStrategy.sol";

interface IProofOfHumanity {
    function humanityOf(address _account) external view returns (bytes20);
}

contract ProofOfHumanityStrategy is IStrategy {
    bytes20 internal constant NULL_POHID = 0x0;

    IProofOfHumanity public immutable poh;

    constructor(address _poh) {
        poh = IProofOfHumanity(_poh);
    }

    function newAirdrop(uint256, bytes calldata) external pure {
        return;
    }

    function checkEligibility(uint256, address _recipient, bytes calldata) external view returns (bytes32, uint) {
        bytes20 pohId = poh.humanityOf(_recipient);
        return (pohId, pohId == NULL_POHID ? 0 : 1);
    }
}
