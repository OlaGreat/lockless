// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice The subset of a Mezo boost gauge incentive contract that Lockless reads.
interface IReward {
    function rewardsListLength() external view returns (uint256);

    function rewards(uint256 index) external view returns (address);
}
