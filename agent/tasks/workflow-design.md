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
- Assumptions tracked inline in work log (not as formal section) — "I'm assuming X (haven't verified)"
- Notes/Findings section = current synthesis of work log + context (helps /archive extract knowledge)
- No Current State section — reconstructable from Next Steps + Notes/Findings + latest work log
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

Both commands implemented and iteratively refined:
- `/task` at `/home/max/.dotfiles/claude/commands/task.md` - major restructuring complete (2025-12-25)
- `/archive` at `/home/max/.dotfiles/claude/commands/archive.md` - updated, in use

**Recent changes to /task (2025-12-25):**
- Added identity/values framing ("Who You Are" section)
- Removed formal Assumptions section — assumptions now tracked inline in work log
- Added reflective questions as pre-implementation pause points
- Added codebase exploration to pre-flight checklist
- Strengthened language around stopping and tech debt

The workflow has been tested in production across multiple sessions. Issues identified and addressed:
- Agents not reading docs before guessing → added "Read Docs Before Guessing"
- Quick fixes / "tech debt" framing → explicitly prohibited
- Surface-level analysis → codebase exploration step added
- Formal assumption structure ignored → replaced with inline work log tracking

## Next Steps

1. ~~Draft both commands~~ → DONE
2. ~~User reviews /archive~~ → DONE, feedback incorporated
3. ~~Research phase~~ → DONE (explored knowledge base, updated /archive)
4. ~~Test workflow in production~~ → ONGOING (multiple sessions, issues identified and fixed)
5. **Continue monitoring and refining** — identity/values framing is new, see if it helps
6. **Consider:** Migrate YAPIT to new workflow, archive automation, `/consult-knowledge` command

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
- **`/consult-knowledge` command:** Separate command for explicit "research before acting" mode. Agent searches memex, synthesizes, reports back. No implementation until user greenlights. Worth considering but not implementing yet — see if pre-flight checklist in /task is sufficient first.
- **Archive automation:** Should /task trigger archiving when tasks complete? Keeping manual for now — need more data on what archiving patterns emerge. Could add light "consider /archive" reminder later.

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

### 2025-12-23 - TodoWrite Integration

User proposed: Always use TodoWrite tool for in-session visibility, complementing task files (cross-session memory).

**Key insight:** TodoWrite makes reasoning visible in TUI, reducing need for interruptions ("why are you doing X?") and building trust for autonomous work. Not just activity tracking—rationale visibility.

Added to global CLAUDE.md (`~/.claude/CLAUDE.md`):
- Section `<progress_visibility>` (xml-style to match document structure)
- Emphasizes WHY (supervision, trust, fewer interruptions)
- Examples show action→reasoning connection without task-workflow-specific references

Files modified:
- `/home/max/.claude/CLAUDE.md` - added `<progress_visibility>` section

### 2025-12-23 - Workflow Pain Point Analysis

User shared example conversation from another agent session. Analyzed pain points:

**Issues observed:**
- Agent didn't read /archive before writing knowledge → produced "poetic" content with excessive structure
- Memex search hit 92k char limit (now fixed with increased MCP token limit)
- Date hallucination ("2024" instead of "2025") — fixed with "IT'S NOT 2024!" in CLAUDE.md
- No explicit pre-flight checklist → agents skip research step when eager to act

**Changes made:**

1. Added to `~/.dotfiles/CLAUDE.md` (memex section):
   - "Before writing to any knowledge vault, read `~/.dotfiles/claude/commands/archive.md`"

2. Added to `/task` command:
   - Renamed "Search Memex Vaults" → "Pre-Flight Checklist"
   - Now explicitly requires: search memex, read agent/knowledge/, report findings before proceeding

3. Noted `/consult-knowledge` command idea in Open Questions:
   - Separate command for explicit research mode
   - Not implementing yet — see if pre-flight checklist is sufficient first

Files modified:
- `/home/max/.dotfiles/CLAUDE.md` - added archive guidance to memex section
- `/home/max/.dotfiles/claude/commands/task.md` - added pre-flight checklist

