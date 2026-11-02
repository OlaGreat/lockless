// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RewardHarvester} from "../src/RewardHarvester.sol";
import {StMEZOStaking} from "../src/StMEZOStaking.sol";
import {IRouter} from "../src/interfaces/IRouter.sol";
import {IPriceFeed} from "../src/interfaces/IPriceFeed.sol";
import {ILocklessVault} from "../src/interfaces/ILocklessVault.sol";
import {HarvesterTestBase} from "./utils/HarvesterTestBase.sol";

contract RewardHarvesterAdminTest is HarvesterTestBase {
    address internal newAccount = makeAddr("newAccount");

    function test_WiresItsDependencies() public view {
        assertEq(address(harvester.router()), address(router));
        assertEq(address(harvester.musd()), address(musd));
        assertEq(address(harvester.staking()), address(staking));
        assertEq(harvester.treasury(), treasury);
        assertEq(harvester.keeper(), keeper);
        assertEq(harvester.owner(), owner);
        assertEq(harvester.feeBps(), FEE_BPS);
    }

    function test_PricesBtcWithItsOracle() public view {
        assertEq(address(harvester.btc()), address(btc));
        assertEq(address(harvester.btcPriceFeed()), address(priceFeed));
    }

    function test_TakesMezoFromTheVault() public view {
        assertEq(address(harvester.vault()), address(vault));
        assertEq(address(harvester.mezo()), address(mezo));
    }

    function test_RevertWhen_VaultIsZero() public {
        RewardHarvester.Markets memory markets = _markets();

        vm.expectRevert(RewardHarvester.ZeroAddress.selector);
        new RewardHarvester(
            markets, staking, ILocklessVault(address(0)), treasury, owner, keeper, FEE_BPS
        );
    }

    function test_RevertWhen_RouterIsZero() public {
        RewardHarvester.Markets memory markets = _markets();
        markets.router = IRouter(address(0));

        _expectZeroAddressRevert(markets);
    }

    function test_RevertWhen_MusdIsZero() public {
        RewardHarvester.Markets memory markets = _markets();
        markets.musd = IERC20(address(0));

        _expectZeroAddressRevert(markets);
    }

    function test_RevertWhen_BtcIsZero() public {
        RewardHarvester.Markets memory markets = _markets();
        markets.btc = IERC20(address(0));

        _expectZeroAddressRevert(markets);
    }

    function test_RevertWhen_BtcPriceFeedIsZero() public {
        RewardHarvester.Markets memory markets = _markets();
        markets.btcPriceFeed = IPriceFeed(address(0));

        _expectZeroAddressRevert(markets);
    }

    function test_RevertWhen_StakingIsZero() public {
        RewardHarvester.Markets memory markets = _markets();

        vm.expectRevert(RewardHarvester.ZeroAddress.selector);
        new RewardHarvester(
            markets, StMEZOStaking(address(0)), vault, treasury, owner, keeper, FEE_BPS
        );
    }

    function test_RevertWhen_FeeIsAboveTheCap() public {
        uint256 tooHigh = harvester.MAX_FEE_BPS() + 1;
        RewardHarvester.Markets memory markets = _markets();

        vm.expectRevert(RewardHarvester.FeeTooHigh.selector);
        new RewardHarvester(markets, staking, vault, treasury, owner, keeper, tooHigh);
    }

    function test_OwnerCanChangeTheFee() public {
        vm.prank(owner);
        harvester.setFeeBps(500);

        assertEq(harvester.feeBps(), 500);
    }

    function test_RevertWhen_NewFeeIsAboveTheCap() public {
        uint256 tooHigh = harvester.MAX_FEE_BPS() + 1;

        vm.expectRevert(RewardHarvester.FeeTooHigh.selector);
        vm.prank(owner);
        harvester.setFeeBps(tooHigh);
    }

    function test_OwnerCanChangeTheTreasury() public {
        vm.prank(owner);
        harvester.setTreasury(newAccount);

        assertEq(harvester.treasury(), newAccount);
    }

    function test_OwnerCanChangeTheKeeper() public {
        vm.prank(owner);
        harvester.setKeeper(newAccount);

        assertEq(harvester.keeper(), newAccount);
    }

    function test_RevertWhen_NewTreasuryIsZero() public {
        vm.expectRevert(RewardHarvester.ZeroAddress.selector);
        vm.prank(owner);
        harvester.setTreasury(address(0));
    }

    function test_RevertWhen_NewKeeperIsZero() public {
        vm.expectRevert(RewardHarvester.ZeroAddress.selector);
        vm.prank(owner);
        harvester.setKeeper(address(0));
    }

    function test_RevertWhen_NonOwnerChangesSettings() public {
        bytes memory unauthorized =
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice);

        vm.startPrank(alice);
        vm.expectRevert(unauthorized);
        harvester.setFeeBps(0);
        vm.expectRevert(unauthorized);
        harvester.setTreasury(newAccount);
        vm.expectRevert(unauthorized);
        harvester.setKeeper(newAccount);
        vm.stopPrank();
    }

    function _expectZeroAddressRevert(RewardHarvester.Markets memory markets) internal {
        vm.expectRevert(RewardHarvester.ZeroAddress.selector);
        new RewardHarvester(markets, staking, vault, treasury, owner, keeper, FEE_BPS);
    }
}
