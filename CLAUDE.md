# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lisk Smart Contracts repository containing Solidity contracts for the Lisk project's L1 (Ethereum) and L2 (Lisk) networks. Built with Foundry framework using Solidity 0.8.23.

## Essential Commands

```bash
# Build contracts
forge build

# Run all tests
forge test

# Run tests with verbosity (shows traces for failures)
forge test -vvv

# Run a single test file
forge test --match-path test/L2/L2Reward.t.sol

# Run a specific test function
forge test --match-test testRewardCalculation

# Check formatting
forge fmt --check

# Apply formatting
forge fmt

# Build with contract sizes
forge build --sizes

# Run static analysis (requires Slither installed)
slither . --exclude-dependencies --exclude-low --exclude-informational --filter-paths "Ed25519.sol"
```

## Architecture

### Contract Layer Structure

**L1 Contracts** (`src/L1/`):
- `L1LiskToken` - ERC20 LSK token on Ethereum (non-upgradeable, 300M fixed supply)
- `L1VestingWallet` - Vesting for L1 tokens
- `SwapAndBridge` - Bridge utility for L1 to L2 transfers

**L2 Contracts** (`src/L2/`):
- `L2LiskToken` - Bridged LSK token (minted/burned only by Standard Bridge)
- `L2Claim` - Claims LSK from Lisk L1 snapshot (upgradeable, uses Merkle proofs)

**Staking System** (L2, all upgradeable via UUPS):
- `L2Staking` - Core staking logic (lock/unlock, durations 14-730 days)
- `L2LockingPosition` - ERC721 NFT representing staking positions
- `L2Reward` - Distributes staking rewards based on weighted positions
- `L2VotingPower` - Non-transferable ERC20 voting power derived from locked positions

**Governance** (L2):
- `L2Governor` - OpenZeppelin Governor for DAO proposals
- Uses `L2VotingPower` as voting token, `TimelockController` for execution delay

**Price Feeds** (L2):
- `L2PriceFeedWithoutRounds` / `L2MultiFeedAdapterWithoutRounds*` - RedStone oracle adapters

### Key Patterns

**Upgradeable Contracts**: Use UUPS pattern with `Ownable2StepUpgradeable`. Implementations disable initializers in constructor. Paused versions exist in `src/L2/paused/` for emergency stops.

**Staking Flow**: User locks LSK → `L2Staking` creates position via `L2LockingPosition` (mints NFT) → `L2VotingPower` adjusts voting power → `L2Reward` tracks weights for rewards.

**Semantic Versioning**: Contracts implement `ISemver` interface with `version()` function.

### Dependencies (lib/)

- `openzeppelin-contracts` / `openzeppelin-contracts-upgradeable` - Core contract libraries
- `forge-std` - Foundry testing utilities
- `openzeppelin-foundry-upgrades` - Upgrade safety checks
- `redstone-oracles-monorepo` - Oracle integration
- `chainlink` - Additional oracle support
- `properties` - Fuzz testing properties (Echidna)

## Test Structure

- `test/L1/`, `test/L2/` - Unit tests matching source structure
- `test/L2/paused/` - Tests for paused contract versions
- `test/invariant/` - Foundry invariant tests with handlers
- `test/fuzzing/` - Echidna fuzzing tests
- `test/mock/` - Mock contracts for testing

Run analysis tools via `test/scripts/`:
- `runSlither.sh` - Static analysis
- `runSlitherMutate.sh` - Mutation testing
- `runEchidna.sh` - Property-based fuzzing

## Bug Fixing Workflow

When a bug is reported, follow test-driven bug fixing:

1. **Reproduce first** - Write a failing test that demonstrates the bug before attempting any fix
2. **Fix with verification** - Use subagents to implement the fix and prove it with the now-passing test

Never jump straight to fixing. The test ensures the bug is understood, the fix is verified, and regression protection is in place.

## Workflow Orchestration

### Plan Mode Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately - don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### Subagent Strategy
Keep main context window clean:
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes - don't over-engineer
- Challenge your own work before presenting it

### Autonomous Bug Fixing
- When given a bug report: follow the test-driven workflow above, then fix autonomously
- Point at logs, errors, failing tests → then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Task Management

1. **Plan First**: Write plan to `tasks/todo.md` with checkable items
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review to `tasks/todo.md`
6. **Capture Lessons**: Update `tasks/lessons.md` after corrections

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.

## Deployment

Deployment scripts are numbered in `script/` directory for sequential execution:
1. `1_deployTokenContracts.sh` - L1/L2 tokens
2. `2_deployStakingAndGovernance.sh` - Staking system + DAO
3. `3_deployVestingWallets.sh` - Vesting contracts
4. `4_deployClaimContract.sh` - L2 claim system
5. `5_deployAirdropContract.sh` - Airdrop

Environment files: `.env.devnet`, `.env.testnet`, `.env.mainnet`

Network variable `NETWORK` determines output folder: `deployment/addresses/{mainnet,testnet,devnet}/`

## Code Style

- Line length: 120 characters
- Multiline function headers: all parameters on new lines
- Bracket spacing enabled
- Tests use `.t.sol` suffix
- Deployment scripts use `.s.sol` suffix

## Important Notes

- Never update `openzeppelin-contracts` via `forge update` - use tagged releases only (security consideration per README)
- L2LiskToken uses CREATE2 for deterministic addresses across L2 networks
- The `web3-functions/` folder contains Gelato/RedStone integration (separate TypeScript project, not core contracts)
