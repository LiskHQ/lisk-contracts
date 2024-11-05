import {
  Web3Function,
  Web3FunctionContext,
} from "@gelatonetwork/web3-functions-sdk";
import { BigNumber, Contract } from "ethers";
import { formatBytes32String } from "ethers/lib/utils";
import { WrapperBuilder } from "@redstone-finance/evm-connector";

const ORACLE_ABI = [
  "function updateDataFeedsValuesPartial(bytes32[]) public",
  "function getValueForDataFeed(bytes32) public view returns (uint256)",
  "function getDataTimestampFromLatestUpdate(bytes32) external view returns (uint256)",
  "function getLivePrice(bytes32[]) public view returns (uint256[], uint256)",
];

Web3Function.onRun(async (context: Web3FunctionContext) => {
  const { userArgs, multiChainProvider } = context;

  const provider = multiChainProvider.default();

  const oracleAddressPrimaryProd = "0x858B9Ba5729C599ED12513E7000f0F316b58Afb5";
  const oraclePrimaryProd = new Contract(oracleAddressPrimaryProd, ORACLE_ABI, provider);

  const dataFeedIdEth = formatBytes32String("ETH");
  const dataFeedIdUsdt = formatBytes32String("USDT");

  // Wrap contract with redstone data service
  const wrappedOraclePrimaryProd = WrapperBuilder.wrap(oraclePrimaryProd).usingDataService(
    {
      dataServiceId: "redstone-primary-prod",
      uniqueSignersCount: 2,
      dataFeeds: ["ETH", "USDT"],
      disablePayloadsDryRun: true,
    },
    ["https://oracle-gateway-1.a.redstone.finance"]
  );

  // Retrieve stored & live prices
  const decimals = BigNumber.from(8);
  const { livePrices, liveTimestamp } = await wrappedOraclePrimaryProd.getLivePrice([dataFeedIdEth, dataFeedIdUsdt]);
  const liveEthPrice: BigNumber = livePrices === undefined ? BigNumber.from(0) : livePrices[0];
  const liveUsdtPrice: BigNumber = livePrices === undefined ? BigNumber.from(0) : livePrices[1];
  const storedEthPrice: BigNumber = await wrappedOraclePrimaryProd.getValueForDataFeed(dataFeedIdEth).catch(() => BigNumber.from(0));
  const storedUsdtPrice: BigNumber = await wrappedOraclePrimaryProd.getValueForDataFeed(dataFeedIdUsdt).catch(() => BigNumber.from(0));
  console.log(`Live ETH price: ${liveEthPrice.toString()}`);
  console.log(`Live USDT price: ${liveUsdtPrice.toString()}`);
  console.log(`Stored ETH price: ${storedEthPrice.toString()}`);
  console.log(`Stored USDT price: ${storedUsdtPrice.toString()}`);

  // Check price deviation
  const priceDeviationEth = computePriceDeviation(liveEthPrice, storedEthPrice, decimals);
  const deviationPrct = (priceDeviationEth.toNumber() / 10 ** 8) * 100;
  console.log(`Deviation: ${deviationPrct.toFixed(2)}%`);

  // Check update time interval
  const currentTimestamp = Date.now();
  const timeElapsed = (currentTimestamp - liveTimestamp) / (1000 * 60 * 60)

  // Only update price if deviation is above 0.5% or last update is more than 6 hours ago
  const minDeviation = 0.5;
  if (deviationPrct < minDeviation && timeElapsed <= 6) {
    return {
      canExec: false,
      message: `No update: price deviation too small or time elapsed since last update is less than 6 hours`,
    };
  }

  // Craft transaction to update the price on-chain
  console.log(`Start price update for ETH`);
  const { data } = await wrappedOraclePrimaryProd.populateTransaction.updateDataFeedsValuesPartial(
    [dataFeedIdEth]
  );
  console.log(`Stop price update`);
  console.log(`Data: ${data}`);

  return {
    canExec: true,
    callData: [{ to: oracleAddressPrimaryProd, data: data as string }],
  };
});

function computePriceDeviation(
  newPrice: BigNumber,
  oldPrice: BigNumber,
  decimals: BigNumber
) {
  const zero = BigNumber.from(0);
  const ten = BigNumber.from(10);
  if (zero.eq(oldPrice)) {
    return ten.mul(decimals);
  } else if (newPrice.gt(oldPrice)) {
    return ((newPrice.sub(oldPrice)).mul(ten).mul(decimals)).div(oldPrice);
  } else {
    return ((oldPrice.sub(newPrice)).mul(ten).mul(decimals)).div(oldPrice);
  }
}