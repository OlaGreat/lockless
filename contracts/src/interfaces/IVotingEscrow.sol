// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice The subset of Mezo's veMEZO contract that Lockless uses.
interface IVotingEscrow {
    struct LockedBalance {
        int128 amount;
        uint256 end;
        bool isPermanent;
        uint256 boost;
    }

    function token() external view returns (address);

    function createLock(uint256 value, uint256 lockDuration) external returns (uint256 tokenId);

    function increaseAmount(uint256 tokenId, uint256 value) external;

    function lockPermanent(uint256 tokenId) external;

    function unlockPermanent(uint256 tokenId) external;

    function merge(uint256 from, uint256 to) external;

    function locked(uint256 tokenId) external view returns (LockedBalance memory);

    function voted(uint256 tokenId) external view returns (bool);

    function ownerOf(uint256 tokenId) external view returns (address);

    function transferFrom(address from, address to, uint256 tokenId) external;
}
