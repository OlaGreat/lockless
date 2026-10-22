// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRouter} from "../../src/interfaces/IRouter.sol";

/// @notice Swaps at a fixed price from its own pre-funded balance and enforces the minimum
///         output, like the Mezo Pools router.
contract MockRouter is IRouter {
    uint256 public immutable outputPerInput;

    error InsufficientOutputAmount();

    constructor(uint256 outputPerInput_) {
        outputPerInput = outputPerInput_;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256
    ) external returns (uint256[] memory amounts) {
        uint256 amountOut = amountIn * outputPerInput;
        if (amountOut < amountOutMin) revert InsufficientOutputAmount();

        IERC20(routes[0].from).transferFrom(msg.sender, address(this), amountIn);
        IERC20(routes[routes.length - 1].to).transfer(to, amountOut);

        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
    }
}
