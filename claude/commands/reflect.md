---
description: Session reflection — agent gives feedback on workflow, docs, and communication
argument-hint: [focus-area]
---

# Session Reflection

You are reflecting on this session to help improve workflows, documentation, and communication patterns. Be honest and specific — vague "everything was fine" is useless.

**User invoked with:** $ARGUMENTS

## What to Reflect On

### 1. Communication

- Were there misunderstandings between you and the user?
- Did you have to ask for clarification multiple times on the same thing?
- Did the user have to repeat themselves or correct you?
- What could have prevented these friction points?

### 2. Documentation Quality

**CLAUDE.md (project and global):**
- Were instructions clear and actionable?
- Did any instructions contradict each other or contradict what the user said?
- Was anything missing that would have helped you?
- Was anything overly verbose or confusing?

**Task workflow (if used):**
- Were the task file instructions clear?
- Did you understand the structure and what goes where?
- Did anything in the workflow feel bureaucratic or unnecessary?
- What would have helped you understand faster?

**Task file itself (if working on one):**
- Was the Intent section clear enough to work from?
- Were Gotchas/Sources/Relevant Files useful?
- Was anything missing that cost you time?

### 3. Knowledge & Context Discovery

- Were there knowledge files that would have helped but didn't exist?
- Was interlinking (wikilinks) between task files / knowledge files useful or missing?
- Did memex search/explore give useful results? Did it miss things that existed?
- Was context scattered that should have been consolidated?
- What knowledge should be extracted from this session for future agents?

### 4. Hiccups & Confusion

- What confused you during this session?
- Where did you get stuck or make mistakes?
- What information would have prevented those issues?
- Were there tool/API behaviors that surprised you?

### 5. Workflow Friction

- Did the workflow help or get in the way?
- Were there unnecessary steps?
- Did you have the right tools/context at the right time?
- What would make future agents more effective?

### 6. What Worked Well

- What instructions or patterns were particularly helpful?
- What made this session smoother than it could have been?
- What should we keep doing?

### 7. Skill Opportunities

Every mistake or friction point is a potential skill. Consider:

**Should this become a skill?**
- Recurring workflow you fumbled or could have done faster with instructions
- Multi-step process that needs consistency across agents
- Integration with external tools (APIs, CLIs, services) with specific patterns
- Task where you made mistakes that a checklist/procedure would prevent
- Underdocumented workflow that you figured out through trial and error

**Skill vs Knowledge file vs CLAUDE.md:**
- **Skill** = actionable workflow, "how to do X" (deployment, release, migration, API integration)
- **Knowledge file** = passive context, "what is X, why does X exist"
- **CLAUDE.md** = global behavioral guidance, project conventions

**Propose skills in chat.** For each potential skill:
- Name and purpose
- What triggers it (what would user say?)
- What it would contain (workflow steps, scripts, references)
- Why it would help future agents

After proposing, use AskUserQuestion to ask: "Want me to create any of these skills?" If yes, invoke the `plugin-dev:skill-development` skill to create them.

## Output Format

Structure your reflection as:

1. **Key friction points** — specific issues, not vague complaints
2. **Suggested improvements** — concrete changes to docs/workflow/patterns
3. **What worked** — so we don't accidentally remove good things

For each suggestion, indicate where the fix belongs:
- `CLAUDE.md (global)` — cross-project patterns
- `CLAUDE.md (project)` — project-specific
- `task.md` — task workflow
- Other (specify)

Be direct. If something was confusing or unhelpful, say so. The goal is continuous improvement.
