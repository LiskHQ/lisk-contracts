// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2LockingPosition } from "src/L2/L2LockingPosition.sol";
import "script/Utils.sol";

/// @title IL2Staking
/// @notice Interface for L2 Staking contract. Used to initialize Staking contract.
interface IL2Staking {
    function initializeLockingPosition(address lockingPositionContract) external;
    function lockingPositionContract() external view returns (address);
}

/// @title L2LockingPositionScript - L2 Locking Position contract deployment script
/// @notice This contract is used to deploy L2 Locking Position contract.
contract L2LockingPositionScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2 Locking Position contract.
    function run() public {
        // Deployer's private key. Owner of the L2 Locking Position. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L2 Locking Position...");

        // get L2Staking contract address
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile();
        assert(l2AddressesConfig.L2Staking != address(0));
        console2.log("L2 Staking address: %s", l2AddressesConfig.L2Staking);
        IL2Staking stakingContract = IL2Staking(l2AddressesConfig.L2Staking);

        // Get L2LockingPosition contract owner address. Ownership is transferred to this address after deployment.
        address ownerAddress = vm.envAddress("L2_STAKING_OWNER_ADDRESS");
        console2.log("L2 Locking Position future owner address: %s", ownerAddress);

        // deploy L2LockingPosition implementation contract
        vm.startBroadcast(deployerPrivateKey);
        L2LockingPosition l2LockingPositionImplementation = new L2LockingPosition();
        vm.stopBroadcast();
        assert(address(l2LockingPositionImplementation) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(
            l2LockingPositionImplementation.proxiableUUID()
                == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );

        // deploy L2LockingPosition proxy contract and at the same time initialize the proxy contract (calls the
        // initialize function in L2LockingPosition)
        vm.startBroadcast(deployerPrivateKey);
        ERC1967Proxy l2LockingPositionProxy = new ERC1967Proxy(
            address(l2LockingPositionImplementation),
            abi.encodeWithSelector(l2LockingPositionImplementation.initialize.selector, l2AddressesConfig.L2Staking)
        );
        vm.stopBroadcast();
        assert(address(l2LockingPositionProxy) != address(0));

        // wrap in ABI to support easier calls
        L2LockingPosition l2LockingPosition = L2LockingPosition(payable(address(l2LockingPositionProxy)));
        assert(l2LockingPosition.owner() == vm.addr(deployerPrivateKey));
        assert(l2LockingPosition.stakingContract() == l2AddressesConfig.L2Staking);

        // initialize the L2Staking contract by calling initializeLockingPosition of the L2Staking contract
        vm.startBroadcast(deployerPrivateKey);
        stakingContract.initializeLockingPosition(address(l2LockingPosition));
        vm.stopBroadcast();
        assert(stakingContract.lockingPositionContract() == address(l2LockingPosition));

        // transfer ownership of the L2LockingPosition contract to the owner address
        /*vm.startBroadcast(deployerPrivateKey);
        l2LockingPosition.transferOwnership(ownerAddress);
        vm.stopBroadcast();
        assert(l2LockingPosition.owner() == ownerAddress);*/

        console2.log("L2 L2LockingPosition (implementation) address: %s", address(l2LockingPositionImplementation));
        console2.log("L2 L2LockingPosition (proxy) address: %s", address(l2LockingPosition));
        console2.log("L2 L2LockingPosition owner address: %s", l2LockingPosition.owner());

        // write L2 Locking Position address to l2addresses.json
        l2AddressesConfig.L2LockingPositionImplementation = address(l2LockingPositionImplementation);
        l2AddressesConfig.L2LockingPosition = address(l2LockingPosition);
        utils.writeL2AddressesFile(l2AddressesConfig);
    }
}
