// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { L1LiskToken } from "src/L1/L1LiskToken.sol";
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

/// @title TransferFunds2ndBatchScript - L1 Lisk token transfer script
/// @notice This contract is used to transfer all deployer's L1 Lisk tokens to a different addresses on L1 and L2
///         networks. When sending tokens to the L2 network, the L1 Standard Bridge contract is used.
contract TransferFunds2ndBatchScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function transfers L1 Lisk tokens to a different addresses on L1 and L2 networks.
    /// @dev This function first sends deployer's L1 Lisk tokens to all L1 addresses specified in the accounts_2.json
    ///      file. After it approves L1 Standard Bridge to transfer all remaining deployer's L1 Lisk tokens to the L2
    ///      network. It does this in two steps. First it sends tokens to all L2 addresses specified in the
    ///      accounts_2.json file. After it transfers all remaining tokens to the L2 Claim contract.
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address l1StandardBridge = vm.envAddress("L1_STANDARD_BRIDGE_ADDR");
        assert(l1StandardBridge != address(0));

        console2.log("Transferring Lisk tokens from L1 to a different addresses on L1 and L2 networks...");

        // get L1LiskToken contract address
        Utils.L1AddressesConfig memory l1AddressesConfig = utils.readL1AddressesFile();
        assert(l1AddressesConfig.L1LiskToken != address(0));
        console2.log("L1 Lisk token address: %s", l1AddressesConfig.L1LiskToken);

        // get L2LiskToken and L2Claim contracts addresses
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile();
        assert(l2AddressesConfig.L2LiskToken != address(0));
        assert(l2AddressesConfig.L2ClaimContract != address(0));
        console2.log("L2 Lisk token address: %s", l2AddressesConfig.L2LiskToken);
        console2.log("L2 Claim contract address: %s", l2AddressesConfig.L2ClaimContract);

        // get accounts to which L1 Lisk tokens will be transferred
        Utils.Accounts memory accounts = utils.readAccountsFile("accounts_2.json");
        console2.log(
            "Number of L1 and L2 addresses to which L1 Lisk tokens will be transferred: %s",
            accounts.l1Addresses.length + accounts.l2Addresses.length
        );

        // get L1LiskToken and L1StandardBridge contracts instances
        L1LiskToken l1LiskToken = L1LiskToken(address(l1AddressesConfig.L1LiskToken));
        IL1StandardBridge bridge = IL1StandardBridge(l1StandardBridge);

        console2.log("Sending L1 Lisk tokens to %s L1 addresses...", accounts.l1Addresses.length);

        // send L1 Lisk tokens to all L1 addresses
        for (uint256 i = 0; i < accounts.l1Addresses.length; i++) {
            console2.log(
                "Sending %s L1 Lisk tokens to L1 address: %s",
                accounts.l1Addresses[i].amount,
                accounts.l1Addresses[i].addr
            );
            vm.startBroadcast(deployerPrivateKey);
            l1LiskToken.transfer(accounts.l1Addresses[i].addr, accounts.l1Addresses[i].amount);
            vm.stopBroadcast();
        }

        for (uint256 i = 0; i < accounts.l1Addresses.length; i++) {
            assert(l1LiskToken.balanceOf(accounts.l1Addresses[i].addr) == accounts.l1Addresses[i].amount);
        }

        console2.log("L1 Lisk tokens successfully sent to all L1 addresses!");

        // balance of L1 Lisk tokens before sending them to L2 addresses
        uint256 balanceBeforeDeployer = l1LiskToken.balanceOf(vm.addr(deployerPrivateKey));
        uint256 balanceBeforeBridge = l1LiskToken.balanceOf(l1StandardBridge);

        console2.log(
            "Approving all remaining L1 Lisk tokens to be transfered by L1 Standard Bridge to the L2 network: %s",
            balanceBeforeDeployer
        );
        vm.startBroadcast(deployerPrivateKey);
        l1LiskToken.approve(address(bridge), balanceBeforeDeployer);
        vm.stopBroadcast();

        assert(l1LiskToken.allowance(vm.addr(deployerPrivateKey), address(bridge)) == balanceBeforeDeployer);

        console2.log("L1 Lisk tokens successfully approved to be transfered by L1 Standard Bridge!");

        console2.log("Sending L1 Lisk tokens to %s L2 addresses...", accounts.l2Addresses.length);

        // send L1 Lisk tokens to all L2 addresses
        for (uint256 i = 0; i < accounts.l2Addresses.length; i++) {
            console2.log(
                "Sending %s L1 Lisk tokens to L2 address: %s",
                accounts.l2Addresses[i].amount,
                accounts.l2Addresses[i].addr
            );
            vm.startBroadcast(deployerPrivateKey);
            bridge.depositERC20To(
                l1AddressesConfig.L1LiskToken,
                l2AddressesConfig.L2LiskToken,
                accounts.l2Addresses[i].addr,
                accounts.l2Addresses[i].amount,
                1000000,
                ""
            );
            vm.stopBroadcast();
        }

        // total amount of tokens sent to L2 addresses
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < accounts.l2Addresses.length; i++) {
            totalAmount += accounts.l2Addresses[i].amount;
        }
        assert(l1LiskToken.balanceOf(vm.addr(deployerPrivateKey)) == balanceBeforeDeployer - totalAmount);

        console2.log("L1 Lisk tokens successfully sent to all L2 addresses!");

        console2.log("Transferring all remaining L1 Lisk tokens to the L2 Claim contract...");

        uint256 amountClaimContract = balanceBeforeDeployer - totalAmount;
        console2.log("Sending %s L1 Lisk tokens to the L2 Claim contract...", amountClaimContract);

        vm.startBroadcast(deployerPrivateKey);
        bridge.depositERC20To(
            l1AddressesConfig.L1LiskToken,
            l2AddressesConfig.L2LiskToken,
            l2AddressesConfig.L2ClaimContract,
            amountClaimContract,
            1000000,
            ""
        );
        vm.stopBroadcast();

        assert(l1LiskToken.balanceOf(vm.addr(deployerPrivateKey)) == 0);
        assert(l1LiskToken.balanceOf(l1StandardBridge) == balanceBeforeDeployer + balanceBeforeBridge);

        console2.log("L1 Lisk tokens successfully transferred to the L2 Claim contract!");
    }
}
