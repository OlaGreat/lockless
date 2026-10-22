// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title StMEZOStaking
/// @notice Stake stMEZO to earn the rewards Lockless harvests, streamed over each epoch.
contract StMEZOStaking is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_REWARD_TOKENS = 8;
    uint256 private constant PRECISION = 1e18;

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
    mapping(address account => mapping(address token => uint256)) public userRewardPerTokenPaid;
    mapping(address account => mapping(address token => uint256)) public unclaimedRewards;

    event Staked(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event RewardTokenAdded(address indexed token, address indexed distributor, uint256 duration);
    event RewardAdded(address indexed token, uint256 amount);
    event RewardPaid(address indexed account, address indexed token, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error ZeroDuration();
    error RewardTokenExists();
    error TooManyRewardTokens();
    error InsufficientStake();
    error UnknownRewardToken();
    error OnlyDistributor();

    modifier updateRewards(address account) {
        _updateRewards(account);
        _;
    }

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
    function stake(uint256 amount) external nonReentrant updateRewards(msg.sender) {
        _requireNonZeroAmount(amount);
        totalStaked += amount;
        balanceOf[msg.sender] += amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    /// @notice Returns staked stMEZO to the caller.
    function withdraw(uint256 amount) external nonReentrant updateRewards(msg.sender) {
        _requireNonZeroAmount(amount);
        if (amount > balanceOf[msg.sender]) revert InsufficientStake();
        totalStaked -= amount;
        balanceOf[msg.sender] -= amount;
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Pays the caller everything they have earned in every reward token.
    function claimRewards() external nonReentrant updateRewards(msg.sender) {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            _payReward(msg.sender, rewardTokens[i]);
        }
    }

    /// @notice Funds a reward token and streams it, plus anything still unpaid, over its duration.
    function notifyRewardAmount(address token, uint256 amount)
        external
        nonReentrant
        updateRewards(address(0))
    {
        _requireKnownRewardToken(token);
        if (msg.sender != rewardData[token].distributor) revert OnlyDistributor();
        _requireNonZeroAmount(amount);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _startRewardPeriod(token, amount);
        emit RewardAdded(token, amount);
    }

    function rewardTokensLength() external view returns (uint256) {
        return rewardTokens.length;
    }

    /// @notice Reward earned per staked token since the start, scaled by 1e18.
    function rewardPerToken(address token) public view returns (uint256) {
        RewardData storage data = rewardData[token];
        if (totalStaked == 0) return data.rewardPerTokenStored;
        uint256 elapsed = lastTimeRewardApplicable(token) - data.lastUpdate;
        return data.rewardPerTokenStored + (elapsed * data.rate * PRECISION) / totalStaked;
    }

    /// @notice Rewards an account can claim right now in a given token.
    function earned(address account, address token) public view returns (uint256) {
        uint256 owedPerToken = rewardPerToken(token) - userRewardPerTokenPaid[account][token];
        return unclaimedRewards[account][token] + (balanceOf[account] * owedPerToken) / PRECISION;
    }

    /// @notice The latest moment that still earns rewards for a token.
    function lastTimeRewardApplicable(address token) public view returns (uint256) {
        return Math.min(block.timestamp, rewardData[token].periodFinish);
    }

    function _updateRewards(address account) private {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            _updateReward(rewardTokens[i], account);
        }
    }

    function _updateReward(address token, address account) private {
        RewardData storage data = rewardData[token];
        data.rewardPerTokenStored = rewardPerToken(token);
        data.lastUpdate = lastTimeRewardApplicable(token);
        if (account == address(0)) return;
        unclaimedRewards[account][token] = earned(account, token);
        userRewardPerTokenPaid[account][token] = data.rewardPerTokenStored;
    }

    function _startRewardPeriod(address token, uint256 amount) private {
        RewardData storage data = rewardData[token];
        data.rate = (amount + _unstreamedReward(data)) / data.duration;
        data.lastUpdate = block.timestamp;
        data.periodFinish = block.timestamp + data.duration;
    }

    function _unstreamedReward(RewardData storage data) private view returns (uint256) {
        if (block.timestamp >= data.periodFinish) return 0;
        return (data.periodFinish - block.timestamp) * data.rate;
    }

    function _payReward(address account, address token) private {
        uint256 reward = unclaimedRewards[account][token];
        if (reward == 0) return;
        unclaimedRewards[account][token] = 0;
        IERC20(token).safeTransfer(account, reward);
        emit RewardPaid(account, token, reward);
    }

    function _requireKnownRewardToken(address token) private view {
        if (rewardData[token].distributor == address(0)) revert UnknownRewardToken();
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
