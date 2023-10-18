// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IStrategy } from "./IStrategy.sol";

interface IProofOfHumanity {
    function humanityOf(address _account) external view returns (bytes20);
}

contract WeightedProofOfHumanityStrategy is IStrategy {
    bytes20 internal constant NULL_POHID = 0x0;

    event Created(uint256 airdropId, uint256 weight);

    IProofOfHumanity public immutable poh;
    address public immutable cocodrop;
    mapping(uint256 => uint256) public weight;

    constructor(address _cocodrop, address _poh) {
        poh = IProofOfHumanity(_poh);
        cocodrop = _cocodrop;
    }

    function newAirdrop(uint256 _airdropId, bytes calldata _data) external {
        require(msg.sender == cocodrop, "only cocodrop");
        uint256 _weight = abi.decode(_data, (uint256));
        weight[_airdropId] = _weight;

        emit Created(_airdropId, _weight);
    }

    function checkEligibility(
        uint256 _airdropId,
        address _recipient,
        bytes calldata
    ) external view returns (bytes32, uint) {
        bytes20 pohId = poh.humanityOf(_recipient);
        return (pohId, pohId == NULL_POHID ? 0 : weight[_airdropId]);
    }
}
