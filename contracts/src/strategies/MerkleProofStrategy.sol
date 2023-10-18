// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IStrategy } from "./IStrategy.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleProofStrategy is IStrategy {
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
        bytes32[] memory _merkleProof = abi.decode(_data, (bytes32[]));

        require(MerkleProof.verify(_merkleProof, root[_airdropId], bytes20(_recipient)), "invalid proof");

        // hash would not be unique if recipient is 2 times in the tree
        return (bytes20(_recipient), 1);
    }
}
