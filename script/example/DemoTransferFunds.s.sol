// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import "script/Utils.sol";

/// @title DemoTransferFundsScript - Demo Transferring LSK to Claim contract
/// @notice In Demo environment, after Claim contract is deployed, this script is used to send LSK tokens to Claim
/// contract.
contract DemoTransferFundsScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils internal utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice Transfer LSK Tokens to Claim contract
    function run() public {
        // Deployer's private key. Owner of the L2 Lisk token. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // read L2LiskToken address from l2addresses.json
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile();
        IERC20 lsk = IERC20(l2AddressesConfig.L2LiskToken);

        vm.startBroadcast(deployerPrivateKey);
        lsk.transfer(l2AddressesConfig.L2ClaimContract, 10000 ether);
        vm.stopBroadcast();
    }
}
