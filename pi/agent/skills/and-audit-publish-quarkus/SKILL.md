---
name: and-audit-publish-quarkus
description: Guidance for publishing audit log events in AND Quarkus services. Covers code, CI/CD, and env config. Use when adding, reviewing, or refactoring compliance audit logging.
---

# AND Audit Log Publish

Use this skill when implementing or reviewing audit logging in AND Quarkus projects. It covers:

- adding audit log publishing to a **new** service
- **modernizing** an existing service that uses a different audit pattern
- **CI/CD and environment configuration** for each deployment target
- **verifying** that code, CI, and runtime config are correct

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

---

## Adding Audit Log to a New Service

### 1. Ensure parent POM is up to date

```xml
<parent>
  <groupId>mn.and</groupId>
  <artifactId>quarkus-parent</artifactId>
  <version>1.4.3</version>
  <relativePath/>
</parent>
```

The parent provides:

- `quarkus-common` as a managed dependency (brings `AuditPublisher`, `AuditLogger`, etc.)
- Maven profiles (`audit-backend-amqp`, `audit-backend-kafka`, `audit-backend-sqs`) that wire the correct broker library

No manual `quarkus-common` dependency declaration is needed if you use the parent's bill of materials — but most services add it explicitly:

```xml
<dependency>
  <groupId>mn.and</groupId>
  <artifactId>quarkus-common</artifactId>
</dependency>
```

### 2. Create a domain audit facade

Create one **domain audit service** per microservice that centralises all audit logic:

```java
@ApplicationScoped
@RequiredArgsConstructor
public class CaseAuditService {

  private final AuditPublisher auditPublisher;

  public void created(String caseId, String org, String user) {
    publish(caseId, "CASE_CREATED", AuditStatus.CREATED, "Case created");
  }

  public void statusChanged(String caseId, String oldStatus, String newStatus, String org, String user) {
    var payload = AuditPayload.builder()
        .add("caseId", caseId)
        .add("previousStatus", oldStatus)
        .add("newStatus", newStatus)
        .build();
    auditPublisher.publish("cases", caseId, payload, AuditStatus.UPDATED,
        "CASE_STATUS_CHANGED", "Status changed from " + oldStatus + " to " + newStatus,
        org, user);
  }

  public void failed(String caseId, String errorType, String errorMessage, String org, String user) {
    var payload = AuditPayload.builder()
        .add("caseId", caseId)
        .add("errorType", errorType)
        .add("errorMessage", errorMessage)
        .build();
    auditPublisher.publish("cases", caseId, payload, AuditStatus.FAIL,
        "CASE_OPERATION_FAILED", errorMessage, org, user);
  }
}
```

### 3. Publish from business logic

Inject the facade and call it at the appropriate point:

```java
@ApplicationScoped
@RequiredArgsConstructor
public class CaseService {

  private final CaseRepository repository;
  private final CaseAuditService auditService;
  private final ApiHeaders apiHeaders;

  public CaseDto updateStatus(UUID caseId, String newStatus) {
    var existing = repository.findById(caseId);
    var oldStatus = existing.getStatus();

    try {
      existing.setStatus(newStatus);
      repository.persist(existing);

      auditService.statusChanged(
          caseId.toString(), oldStatus, newStatus,
          apiHeaders.getOrgUuid(), apiHeaders.getEffectiveUserUuid());

      return mapToDto(existing);
    } catch (Exception e) {
      auditService.failed(
          caseId.toString(), e.getClass().getSimpleName(), e.getMessage(),
          apiHeaders.getOrgUuid(), apiHeaders.getEffectiveUserUuid());
      throw e;
    }
  }
}
```

### 4. Configure CI/CD (see DevOps section below)

---

## Modernizing an Existing Service

If a service already has audit logging but uses an old or non-standard pattern, follow this migration.

### Signs you need modernisation

