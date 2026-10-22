// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRewardsDistributor} from "../../src/interfaces/IRewardsDistributor.sol";
import {MockVotingEscrow} from "./MockVotingEscrow.sol";

/// @notice Adds a preset rebase to a lock when claimed, like Mezo's rebase distributor does
///         for permanent locks. Anyone can claim for any lock.
contract MockRewardsDistributor is IRewardsDistributor {
    MockVotingEscrow public immutable ve;
    IERC20 public immutable token;

    mapping(uint256 tokenId => uint256) public pending;

    constructor(MockVotingEscrow ve_) {
        ve = ve_;
        token = IERC20(ve_.token());
    }

    function setPending(uint256 tokenId, uint256 amount) external {
        pending[tokenId] = amount;
    }

    function claim(uint256 tokenId) external returns (uint256 amount) {
        amount = pending[tokenId];
        if (amount == 0) return 0;
        delete pending[tokenId];
        token.approve(address(ve), amount);
        ve.depositFor(tokenId, amount);
    }
}
