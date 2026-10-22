// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {StMEZOStaking} from "./StMEZOStaking.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {ILocklessVault} from "./interfaces/ILocklessVault.sol";

/// @title RewardHarvester
/// @notice Receives what the vault harvests, swaps incentives into MUSD on Mezo Pools, locks MEZO
///         incentives into the vault as stMEZO, keeps a protocol fee and streams the rest to
///         stMEZO stakers.
contract RewardHarvester is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_FEE_BPS = 2_000;
    uint256 private constant BPS = 10_000;

    IRouter public immutable router;
    IERC20 public immutable musd;
    StMEZOStaking public immutable staking;
    ILocklessVault public immutable vault;
    IERC20 public immutable mezo;

    address public treasury;
    address public keeper;
    uint256 public feeBps;

    event Swapped(address indexed tokenIn, uint256 amountIn, uint256 musdOut);
    event Distributed(address indexed token, uint256 toStakers, uint256 fee);
    event MezoLocked(uint256 amount);
    event FeeUpdated(uint256 feeBps);
    event TreasuryUpdated(address indexed treasury);
    event KeeperUpdated(address indexed keeper);

    error ZeroAddress();
    error OnlyKeeper();
    error InvalidRoute();
    error NothingToDistribute();
    error NothingToLock();
    error FeeTooHigh();

    modifier onlyKeeper() {
        if (msg.sender != keeper) revert OnlyKeeper();
        _;
    }

    constructor(
        IRouter router_,
        IERC20 musd_,
        StMEZOStaking staking_,
        ILocklessVault vault_,
        address treasury_,
        address owner_,
        address keeper_,
        uint256 feeBps_
    ) Ownable(owner_) {
        _requireNonZeroAddress(address(router_));
        _requireNonZeroAddress(address(musd_));
        _requireNonZeroAddress(address(staking_));
        _requireNonZeroAddress(address(vault_));
        _requireNonZeroAddress(treasury_);
        _requireNonZeroAddress(keeper_);
        _requireFeeWithinCap(feeBps_);

        router = router_;
        musd = musd_;
        staking = staking_;
        vault = vault_;
        mezo = vault_.mezo();
        treasury = treasury_;
        keeper = keeper_;
        feeBps = feeBps_;
    }

    /// @notice Swaps a harvested reward token into MUSD along the given Mezo Pools route.
    /// @param minMusdOut Smallest MUSD amount the keeper accepts, protecting against slippage.
    function swapToMusd(
        address tokenIn,
        uint256 amountIn,
        uint256 minMusdOut,
        IRouter.Route[] calldata routes
    ) external onlyKeeper nonReentrant returns (uint256 musdOut) {
        _requireRouteToMusd(tokenIn, routes);

        uint256 musdBefore = musd.balanceOf(address(this));
        IERC20(tokenIn).forceApprove(address(router), amountIn);
        router.swapExactTokensForTokens(
            amountIn, minMusdOut, routes, address(this), block.timestamp
        );
        musdOut = musd.balanceOf(address(this)) - musdBefore;

        emit Swapped(tokenIn, amountIn, musdOut);
    }

    /// @notice Locks MEZO incentives into the vault, turning them into stMEZO for stakers.
    function lockMezo() external onlyKeeper nonReentrant returns (uint256 amount) {
        amount = mezo.balanceOf(address(this));
        if (amount == 0) revert NothingToLock();
        mezo.forceApprove(address(vault), amount);
        vault.deposit(amount, address(this));
        emit MezoLocked(amount);
    }

    /// @notice Sends the protocol fee to the treasury and streams the rest of a token to stakers.
    function distribute(address token) external onlyKeeper nonReentrant {
        uint256 amount = IERC20(token).balanceOf(address(this));
        if (amount == 0) revert NothingToDistribute();

        uint256 fee = (amount * feeBps) / BPS;
        uint256 toStakers = amount - fee;
        _payTreasury(token, fee);
        _fundStakers(token, toStakers);

        emit Distributed(token, toStakers, fee);
    }

    function setFeeBps(uint256 newFeeBps) external onlyOwner {
        _requireFeeWithinCap(newFeeBps);
        feeBps = newFeeBps;
        emit FeeUpdated(newFeeBps);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        _requireNonZeroAddress(newTreasury);
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    function setKeeper(address newKeeper) external onlyOwner {
        _requireNonZeroAddress(newKeeper);
        keeper = newKeeper;
        emit KeeperUpdated(newKeeper);
    }

    function _payTreasury(address token, uint256 fee) private {
        if (fee == 0) return;
        IERC20(token).safeTransfer(treasury, fee);
    }

    function _fundStakers(address token, uint256 amount) private {
        IERC20(token).forceApprove(address(staking), amount);
        staking.notifyRewardAmount(token, amount);
    }

    function _requireRouteToMusd(address tokenIn, IRouter.Route[] calldata routes) private view {
        if (routes.length == 0) revert InvalidRoute();
        if (routes[0].from != tokenIn) revert InvalidRoute();
        if (routes[routes.length - 1].to != address(musd)) revert InvalidRoute();
    }

    function _requireFeeWithinCap(uint256 newFeeBps) private pure {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
    }

    function _requireNonZeroAddress(address account) private pure {
        if (account == address(0)) revert ZeroAddress();
    }
}
