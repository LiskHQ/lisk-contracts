// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Script, console2 } from "forge-std/Script.sol";
import { L2LiskToken } from "src/L2/L2LiskToken.sol";
import "script/Utils.sol";

contract L2LiskTokenScript is Script {
    address private constant L2_STANDARD_BRIDGE = 0x4200000000000000000000000000000000000010;
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L2 Lisk token...");

        // get L1LiskToken contract address
        Utils.L1AddressesConfig memory l1AddressesConfig = utils.readL1AddressesFile();
        console2.log("L1 Lisk token address: %s", l1AddressesConfig.L1LiskToken);

        // deploy L1LiskToken contract
        vm.startBroadcast(deployerPrivateKey);
        L2LiskToken l2LiskToken =
            new L2LiskToken(L2_STANDARD_BRIDGE, l1AddressesConfig.L1LiskToken, "Lost Space Key", "LSK", 18);
        vm.stopBroadcast();

        assert(address(l2LiskToken) != address(0));
        assert(keccak256(bytes(l2LiskToken.name())) == keccak256(bytes("Lost Space Key")));
        assert(keccak256(bytes(l2LiskToken.symbol())) == keccak256(bytes("LSK")));
        assert(l2LiskToken.decimals() == 18);
        assert(l2LiskToken.REMOTE_TOKEN() == l1AddressesConfig.L1LiskToken);
        assert(l2LiskToken.BRIDGE() == L2_STANDARD_BRIDGE);

        console2.log("L2 Lisk token successfully deployed!");
        console2.log("L2 Lisk token address: %s", address(l2LiskToken));

        // write L2LiskToken address to l2addresses.json
        Utils.L2AddressesConfig memory l2AddressesConfig;
        l2AddressesConfig.L2LiskToken = address(l2LiskToken);
        utils.writeL2AddressesFile(l2AddressesConfig);
    }
}
