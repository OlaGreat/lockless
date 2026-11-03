// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Stands in for Mezo's MEZO and BTC token precompiles on a fork, where their own code
///         cannot run. Matches the interface Mezo's contracts call (tigris IMEZO), where `mint`
///         returns a bool. Balances start empty because the precompiles keep theirs outside EVM
///         storage.
contract PrecompileTokenStandIn is ERC20 {
    constructor() ERC20("Precompile stand-in", "STANDIN") {}

    function mint(address to, uint256 amount) external returns (bool) {
        _mint(to, amount);
        return true;
    }
}
