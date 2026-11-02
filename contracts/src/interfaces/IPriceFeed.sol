// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Mezo's MUSD price feed. Returns BTC's USD price with 18 decimals and reverts when the
///         underlying oracle is stale.
interface IPriceFeed {
    function fetchPrice() external view returns (uint256);
}