- service declares `com.azure:azure-messaging-servicebus` directly in its POM
- service imports `com.azure.messaging.servicebus.*` or uses `ServiceBusSenderClient`
- service has `AUDIT_LOG_AZURE_CONNECTION_STRING` or other `AUDIT_LOG_AZURE_*` env vars
- service calls `auditLogger.send(...)` directly instead of `AuditPublisher`
- service has raw `KafkaProducer` or manual connection management for audit
- service catches exceptions around audit publish calls
- service has `@IfBuildProperty(name = "mn.and.audit.backend", stringValue = "rabbitmq")` or `"azure"`

### Migration steps

#### POM changes

Remove the old broker dependency:

```xml
<!-- REMOVE this -->
<dependency>
  <groupId>com.azure</groupId>
  <artifactId>azure-messaging-servicebus</artifactId>
</dependency>
```

Ensure `quarkus-common` and parent version are current:

```xml
<parent>
  <groupId>mn.and</groupId>
  <artifactId>quarkus-parent</artifactId>
  <version>1.4.3</version>
</parent>
```

No new dependency to add — the `audit-backend-amqp` Maven profile pulls `quarkus-messaging-amqp` at build time.

#### Code changes

Replace direct `AuditLogger` usage with `AuditPublisher` where possible. If the old code does this:

```java
@Inject AuditLogger auditLogger;

auditLogger.send(feature, objectId, payload, status, event, description, org, user);
```

Replace with:

```java
@Inject AuditPublisher auditPublisher;

auditPublisher.publish(feature, objectId, payload, status, event, description);
```

Note: `AuditPublisher` automatically resolves organization and user from `ApiHeaders`, so you don't pass them explicitly.

#### Env var changes

Rename old Azure-specific env vars to the unified AMQP vars:

| Old (remove)                        | New (use)                                                                                                                                              |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `AUDIT_LOG_AZURE_CONNECTION_STRING` | `AUDIT_LOG_AMQP_HOST`, `AUDIT_LOG_AMQP_USERNAME`, `AUDIT_LOG_AMQP_PASSWORD`, `AUDIT_LOG_AMQP_PORT`, `AUDIT_LOG_AMQP_USE_SSL`, `AUDIT_LOG_AMQP_ADDRESS` |
| `AUDIT_LOG_AZURE_ENTITY_TYPE`       | removed (no equivalent needed)                                                                                                                         |
| `AUDIT_LOG_AZURE_QUEUE_NAME`        | `AUDIT_LOG_AMQP_ADDRESS`                                                                                                                               |
| `AUDIT_LOG_AZURE_TOPIC_NAME`        | `AUDIT_LOG_AMQP_ADDRESS`                                                                                                                               |
| `AUDIT_LOG_RABBITMQ_*`              | `AUDIT_LOG_AMQP_*`                                                                                                                                     |
| `MP_MESSAGING_OUTGOING_AUDIT_*`     | `AUDIT_LOG_AMQP_*`                                                                                                                                     |

If the old code referenced `azure-messaging-servicebus` import or `ServiceBusSenderClient`, remove those entirely.

---

## DevOps / CI/CD Configuration

### Build pipeline (`.gitlab-ci.yml`)

The `AUDIT_LOG_BACKEND` must be forwarded to the Docker build stage so the correct `AuditLogger` bean is compiled in.

**build stage** — pass the backend value as a build arg:

```yaml
variables:
  AUDIT_LOG_BACKEND: "amqp" # or "log" / "kafka" / "sqs"
  AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS: >
    --build-arg AUDIT_LOG_BACKEND=${AUDIT_LOG_BACKEND}
```

**Dockerfile** — receive the arg and pass it to Maven:

```dockerfile
ARG BUILD_AUDIT_LOG_BACKEND=log

RUN ./mvnw package -DAUDIT_LOG_BACKEND=${BUILD_AUDIT_LOG_BACKEND} ...
```

**deploy jobs** — may set `BUILD_AUDIT_LOG_BACKEND` if the template rebuilds, otherwise ensure the target image was built with the right backend.

Example per-environment overrides:

