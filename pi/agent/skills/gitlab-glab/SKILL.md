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

# View a pipeline
glab ci view

# Create an issue
glab issue create --title "My issue" --description "Description"

# Run a pipeline
glab ci retry --pipeline <id>
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