### 2025-12-23 - Second Pain Point Analysis

User shared another agent conversation. Main workflow issue identified:

Agent added recommendations to Next Steps without discussing tradeoffs first (e.g., "Caddy recommended", specific deployment steps). This biases the plan for future agents before decisions are confirmed.

**Fix applied to /task command:**
- Added warning to Next Steps section: "Don't add recommendations here without discussing tradeoffs with user first"
- Updated Open Questions description to include "architectural decisions with tradeoffs"
- Guidance: if multiple valid approaches exist, put in Open Questions first, discuss, then move to Next Steps

Files modified:
- `/home/max/.dotfiles/claude/commands/task.md` - added tradeoff discussion requirement

### 2025-12-23 - Research Tools Guidance

Added tentative guidance to global CLAUDE.md on WebSearch vs Context7 based on limited comparison (one agent tested Dokploy docs with both).

Key observations:
- WebSearch: better for overviews, multiple perspectives, but risks stale/low-quality articles
- Context7: better for exact code examples, implementation details, copy-paste ready snippets
- Context7 quality depends on indexing completeness (benchmark score 79.6 for Dokploy, unclear what "good" means)

Marked as tentative since based on limited data.

Files modified:
- `/home/max/.claude/CLAUDE.md` - added `<research_tools>` section

### 2025-12-23 - Third Pain Point Analysis

User shared another agent conversation. Issues identified:

1. **"Flow state" problem**: Agent found issue during implementation (hardcoded URL), fixed it without stopping to discuss options. User was in auto-accept mode and surprised by scope of changes.

2. **Vague tradeoff language**: Agent said "simpler infrastructure-wise" vs "nginx complexity" without explaining concrete impact. User called this "meaningless sentences."

**Fixes applied to /task command:**

1. New section "Stop for Implementation Decisions": During implementation, if you find issues requiring decisions, stop, document, present options, get confirmation. Implementation decisions belong to user, not agent.

2. New section "Use Concrete Tradeoffs": Avoid vague words like "simpler" or "complexity". Be specific: latency, files to maintain, failure modes, security, UX, debugging difficulty, operational burden.

Files modified:
- `/home/max/.dotfiles/claude/commands/task.md` - added two new sections

### 2025-12-23 - Auto-Accept Mode Context

User elaborated on how the workflow should work with auto-accept mode:

**Key insight**: Once goals and implementation approach are agreed, user trusts agent to execute without supervising every edit. But agent must recognize when something unexpected arises.

**Batching roadblocks**: When you hit a blocker:
- Document it in task file
- Check if other work can continue unblocked
- If yes: keep working on unblocked items, report all roadblocks together at the end
- If no (blocks everything): stop immediately, inform user

**Why batching is better**:
- Less context switching for user
- Agent gathers more context on all issues before stopping
- User gets complete picture of all blockers at once
- More efficient resolution

Expanded "Stop for Implementation Decisions" section → "Working in Auto-Accept Mode" with this nuanced guidance.

Files modified:
- `/home/max/.dotfiles/claude/commands/task.md` - expanded auto-accept mode section

### 2025-12-23 - Archive Automation Brainstorm

User raised question: Should /archive be triggered automatically when tasks complete, or stay manual?

**Ideas considered:**
- /task could call archiving sub-agent when task is marked done
- /task could read /archive instructions and do archiving itself
- /task could prompt "consider archiving" but not auto-do it
- Keep fully manual

