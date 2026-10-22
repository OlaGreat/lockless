// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVotingEscrow} from "../../src/interfaces/IVotingEscrow.sol";

/// @notice Pays its whole balance of each requested token to the owner of the lock, like a
///         boost gauge incentive contract does after an epoch ends.
contract MockBribe {
    IVotingEscrow public immutable ve;

    constructor(IVotingEscrow ve_) {
        ve = ve_;
    }

    function getReward(uint256 tokenId, address[] calldata tokens) external {
        address owner = ve.ownerOf(tokenId);
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20 token = IERC20(tokens[i]);
            token.transfer(owner, token.balanceOf(address(this)));
        }
    }
}
