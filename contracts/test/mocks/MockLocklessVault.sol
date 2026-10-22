// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILocklessVault} from "../../src/interfaces/ILocklessVault.sol";
import {MockERC20} from "./MockERC20.sol";

/// @notice Takes MEZO and mints its receipt token 1:1, like LocklessVault.deposit does.
contract MockLocklessVault is ILocklessVault {
    IERC20 public immutable mezo;
    MockERC20 public immutable receipt;

    constructor(IERC20 mezo_, MockERC20 receipt_) {
        mezo = mezo_;
        receipt = receipt_;
    }

    function deposit(uint256 amount, address receiver) external {
        mezo.transferFrom(msg.sender, address(this), amount);
        receipt.mint(receiver, amount);
    }
}
