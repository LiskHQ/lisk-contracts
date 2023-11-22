import * as fs from 'fs';
import { solidityPackedKeccak256 } from 'ethers';
import * as tweetnacl from 'tweetnacl';

interface Key {
	address: string
	keyPath: string
	publicKey: string
	privateKey: string
	plain: {
		generatorKeyPath: string
		generatorKey: string
		generatorPrivateKey: string
		blsKeyPath: string
		blsKey: string
		blsProofOfPossession: string
		blsPrivateKey: string
	}
	encrypted: {}
}
interface DevValidator {
	keys: Key[];
}

interface Balances {
	merkleRoot: string;
	nodes: {
		lskAddress: string
		address: string
		balance: number
		balanceBeddows: number
		numberOfSignatures: number
		mandatoryKeys: Array<string>
		optionalKeys: Array<string>
		payload: string
		hash: string
		proof: Array<string>
	}[];
}

const keys = (JSON.parse(fs.readFileSync('./data/example/dev-validators.json', 'utf-8')) as DevValidator).keys;
const balances = JSON.parse(fs.readFileSync('./data/example/merkle-tree-result.json', 'utf-8')) as Balances;

const signMessage = (message: string, key: Key): string => {
	return Buffer.from(
		tweetnacl.sign.detached(
			Buffer.from(message.substring(2), 'hex'),
			Buffer.from(key.privateKey, 'hex'),
		),
	).toString('hex');
}

const recipient = '0x34A1D3fff3958843C43aD80F30b94c510645C316';
const BYTES_9 = '000000000000000000';

interface SigPair {
	pubKey: string;
	r: string;
	s: string;
}

interface Signature {
	message: string;
	sigs: SigPair[];
}

const signatures: Signature[] = [];

for (const [index, account] of balances.nodes.entries()) {
	const message =
		solidityPackedKeccak256(
			['bytes32', 'address'],
			[account.hash, recipient],
		) + BYTES_9;

	const sigs: SigPair[] = [];

	// Regular Account
	if (account.numberOfSignatures === 0) {
		const key = keys[index];
		const signature = signMessage(message, key);

		sigs.push({
			pubKey: '0x' + key.publicKey,
			r: '0x' + signature.substring(0, 64),
			s: '0x' + signature.substring(64)
		})
	} else {
		// Multisig Account
		// Signing all keys regardless of required amount
		for (const pubKey of account.mandatoryKeys.concat(account.optionalKeys)) {
			const key = keys.find(key => '0x' + key.publicKey === pubKey)!;
			const signature = signMessage(message, key);

			sigs.push({
				pubKey: '0x' + key.publicKey,
				r: '0x' + signature.substring(0, 64),
				s: '0x' + signature.substring(64)
			})
		}
	}


	signatures.push({
		message,
		sigs
	});
}

fs.writeFileSync("./data/example/signatures.json", JSON.stringify(signatures), "utf-8");