/*
		The proposer publishes the description, amount and deadline
		while the deadline hasn't been reached
				voter can cast their vote only once as either yes or no
				the consensus increments yesVotes and noVotes based of the voter's choice
		show outcome
*/
import { loadStdlib } from "@reach-sh/stdlib";
import * as backend from "./build/index.main.mjs";

const stdlib = loadStdlib();

const startBal = stdlib.parseCurrency(100);
const accProposer = await stdlib.newTestAccount(startBal);

const ctcProposer = accProposer.contract(backend);
const deadline = 10;

try {
	await ctcProposer.p.Proposer({
		description: "Free food for school kids",
		deadline,
		ready: () => {
			console.log("Contract is ready");
			throw 42;
		},
	});
} catch (e) {
	if (e !== 42) {
		throw e;
	}
}
const users = await stdlib.newTestAccounts(5, startBal);

const willError = async (f) => {
	let error;
	try {
		await f();
		error = false;
	} catch (e) {
		error = e;
	}
	if (error === false) throw Error("expected to error but didn't");
	console.log(f, "errored as intended");
};

const vote = async (voter) => {
	const who = users[voter];
	const ctc = who.contract(backend, ctcProposer.getInfo());
	const vote = Math.random() < 0.5;
	await ctc.apis.Voter.vote(vote);
	const description = await ctc.views.Proposal.description();
	const deadline = await ctc.views.Proposal.deadline();
	console.log(description[1], parseInt(deadline[1]._hex, 16));

	console.log(
		stdlib.formatAddress(who),
		"voted",
		vote,
		"has",
		stdlib.formatCurrency(await stdlib.balanceOf(who))
	);
};

const timesUp = async () => {
	const results = await ctcProposer.apis.Voting.timesUp();
	const yes = parseInt(results[1]._hex, 16);
	const no = parseInt(results[2]._hex, 16);
	const outcome = parseInt(results[0]._hex, 16);
	console.log("Times up. Outcome:", outcome, ",Yes:", yes, ",No:", no);
};

await vote(0);
await vote(1);
await vote(2);
await willError(() => vote(2));
await vote(3);
await vote(4);

console.log("Waiting for the deadline");
await stdlib.wait(deadline);

await timesUp();
