// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IStrategy {
    /** A new airdrop was created using this strategy
     *  Cocodrop will call this function with relevant extra data given by the creator of the airdrop
     */
    function newAirdrop(uint256 airdropId, bytes calldata data) external;

    /** Eligibility check - given recipient and relevant extradata
     *  Cocodrop will call this function when an user tries to redeem
     *  @return claimHash - unique value per properties of the claim (e.g. ERC721 tokenId)
     *  @return weight - value to multiply airdrop base amount with to calculate amount to be transfered to recipient
     *             If not eligible, function can return weight 0, or revert (thus having the revert string show up),
     *             depending on airdrop's creator preference
     */
    function checkEligibility(
        uint256 airdropId,
        address recipient,
        bytes calldata data
    ) external view returns (bytes32 claimHash, uint256 weight);
}
