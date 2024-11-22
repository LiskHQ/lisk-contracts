# RedStone Price Feed Monitoring

Inside this directory, you will find the code for the RedStone Price Feed monitoring using Tenderly Web3 Actions. This code is used to monitor the price feed of the RedStone smart contracts for different token pairs and trigger alerts if the price feed was not updated for a certain period of time. In this case, the alert is sent to Opsgenie.

## Install Tenderly CLI
If you haven't already, install [Tenderly CLI](https://github.com/Tenderly/tenderly-cli#installation).

Before you go on, you need to login with CLI, using your Tenderly credentials:

```bash
tenderly login
```

## Build and Publish/Deploy Web3 Actions

Before you can build and publish/deploy the Web3 Actions, you need modify the configuration `.yaml` file for the project.
Some configuration files inside this directory are:
- [`lskUsd.yaml`](./lskUsd.yaml) - configuration file for the RedStone price feed monitoring for the LSK/USD token pair
- [`ethUsd.yaml`](./ethUsd.yaml) - configuration file for the RedStone price feed monitoring for the ETH/USD token pair
- [`usdtUsd.yaml`](./usdtUsd.yaml) - configuration file for the RedStone price feed monitoring for the USDT/USD token pair
- [`usdcUsd.yaml`](./usdcUsd.yaml) - configuration file for the RedStone price feed monitoring for the USDC/USD token pair
- [`wbtcUsd.yaml`](./wbtcUsd.yaml) - configuration file for the RedStone price feed monitoring for the WBTC/USD token pair

You need to provide the following information in the configuration file(s), under `actions`:
- `YOUR_ACCOUNT_SLUG` - your Tenderly account
- `YOUR_PROJECT_SLUG` - your Tenderly project

**Note**: Both of the above values can be accessed from the Settings page on your Tenderly dashboard.

To build different Web3 Actions, run the following command:

```bash
tenderly actions build --project-config [yaml_filename_without_extension]
```

To publish/deploy the Web3 Actions, run the following command:

```bash
tenderly actions publish --project-config [yaml_filename_without_extension]
or
tenderly actions deploy --project-config [yaml_filename_without_extension]
```
`publish` is used to publish the Web3 Actions to the Tenderly platform without deploying them.
