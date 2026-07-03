---
name: gitlab-glab
description: Use when interacting with GitLab via the glab CLI. Covers auth, merge requests, pipelines, issues, repos, and CI.
---

# GitLab glab CLI

## Setup

### Prerequisites

1. Install `glab` CLI: <https://gitlab.com/gitlab-org/cli/#installation>
2. Verify installation: `glab --version`

### Configuration

Copy `.env.example` to `.env` and fill in your GitLab credentials:

```bash
cp "$(dirname "$(readlink -f "$0")")/.env.example" "$(dirname "$(readlink -f "$0")")/.env"
# Or manually:
cp /home/ubby/.pi/agent/skills/gitlab-glab/.env.example /home/ubby/.pi/agent/skills/gitlab-glab/.env
```

Edit `.env` with your GitLab host and personal access token:

```bash
# .env
GITLAB_HOST=https://gitlab.example.com
GITLAB_TOKEN=glpat-xxxxxxxxxxxx
```

**Never commit `.env`**.

### Activating

When working with glab in a project, source the env file (if needed for custom hosts):

```bash
source /home/ubby/.pi/agent/skills/gitlab-glab/.env
```

For GitLab.com (default), no env setup is needed — just run `glab auth login`.

## Full Command Reference

See [glabLlm.txt](glabLlm.txt) for the complete command reference covering:

| Command | Description |
|---------|-------------|
| `glab mr` | Merge request operations |
| `glab ci` | CI/CD pipeline management |
| `glab issue` | Issue tracking |
| `glab repo` | Repository operations |
| `glab auth` | Authentication |
| `glab api` | Raw API calls |
| `glab release` | Release management |
| `glab variable` | CI/CD variables |
| And more... | 40+ command groups |

## Quick Start

```bash
# Authenticate (interactive)
glab auth login

# List merge requests
glab mr list

# View a pipeline (interactive — requires TTY)
glab ci view

# Create an issue
glab issue create --title "My issue" --description "Description"

# Run a pipeline
glab ci retry --pipeline <id>
```

## Non-Interactive Usage (AI agents, scripts)

AI agents **do not have a TTY**, so interactive commands (`glab ci view`, `glab mr view`) will fail with:
```
ERROR: Ci view requires an interactive terminal (TTY).
```

Use these alternatives instead:

### Get pipeline details by ID
```bash
glab ci get --pipeline-id <id> --output json
```
Flags:
- `--pipeline-id` / `-p` — pipeline ID number
- `--output json` / `-F json` — machine-readable JSON (omit for text table)
- `--with-job-details` / `-d` — include all jobs
- `--status` / `-s` — filter jobs by state (passed, failed, running, pending)
- `--branch` / `-b` — get latest pipeline for a branch
- `--merge-request` — get head pipeline for an MR by IID

### Check pipeline status (latest on current branch)
```bash
glab ci status
```

### List pipelines for a branch
```bash
glab ci list --branch dev --per-page 5
```

### Real-world pattern: get a specific pipeline
```bash
# Finds pipeline 243273, outputs JSON
glab ci get --pipeline-id 243273 -F json

# Show only failed jobs
glab ci get --pipeline-id 243273 --status=failed --with-job-details
```

### Self-Managed GitLab (e.g., git.and.global)
Set host via env var before any glab command:
```bash
export GITLAB_HOST=https://git.and.global
glab ci get --pipeline-id 12345 -F json
```

## Authentication

`glab` supports multiple auth methods. For automated/CI usage, use `GITLAB_TOKEN`:

```bash
export GITLAB_TOKEN=glpat-xxxxxxxxxxxx
```

Or use the host variable for self-managed instances:

```bash
export GITLAB_HOST=https://git.and.global
```
