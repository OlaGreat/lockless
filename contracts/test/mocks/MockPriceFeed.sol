// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IPriceFeed} from "../../src/interfaces/IPriceFeed.sol";

/// @notice Follows Mezo's MUSD PriceFeed: returns BTC's USD price with 18 decimals and reverts
///         with the same message when its oracle is stale.
contract MockPriceFeed is IPriceFeed {
    uint256 public price;
    bool public stale;

    constructor(uint256 price_) {
        price = price_;
    }

    function setPrice(uint256 newPrice) external {
        price = newPrice;
    }

    function setStale(bool isStale) external {
        stale = isStale;
    }

    function fetchPrice() external view returns (uint256) {
        require(!stale, "PriceFeed: Oracle is stale.");
        return price;
    }
}
