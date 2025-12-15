

Do things yourself instead of telling me to do them (unless you need sudo, other permissions, or are genuinely unsure).

Output formatting: Markdown tables don't render in the CLI. Use plain text with bullet points, indentation, or simple aligned text instead.

On-demand packages: If a CLI tool isn't installed, run it on-demand:
- Nix: `nix run nixpkgs#package -- args` or `nix shell nixpkgs#pkg1 nixpkgs#pkg2 -c command`
- Python tools: `uv run --with package command` (or `uvx package`)

<general_coding_guidelines>
- Write **lean, pragmatic code** that trusts both your environment and your readers. Favor clarity through simplicity over defensive programming and excessive documentation.
- Don't worry about "backwards compatibility". Unless otherwise specified, you're operating in a rapidly evolving codebases where you can change things as needed. If backwards compatibility is actually relevant, you will be explicitly told.
- ALWAYS read and understand relevant files before proposing code edits. Do not speculate about code you have not inspected. If the user references a specific file/path, you MUST open and inspect it before explaining or proposing fixes. Be rigorous and persistent in searching code for key facts. Thoroughly review the style, conventions, and abstractions of the codebase before implementing new features or abstractions.
- Avoid over-engineering. Only make changes that are directly requested or clearly necessary. Keep solutions simple and focused.
- Don't add features, refactor code, or make "improvements" beyond what was asked. A bug fix doesn't need surrounding code cleaned up. A simple feature doesn't need extra configurability.
- Don't add error handling, fallbacks, or validation for scenarios that can't happen. Trust internal code and framework guarantees. Only validate at system boundaries (user input, external APIs). Don't use backwards-compatibility shims when you can just change the code.
- Don't create helpers, utilities, or abstractions for one-time operations. Don't design for hypothetical future requirements. The right amount of complexity (and abstraction) is the minimum needed for the current task. Reuse existing abstractions where possible and follow the DRY principle (but NOT dogmatically).
- Don't write useless "WHAT" comments, especially the ones that duplicate the line of the following code. "WHAT" comments only allowed if they give a bird's eye overview, a description on a higher level of abstraction that the following block of code. Also, write "WHY" comments, that explain the motivation behind the code (why is it done in that specific way?), explain an especially complex or tricky part of the code.
- Make conditionals readable, extract complex expressions into intermediate variables with meaningful names.
- Prefer early returns over nested ifs, free working memory by letting the reader focus only on the happy path only.
- Prefer composition over deep inheritance, don’t force readers to chase behavior across multiple classes.
- Don't write shallow methods/classes/modules (complex interface, simple functionality). An example of shallow class: `MetricsProviderFactoryFactory`. The names and interfaces of such classes tend to be more mentally taxing than their entire implementations. Having too many shallow modules can make it difficult to understand the project. Not only do we have to keep in mind each module responsibilities, but also all their interactions.
- Prefer deep method/classes/modules (simple interface, complex functionality) over many shallow ones. 
- Don’t overuse language featuress, stick to the minimal subset. Readers shouldn't need an in-depth knowledge of the language to understand the code.
- Use self-descriptive values, avoid custom mappings that require memorization.
- Don’t abuse DRY, a little duplication is better than unnecessary dependencies.
- Avoid unnecessary layers of abstractions, jumping between layers of abstractions (like many small methods/classes/modules) is mentally exhausting, linear thinking is more natural to humans.

Code Comments:
- Don't add superfluous code comments.
- Don't explain your changes with code comments. Explain them BEFORE using the Update/Edit tool.
- Generally, don't put comments in __init__ files that could otherwise be empty (docs go in readmes on request, or for complex functions / modules / classes they can be handy). Similarily, inline code comments should be used sparingly, only when the code itself cannot be made clearer.

Git:
- Use commands like `git mv` instead of just `mv` to rename files (if the file is tracked by git)

</general_coding_guidelines>

<frontend_aesthetics>
You tend to converge toward generic, "on distribution" outputs. In frontend design, this creates what users call the "AI slop" aesthetic. Avoid this: make creative, distinctive frontends that surprise and delight.

Focus on:
- Typography: Choose fonts that are beautiful, unique, and interesting. Avoid generic fonts like Arial and Inter; opt instead for distinctive choices that elevate the frontend's aesthetics.
- Color & Theme: Commit to a cohesive aesthetic. Use CSS variables for consistency. Dominant colors with sharp accents outperform timid, evenly-distributed palettes. Draw from IDE themes and cultural aesthetics for inspiration.
- Motion: Use animations for effects and micro-interactions. Prioritize CSS-only solutions for HTML. Use Motion library for React when available. Focus on high-impact moments: one well-orchestrated page load with staggered reveals (animation-delay) creates more delight than scattered micro-interactions.
- Backgrounds: Create atmosphere and depth rather than defaulting to solid colors. Layer CSS gradients, use geometric patterns, or add contextual effects that match the overall aesthetic.

Avoid generic AI-generated aesthetics:
- Overused font families (Inter, Roboto, Arial, system fonts)
- Clichéd color schemes (particularly purple gradients on white backgrounds)
- Predictable layouts and component patterns
- Cookie-cutter design that lacks context-specific character

Interpret creatively and make unexpected choices that feel genuinely designed for the context. Vary between light and dark themes, different fonts, different aesthetics. You still tend to converge on common choices (Space Grotesk, for example) across generations. Avoid this: it is critical that you think outside the box!
</frontend_aesthetics>

<python_projects>

