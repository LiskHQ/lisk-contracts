// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Script, console2 } from "forge-std/Script.sol";
import { L1LiskToken } from "src/L1/L1LiskToken.sol";
import "script/Utils.sol";

interface IL1StandardBridge {
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

contract TransferFundsScript is Script {
    address private constant L1_STANDARD_BRIDGE = 0xFBb0621E0B23b5478B630BD55a5f21f67730B0F1;
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

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
        IL1StandardBridge bridge = IL1StandardBridge(L1_STANDARD_BRIDGE);

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
        assert(l1LiskToken.balanceOf(L1_STANDARD_BRIDGE) == 200000000 * 10 ** 18);

        console2.log("L1 Lisk tokens successfully transferred to the L2 Claim contract!");
    }
}
