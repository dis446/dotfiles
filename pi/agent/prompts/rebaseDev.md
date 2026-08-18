---
description: Clean rebase of the dev branch
---

Do a clean pull with rebase of the dev branch. Then rebase the current feature branch onto the dev branch, taking care to not lose any work done in either branch. Pay attention to DB migration file numberings. Ensure code style passes (using the repo's pre-existing code linters and formatters) and execute the tests.
If tests or code style fails, stop and report back to the user for further instructions. If no issues and a clean rebase was done, force push to the remote.
