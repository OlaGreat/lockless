// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice The part of LocklessVault the reward harvester uses to compound MEZO.
interface ILocklessVault {
    function mezo() external view returns (IERC20);

    function deposit(uint256 amount, address receiver) external;
}
