// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice The subset of Mezo's veMEZO boost voter that Lockless uses.
interface IBoostVoter {
    function vote(uint256 tokenId, address[] calldata gauges, uint256[] calldata weights) external;

    function reset(uint256 tokenId) external;

    function poke(uint256 tokenId) external;

    function claimBribes(address[] calldata bribes, address[][] calldata tokens, uint256 tokenId)
        external;

    function lastVoted(uint256 tokenId) external view returns (uint256);
}
