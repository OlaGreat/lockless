// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LocklessVault} from "../src/LocklessVault.sol";
import {RewardHarvester} from "../src/RewardHarvester.sol";
import {StMEZO} from "../src/StMEZO.sol";
import {StMEZOStaking} from "../src/StMEZOStaking.sol";
import {IBoostVoter} from "../src/interfaces/IBoostVoter.sol";
import {IRewardsDistributor} from "../src/interfaces/IRewardsDistributor.sol";
import {IRouter} from "../src/interfaces/IRouter.sol";
import {IVotingEscrow} from "../src/interfaces/IVotingEscrow.sol";

/// @notice Deploys and wires the Lockless contracts.
/// @dev forge script script/DeployLockless.s.sol --rpc-url mezo_testnet --broadcast
///      --private-key $PRIVATE_KEY. KEEPER_ADDRESS, TREASURY_ADDRESS and FEE_BPS are optional.
contract DeployLockless is Script {
    uint256 private constant DEFAULT_FEE_BPS = 1_000;
    uint256 private constant REWARD_DURATION = 7 days;

    address private constant TESTNET_VE_MEZO = 0xaCE816CA2bcc9b12C59799dcC5A959Fb9b98111b;
    address private constant TESTNET_BOOST_VOTER = 0x21d7bDF5a5929AD179F8cA0c9014A0B62ae6Bfd1;
    address private constant TESTNET_REBASE_DISTRIBUTOR =
        0x2962E8817ae716019F759d098e2caE658bDcAd04;
    address private constant TESTNET_ROUTER = 0x9a1ff7FE3a0F69959A3fBa1F1e5ee18e1A9CD7E9;
    address private constant TESTNET_MUSD = 0x118917a40FAF1CD7a13dB0Ef56C86De7973Ac503;

    struct Config {
        IVotingEscrow veMEZO;
        IBoostVoter voter;
        IRewardsDistributor rebaseDistributor;
        IRouter router;
        IERC20 musd;
        address owner;
        address keeper;
        address treasury;
        uint256 feeBps;
        uint256 rewardDuration;
    }

    struct Deployment {
        LocklessVault vault;
        StMEZO stMEZO;
        StMEZOStaking staking;
        RewardHarvester harvester;
    }

    function run() external returns (Deployment memory deployment) {
        Config memory config = testnetConfig(
            msg.sender,
            vm.envOr("KEEPER_ADDRESS", msg.sender),
            vm.envOr("TREASURY_ADDRESS", msg.sender)
        );
        config.feeBps = vm.envOr("FEE_BPS", DEFAULT_FEE_BPS);

        vm.startBroadcast();
        deployment = deploy(config);
        vm.stopBroadcast();

        _saveDeployment(config, deployment);
    }

    /// @notice Deploys every contract and connects them. Calls are made as `config.owner`.
    function deploy(Config memory config) public returns (Deployment memory deployment) {
        deployment.vault = _deployVault(config);
        deployment.stMEZO = deployment.vault.stMEZO();
        deployment.staking = new StMEZOStaking(deployment.stMEZO, config.owner);
        deployment.harvester = _deployHarvester(config, deployment.staking);
        _connect(config, deployment);
    }

    function testnetConfig(address owner, address keeper, address treasury)
        public
        pure
        returns (Config memory)
    {
        return Config({
            veMEZO: IVotingEscrow(TESTNET_VE_MEZO),
            voter: IBoostVoter(TESTNET_BOOST_VOTER),
            rebaseDistributor: IRewardsDistributor(TESTNET_REBASE_DISTRIBUTOR),
            router: IRouter(TESTNET_ROUTER),
            musd: IERC20(TESTNET_MUSD),
            owner: owner,
            keeper: keeper,
            treasury: treasury,
            feeBps: DEFAULT_FEE_BPS,
            rewardDuration: REWARD_DURATION
        });
    }

    function _deployVault(Config memory config) private returns (LocklessVault) {
        return new LocklessVault(
            config.veMEZO, config.voter, config.rebaseDistributor, config.owner, config.keeper
        );
    }

    function _deployHarvester(Config memory config, StMEZOStaking staking)
        private
        returns (RewardHarvester)
    {
        return new RewardHarvester(
            config.router,
            config.musd,
            staking,
            config.treasury,
            config.owner,
            config.keeper,
            config.feeBps
        );
    }

    function _connect(Config memory config, Deployment memory deployment) private {
        address harvester = address(deployment.harvester);
        deployment.vault.setRewardsReceiver(harvester);
        deployment.staking.addRewardToken(address(config.musd), harvester, config.rewardDuration);
        deployment.staking
            .addRewardToken(address(deployment.stMEZO), harvester, config.rewardDuration);
    }

    function _saveDeployment(Config memory config, Deployment memory deployment) private {
        string memory key = "deployment";
        vm.serializeUint(key, "chainId", block.chainid);
        vm.serializeUint(key, "startBlock", block.number);
        vm.serializeAddress(key, "veMEZO", address(config.veMEZO));
        vm.serializeAddress(key, "boostVoter", address(config.voter));
        vm.serializeAddress(key, "rebaseDistributor", address(config.rebaseDistributor));
        vm.serializeAddress(key, "router", address(config.router));
        vm.serializeAddress(key, "musd", address(config.musd));
        vm.serializeAddress(key, "mezo", config.veMEZO.token());
        vm.serializeAddress(key, "vault", address(deployment.vault));
        vm.serializeAddress(key, "stMEZO", address(deployment.stMEZO));
        vm.serializeAddress(key, "staking", address(deployment.staking));
        string memory json = vm.serializeAddress(key, "harvester", address(deployment.harvester));
        vm.writeJson(json, _deploymentPath());
    }

    function _deploymentPath() private view returns (string memory) {
        return string.concat(vm.projectRoot(), "/deployments/", vm.toString(block.chainid), ".json");
    }
}
