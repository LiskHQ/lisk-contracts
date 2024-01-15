// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2Claim } from "src/L2/L2Claim.sol";
import "script/Utils.sol";

/// @title L2ClaimScript - L2 Claim contract deployment script
/// @notice This contract is used to deploy L2 Claim contract and write its address to JSON file.
contract L2ClaimScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    /// @notice  Recover LSK Tokens after 2 years
    uint256 public constant RECOVER_PERIOD = 730 days;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2 Claim contract and writes its address to JSON file.
    function run() public {
        // Deployer's private key. Owner of the Claim contract which can perform upgrades. PRIVATE_KEY is set in .env
        // file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // DAO Address, will be used to receive unclaimed LSK after claim period
        address daoAddress = vm.envAddress("DAO_ADDRESS");

        // Owner Address, the ownership of L2Claim Proxy Contract is transferred to after deployment.
        address ownerAddress = vm.envAddress("L2_CLAIM_OWNER_ADDRESS");

        console2.log("Deploying L2 Claim contract...");

        // get L2LiskToken contract address
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile();
        console2.log("L2 Lisk token address: %s", l2AddressesConfig.L2LiskToken);

        // get MerkleTree details
        Utils.MerkleRoot memory merkleRoot = utils.readMerkleRootFile();
        console2.log("MerkleRoot: %s", vm.toString(merkleRoot.merkleRoot));

        // deploy L2Claim Implementation Contract
        vm.startBroadcast(deployerPrivateKey);
        L2Claim l2ClaimImplementation = new L2Claim();
        vm.stopBroadcast();

        assert(address(l2ClaimImplementation) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(l2ClaimImplementation.proxiableUUID() == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1));

        // deploy L2Claim Proxy Contract
        // at the same time initialize the proxy contract (calls the initialize function in L2Claim)
        vm.startBroadcast(deployerPrivateKey);
        ERC1967Proxy l2ClaimProxy = new ERC1967Proxy(
            address(l2ClaimImplementation),
            abi.encodeWithSelector(
                l2ClaimImplementation.initialize.selector,
                l2AddressesConfig.L2LiskToken,
                merkleRoot.merkleRoot,
                block.timestamp + RECOVER_PERIOD
            )
        );
        vm.stopBroadcast();
        assert(address(l2ClaimProxy) != address(0));

        // wrap in ABI to support easier calls
        L2Claim l2Claim = L2Claim(address(l2ClaimProxy));
        assert(address(l2Claim.l2LiskToken()) == l2AddressesConfig.L2LiskToken);
        assert(l2Claim.merkleRoot() == merkleRoot.merkleRoot);

        // Assign DAO Address
        vm.startBroadcast(deployerPrivateKey);
        l2Claim.setDAOAddress(daoAddress);
        vm.stopBroadcast();
        assert(l2Claim.daoAddress() == daoAddress);

        // Transfer ownership of L2Claim Proxy
        vm.startBroadcast(deployerPrivateKey);
        l2Claim.transferOwnership(ownerAddress);
        vm.stopBroadcast();
        assert(l2Claim.owner() == ownerAddress);

        console2.log("L2 Claim contract successfully deployed!");
        console2.log("L2 Claim (Implementation) address: %s", address(l2ClaimImplementation));
        console2.log("L2 Claim (Proxy) address: %s", address(l2Claim));
        console2.log("DAO Address of L2 Claim (Proxy) address: %s", l2Claim.daoAddress());
        console2.log("Owner of L2 Claim (Proxy) address: %s", l2Claim.owner());

        // write L2ClaimContract address to l2addresses.json
        l2AddressesConfig.L2ClaimImplementation = address(l2ClaimImplementation);
        l2AddressesConfig.L2ClaimContract = address(l2Claim);
        utils.writeL2AddressesFile(l2AddressesConfig);
    }
}
