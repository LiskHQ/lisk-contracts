// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { L1LiskToken } from "src/L1/L1LiskToken.sol";
import { IL2LiskToken } from "src/interfaces/L2/IL2LiskToken.sol";
import { IL2Reward } from "src/interfaces/L2/IL2Reward.sol";
import "script/contracts/Utils.sol";

/// @title IL1StandardBridge - L1 Standard Bridge interface
/// @notice This contract is used to transfer L1 Lisk tokens to the L2 network as L2 Lisk tokens.
interface IL1StandardBridge {
    /// Deposits L1 Lisk tokens into a target account on L2 network.
    /// @param _l1Token L1 Lisk token address.
    /// @param _l2Token L2 Lisk token address.
    /// @param _to Target account address on L2 network.
    /// @param _amount Amount of L1 Lisk tokens to be transferred.
    /// @param _minGasLimit Minimum gas limit for the deposit message on L2.
    /// @param _extraData Optional data to forward to L2. Data supplied here will not be used to
    ///                   execute any code on L2 and is only emitted as extra data for the
    ///                   convenience of off-chain tooling.
    function depositERC20To(
        address _l1Token,
        address _l2Token,
        address _to,
        uint256 _amount,
        uint32 _minGasLimit,
        bytes calldata _extraData
    )
        external;
}

/// @title FundVestingAndDAOScript
/// @notice This contract is used to transfer deployer's L1 Lisk tokens to the Vesting and DAO contract.
contract FundVestingAndDAOScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    /// @notice Stating the network layer of this script
    string public constant layer = "L2";

    /// @notice Amount of LSK tokens to be transferred to the DAO.
    uint256 public constant DAO_AMOUNT = 6_250_000 * 10 ** 18; // 6,250,000 LSK

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function transfers deployer's L1 Lisk tokens to the Vesting and DAO contract.
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address l1StandardBridge = vm.envAddress("L1_STANDARD_BRIDGE_ADDR");
        assert(l1StandardBridge != address(0));

        console2.log("Transferring deployer's L1 Lisk tokens to the Vesting and DAO contract...");

        // get L1LiskToken contract address
        Utils.L1AddressesConfig memory l1AddressesConfig = utils.readL1AddressesFile();
        assert(l1AddressesConfig.L1LiskToken != address(0));
        console2.log("L1 Lisk token address: %s", l1AddressesConfig.L1LiskToken);

        // get L2LiskToken contract address
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile();
        assert(l2AddressesConfig.L2LiskToken != address(0));
        console2.log("L2 Lisk token address: %s", l2AddressesConfig.L2LiskToken);

        // get L1LiskToken and L1StandardBridge contracts instances
        L1LiskToken l1LiskToken = L1LiskToken(address(l1AddressesConfig.L1LiskToken));
        IL1StandardBridge bridge = IL1StandardBridge(l1StandardBridge);

        Utils.VestingPlan[] memory plans = utils.readVestingPlansFile(layer);

        for (uint256 i; i < plans.length; i++) {
            Utils.VestingPlan memory vestingPlan = plans[i];
            address vestingWalletAddress = utils.readVestingWalletAddress(vestingPlan.name, layer);

            console2.log(
                "Transferring %s Lisk tokens to the vesting wallet %s ... on L2",
                vestingPlan.amount,
                vestingWalletAddress
            );

            // transfer L1 Lisk tokens to the vesting wallet on L2 network
            uint256 amount = vestingPlan.amount;
            vm.startBroadcast(deployerPrivateKey);
            l1LiskToken.approve(l1StandardBridge, amount);
            bridge.depositERC20To(
                address(l1LiskToken), address(l2AddressesConfig.L2LiskToken), vestingWalletAddress, amount, 1000000, ""
            );
            vm.stopBroadcast();
        }

        // get DAO address (L2TimelockController) contract address
        assert(l2AddressesConfig.L2TimelockController != address(0));
        console2.log("L2 Timelock Controller address: %s", l2AddressesConfig.L2TimelockController);

        // transfer L1 Lisk tokens to the DAO on L2 network
        vm.startBroadcast(deployerPrivateKey);
        l1LiskToken.approve(l1StandardBridge, DAO_AMOUNT);
        bridge.depositERC20To(
            address(l1LiskToken),
            address(l2AddressesConfig.L2LiskToken),
            l2AddressesConfig.L2TimelockController,
            DAO_AMOUNT,
            1000000,
            ""
        );
        vm.stopBroadcast();

        console2.log("Transferred deployer's L1 Lisk tokens to the Vesting and DAO contract.");
    }
}
