// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title StMEZOStaking
/// @notice Stake stMEZO to earn the rewards Lockless harvests, streamed over each epoch.
contract StMEZOStaking is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_REWARD_TOKENS = 8;

    struct RewardData {
        address distributor;
        uint256 duration;
        uint256 periodFinish;
        uint256 rate;
        uint256 lastUpdate;
        uint256 rewardPerTokenStored;
    }

    IERC20 public immutable stakingToken;

    uint256 public totalStaked;
    mapping(address account => uint256) public balanceOf;

    address[] public rewardTokens;
    mapping(address token => RewardData) public rewardData;

    event Staked(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event RewardTokenAdded(address indexed token, address indexed distributor, uint256 duration);

    error ZeroAddress();
    error ZeroAmount();
    error ZeroDuration();
    error RewardTokenExists();
    error TooManyRewardTokens();
    error InsufficientStake();

    constructor(IERC20 stakingToken_, address owner_) Ownable(owner_) {
        _requireNonZeroAddress(address(stakingToken_));
        stakingToken = stakingToken_;
    }

    /// @notice Registers a token that stakers can earn, and who may fund it.
    function addRewardToken(address token, address distributor, uint256 duration)
        external
        onlyOwner
    {
        _requireNonZeroAddress(token);
        _requireNonZeroAddress(distributor);
        _requireNewRewardToken(token);
        if (duration == 0) revert ZeroDuration();
        if (rewardTokens.length == MAX_REWARD_TOKENS) revert TooManyRewardTokens();

        rewardTokens.push(token);
        rewardData[token].distributor = distributor;
        rewardData[token].duration = duration;
        emit RewardTokenAdded(token, distributor, duration);
    }

    /// @notice Stakes stMEZO from the caller.
    function stake(uint256 amount) external nonReentrant {
        _requireNonZeroAmount(amount);
        totalStaked += amount;
        balanceOf[msg.sender] += amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    /// @notice Returns staked stMEZO to the caller.
    function withdraw(uint256 amount) external nonReentrant {
        _requireNonZeroAmount(amount);
        if (amount > balanceOf[msg.sender]) revert InsufficientStake();
        totalStaked -= amount;
        balanceOf[msg.sender] -= amount;
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function rewardTokensLength() external view returns (uint256) {
        return rewardTokens.length;
    }

    function _requireNewRewardToken(address token) private view {
        if (rewardData[token].distributor != address(0)) revert RewardTokenExists();
    }

    function _requireNonZeroAddress(address account) private pure {
        if (account == address(0)) revert ZeroAddress();
    }

    function _requireNonZeroAmount(uint256 amount) private pure {
        if (amount == 0) revert ZeroAmount();
    }
}
