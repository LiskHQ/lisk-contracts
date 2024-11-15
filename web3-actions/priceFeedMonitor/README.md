# RedStone Price Feed Monitoring

Inside this folder, you will find the code for the RedStone Price Feed monitoring using Tenderly Web3 Actions. This code is used to monitor the price feed of the RedStone smart contracts for different token pairs and trigger alerts if the price feed was not updated for a certain period of time. In this case, the alert is sent to the Opsgenie.

## Install Tenderly CLI
If you haven't already, install [Tenderly CLI](https://github.com/Tenderly/tenderly-cli#installation). 

Before you go on, you need to login with CLI, using your Tenderly credentials:

```bash
tenderly login
```

## Build and Publish/Deploy Web3 Actions

Before you can build and publish/deploy the Web3 Actions, you need modify the configuration `.yaml` file for the project.
Some configuration files inside this folder are:
- `lskUsd.yaml` - configuration file for the RedStone price feed monitoring for the LSK/USD token pair
- `ethUSD.yaml` - configuration file for the RedStone price feed monitoring for the ETH/USD token pair
- `usdtUsd.yaml` - configuration file for the RedStone price feed monitoring for the USDT/USD token pair

You need to provide the following information in the configuration file:
- `YOUR_USERNAME` - your Tenderly account
- `YOUR_PROJECT_SLUG` - your Tenderly project

To build different Web3 Actions, run the following command:

```bash
tenderly actions build --project-config [yaml_file]
```

To publish/deploy the Web3 Actions, run the following command:

```bash
tenderly actions publish --project-config [yaml_file]
or
tenderly actions deploy --project-config [yaml_file]
```
`publish` is used to publish the Web3 Actions to the Tenderly platform without deploying them.
