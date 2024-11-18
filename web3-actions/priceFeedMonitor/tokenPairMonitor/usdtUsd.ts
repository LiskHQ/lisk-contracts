import {
	ActionFn,
	Context,
	Event,
	PeriodicEvent,
} from '@tenderly/actions';
import { checkTokenPairPriceUpdateTime } from './validate';

// Define the contract address and token pair
const CONTRACT_ADDRESS = "0xd2176Dd57D1e200c0A8ec9e575A129b511DBD3AD";
const TOKEN_PAIR = "USDT/USD";

export const monitorUsdtUsdFn: ActionFn = async (context: Context, event: Event) => {
	const periodicEvent = event as PeriodicEvent;
	console.log(periodicEvent);

	// Get Opsgenie API key from the secrets
	const apiKey = await context.secrets.get("OPSGENIE_API_KEY");

	// Current time in seconds
	const currentTimestamp = Math.floor(periodicEvent.time.getTime() / 1000);

	await checkTokenPairPriceUpdateTime(CONTRACT_ADDRESS, TOKEN_PAIR, apiKey, currentTimestamp);
}
