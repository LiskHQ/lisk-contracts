import { ethers } from 'ethers';
var opsgenie = require("opsgenie-sdk");

// Define the ABI for the L2PriceFeedWithoutRounds contract
const CONTRACT_ABI = [
    {
        inputs: [],
        name: "latestRoundData",
        outputs: [
            { internalType: "uint80", name: "roundId", type: "uint80" },
            { internalType: "int256", name: "answer", type: "int256" },
            { internalType: "uint256", name: "startedAt", type: "uint256" },
            { internalType: "uint256", name: "updatedAt", type: "uint256" },
            { internalType: "uint80", name: "answeredInRound", type: "uint80" },
        ],
        stateMutability: "view",
        type: "function",
    },
];

// Define the RPC URL
const RPC_URL = "https://rpc.api.lisk.com";

// Define Opsgenie API URL
const OPSGENIE_API_URL = "https://api.opsgenie.com";

// Function to send an alert to Opsgenie
async function sendOpsgenieAlert(
    tokenPair: string,
    apiKey: string
): Promise<void> {
    const message = "[Tenderly] The latest data for " + tokenPair + " token pair is older than 6 hours.";
    const description = "[Tenderly] The latest data for " + tokenPair + " token pair is older than 6 hours.";
    const alertPayload = {
        message: message,
        description: description,
        teams: [
            {
                name: "Lisk"
            }
        ],
        visibleTo: [
            {
                name: "Lisk",
                type: "team"
            }
        ],
        priority: "P2"
    };

    opsgenie.configure({
        host: OPSGENIE_API_URL,
        api_key: apiKey
    });

    const response = await opsgenie.alertV2.create(alertPayload);
    console.log("Opsgenie alert creation status:", response);
}

export async function checkTokenPairPriceUpdateTime(
    contractAddress: string,
    tokenPair: string,
    apiKey: string,
    currentTimestamp: number
) {
    // Initialize the provider
    const provider = new ethers.providers.JsonRpcProvider(RPC_URL);

    // Create a contract instance
    const contract = new ethers.Contract(contractAddress, CONTRACT_ABI, provider);

    try {
        // Call the latestRoundData function
        const latestRoundData = await contract.latestRoundData();

        // Log the results
        console.log("Latest Round Data for", tokenPair, "token pair:");
        console.log("Answer:", latestRoundData.answer.toString());
        console.log("Started At:", latestRoundData.startedAt.toString());
        console.log("Updated At:", latestRoundData.updatedAt.toString());

        // Check if updatedAt is older than 6 hours from the current time
        const sixHoursInSeconds = 6 * 60 * 60;
        const updatedAt = Number(latestRoundData.updatedAt.toString());

        console.log("Current Time:", currentTimestamp);

        if ((currentTimestamp) - updatedAt > sixHoursInSeconds) {
            console.warn("Warning: The latest data for", tokenPair, "token pair is older than 6 hours.");
            // Send alert to Opsgenie
            await sendOpsgenieAlert(tokenPair, apiKey);
        } else {
            console.log("The latest data for", tokenPair, "token pair is up-to-date.");
        }
    } catch (error) {
        console.error("Error fetching latest round data:", error);
        throw new Error("Failed to check " + tokenPair + " token pair price update time: " + error);
    }
}