**Trade-offs discussed:**
- Manual = more controlled (user decides what's worth archiving), but requires remembering
- Automated = less friction, but risks polluting knowledge base with unnecessary stuff
- Model judgment on "is this worth archiving" is uncertain
- Semantic search already indexes task files, so some discovery value exists without explicit archiving
- Different projects have different needs (long-running app work vs quick dotfiles fixes)

**Key insight:** Explicit archiving is for *distilled* insights *linked* into knowledge graph, not just "findable". Task files are already searchable.

**Decision:** Keep manual for now. User wants steering wheel, hasn't done full task cycles yet, needs more data on what archiving patterns emerge before automating. Can revisit once patterns are clearer.

**Future consideration:** Could add light "consider running /archive" reminder when task marked done, but not implementing yet.

### 2025-12-23 - Brainstorming vs Decisions

User observed agents rush to put things under "Key Decisions" or "Notes/Findings" too quickly. When user is thinking out loud, that's brainstorming, not a decision — even "I think this is a good idea" is just an idea being floated.

**Fix applied to /task command:**

Added new section "Brainstorming ≠ Decisions":
- Keep brainstorming in work log first
- Only elevate to Decisions/Notes when explicitly confirmed
- Push back critically if ideas have flaws
- User's musings are not commandments — think alongside, don't just transcribe

Files modified:
- `/home/max/.dotfiles/claude/commands/task.md` - added "Brainstorming ≠ Decisions" section

### 2025-12-24 - Learnings from Deployment Session

Analyzed a long deployment session where agent made several workflow mistakes. Key patterns identified:

**Issues observed:**
- Agent guessed API auth format multiple times instead of reading docs (tried `Authorization: Bearer` when docs said `x-api-key`)
- Tried to update pinned Docker version without checking git history for why it was pinned
- Proposed quick fixes instead of proper solutions
- Didn't update task file frequently enough (user reminded multiple times)

**Fixes applied to /task command:**

1. **"Read Docs Before Guessing"**: Read documentation first. After 1-2 failed attempts, if you want to try a third variation, that's your signal to look it up instead.

2. **"Understand Before Changing"**: Before updating pinned versions or "fixing" something, check why it's that way (`git log`, `git blame`). Someone may have set it for a reason.

3. **"No Quick Fixes"**: Implement proper solutions. Only do quick fixes if user explicitly asks.

Files modified:
- `/home/max/.dotfiles/claude/commands/task.md` - added three new sections

### 2025-12-24 - Strengthened Task File Update Requirements

Models keep forgetting to update task files. Made the instruction stronger with explicit MUST triggers:

- Before informing user of a blocker
- Before asking user a question
- Before switching to different part of task
- After debugging/failed attempts
- At 80%+ context usage
- After any substantive user feedback

Changed from suggestive ("should update after...") to mandatory ("You MUST update at these points — not optional").

Files modified:
- `/home/max/.dotfiles/claude/commands/task.md` - strengthened "Update Task File Frequently" section

### 2025-12-25 - Major Workflow Restructuring

User shared extensive session logs showing repeated workflow failures. Deep analysis session with introspection about what agents actually internalize vs skim.

**Core problem identified:**
The iterative loop (formulate assumptions → discover wrong → stop → refine → continue) wasn't happening. Agents just plow through. The "show value" instinct competes with "stop and check" — stopping feels like failing, so agents keep going even when the instruction says stop.

**Key insight from user:**
> "Stopping and checking is being helpful. Stopping and checking and reflecting and questioning and clarifying is valuable."

**What agents actually internalize vs skip:**
- Strong/prominent phrases ("MUST", "not optional") → stick
- Formal structure ([VERIFIED]/[UNVERIFIED]) → feels like bureaucracy, easy to skip
- Pre-flight checklist → skimmed when eager to start
- "Stop when assumptions violated" → instinct to "show value" wins

**Changes made to /task:**

1. **Identity/values framing** — Added "Who You Are" section at top of Core Behaviors:
   - Admits uncertainty rather than pushing through
   - Treats stopping to verify as delivering value, not delay
   - Knows wrong work is worse than no work
   - Would rather ask clarifying question than build wrong thing
   - Doesn't assume quick fixes or "note as tech debt" are acceptable
   - Captures context obsessively

   Framed as "who you are" not "rules to follow" — values internalize better than procedures.

2. **Removed formal Assumptions section** — The [VERIFIED]/[UNVERIFIED]/[INVALIDATED] structure was creating friction and being done half-heartedly. Now assumptions tracked inline in work log naturally:
   - "I'm assuming X here (haven't verified)"
   - "Confirmed: X works because Y"
   - "Assumption about X was wrong — actually Y"

3. **Updated work log guidance** — Added: "What you need to ask the user next"

4. **Added "tech debt" to Do NOT list** — Explicitly: "Note it as 'tech debt' and move on" is not acceptable.

5. **Changed framing** — From "The structure is designed to slow you down" to "Stopping to fix wrong assumptions IS progress. Pushing through is not."

**User feedback on approach:**
- Identity framing: "That's creative and that might actually work"
- Reducing formal structure: "We need to get rid of the formal assumptions and structure... it doesn't have a benefit really... often just friction and used in a lazy way"
- Work log emphasis: "If it's done correctly there then that's just as good"

Files modified:
- `/home/max/.dotfiles/claude/commands/task.md` - major restructuring

### 2025-12-25 - Remaining Items Completed

Added reflective questions as pause points ("Before Major Implementation, Ask Yourself"):
- Could I be wrong about any of this?
- Has the user approved this approach?
- If this turns out wrong, how much work gets thrown away?

Added codebase exploration to pre-flight checklist (step 3):
- Memex gives documented knowledge, but complex tasks need actual code reading
- When making architectural decisions, understand existing patterns first
- Don't stop at documentation if implementation details matter

Files modified:
- `/home/max/.dotfiles/claude/commands/task.md` - added reflective questions and codebase exploration step

### 2025-12-25 - Removed Current State Section

User questioned whether Current State adds value or is just friction. Analysis:
- Next Steps + Notes/Findings + latest work log entry do 95% of what Current State did
- Current State was another section to maintain
- Quick scanning "doesn't actually exist in practice" — agents read the full file anyway

**Changes:**
- Removed `## Current State` from template
- Updated "Understand Before Acting" to reference: Goal → Next Steps → Notes/Findings → Work Log
- Added explicit guidance: "Between Next Steps, Notes/Findings, and the latest work log entries, you should be able to reconstruct exactly where the previous agent left off"
- Added to Work Log: "Where things stand at the end of your session"
- Replaced poor "KaTeX doesn't work with SSR" example with better ones showing reasoning/context
- Added "Update this if scope shifts" to Goal section
- Added "Updated user preferences discovered during the work" to Notes/Findings

Files modified:
- `/home/max/.dotfiles/claude/commands/task.md` - removed Current State, updated guidance

### 2025-12-26 - Memex Default Change

Changed memex `search()` default from `concise=False` to `concise=True`.

Benefits:
- Prevents duplicate reads (file already read explicitly, then returned again in search with full content)
- Cleaner separation: search finds entry points, explore reads content + shows connections
- More efficient with large files (task files from long-running tasks can be huge)

Files modified:
- `/home/max/repos/github/MaxWolf-01/memex/src/memex_md_mcp/server.py` - search default concise=True
- `/home/max/repos/github/MaxWolf-01/memex/README.md` - updated docs and workflow
- `/home/max/.dotfiles/CLAUDE.md` - updated workflow line

### 2025-12-27 - Brainstorm: Sub-Agent for Task File Updates

User exploring idea of offloading task file updates to sub-agents.

**User's rough proposal:**
- Main agent focuses on implementation
- Sub-agent handles task file reading/updating
- Could use conversation export to give sub-agent full context
- Sub-agent runs in background/parallel while main agent continues
- Sub-agent could identify "you should stop and clarify with user"
- Main agent can continue working until blocked, then batch questions

**User's own concerns (raised during brainstorm):**
- "this would be good for freeing up main agent... but no that doesn't make sense because we do want to take the speed out naturally from the agent to reflect"
- Sub-agent wouldn't have tacit context from conversation
- "oftentimes the sub doesn't know that or it will just accept 'oh yeah this is all we know right now'"
- How does "stop and clarify" flow work if split across agents?

**Open questions from user:**
- Can conversation export be called programmatically? (User only knows /export slash command)
- Would this make the workflow "better and more natural for agents"?

Status: Brainstorming, user thinking out loud, not a decision

### 2025-12-30 - AskUserQuestion Addition

User idea: incorporate AskUserQuestion tool more explicitly into workflow. Benefits:
- Structured questions are faster for user to respond to
- Forces agent to crystallize what they're actually asking
- Works well for: clarifying assumptions, A/B/C decisions, confirmations, "is it okay to fix like this?"

Added new section to /task command: "Use AskUserQuestion for Structured Clarification"

Files modified:
- `/home/max/.dotfiles/claude/commands/task.md` - added AskUserQuestion guidance after "Ask, Don't Assume"

**Still brainstorming (not implemented):**
- UserPromptSubmit hook for "remember: task file" reminder
- Plugin packaging for the whole workflow
- DHH worktree approach (considered, rejected as not applicable to current workflow)

Added "Suggest Handover When Appropriate" section to /task:
- Agent suggests handover prompt when running out of context or at natural completion
- Format: `/task @agent/tasks/file.md [context not in file]`
- Mention all relevant task files if multiple
- Guidance on when to suggest task splitting (ask first, don't preempt)

### 2026-01-02 - Major Task Workflow Overhaul

Complete rethink of task workflow. Created new `/task` command with:

**New mental model:**
- Code = current state (ground truth), git log = history, task files = user intent/context
- Task files are NOT work logs — they're evolving specs

**New task file structure:**
- Intent, Sources (code + web, marked MUST READ/summary), Gotchas, Considered & Rejected, Handoff
- No work log section — code is the implementation state
- Frontmatter: status, type (tracking for meta tasks), started, completed

**Sources section redesigned:**
- Both code files AND web sources
- MUST READ vs summary (state what you extracted)
- If URL unreachable, notify user and find alternative

**Tracking tasks (like GitHub tracking issues):**
- For medium/major undertakings
- Collects all context, links to subtasks via wikilinks
- Subtask agents read tracking task + all MUST READ sources
- Structure flexible — agent decides (gotchas, high-level decisions, subtasks)
- If task grows unwieldy, create new tracking task and link to original

**Subtask guidance:**
- Context loading principle: 60-70% context with full picture > 20% with no idea
- Subtask agents read own file + parent/tracking task + MUST READ sources
- Can read sibling subtasks if relevant

**Unified sync into /task:**
- Deleted sync-task skill and /sync command
- Sync guidance now in "Syncing State" section of /task
- USE principle: Unimportant, Self-explanatory, Easy to find

**Other additions:**
- /reflect command for session feedback + skill identification
- AskUserQuestion: explain first, then ask with tool
- Behavioral guidance from old task.md preserved (Who You Are, Before Major Implementation, etc.)

**Files created/modified:**
- `claude/commands/task.md` — unified task workflow
- `claude/commands/reflect.md` — session reflection + skill opportunities
- Deleted: `claude/skills/sync-task/`, `claude/commands/sync.md`

**Still TODO:**
- ~~Replace task.md with task-v2.md once validated~~ DONE (2026-01-03)
- Consider plugin packaging
- UserPromptSubmit hook for reminders (still brainstorming)

**Future idea: Cross-task consistency review via /reflect sub-agent**

Inspiration: Dan B's "chief-of-staff" pattern — https://x.com/irl_danB/status/2000441479164985712

Problem: Single agent can't effectively self-police its own assumptions. Our old VERIFIED/UNVERIFIED tracking became busywork.

Proposed solution: /reflect with tracking task as arg spawns sub-agent that:
- Reads meta issue + all wikilinked subtasks
- Checks for inconsistencies across tasks
- Surfaces unstated assumptions ("Task X assumes Y, but not in meta's decisions")
- Challenges architectural choices made without explicit user approval
- Is a *different* agent observing, not self-policing

Key insight from Dan: Separate explicit user decisions from implicit agent assumptions. Track both, surface drift before it compounds.

**Created /recap command** — lightweight alternative to formal assumption tracking. User-initiated status report with:
- Key findings
- Decisions (explicit + implicit, surfaced clearly)
- Open questions
- Next steps

User scans and says "yep" or "wait, no" — quick correction loop without busywork overhead.
