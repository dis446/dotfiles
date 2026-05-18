---
name: and-audit-log-publish
description: Guidance for publishing audit log events in AND microservices. Use when adding, reviewing, or refactoring compliance audit logging, especially for human actions, FAIL audit events, payload design, and AuditLogger usage.
---

# AND Audit Log Publish

Use this skill when implementing or reviewing audit logging in AND services.

## Purpose

Audit log records important **human actions** for compliance, traceability, and audit-review UI.

Publish audit for actions like:
- create
- approve / reject / status change
- detail view of sensitive business record
- application/request investigation
- manual override / reopen / retry
- manual assignment / reassignment
- export / download
- comment / remark / rationale change
- other material user-driven business decisions

Do **not** publish noisy low-value events like:
- health checks
- background retries
- framework internals
- generic technical events with no compliance value
- routine pagination/list browsing unless product explicitly wants it

## Platform Standard

Target platform pattern for AND microservices:
- use `mn.and.common.logging.audit.AuditLogger`
- use one **domain audit facade/service** per microservice, for example:
  - `CaseAuditService`
  - `ContractAuditService`
  - `DocumentAuditService`
- centralize:
  - audit action names
  - statuses
  - feature/entity names
  - payload builders
  - FAIL-event publishing helpers

Do **not** scatter raw `auditLogger.send(...)` calls everywhere once repo grows.

## Environment and Backend

In dev environment, audit log transport is **Azure Service Bus** via common-lib.

Relevant common implementation:
- `mn.and.common.logging.audit.AuditLogger`
- `mn.and.common.logging.audit.AzureServiceBusAuditLogger`
- `mn.and.common.logging.audit.DefaultAuditLogger`

Meaning:
- service code should call `AuditLogger`
- service code should **not** implement Azure Service Bus details directly
- service code should **not** add extra transport-level try/catch around `auditLogger.send(...)` only to protect broker publishing
- transport/logger implementation already handles serialization/send failures internally

## Core Rules

1. Publish audit for **business-significant human actions**.
2. Use stable **business lookup id** as `objectId`.
   - Use whichever id audit UI and operations users naturally search by.
   - Often this is `applicationId` or `requestId`.
   - Sometimes it is entity UUID if that is primary lookup key.
   - Do **not** assume one universal id across all repos.
3. Keep payload **compact**.
4. Avoid unnecessary PII, large blobs, and internal infrastructure details.
5. Publish `FAIL` audit event when business action itself fails in meaningful way.
6. Do not create audit-on-audit loops for transport failures.
7. Never pass raw request/response/entity objects to audit logger unless payload is already known-safe and small.

## What to Publish

Each audit event should usually include:
- feature/entity type
- object id
- compact object data
- status
- event/action name
- description
- organization
- createdBy
  - prefer actor user id when available
  - otherwise fall back to authenticated/request user id

Preferred compact payload style:
- `caseId=...`
- `bundleId=...`
- `contractId=...`
- `status=...`
- `previousStatus=...`
- `newStatus=...`
- `rejectionCode=...` only when relevant
- `resultCount=...` or `caseCount=...` when count itself matters
- `errorType=...`
- `errorMessage=...`

Avoid by default:
- full request body
- full response body
- large JSON payloads
- template/document content
- storage paths / internal infrastructure values
- free-text notes/comments/rationale bodies
- customer name, email, or other PII unless explicitly required by compliance

## FAIL Event Guidance

Publish `FAIL` when user-triggered business operation fails, for example:
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

## Recommended Clean Pattern

Preferred service-level structure:
1. business service/resource performs operation
2. domain audit facade builds compact payload
3. facade publishes success event
4. if business action fails, facade/helper publishes `FAIL` event
5. original exception is rethrown

If many endpoints need same success/failure pattern, create one reusable helper/wrapper in repo.
Do **not** duplicate large try/catch blocks in every method if a clearer shared pattern is available.

## Implementation Guidance

- Inject `AuditLogger` into audit facade/service, not every class by default.
- Avoid publishing directly from resource/controller layer unless repo is very small or there is no better abstraction.
- Keep event/action names in constants or enums.
- Centralize payload builders near audit facade.
- Build explicit safe payload strings/maps.
- Prefer small helper methods over hidden magic.
- If using request/response failure context, ensure stored payload is already sanitized and compact.
- If repo uses local audit DB or custom wrapper, treat that as repo-specific pattern unless it aligns with platform standard.

## Procedure

### Success event
1. Perform business operation.
2. Build compact payload from relevant identifiers and status fields.
3. Call `auditLogger.send(...)` with success status/event.

### FAIL event
1. Catch business exception only where needed for meaningful FAIL audit.
2. Build compact FAIL payload with known identifiers and error summary.
3. Call `auditLogger.send(...)` with status `FAIL`.
4. Rethrow original exception.

## Review Checklist

Before finishing audit log code, verify:
- Is action human and compliance-relevant?
- Is `objectId` correct for audit UI lookup in this domain?
- Is payload compact and useful?
- Are raw DTO/request/response/entity objects avoided?
- Is unnecessary PII excluded?
- Does business failure publish a `FAIL` event when appropriate?
- Is original exception still rethrown?
- Is there no redundant transport-level try/catch around `AuditLogger`?
- Is audit logic centralized enough to stay maintainable across repo growth?
