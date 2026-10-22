// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title StMEZO
/// @notice Liquid receipt for MEZO held in the Lockless permanent lock.
/// @dev Each stMEZO is backed by one MEZO inside the vault's veMEZO lock. Only the vault mints.
contract StMEZO is ERC20, ERC20Permit {
    string private constant NAME = "Lockless Staked MEZO";
    string private constant SYMBOL = "stMEZO";

    address public immutable vault;

    error OnlyVault();
    error ZeroVault();

    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    constructor(address vault_) ERC20(NAME, SYMBOL) ERC20Permit(NAME) {
        if (vault_ == address(0)) revert ZeroVault();
        vault = vault_;
    }

    /// @notice Mints stMEZO for MEZO that the vault has just locked.
    function mint(address to, uint256 amount) external onlyVault {
        _mint(to, amount);
    }
}
