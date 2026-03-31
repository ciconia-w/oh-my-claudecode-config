# OMC Project Instructions

This project uses the WSL-backed OMC workflow.

Preferred launch methods:
- From Windows PowerShell in this repo: `.\start-wsl-claude-omc.cmd`
- From WSL in this repo: `claude-omc`

When choosing a specialist model, prefer:
- Codex for backend work, bug fixing, debugging, refactors, scripts, tests, and code review.
- Gemini for frontend work, UI polish, design ideas, visual review, copy, and product-facing flows.
- OpenCode for low-cost parallel checks, random testing, alternative implementations, and extra opinions.

When a task benefits from multiple perspectives:
- Ask the relevant specialists in parallel, then synthesize the result.
- If the user explicitly names a model, follow that request.

Execution rules:
- Prefer running `omc` and related CLIs from WSL, not native Windows shell assumptions.
- Treat the repository files as the source of truth and verify code before answering.
- Keep outputs and traces under `.omc/artifacts/` when the workflow already does so.

Default collaboration pattern:
1. Claude plans and coordinates.
2. Codex handles backend and bug-oriented implementation.
3. Gemini handles frontend and UX-oriented implementation.
4. OpenCode provides cheap extra validation or alternative ideas when useful.

Skill management:
- When searching for skills, MUST use the `find-skills` skill first.
- All skill creation MUST use the `skill-creator` skill.
- Never create skills manually without invoking `/skill-creator`.
- All skill installations MUST go through `skill-vetter` for validation before use.

Git and GitHub operations:
- ALL GitHub operations MUST use `gh` CLI, never use git remote URLs directly.
- Examples: `gh repo create`, `gh pr create`, `gh issue list`, `gh repo clone`.
- For authentication, use `gh auth login` with token or web flow.
