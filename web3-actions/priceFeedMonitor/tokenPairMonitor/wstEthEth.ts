import { ActionFn, Context, Event, PeriodicEvent } from "@tenderly/actions";
import { checkTokenPairPriceUpdateTime } from "./validate";

// Define the contract address and token pair
const CONTRACT_ADDRESS = "0x0x731f330542734B4059334ca8e1Da30AF358b41b2";
const TOKEN_PAIR = "wstETH/ETH";

export const monitorWstEthEthFn: ActionFn = async (context: Context, event: Event) => {
	const periodicEvent = event as PeriodicEvent;
	console.log(periodicEvent);

	// Retrieve neecessary secrets from the context
	const rpcHttpEndpoint = await context.secrets.get("LISK_RPC_HTTP_ENDPOINT");
	const opsgenieApiKey = await context.secrets.get("OPSGENIE_API_KEY");

	// Current time in seconds
	const currentTimestamp = Math.floor(periodicEvent.time.getTime() / 1000);

	await checkTokenPairPriceUpdateTime(
		CONTRACT_ADDRESS,
		TOKEN_PAIR,
		currentTimestamp,
		rpcHttpEndpoint,
		opsgenieApiKey,
	);
};
