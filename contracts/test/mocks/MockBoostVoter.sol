// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IBoostVoter} from "../../src/interfaces/IBoostVoter.sol";
import {MockVotingEscrow} from "./MockVotingEscrow.sol";
import {MockBribe} from "./MockBribe.sol";

/// @notice Follows the boost voter rules Lockless relies on: one vote or reset per lock per
///         epoch, owner or approved callers only, and incentives paid to the lock owner.
contract MockBoostVoter is IBoostVoter {
    uint256 private constant WEEK = 1 weeks;

    MockVotingEscrow public immutable ve;

    mapping(uint256 tokenId => uint256) public lastVoted;
    mapping(uint256 tokenId => uint256) public pokeCount;
    mapping(uint256 tokenId => address[]) private _gauges;
    mapping(uint256 tokenId => uint256[]) private _weights;

    error NotApprovedOrOwner();
    error AlreadyVotedOrDeposited();

    modifier onlyApprovedOrOwner(uint256 tokenId) {
        if (!ve.isApprovedOrOwner(msg.sender, tokenId)) revert NotApprovedOrOwner();
        _;
    }

    modifier onlyNewEpoch(uint256 tokenId) {
        if ((block.timestamp / WEEK) * WEEK <= lastVoted[tokenId]) {
            revert AlreadyVotedOrDeposited();
        }
        _;
    }

    constructor(MockVotingEscrow ve_) {
        ve = ve_;
    }

    function vote(uint256 tokenId, address[] calldata gauges, uint256[] calldata weights)
        external
        onlyNewEpoch(tokenId)
        onlyApprovedOrOwner(tokenId)
    {
        lastVoted[tokenId] = block.timestamp;
        _gauges[tokenId] = gauges;
        _weights[tokenId] = weights;
        ve.voting(tokenId, true);
    }

    function reset(uint256 tokenId) external onlyNewEpoch(tokenId) onlyApprovedOrOwner(tokenId) {
        delete _gauges[tokenId];
        delete _weights[tokenId];
        ve.voting(tokenId, false);
    }

    function poke(uint256 tokenId) external {
        pokeCount[tokenId] += 1;
    }

    function claimBribes(address[] calldata bribes, address[][] calldata tokens, uint256 tokenId)
        external
        onlyApprovedOrOwner(tokenId)
    {
        for (uint256 i = 0; i < bribes.length; i++) {
            MockBribe(bribes[i]).getReward(tokenId, tokens[i]);
        }
    }

    function votedGauges(uint256 tokenId) external view returns (address[] memory) {
        return _gauges[tokenId];
    }

    function votedWeights(uint256 tokenId) external view returns (uint256[] memory) {
        return _weights[tokenId];
    }
}
