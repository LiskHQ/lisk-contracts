import {
  Web3Function,
  Web3FunctionContext,
} from "@gelatonetwork/web3-functions-sdk";
import { BigNumber, Contract } from "ethers";
import { arrayify, toUtf8String, formatBytes32String } from "ethers/lib/utils";
import { WrapperBuilder } from "@redstone-finance/evm-connector";
import * as redstone from "redstone-protocol";

const ORACLE_ABI = [
  "function updateDataFeedsValuesPartial(bytes32[]) public",
  "function getLastUpdateDetails(bytes32) public view returns (uint256, uint256, uint256)",
  "function getLivePrice(bytes32[]) public view returns (uint256[], uint256)",
];

const MIN_DEVIATION = 0.5; // 0.5%

const DEBUG_MODE = false;
const debugLog = conditionalLog(DEBUG_MODE);

interface DataFeed {
  symbol: string;
  id: string;
  livePrice: BigNumber;
  timestamp: number;
  storedPrice: BigNumber;
  storedTimestamp: number;
}

Web3Function.onRun(async (context: Web3FunctionContext) => {
  const { userArgs, multiChainProvider } = context;

  const provider = multiChainProvider.default();

  const dataServiceId = userArgs.dataServiceId as string;
  const dataFeedIdsString = userArgs.symbols as string[];
  const dataFeedIdsBytes32 = dataFeedIdsString.map((id) =>
    formatBytes32String(id)
  );
  const oracleAddress = userArgs.oracleAddress as string;

  const oracle = new Contract(oracleAddress, ORACLE_ABI, provider);

  let dataFeedIds = new Map<string, DataFeed>();
  for (const id of dataFeedIdsString) {
    dataFeedIds.set(id, {
      symbol: id,
      id: formatBytes32String(id),
      livePrice: BigNumber.from(0),
      timestamp: 0,
      storedPrice: BigNumber.from(0),
      storedTimestamp: 0,
    });
  }
  debugLog("Data feed ids: ", dataFeedIds);

  // Wrap contract with redstone data service
  let wrappedOraclePrimaryProd;
  switch (dataServiceId) {
    case "redstone-primary-prod":
      wrappedOraclePrimaryProd = WrapperBuilder.wrap(oracle).usingDataService(
        {
          dataServiceId: "redstone-primary-prod",
          uniqueSignersCount: 2,
          dataFeeds: dataFeedIdsString,
          disablePayloadsDryRun: true,
        },
        ["https://oracle-gateway-1.a.redstone.finance"]
      );
      break;
    case "redstone-main-demo":
      wrappedOraclePrimaryProd = WrapperBuilder.wrap(oracle).usingDataService(
        {
          dataServiceId: "redstone-main-demo",
          uniqueSignersCount: 1,
          dataFeeds: dataFeedIdsString,
          disablePayloadsDryRun: true,
        },
        ["https://d33trozg86ya9x.cloudfront.net"]
      );
      break;
    default:
      return {
        canExec: false,
        message: `Data service id not found: ${dataServiceId}`,
      };
  }

  // Retrieve stored & live prices
  const { data: livePriceData } =
    await wrappedOraclePrimaryProd.populateTransaction.getLivePrice(
      dataFeedIdsBytes32
    );
  const txCalldataBytes = arrayify(String(livePriceData));
  const parsingResult = redstone.RedstonePayload.parse(txCalldataBytes);

  debugLog("Unsigned metadata: ", toUtf8String(parsingResult.unsignedMetadata));
  debugLog("Data packages count: ", parsingResult.signedDataPackages.length);
  debugLog(
    "------------------------------------------------------------------------"
  );

  let dataPackageIndex = 0;
  for (const signedDataPackage of parsingResult.signedDataPackages) {
    debugLog(
      "------------------------------------------------------------------------"
    );
    debugLog(`Data package: ${dataPackageIndex}`);
    debugLog(
      `Timestamp: ${signedDataPackage.dataPackage.timestampMilliseconds}`
    );
    debugLog(
      `Date and time: ${new Date(
        signedDataPackage.dataPackage.timestampMilliseconds
      ).toUTCString()}`
    );
    debugLog("Signer address: ", signedDataPackage.recoverSignerAddress());
    debugLog(
      "Data points count: ",
      signedDataPackage.dataPackage.dataPoints.length
    );
    debugLog(
      "Data points symbols: ",
      signedDataPackage.dataPackage.dataPoints.map((dp) => dp.dataFeedId)
    );
    debugLog(
      "Data points values: ",
      signedDataPackage.dataPackage.dataPoints.map((dp) =>
        BigNumber.from(dp.value).toNumber()
      )
    );

    let dataFeed = dataFeedIds.get(
      signedDataPackage.dataPackage.dataPoints[0].dataFeedId
    );

    if (
      dataFeed != undefined &&
      dataFeed.symbol === signedDataPackage.dataPackage.dataPoints[0].dataFeedId
    ) {
      if (dataFeed.timestamp === 0) {
        dataFeed.livePrice = BigNumber.from(
          signedDataPackage.dataPackage.dataPoints[0].value
        );
        dataFeed.timestamp =
          signedDataPackage.dataPackage.timestampMilliseconds;
      }
    }
    debugLog("Data feed: ", dataFeed);
    dataPackageIndex++;
  }

  // Check if all data feeds are present
  for (const dataFeed of dataFeedIds.values()) {
    if (dataFeed.timestamp === 0 || dataFeed.livePrice.eq(0)) {
      console.log("Data feed not found: ", dataFeed);
      return {
        canExec: false,
        message: `Data feed not found: ${dataFeed.symbol}`,
      };
    }
  }
  debugLog(
    "------------------------------------------------------------------------"
  );

  // Get stored prices and timestamps from the blockchain
  for (const dataFeed of dataFeedIds.values()) {
    [dataFeed.storedTimestamp, , dataFeed.storedPrice] =
      await wrappedOraclePrimaryProd
        .getLastUpdateDetails(dataFeed.id)
        .catch(() => [BigNumber.from(0), 0, 0]);
  }
  // And print them out
  debugLog("Stored prices and timestamps:");
  for (const dataFeed of dataFeedIds.values()) {
    console.log(
      `Live ${dataFeed.symbol} price: ${dataFeed.livePrice.toString()}`
    );
    console.log(
      `Stored ${dataFeed.symbol} price: ${dataFeed.storedPrice.toString()}`
    );
  }
  console.log(
    "------------------------------------------------------------------------"
  );

  // Check price deviation and create an array for price feeds which needs to be updated
  const decimals = 8;
  let priceFeedIdsToUpdate: string[] = [];
  console.log("Price deviations and time elapsed since last update:");
  console.log(
    "------------------------------------------------------------------------"
  );
  for (const dataFeed of dataFeedIds.values()) {
    const priceDeviation = computePriceDeviation(
      dataFeed.livePrice,
      dataFeed.storedPrice,
      decimals
    );
    console.log(
      `Price deviation for ${dataFeed.symbol}: ${priceDeviation.toString()}`
    );
    const deviationPrct = (priceDeviation.toNumber() / 10 ** decimals) * 100;
    console.log(`Deviation in %: ${deviationPrct.toFixed(2)}%`);
    debugLog(
      "------------------------------------------------------------------------"
    );

    // Check update time interval
    const currentTimestamp = Date.now();
    const timeElapsed =
      (currentTimestamp - dataFeed.storedTimestamp) / (1000 * 60 * 60);
    console.log(
      `Current timestamp for ${dataFeed.symbol}: ${currentTimestamp}`
    );
    console.log(
      `Stored timestamp for ${dataFeed.symbol}: ${dataFeed.storedTimestamp}`
    );
    console.log(
      `Time elapsed since last update for ${dataFeed.symbol} in hours: ${timeElapsed}`
    );
    console.log(
      "------------------------------------------------------------------------"
    );

    // Only update price if deviation is above 0.5% or last update is more than 6 hours ago
    if (deviationPrct >= MIN_DEVIATION || timeElapsed > 6) {
      priceFeedIdsToUpdate.push(dataFeed.id);
    }
  }

  // Print out the price feeds which needs to be updated as symbols
  console.log("Price feeds to update: ", priceFeedIdsToUpdate);

  // Only update price if deviation is above 0.5% or last update is more than 6 hours ago
  if (priceFeedIdsToUpdate.length === 0) {
    return {
      canExec: false,
      message: `No update: price deviation too small or time elapsed since last update is less than 6 hours`,
    };
  }

  // Craft transaction to update the price on-chain
  console.log("Updating price feeds...");
  const { data: updateDataFeedsPartialData } =
    await wrappedOraclePrimaryProd.populateTransaction.updateDataFeedsValuesPartial(
      priceFeedIdsToUpdate
    );
  console.log(`Data received: ${updateDataFeedsPartialData}`);

  return {
    canExec: true,
    callData: [
      { to: oracleAddress, data: updateDataFeedsPartialData as string },
    ],
  };
});

function computePriceDeviation(
  newPrice: BigNumber,
  oldPrice: BigNumber,
  decimals: number
) {
  const zero = BigNumber.from(0);
  const one = BigNumber.from(1);

  if (zero.eq(oldPrice)) {
    return one.mul(10 ** decimals);
  } else if (newPrice.gt(oldPrice)) {
    return newPrice
      .sub(oldPrice)
      .mul(10 ** decimals)
      .div(oldPrice);
  } else {
    return oldPrice
      .sub(newPrice)
      .mul(10 ** decimals)
      .div(oldPrice);
  }
}

function conditionalLog(condition: boolean) {
  return (...args: any[]): void => {
    if (condition) console.log(...args);
  };
}
