// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Script, console2 } from "forge-std/Script.sol";
import { L1LiskToken } from "src/L1/L1LiskToken.sol";
import "script/Utils.sol";

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

/// @title TransferFundsScript - L1 Lisk token transfer script
/// @notice This contract is used to transfer all deployer's L1 Lisk tokens to the L2 Claim contract via L1 Standard
/// Bridge.
contract TransferFundsScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function transfers L1 Lisk tokens to the L2 Claim contract.
    /// @dev This function first approves L1 Standard Bridge to transfer all deployer's L1 Lisk tokens and then calls
    /// the depositERC20To function of the L1 Standard Bridge contract to transfer all deployer's L1 Lisk tokens to the
    /// L2 Claim contract.
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address l1StandardBridge = vm.envAddress("L1_STANDARD_BRIDGE_ADDR");

        console2.log("Transferring Lisk tokens from L1 to L2 Claim contract...");

        // get L1LiskToken contract address
        Utils.L1AddressesConfig memory l1AddressesConfig = utils.readL1AddressesFile();
        console2.log("L1 Lisk token address: %s", l1AddressesConfig.L1LiskToken);

        // get L2LiskToken and L2Claim contracts addresses
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile();
        console2.log("L2 Lisk token address: %s", l2AddressesConfig.L2LiskToken);
        console2.log("L2 Claim contract address: %s", l2AddressesConfig.L2ClaimContract);

        // get L1LiskToken and L1StandardBridge contracts instances
        L1LiskToken l1LiskToken = L1LiskToken(address(l1AddressesConfig.L1LiskToken));
        IL1StandardBridge bridge = IL1StandardBridge(l1StandardBridge);

        console2.log(
            "Approving L1 Lisk tokens to be transfered by L1 Standard Bridge to the L2 Lisk token contract: %s",
            l1LiskToken.balanceOf(vm.addr(deployerPrivateKey))
        );
        vm.startBroadcast(deployerPrivateKey);
        l1LiskToken.approve(address(bridge), l1LiskToken.balanceOf(vm.addr(deployerPrivateKey)));
        vm.stopBroadcast();

        assert(
            l1LiskToken.allowance(vm.addr(deployerPrivateKey), address(bridge))
                == l1LiskToken.balanceOf(vm.addr(deployerPrivateKey))
        );

        console2.log("Transferring all L1 Lisk tokens to the L2 Claim contract...");
        vm.startBroadcast(deployerPrivateKey);
        bridge.depositERC20To(
            l1AddressesConfig.L1LiskToken,
            l2AddressesConfig.L2LiskToken,
            l2AddressesConfig.L2ClaimContract,
            l1LiskToken.balanceOf(vm.addr(deployerPrivateKey)),
            1000000,
            ""
        );
        vm.stopBroadcast();

        assert(l1LiskToken.balanceOf(vm.addr(deployerPrivateKey)) == 0);
        assert(l1LiskToken.balanceOf(l1StandardBridge) == 200000000 * 10 ** 18);

        console2.log("L1 Lisk tokens successfully transferred to the L2 Claim contract!");
    }
}
