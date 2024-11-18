import {
	ActionFn,
	Context,
	Event,
	PeriodicEvent,
} from '@tenderly/actions';
import { checkTokenPairPriceUpdateTime } from './validate';

// Define the contract address and token pair
const CONTRACT_ADDRESS = "0x6b7AB4213c77A671Fc7AEe8eB23C9961fDdaB3b2";
const TOKEN_PAIR = "ETH/USD";

export const monitorEthUsdFn: ActionFn = async (context: Context, event: Event) => {
	const periodicEvent = event as PeriodicEvent;
	console.log(periodicEvent);

	// Get Opsgenie API key from the secrets
	const apiKey = await context.secrets.get("OPSGENIE_API_KEY");

	// Current time in seconds
	const currentTimestamp = Math.floor(periodicEvent.time.getTime() / 1000);

	await checkTokenPairPriceUpdateTime(CONTRACT_ADDRESS, TOKEN_PAIR, apiKey, currentTimestamp);
}
