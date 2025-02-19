# RedStone Oracle Web3 Function

This project contains Web3 Function for interacting with RedStone price feed smart contracts.

## Installation

⚠️ **Important**: This project requires specific package versions to ensure compatibility and avoid known security issues. Please use the following command to install dependencies:

```bash
yarn install --pure-lockfile
```

Do not use `npm install` or regular `yarn install` as this may override the carefully selected package versions in the lockfile.

## Overview

This project implements Web3 Function that interacts with RedStone price feed smart contracts to:

- Fetch live price data for specified assets from RedStone data services
- Compare with stored prices
- Update onchain prices when deviation thresholds are met
- Handle multiple data feeds simultaneously

## Development

After installing dependencies, you can:

1. Run tests: `yarn w3f:test`
2. Deploy function: `yarn w3f:deploy`