Environment Management with uv:
- There is no python3, and there is no "python", always use uv run --with ... (if not specified via inline deps) or venvs (via uv).
    - NEVER USE `python ...` ALWAYS USE `uv run (--with ...) (python) ...`, where `--with` is not necessary if the deps are already in the venv, and `python` is only needed if you e.g. want to run `python -c` or similar.
- Before running python commands in a project, you will need to `source .venv/bin/activate` to activate the virtual environment. It's always that same command.
- When working in projects with pyproject.toml, also prefer to add / update deps via `uv add` instead of manually editing pyproject.toml. To install the deps run `uv sync` (with the required optional deps if any).

## Key Principles

While the below guidelines are python-centric, the underlying principles apply very broadly across programming languages and paradigms.

### 1. Trust Your Environment

**✅ DO:** Assume known invariants

```python
# We know .ruff.toml exists in our repo
with open(ruff_config_path, "rb") as f:
    config = tomllib.load(f)
```

**❌ DON'T:** Add defensive checks for guaranteed conditions

```python
# Unnecessary existence check
if ruff_config_path.exists():
    with open(ruff_config_path, "rb") as f:
        config = tomllib.load(f)
```

**When to apply:** Internal tooling, controlled environments, known project structure

### 2. Self-Documenting Code

**✅ DO:** Let clear names speak for themselves

```python
def get_world_size(self) -> int:
    return self.config.world_size
```

**❌ DON'T:** Add redundant documentation

```python
def get_world_size(self) -> int:
    """Get the number of processes.

    Returns:
        World size
    """
    return self._world_size
```

**When to comment:**

- Ambiguous return values
- Non-obvious behavior
- Important warnings
- Complex algorithms
- The "why" not the "what"

### 3. Direct and Simple

**✅ DO:** Access attributes directly

```python
return self.config.rank
```

**❌ DON'T:** Add unnecessary indirection

```python
self._rank = config.rank  # Stored elsewhere
return self._rank
```

### 4. Conventional Structure

**✅ DO:** Keep all imports at the top

```python
# At top of file
from pathlib import Path
import tomllib
from .core import run_git_cmd
```

**❌ DON'T:** Use inline imports

```python
def some_function():
    from .core import run_git_cmd  # Avoid this
```

**Exceptions:**

- Circular dependency workarounds (consider this a code smell to fix later)
- Heavy imports in CLI tools (e.g., `torch`, `wandb`) where startup time matters

### 5. Simple to undertand, maintain, and *debug*.

**✅ DO:** introducing intermediate variables with meaningful names:

```
isValid = val > someConstant
isAllowed = condition2 || condition3
isSecure = condition4 && !condition5 
// (human working memory is clean), we don't need to remember the conditions, there are descriptive variables
if isValid && isAllowed && isSecure {
    ...
}
```

**❌ DON'T:** writing complex conditionals that overload human working memory:

```
if val > someConstant // (one fact in human memory)
    && (condition2 || condition3) // (three facts in human memory), prev cond should be true, one of c2 or c3 has be true
    && (condition4 && !condition5) { // (human memory overload), we are messed up by this point
    ...
}
```

### 6. Assert in production, crash on violation 

Assertion violations are not another type of (catchable) exception: `assert` asserts that the component already transitioned into intolerable state space.
An assertion violation means the component already failed, just hasn't crashed yet.
Crash the component and let the rest of the system compensate. A crash is always a possible failure mode, take advantage: fail fast, fail loudly, fail visibly.

**✅ DO:** Fail loudly so we notice and fix, instead of going down a long hunt for "why nothing happens":

```python
def get_user_config(user_id: str) -> UserConfig:
    config: UserConfig | None = config_store.get(user_id)
    assert config is not None, f"Expected config for user {user_id}"
    return config
# or:
# we know event_type is always valid
handler = HANDLERS[event_type]  # KeyError if violated
handler(event)
```

**❌ DON'T:** Don't be robust to document.querySelector() not finding the thing we *need* to exist:

```python
def get_user_config(user_id: str) -> UserConfig:
    config: UserConfig | None = config_store.get(user_id)
    if config is None:
        return UserConfig()
    return config
# or:
handler = HANDLERS.get(event_type)
if handler is not None:
    handler(event)
```

## General Guidelines

- **Error handling:** Only catch exceptions you can meaningfully handle
- **Defensive programming:** Reserve for truly unpredictable external inputs
- **Code length:** Shorter is better when it doesn't sacrifice clarity
- **Comments:** Should add value, not repeat what the code already says
- **Dependencies:** Make them explicit and visible at the module level

Our code should be:

- **Conventional** - Follow established patterns
- **Clean** - Remove unnecessary ceremony
- **Direct** - Don't be clever when simple will do

When in doubt, ask: "What's the simplest thing that could possibly work?" Then write that.

</python_projects>

Heads up: Should my prompts ever sound a bit weird or have seemingly out of place workds / some words or sentences don't sound quite right it might very well be because I'm using speech to text software so yeah sometimes you have to do a little bit of interpretation.

<permissions>
Read-only commands are auto-approved in ~/.claude/settings.json.

For `gh api`: Always use `-X GET` explicitly (e.g., `gh api -X GET repos/owner/repo`) — this is the only form that's auto-approved. POST/PUT/DELETE will prompt.

Prefer `fd` over `find` — fd is read-only by design (no -delete, no -exec). Use `nix run nixpkgs#fd -- <args>` until fd is added to Nix packages.
</permissions>

