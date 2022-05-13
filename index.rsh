'reach 0.1';
 
/*
 - who is involved in this application - Proposer, Voter
 - what information is known at the start of the application : the proposer knows the deadline, description, amount
 - what information is discovered the voter learns of the deadline, description, amount
 
 if a participant starts of with knowledge it's a field in the interact object,
 if a participant learns something, it's an argument to a function,
 if a participant provides something later, it's a result to a function
 
 1. Proposer - Publishes description, amount, deadline
 2. while deadline hasn't been reached
    2a. check voter's voting state
    2b. allow voter to vote
    2c. increment votes
    2d. show votes
 3. show votes
*/
const [isVote, YES, NO] = makeEnum(2);
const [isExecuted, EXECUTED, NOT_EXECUTED] = makeEnum(2);
const [isTimeout, TIMEOUT, NOT_TIMEOUT] = makeEnum(2);

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
