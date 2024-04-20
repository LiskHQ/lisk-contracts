
# Vesting

This page documents the contract [L2VestingWallet.sol](../src/L2/L2VestingWallet.sol) used for vesting and the corresponding deployment script [script/L2VestingWallet.s.sol](script/L2VestingWallet.s.sol). As the basis for the vesting implementation for Lisk we use OpenZeppelin's [VestingWallet](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/finance/VestingWallet.sol). 


## Vesting Schedules

The following table gives an overview of the vesting schedules implemented in the deployed vesting contracts. Note that the vesting for the DAO treasury is implemented in four distinct contracts as the addition of 100,000,000 LSK to the DAO treasury depends on a governance vote and there are slight differences in the emissions in the different yeras.

| Category | Amount (LSK) | Beneficiary Address | Start Timestamp | Duration in Days | Description |
|----------|--------------|-----------------|------------------|-------------|-------------|
| Treasury | 8,000,000 | <treasury address> | 1735689600 | 1095 | All tokens are linearly released over 3 years between 1.1.2025 and 31.12.2027. |
| Team     | 7,000,000 | <team address> | 1735689600 | 1461 | All tokens are linearly released over 4 years between 1.1.2025 and 31.12.2028. |
| Investors | 30,000,000 | <investor address> | 1716163200 | 730 | 10,000,000 LSK liquid at migration, the remaining 20,000,000 LSK vested linearly 24 months. |
| Ecosystem Fund | ~7,860,000 | <ecosystem fund address> | 1735689600 | 0 | 5,000,000 LSK are liquid at migration, the remaining ~2,860,000 LSK are released on 1.1.2025. |
| DAO Fund | 15,000,000 | <dao treasury> | 1716163200 | 226 | 6,250,000 LSK liquid at migration, 8,750,000 LSK are linearly released in 2024. |
| DAO Fund | 30,000,000 | <dao treasury> | 1735689600 | 730 | 15,000,000 LSK are linearly released in 2025, 15,000,000 LSK are linearly released in 2026. |
| DAO Fund - optional | 90,000,000 | <dao treasury> | 1798761600 | 2192 | 15,000,000 LSK are linearly released in the years 2027-2032. |
| DAO Fund - optional | 10,000,000 | <dao treasury> | 1988150400 | 365 | 10,000,000 LSK are linearly released in 2033. |

## Owner and Contract Upgrades


