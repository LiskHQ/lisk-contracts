// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { PropertiesAsserts } from "properties/util/PropertiesHelper.sol";
import { L2LiskToken } from "src/L2/L2LiskToken.sol";
import { L2LockingPosition } from "src/L2/L2LockingPosition.sol";
import { L2Staking } from "src/L2/L2Staking.sol";

interface iHevm {
    function prank(address sender) external;
}

contract L2RewardEchidnaTest is PropertiesAsserts {
    L2Staking public l2Staking;
    L2LockingPosition public l2LockingPosition;

    iHevm public hevm;

    constructor() {
        hevm = iHevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        address bridge = address(0x1234567890123456789012345678901234567890);
        address remoteToken = address(0xaBcDef1234567890123456789012345678901234);

        hevm.prank(msg.sender);
        L2LiskToken l2LiskToken = new L2LiskToken(remoteToken);
        l2LiskToken.initialize(bridge);

        L2Staking l2StakingImplementation = new L2Staking();
        l2Staking = L2Staking(
            address(
                new ERC1967Proxy(
                    address(l2StakingImplementation),
                    abi.encodeWithSelector(l2Staking.initialize.selector, address(l2LiskToken))
                )
            )
        );

        L2LockingPosition l2LockingPositionImplementation = new L2LockingPosition();
        l2LockingPosition = L2LockingPosition(
            address(
                new ERC1967Proxy(
                    address(l2LockingPositionImplementation),
                    abi.encodeWithSelector(l2LockingPosition.initialize.selector, address(l2Staking))
                )
            )
        );
    }

    function durationIsNeverLargerThanMax(uint256 lockID) public {
        lockID = PropertiesAsserts.clampBetween(lockID, 1, 1000);
        (,, uint256 expDate, uint256 pausedDuration) = l2LockingPosition.lockingPositions(lockID);
        uint256 maxDuration = l2Staking.MAX_LOCKING_DURATION();
        uint256 today = block.timestamp / 1 days;
        PropertiesAsserts.assertWithMsg(
            pausedDuration <= maxDuration, "The position paused duration is larger than max!"
        );
        if (expDate > today) {
            PropertiesAsserts.assertWithMsg(
                expDate - today <= maxDuration, "The position unpaused duration is larger than max!"
            );
        }
    }
}
