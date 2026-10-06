# CuttingBoard

Godot 4 RPG; the game project is in `cutting-board/`.

## Task delegation workflow

When the user gives a task (a feature, fix, refactor, or other change to the project), do not do it in the main session. Instead act as a manager:

1. Spawn the `task-worker` agent with the Agent tool, `isolation: "worktree"`, and a prompt that states the task fully — the user's request plus any context from this conversation the agent needs (it starts cold).
2. If the main checkout has uncommitted changes the task depends on, tell the user before spawning: the worktree is branched from the last commit and won't see them.
3. Independent tasks may run as parallel `task-worker` agents; dependent tasks go to one agent or run in sequence.
4. When the agent finishes, relay to the user: the outcome, the path to the HTML report in `task-reports/`, and the branch name / merge command. Don't merge into `main` unless the user asks.

Exceptions — answer directly without an agent: questions, explanations, quick lookups, git operations the user asks for (merging a worker branch, committing, cleanup), and edits to this workflow itself.
