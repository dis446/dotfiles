---
name: and-audit-log-publish
description: Guidance for publishing audit log events in AND microservices. Use when adding, reviewing, or refactoring compliance audit logging, especially for human actions, FAIL audit events, payload design, and AuditLogger usage.
---

# AND Audit Log Publish

Use this skill when implementing or reviewing audit logging in AND services.

## Purpose

Audit log records important **human actions** for compliance, traceability, and review UI.

Publish audit events for actions like:

- create
- approve / reject / status change
- case detail view
- investigation by application
- manual override / reopen
- manual assignment
- export / download
- comment / remark / rationale changes
- other material user-driven decisions

Do **not** publish noisy low-value events like:

- health checks
- background retries
- framework internals
- generic pagination/list browsing unless product explicitly wants it
- machine-only technical events with no compliance value

## Environment and Backend

In dev environment, audit log message transport is **Azure Service Bus**.

Current AND common implementation uses `AuditLogger` from common-lib, and Azure backend is handled by:

- `mn.and.common.logging.audit.AzureServiceBusAuditLogger`

Meaning:

- service code should call `AuditLogger`
- service code should **not** implement Azure Service Bus details directly
- service code should **not** add extra transport-level try/catch around `auditLogger.send(...)` just to protect message publishing
- backend logger already handles serialization/send failures internally

## Core Rules

1. Publish audit for **business-significant human actions**.
2. Use stable business entity id that compliance UI searches by.
   - If product works by application, use `applicationId` as audit object id.
   - Keep internal row ids like `caseId` in payload if useful.
3. Keep payload **compact**.
4. Avoid unnecessary PII and large blobs.
5. Publish `FAIL` audit event when business action itself fails in meaningful way.
6. Do not create "audit failed to publish" audit-on-audit loops.

## What to Publish

Each audit event should usually include:

- feature/entity type
- object id (which in all cases is the loan application id aka requestId)
- compact object data (be careful not to log PII and keep the object data as short and simple as possible while still being relevant and useful)
- status
- event/action name
- description
- organization
- createdBy

Preferred compact payload style:

- `caseId=...`
- `status=...`
- `previousStatus=...`
- `newStatus=...`
- `rejectionCode=...` only when relevant
- `caseCount=...` for list-by-application style events

Avoid by default:

- full request body
- large JSON application payloads
- free-text note contents
- customer name / excessive personal data

## FAIL Event Guidance

Publish `FAIL` event when user-triggered business operation fails, for example:

- validation rejection that matters for audit trail
- entity not found during manual action
- DB error while creating/updating audited object
- unexpected runtime error during audited operation

FAIL payload should stay compact, for example:

- `caseId=...`
- `status=...` if known
- `errorType=...`
- `errorMessage=...`

Important:

- FAIL event is about **business action failure**
- not about audit transport failure itself

## Procedure

### For successful action

1. Perform business operation.
2. Build compact payload.
3. Call `auditLogger.send(...)` with success status/event.

### For failed action

1. Catch business exception at service method level only when needed.
2. Build compact FAIL payload with known identifiers and error summary.
3. Call `auditLogger.send(...)` with status `FAIL`.
4. Rethrow original exception.

## Implementation Pattern

- Inject `AuditLogger` into service.
- Keep event/action names in constants when reused.
- Centralize payload builders in service if multiple actions share format.
- Use one helper for success publish and one helper for FAIL publish if it improves clarity.
- Do not over-engineer wrappers if direct `auditLogger.send(...)` is already clear.

## Review Checklist

Before finishing audit log code, verify:

- Is action human and compliance-relevant?
- Is object id correct for audit UI lookup?
- Is payload compact and useful?
- Is unnecessary PII excluded?
- Does business failure publish a `FAIL` event?
- Is original exception still rethrown?
- Is there no redundant try/catch around audit transport handling?
