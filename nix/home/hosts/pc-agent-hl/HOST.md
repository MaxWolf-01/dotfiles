---
host: pc
user: agent-hl
isolated: true
---

# Worker host: agent-hl@pc

pc's worker user for Helferline work: `claude` here is logged into the
Helferline account, commits carry the work identity, and work repos exist here
only as mirrors under `~/work/helferline/`, pushed by the orchestrator. Same
machine, same limits and the same isolation as agent@pc, whose record describes
them; the two users cannot read each other's homes, so nothing personal is
reachable from a session the whole team can open.

## Available

@TOOLCHAIN@, and otherwise what agent@pc's record lists.

## Belongs elsewhere

Everything agent@pc's record sends elsewhere, GitHub included: the mirrors
arrive by push from the orchestrator and nothing here can fetch, push, or open
a PR.
