// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { L2Airdrop } from "src/L2/L2Airdrop.sol";
import "script/Utils.sol";

/// @title L2AirdropScript - L2 Airdrop deployment script
/// @notice This contract is used to deploy L2 Airdrop contract.
contract L2AirdropScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2 Airdrop contract.
    function run() public {
        // Deployer's private key. Owner of the L2 Airdrop. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L2 Airdrop contract...");

        // address, the ownership of L2 Airdrop contract is transferred to after deployment
        address newOwnerAddress = vm.envAddress("L2_AIRDROP_OWNER_ADDRESS");
        console2.log("L2 Airdrop owner address: %s (after ownership will be accepted)", newOwnerAddress);

        // get L2LiskToken contract address
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile();
        console2.log("L2 Lisk token address: %s", l2AddressesConfig.L2LiskToken);

        // get L2LockingPosition contract address
        console2.log("L2 Locking Position address: %s", l2AddressesConfig.L2LockingPosition);

        // get L2Staking contract address
        console2.log("L2 Staking address: %s", l2AddressesConfig.L2Staking);

        // get L2VotingPower contract address
        console2.log("L2 Voting Power address: %s", l2AddressesConfig.L2VotingPower);

        // get DAO (L2TimelockController) contract address
        console2.log("DAO (L2TimelockController) address: %s", l2AddressesConfig.L2TimelockController);

        // deploy L2Airdrop contract and transfer its ownership; new owner has to accept ownership to become the owner
        // of the contract
        vm.startBroadcast(deployerPrivateKey);
        L2Airdrop l2Airdrop = new L2Airdrop(
            l2AddressesConfig.L2LiskToken,
            l2AddressesConfig.L2LockingPosition,
            l2AddressesConfig.L2Staking,
            l2AddressesConfig.L2VotingPower,
            l2AddressesConfig.L2TimelockController
        );
        l2Airdrop.transferOwnership(newOwnerAddress);
        vm.stopBroadcast();

        assert(address(l2Airdrop) != address(0));
        assert(l2Airdrop.owner() == vm.addr(deployerPrivateKey));
        assert(l2Airdrop.pendingOwner() == newOwnerAddress);

        console2.log("L2 Airdrop successfully deployed!");
        console2.log("L2 Airdrop address: %s", address(l2Airdrop));

        // write L2Airdrop address to l2addresses.json
        l2AddressesConfig.L2Airdrop = address(l2Airdrop);
        utils.writeL2AddressesFile(l2AddressesConfig);
    }
}
