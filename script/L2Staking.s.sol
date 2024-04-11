// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2Staking } from "src/L2/L2Staking.sol";
import "script/Utils.sol";

/// @title L2StakingScript - L2 Staking contract deployment script
/// @notice This contract is used to deploy L2 Staking contract.
contract L2StakingScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2 Staking contract.
    function run() public {
        // Deployer's private key. Owner of the L2 Staking. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L2 Staking...");

        // get L2LiskToken contract address
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile();
        assert(l2AddressesConfig.L2LiskToken != address(0));
        console2.log("L2 Lisk Token address: %s", l2AddressesConfig.L2LiskToken);

        // deploy L2Staking implementation contract
        vm.startBroadcast(deployerPrivateKey);
        L2Staking l2StakingImplementation = new L2Staking();
        vm.stopBroadcast();
        assert(address(l2StakingImplementation) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(
            l2StakingImplementation.proxiableUUID() == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );

        // deploy L2Staking proxy contract and at the same time initialize the proxy contract (calls the
        // initialize function in L2Staking)
        vm.startBroadcast(deployerPrivateKey);
        ERC1967Proxy l2StakingProxy = new ERC1967Proxy(
            address(l2StakingImplementation),
            abi.encodeWithSelector(l2StakingImplementation.initialize.selector, l2AddressesConfig.L2LiskToken)
        );
        vm.stopBroadcast();
        assert(address(l2StakingProxy) != address(0));

        // wrap in ABI to support easier calls
        L2Staking l2Staking = L2Staking(payable(address(l2StakingProxy)));
        assert(keccak256(bytes(l2Staking.version())) == keccak256(bytes("1.0.0")));
        assert(l2Staking.owner() == vm.addr(deployerPrivateKey));
        assert(l2Staking.l2LiskTokenContract() == l2AddressesConfig.L2LiskToken);
        assert(l2Staking.emergencyExitEnabled() == false);

        console2.log("L2 Staking (implementation) address: %s", address(l2StakingImplementation));
        console2.log("L2 Staking (proxy) address: %s", address(l2Staking));
        console2.log("L2 Staking owner address: %s", l2Staking.owner());

        // write L2 Staking address to l2addresses.json
        l2AddressesConfig.L2StakingImplementation = address(l2StakingImplementation);
        l2AddressesConfig.L2Staking = address(l2Staking);
        utils.writeL2AddressesFile(l2AddressesConfig);
    }
}
