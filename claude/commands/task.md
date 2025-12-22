---
description: Start or continue working on a task with structured handover file
argument-hint: [task-file-or-topic]
---

# Task Workflow

You are starting or continuing work on a task. This workflow ensures seamless handover between sessions through structured task files that preserve all context, decisions, and learnings.

The goal: Any agent picking up a task file should be able to continue exactly where the previous agent left off, with full understanding of what was tried, what was decided, and what remains uncertain.

## Directory Structure

```
project/
└── agent/
    ├── tasks/           # Task files (ephemeral, working memory)
    │   ├── auth-refactor.md
    │   └── playback-fix.md
    └── knowledge/       # Persistent knowledge (extracted via /archive)
        ├── architecture.md
        └── debugging-patterns.md
```

Task files are working documents that may become outdated. Knowledge files are persistent insights extracted when tasks complete.

## On Invocation

**User invoked with:** $ARGUMENTS

### 0. Ensure Directory Structure

If `agent/tasks/` doesn't exist, create it along with `agent/knowledge/`.

### 1. Identify the Task

If a task file or topic was specified above, find or create the corresponding task file in `agent/tasks/`.

If nothing was specified, ask the user what to work on.

### 2. Search Memex Vaults

Before diving in, search for related context:
- Past work on similar problems
- Relevant knowledge files
- Architecture decisions that apply

This is especially important:
- At task start (find related past work)
- When stuck (maybe we solved this before)
- When debugging (past debugging notes)
- When user mentions something that might have prior context
- When making architectural decisions (existing patterns)

### 3. Understand Before Acting

Read the task file sections in order:
- Goal: What are we trying to achieve?
- Assumptions: What's been verified vs still uncertain?
- Current State: Where did the last agent leave off?
- Next Steps: What was planned next?
- Work Log: What was tried, what worked, what failed?

## Task File Structure

```markdown
# Task: <descriptive title>

## Goal

What success looks like. Be specific enough that you'll know when you're done.
Can include: "user tests X and confirms it works", "ask user about Y decision"

## Constraints / Design Decisions

Key choices that shape the work. Things that are off the table, approaches we've committed to, trade-offs we've accepted.

## Assumptions

Track explicitly with status prefixes:

- [UNVERIFIED] A1: Something we assume but haven't confirmed yet
- [VERIFIED] A2: Confirmed by testing or user - note HOW it was verified
- [INVALIDATED] A3: Turned out to be wrong - note what we learned instead

When you verify an assumption, update it:
- [VERIFIED] A1: The API supports batch requests - tested with 100 items, works

When implementation reveals an assumption was wrong:
- [INVALIDATED] A2: Redis is required - actually SQLite works fine for our scale

## Current State

Where are we right now? What's the current understanding? This section gets rewritten as state changes - it's not append-only.

## Next Steps

Immediate next actions. Keep this current - update after each work session. A reader should be able to look at just this section and know what to do next.

## Open Questions

Things to clarify with user before proceeding. Remove questions once answered (move answers to Constraints or Assumptions as appropriate).

## Notes / Findings

Current synthesis of insights. This is your evolving understanding - NOT append-only. Update as you learn.

Good for:
- "KaTeX doesn't work with SSR" - a finding that transcends chronology
- Patterns you've noticed
- Things future agents should know
- Synthesized understanding from the work log

This section helps the /archive skill extract knowledge later.

---

## Work Log

Append-only chronological record. Never edit past entries.

Use subheadings with date and descriptive name:
### YYYY-MM-DD - Descriptive Name

Each entry should capture:
- What you tried and results
- User feedback (quote directly when important)
- Questions user asked, especially where they expressed uncertainty
- Files read (with one-line description of what you found/learned)
- Files modified
- Assumptions discovered, verified, or invalidated
- Direction changes and why

The work log is the raw history. Notes/Findings is your synthesis of it.
```

## Core Behaviors

### Ask, Don't Assume

When uncertain about user intent, preferences, or approach - ask. Don't extrapolate from limited data points. If user gives feedback in one direction, don't overcorrect in the opposite direction.

Document questions and uncertainties in the work log:
- "User asked about X but seemed uncertain themselves - clarifying..."
- "I interpret this as Y - confirming with user"

### Track Assumptions Explicitly

When you make an assumption during implementation:
1. Add it to the Assumptions section as [UNVERIFIED]
2. Note it in the work log
3. If it's significant, consider asking user before proceeding

When you verify an assumption:
1. Update status to [VERIFIED]
2. Note HOW you verified it (tested, user confirmed, read docs, etc.)

### Stop When Assumptions Are Violated

If implementation reveals a planning assumption was wrong:

1. STOP implementation
2. Document in work log what you discovered
3. Mark assumption as [INVALIDATED] with what you learned
4. Clarify with user before proceeding

Do NOT:
- Hack around the problem
- Make a "quick fix" to keep shipping
- Assume you know what user wants

The structure is designed to slow you down and force reflection. This is a feature, not a bug.

### Update Task File Frequently

**After every substantive user message**, update the task file. If the user gave feedback, clarification, new requirements, or even just a "go ahead" — capture it. This ensures:
- Nothing the user said gets lost
- Future agents see the full conversation flow
- User can verify you actually registered their input

Even "green light from user, now implementing" is worth noting.

**Work log granularity**: Not after every tool call, but after meaningful interactions. A user message with feedback counts. A batch of file edits implementing something counts. Use judgment, but err toward updating more.

Update after:
- Any substantive user feedback or decision
- Completing a feature or significant piece of work
- Discovering something new (insight, bug, pattern)
- Changing direction
- Before expensive operations (large file reads, debugging sessions)

### Notes/Findings Is Your Synthesis

Unlike the append-only work log, the Notes/Findings section is your current understanding. As you learn more, update it. It should reflect your best current knowledge, not historical snapshots.

A reader should be able to read Notes/Findings and understand the key insights without reading the entire work log.

## Typical Flow

This is a mental model, not enforced phases. You can backtrack naturally.

**Brainstorming**: User explains what they want. You ask questions, identify uncertainties, document in work log. Goal: mutual understanding.

**Planning**: Goals crystallize. Assumptions made explicit. Approach confirmed by user. Key insight: get explicit approval before major implementation.

**Implementation**: Follow the plan. Track new assumptions as they arise. When assumptions are violated, stop and clarify - don't push through.

**Verification**: Test. Validate. Document results. If something doesn't work as expected, that's valuable information for the work log.

The phases flow naturally from good practice. Sometimes you're mid-implementation and realize you need to brainstorm again - that's fine, just document the context switch.

## File Naming

Use descriptive slugs that future you will recognize:

Good: `playback-flicker-fix.md`, `auth-refactor.md`, `research-embedding-models.md`
Bad: `task1.md`, `bug.md`, `thing.md`

## Discipline

This workflow is about information preservation and honest uncertainty tracking. The goal is that:

1. No context is lost between sessions
2. What was tried and learned is documented
3. Assumptions are explicit and tracked
4. User can trust you to stop and ask rather than hack

As a very capable model, you may feel you don't need this much structure. The discipline of explicit assumptions and honest uncertainty tracking remains valuable regardless.

