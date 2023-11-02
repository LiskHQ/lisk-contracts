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
        Utils.L2AddressesConfig memory addressCfg = utils.readL2AddressesFile();
        console2.log("L2 Lisk token address: %s", addressCfg.L2LiskToken);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // deploy L2Claim contract
        vm.startBroadcast(deployerPrivateKey);
        L2Claim l2Claim = new L2Claim(address(addressCfg.L2LiskToken));
        vm.stopBroadcast();

        assert(address(l2Claim) != address(0));
        assert(keccak256(bytes(l2Claim.name())) == keccak256(bytes("Claim process")));
        assert(address(l2Claim.l2LiskToken()) == address(addressCfg.L2LiskToken));
    }
}
