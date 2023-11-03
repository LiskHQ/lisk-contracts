// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Script, console2 } from "forge-std/Script.sol";
import { L2Claim } from "src/L2/L2Claim.sol";
import "script/Utils.sol";

contract L2ClaimTokensScript is Script {
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    function run() public {
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

        // claim 5 Lisk tokens for a demonstration purpose
        vm.startBroadcast(deployerPrivateKey);
        l2Claim.claim();
        vm.stopBroadcast();

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
