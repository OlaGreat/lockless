// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MockVotingEscrow} from "./MockVotingEscrow.sol";
import {MockERC20} from "./MockERC20.sol";

/// @notice Follows the rules of Mezo's incentive contract (tigris VotingReward and Reward) that
///         Lockless relies on: each lock earns its own amount per token, only the lock's owner,
///         an approved address or the voter may claim, and payment goes to the lock's current
///         owner. A burned lock has no owner, so its rewards can no longer be paid.
contract MockBribe {
    MockVotingEscrow public immutable ve;
    address public immutable voter;

    address[] public rewards;
    mapping(address token => bool) public isReward;
    mapping(uint256 tokenId => mapping(address token => uint256)) private _earned;

    error NotAuthorized();

    constructor(MockVotingEscrow ve_, address voter_) {
        ve = ve_;
        voter = voter_;
    }

    /// @dev Test hook: funds this contract and credits the amount to one lock.
    function addEarned(address token, uint256 tokenId, uint256 amount) external {
        _registerReward(token);
        MockERC20(token).mint(address(this), amount);
        _earned[tokenId][token] += amount;
    }

    function getReward(uint256 tokenId, address[] calldata tokens) external {
        if (!ve.isApprovedOrOwner(msg.sender, tokenId) && msg.sender != voter) {
            revert NotAuthorized();
        }
        address owner = ve.ownerOf(tokenId);
        for (uint256 i = 0; i < tokens.length; i++) {
            _pay(owner, tokenId, tokens[i]);
        }
    }

    function earned(address token, uint256 tokenId) external view returns (uint256) {
        return _earned[tokenId][token];
    }

    function rewardsListLength() external view returns (uint256) {
        return rewards.length;
    }

    function _pay(address owner, uint256 tokenId, address token) private {
        uint256 amount = _earned[tokenId][token];
        if (amount == 0) return;
        _earned[tokenId][token] = 0;
        MockERC20(token).transfer(owner, amount);
    }

    function _registerReward(address token) private {
        if (isReward[token]) return;
        isReward[token] = true;
        rewards.push(token);
    }
}
