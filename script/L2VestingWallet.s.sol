// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2VestingWallet } from "src/L2/L2VestingWallet.sol";
import "script/Utils.sol";

/// @title L2VestingWalletScript - L2 Voting Power contract deployment script
/// @notice This contract is used to deploy L2 Voting Power contract.
contract L2VestingWalletScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2 Voting Power contract.
    function run() public {
        // Deployer's private key. Owner of the L2 Voting Power. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L2VestingWallet Implementation...");

        // deploy L2VotingPower implementation contract
        vm.startBroadcast(deployerPrivateKey);
        L2VestingWallet l2VestingWalletImplementation = new L2VestingWallet();
        vm.stopBroadcast();
        assert(address(l2VestingWalletImplementation) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(
            l2VestingWalletImplementation.proxiableUUID()
                == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );

        Utils.VestingPlans memory plans = utils.readVestingPlansFile();
        for (uint256 i; i < plans.vestingPlans.length; i++) {
            console2.log("Deploying Vesting Plan #%d: %s", i, plans.vestingPlans[i].name);

            Utils.VestingPlan memory vestingPlan = plans.vestingPlans[i];
            address beneficiary = vm.envAddress(vestingPlan.beneficiaryAddressTag);

            vm.startBroadcast(deployerPrivateKey);
            ERC1967Proxy l2VestingWalletProxy = new ERC1967Proxy(
                address(l2VestingWalletImplementation),
                abi.encodeWithSelector(
                    l2VestingWalletImplementation.initialize.selector,
                    beneficiary,
                    vestingPlan.startTimestamp,
                    uint64(vestingPlan.durationDays * 1 days),
                    vestingPlan.name
                )
            );
            vm.stopBroadcast();
            assert(address(l2VestingWalletProxy) != address(0));

            // wrap in ABI to support easier calls
            L2VestingWallet l2VestingWallet = L2VestingWallet(payable(address(l2VestingWalletProxy)));
            assert(keccak256(bytes(l2VestingWallet.name())) == keccak256(bytes(vestingPlan.name)));
            assert(l2VestingWallet.start() == vestingPlan.startTimestamp);
            assert(l2VestingWallet.duration() == uint256(vestingPlan.durationDays * 1 days));
            assert(keccak256(bytes(l2VestingWallet.version())) == keccak256(bytes("1.0.0")));

            // Owner automatically transferred to beneficiary during initialize
            assert(l2VestingWallet.owner() == beneficiary);

            // TODO: Output Implementation and VestingWallet as JSON
        }
    }
}
