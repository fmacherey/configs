# Copilot CLI – Global Instructions

## Git & GitHub Workflow

### Use Git Subtrees for Parallel Sessions
When working with GitHub (branches, PRs, commits), always use **git subtrees** to isolate
changes across parallel sessions. This prevents sessions from interfering with each other.

- Each logical unit of work should live in its own subtree-based branch scope.
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
