
# Vesting

This page documents the contract [L2VestingWallet.sol](../src/L2/L2VestingWallet.sol) used for vesting and the corresponding deployment script [L2VestingWallet.s.sol](../script/L2VestingWallet.s.sol). As the basis for the vesting implementation for Lisk we use OpenZeppelin's [VestingWalletUpgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/release-v5.0/contracts/finance/VestingWalletUpgradeable.sol).


## Vesting Schedules

The following table gives an overview of the vesting schedules, each implemented by a separate deployed vesting contract. Note that the vesting for the DAO treasury is implemented in four distinct contracts as the addition of 100,000,000 LSK to the DAO treasury depends on a governance vote and there are slight differences in the emissions in the different years.

Some vesting wallets will be deployed on L1 and some on L2. The vesting schedules are read from the [vestingPlans_L1.json](../script/data/devnet/vestingPlans_L1.json) and [vestingPlans_L2.json](../script/data/devnet/vestingPlans_L2.json) files. Note that the vested amount is not passed into the initializer of `VestingWalletUpgradeable` contract, rather all tokens transferred to this smart contract are vested over the provided period.

| Category | Network Layer | Amount (LSK) | Wallet address | Beneficiary Address | Start Timestamp | Duration in Days | Description |
|----------|---------------|--------------|----------------|---------------------|----------|------------------|-------------|
| Treasury | L1            | 8,000,000 |[0x18a0b8c653c291D69F21A6Ef9a1000335F71618e](https://eth.blockscout.com/address/0x18a0b8c653c291D69F21A6Ef9a1000335F71618e)| [0xCAaCF7d9E40D0f4dB66419d678A8D46dE74B0C02](https://eth.blockscout.com/address/0xCAaCF7d9E40D0f4dB66419d678A8D46dE74B0C02) | 1735689600 | 1095 | All tokens are linearly released over 3 years between 1.1.2025 and 31.12.2027. |
| Team I    | L1            | 5,500,000 |[0xe09899a4C98473460BC19D136B330608B465Dc55](https://eth.blockscout.com/address/0xe09899a4C98473460BC19D136B330608B465Dc55)| [0x84798151d27C09E9B6C85A110E6a195D83A4D5F0](https://eth.blockscout.com/address/0x84798151d27C09E9B6C85A110E6a195D83A4D5F0) | 1735689600 | 1461 | All tokens are linearly released over 4 years between 1.1.2025 and 31.12.2028. |
| Team II    | L1            | 1,500,000 |[0x2294A7f24187B84995A2A28112f82f07BE1BceAD](https://eth.blockscout.com/address/0x2294A7f24187B84995A2A28112f82f07BE1BceAD)| [0x586C7735d78f421495FE7e4E32B4e13a90661395](https://eth.blockscout.com/address/0x586C7735d78f421495FE7e4E32B4e13a90661395) | 1735689600 | 1461 | All tokens are linearly released over 4 years between 1.1.2025 and 31.12.2028. |
| Investors | L1            | 30,000,000 |[0x58a61b1807a7bDA541855DaAEAEe89b1DDA48568](https://eth.blockscout.com/address/0x58a61b1807a7bDA541855DaAEAEe89b1DDA48568)| [0x4B00A4659454013388b39DF9b23F5DbE65Bbc06E](https://eth.blockscout.com/address/0x4B00A4659454013388b39DF9b23F5DbE65Bbc06E) | 1716163200 | 730 | 10,000,000 LSK liquid at migration, the remaining 20,000,000 LSK vested linearly over 24 months, starting 20.05.2024. |
| Ecosystem Fund | L1            | 7,711,644 |[0x114cB34b1A0fBBB686E31Bf5542d64A98c42eE23](https://eth.blockscout.com/address/0x114cB34b1A0fBBB686E31Bf5542d64A98c42eE23)| [0xC30B50cdCccEb70b8D87fDda4F08258e8A02539E](https://eth.blockscout.com/address/0xC30B50cdCccEb70b8D87fDda4F08258e8A02539E) | 1735689600 | 0 | 5,000,000 LSK are liquid at migration, the remaining 2,711,644 LSK are released on 1.1.2025. |
| DAO Fund | L2            | 15,000,000 |[0xfDEf6f02778Ab9e38A75A52b3Ba900C2aD751ecE](https://blockscout.lisk.com/address/0xfDEf6f02778Ab9e38A75A52b3Ba900C2aD751ecE)| [0x2294A7f24187B84995A2A28112f82f07BE1BceAD](https://blockscout.lisk.com/address/0x2294A7f24187B84995A2A28112f82f07BE1BceAD) | 1716163200 | 226 | 6,250,000 LSK liquid at migration, 8,750,000 LSK are linearly released in 2024, starting 20.05.2024. |
| DAO Fund | L2            | 30,000,000 |[0x21498d0c5d90198059B7B29Bbb6DB46f36a66e27](https://blockscout.lisk.com/address/0x21498d0c5d90198059B7B29Bbb6DB46f36a66e27)| [0x2294A7f24187B84995A2A28112f82f07BE1BceAD](https://blockscout.lisk.com/address/0x2294A7f24187B84995A2A28112f82f07BE1BceAD) | 1735689600 | 730 | 15,000,000 LSK are linearly released in 2025, 15,000,000 LSK are linearly released in 2026. |
| DAO Fund - optional | L2            | 90,000,000 |[0xdEA264322978933724d2147C45ddd186E7994A8c](https://blockscout.lisk.com/address/0xdEA264322978933724d2147C45ddd186E7994A8c)| [0x2294A7f24187B84995A2A28112f82f07BE1BceAD](https://blockscout.lisk.com/address/0x2294A7f24187B84995A2A28112f82f07BE1BceAD) | 1798761600 | 2192 | 15,000,000 LSK are linearly released in the years 2027-2032. |
| DAO Fund - optional | L2            | 10,000,000 |[0x8F0dc4c07a876aB963eB84df26cDAA1cc43F6b24](https://blockscout.lisk.com/address/0x8F0dc4c07a876aB963eB84df26cDAA1cc43F6b24)| [0x2294A7f24187B84995A2A28112f82f07BE1BceAD](https://blockscout.lisk.com/address/0x2294A7f24187B84995A2A28112f82f07BE1BceAD) | 1988150400 | 365 | 10,000,000 LSK are linearly released in 2033. |

## Owner, Contract Admin and Contract Upgrades

The vesting smart contracts will hold a significant portion of LSK tokens vested for the community and other stakeholders. By design, beneficiary address for these smart contract will be the owner of the vesting contract. While Contract Admin is authorized to upgrade the contracts, set to the multisignature controlled by the Security Council. Refer to [Privilege Roles, Operations and Upgrades](privilege-roles-operations.md) page for more details.

Vesting contracts will be upgraded exclusively if any of them is hacked or contains a vulnerability, and only to control the damage. This is a security measure protecting the vested LSK tokens.

Note that the released vested tokens could be claimed to the beneficiary address by anyone, not necessarily by the contract owner.
