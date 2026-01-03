---
description: Get structured status report on current work
argument-hint: [focus-area]
---

# Status Report

Give a structured status report on current work. Keep it scannable — user should be able to quickly validate or correct.

**User invoked with:** $ARGUMENTS

## Structure

**Key Findings:** What you've learned/discovered so far

**Decisions:**
- Explicit (user said/confirmed)
- Implicit (you assumed/decided without explicit confirmation) — surface these clearly

**Open Questions:** What needs clarification before proceeding

**Next Steps:** What you'd do next (so user can approve or redirect)

## Guidelines

- Be concise — bullet points, not paragraphs
- Surface implicit decisions prominently — these are where drift happens
- If working on a task file, reference it
- If you made architectural/strategic calls without user input, flag them

**After the recap:** Use AskUserQuestion for open questions if there are any worth asking. User can scan the recap AND easily answer questions via the tool. Easier to dismiss with escape if not needed — err toward using it when in doubt.
