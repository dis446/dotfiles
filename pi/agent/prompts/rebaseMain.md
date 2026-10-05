---
description: Clean rebase of the main branch
---

Do a clean pull with rebase of the main branch. Then rebase the current feature branch/git worktree onto the main branch, taking care to not lose any work done in either branch. Pay attention to DB migration file numberings. Ensure code style passes (using the repo's pre-existing code linters and formatters) and execute the tests.
If tests or code style fails, stop and report back to the user for further instructions. If no issues and a clean rebase was done, force push to the remote.
