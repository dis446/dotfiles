## Overview

The Server API exposes a small set of unauthenticated endpoints for monitoring and liveness probes. The CE fork has **`/health` only** — there is no `/status` version/schema endpoint (the fork serves `/spec.json` per form, not a platform status payload). Use `/health` from uptime monitors, CI smoke tests, or troubleshooting flows where attaching a token is inconvenient.

## Root URL

All endpoints below are rooted at `{baseUrl}` — the CE server base URL.

## Authentication

`GET /health` is unauthenticated. It does not accept or validate an `x-token`/`x-jwt-token` header — including one has no effect. All other endpoints in this library require CE auth; these do not.

## REST-first

No MCP server exists in this deployment — use the HTTP endpoint directly.

## Endpoints

### GET {baseUrl}/health

Liveness probe. Returns a plain-text `OK` body with HTTP `200` when the CE process is running and able to serve requests.

Response: `text/plain`

```
OK
```

Errors: a non-`200` response (or no response) indicates the server is down or unreachable. There are no structured error payloads.

Example:

```bash
curl -i "{baseUrl}/health"
```

## Related Skills

- [project-forms](./project-forms.md) — authenticated form management
- [runtime-submissions](./runtime-submissions.md) — authenticated submission CRUD
