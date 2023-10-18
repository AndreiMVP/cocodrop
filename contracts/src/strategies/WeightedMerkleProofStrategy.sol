// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IStrategy } from "./IStrategy.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract WeightedMerkleProofStrategy is IStrategy {
    event Created(uint256 airdropId, bytes32 root);

    address public immutable cocodrop;
    mapping(uint256 => bytes32) public root;

    constructor(address _cocodrop) {
        cocodrop = _cocodrop;
    }

    function newAirdrop(uint256 _airdropId, bytes calldata _data) external {
        require(msg.sender == cocodrop, "only cocodrop");
        bytes32 _root = abi.decode(_data, (bytes32));
        root[_airdropId] = _root;

        emit Created(_airdropId, _root);
    }

    function checkEligibility(
        uint256 _airdropId,
        address _recipient,
        bytes calldata _data
    ) external view returns (bytes32, uint256) {
        (uint256 weight, bytes32[] memory _merkleProof) = abi.decode(_data, (uint256, bytes32[]));
        bytes32 leaf = keccak256(abi.encodePacked(_recipient, weight));

        // hash would not be unique if there are 2 of the same leafs in the tree
        // could have keccak256(_data) to solve this, but it would be too rare of a case for the extra cost
        return (leaf, MerkleProof.verify(_merkleProof, root[_airdropId], leaf) ? weight : 0);
    }
}
