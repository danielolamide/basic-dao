# Workshop : Basic DAO
In this workshop, we will design a Basic DAO application that allows a Proposer to create a proposal where DAO members can vote on whether they want the proposal to be executed or not. The proposer creates a proposal with a description and a relative deadline. When the voter casts their vote a counter is kept based on their vote choice and when the relative deadline hits, the choice with the highest count determines the outcome of the proposal as either executed or not executed.

This workshop assumes you've completed the Reach [Tutorial](https://docs.reach.sh/tut/rps/#tut).

We assume that you'll go through this workshop in a directory named `~/reach/basic-dao`:
```sh
$ mkdir -p ~/reach/basic-dao && cd ~/reach/basic-dao
```

Install [Reach](https://docs.reach.sh/tool/#ref-install) in the `basic-dao` directory and afterwards you can check if it's installed by running:
```sh
$ ./reach version
```

You should then start off by initializing your Reach program:
```sh
$ ./reach init
```

## Problem Analysis
When designing an application we should always ask ourselves some questions in regards to what information is relevant to the implementation of the application.

In that case here are questions we asked ourselves,
- Who is involved in this application?
- What information do they know at the start of the program?
- What information are they going to discover and use in the program?
- What funds change ownership during the application and how?

An excellent practice is to answer these questions in the form of comments in your `index.rsh` file.  
`/* Remember comment are written like this. */`  

**Write down the problem analysis of this program as a comment.**

Let's compare our answers:
- This program involves two parties the Proposer who deploys the proposal and the Voters who cast votes.
- The Proposer is aware of the description and the deadline.
- The Voters do not know about the deadline or description at the start of the program.
- The Voters learn about the description and deadline during the program execution.
- In our program no funds changed ownership, the only funds used were funds to pay for on-chain transactions.

It's okay if some of your answers differ from ours!

## Data Definition
Now we need to structure how we will present information in the program:
- What data type will represent the description set by the Proposer?
- What data type will represent the deadline set by the Proposer?
- What data type will represent the vote cast by the Voter?

Feel free to refer to the [Types](https://docs.reach.sh/rsh/compute/#ref-programs-types) for a reminder of what data types are available in Reach.

After settling on the data types to use, we determine how the program will get this information. We need to work on the participant interact interface.

**What participant interact interface will each participant use?**

You should look back at your problem analysis to do this step. Whenever a participant starts off knowing something, then it is a field in the interact object. If they learn something, then it will be an argument to a function. If they provide something later, then it will be the result of a function.

You should write your answers in your Reach file (index.rsh) as the participant interact interface for each of the participants.

**Write down the data definitions for this program as definitions.**

Let's compare your answers with ours: 
- The description will be represented as `Bytes(length)`.
- The deadline will be repesented as a `UInt`, as it is a relative time delta signifying a change in block numbers.
- The vote will be represented by a function `Fun([Bool], Null)`.

Our participant interact interfaces, including some handy logging and view functions looks like this so far:
```js
const Proposer = Participant('Proposer', {
  deadline: UInt,
  description: Bytes(128),
  ready : Fun([], Null)
});
 
const Voter = API('Voter', {
  vote : Fun([Bool], Null)
});

const Voting = API("Voting", {
  timesUp : Fun([], Array(UInt, 3))
})

const Proposal = View('Proposal', {
  description : Bytes(128),
  deadline : UInt
})
```
At this point, you can modify your JavaScript file (index.mjs) to contain definitions of these values, although you may want to use placeholders for the actual values. When you're writing a Reach program, especially in the early phases, you should have these two files open side-by-side and update them in tandem as you're deciding the participant interact interface

## Communication Construction
Now, we can write down the structure of the communication and action in our application.

**Write down the communication pattern for this program as comments.**

Here's what we wrote:
```js
// The Proposer publishes the parameters of the proposal.
// While the deadline has not been hit
//  A voter casts their vote
//  The vote count is incremented based on vote choice
// The deadline is hit and the voters are shown the outcome and total number of votes.
```
Now, let's write some code in the flow of the communication pattern.

The body of your application should look something like this
```js
Proposer.only(() => {
    const deadline = declassify(interact.deadline);
    const description = declassify(interact.description)
});

//The Proposer publishes the parameters of the proposal.
Proposer.publish(deadline, description);
Proposer.interact.ready();

//Set views
Proposal.description.set(description);
Proposal.deadline.set(deadline);

//Create voters set to keep track of voters
const Voters = new Set();
const [keepGoing, votesYes, votesNo] =
    parallelReduce([true, 0, 0])
        .invariant(balance() == 0)
        .while(keepGoing)
        //A voter casts their vote while the deadline is not hit
        .api(Voter.vote,
          (vote) => {
            //assumptions that must be true to call vote
            check(! Voters.member(this), "the account hasn't voted");
          },
          (vote) => 0,
          (vote, notify) => {
            //actually store that they are voting
            check(! Voters.member(this), "the account hasn't voted");
            Voters.insert(this);
            notify(null);
            const [votedYes, votedNo] = vote ? [1, 0] : [0, 1];
            //The vote count is incremented based on vote choice
            return [true, votesYes + votedYes, votesNo + votedNo];
          }
        )
        .timeout(relativeTime(deadline), () => {
            //The deadline is hit and the voters are shown the outcome and total number of votes.
            const [[], k] = call(Voting.timesUp)
            const result = votesYes > votesNo ? EXECUTED : NOT_EXECUTED;
            k(array(UInt, [result, votesYes, votesNo] ));
            return [false, votesYes, votesNo];
        });
commit();
exit();
```
## Assetion Insertion
When we are programming, we hold a complex theory of the behavior of the program inside of our minds that helps us know what should happen next in the program based on what has happened before and what is true at every point in the program. As programs become more complex, this theory becomes more and more difficult to grasp, so we might make mistakes. Furthermore, when another programmer reads our code (such as a version of ourselves from the future trying to modify the program), it can be very difficult to understand this theory for ourselves. Assertions are ways of encoding this theory directly into the text of the program in a way that will be checked by Reach and available to all future readers and editors of the code.

Look at your application. What are the assumptions you have about the values in the program?

**Write down the properties you know are true about the various values in the program.**
Our assumptions were :
- Once a voter casts their vote for a proposal they cannot vote again

**Insert assertions into the program corresponding to facts that should be true.**  

Here's what we did:
```js
check(!Voters.member(this), "the account hasn't voted");
```
## Interaction Introduction
A key concept of Reach programs is that they are concerned solely with the communication and consensus portions of a decentralized application. Frontends are responsible for all other aspects of the program. Thus, eventually a Reach programmer needs to insert calls into their code to send data to and from the frontend via the participant interact interfaces that they defined during the Data Definition step.

**Insert interact calls to the frontend into the program.**

Look at out whole program now
```js
const [isExecuted, EXECUTED, NOT_EXECUTED] = makeEnum(2);

export const main = Reach.App(() => {
  const Proposer = Participant('Proposer', {
      deadline: UInt,
      description: Bytes(128),
      ready : Fun([], Null)
  });

  const Voter = API('Voter', {
    vote : Fun([Bool], Null)
  })

  const Voting = API("Voting", {
    timesUp : Fun([], Array(UInt, 3))
  })

  const Proposal = View('Proposal', {
    description : Bytes(128),
    deadline : UInt
  })

  init();

  Proposer.only(() => {
      const deadline = declassify(interact.deadline);
      const description = declassify(interact.description)
  });

  //1
  Proposer.publish(deadline, description);
  Proposer.interact.ready();

  Proposal.description.set(description);
  Proposal.deadline.set(deadline);

  const Voters = new Set();
  const [keepGoing, votesYes, votesNo] =
      //2
      parallelReduce([true, 0, 0])
          .invariant(balance() == 0)
          .while(keepGoing)
          .api(Voter.vote,
            (vote) => {
              //assumptions that must be true to call vote
              check(! Voters.member(this), "the account hasn't voted");
            },
            (vote) => 0,
            (vote, notify) => {
              //actually store that they are voting
              check(! Voters.member(this), "the account hasn't voted");
              Voters.insert(this);
              notify(null);
              const [votedYes, votedNo] = vote ? [1, 0] : [0, 1];
              return [true, votesYes + votedYes, votesNo + votedNo];
            }
          )
          .timeout(relativeTime(deadline), () => {
              const [[], k] = call(Voting.timesUp)
              const result = votesYes > votesNo ? EXECUTED : NOT_EXECUTED;
              k(array(UInt, [result, votesYes, votesNo] ));
              return [false, votesYes, votesNo];
          });
  commit();
  exit();
});
```
## Deployment Decisions
Now, it's time to test our program. This is an automated test deployment.  

The program is pretty easy to test, We create test accounts for the Proposer and any number of Voters. The vote choice of a Voter will rely on a generating a random boolean, where `True` is a yes vote and `False` is a no vote.

Here's the Javascript frontend we wrote:
```js
import { loadStdlib } from "@reach-sh/stdlib";
import * as backend from "./build/index.main.mjs";

const stdlib = loadStdlib();

const startBal = stdlib.parseCurrency(100);
const accProposer = await stdlib.newTestAccount(startBal);

const ctcProposer = accProposer.contract(backend);
const deadline = 10;
const outcomes = ["EXECUTED", "NOT_EXECUTED"];

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
	console.log(`Times up. Outcome: ${outcomes[outcome]}.
		\nTotal yes votes : ${yes}, total no votes No: ${no}`);
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
```
This is what it looks like when we run the program
```sh
$ ./reach run
Contract is ready
Free food for school kids 10
XEWAYW2PSU3U7FG5MSTPGK5AWMN3G6UBVNXOUFYEGHX2QC33NHEJT5BOBY voted true has 99.998
Free food for school kids 10
2HQKTC52SZWHRZLKZ3SV7VMWRGIBPMR7L4NV4BXXV73Y6Z5AXDLJDK7FHA voted false has 99.998
Free food for school kids 10
AVWVNAOUWEU7RKKSEQJ5KJ3KTEYNRFFMPTYO3TJ5IWVQHC7RUJEKACYTLQ voted true has 99.998
[Function (anonymous)] errored as intended - //We intentianally tried to vote twice with Voter 3 which threw an error
Free food for school kids 10
K5S3M5OQG6BYWKJOMBVKZNPP2VQ4VPL7Q6LOS2RKXYWYJCGCXY2YVVF4XQ voted true has 99.9981
Free food for school kids 10
7IJD7WVVROISMWGMHRU7ZHY4NQEV36K4ORPJBOP5ELGE3OBP25PXBKH3RQ voted true has 99.998
```
## Discussions and Next Steps
Great Job! Hope you had as much fun working on this as we did. The contract is far from perfect but it provided an amazing base for us to understand Reach in depth.  

If you'd like to make this application more interesting you could: 
- Use tokens to cast votes.
- Token gate the DAO, so that ownership of DAO's Token would be equal to membership.

If you found this workshop rewarding, please let us know on [the Discord community](https://discord.gg/AZsgcXu).

