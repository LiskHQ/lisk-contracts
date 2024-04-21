// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import "script/contracts/Utils.sol";

/// @title L2DemoToken - Demo L2 LSK Token
/// @notice In Demo environment, this contract will be used due to the lack of bridge.
contract L2DemoToken is ERC20 {
    constructor(uint256 _totalSupply) ERC20("Demo Lisk Token", "dLSK") {
        _mint(msg.sender, _totalSupply);
    }
}

/// @title L2DemoTokenScript - Deploying Demo ERC20 as L2 LSK Token
/// @notice In Demo environment, this script will be used to deploy L2 LSK Token and mint LSK to deployer.
contract L2DemoTokenScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils internal utils;

    function setUp() public {
        utils = new Utils();
    }

    function run() public {
        // Deployer's private key. Owner of the Demo L2 Lisk token. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying Demo Lisk token...");

        vm.startBroadcast(deployerPrivateKey);
        ERC20 lsk = new L2DemoToken(10000 ether);
        vm.stopBroadcast();

        assert(lsk.decimals() == 18);
        assert(lsk.totalSupply() == 10000 ether);

        console2.log("L2 Demo Lisk Token successfully deployed!");
        console2.log("L2 Demo Lisk Token address: %s", address(lsk));

        // write L2LiskToken address to l2addresses.json
        Utils.L2AddressesConfig memory l2AddressesConfig;
        l2AddressesConfig.L2LiskToken = address(lsk);
        utils.writeL2AddressesFile(l2AddressesConfig);
    }
}
