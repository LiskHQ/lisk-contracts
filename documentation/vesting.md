
# Vesting

This page documents the contract [L2VestingWallet.sol](../src/L2/L2VestingWallet.sol) used for vesting and the corresponding deployment script [L2VestingWallet.s.sol](../script/L2VestingWallet.s.sol). As the basis for the vesting implementation for Lisk we use OpenZeppelin's [VestingWalletUpgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/release-v5.0/contracts/finance/VestingWalletUpgradeable.sol).


## Vesting Schedules

The following table gives an overview of the vesting schedules, each implemented by a separate deployed vesting contract. Note that the vesting for the DAO treasury is implemented in four distinct contracts as the addition of 100,000,000 LSK to the DAO treasury depends on a governance vote and there are slight differences in the emissions in the different yeras.

The vesting schedules are read from the [vestingPlans.json](../script/data/devnet/vestingPlans.json) file. Note that the vested amount is not passed into the initializer of `VestingWalletUpgradeable` contract, rather all tokens transferred to this smart contract are vested over the provided period.

| Category | Amount (LSK) | Beneficiary Address | Start Timestamp | Duration in Days | Description |
|----------|--------------|-----------------|------------------|-------------|-------------|
| Treasury | 8,000,000 | <treasury address> | 1735689600 | 1095 | All tokens are linearly released over 3 years between 1.1.2025 and 31.12.2027. |
| Team     | 7,000,000 | <team address> | 1735689600 | 1461 | All tokens are linearly released over 4 years between 1.1.2025 and 31.12.2028. |
| Investors | 30,000,000 | <investor address> | 1716163200 | 730 | 10,000,000 LSK liquid at migration, the remaining 20,000,000 LSK vested linearly over 24 months, starting 20.05.2024. |
| Ecosystem Fund | ~7,860,000 | <ecosystem fund address> | 1735689600 | 0 | 5,000,000 LSK are liquid at migration, the remaining ~2,860,000 LSK are released on 1.1.2025. |
| DAO Fund | 15,000,000 | <dao treasury> | 1716163200 | 226 | 6,250,000 LSK liquid at migration, 8,750,000 LSK are linearly released in 2024, starting 20.05.2024. |
| DAO Fund | 30,000,000 | <dao treasury> | 1735689600 | 730 | 15,000,000 LSK are linearly released in 2025, 15,000,000 LSK are linearly released in 2026. |
| DAO Fund - optional | 90,000,000 | <dao treasury> | 1798761600 | 2192 | 15,000,000 LSK are linearly released in the years 2027-2032. |
| DAO Fund - optional | 10,000,000 | <dao treasury> | 1988150400 | 365 | 10,000,000 LSK are linearly released in 2033. |

## Owner and Contract Upgrades

The vesting smart contracts will hold a significant portion of LSK tokens vested for the community and other stakeholders. The owner address for these smart contract will be set to the multisignature controlled by the Security Council. The owner is authorized to upgrade the contracts.

Vesting contracts will be upgraded exclusively if any of them is hacked or contains a vulnerability, and only to control the damage. This is a security measure protecting the vested LSK tokens.

Note that the released vested tokens could be claimed to the beneficiary address by anyone, not necessarily by the contract owner.
