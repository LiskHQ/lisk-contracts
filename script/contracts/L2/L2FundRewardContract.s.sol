// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { IL2LiskToken } from "src/interfaces/L2/IL2LiskToken.sol";
import { IL2Reward } from "src/interfaces/L2/IL2Reward.sol";
import "script/contracts/Utils.sol";

/// @title FundRewardContractScript
/// @notice This contract is used to transfer deployer's L2 Lisk tokens to the L2Reward contract.
contract FundRewardContractScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    /// @notice Amount of LSK tokens to be allocated for L2Reward contract.
    uint256 public constant REWARD_CONTRACT_AMOUNT = 24_000_000 * 10 ** 18; // 24 million LSK tokens

    /// @notice Duration for which L2Reward contract is funded.
    uint16 public constant REWARD_CONTRACT_FUNDING_DURATION = 1095; // 3 years

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function transfers deployer's L2 Lisk tokens to the L2Reward contract.
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Transferring deployer's L2 Lisk tokens to the L2Reward contract...");

        // get L2LiskToken and L2Reward contracts instances
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile();
        assert(l2AddressesConfig.L2LiskToken != address(0));
        assert(l2AddressesConfig.L2Reward != address(0));
        IL2LiskToken l2LiskToken = IL2LiskToken(l2AddressesConfig.L2LiskToken);
        IL2Reward l2Reward = IL2Reward(l2AddressesConfig.L2Reward);

        // check that deployer has enough L2 Lisk tokens to fund the L2Reward contract
        assert(l2LiskToken.balanceOf(vm.addr(deployerPrivateKey)) >= REWARD_CONTRACT_AMOUNT);

        // approve L2Reward contract to transfer L2 Lisk tokens
        vm.startBroadcast(deployerPrivateKey);
        l2LiskToken.approve(address(l2Reward), REWARD_CONTRACT_AMOUNT);
        vm.stopBroadcast();

        assert(l2LiskToken.allowance(vm.addr(deployerPrivateKey), address(l2Reward)) == REWARD_CONTRACT_AMOUNT);

        // fund L2Reward contract
        vm.startBroadcast(deployerPrivateKey);
        l2Reward.fundStakingRewards(
            REWARD_CONTRACT_AMOUNT, REWARD_CONTRACT_FUNDING_DURATION, l2Reward.REWARD_DURATION_DELAY()
        );
        vm.stopBroadcast();

        assert(l2LiskToken.balanceOf(address(l2Reward)) == REWARD_CONTRACT_AMOUNT);

        console2.log("Deployer's L2 Lisk tokens successfully transferred to the L2Reward contract.");
    }
}
