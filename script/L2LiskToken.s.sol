// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Script, console2 } from "forge-std/Script.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { L2LiskToken } from "src/L2/L2LiskToken.sol";
import "script/Utils.sol";

/// @title L2LiskTokenScript - L2 Lisk token deployment script
/// @notice This contract is used to deploy L2 Lisk token contract and write its address to JSON file.
contract L2LiskTokenScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    /// @notice L2 Standard Bridge address.
    address private constant L2_STANDARD_BRIDGE = 0x4200000000000000000000000000000000000010;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2 Lisk token contract and writes its address to JSON file.
    function run() public {
        // Deployer's private key. Owner of the L2 Lisk token. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L2 Lisk token...");

        // get L1LiskToken contract address
        Utils.L1AddressesConfig memory l1AddressesConfig = utils.readL1AddressesFile();
        console2.log("L1 Lisk token address: %s", l1AddressesConfig.L1LiskToken);

        // get salt for L2LiskToken contract
        bytes32 salt = keccak256(bytes(vm.envString("L2_TOKEN_SALT")));
        console2.log("L2 Lisk token address salt: %s", vm.envString("L2_TOKEN_SALT"));

        // calculate L2LiskToken contract address
        address l2LiskTokenAddressCalculated = computeCreate2Address(
            salt, hashInitCode(type(L2LiskToken).creationCode, abi.encode(l1AddressesConfig.L1LiskToken))
        );
        console2.log("Calculated L2 Lisk token address: %s", l2LiskTokenAddressCalculated);

        // deploy L2LiskToken contract
        vm.startBroadcast(deployerPrivateKey);
        L2LiskToken l2LiskToken = new L2LiskToken{ salt: salt }(l1AddressesConfig.L1LiskToken);
        l2LiskToken.initialize(L2_STANDARD_BRIDGE);
        vm.stopBroadcast();

        assert(address(l2LiskToken) == l2LiskTokenAddressCalculated);
        assert(keccak256(bytes(l2LiskToken.name())) == keccak256(bytes("Lisk")));
        assert(keccak256(bytes(l2LiskToken.symbol())) == keccak256(bytes("LSK")));
        assert(l2LiskToken.decimals() == 18);
        assert(l2LiskToken.totalSupply() == 0);
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
