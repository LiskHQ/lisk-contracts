// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Script, console2 } from "forge-std/Script.sol";
import { L2Claim } from "src/L2/L2Claim.sol";

contract L2ClaimScript is Script {
    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // deploy L1LiskToken contract
        vm.startBroadcast(deployerPrivateKey);
        L2Claim l2Claim = new L2Claim();
        vm.stopBroadcast();

        assert(address(l2Claim) != address(0));
        assert(keccak256(bytes(l2Claim.name())) == keccak256(bytes("Claim process")));
    }
}
