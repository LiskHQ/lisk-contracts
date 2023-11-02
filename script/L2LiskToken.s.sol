// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Script, console2 } from "forge-std/Script.sol";
import { L2LiskToken } from "src/L2/L2LiskToken.sol";
import "script/Utils.sol";

contract L2LiskTokenScript is Script {
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    function run() public {
        Utils.L1AddressesConfig memory addressCfg = utils.readL1AddressesFile();
        console2.log("L1 Lisk token address: %s", addressCfg.L1LiskToken);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // deploy L1LiskToken contract
        vm.startBroadcast(deployerPrivateKey);
        L2LiskToken l2LiskToken =
        new L2LiskToken(address(0x4200000000000000000000000000000000000010), addressCfg.L1LiskToken, "Lisk", "LSK", 18);
        vm.stopBroadcast();

        assert(address(l2LiskToken) != address(0));
        assert(keccak256(bytes(l2LiskToken.name())) == keccak256(bytes("Lisk")));
        assert(keccak256(bytes(l2LiskToken.symbol())) == keccak256(bytes("LSK")));
        assert(l2LiskToken.decimals() == 18);

        // write L2LiskToken address to l2addresses.json
        Utils.L2AddressesConfig memory finalCfg;
        finalCfg.L2LiskToken = address(l2LiskToken);
        utils.writeL2AddressesFile(finalCfg);
    }
}
