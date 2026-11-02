// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVotingEscrow} from "../../src/interfaces/IVotingEscrow.sol";
import {IRewardsDistributor} from "../../src/interfaces/IRewardsDistributor.sol";
import {MockVotingEscrow} from "./MockVotingEscrow.sol";

/// @notice Follows the claim rules of Mezo's rebase distributor (tigris RewardsDistributor):
///         anyone can claim for any lock, a live or permanent lock gets the rebase added to it,
///         an expired lock gets it paid as MEZO to its owner, and claims revert until the new
///         week's period has been started. Error names match the real contract.
contract MockRewardsDistributor is IRewardsDistributor {
    MockVotingEscrow public immutable ve;
    IERC20 public immutable token;

    bool public periodStarted = true;
    mapping(uint256 tokenId => uint256) public claimable;

    error UpdatePeriod();

    constructor(MockVotingEscrow ve_) {
        ve = ve_;
        token = IERC20(ve_.token());
    }

    /// @dev Test hook: sets the rebase a lock can claim. Fund this contract with MEZO first.
    function setPending(uint256 tokenId, uint256 amount) external {
        claimable[tokenId] = amount;
    }

    /// @dev Test hook: simulates the start of a week before Mezo has started the new period.
    function setPeriodStarted(bool started) external {
        periodStarted = started;
    }

    function claim(uint256 tokenId) external returns (uint256 amount) {
        if (!periodStarted) revert UpdatePeriod();
        amount = claimable[tokenId];
        if (amount == 0) return 0;
        delete claimable[tokenId];
        _pay(tokenId, amount);
    }

    function _pay(uint256 tokenId, uint256 amount) private {
        if (_isExpired(ve.locked(tokenId))) {
            token.transfer(ve.ownerOf(tokenId), amount);
        } else {
            token.approve(address(ve), amount);
            ve.depositFor(tokenId, amount);
        }
    }

    function _isExpired(IVotingEscrow.LockedBalance memory lock) private view returns (bool) {
        return block.timestamp >= lock.end && !lock.isPermanent;
    }
}
