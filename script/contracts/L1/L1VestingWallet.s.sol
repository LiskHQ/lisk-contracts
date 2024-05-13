// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L1VestingWallet } from "src/L1/L1VestingWallet.sol";
import "script/contracts/Utils.sol";

/// @title L1VestingWalletScript - L1 Vesting Wallet contract deployment script
/// @notice This contract is used to deploy L1 Vesting Wallet contract.
contract L1VestingWalletScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 addresses.
    Utils utils;

    /// @notice Stating the network layer of this script
    string public constant layer = "L1";

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L1 Vesting Wallet contract.
    function run() public {
        Utils.L1AddressesConfig memory l1AddressesConfig = utils.readL1AddressesFile();

        // Deployer's private key. Owner of the L1 Vesting Wallet. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L1VestingWallet Implementation...");

        // deploy L1VestingWallet implementation contract
        vm.startBroadcast(deployerPrivateKey);
        L1VestingWallet l1VestingWalletImplementation = new L1VestingWallet();
        vm.stopBroadcast();
        assert(address(l1VestingWalletImplementation) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(
            l1VestingWalletImplementation.proxiableUUID()
                == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );

        // owner Address, the ownership of L2VestingWallet Proxy Contract is transferred to after deployment
        address ownerAddress = vm.envAddress("L1_VESTING_WALLET_OWNER_ADDRESS");
        console2.log("L1 VestingWallet contract owner address: %s (after ownership will be accepted)", ownerAddress);

        Utils.VestingPlan[] memory plans = utils.readVestingPlansFile(layer);
        Utils.VestingWallet[] memory vestingWallets = new Utils.VestingWallet[](plans.length);
        for (uint256 i; i < plans.length; i++) {
            Utils.VestingPlan memory vestingPlan = plans[i];
            address beneficiary = utils.readVestingAddress(vestingPlan.beneficiaryAddressTag, layer);

            console2.log("Deploying Vesting Plan #%d: %s to: %s", i, vestingPlan.name, beneficiary);
            vm.startBroadcast(deployerPrivateKey);
            ERC1967Proxy l1VestingWalletProxy = new ERC1967Proxy(
                address(l1VestingWalletImplementation),
                abi.encodeWithSelector(
                    l1VestingWalletImplementation.initialize.selector,
                    beneficiary,
                    vestingPlan.startTimestamp,
                    uint64(vestingPlan.durationDays * 1 days),
                    vestingPlan.name,
                    ownerAddress
                )
            );
            vm.stopBroadcast();
            assert(address(l1VestingWalletProxy) != address(0));

            // wrap in ABI to support easier calls
            L1VestingWallet l1VestingWallet = L1VestingWallet(payable(address(l1VestingWalletProxy)));
            assert(keccak256(bytes(l1VestingWallet.name())) == keccak256(bytes(vestingPlan.name)));
            assert(l1VestingWallet.start() == vestingPlan.startTimestamp);
            assert(l1VestingWallet.duration() == uint256(vestingPlan.durationDays * 1 days));
            assert(keccak256(bytes(l1VestingWallet.version())) == keccak256(bytes("1.0.0")));

            // Owner automatically transferred to beneficiary during initialize
            assert(l1VestingWallet.owner() == beneficiary);

            vestingWallets[i] = Utils.VestingWallet(vestingPlan.name, address(l1VestingWalletProxy));
        }

        // Write all Vesting Contract addresses to vestingWallets_L1.json
        utils.writeVestingWalletsFile(vestingWallets, layer);

        // write L1VestingWallet address to l1addresses.json
        l1AddressesConfig.L1VestingWalletImplementation = address(l1VestingWalletImplementation);
        utils.writeL1AddressesFile(l1AddressesConfig);
    }
}
