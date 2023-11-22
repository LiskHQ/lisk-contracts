import * as fs from 'fs';

// Create Balances
// [#0 - #49] First 50 addresses are regular addresses
const NUM_OF_REGULAR_ACCOUNTS = 50;

// Multisig Accounts
// For each account it will use the address of the index as account holder,
// while the "keys" are used from #0 onwards

// #50: numSig 3  => 3M
// #51: numSig 2  => 1M + 2O
// #52: numSig 5  => 3M + 3O
// #53: numSig 64 => 64M
const multiSigs = [{
	numberOfSignatures: 3,
	numberOfMandatoryKeys: 3,
	numberOfOptionalKeys: 0,
},{
	numberOfSignatures: 2,
	numberOfMandatoryKeys: 1,
	numberOfOptionalKeys: 2,
},{
	numberOfSignatures: 5,
	numberOfMandatoryKeys: 3,
	numberOfOptionalKeys: 3,
},{
	numberOfSignatures: 64,
	numberOfMandatoryKeys: 64,
	numberOfOptionalKeys: 0,
}]

const randomBalance = (startAmount: number) : number => Number((startAmount + Math.random()).toFixed(8));

const accounts = JSON.parse(fs.readFileSync('./data/example/dev-validators.json', 'utf-8')).keys;

const results: {
	lskAddress: string;
	balance: number;
	numberOfSignatures?: number;
	mandatoryKeys?: string[];
	optionalKeys?: string[];
}[] = [];

// Regular Accounts
for (let index = 0; index < NUM_OF_REGULAR_ACCOUNTS; index++) {
	const account = accounts[index];
	const balance = randomBalance(index);

	results.push({
		lskAddress: account.address,
		balance,
	});
}

for (const multiSig of multiSigs) {
	let account = accounts[results.length];
	results.push({
		lskAddress: account.address,
		balance: randomBalance(results.length),
		numberOfSignatures: multiSig.numberOfSignatures,
		mandatoryKeys: [... Array(multiSig.numberOfMandatoryKeys).keys()].map((_, index) => accounts[index].publicKey),
		optionalKeys: [... Array(multiSig.numberOfOptionalKeys).keys()].map((_, index) => accounts[index + multiSig.numberOfMandatoryKeys].publicKey),
	});
}


fs.writeFileSync('./data/example/balances.json', JSON.stringify(results), 'utf-8');
