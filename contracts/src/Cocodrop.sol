// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IStrategy } from "./strategies/IStrategy.sol";

contract Cocodrop {
    struct Airdrop {
        bool paused; // whether airdrop is paused; when true: can't redeem and can withdraw funds
        bool delegatedRedeem; // whether anyone can redeem airdrop for other eligible users, calling `redeemMany`
        address owner; // owner of airdrop that can edit airdrop and withdraw funds
        IERC20 token; // erc20 to be airdropped
        uint256 baseAmount; // base amount before multiplying with weights returned by strategies checks
        uint256 balance; // current airdrop funds; anyone can increase at any time
        IStrategy[] strategies; // list of IStrategy contracts to check for eligibility, returning an unique claim hash and weight
    }

    event Created(
        uint256 indexed airdropId,
        address owner,
        IERC20 token,
        IStrategy[] strategies,
        bytes[] strategiesData
    );
    event Edited(uint256 indexed airdropId, uint256 baseAmount, bool delegatedRedeem, string info);
    event Paused(uint256 indexed airdropId);
    event Unpaused(uint256 indexed airdropId);
    event Funded(uint256 indexed airdropId, uint256 amount);
    event FundsWithdrawn(uint256 indexed airdropId);
    event Redeemed(uint256 indexed airdropId, address redeemer, uint256 amount);

    /// @dev list of created airdrops; airdrops[airdropId]
    Airdrop[] public airdrops;

    /// @dev whether claimHash has been redeemed for an airdrop [airdropId][claimHash]
    mapping(uint256 => mapping(bytes32 => bool)) public redeemed;

    /** Pause airdrop. AIRDROP OWNER ONLY
     *  @param _airdropId id of the airdrop to pause
     */
    function pauseAirdrop(uint256 _airdropId) external {
        require(msg.sender == airdrops[_airdropId].owner, "only owner");

        airdrops[_airdropId].paused = true;

        emit Paused(_airdropId);
    }

    /** Unpause airdrop. AIRDROP OWNER ONLY
     *  @param _airdropId id of the airdrop to unpause
     */
    function unpauseAirdrop(uint256 _airdropId) external {
        require(msg.sender == airdrops[_airdropId].owner, "only owner");

        airdrops[_airdropId].paused = false;

        emit Unpaused(_airdropId);
    }

    /** Edit airdrop. AIRDROP OWNER ONLY
     *  @param _airdropId id of the airdrop to edit
     *  @param _delegatedRedeem new delegatedRedeem value
     *  @param _baseAmount new baseAmount value
     *  @param _info new airdrop info uri
     */
    function editAirdrop(
        uint256 _airdropId,
        bool _delegatedRedeem,
        uint256 _baseAmount,
        string calldata _info
    ) external {
        Airdrop storage airdrop = airdrops[_airdropId];
        require(msg.sender == airdrop.owner, "only owner");

        airdrop.delegatedRedeem = _delegatedRedeem;
        airdrop.baseAmount = _baseAmount;

        // info uri could be empty for gas saving, in which case it shouldn't be considered updated
        emit Edited(_airdropId, _baseAmount, _delegatedRedeem, _info);
    }

    /** Fund an airdrop.
     *  @param _airdropId id of the airdrop to fund
     *  @param _amount amount of corresonding tokens to fund
     */
    function fund(uint256 _airdropId, uint256 _amount) external {
        // allowance must be given before transfer
        require(airdrops[_airdropId].token.transferFrom(msg.sender, address(this), _amount), "transfer failed");

        airdrops[_airdropId].balance += _amount;

        emit Funded(_airdropId, _amount);
    }

    /** Withdraw all the remaining funds of the airdrop. AIRDROP OWNER ONLY
     *  @param _airdropId id of the airdrop to withdraw from
     */
    function withdraw(uint256 _airdropId) external {
        Airdrop storage airdrop = airdrops[_airdropId];
        require(msg.sender == airdrop.owner, "only owner");
        require(airdrop.paused, "only when paused");

        uint256 toWithdraw = airdrop.balance;
        airdrop.balance = 0;

        airdrop.token.transfer(msg.sender, toWithdraw);

        emit FundsWithdrawn(_airdropId);
    }

    /** Sender creates an airdrop. Becomes owner of the airdrop.
     *  @param _token erc20 to be used for the airdrop
     *  @param _baseAmount base amount before multiplying with weights returned by strategies checks
     *  @param _delegatedRedeem whether anyone can redeem airdrop for other eligible users
     *  @param _initialBalance balance of the corresponding token the airdrop starts with
     *  @param _strategies list of IStrategy contracts that would allow checking for eligibility
     *  @param _strategiesData extradata to pass per strategy contract when new airdrop was created; up to strategy contracts to emit relevant events
     *  @param _info airdrop info uri
     */
    function create(
        IERC20 _token,
        uint256 _baseAmount,
        bool _delegatedRedeem,
        uint256 _initialBalance,
        IStrategy[] calldata _strategies,
        bytes[] calldata _strategiesData,
        string calldata _info
    ) external {
        // allowance must be given before transfer
        require(_token.transferFrom(msg.sender, address(this), _initialBalance), "transfer failed");

        // the id of the airdrop is the list length before adding it; thus first airdrop has id 0
        uint256 airdropId = airdrops.length;

        Airdrop storage airdrop = airdrops.push();
        airdrop.owner = msg.sender;
        airdrop.token = _token;
        airdrop.baseAmount = _baseAmount;
        airdrop.delegatedRedeem = _delegatedRedeem;
        airdrop.balance = _initialBalance;
        airdrop.strategies = _strategies;

        // notify strategies airdrop has been created
        for (uint256 i; i < _strategies.length; i++) _strategies[i].newAirdrop(airdropId, _strategiesData[i]);

        emit Created(airdropId, msg.sender, _token, _strategies, _strategiesData);
        emit Edited(airdropId, _baseAmount, _delegatedRedeem, _info);
        emit Funded(airdropId, _initialBalance);
    }

    /** Sender redeems an airdrop. Passes relevant extra data for each of the corresponding airdrop's strategies
     *  @param _airdropId id of the airdrop to redeem from
     *  @param _data list of extradata to use for the stategies call check; it's length should be same as the number of airdrop's strategies
     */
    function redeem(uint256 _airdropId, bytes[] calldata _data) public {
        Airdrop storage airdrop = airdrops[_airdropId];

        require(!airdrop.paused, "airdrop paused");

        bytes32 claimHash;
        uint256 toRedeem = airdrop.baseAmount;
        IStrategy[] memory cachedStrategies = airdrop.strategies;
        for (uint256 i = 0; i < cachedStrategies.length; i++) {
            (bytes32 strategyGivenHash, uint256 weight) = cachedStrategies[i].checkEligibility(
                _airdropId,
                msg.sender,
                _data[i]
            );

            // the combinations of hashes returned by the strategies would result in an unique claim hash
            // it's for the creator of the airdrop to make sure the intended valid combination is stored
            claimHash = keccak256(abi.encode(claimHash, strategyGivenHash));

            // weight could be 0, which would lead in the user not be eligible for the airdrop
            // or it could be 1 which would result in a weight not affecting the final amount to redeem
            // note: case in which all strategies return weight 1 would result in user being able to withdraw `baseAmount` tokens;
            //       it's up to the owner to make sure it doesn't happen
            toRedeem *= weight;
        }

        // a strategy can fail via revert, or it can return weight 0 which would make airdrop claim not valid
        // ultimately both cases should be handled by frontend
        require(toRedeem > 0, "not eligible");
        require(!redeemed[_airdropId][claimHash], "already redeemed");

        redeemed[_airdropId][claimHash] = true;

        // would revert in case of insufficient balance left
        airdrop.balance -= toRedeem;

        airdrop.token.transfer(msg.sender, toRedeem);

        emit Redeemed(_airdropId, msg.sender, toRedeem);
    }

    /** Redeem an airdrop for a list of recipients. Same comments apply as `redeem` function.
     *  @param _airdropId id of the airdrop to redeem from
     *  @param _recipients list of recipients to redeem for
     *  @param _data list of extradata corresponding to each recipient to use for the stategies call check
     */
    function redeemMany(uint256 _airdropId, address[] calldata _recipients, bytes[][] calldata _data) public {
        Airdrop storage airdrop = airdrops[_airdropId];

        require(!airdrop.paused, "airdrop paused");
        require(airdrop.delegatedRedeem, "no permission");

        uint256 cachedNbRecipients = _recipients.length;
        IStrategy[] memory cachedStrategies = airdrop.strategies;
        uint256 cachedNbStrategies = cachedStrategies.length;
        for (uint256 i = 0; i < cachedNbRecipients; i++) {
            address recipient = _recipients[i];
            bytes32 claimHash;
            uint256 toRedeem = airdrop.baseAmount;
            for (uint256 j = 0; j < cachedNbStrategies; j++) {
                (bytes32 strategyGivenHash, uint256 weight) = cachedStrategies[j].checkEligibility(
                    _airdropId,
                    recipient,
                    _data[i][j]
                );

                claimHash = keccak256(abi.encode(claimHash, strategyGivenHash));

                toRedeem *= weight;
            }

            require(toRedeem > 0, "not eligible");
            require(!redeemed[_airdropId][claimHash], "already redeemed");

            redeemed[_airdropId][claimHash] = true;
            airdrop.balance -= toRedeem;

            airdrop.token.transfer(recipient, toRedeem);

            emit Redeemed(_airdropId, recipient, toRedeem);
        }
    }
}
