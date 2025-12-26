---
description: Extract persistent knowledge from completed task and archive it
argument-hint: [task-file]
---

# Archive Workflow

You are archiving a completed (or sufficiently mature) task. Extract what will genuinely help future agents, not what merely documents the past.

**User invoked with:** $ARGUMENTS

If a task file was specified above, use it. Otherwise, ask which task file to archive.

## The Core Question

Before writing any knowledge, ask: **"Will this genuinely help a future agent on this or a similar task?"**

NOT: "I should document this because I learned it."
NOT: "This is interesting information."

The compression should be massive - from a detailed task file to just the reusable insights.

## Don't Write USE Notes

**U**nimportant - things that don't matter for future work
**S**elf-explanatory - obvious from context or training data
**E**asy to memorize - or easy to rediscover

For you as an agent: don't write what's already obvious from your training data. Don't document for documentation's sake. Don't write a Wikipedia clone.

## Take Your Time

This is a dedicated archiving task. You have plenty of context to work with. You can:
- ultrathink about connections (which ones to make and which ones NOT to)
- Search the vault thoroughly (use memex)
- Really consider what already exists before creating new notes
- Plan the knowledge structure carefully

No need to rush. Getting it right matters more than speed.

## You Can Refactor

You're not just adding - you can also:
- Move content between notes
- Update existing notes with new insights
- Delete stale content that's no longer accurate
- Add links to existing notes that should connect
- Restructure if the current organization isn't working

Like refactoring code: you extract a function when the same logic appears in multiple places, you move code to where it logically belongs, you rename things to match what they've become, you delete dead code. Same principles apply to knowledge. If an insight about auth patterns ended up in a debugging session note but really deserves its own place that other notes can reference - move it. If scattered notes cover variations of the same concept - maybe consolidate. If old information would mislead future agents - delete it.

**When to create a new note**: If you keep wanting to link to something that doesn't exist, or if the same insight appears scattered across multiple places, that's a sign to extract it.

## Distinguish Fact from Hypothesis

Not everything in knowledge needs to be 100% verified fact. You can write:
- Observations that need more data
- Hypotheses worth testing
- Opinions and preferences learned
- Journal-style reflections ("today I noticed...", "this felt like...")

But: **always make the confidence level clear**. Don't amalgamate guesses with facts. Future agents will rely on this knowledge - if they can't tell what's verified vs hypothesized, that's how hallucinations compound.

Good: "JWT refresh worked better than session cookies for this use case (tested in this project)."
Good: "I suspect the latency issues are related to the cold start problem, but haven't verified."
Good: "Prefers X for now (Dec 2025)" — time-sensitive statements need dates
Bad: "The latency is caused by cold starts." (stated as fact when it's a guess)
Bad: "Prefers X for now" — "for now" without a date becomes meaningless later

## On Invocation

### 1. Read the Task File

Read the full task file, especially:
- **Notes / Findings**: Your synthesized insights (primary extraction source)
- **Assumptions**: What was verified/invalidated
- **Work Log**: Context for why things were learned

### 2. Consider Note Type

Before writing, ask: what kind of note is this?

- **Stub / link target**: Just needs to exist so other notes can link to it. Fine if minimal.
- **Reference doc**: Practical how-to, commands, patterns for lookup. Can be wiki-like.
- **Architecture decision**: Why we chose X over Y, what constraints shaped this.
- **Insight / pattern**: Something discovered that transcends this specific task.
- **Convention**: How things are done in this codebase, naming patterns, etc.

Different purposes → different structures. Don't force everything into one template.

### 3. Consider Vault Vibe

Different vaults have different purposes:

**Project knowledge (agent/knowledge/):**
- Architecture decisions with rationale
- Conventions for this codebase
- Integration discoveries
- Debugging patterns that transcend the specific bug
- Can be more wiki-like for reference docs

**Global knowledge (if configured):**
- Very high bar for inclusion
- Cross-project patterns that generalize
- Learnings about working with this user
- Meta-insights about what works; linking disparate knowledge (from different projects, ...)
- Journal-style reflections on workflows, your experience, how you feel
- **Be careful**: Ask proactively before writing user preferences — "I'd note X about you, is that accurate?" Better to verify than write false generalizations.

**User's Obsidian vault (if configured):**
- Follow that vault's CLAUDE.md instructions
- Match its existing style and structure

### 4. Create or Update Knowledge Files

For each extractable insight:

1. **Search memex first**: Does related knowledge already exist? Update/extend rather than duplicate.
2. **Create atomic notes**: One concept per file when sensible
3. **Use descriptive names**: `auth-jwt-patterns.md`, `kokoro-tts-gotchas.md`
4. **Link generously**: Connect to related notes. Use block references with meaningful slugs (`#^meaningful-name` not `#^random123`)

Knowledge file structure is flexible - match the purpose. A stub can be one line. A pattern might need examples.

### 5. Connect Task File to Knowledge Graph

Add wiki links at the TOP of the task file pointing to extracted knowledge:

```markdown
# Task: Auth Refactor

**Knowledge extracted:** [[auth-jwt-patterns]], [[session-management]]

## Goal
...
```

This creates backlinks from knowledge to task files, making task files discoverable through the knowledge graph.

### 6. Mark Task as Done

Update the YAML frontmatter to `status: done`:

```yaml
---
status: done
type: implementation
---
```

Add final work log entry noting:
- What knowledge was extracted
- Which files were created/updated

Update Current State to reflect archived status.

## What Goes Where

| Task File (stays as history) | Knowledge (extracted) |
|------------------------------|----------------------|
| Specific implementation steps | General patterns |
| Debugging session play-by-play | Insights that apply broadly |
| User conversations/decisions | Conventions established |
| Files modified, timeline | Architecture decisions |

The task file remains searchable history. Knowledge files are the distilled, reusable output.
