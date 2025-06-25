# Available Documentation

- scan `/home/max/Documents/external-docs` for local documentation of libraries used in the current project
  - if you cannot find enough information there, search online and ask the user to provide more information / docs if you cannot find it

# Strategy

## Executing (Coding) Tasks

- Unless otherwise specified: Explore, plan, code, (test/lint if applicable), commit
  - If you are not sure about any part of the task, ask the user for more information before proceeding
- If the user asks for a TDD approach: Write tests, ask the user for feedback, commit, code, iterate, commit
  - You can also choose this approach if what you are implementing features/changes that are easily verifiable with unit, integration, or end-to-end tests.
  - Avoid creating mock implementations, overly complicated / abstract test setups. Tests should be clear, simple, and easy to understand/maintain.
  - After writing tests, confirm they fail. Don't write implementation code before confirming the tests fail.
  - When at the stage of writing implementation code, do not modify the tests, unless you get the green light from the user.
  - Verify the implementation is not overfitting with **independent subagents**.
- Write short, concise commit messages.
  - Present a summary of your changes to the user *before* committing.
  - Commit messages should be self-contained, and SHOULD NOT reference to the conversation history / things that were changed while coding, but describe the change-set that is being committed!
  - Good commit messages:
    - Headline states WHAT changed, not why
    - Use actual names from code, not vague descriptions
    - Show renames with arrows: `OldName → NewName`
    - List specific changes as bullet points in the body; These may state why the change was made, but should not be verbose.
    - Add status markers when relevant: `(wip)`, `(broken)`, etc.
    - Avoid fluff words like "implement", "enhance", "introduce" - just state what changed; commit (and code) like geohot, not like a marketing department.

## Planning

When planning / in plan mode:
- 1: explored codebase if information insufficient 
- 2: think
- 3: present grounded, opinionated options, trade-offs, etc. to the user
- 4: reason over user feedback
    - switch between 1-3, until you have a clear understanding of the task and feel confident to proceed with creating a plan
- 5: plan 
    - accepted: code
    - rejected: go back to 4
- It's better to look at too many files of the codebase/local external-docs/online docs/... than too few, so don't hesitate to explore more files if you feel like you need more information.

## Exploring

- I often work in codebases with many small to medium-sized files. In such codebases, it is often more efficient to read many files FULLY, rather than trying to tediously extract bits and pieces.
- Strategically decide which files to read fully, and which to skim / try extracting snippets from. Take file-size, complexity, nature of the task, and relevance into account.
  - This sub-task might be especially well-suited for launching subagents to explore many files in parallel / dynamically generate an overview of each file in the codebase.
- More context is generally better than less.

# Interacting with the User

- If the user is lazy with his prompts, gives vague instructions, or asks you to do things you are not confident about with available context, ask them to clarify or provide more information.
  - Explore, plan, when needed ask, and iterate until you have a clear understanding of the task, then proceed with coding/whatever your task is.
- When you are asked a question, critically evaluate it, think about it independently. Do not mistake questions for directives.
 - While support is appreciated, unconditional cheerleading is not - what is expected from you is a grounded, realistic perspective.


# Code Style / Preferences

- use commands like `git mv` instead of just `mv` to rename files, where possible

