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
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    function run() public {
        Utils.L1AddressesConfig memory addressL1Cfg = utils.readL1AddressesFile();
        console2.log("L1 Lisk token address: %s", addressL1Cfg.L1LiskToken);

        Utils.L2AddressesConfig memory addressL2Cfg = utils.readL2AddressesFile();
        console2.log("L2 Lisk token address: %s", addressL2Cfg.L2LiskToken);
        console2.log("L2 Claim contract address: %s", addressL2Cfg.L2ClaimContract);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // transfer all Lisk tokens from deployer to a bridged Lisk token contract
        vm.startBroadcast(deployerPrivateKey);
        L1LiskToken l1LiskToken = L1LiskToken(address(addressL1Cfg.L1LiskToken));
        IL1StandardBridge bridge = IL1StandardBridge(address(0x4200000000000000000000000000000000000010));

        console2.log(
            "Approving deployers L1 Lisk tokens to be transfered by L1 Standard Bridge: %s",
            l1LiskToken.balanceOf(vm.addr(deployerPrivateKey))
        );
        l1LiskToken.approve(address(bridge), l1LiskToken.balanceOf(vm.addr(deployerPrivateKey)));
        bridge.depositERC20To(
            addressL1Cfg.L1LiskToken,
            addressL2Cfg.L2LiskToken,
            addressL2Cfg.L2ClaimContract,
            l1LiskToken.balanceOf(vm.addr(deployerPrivateKey)),
            1000000,
            ""
        );
        vm.stopBroadcast();
    }
}
