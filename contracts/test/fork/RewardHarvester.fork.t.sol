// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RewardHarvester} from "../../src/RewardHarvester.sol";
import {StMEZOStaking} from "../../src/StMEZOStaking.sol";
import {IRouter} from "../../src/interfaces/IRouter.sol";
import {IPriceFeed} from "../../src/interfaces/IPriceFeed.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockLocklessVault} from "../mocks/MockLocklessVault.sol";

/// @notice Prices harvest swaps with the real Mezo testnet BTC price feed on a local fork.
/// @dev Run with: RUN_FORK_TESTS=true forge test --match-path "test/fork/*". The feed reads a Mezo
///      oracle precompile that cannot run on a fork, so only that precompile is replaced, with
///      values recorded from the live chain. The feed's own staleness check and scaling still run.
contract RewardHarvesterForkTest is Test {
    IRouter internal constant ROUTER = IRouter(0x9a1ff7FE3a0F69959A3fBa1F1e5ee18e1A9CD7E9);
    IERC20 internal constant MUSD = IERC20(0x118917a40FAF1CD7a13dB0Ef56C86De7973Ac503);
    IERC20 internal constant BTC = IERC20(0x7b7C000000000000000000000000000000000000);
    IPriceFeed internal constant BTC_PRICE_FEED =
        IPriceFeed(0x86bCF0841622a5dAC14A313a15f96A95421b9366);
    address internal constant BTC_ORACLE_PRECOMPILE = 0x7b7c000000000000000000000000000000000015;
    /// @dev A block every public RPC node has.
    uint256 internal constant DEFAULT_FORK_BLOCK = 16_280_000;
    /// @dev The oracle's answer at DEFAULT_FORK_BLOCK on the live chain, with 18 decimals.
    int256 internal constant RECORDED_BTC_PRICE = 83_462_685e15;
    uint8 internal constant ORACLE_DECIMALS = 18;
    /// @dev The feed rejects prices older than this (PriceFeed.MAX_PRICE_DELAY).
    uint256 internal constant MAX_PRICE_DELAY = 60;

    RewardHarvester internal harvester;

    modifier onlyWhenForking() {
        if (!vm.envOr("RUN_FORK_TESTS", false)) {
            vm.skip(true);
            return;
        }
        _;
    }

    function setUp() public {
        if (!vm.envOr("RUN_FORK_TESTS", false)) return;
        vm.createSelectFork("mezo_testnet", vm.envOr("MEZO_FORK_BLOCK", DEFAULT_FORK_BLOCK));
        MockERC20 stToken = new MockERC20("Lockless Staked MEZO", "stMEZO");
        address owner = makeAddr("owner");
        harvester = new RewardHarvester(
            RewardHarvester.Markets(ROUTER, MUSD, BTC, BTC_PRICE_FEED),
            new StMEZOStaking(stToken, owner),
            new MockLocklessVault(new MockERC20("Mezo", "MEZO"), stToken),
            makeAddr("treasury"),
            owner,
            makeAddr("keeper"),
            1_000
        );
    }

    function test_FloorUsesTheRealFeedPrice() public onlyWhenForking {
        _standInForTheOracle(block.timestamp);

        uint256 expected = (uint256(RECORDED_BTC_PRICE) * 9_700) / 10_000;
        assertEq(harvester.oracleFloor(1 ether), expected);
    }

    function test_RevertWhen_TheRealFeedSeesAStalePrice() public onlyWhenForking {
        _standInForTheOracle(block.timestamp - MAX_PRICE_DELAY - 1);

        vm.expectRevert("PriceFeed: Oracle is stale.");
        harvester.oracleFloor(1 ether);
    }

    function _standInForTheOracle(uint256 updatedAt) internal {
        vm.mockCall(
            BTC_ORACLE_PRECOMPILE,
            abi.encodeWithSignature("decimals()"),
            abi.encode(ORACLE_DECIMALS)
        );
        vm.mockCall(
            BTC_ORACLE_PRECOMPILE,
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(uint80(1), RECORDED_BTC_PRICE, updatedAt, updatedAt, uint80(1))
        );
    }
}
