// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { Vm } from "forge-std/Vm.sol";
import { OptimismMintableERC20Factory } from "@optimism/universal/OptimismMintableERC20Factory.sol";
import { OptimismMintableERC20 } from "@optimism/universal/OptimismMintableERC20.sol";

/// @title OptimismMintableERC20Deployment - OptimismMintableERC20 deployment script
/// @notice This contract is used to deploy generic OptimismMintableERC20 contracts.
///         using the OptimismMintableERC20Factory
contract OptimismMintableERC20Deployment is Script {
    address constant FACTORY_PREDEPLOY = 0x4200000000000000000000000000000000000012;
    OptimismMintableERC20Factory erc20Factory;

    function setUp() public {
        erc20Factory = OptimismMintableERC20Factory(FACTORY_PREDEPLOY);
    }

    /// @notice This function deploys an OptimismMintableERC20 contract.
    function run(address _remoteToken, string memory _name, string memory _symbol, uint8 _decimals) public {
        console2.log("Deploying", _name, " contract on Lisk...");
        console2.log("   remoteToken =", _remoteToken);
        console2.log("   name =", _name);
        console2.log("   symbol =", _symbol);
        console2.log("   decimals =", _decimals);

        // Deployer's private key set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.recordLogs();
        vm.startBroadcast(deployerPrivateKey);
        erc20Factory.createOptimismMintableERC20WithDecimals(_remoteToken, _name, _symbol, _decimals);
        vm.stopBroadcast();

        Vm.Log[] memory logs = vm.getRecordedLogs();
        address l2TokenAddress = address(uint160(uint256(logs[1].topics[1])));

        console2.log(_name, " successfully deployed to", l2TokenAddress);
        OptimismMintableERC20 l2Token = OptimismMintableERC20(l2TokenAddress);

        assert(_remoteToken == l2Token.remoteToken());
        assert(keccak256(abi.encodePacked((_name))) == keccak256(abi.encodePacked((l2Token.name()))));
        assert(keccak256(abi.encodePacked((_symbol))) == keccak256(abi.encodePacked((l2Token.symbol()))));
        assert(_decimals == l2Token.decimals());
    }
}
