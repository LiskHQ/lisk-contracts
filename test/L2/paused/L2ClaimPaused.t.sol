// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Test, console, stdJson } from "forge-std/Test.sol";
import { L2Claim, ED25519Signature, MultisigKeys } from "src/L2/L2Claim.sol";
import { L2ClaimPaused } from "src/L2/paused/L2ClaimPaused.sol";
import { Utils } from "script/contracts/Utils.sol";
import { MockERC20 } from "../../mock/MockERC20.sol";

contract L2ClaimV2Mock is L2Claim {
    function initializeV2(uint256 _recoverPeriodTimestamp) public reinitializer(3) {
        recoverPeriodTimestamp = _recoverPeriodTimestamp;
        version = "2.0.0";
    }

    function onlyV2() public pure returns (string memory) {
        return "Hello from V2";
    }
}

contract L2ClaimPausedTest is Test {
    using stdJson for string;

    ERC20 public lsk;
    L2Claim public l2Claim;
    L2Claim public l2ClaimImplementation;
    L2ClaimPaused l2ClaimPausedProxy;
    Utils public utils;
    string public MerkleRootJson;
    Utils.MerkleRoot public merkleRoot;

    // get MerkleRoot struct
    function getMerkleRoot() internal view returns (Utils.MerkleRoot memory) {
        return abi.decode(MerkleRootJson.parseRaw("."), (Utils.MerkleRoot));
    }

    function setUp() public {
        utils = new Utils();
        lsk = new MockERC20(10_000_000 * 10 ** 18);

        // read Merkle Root in a json format from a file
        string memory rootPath = string.concat(vm.projectRoot(), "/test/L2/data");
        MerkleRootJson = vm.readFile(string.concat(rootPath, "/merkle-root.json"));

        // get MerkleRoot struct
        merkleRoot = getMerkleRoot();

        // deploy L2Claim Implementation contract
        l2ClaimImplementation = new L2Claim();

        // deploy L2Claim contract via Proxy and initialize it at the same time
        l2Claim = L2Claim(
            address(
                new ERC1967Proxy(
                    address(l2ClaimImplementation),
                    abi.encodeWithSelector(
                        l2Claim.initialize.selector, address(lsk), merkleRoot.merkleRoot, block.timestamp + 730 days
                    )
                )
            )
        );
        assertEq(address(l2Claim.l2LiskToken()), address(lsk));
        assertEq(l2Claim.merkleRoot(), merkleRoot.merkleRoot);

        // deploy L2ClaimPaused contract
        L2ClaimPaused l2ClaimPaused = new L2ClaimPaused();

        // upgrade Claim contract to L2ClaimPaused contract
        l2Claim.upgradeToAndCall(
            address(l2ClaimPaused), abi.encodeWithSelector(l2ClaimPaused.initializePaused.selector)
        );

        // wrap L2Claim Proxy with new contract
        l2ClaimPausedProxy = L2ClaimPaused(address(l2Claim));

        // LSK Token and MerkleRoot unchanged
        assertEq(address(l2ClaimPausedProxy.l2LiskToken()), address(lsk));
        assertEq(l2ClaimPausedProxy.merkleRoot(), merkleRoot.merkleRoot);

        // version of L2Claim changed to 1.0.0-paused
        assertEq(l2ClaimPausedProxy.version(), "1.0.0-paused");

        // assure cannot re-reinitialize
        vm.expectRevert();
        l2ClaimPausedProxy.initializePaused();
    }

    function test_ClaimRegularAccount_Paused() public {
        vm.expectRevert(L2ClaimPaused.ClaimIsPaused.selector);
        l2ClaimPausedProxy.claimRegularAccount(new bytes32[](0), bytes32(0), 0, address(0), ED25519Signature(0, 0));
    }

    function test_ClaimMultisigAccount_Paused() public {
        vm.expectRevert(L2ClaimPaused.ClaimIsPaused.selector);
        l2ClaimPausedProxy.claimMultisigAccount(
            new bytes32[](0),
            bytes20(0),
            0,
            MultisigKeys(new bytes32[](0), new bytes32[](0)),
            address(0),
            new ED25519Signature[](0)
        );
    }

    function test_UpgradeToAndCall_CanUpgradeFromPausedContractToNewContract() public {
        L2ClaimV2Mock l2ClaimV2Implementation = new L2ClaimV2Mock();

        // change recover period to 20 years
        uint256 newRecoverPeriodTimestamp = block.timestamp + 365 days * 20;

        // upgrade Claim contract to L2ClaimV2Mock contract
        l2Claim.upgradeToAndCall(
            address(l2ClaimV2Implementation),
            abi.encodeWithSelector(l2ClaimV2Implementation.initializeV2.selector, newRecoverPeriodTimestamp)
        );

        // wrap L2Claim Proxy with new contract
        L2ClaimV2Mock l2ClaimV2 = L2ClaimV2Mock(address(l2Claim));

        // LSK Token and MerkleRoot unchanged
        assertEq(address(l2ClaimV2.l2LiskToken()), address(lsk));
        assertEq(l2ClaimV2.merkleRoot(), merkleRoot.merkleRoot);

        // version of L2Claim changed to 2.0.0
        assertEq(l2ClaimV2.version(), "2.0.0");

        // new Timestamp changed by reinitializer
        assertEq(l2ClaimV2.recoverPeriodTimestamp(), newRecoverPeriodTimestamp);

        // new function introduced
        assertEq(l2ClaimV2.onlyV2(), "Hello from V2");

        // assure cannot re-reinitialize
        vm.expectRevert();
        l2ClaimV2.initializeV2(newRecoverPeriodTimestamp + 1);
    }
}
