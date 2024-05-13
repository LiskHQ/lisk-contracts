// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { L1LiskToken } from "src/L1/L1LiskToken.sol";
import "script/contracts/Utils.sol";

/// @title L1FundVestingScript
/// @notice This contract is used to transfer deployer's L1 Lisk tokens to the Vesting contract with L1 Network.
contract L1FundVestingScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    /// @notice Stating the network layer of this script
    string public constant layer = "L1";

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function transfers deployer's L1 Lisk tokens to the Vesting contract.
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // get L1LiskToken contract address
        Utils.L1AddressesConfig memory l1AddressesConfig = utils.readL1AddressesFile();
        assert(l1AddressesConfig.L1LiskToken != address(0));
        console2.log("L1 Lisk token address: %s", l1AddressesConfig.L1LiskToken);

        // get L1LiskToken instances
        L1LiskToken l1LiskToken = L1LiskToken(address(l1AddressesConfig.L1LiskToken));

        Utils.VestingPlan[] memory plans = utils.readVestingPlansFile(layer);
        for (uint256 i; i < plans.length; i++) {
            Utils.VestingPlan memory vestingPlan = plans[i];
            address vestingWalletAddress = utils.readVestingWalletAddress(vestingPlan.name, layer);

            console2.log(
                "Transferring %s Lisk tokens to the vesting wallet %s ... on L1",
                vestingPlan.amount,
                vestingWalletAddress
            );

            // transfer L1 Lisk tokens to the vesting wallet
            vm.startBroadcast(deployerPrivateKey);
            l1LiskToken.transfer(vestingWalletAddress, vestingPlan.amount);
            assert(l1LiskToken.balanceOf(vestingWalletAddress) == vestingPlan.amount);
            vm.stopBroadcast();
        }

        console2.log("Transferred deployer's L1 Lisk tokens to the Vesting contract.");
    }
}
