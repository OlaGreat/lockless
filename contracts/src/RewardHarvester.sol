// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {StMEZOStaking} from "./StMEZOStaking.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol";
import {ILocklessVault} from "./interfaces/ILocklessVault.sol";

/// @title RewardHarvester
/// @notice Receives what the vault harvests, swaps BTC incentives into MUSD on Mezo Pools, locks
///         MEZO incentives into the vault as stMEZO, keeps a protocol fee and streams the rest to
///         stMEZO stakers.
contract RewardHarvester is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The Mezo contracts the harvester trades through and prices against.
    struct Markets {
        IRouter router;
        IERC20 musd;
        IERC20 btc;
        IPriceFeed btcPriceFeed;
    }

    uint256 public constant MAX_FEE_BPS = 2_000;
    /// @notice A swap must return at least the oracle value of its BTC less this much.
    uint256 public constant MAX_SLIPPAGE_BPS = 300;
    uint256 private constant BPS = 10_000;
    uint256 private constant PRICE_PRECISION = 1e18;

    IRouter public immutable router;
    IERC20 public immutable musd;
    IERC20 public immutable btc;
    IPriceFeed public immutable btcPriceFeed;
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
    error SwapBelowOracleFloor();

    modifier onlyKeeper() {
        if (msg.sender != keeper) revert OnlyKeeper();
        _;
    }

    constructor(
        Markets memory markets,
        StMEZOStaking staking_,
        ILocklessVault vault_,
        address treasury_,
        address owner_,
        address keeper_,
        uint256 feeBps_
    ) Ownable(owner_) {
        _requireValidMarkets(markets);
        _requireNonZeroAddress(address(staking_));
        _requireNonZeroAddress(address(vault_));
        _requireNonZeroAddress(treasury_);
        _requireNonZeroAddress(keeper_);
        _requireFeeWithinCap(feeBps_);

        router = markets.router;
        musd = markets.musd;
        btc = markets.btc;
        btcPriceFeed = markets.btcPriceFeed;
        staking = staking_;
        vault = vault_;
        mezo = vault_.mezo();
        treasury = treasury_;
        keeper = keeper_;
        feeBps = feeBps_;
    }

    /// @notice Swaps harvested BTC into MUSD along the given Mezo Pools route.
    /// @dev Whatever minimum the keeper passes, the swap must return at least `oracleFloor`, so a
    ///      keeper cannot sell stakers' BTC far below Mezo's oracle price.
    /// @param minMusdOut Smallest MUSD amount the keeper accepts from the router.
    function swapBtcToMusd(uint256 amountIn, uint256 minMusdOut, IRouter.Route[] calldata routes)
        external
        onlyKeeper
        nonReentrant
        returns (uint256 musdOut)
    {
        _requireRouteFromBtcToMusd(routes);
        uint256 floor = oracleFloor(amountIn);

        musdOut = _swap(amountIn, minMusdOut, routes);
        if (musdOut < floor) revert SwapBelowOracleFloor();

        emit Swapped(address(btc), amountIn, musdOut);
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

    /// @notice The least MUSD a swap of `btcAmount` must return: its value at Mezo's oracle price,
    ///         with MUSD taken at one dollar, less MAX_SLIPPAGE_BPS.
    function oracleFloor(uint256 btcAmount) public view returns (uint256) {
        uint256 keptBps = BPS - MAX_SLIPPAGE_BPS;
        return Math.mulDiv(btcAmount, btcPriceFeed.fetchPrice() * keptBps, PRICE_PRECISION * BPS);
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

    function _swap(uint256 amountIn, uint256 minMusdOut, IRouter.Route[] calldata routes)
        private
        returns (uint256 musdOut)
    {
        uint256 musdBefore = musd.balanceOf(address(this));
        btc.forceApprove(address(router), amountIn);
        router.swapExactTokensForTokens(
            amountIn, minMusdOut, routes, address(this), block.timestamp
        );
        musdOut = musd.balanceOf(address(this)) - musdBefore;
    }

    function _payTreasury(address token, uint256 fee) private {
        if (fee == 0) return;
        IERC20(token).safeTransfer(treasury, fee);
    }

    function _fundStakers(address token, uint256 amount) private {
        IERC20(token).forceApprove(address(staking), amount);
        staking.notifyRewardAmount(token, amount);
    }

    function _requireRouteFromBtcToMusd(IRouter.Route[] calldata routes) private view {
        if (routes.length == 0) revert InvalidRoute();
        if (routes[0].from != address(btc)) revert InvalidRoute();
        if (routes[routes.length - 1].to != address(musd)) revert InvalidRoute();
    }

    function _requireValidMarkets(Markets memory markets) private pure {
        _requireNonZeroAddress(address(markets.router));
        _requireNonZeroAddress(address(markets.musd));
        _requireNonZeroAddress(address(markets.btc));
        _requireNonZeroAddress(address(markets.btcPriceFeed));
    }

    function _requireFeeWithinCap(uint256 newFeeBps) private pure {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
    }

    function _requireNonZeroAddress(address account) private pure {
        if (account == address(0)) revert ZeroAddress();
    }
}
