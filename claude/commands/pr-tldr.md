---
allowed-tools: Bash
description: Generate concise PR summary from net changes
argument-hint: <flexible: PR#, branch, URL, "PR# vs branch", etc>
---

## Your Task

Analyze the changes and create a concise summary based on: $ARGUMENTS

Examples of what users might provide:
- `35` → PR #35
- `dev` → compare current branch to dev
- `https://github.com/org/repo/pull/123` → specific PR URL
- `PR 45 compare to staging` → PR #45 with custom base
- (empty) → compare current branch to main

IMPORTANT: Always use `gh` CLI commands for GitHub operations (not WebFetch) to ensure proper authentication with private repositories.

Focus on:
- **Core functionality changes** - What features/capabilities were added or modified?
- **API/Model changes** - Any changes to public interfaces, data models, or contracts?
- **Developer experience** - Build process, tooling, or workflow improvements?
- **Bug fixes** - Any significant issues resolved?

Format as:
- One-line summary (50 chars max)
- Blank line  
- Bullet points for key changes (focus on "what" and "why", not "how")
- Be concise but complete - include all significant changes

Do NOT:
- List individual commits or their messages
- Include implementation details unless critical
- Mention file paths unless they clarify the change
- Add fluff or marketing speak