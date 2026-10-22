// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployLockless} from "../script/DeployLockless.s.sol";
import {IRouter} from "../src/interfaces/IRouter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockVotingEscrow} from "./mocks/MockVotingEscrow.sol";
import {MockBoostVoter} from "./mocks/MockBoostVoter.sol";
import {MockRewardsDistributor} from "./mocks/MockRewardsDistributor.sol";
import {MockRouter} from "./mocks/MockRouter.sol";

contract DeployLocklessTest is Test {
    address internal owner = makeAddr("owner");
    address internal keeper = makeAddr("keeper");
    address internal treasury = makeAddr("treasury");

    DeployLockless internal script;
    DeployLockless.Config internal config;
    DeployLockless.Deployment internal deployment;

    function setUp() public {
        script = new DeployLockless();
        MockERC20 mezo = new MockERC20("Mezo", "MEZO");
        MockVotingEscrow ve = new MockVotingEscrow(mezo);
        config = DeployLockless.Config({
            veMEZO: ve,
            voter: new MockBoostVoter(ve),
            rebaseDistributor: new MockRewardsDistributor(ve),
            router: IRouter(address(new MockRouter(1))),
            musd: new MockERC20("Mezo USD", "MUSD"),
            owner: address(script),
            keeper: keeper,
            treasury: treasury,
            feeBps: 1_000,
            rewardDuration: 7 days
        });
        deployment = script.deploy(config);
    }

    function test_PointsTheVaultAtTheHarvester() public view {
        assertEq(deployment.vault.rewardsReceiver(), address(deployment.harvester));
        assertEq(deployment.vault.keeper(), keeper);
    }

    function test_StakesTheVaultsStMEZO() public view {
        assertEq(address(deployment.staking.stakingToken()), address(deployment.vault.stMEZO()));
        assertEq(address(deployment.stMEZO), address(deployment.vault.stMEZO()));
    }

    function test_LetsTheHarvesterFundMusdAndStMEZORewards() public view {
        _assertRewardFundedByHarvester(address(config.musd));
        _assertRewardFundedByHarvester(address(deployment.stMEZO));
        assertEq(deployment.staking.rewardTokensLength(), 2);
    }

    function test_ConfiguresTheHarvester() public view {
        assertEq(address(deployment.harvester.staking()), address(deployment.staking));
        assertEq(address(deployment.harvester.musd()), address(config.musd));
        assertEq(deployment.harvester.treasury(), treasury);
        assertEq(deployment.harvester.keeper(), keeper);
        assertEq(deployment.harvester.feeBps(), 1_000);
    }

    function test_LetsTheHarvesterLockMezoIntoTheVault() public view {
        assertEq(address(deployment.harvester.vault()), address(deployment.vault));
    }

    function test_GivesOwnershipToTheConfiguredOwner() public view {
        assertEq(deployment.vault.owner(), config.owner);
        assertEq(deployment.staking.owner(), config.owner);
        assertEq(deployment.harvester.owner(), config.owner);
    }

    function test_TestnetConfigUsesMezoTestnetContracts() public view {
        DeployLockless.Config memory testnet = script.testnetConfig(owner, keeper, treasury);

        assertEq(address(testnet.veMEZO), 0xaCE816CA2bcc9b12C59799dcC5A959Fb9b98111b);
        assertEq(address(testnet.voter), 0x21d7bDF5a5929AD179F8cA0c9014A0B62ae6Bfd1);
        assertEq(address(testnet.rebaseDistributor), 0x2962E8817ae716019F759d098e2caE658bDcAd04);
        assertEq(address(testnet.router), 0x9a1ff7FE3a0F69959A3fBa1F1e5ee18e1A9CD7E9);
        assertEq(address(testnet.musd), 0x118917a40FAF1CD7a13dB0Ef56C86De7973Ac503);
        assertEq(testnet.owner, owner);
        assertEq(testnet.keeper, keeper);
        assertEq(testnet.treasury, treasury);
    }

    function _assertRewardFundedByHarvester(address token) internal view {
        (address distributor, uint256 duration,,,,) = deployment.staking.rewardData(token);
        assertEq(distributor, address(deployment.harvester));
        assertEq(duration, config.rewardDuration);
    }
}
