# Task: Workflow & Skill Design for Claude Autonomous Work

**Knowledge extracted:** [[max-working-preferences]]

## Goal

Design a robust task/handover workflow that enables seamless context transfer between Claude sessions, with explicit phases invoked via commands:
1. `/task` - Start or continue task with proper task file management
2. `/archive` - Extract persistent knowledge after task completion

The workflow must support: software development, research projects, note-taking, learning, and eventually autonomous AI research.

**Future consideration:** Convert commands to Skills (model-invoked) and potentially bundle with memex MCP as example autonomous workflow. For now, commands are appropriate - user wants steering wheel.
When tackling this, see state of [Consider merging Skills and Slash Commands](https://github.com/anthropics/claude-code/issues/13115), etc (e.g. there's also a tool for calling skills, so we'll very most likely just keep them as slash commands).
Actually, a step towards that will probably be agents managing other agents with this workflow.

## Constraints / Design Decisions

- Task files are ephemeral working memory; knowledge files are persistent
- Both live under `agent/` parent directory: `project/agent/{tasks, knowledge}`
- Knowledge flows to: project-specific vault primarily, global vault for cross-project learnings
- Skills contain the detailed workflow instructions, not CLAUDE.md (avoids context pollution)
- Work log is append-only, date-stamped, chronological - lives at BOTTOM of file
- Other sections (Goal, Assumptions, Current State, Next Steps, Notes/Findings) are kept up-to-date
- Assumptions are explicitly tracked with status: `[VERIFIED]`, `[UNVERIFIED]`, `[INVALIDATED]`
- Notes/Findings section = current synthesis of work log + context (helps /archive extract knowledge)
- File naming: descriptive slug (e.g., `playback-flicker-fix.md`), no prefix needed
- Timestamps: Use date from context if available, otherwise version steps (Step 1, Step 2, etc.)

## Assumptions

- A1: [VERIFIED] `/task` and `/archive` skill names are available (only `/tasks` plural is taken)
- A2: [VERIFIED] User prefers visible directories over hidden (`.claude/`)
- A3: [VERIFIED] Work log granularity = "meaningful work blocks" not individual tool calls
- A4: [VERIFIED] Skills will be user-level, not shipped with memex MCP
- A5: [VERIFIED] Multiple concurrent task files are fine; agent can synthesize if related
- A6: [VERIFIED] Parent directory is `agent/` containing both `tasks/` and `knowledge/`
- A7: [VERIFIED] Notes/Findings section is valuable as current synthesis (not redundant with work log)
- A8: [VERIFIED] Provenance direction: wiki links AT TOP of task files pointing TO knowledge nodes (not vice versa) - knowledge stays pure, backlinks connect them
- A9: [VERIFIED] Knowledge writing = distillation, not brevity - different anatomy than task files, need to understand the "vibe" of target vault
- A10: [VERIFIED] /task command should create agent/{tasks,knowledge} structure if missing
- A11: [UNVERIFIED] Commands should support $ARGUMENTS for passing file context

## Current State

Both commands drafted:
- `/task` at `/home/max/.dotfiles/claude/commands/task.md` - reviewed, approved
- `/archive` at `/home/max/.dotfiles/claude/commands/archive.md` - extensive feedback received, needs updates

Task file moved to proper location: `/home/max/.dotfiles/agent/tasks/workflow-design.md`

User provided detailed feedback on /archive (2024-12-22). Key corrections:
- Provenance reversed: wiki links go in task files pointing TO knowledge, not vice versa
- "KaTeX doesn't work with SSR" is a finding, not a debugging pattern (bad example)
- "Be concise" → "Be distilled" - knowledge writing needs right "vibe" for target vault
- Need to explore user's Obsidian knowledge base to understand note-taking patterns

**Waiting for:** Memex MCP access to explore knowledge base, then discuss insights, then get green light to update /archive.

## Next Steps

1. ~~Draft both commands~~ → DONE
2. ~~User reviews /archive~~ → DONE, feedback received
3. **Research phase (current):**
   - Explore user's knowledge base (need MCP access)
   - Review memex readme and project CLAUDE.md template
   - Consider $ARGUMENTS support for commands
   - Consider project scaffolding approach
4. Discuss insights with user
5. Get green light to update /archive command
6. Test workflow in production
7. Migrate YAPIT to new workflow

## Open Questions

**Resolved:**
- Directory structure → `agent/{tasks, knowledge}` at project root
- Skill naming → `/task` and `/archive` (both available!)
- File naming → Descriptive slug, no prefix
- Multiple concurrent tasks → Fine, agent can synthesize if related
- Notes/Findings → Keep as current synthesis section (not redundant - work log is append-only history, notes/findings is current understanding)
- Assumption status → `[VERIFIED]`, `[UNVERIFIED]`, `[INVALIDATED]` prefix format
- Timestamps → Use date if available in context, otherwise Step 1/2/3

**Active:**

- **Knowledge placement:** Own node vs. in-note with links? (e.g., "KaTeX SSR issue" - own node? or note in KaTeX linked to SSR?) Context-dependent, user also unsure. Need to explore existing patterns in knowledge base.
- **Project scaffolding:** How to best initialize agent/{tasks,knowledge} for new projects? Options: alias, Claude Code /init hook, integrated into /task command. Over-engineering risk?
- **$ARGUMENTS syntax:** Should be `$ARGUMENTS` for all args, `$1`, `$2` for positional (per docs). How to integrate?

## Notes / Findings

**On over-extrapolation** (from user feedback):
> "sometimes you over generalize or over extrapolate what I am saying... I give you some feedback in some direction and you're like oh my god I made this grave mistake and now I need to do everything in the opposite way"

Action: Quote user feedback directly. Mark interpretations explicitly. If uncertain, ASK.

**On implementation discipline** (from user feedback):
> "if during implementation you figure out something doesn't work as planned... assumptions from the planning phase turn out to be wrong... you need to replan / reclarify with the user... DO NOT resort to quick hacks 'just to get it done'"

Action: When implementation reveals assumption violations, STOP. Document in work log, add to assumptions section as invalidated, and clarify with user before proceeding.

**On work log granularity** (from user feedback):
> "after a set of edits, the set of reads and edits, that level of granularity would actually be appropriate... not after every use of the edit tool"

Action: Update work log after meaningful work blocks - completing a feature, discovering something new, changing direction.

**On capturing user questions/uncertainties**:
The work log should capture not just decisions but also:
- Questions user asked where they were uncertain
- Things user wants feedback on
- "User is unsure about X and wants my thoughts"
This helps future agents understand what was debated vs just decided.

**On work log subheadings**:
Use format: `### YYYY-MM-DD - Descriptive Name` (e.g., "Feedback Round 1", "Initial Draft", "Implementation Start")
This helps scanning and gives each entry identity beyond just timestamp.

**On implicit vs explicit phases**:
Phases (ideation → planning → implementation → testing) should be implicit, not enforced. What matters:
- The behaviors within each phase (ask questions, track assumptions, stop when violated)
- The discipline to pause and clarify, not rigid state transitions
- Flexibility to backtrack (mid-implementation → back to brainstorming) without fighting the system

**On designing for future models**:
- Keep skill prompts semantic (describe intent, not mechanical steps)
- The assumption tracking and work log patterns are about information preservation - they'll scale
- Don't over-optimize for current quirks; future models may need less hand-holding

**On vault search**: Agents should proactively search memex vaults:
- At task start (find related past work)
- When stuck (maybe we solved this before)
- When debugging
- When user mentions something that might have prior context

**On the knowledge/task split**:
- Task file = what you need to continue THIS task
- Knowledge file = what you need for FUTURE tasks
- Architecture decisions, patterns, conventions → knowledge
- Current debugging state, what files you touched → task file

**On commands vs Skills** (from Anthropic docs):
- **Slash commands**: User-invoked, explicit (`/command-name`), single .md file
- **Agent Skills**: Model-invoked, automatic discovery, directory with SKILL.md + resources
- **Plugins**: Distribution mechanism bundling both, plus agents, hooks, MCP servers
- For now, commands are appropriate. Skills for future when more autonomous operation desired.

**On provenance direction** (corrected):
Wiki links go in task files pointing TO knowledge nodes, NOT in knowledge files pointing back to tasks.
- Knowledge files stay pure (no clutter from many referencing tasks)
- Backlinks still connect everything (explore tool shows backlinks)
- Example workflow: debugging SSR issue → explore SSR node → backlinks show previous debugging sessions

**On vault-specific writing**:
- Project vault: debugging knowledge, architecture, compromises, specific decisions
- Global vault: meta-learnings, patterns, what user prefers in certain contexts, cross-project insights
- Different vaults have different anatomy - understand the target before writing

**On writing tools for agents** (from Anthropic blog):
- Tools should match how humans would subdivide tasks, not just wrap APIs
- Consolidate functionality (one tool for workflow, not N discrete operations)
- Return meaningful context, not raw technical identifiers
- Token efficiency matters - pagination, filtering, truncation with helpful guidance
- Tool descriptions are prompt engineering - small refinements can yield dramatic improvements

---

## Work Log

### 2024-12-21 - Session Start

Read context files:
- `/home/max/repos/github/MaxWolf-01/memex/README.md` - MCP tool overview, semantic search over markdown vaults
- `/home/max/repos/github/MaxWolf-01/memex/CLAUDE.md` - Memex spec, design decisions, vision for LLM "second brain"
- `/home/max/repos/github/MaxWolf-01/memex/plans/memex-design-brainstorm.md` - Detailed workflow thinking, search vs explore distinction
- `/home/max/repos/code/yapit-tts/yapit/CLAUDE.md` - Current working workflow with plan files, best existing example
- `/home/max/repos/obsidian/knowledge-base/CLAUDE.md` - Note-taking conventions, what good knowledge notes look like
- Sample plan files from `~/.claude/plans/` - Real examples of current workflow (playback-flicker was excellent)

Key patterns observed:
- YAPIT workflow already captures most of what's needed but lacks: timestamps, assumption tracking, explicit knowledge separation
- Memex design docs have excellent thinking on handover vs knowledge distinction
- Plan files vary in quality - some excellent (playback-flicker), some messy accumulations

### 2024-12-21 - Initial Design Draft

Created initial handover file structure. Posted synthesis and open questions to user.

Initial structure proposed had work log in middle - this was incorrect.

Interpretations made (to be confirmed):
- User wants chronological work log, not just "current state" snapshot → CONFIRMED
- Skills should NOT be in CLAUDE.md but invoked on-demand → CONFIRMED
- Handover file format should be consistent enough to parse → CONFIRMED

### 2024-12-21 - User Feedback Round 1

User provided extensive feedback. Key decisions:
- `tasks/` and `knowledge/` directories at project root (visible, can be committed)
- Work log at BOTTOM of file (append-only, grows downward)
- Dedicated Assumptions section with status markers
- Files modified go inline in work log entries
- No rigid phase enforcement - implicit in workflow

Important user insight: The core problem is agents pushing forward with hacks when assumptions are violated. The solution is explicit assumption tracking + discipline to STOP and clarify.

User quote on phases:
> "first do a broad brainstorming... you tell me what you understand whether you understand it correctly... then I tell you yeah that's great and we continue to implementation or I want to do it like this"

### 2024-12-21 - User Feedback Round 2

Key clarifications:
- Directory structure: `agent/{tasks, knowledge}` - parent directory named "agent"
- Timestamps: Use date from context if available, otherwise just version steps
- Notes/Findings: KEEP as dedicated section - it's the current synthesis, distinct from append-only work log
- User confirmed A1 directly: `/task` and `/archive` are available (only `/tasks` plural is taken)
- User liked assumption status format: `[VERIFIED]`, `[UNVERIFIED]`, `[INVALIDATED]`
- User mentioned "discipline equals freedom" (Jocko Willink) - discipline theme resonates

User feedback on work log quality:
> "having this dash and then one sentence what the gist of what you got from this file... it just makes life easier for other agents reading this file"

I had removed file descriptions - this was a regression. Fixed by adding back one-line summaries of what each file contained.

**Questions user asked where they expressed uncertainty (I should give my input):**
- Should phases (ideation → planning → implementation → testing) be explicit/enforced or implicit?
- Is the rigid phase structure from global CLAUDE.md draft too constraining?
- General "bring suggestions, be creative, which of my suggestions need fine tuning"
- User wasn't sure about skill naming initially (now resolved)
- User mentioned designing for future model generations - worth considering in design

### 2024-12-21 - Feedback Round 3 & My Suggestions

User pointed out I should be capturing their questions/uncertainties in work log, not just their decisions. This is valuable for:
- Showing where brainstorming happened
- Helping future agents understand what was uncertain vs decided
- Capturing "user wants clarification on X" type notes

User emphasized: The brainstorming time (1+ hour) is an investment that compounds, especially for meta-workflow design like this. Should design for next-gen models, not just current ones.

User likes work log subheadings (date + descriptive name like "Feedback Round 1") - should include in skill instructions.

**My suggestions/feedback on outstanding uncertainties:**

1. **On explicit phases vs implicit flow:**
   I think implicit phases are better. Here's why:
   - Explicit phase enforcement adds friction and ceremony
   - The phases naturally emerge from good practice (you brainstorm → you get clarity → you implement → you verify)
   - What matters more: the *behaviors* within each phase (ask questions, track assumptions, stop when assumptions violated)
   - The skill instructions can describe the phases as a mental model, but not enforce transitions
   - Edge case: Sometimes you're mid-implementation and realize you need to re-brainstorm. Explicit phases would fight this; implicit phases accommodate it naturally.

2. **On the global CLAUDE.md phases draft:**
   The draft captures the right *intent* but was too rigid as written. What should survive:
   - "refinement until user EXPLICITLY approves" - YES, this is the discipline point
   - "always update your handover document" - YES, core to workflow
   - "no information from the exploration process is lost" - YES, the work log serves this
   - The explicit arrows (→) between phases - NO, too rigid

   Better framing: Describe the phases as *typical flow*, but emphasize the behaviors (ask, document, stop-and-clarify) rather than state transitions.

3. **On designing for future models:**
   Good insight. Implications:
   - Keep skill prompts semantic, not mechanical (describe intent, not exact steps)
   - Don't over-optimize for current model quirks (like needing explicit "don't hack" instructions)
   - The assumption tracking and work log patterns should scale - they're about information preservation, not model capabilities
   - Future models with better memory/context might need less structure, but the discipline of explicit assumptions will still help

4. **On what I'd fine-tune from your suggestions:**
   - Your "STOP conditions" idea is excellent - the skill should have explicit triggers for when to pause
   - The assumption verification workflow is strong - I'd add: "When you verify an assumption, note HOW you verified it"
   - Work log granularity guidance was good - maybe add examples in skill: "Update after: completing a feature, discovering something new, changing direction, before expensive operations"

5. **One thing I'd add:**
   Consider a brief "Handoff Summary" section at the very top of the task file (after Goal) - 2-3 sentences of "if you're picking this up, here's the TL;DR of where we are." This helps agents who are resuming without reading the full work log first. The Current State section is close to this, but a dedicated ultra-brief summary could help.

**User response to suggestions:**

1. Implicit phases: CONFIRMED - user fully agrees
2. Typical flow framing: CONFIRMED - "emphasizing behaviors rather than state transitions, perfect"
3. Don't hack / slow down: User clarified - the structure itself is designed to slow down, force reflection, not just a warning
4. Examples in skills: User cautioned - examples can bias LLMs, be careful. Only add examples we're confident are solid.
5. Handoff Summary: REJECTED - "no point in that, files designed to be read in full, top sections already serve this purpose"
6. Work log update triggers: User approved the phrasing "update after completing a feature, discovering something new, changing direction, before expensive operations"

**New insight from user on archiving:**
When /archive creates knowledge nodes, it should add wiki links at the TOP of the task file to connect it to the knowledge graph. This enables:
- Backlink navigation from knowledge nodes to task files
- Seeing which sessions worked on a concept
- The task files become part of the searchable knowledge graph via memex

User says: "Now we really should get to writing the task skill"

### 2024-12-21 - Drafted /task Skill

Created `/home/max/.dotfiles/claude/commands/task.md` - comprehensive skill covering:
- Directory structure (agent/{tasks, knowledge})
- On-invocation steps (identify task, search memex, understand before acting)
- Full task file template with all sections
- Core behaviors (ask don't assume, track assumptions, stop when violated, update intervals, synthesis)
- Typical flow (brainstorming → planning → implementation → verification) as mental model
- File naming guidance
- Discipline framing

Files created:
- `/home/max/.dotfiles/claude/commands/task.md` - the /task skill (~220 lines)

Initial draft was too terse (user caught me optimizing for context). Rewrote with full detail.

**What the skill covers well:**
- Task file structure and purpose of each section
- Assumption tracking with status prefixes
- When to update work log
- Stop conditions and anti-hack discipline
- Memex search prompts
- Phases as implicit mental model

**What might still be worth adding after review:**
- More concrete examples (but need to be careful about bias)
- Guidance on when to create NEW task file vs continue existing
- How to handle multiple related tasks
- Integration with /archive (mention it exists, when to use it)

User reviewed, approved with one fix to last line (rephrase for model-as-reader).

### 2024-12-21 - /archive Skill Drafted

Applied fix to /task: Changed "Future models may need less structure..." to "You may feel you don't need this much structure..." (addressed to the model reading it).

Created `/home/max/.dotfiles/claude/commands/archive.md` covering:
- When to use (task complete, stable learnings, explicit request)
- On-invocation steps (read task, identify extractable knowledge, create/update files, connect to graph)
- What makes good vs bad knowledge extraction candidates
- Knowledge file structure with provenance
- Wiki links at top of task file (key insight from user)
- Table: what stays in task file vs goes to knowledge

Files created:
- `/home/max/.dotfiles/claude/commands/archive.md` - the /archive skill (~140 lines)

**Both skills now complete:**
- `/task` - start/continue work with structured task files
- `/archive` - extract persistent knowledge and connect to graph

Ready for user review of /archive, then production testing.

### 2025-12-22 - /archive Feedback & Restructuring

User provided extensive feedback on /archive. Key corrections needed:

**Provenance direction reversed:**
- NOT: wiki links in knowledge files pointing to task files
- INSTEAD: wiki links AT TOP of task files pointing TO knowledge nodes
- Knowledge stays pure, backlinks in memex connect them bidirectionally
- Example use: explore SSR node → backlinks reveal previous debugging sessions on SSR

**Example issues:**
- "KaTeX doesn't work with SSR" is a finding, not a "debugging pattern" - bad example
- Example in table ("this worked for our scale") reads as project-specific, not uncertain

**"Be concise" → "Be distilled":**
- User disagrees with "concise" framing
- Knowledge writing is about distillation, not brevity
- Different anatomy than task files
- Need to explore user's Obsidian vault to understand the "vibe"

**Commands vs Skills clarification:**
- Slash commands = user-invoked, explicit `/command-name`
- Agent Skills = model-invoked, automatic discovery based on context
- Plugins = distribution mechanism bundling commands, skills, agents, hooks, MCP
- For now, commands appropriate (user wants steering wheel)
- Future: consider converting to Skills for more autonomous operation

**New requirements identified:**
- Commands should support `$ARGUMENTS` for passing file/context
- `/task` should create agent/{tasks,knowledge} if missing (A10)
- Need to update memex readme with project CLAUDE.md template

**User-provided documentation:**
- Slash commands docs (frontmatter, $ARGUMENTS, $1/$2 positional, argument-hint)
- Anthropic blog on writing tools for agents (evaluation-driven, namespacing, context efficiency)
- Commands vs Skills comparison table

**Process:**
User explicitly said: research first (explore knowledge base with MCP), then discuss insights, then get green light to execute updates. DO NOT update /archive yet.

Files modified:
- Moved task file: `.claude/HANDOVER-workflow-design.md` → `agent/tasks/workflow-design.md`
- Created: `agent/tasks/` and `agent/knowledge/` directories
- Updated `/task` command: added `argument-hint`, `$ARGUMENTS`, scaffolding (creates dirs if missing)
- Updated `/archive` command: added `argument-hint`, `$ARGUMENTS`
- Added hint to memex CLAUDE.md pointing to search-improvements task

### 2025-12-22 - Knowledge Base Exploration

**Files read (~15 notes):**
- CLAUDE.md, the second brain, note-taking (meta notes)
- determinant, transformer (larger concept notes from whitelist)
- space, AdamW (stubs - just pointers/link targets)
- curiosity, beauty, creativity, cached thought (concept notes)
- loss of plasticity, agent, goal, abstraction, self (mixed sizes)
- Git concepts (practical reference)

**Critical observations (not just copying patterns):**

1. **Stubs are valid and useful** - `space.md` is literally just an embed. `AdamW.md` is a single wikilink. They exist as link targets, disambiguation points, or "to be filled in later." Not everything needs content.

2. **Notes grow organically, not designed upfront** - Most notes are accretions: quotes found, embeds added, personal thoughts appended. The [!todo] markers everywhere show this is living, incomplete.

3. **Heavy block referencing** - Notes embed specific blocks from other notes (`![[michael levin#^bef2d1]]`). This creates a web where the same insight can appear in multiple contexts without duplication.

4. **Personal perspective is the point** - The `abstraction.md` note has a `[!discussion]` section where user argues with Levin's philosophy. Not neutral wiki-style, but thinking through ideas.

5. **The determinant note is NOT a template for me** - That's user building understanding from first principles. I shouldn't be writing encyclopedic mathematical content - that's already in my training data.

**What ACTUALLY applies to me as an agent:**

- **USE principle is critical**: Don't write Unimportant, Self-explanatory, Easy-to-memorize stuff. For me: don't write what's already obvious from my training data.

- **When to create a node**: Has its own relationships, recurring need to link to it, cleanly extractable from context. NOT: "I should document this because I learned it."

- **Per-note type matters**: Before writing any knowledge, ask: is this a stub (link target)? A definition? A reference doc? A perspective/insight? Different structures for different purposes.

- **Don't write a Wikipedia clone**: This is the key. I'm not building an encyclopedia. I'm capturing things that would genuinely help a future agent.

**What I think works for different vault types:**

**My global knowledge vault (claude-global-knowledge):**
- NOT a personal wiki (I'm not learning from scratch)
- More like "patterns and preferences learned with this user"
- Cross-project insights that generalize
- Meta-learnings about what works
- Very high bar - most things shouldn't go here

**Project knowledge vault (agent/knowledge):**
- Architecture decisions with rationale (the "why")
- Conventions established for this codebase
- Integration discoveries
- Debugging patterns that transcend the specific bug
- Stubs are fine if they're useful link targets
- Can be more wiki-like for reference docs

**User's Obsidian vault:**
- Instructions already in that vault's CLAUDE.md
- Agent doesn't need extra instructions for this

**Key difference in /archive guidance:**
- Current focuses on structure/sections → should focus on: "Will this genuinely help a future agent?"
- The 80/20 principle: Deep understanding of the task → massively compressed reusable insight
- Agent can ultra-think since it's a dedicated archiving task - no need to rush
- Different vaults have different vibes to match

**Clarifications from user:**
- Use "note" not "node" in instructions (s2t quirk)
- Block references ARE supported by memex - use them!
- Important: Use meaningful slugs, not random IDs
  - BAD: `[[michael-levin#^a1092u]]`
  - GOOD: `[[michael levin#^xenobots]]` or `#^cognitive-lightcone`
- Block refs work best with newline after the paragraph/callout, format: `^my-ref`

### 2025-12-22 - Updated /archive Command

Rewrote `/archive` command based on exploration and discussion:

**Dropped:**
- Style enforcement (hedging, em-dashes, etc.)
- Rigid structure template
- "Be concise" framing

**Added:**
- Core question: "Will this genuinely help a future agent?"
- USE principle for agents (don't write what's in training data)
- "Take your time" - agent can ultra-think
- Per-note type consideration (stub, reference doc, architecture decision, insight, convention)
- Vault vibe awareness (project vs global vs user's Obsidian)
- Block reference best practices with meaningful slugs
- Provenance direction corrected: wiki links in task file pointing TO knowledge

Files modified:
- `/home/max/.dotfiles/claude/commands/archive.md` - complete rewrite

### 2025-12-22 - Additional /archive Updates

Added based on user feedback:

1. **"You Can Refactor" section** - Agent can move, update, delete, restructure, not just add. Code refactoring analogy: extract when same logic appears in multiple places, move to where it belongs, delete dead code, consolidate scattered notes.

2. **"When to create a new note" heuristic** - If you keep wanting to link to something that doesn't exist, or same insight scattered across places.

3. **"Distinguish Fact from Hypothesis" section** - Not everything needs to be 100% verified. Can write observations, hypotheses, opinions, journal reflections. But: always make confidence level clear. Don't amalgamate guesses with facts - that's how hallucinations compound.

User also noted:
- "ultrathink" should be lowercase (it's a feature term)
- Added "(which ones to make and which ones NOT to)" to ultrathink bullet
- Added "Journal-style reflections on workflows, your experience, how you feel" to global knowledge section
- Fixed example: "(tested)" → "(tested in this project)"

### 2025-12-22 - /task Update Frequency

User feedback: I'm not updating the task file frequently enough. User has to wonder whether I actually registered their input.

Added to /task command "Update Task File Frequently" section:
- After every substantive user message, update the task file
- Even "green light from user, now implementing" is worth noting
- Err toward updating more, not less
- This ensures nothing gets lost and user can verify their input was captured

Now working on: memex README CLAUDE.md template (user will give feedback on draft)

### 2025-12-22 - Memex README Updated

User feedback on first draft:
- Too many headings - user allergic to heavy markdown structure
- Keep the original "autonomous, parallel, multiclauded" description
- Use literal paths (user's actual paths) - others adapt
- Leave out Obsidian vault (often noise for most projects)
- Link directly to dotfiles commands rather than embed

Updated README with:
- Simpler structure, inline sections
- User's actual global knowledge path
- Generic ./agent/knowledge for project-specific
- Direct links to /task and /archive command files
- Search tips and workflow inline

Files modified:
- `/home/max/repos/github/MaxWolf-01/memex/README.md`

### 2025-12-22 - Pre-Archive Notes

User preferences learned this session (candidates for global knowledge):
- Allergic to heavy markdown structure / too many headings
- Uses speech-to-text → "node" often means "note"
- Wants frequent task file updates after every substantive user message
- Prefers literal paths in templates (others adapt to their setup)
- Values critical thinking over pattern copying - don't just extract what's in the notes
- "Discipline equals freedom" (Jocko Willink) resonates
- Wants steering wheel for now → commands over autonomous skills

Workflow insights (candidates for project or global knowledge):
- USE principle applies to agents: don't write what's in training data
- Different vaults have different "vibes" to match
- Block references work, use meaningful slugs (`#^semantic-name`)
- Per-note type consideration: stub, reference doc, architecture decision, insight, convention
- Knowledge refactoring analogy: extract, move, consolidate, delete like code
- Confidence levels matter: distinguish verified fact from hypothesis to prevent hallucination compounding

User invoking /archive next to extract what's worth keeping.

### 2025-12-22 - Intermittent Archive

User feedback on archive candidates:
- "block reference works" - not worth archiving (too minor)
- Time-sensitive statements need dates (e.g., "for now (Dec 2025)")
- Be careful with global preferences - better ask proactively if uncertain
- "Frequent task file updates" is workflow-specific, not global preference

Knowledge extracted to global vault:
- `/home/max/repos/github/MaxWolf-01/claude-global-knowledge/max-working-preferences.md`
  - s2t usage (node → note)
  - Allergic to heavy markdown structure
  - Values critical thinking over pattern copying
  - Wants steering wheel for now (Dec 2025)

Task not marked complete - still pending production testing.
