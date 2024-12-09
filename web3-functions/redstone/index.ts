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
  "function getLivePricesAndTimestamp(bytes32[]) public view returns (uint256[], uint256)",
];

const REDSTONE_PRIMARY_PROD = "redstone-primary-prod";
const REDSTONE_MAIN_DEMO = "redstone-main-demo";
// https://github.com/redstone-finance/redstone-oracles-monorepo/blob/main/packages/sdk/src/data-services-urls.ts
const DEV_GWS = [
  "https://oracle-gateway-1.b.redstone.vip",
  "https://oracle-gateway-1.b.redstone.finance",
  "https://d33trozg86ya9x.cloudfront.net", // https://github.com/gelatodigital/w3f-redstone-poc-v2/blob/main/web3-functions/redstone/index.ts#L32
];
const PROD_GWS = [
  "https://oracle-gateway-1.a.redstone.vip",
  "https://oracle-gateway-1.a.redstone.finance",
  "https://oracle-gateway-2.a.redstone.finance",
];
const REDSTONE_DATA_SERVICES_URLS: Record<string, string[]> = {
  REDSTONE_PRIMARY_PROD: PROD_GWS,
  REDSTONE_MAIN_DEMO: DEV_GWS,
};

const MIN_DEVIATION = 0.5; // 0.5%
const MIN_TIME_ELAPSED_HOURS = 6; // 6 hours
const DECIMALS = 8; // price feed precision
const zero = BigNumber.from(0);
const one = BigNumber.from(1);

const DEBUG_MODE = false;
const debugLog = conditionalLog(DEBUG_MODE);

interface DataFeed {
  symbol: string;
  id: string;
  livePrice: BigNumber;
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

  const idToDataFeedMap = new Map<string, DataFeed>();
  for (const id of dataFeedIdsString) {
    idToDataFeedMap.set(id, {
      symbol: id,
      id: formatBytes32String(id),
      livePrice: BigNumber.from(0),
      storedPrice: BigNumber.from(0),
      storedTimestamp: 0,
    });
  }
  debugLog("Data feed ids: ", idToDataFeedMap);

  // Wrap contract with redstone data service
  let wrappedOracle;
  switch (dataServiceId) {
    case REDSTONE_PRIMARY_PROD:
      wrappedOracle = WrapperBuilder.wrap(oracle).usingDataService(
        {
          dataServiceId: REDSTONE_PRIMARY_PROD,
          uniqueSignersCount: 2,
          dataFeeds: dataFeedIdsString,
          disablePayloadsDryRun: true,
        },
        REDSTONE_DATA_SERVICES_URLS.REDSTONE_PRIMARY_PROD
      );
      break;
    case REDSTONE_MAIN_DEMO:
      wrappedOracle = WrapperBuilder.wrap(oracle).usingDataService(
        {
          dataServiceId: REDSTONE_MAIN_DEMO,
          uniqueSignersCount: 1,
          dataFeeds: dataFeedIdsString,
          disablePayloadsDryRun: true,
        },
        REDSTONE_DATA_SERVICES_URLS.REDSTONE_MAIN_DEMO
      );
      break;
    default:
      return {
        canExec: false,
        message: `Data service id not found: ${dataServiceId}`,
      };
  }

  // Retrieve live prices
  const { data: livePriceData } =
    await wrappedOracle.populateTransaction.getLivePricesAndTimestamp(
      dataFeedIdsBytes32
    );
  const txCalldataBytes = arrayify(String(livePriceData));

  let parsingResult;
  try {
    parsingResult = redstone.RedstonePayload.parse(txCalldataBytes);
  } catch (error) {
    throw new Error("Unable to parse live price tx call data");
  }

  debugLog("Unsigned metadata: ", toUtf8String(parsingResult.unsignedMetadata));
  debugLog("Data packages count: ", parsingResult.signedDataPackages.length);
  debugLog(getDashLine());

  parsingResult.signedDataPackages.forEach(
    (signedDataPackage, dataPackageIndex) => {
      debugLog(getDashLine());
      printSignedDataPackage(dataPackageIndex, signedDataPackage);

      const dataFeed = idToDataFeedMap.get(
        signedDataPackage.dataPackage.dataPoints[0].dataFeedId
      );

      if (dataFeed != undefined) {
        if (dataFeed.livePrice.eq(zero)) {
          dataFeed.livePrice = BigNumber.from(
            signedDataPackage.dataPackage.dataPoints[0].value
          );
        }
      }
      debugLog("Data feed: ", dataFeed);
    }
  );

