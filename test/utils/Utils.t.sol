// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2 } from "forge-std/Test.sol";
import { Utils } from "script/contracts/Utils.sol";

contract UtilsTest is Test {
    Utils utils;

    function setUp() public {
        vm.setEnv("NETWORK", "testnet");

        utils = new Utils();
    }

    function test_readAndWriteL1AddressesFile() public {
        Utils.L1AddressesConfig memory config =
            Utils.L1AddressesConfig({ L1LiskToken: address(0x1), L1VestingWalletImplementation: address(0x2) });

        utils.writeL1AddressesFile(config, "./l1Addresses.json");

        Utils.L1AddressesConfig memory configReadFromFile = utils.readL1AddressesFile("./l1Addresses.json");

        assertEq(configReadFromFile.L1LiskToken, config.L1LiskToken);
        assertEq(configReadFromFile.L1VestingWalletImplementation, config.L1VestingWalletImplementation);
    }

    function test_readAndWriteL2AddressesFile() public {
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

        utils.writeL2AddressesFile(config, "./l2Addresses.json");

        Utils.L2AddressesConfig memory configReadFromFile = utils.readL2AddressesFile("./l2addresses.json");

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
        assertEq(
            vm.toString(utils.readMerkleRootFile().merkleRoot),
            "0x92ebb53b56a4136bfd1ea09a7e2d64f3dc3165020516f6ee5e17aee9f65a7f3b"
        );
    }

    function test_readWriteVestingWalletsFile() public {
        Utils.VestingWallet[] memory vestingWallets = new Utils.VestingWallet[](2);
        vestingWallets[0] = Utils.VestingWallet({ name: "wallet1", vestingWalletAddress: address(0x1) });
        vestingWallets[1] = Utils.VestingWallet({ name: "wallet2", vestingWalletAddress: address(0x2) });

        utils.writeVestingWalletsFile(vestingWallets, "./vestingWallets.json");

        assertEq(utils.readVestingWalletAddress("wallet1", "./vestingWallets.json"), address(0x1));
        assertEq(utils.readVestingWalletAddress("wallet2", "./vestingWallets.json"), address(0x2));
    }

    function test_readVestingAddress() public {
        address team1Address = address(0xE1F2e7E049A8484479f14aF62d831f70476fCDBc);
        address team2Address = address(0x74A898371f058056cD94F5D2D24d5d0BFacD3EB9);

        assertEq(utils.readVestingAddress("team1Address", "L1"), team1Address);
        assertEq(utils.readVestingAddress("team2Address", "L1"), team2Address);
    }

    function test_readAccountsFile() public {
        Utils.Accounts memory accountsReadFromFile1 = utils.readAccountsFile("accounts_1.json");

        assertEq(accountsReadFromFile1.l1Addresses.length, 6);
        assertEq(accountsReadFromFile1.l1Addresses[0].addr, address(0x0a5bFdBbF7aDe3042da107EaA726d5A71D2DcbaD));
        assertEq(accountsReadFromFile1.l1Addresses[0].amount, 2000000000000000000000000);
        assertEq(accountsReadFromFile1.l2Addresses.length, 0);

        Utils.Accounts memory accountsReadFromFile2 = utils.readAccountsFile("accounts_2.json");
        assertEq(accountsReadFromFile2.l1Addresses.length, 0);
        assertEq(accountsReadFromFile2.l2Addresses.length, 1);
        assertEq(accountsReadFromFile2.l2Addresses[0].addr, address(0x473BbFd3097D597d14466EF19519f406D6f9202d));
        assertEq(accountsReadFromFile2.l2Addresses[0].amount, 51000000000000000000);
    }
}
