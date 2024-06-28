// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2 } from "forge-std/Test.sol";
import { Utils } from "script/contracts/Utils.sol";

contract UtilsTest is Test {
    Utils utils;
    string network;
    string salt;

    function setUp() public virtual {
        network = "testnet";
        salt = "salty_the_salt";
        vm.setEnv("DETERMINISTIC_ADDRESS_SALT", salt);
        vm.setEnv("NETWORK", network);
        utils = new Utils();
    }

    function test_readAndWriteL1AddressesFile() public {
        Utils.L1AddressesConfig memory config =
            Utils.L1AddressesConfig({ L1LiskToken: address(0x1), L1VestingWalletImplementation: address(0x2) });

        utils.writeL1AddressesFile(config, "./l1Addresses.json");

        Utils.L1AddressesConfig memory configReadFromFile = utils.readL1AddressesFile("./l1Addresses.json");

        assertEq(configReadFromFile.L1LiskToken, config.L1LiskToken);
        assertEq(configReadFromFile.L1VestingWalletImplementation, config.L1VestingWalletImplementation);

        vm.removeFile("./l1Addresses.json");
    }

    function test_readAndWriteL2AddressesFile() public {
        uint160 index = 1;
        Utils.L2AddressesConfig memory config = Utils.L2AddressesConfig({
            L2Airdrop: address(index++),
            L2ClaimContract: address(index++),
            L2ClaimImplementation: address(index++),
            L2ClaimPaused: address(index++),
            L2Governor: address(index++),
            L2GovernorImplementation: address(index++),
            L2GovernorPaused: address(index++),
            L2LiskToken: address(index++),
            L2LockingPosition: address(index++),
            L2LockingPositionImplementation: address(index++),
            L2LockingPositionPaused: address(index++),
            L2Reward: address(index++),
            L2RewardImplementation: address(index++),
            L2RewardPaused: address(index++),
            L2Staking: address(index++),
            L2StakingImplementation: address(index++),
            L2TimelockController: address(index++),
            L2VestingWalletImplementation: address(index++),
            L2VotingPower: address(index++),
            L2VotingPowerImplementation: address(index++),
            L2VotingPowerPaused: address(index++)
        });

        utils.writeL2AddressesFile(config, "./l2Addresses.json");

        Utils.L2AddressesConfig memory configReadFromFile = utils.readL2AddressesFile("./l2Addresses.json");

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

        vm.removeFile("./l2Addresses.json");
    }

    function test_readMerkleRootFile() public view {
        assertEq(
            vm.toString(utils.readMerkleRootFile("merkle-root.json").merkleRoot),
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

        vm.removeFile("./vestingWallets.json");
    }

    function test_readVestingAddress() public view {
        address team1Address = address(0xE1F2e7E049A8484479f14aF62d831f70476fCDBc);
        address team2Address = address(0x74A898371f058056cD94F5D2D24d5d0BFacD3EB9);

        assertEq(utils.readVestingAddress("team1Address", "L1"), team1Address);
        assertEq(utils.readVestingAddress("team2Address", "L1"), team2Address);
    }

    function test_readAccountsFile() public view {
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

    function test_readVestingPlansFile() public view {
        Utils.VestingPlan[] memory vestingPlans = utils.readVestingPlansFile("L1");

        assertEq(vestingPlans.length, 5);
        assertEq(vestingPlans[0].name, "Team I");
        assertEq(vestingPlans[0].beneficiaryAddressTag, "team1Address");
        assertEq(vestingPlans[0].startTimestamp, 1735689600);
        assertEq(vestingPlans[0].durationDays, 1461);
        assertEq(vestingPlans[0].amount, 5500000000000000000000000);
    }

    function test_getL1AddressesFilePath() public view {
        assertEq(
            utils.getL1AddressesFilePath(),
            string.concat(vm.projectRoot(), "/deployment/", network, "/l1addresses.json")
        );
    }

    function test_getL2AddressesFilePath() public view {
        assertEq(
            utils.getL2AddressesFilePath(),
            string.concat(vm.projectRoot(), "/deployment/", network, "/l2addresses.json")
        );
    }

    function test_getVestingWalletsFilePath() public view {
        assertEq(
            utils.getVestingWalletsFilePath("l1"),
            string.concat(vm.projectRoot(), "/deployment/", network, "/vestingWallets_l1.json")
        );
    }

    function test_getPreHashSalt() public view {
        string memory contractName = "contract";
        assertEq(utils.getPreHashedSalt(contractName), string.concat(salt, "_", contractName));
    }

    function test_getSalt() public view {
        string memory contractName = "contract";
        assertEq(utils.getSalt(contractName), keccak256(abi.encodePacked(string.concat(salt, "_", contractName))));
    }

    function test_getNetworkType() public view {
        assertEq(utils.getNetworkType(), network);
    }
}