```yaml
# SIT build — use AMQP (RabbitMQ)
build-sit:
  extends: build
  variables:
    AUDIT_LOG_BACKEND: "amqp"

# Dev deploy — use AMQP (Azure Service Bus)
alpha-dev:
  extends: ".dev_deploy"
  variables:
    BUILD_AUDIT_LOG_BACKEND: "amqp"
```

### Environment helm values (`.gitlab/alpha-*.yaml`)

Each environment needs its own runtime config. The env var names are **unified** — same keys regardless of whether the broker is RabbitMQ or Azure Service Bus.

```yaml
# .gitlab/alpha-dev.yaml  (Azure Service Bus)
application:
  env:
    - name: AUDIT_LOG_SOURCE
      value: "my-service"
    - name: AUDIT_LOG_BACKEND
      value: "amqp"
    - name: AUDIT_LOG_AMQP_HOST
      value: "sb-my-namespace.servicebus.windows.net"
    - name: AUDIT_LOG_AMQP_PORT
      value: "5671"
    - name: AUDIT_LOG_AMQP_USE_SSL
      value: "true"
    - name: AUDIT_LOG_AMQP_USERNAME
      value: "app_log_mgmt"
    - name: AUDIT_LOG_AMQP_PASSWORD
      value: "$AUDIT_LOG_AMQP_PASSWORD"          # from CI/CD secret
    - name: AUDIT_LOG_AMQP_ADDRESS
      value: "audit-queue"

# .gitlab/alpha-ptf-sit.yaml  (RabbitMQ — note different port, no SSL, exchange/routing-keys)
application:
  env:
    - name: AUDIT_LOG_SOURCE
      value: "my-service"
    - name: AUDIT_LOG_BACKEND
      value: "amqp"
    - name: AUDIT_LOG_AMQP_HOST
      value: "rabbitmq.rabbitmq.svc.cluster.local"
    - name: AUDIT_LOG_AMQP_PORT
      value: "5672"
    - name: AUDIT_LOG_AMQP_USERNAME
      value: "app_notification_service"
    - name: AUDIT_LOG_AMQP_PASSWORD
      value: "$AUDIT_LOG_AMQP_PASSWORD"          # from CI/CD secret
    - name: AUDIT_LOG_AMQP_EXCHANGE
      value: "audit-log-exchange"
    - name: AUDIT_LOG_AMQP_ROUTING_KEYS
      value: "alpha-audit-log"
```

Key differences between RabbitMQ and Azure Service Bus config:

| Property                      | RabbitMQ                  | Azure Service Bus                    |
| ----------------------------- | ------------------------- | ------------------------------------ |
| `AUDIT_LOG_AMQP_HOST`         | cluster-internal DNS      | `<namespace>.servicebus.windows.net` |
| `AUDIT_LOG_AMQP_PORT`         | `5672`                    | `5671`                               |
| `AUDIT_LOG_AMQP_USE_SSL`      | `false` (omit)            | `true`                               |
| `AUDIT_LOG_AMQP_ADDRESS`      | not needed                | queue or topic name                  |
| `AUDIT_LOG_AMQP_EXCHANGE`     | e.g. `audit-log-exchange` | not needed                           |
| `AUDIT_LOG_AMQP_ROUTING_KEYS` | e.g. `alpha-audit-log`    | not needed                           |

For `log` or SIT environments where audit is not forwarded to a broker, just set:

```yaml
- name: AUDIT_LOG_BACKEND
  value: "log"
```

No AMQP env vars needed.

### CI/CD secrets

The platform team must add these CI/CD variables for any environment that uses `amqp` backend:

| Variable                  | Example value                  |
| ------------------------- | ------------------------------ |
| `AUDIT_LOG_AMQP_PASSWORD` | the broker password or SAS key |

### Kubernetes secrets

If the password is stored in a K8s secret instead of CI/CD variables, reference it in the helm values:

```yaml
- name: AUDIT_LOG_AMQP_PASSWORD
  valueFrom:
    secretKeyRef:
      name: my-service-secret
      key: amqp-audit-password
```

---

## Verification Checklist

Use this checklist when reviewing audit log PRs or debugging why events aren't reaching the broker.

### Code review