  // Check if all data feeds are present
  for (const dataFeed of idToDataFeedMap.values()) {
    if (dataFeed.livePrice.eq(zero)) {
      console.log("Data feed not found: ", dataFeed);
      return {
        canExec: false,
        message: `Data feed not found: ${dataFeed.symbol}`,
      };
    }
  }
  debugLog(getDashLine());

  // Retrieve stored prices and timestamps from the blockchain
  for (const dataFeed of idToDataFeedMap.values()) {
    [dataFeed.storedTimestamp, , dataFeed.storedPrice] = await wrappedOracle
      .getLastUpdateDetails(dataFeed.id)
      .catch(() => [BigNumber.from(0), 0, 0]);
  }
  // And print them out
  debugLog("Stored prices and timestamps:");
  printPrices(idToDataFeedMap);
  console.log(getDashLine());

  // Check price deviation and create an array for price feeds which needs to be updated
  const priceFeedIdsToUpdate: string[] = [];
  console.log("Price deviations and time elapsed since last update:");
  console.log(getDashLine());
  for (const dataFeed of idToDataFeedMap.values()) {
    const priceDeviation = computePriceDeviation(
      dataFeed.livePrice,
      dataFeed.storedPrice,
      DECIMALS
    );
    console.log(
      `Price deviation for ${dataFeed.symbol}: ${priceDeviation.toString()}`
    );
    const deviationPrct = (priceDeviation.toNumber() / 10 ** DECIMALS) * 100;
    console.log(`Deviation in %: ${deviationPrct.toFixed(2)}%`);
    debugLog(getDashLine());

    // Check update time interval
    const currentTimestamp = Date.now();
    const timeElapsed =
      (currentTimestamp - dataFeed.storedTimestamp) / (1000 * 60 * 60);
    printTimestamps(dataFeed, currentTimestamp, timeElapsed);
    console.log(getDashLine());

    // Only update price if deviation is above 0.5% or last update is more than 6 hours ago
    if (
      deviationPrct >= MIN_DEVIATION ||
      timeElapsed >= MIN_TIME_ELAPSED_HOURS
    ) {
      priceFeedIdsToUpdate.push(dataFeed.id);
    }
  }

  // Print out the price feeds which needs to be updated as symbols
  console.log("Price feeds to update: ", priceFeedIdsToUpdate);

  // Only update price if deviation is above 0.5% or last update is more than 6 hours ago
  if (priceFeedIdsToUpdate.length === 0) {
    return {
      canExec: false,
      message: `No update: price deviation less than ${MIN_DEVIATION.toFixed(
        2
      )}% or time elapsed since last update is less than ${MIN_TIME_ELAPSED_HOURS} hours`,
    };
  }

  // Craft transaction to update the price on-chain
  console.log("Updating price feeds...");
  const { data: updateDataFeedsPartialData } =
    await wrappedOracle.populateTransaction.updateDataFeedsValuesPartial(
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

function printSignedDataPackage(
  dataPackageIndex: number,
  signedDataPackage: redstone.SignedDataPackage
) {
  debugLog(`Data package: ${dataPackageIndex}`);
  debugLog(`Timestamp: ${signedDataPackage.dataPackage.timestampMilliseconds}`);
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
}

function printPrices(idToDataFeedMap: Map<string, DataFeed>) {
  for (const dataFeed of idToDataFeedMap.values()) {
    console.log(
      `Live ${dataFeed.symbol} price: ${dataFeed.livePrice.toString()}`
    );
    console.log(
      `Stored ${dataFeed.symbol} price: ${dataFeed.storedPrice.toString()}`
    );
  }
}

function printTimestamps(
  dataFeed: DataFeed,
  currentTimestamp: number,
  timeElapsed: number
) {
  console.log(`Current timestamp for ${dataFeed.symbol}: ${currentTimestamp}`);
  console.log(
    `Stored timestamp for ${dataFeed.symbol}: ${dataFeed.storedTimestamp}`
  );
  console.log(
    `Time elapsed since last update for ${dataFeed.symbol} in hours: ${timeElapsed}`
  );
}

function getDashLine() {
  return "------------------------------------------------------------------------";
}
