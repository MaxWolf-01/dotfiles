Look at the codebase / parts of it that the user specified for places to refactor:
Arguments:
#$ARGUMENTS

First create a plan, then present it to the user for approval. If the user approves, proceed with coding.
Following these guidelines will help your plan / PR get accepted.

We'll start with what will get your plan rejected:

- No code golf! While low line count is a guiding light of this project, anything that remotely looks like code golf will be rejected. The true goal is reducing complexity and increasing readability, and deleting lines does nothing to help with that.
- Anything you claim is a "speedup" must be benchmarked. In general, the goal is simplicity, so even if your implementation makes things marginally faster, you have to consider the tradeoff with maintainability and readability.
- In general, refactors should be reasonably well-tested (existing unit tests, or new ones, or at least manual verification that e.g. a script still works as expected).

Now, what we want:

- Bug fixes.
- Refactors that are clear wins. In general, if your refactor isn't a clear win it will be closed. But some refactors are amazing! Think about readability in a deep core sense. A whitespace change or moving a few functions around is useless, but if you realize that two 100 line functions can actually use the same 110 line function with arguments while also improving readability, this is a big win. Refactors should pass process replay.
- Tests. If you can add tests that are non brittle or overly complex, they are welcome. Finding bugs, even writing broken tests (that should pass) with @unittest.expectedFailure is great.
- Dead code removal. Less for people to read and be confused by.