- [ ] Does the service use `AuditPublisher` rather than raw `AuditLogger`?
- [ ] Is there one centralised domain audit facade (e.g. `CaseAuditService`) instead of scattered `send()` calls?
- [ ] Are event/action names in constants or enums, not inline strings?
- [ ] Is `objectId` a stable business lookup id (applicationId, requestId, etc.)?
- [ ] Is payload compact? No raw DTO/response/entity objects, no PII, no large blobs?
- [ ] Do business failures publish a `FAIL` event?
- [ ] Is the original exception still rethrown after FAIL audit?
- [ ] Are there no redundant try/catch blocks around audit publish calls?
- [ ] Is there no audit-on-audit loop (e.g. sending audit about audit transport failure)?
- [ ] Is `ApiHeaders.getEffectiveUserUuid()` used for `createdBy`?

### CI/CD review

- [ ] Does the parent POM version resolve to `1.4.3` or later?
- [ ] Does the service POM have the legacy `azure-messaging-servicebus` dependency removed?
- [ ] Does the Docker build stage pass `AUDIT_LOG_BACKEND` as a build arg?
- [ ] Does the Dockerfile forward `-DAUDIT_LOG_BACKEND=${BUILD_AUDIT_LOG_BACKEND}` to Maven?
- [ ] Does `.gitlab-ci.yml` set the correct `AUDIT_LOG_BACKEND` / `BUILD_AUDIT_LOG_BACKEND` for each environment?
- [ ] Are all `AUDIT_LOG_AZURE_*`, `AUDIT_LOG_RABBITMQ_*`, and `MP_MESSAGING_OUTGOING_AUDIT_*` env vars removed from helm values?
- [ ] Are the unified `AUDIT_LOG_AMQP_*` env vars present in each environment that uses `amqp`?
- [ ] Is `AUDIT_LOG_AMQP_HOST` pointing to the correct endpoint?
- [ ] For Azure Service Bus: is port 5671, SSL true, and `AUDIT_LOG_AMQP_ADDRESS` set to the queue/topic name?
- [ ] For RabbitMQ: is `AUDIT_LOG_AMQP_EXCHANGE` and `AUDIT_LOG_AMQP_ROUTING_KEYS` set (or using defaults)?
- [ ] Is the `AUDIT_LOG_AMQP_PASSWORD` referenced from a CI/CD secret or K8s secret (not hardcoded)?

### Runtime debugging

If audit events are not reaching the broker:

1. Check the pod logs for `AuditLogger` init messages:
   - `"AMQP-based audit logger..."` — correct bean is active
   - `"Default audit logger initialized (logs only)"` — wrong bean, build-time `AUDIT_LOG_BACKEND` was not `amqp`
2. Check for `"Failed to send audit event via AMQP"` errors
3. Verify environment variables are actually set in the pod: `kubectl exec <pod> -- env | grep AUDIT_LOG`
4. If connecting to Azure Service Bus, verify the `AUDIT_LOG_AMQP_PASSWORD` SAS key is correct (it rotates periodically)
5. If using RabbitMQ, verify the exchange exists: `rabbitmqadmin -u <user> -p <pass> list exchanges`

---

## Platform Standard

Target platform pattern for AND microservices:

- use `mn.and.common.logging.audit.AuditPublisher` for request-driven business audit publishing
- use `mn.and.common.logging.audit.AuditPayload` to build compact payloads
- use `mn.and.common.logging.audit.AuditStatus` for standard statuses
- keep `mn.and.common.logging.audit.AuditLogger` as lower-level transport API
- align service with `mn.and:quarkus-common:1.4.3` (minimum)
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

The AMQP audit logger handles both **RabbitMQ** and **Azure Service Bus** via the SmallRye Reactive Messaging AMQP connector (`quarkus-messaging-amqp`).

### Backend selection

Set `AUDIT_LOG_BACKEND` (build-time system property and runtime env var):

| Value   | Transport                                  |
| ------- | ------------------------------------------ |
| `log`   | application logger only (default)          |
| `amqp`  | RabbitMQ or Azure Service Bus via AMQP 1.0 |
| `kafka` | Apache Kafka                               |
| `sqs`   | Amazon SQS                                 |

