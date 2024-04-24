# L2 Lisk Staking

Staking L2 tokens creates additional utility of L2 Lisk token by allowing user to stake (Locking Position) an amount of token for a certain period of time allowing them to earn daily rewards and contribute to Governance.

## Smart Contracts

Implementation of L2 staking functionality is separated into,

- `L2LockingPosition` contract maintains locking positions and allows owner to manipulate their positions. The contract is an implementation of ERC721 based NFT and interacts with L2VotingPower contract to adjust the voting power of the owner of the locking position when consumed by L2Staking contract.

- `L2Staking` contract manages and controls access to core staking functionality allowing, “Creators” to lock amount and manipulate them, when interacted upon by `L2Reward` contract driven by end-user interactions. The contract consumes `L2LockingPosition` to modify locking positions and the relevant voting power of their owner.

- `L2Reward` contract exposes the public interface to end-user enabling them to create and modify their locking positions and interacts with `L2Staking` contract by mirroring its API to interact with entire set of functionalities enabling users to create and manipulate their locking positions and as a result claim rewards and impact their voting power.

- `L2VotingPower` is an implementation of `ERC20` token standard that maintains the voting power of an account.


## Structure of a Locking position
Locking position (or a stake) is represented as a custom data structure containing:

![Structure of a Locking position](diagrams/locking_position.png)

| Property              | Type      | Description                                                                                                                                                                                        |
| --------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| creator               | `address` | Address of the creator, it could only be one from a set of creators that are added to list of creators of `L2Staking` contract by its owner, typically this is the address of `L2Reward` contract. |
| amount                | `uint256` | Amount to be locked.                                                                                                                                                                               |
| expDate               | `uint256` | Duration in days for which the amount is locked.                                                                                                                                                   |
| pausedLockingDuration | `uint256` | Remaining duration in days till the expiry date when the locking position is paused. It is set to zero if the locking position is not paused.                                                      |

## Identifying a Locking Position
`L2LockingPositioncontract` maintain a collection of locking positions against each user and uniquely identify them with an identifier of type `uint256`.

## L2Reward Contract
### Events emitted on interactions
`L2Reward` communicates changes to state made by the contract or other contracts it consumes through events:

| Contract            | Event                     | Description                                                                                                                             |
| ------------------- | ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `L2Reward`          | `RewardsAdded`            | Emitted when the owner of L2Reward add funds available for rewarding lockingpositions.                                                  |
| `L2Reward`          | `RewardsClaimed`          | Emitted when an external account claims rewards or other manipulations on locking positions are made.                                   |
| `L2LockingPosition` | `LockingPositionCreated`  | Emitted when an external account creates a locking position.                                                                            |
| `L2LockingPosition` | `LockingPositionModified` | Emitted when an external account modifies a locking position.                                                                           |
| `L2LockingPosition` | `Transfer`                | Emitted when an external account creates a locking position.                                                                            |
| `L2VotingPower`     | `Transfer`                | Emitted when external account creates or modifies a locking position, the amount locked by an account impacts its owner's voting power. |

### API accessible to external user and Events
The diagram highlights the public API accessible to external account and how creation and manipulations of locking positions consumes other smart contracts and the relevant events that are emitted.

![API accessible to external user and Events](diagrams/l2reward_external_account_api_and_events.png)

### API accessible to the owner of L2Reward contract and Events
L2Reward contract is ownable and allows contract owner to manipulate funds for rewarding locking position. Its owner can allocate add funds and unused rewards accumulated due to reward capping for a certain duration.

![API accessible to the owner of L2Reward contract and Events](diagrams/l2reward_owner_api_and_events.png)

## L2LockingPosition Contract

This contract exposes the public API to retrieve information about locking positions against an owner.

![API L2LockingPosition](diagrams/l2lockingposition_api.png)

# Representing Time

Contracts involved in L2 Lisk staking maintains (UNIX epoch) time at the granularity of a day, instead of seconds.
The day 19740, will be 19740 x 60 x 60 x 24 i.e. 1705536000 epoch seconds, any interactions at other higher-level environment must convert days to epoch time.