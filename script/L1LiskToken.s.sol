// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Script, console2 } from "forge-std/Script.sol";
import { L1LiskToken } from "src/L1/L1LiskToken.sol";
import "script/Utils.sol";

/// @title L1LiskTokenScript - L1 Lisk token deployment script
/// @notice This contract is used to deploy L1 Lisk token contract, transfer its ownership and write its address to JSON
///         file.
contract L1LiskTokenScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This contract is used to deploy L1 Lisk token contract, transfer its ownership and write its address to
    ///         JSON file.
    function run() public {
        // Deployer's private key. Owner of the L1 Lisk token. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Address, the ownership of L1 Lisk token contract is transferred to after deployment.
        address ownerAddress = vm.envAddress("L1_TOKEN_OWNER_ADDRESS");

        console2.log("Simulation: Deploying L1 Lisk token...");

        // deploy L1LiskToken contract and transfer its ownership
        vm.startBroadcast(deployerPrivateKey);
        L1LiskToken l1LiskToken = new L1LiskToken();
        l1LiskToken.transferOwnership(ownerAddress);
        vm.stopBroadcast();

        assert(address(l1LiskToken) != address(0));
        assert(keccak256(bytes(l1LiskToken.name())) == keccak256(bytes("Lisk")));
        assert(keccak256(bytes(l1LiskToken.symbol())) == keccak256(bytes("LSK")));
        assert(l1LiskToken.decimals() == 18);
        assert(l1LiskToken.totalSupply() == 300000000 * 10 ** 18);
        assert(l1LiskToken.balanceOf(vm.addr(deployerPrivateKey)) == 300000000 * 10 ** 18);
        assert(l1LiskToken.hasRole(l1LiskToken.DEFAULT_ADMIN_ROLE(), vm.addr(deployerPrivateKey)) == false);
        assert(l1LiskToken.hasRole(l1LiskToken.BURNER_ROLE(), vm.addr(deployerPrivateKey)) == false);
        assert(l1LiskToken.hasRole(l1LiskToken.DEFAULT_ADMIN_ROLE(), ownerAddress) == true);
        assert(l1LiskToken.hasRole(l1LiskToken.BURNER_ROLE(), ownerAddress) == false);
        assert(l1LiskToken.balanceOf(ownerAddress) == 0);

        console2.log("Simulation: L1 Lisk token successfully deployed!");
        console2.log("Simulation: L1 Lisk token address: %s", address(l1LiskToken));

        // write L1LiskToken address to l1addresses.json
        Utils.L1AddressesConfig memory l1AddressesConfig;
        l1AddressesConfig.L1LiskToken = address(l1LiskToken);
        utils.writeL1AddressesFile(l1AddressesConfig);
    }
}
