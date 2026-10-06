---
host: pc
user: agent-hl
isolated: true
---

# Worker host: agent-hl@pc

OUT OF SERVICE since 2026-10-06: pc's RAM flips bits in what it writes. Spawn no worker here; workers already running finish. Remove this paragraph once memtest passes.

pc's worker user for Helferline work: `claude` here is logged into the
Helferline account, commits carry the work identity, and work repos exist here
only as mirrors under `~/work/helferline/`, pushed by the orchestrator. Same
machine, same tools and the same limits as agent@pc, and a home the other
worker user cannot read, so nothing personal is reachable from a session the
whole team can open.

@BODY@
