// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Script, console2 } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";

contract Utils is Script {
    using stdJson for string;

    struct AddressesConfig {
        address L1LiskToken;
    }

    function readAddressesFile() external view returns (AddressesConfig memory) {
        string memory root = vm.projectRoot();
        string memory addressPath = string.concat(root, "/deployment/l1addresses.json");
        string memory addressJson = vm.readFile(addressPath);
        bytes memory addressRaw = vm.parseJson(addressJson);
        return abi.decode(addressRaw, (AddressesConfig));
    }

    function writeAddressesFile(AddressesConfig memory cfg) external {
        string memory json = "";
        string memory finalJson = vm.serializeAddress(json, "L1LiskToken", cfg.L1LiskToken);
        finalJson.write(string.concat("deployment/l1addresses.json"));
    }
}
