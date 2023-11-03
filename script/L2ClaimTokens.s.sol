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
        Utils.L2AddressesConfig memory addressCfg = utils.readL2AddressesFile();
        console2.log("L2 Claim contract address: %s", addressCfg.L2ClaimContract);

        // claim 5 Lisk tokens for a demonstration
        vm.startBroadcast(deployerPrivateKey);
        L2Claim l2Claim = L2Claim(address(addressCfg.L2ClaimContract));
        l2Claim.claim();
        vm.stopBroadcast();

        // check that deployer has 5 Lisk tokens
        console2.log("Deployer's Lisk token balance: %s", l2Claim.l2LiskToken().balanceOf(vm.addr(deployerPrivateKey)));

        // check that L2Claim contract has less Lisk tokens than before
        console2.log("L2Claim's Lisk token balance: %s", l2Claim.l2LiskToken().balanceOf(address(l2Claim)));
    }
}
