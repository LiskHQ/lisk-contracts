// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Script, console2 } from "forge-std/Script.sol";
import { L2Claim } from "src/L2/L2Claim.sol";
import "script/Utils.sol";

contract L2ClaimScript is Script {
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L2 Claim contract...");

        // get L2LiskToken contract address
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile();
        console2.log("L2 Lisk token address: %s", l2AddressesConfig.L2LiskToken);

        // deploy L2Claim contract
        vm.startBroadcast(deployerPrivateKey);
        L2Claim l2Claim = new L2Claim(address(l2AddressesConfig.L2LiskToken));
        vm.stopBroadcast();

        assert(address(l2Claim) != address(0));
        assert(keccak256(bytes(l2Claim.name())) == keccak256(bytes("Claim process")));
        assert(address(l2Claim.l2LiskToken()) == address(l2AddressesConfig.L2LiskToken));

        console2.log("L2 Claim contract successfully deployed!");
        console2.log("L2 Claim contract address: %s", address(l2Claim));

        // write L2ClaimContract address to l2addresses.json
        l2AddressesConfig.L2ClaimContract = address(l2Claim);
        utils.writeL2AddressesFile(l2AddressesConfig);
    }
}
