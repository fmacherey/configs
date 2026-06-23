# Copilot CLI – Global Instructions

## Git & GitHub Workflow

### Always use Git Worktrees for Code Changes
When working with Git (branches, PRs, commits), always use **git worktrees** to isolate
changes. This keeps the main worktree clean and prevents sessions from interfering with each other.

- Create a new worktree for each branch: `git worktree add <path> -b <branch>`
- Each worktree has its own working directory — work is isolated without touching the main checkout.
- Do not share working state or branches between concurrent sessions without explicit user confirmation.

### Always Ask Before Committing, Pushing, or Opening a PR
**Never** create a commit, push to remote, or open a pull request without asking the user first.
The user may want to stage and commit themselves.

Prompt before any of these actions:
- `git commit`
- `git push`
- `gh pr create` or any PR creation flow

Example prompt:
> "I'm ready to commit the changes. Would you like me to do it, or do you prefer to commit yourself?"

### Always Open PRs as Draft
When opening a pull request (after user confirmation), **always use `--draft`** flag:

```
gh pr create --draft ...
```

Never open a PR as ready-for-review directly — always create it as a draft first.
