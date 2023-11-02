// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Script, console2 } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";

contract Utils is Script {
    using stdJson for string;

    struct L1AddressesConfig {
        address L1LiskToken;
    }

    struct L2AddressesConfig {
        address L2ClaimContract;
        address L2LiskToken;
    }

    function readL1AddressesFile() external view returns (L1AddressesConfig memory) {
        string memory root = vm.projectRoot();
        string memory addressPath = string.concat(root, "/deployment/l1addresses.json");
        string memory addressJson = vm.readFile(addressPath);
        bytes memory addressRaw = vm.parseJson(addressJson);
        return abi.decode(addressRaw, (L1AddressesConfig));
    }

    function writeL1AddressesFile(L1AddressesConfig memory cfg) external {
        string memory json = "";
        string memory finalJson = vm.serializeAddress(json, "L1LiskToken", cfg.L1LiskToken);
        finalJson.write(string.concat("deployment/l1addresses.json"));
    }

    function readL2AddressesFile() external view returns (L2AddressesConfig memory) {
        string memory root = vm.projectRoot();
        string memory addressPath = string.concat(root, "/deployment/l2addresses.json");
        string memory addressJson = vm.readFile(addressPath);
        bytes memory addressRaw = vm.parseJson(addressJson);
        return abi.decode(addressRaw, (L2AddressesConfig));
    }

    function writeL2AddressesFile(L2AddressesConfig memory cfg) external {
        string memory json = "";
        vm.serializeAddress(json, "L2LiskToken", cfg.L2LiskToken);
        string memory finalJson = vm.serializeAddress(json, "L2ClaimContract", cfg.L2ClaimContract);
        finalJson.write(string.concat("deployment/l2addresses.json"));
    }
}
