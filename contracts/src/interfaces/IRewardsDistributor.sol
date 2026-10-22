// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Mezo's veMEZO rebase distributor. Claiming adds the rebase to a permanent lock.
interface IRewardsDistributor {
    function claim(uint256 tokenId) external returns (uint256 amount);
}
