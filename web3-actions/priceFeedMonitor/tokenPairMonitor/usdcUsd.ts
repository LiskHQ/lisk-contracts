import {
	ActionFn,
	Context,
	Event,
	PeriodicEvent,
} from '@tenderly/actions';
import { checkTokenPairPriceUpdateTime } from './validate';

// Define the contract address and token pair
const CONTRACT_ADDRESS = "0xb4e6A7861067674AC398a26DD73A3c524C602184";
const TOKEN_PAIR = "USDC/USD";

export const monitorUsdcUsdFn: ActionFn = async (context: Context, event: Event) => {
	const periodicEvent = event as PeriodicEvent;
	console.log(periodicEvent);

	// Get Opsgenie API key from the secrets
	const apiKey = await context.secrets.get("OPSGENIE_API_KEY");

	// Current time in seconds
	const currentTimestamp = Math.floor(periodicEvent.time.getTime() / 1000);

	await checkTokenPairPriceUpdateTime(CONTRACT_ADDRESS, TOKEN_PAIR, apiKey, currentTimestamp);
}