### Maven profile

The `quarkus-parent` POM provides profiles that wire the correct dependency:

```bash
./mvnw package -DAUDIT_LOG_BACKEND=amqp
```

This activates the `audit-backend-amqp` profile, pulling `quarkus-messaging-amqp`. No manual dependency declaration needed in the service POM.

### Build-time rule

- `mn.and.audit.backend` is checked at **build time** by `@IfBuildProperty` to decide which `AuditLogger` bean is compiled in
- if `AUDIT_LOG_BACKEND=amqp` is not passed during Docker/Maven build, only `DefaultAuditLogger` is available and AMQP transport won't work
- always forward `AUDIT_LOG_BACKEND` to the **Docker build stage** / Maven package stage, not only at runtime

### Runtime config (`AUDIT_LOG_AMQP_*` env vars)

Both RabbitMQ and Azure Service Bus use the same env vars — just different values:

```yaml
- name: AUDIT_LOG_SOURCE
  value: "my-service"
- name: AUDIT_LOG_BACKEND
  value: "amqp"
- name: AUDIT_LOG_AMQP_HOST
  value: "<hostname>"
- name: AUDIT_LOG_AMQP_PORT
  value: "5672" # 5671 for Azure SB with SSL
- name: AUDIT_LOG_AMQP_USE_SSL
  value: "false" # true for Azure SB
- name: AUDIT_LOG_AMQP_USERNAME
  value: "<username>"
- name: AUDIT_LOG_AMQP_PASSWORD
  value: "$AUDIT_LOG_AMQP_PASSWORD"
- name: AUDIT_LOG_AMQP_ADDRESS
  value: "<queue-or-topic-name>" # Azure SB only; not needed for RabbitMQ
- name: AUDIT_LOG_AMQP_EXCHANGE
  value: "audit-log-exchange" # RabbitMQ only
- name: AUDIT_LOG_AMQP_ROUTING_KEYS
  value: "alpha-audit-log" # RabbitMQ only
```

Relevant common implementation:

- `mn.and.common.logging.audit.AuditPublisher`
- `mn.and.common.logging.audit.AuditPayload`
- `mn.and.common.logging.audit.AuditStatus`
- `mn.and.common.logging.audit.AuditLogger`
- `mn.and.common.logging.audit.AmqpAuditLogger`
- `mn.and.common.logging.audit.DefaultAuditLogger`
- `mn.and.common.logging.audit.SqsAuditLogger`

Meaning:

- request-driven business code should usually call `AuditPublisher`
- service code should **not** implement broker details directly
- service code should **not** add extra transport-level try/catch around audit publishing only to protect broker publishing
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
  - prefer `ApiHeaders.getEffectiveUserUuid()`
  - this uses actor user id when available
  - otherwise falls back to authenticated/request user id

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

- Inject `AuditPublisher` into audit facade/service by default.
- Use `AuditLogger` directly only for lower-level or non-request use cases.
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
2. Build compact payload from relevant identifiers and status fields using `AuditPayload`.
3. Call `AuditPublisher` with standard `AuditStatus`.

### FAIL event

1. Catch business exception only where needed for meaningful FAIL audit.
2. Build compact FAIL payload with known identifiers and error summary using `AuditPayload`.
3. Call `AuditPublisher` with status `FAIL`.
4. Rethrow original exception.

## Review Checklist

Before finishing audit log code, verify:

- [ ] Is action human and compliance-relevant?
- [ ] Is `objectId` correct for audit UI lookup in this domain?
- [ ] Is payload compact and useful?
- [ ] Are raw DTO/request/response/entity objects avoided?
- [ ] Is unnecessary PII excluded?
- [ ] Does business failure publish a `FAIL` event when appropriate?
- [ ] Is original exception still rethrown?
- [ ] Is there no redundant transport-level try/catch around `AuditLogger`?
- [ ] Is audit logic centralized enough to stay maintainable across repo growth?
