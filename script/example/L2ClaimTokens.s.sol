// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { L2Claim } from "src/L2/L2Claim.sol";
import "script/Utils.sol";

/// @title L2ClaimTokensScript - L2 Claim Lisk tokens script
/// @notice This contract is used to claim L2 Lisk tokens from the L2 Claim contract for a demonstration purpose.
contract L2ClaimTokensScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function claims L2 Lisk tokens from the L2 Claim contract for a demonstration purpose.
    function run() public view {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // print deployer address
        console2.log("Deployer address: %s", vm.addr(deployerPrivateKey));

        // get L2Claim contract address
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile();
        console2.log("L2 Claim contract address: %s", l2AddressesConfig.L2ClaimContract);

        // check L2Claim contract Lisk token balance
        L2Claim l2Claim = L2Claim(address(l2AddressesConfig.L2ClaimContract));
        console2.log(
            "L2 Claim contract Lisk token balance before claim: %s", l2Claim.l2LiskToken().balanceOf(address(l2Claim))
        );

        // check deployer Lisk token balance
        console2.log(
            "Deployer's Lisk token balance before claim: %s",
            l2Claim.l2LiskToken().balanceOf(vm.addr(deployerPrivateKey))
        );

        // TODO: perform Claim Process for demonstration purpose

        // check that L2Claim contract has less Lisk tokens than before
        console2.log(
            "L2 Claim contract Lisk token balance after claim: %s", l2Claim.l2LiskToken().balanceOf(address(l2Claim))
        );

        // check that deployer has 5 Lisk tokens
        console2.log(
            "Deployer's Lisk token balance after claim: %s",
            l2Claim.l2LiskToken().balanceOf(vm.addr(deployerPrivateKey))
        );
    }
}
