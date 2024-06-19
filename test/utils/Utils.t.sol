// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2 } from "forge-std/Test.sol";
import { Utils } from "script/contracts/Utils.sol";

contract UtilsTest is Test {
    function test_readAndWriteL1AddressesFile() public {
        Utils utils = new Utils();

        Utils.L1AddressesConfig memory config =
            Utils.L1AddressesConfig({ L1LiskToken: address(0x1), L1VestingWalletImplementation: address(0x2) });

        utils.writeL1AddressesFile(config);

        Utils.L1AddressesConfig memory configReadFromFile = utils.readL1AddressesFile();

        assertEq(configReadFromFile.L1LiskToken, config.L1LiskToken);
        assertEq(configReadFromFile.L1VestingWalletImplementation, config.L1VestingWalletImplementation);
    }

    function test_readAndWriteL2AddressesFile() public {
        Utils utils = new Utils();

        Utils.L2AddressesConfig memory config = Utils.L2AddressesConfig({
            L2ClaimContract: address(0x01),
            L2ClaimImplementation: address(0x02),
            L2Governor: address(0x03),
            L2GovernorImplementation: address(0x04),
            L2LiskToken: address(0x05),
            L2LockingPosition: address(0x06),
            L2LockingPositionImplementation: address(0x07),
            L2Reward: address(0x09),
            L2RewardImplementation: address(0x10),
            L2Staking: address(0x11),
            L2StakingImplementation: address(0x12),
            L2TimelockController: address(0x13),
            L2VestingWalletImplementation: address(0x14),
            L2VotingPower: address(0x15),
            L2VotingPowerImplementation: address(0x16)
        });

        utils.writeL2AddressesFile(config);

        Utils.L2AddressesConfig memory configReadFromFile = utils.readL2AddressesFile();

        assertEq(configReadFromFile.L2ClaimContract, config.L2ClaimContract);
        assertEq(configReadFromFile.L2Governor, config.L2Governor);
        assertEq(configReadFromFile.L2GovernorImplementation, config.L2GovernorImplementation);
        assertEq(configReadFromFile.L2LiskToken, config.L2LiskToken);
        assertEq(configReadFromFile.L2LockingPosition, config.L2LockingPosition);
        assertEq(configReadFromFile.L2LockingPositionImplementation, config.L2LockingPositionImplementation);
        assertEq(configReadFromFile.L2Reward, config.L2Reward);
        assertEq(configReadFromFile.L2RewardImplementation, config.L2RewardImplementation);
        assertEq(configReadFromFile.L2Staking, config.L2Staking);
        assertEq(configReadFromFile.L2StakingImplementation, config.L2StakingImplementation);
        assertEq(configReadFromFile.L2TimelockController, config.L2TimelockController);
        assertEq(configReadFromFile.L2VestingWalletImplementation, config.L2VestingWalletImplementation);
        assertEq(configReadFromFile.L2VotingPower, config.L2VotingPower);
        assertEq(configReadFromFile.L2VotingPowerImplementation, config.L2VotingPowerImplementation);
    }

    function test_readMerkleRootFile() public {
        vm.setEnv("NETWORK", "testnet");

        Utils utils = new Utils();
        assertEq(
            vm.toString(utils.readMerkleRootFile().merkleRoot),
            "0x92ebb53b56a4136bfd1ea09a7e2d64f3dc3165020516f6ee5e17aee9f65a7f3b"
        );
    }

    function test_readWriteVestingWalletsFile() public {
        vm.setEnv("NETWORK", "testnet");

        Utils utils = new Utils();

        Utils.VestingWallet[] memory vestingWallets = new Utils.VestingWallet[](2);
        vestingWallets[0] = Utils.VestingWallet({ name: "wallet1", vestingWalletAddress: address(0x1) });
        vestingWallets[1] = Utils.VestingWallet({ name: "wallet2", vestingWalletAddress: address(0x2) });

        utils.writeVestingWalletsFile(vestingWallets, "l1");

        assertEq(utils.readVestingWalletAddress("wallet1", "l1"), address(0x1));
        assertEq(utils.readVestingWalletAddress("wallet2", "l1"), address(0x2));
    }

    function test_readVestingAddress() public {
        vm.setEnv("NETWORK", "testnet");

        Utils utils = new Utils();

        address team1Address = address(0xE1F2e7E049A8484479f14aF62d831f70476fCDBc);
        address team2Address = address(0x74A898371f058056cD94F5D2D24d5d0BFacD3EB9);

        assertEq(utils.readVestingAddress("team1Address", "l1"), team1Address);
        assertEq(utils.readVestingAddress("team2Address", "l1"), team2Address);
    }

    function test_readAccountsFile() public {
        vm.setEnv("NETWORK", "devnet");

        Utils utils = new Utils();

        Utils.Accounts memory accountsReadFromFile = utils.readAccountsFile("accounts_1.json");

        assertEq(accountsReadFromFile.l1Addresses[0].addr, address(0xe708A1b91dDC44576731f7fEb4e193F48923Abba));
        assertEq(accountsReadFromFile.l1Addresses[0].amount, 2000000000000000000000);
        assertEq(accountsReadFromFile.l2Addresses[0].addr, address(0x396DF972a284bA7F5a8BEc2D9B9eC2377a099215));
        assertEq(accountsReadFromFile.l2Addresses[0].amount, 3000000000000000000000);
    }
}
