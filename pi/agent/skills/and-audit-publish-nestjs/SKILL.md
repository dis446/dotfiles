---
name: and-audit-publish-nestjs
description: Guidance for publishing audit log events in AND NestJS services. Use when adding, reviewing, or refactoring compliance audit logging, especially for human actions, FAIL audit events, payload design, and AuditPublisher usage.
---

# AND Audit Log Publish for NestJS

Use this skill when implementing or reviewing audit logging in AND NestJS services.

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

`@and/nest-common` library version must be **at least 1.3.4**.

Target platform pattern for NestJS microservices:

- use `@and/nest-common` `AuditPublisher` for request-driven business audit publishing
- use `@and/nest-common` `AuditPayload` to build compact payloads
- use `@and/nest-common` `AuditStatus` for standard statuses
- keep `@and/nest-common` `AuditLogger` as lower-level transport API
- use one **domain audit facade/service** per microservice, for example:
  - `ContractAuditService`
  - `DocumentAuditService`
  - `RuleEngineAuditService`
- centralize:
  - audit event names (use `as const` objects for type safety)
  - audit feature/entity names (use `as const` objects for type safety)
  - statuses
  - payload builders
  - FAIL-event publishing helpers
  - typed payload shape interfaces

Do **not** scatter raw `auditLogger.send(...)` calls everywhere once repo grows.

## Environment and Backend

For SRE parity with Quarkus services, Nest audit config should support the same env names and backend style:

- `AUDIT_LOG_SOURCE`
- `AUDIT_LOG_BACKEND`
- `AUDIT_LOG_AZURE_CONNECTION_STRING`
- direct `MN_AND_AUDIT_*` env names when service already uses them

Do **not** add repo-specific Azure fallback env names unless the shared config layer explicitly requires them.

### Helm values validation

Every NestJS service that publishes audit logs must have correct `AUDIT_LOG_*` env variables in its helm values files. The canonical config location is:

```
.gitlab/**/*values*.yaml
.gitlab/**/*values*.yml
```

Minimum required env vars across all environments:

```yaml
env:
  AUDIT_LOG_BACKEND: "azure"          # or "log" for local/dev
  AUDIT_LOG_SOURCE: "service-name"    # stable logical source name
  AUDIT_LOG_AZURE_CONNECTION_STRING:  # connection string (secret ref in non-dev)
```

Validation checks to perform when reviewing a NestJS audit PR:

1. Find all `values*.yaml` / `values*.yml` files under `.gitlab/`.
2. For each file, verify `AUDIT_LOG_BACKEND` and `AUDIT_LOG_SOURCE` are present under `env:`.
3. Confirm `AUDIT_LOG_SOURCE` value is a stable, human-readable name (e.g. `"rule-engine"`, `"contract-service"`), not a technical queue/topic name.
4. Confirm `AUDIT_LOG_AZURE_CONNECTION_STRING` is present for non-local environments (staging, prod, etc.) -- usually as a `${{ secrets.AZURE_SOMETHING }}` reference, not a raw string.
5. Flag any repo-specific `AUDIT_LOG_*` env names that should be standardized (e.g. `RULE_ENGINE_AUDIT_LOG_*` or `MN_AND_AUDIT_SB_CONNECTION_STRING` should be replaced with standard `AUDIT_LOG_*` equivalents).
6. Ensure the values are wired through to the NestJS `ConfigModule` / `@nestjs/config` so the `@and/nest-common` audit logger picks them up at runtime.

Do **not** approve PRs that add raw connection strings directly in values files -- always use secret references.

Backend selection should stay framework-neutral:

- `log` -- local logger backend
- `azure` -- Azure Service Bus
- `kafka` -- Kafka

Relevant common implementation:

- `@and/nest-common` `AuditPublisher`
- `@and/nest-common` `AuditPayload`
- `@and/nest-common` `AuditStatus`
- `@and/nest-common` `AuditLogger`
- `@and/nest-common` `DefaultAuditLogger`
- `@and/nest-common` `AzureServiceBusAuditLogger`
- `@and/nest-common` `KafkaAuditLogger`

Meaning:

- request-driven business code should usually call `AuditPublisher`
- service code should **not** implement Azure Service Bus or Kafka details directly
- service code should **not** add extra transport-level try/catch around audit publishing only to protect broker publishing
- transport/logger implementation already handles serialization/send failures internally
- do not hardcode audit source, queue/topic names, or connection strings in the service repo; wire them from env/config only

## Architecture: Audit Module + Token-Based Injection

Create a **dedicated audit module** per microservice with three files:

```
src/audit/
  <domain>-audit.module.ts     # Nest module, imports CommonModule, exports token
  <domain>-audit.service.ts    # Audit facade with explicit methods per event
  <domain>-audit.tokens.ts     # Symbol token for DI
```

### Audit Module

```typescript
// <domain>-audit.module.ts
import { Module } from '@nestjs/common';
import { CommonModule } from '@and/nest-common';
import { DomainAuditService } from './domain-audit.service';
import { DOMAIN_AUDIT_SERVICE } from './domain-audit.tokens';

@Module({
  imports: [CommonModule],
  providers: [
    DomainAuditService,
    {
      provide: DOMAIN_AUDIT_SERVICE,
      useExisting: DomainAuditService,
    },
  ],
  exports: [DOMAIN_AUDIT_SERVICE],
})
export class DomainAuditModule {}
```

### Token File

```typescript
// <domain>-audit.tokens.ts
export const DOMAIN_AUDIT_SERVICE = Symbol('DOMAIN_AUDIT_SERVICE');
```

### Consumption in Feature Modules

Each feature module that needs audit imports the audit module:

```typescript
import { Module } from '@nestjs/common';
import { CommonModule } from '@and/nest-common';
import { DomainAuditModule } from '@/audit/domain-audit.module';
// ... other imports

@Module({
  imports: [CommonModule, DomainAuditModule],
  controllers: [FeatureController],
  providers: [FeatureService],
})
export class FeatureModule {}
```

Consuming services inject via the token:

```typescript
import { Inject } from '@nestjs/common';
import { DOMAIN_AUDIT_SERVICE } from '@/audit/domain-audit.tokens';
import type { DomainAuditService } from '@/audit/domain-audit.service';

export class FeatureService {
  constructor(
    @Inject(DOMAIN_AUDIT_SERVICE)
    private readonly auditService: DomainAuditService,
  ) {}
}
```

## Core Rules

1. Publish audit for **business-significant human actions**.
2. Use stable **business lookup id** as `objectId`.
   - Use whichever id audit UI and operations users naturally search by.
   - Often this is `applicationId` or `requestId`.
   - Sometimes it is entity UUID if that is primary lookup key.
   - Do **not** assume one universal id across all repos.
   - Fall back to `'unknown'` when id is missing or empty.
3. Keep payload **compact**.
4. Avoid unnecessary PII, large blobs, and internal infrastructure details.
5. Publish `FAIL` audit event when business action itself fails in meaningful way.
6. Do not create audit-on-audit loops for transport failures.
7. Never pass raw request/response/entity objects to audit logger unless payload is already known-safe and small.

## What to Publish

Each audit event should usually include:

- feature/entity type
- object id (with `'unknown'` fallback if missing)
- compact object data (only relevant identifiers and statuses)
- status
- event/action name
- description
- organization
- createdBy
  - prefer `getIdentity()` from `@and/nest-common`
  - this uses actor user id when available
  - otherwise falls back to authenticated/request user id
  - `getIdentity()` is already called inside `AuditPublisher`, no need to pass manually

### Preferred compact payload fields

- `id` or `entityId` -- the primary object id
- `entityName` -- human-readable name
- `status` -- current status (use string name, not numeric enum value)
- `previousStatus` -- status before the transition
- `newStatus` -- status after the transition
- `version` -- when versioning applies
- `rejectionCode` -- only when relevant
- `resultCount` or `itemCount` -- when count itself matters
- `errorType` -- for FAIL events
- `errorMessage` -- for FAIL events

### Avoid by default

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

- `entityId=...`
- `status=...` if known
- `errorType=...`
- `errorMessage=...`

Extract error info from exception:

```typescript
private errorPayload(error: unknown): Record<string, string | undefined> {
  if (error instanceof Error) {
    return {
      errorType: error.name,
      errorMessage: error.message,
    };
  }
  return {
    errorType: typeof error,
    errorMessage: typeof error === 'string' ? error : JSON.stringify(error),
  };
}
```

Important:

- FAIL event is about **business action failure**
- not about audit transport failure itself

## Canonical Audit Service Pattern

### Structure

A well-structured audit service should have:

1. **Feature constants** -- `as const` object mapping feature names to strings
2. **Event constants** -- `as const` object listing every event name with `_FAILED` suffix for failure variants
3. **Typed payload shape interfaces** -- explicit types for each entity's audit shape
4. **An explicit method per event** -- `entityCreated()`, `entityUpdated()`, `entityDeleted()`, `entityCreateFailed()`, etc.
5. **Private payload builder methods** -- one per entity type for consistent payloads
6. **Private helper methods** -- `errorPayload()`, `count()`, `statusName()` for cross-cutting concerns
7. **Public methods delegate to private `publishSuccess`/`publishFail`** -- reduce duplication

### Complete Example Pattern

```typescript
import { Injectable } from '@nestjs/common';
import { AuditPayload, AuditPublisher, AuditStatus } from '@and/nest-common';

const FEATURES = {
  ENTITY: 'entity_name',
  OTHER_ENTITY: 'other_entity',
} as const;

const EVENTS = {
  ENTITY_CREATED: 'ENTITY_CREATED',
  ENTITY_UPDATED: 'ENTITY_UPDATED',
  ENTITY_DELETED: 'ENTITY_DELETED',
  ENTITY_PUBLISHED: 'ENTITY_PUBLISHED',
  ENTITY_CREATE_FAILED: 'ENTITY_CREATE_FAILED',
  ENTITY_UPDATE_FAILED: 'ENTITY_UPDATE_FAILED',
  ENTITY_DELETE_FAILED: 'ENTITY_DELETE_FAILED',
  ENTITY_PUBLISH_FAILED: 'ENTITY_PUBLISH_FAILED',
} as const;

// Typed shape for safe payload building
type EntityAuditShape = {
  id?: string;
  name?: string | null;
  status?: string | number | null;
  items?: unknown;
};

@Injectable()
export class DomainAuditService {
  constructor(private readonly auditPublisher: AuditPublisher) {}

  entityCreated(entity: EntityAuditShape) {
    return this.publishSuccess(
      FEATURES.ENTITY,
      entity.id,
      this.entityPayload(entity),
      EVENTS.ENTITY_CREATED,
      `${FEATURES.ENTITY} created: ${entity.name ?? entity.id ?? 'unknown'}`,
    );
  }

  entityUpdated(entity: EntityAuditShape, previousStatus?: string | number | null) {
    return this.publishSuccess(
      FEATURES.ENTITY,
      entity.id,
      {
        ...this.entityPayload(entity),
        previousStatus: this.statusName(previousStatus),
      },
      EVENTS.ENTITY_UPDATED,
      `${FEATURES.ENTITY} updated: ${entity.id ?? entity.name ?? 'unknown'}`,
    );
  }

  entityDeleted(entity: EntityAuditShape) {
    return this.publishSuccess(
      FEATURES.ENTITY,
      entity.id,
      this.entityPayload(entity),
      EVENTS.ENTITY_DELETED,
      `${FEATURES.ENTITY} deleted: ${entity.id ?? entity.name ?? 'unknown'}`,
    );
  }

  entityPublished(entity: EntityAuditShape, version: number, notes?: string | null, previousStatus?: string | number | null) {
    return this.publishSuccess(
      FEATURES.ENTITY,
      entity.id,
      {
        ...this.entityPayload(entity),
        previousStatus: this.statusName(previousStatus),
        newStatus: this.statusName('PUBLISHED'),
        version,
        notes,
      },
      EVENTS.ENTITY_PUBLISHED,
      `${FEATURES.ENTITY} published: ${entity.id ?? entity.name ?? 'unknown'} version ${version}`,
    );
  }

  entityCreateFailed(dto: EntityAuditShape, error: unknown) {
    return this.publishFail(
      FEATURES.ENTITY,
      dto.name ?? 'unknown',
      {
        entityName: dto.name,
        ...this.errorPayload(error),
      },
      EVENTS.ENTITY_CREATE_FAILED,
      `Failed to create ${FEATURES.ENTITY}: ${dto.name ?? 'unknown'}`,
    );
  }

  entityUpdateFailed(entityId: string, dto: EntityAuditShape, error: unknown) {
    return this.publishFail(
      FEATURES.ENTITY,
      entityId,
      {
        entityId,
        entityName: dto.name,
        ...this.errorPayload(error),
      },
      EVENTS.ENTITY_UPDATE_FAILED,
      `Failed to update ${FEATURES.ENTITY}: ${entityId}`,
    );
  }

  entityDeleteFailed(entityId: string, error: unknown) {
    return this.publishFail(
      FEATURES.ENTITY,
      entityId,
      {
        entityId,
        ...this.errorPayload(error),
      },
      EVENTS.ENTITY_DELETE_FAILED,
      `Failed to delete ${FEATURES.ENTITY}: ${entityId}`,
    );
  }

  entityPublishFailed(entityId: string, previousStatus: string | number | null, error: unknown) {
    return this.publishFail(
      FEATURES.ENTITY,
      entityId,
      {
        entityId,
        previousStatus: this.statusName(previousStatus),
        ...this.errorPayload(error),
      },
      EVENTS.ENTITY_PUBLISH_FAILED,
      `Failed to publish ${FEATURES.ENTITY}: ${entityId}`,
    );
  }

  // --- Private helpers ---

  private entityPayload(entity: EntityAuditShape): Record<string, string | number | boolean | undefined> {
    return {
      entityId: entity.id,
      entityName: entity.name,
      status: this.statusName(entity.status),
      itemCount: this.count(entity.items),
    };
  }

  private errorPayload(error: unknown): Record<string, string | undefined> {
    if (error instanceof Error) {
      return {
        errorType: error.name,
        errorMessage: error.message,
      };
    }
    return {
      errorType: typeof error,
      errorMessage: typeof error === 'string' ? error : JSON.stringify(error),
    };
  }

  private publishSuccess(
    feature: string,
    objectId: string | undefined,
    objectData: Record<string, string | number | boolean | undefined>,
    event: string,
    description: string,
  ) {
    return this.auditPublisher.publish(
      feature,
      this.safeId(objectId),
      this.buildPayload(objectData),
      AuditStatus.SUCCESS,
      event,
      description,
    );
  }

  private publishFail(
    feature: string,
    objectId: string | undefined,
    objectData: Record<string, string | number | boolean | undefined>,
    event: string,
    description: string,
  ) {
    return this.auditPublisher.publish(
      feature,
      this.safeId(objectId),
      this.buildPayload(objectData),
      AuditStatus.FAIL,
      event,
      description,
    );
  }

  private buildPayload(objectData: Record<string, string | number | boolean | undefined>) {
    const builder = AuditPayload.builder();

    for (const [key, value] of Object.entries(objectData ?? {})) {
      const normalized = this.normalizeValue(value);

      if (normalized === undefined || normalized === null || normalized === '') {
        continue;
      }

      builder.add(key, normalized);
    }

    return builder.build();
  }

  private normalizeValue(value: unknown): unknown {
    if (value instanceof Date) {
      return value.toISOString();
    }
    return value;
  }

  private safeId(value: string | undefined): string {
    return value && value.trim().length > 0 ? value : 'unknown';
  }

  private count(items: unknown): number | undefined {
    return Array.isArray(items) ? items.length : undefined;
  }

  private statusName(status: string | number | null | undefined): string | undefined {
    if (status === null || status === undefined || status === '') {
      return undefined;
    }
    return typeof status === 'number' ? this.enumName(status) : status;
  }

  private enumName(value: number): string | undefined {
    // Override in subclasses or pass a status-name map
    return String(value);
  }
}
```

## Canonical try/catch Pattern in Services

Every business service method that performs audit-worthy operations should follow this exact pattern:

```typescript
async businessMethod(param: string): Promise<Result> {
  try {
    // 1. Perform business operation (DB writes, validations, etc.)
    const result = await this.db.insert(...).returning();

    // 2. Publish success audit event (inside try block, after successful operation)
    await this.auditService.entityCreated(result);

    return result;
  } catch (error) {
    // 3. Publish FAIL audit event (inside catch block, before rethrow)
    await this.auditService.entityCreateFailed({ name: param }, error);

    // 4. Always rethrow the original exception
    throw error;
  }
}
```

Key rules:

- Success audit is published **inside the try block** after the business operation completes.
- FAIL audit is published **inside the catch block** before rethrowing.
- The original exception is **always rethrown** so the HTTP layer can respond appropriately.
- Do **not** wrap the FAIL publish call in its own try/catch -- if audit transport fails, the service should not silently swallow that either.
- When the business operation involves DB transactions, call the success audit **inside the transaction** but after the commit-able operations. The FAIL audit should be outside the transaction scope or in a top-level catch that handles both transaction and non-transaction errors.

### Transaction-aware try/catch pattern

When using DB transactions, structure the try/catch at the service method level, not inside the transaction callback:

```typescript
async businessMethod(dto: Dto): Promise<Result> {
  let previousStatus: Status | null = null;

  try {
    return await this.db.transaction(async (tx) => {
      const existing = await tx.select(...);
      previousStatus = existing.status;

      // ... perform DB operations ...

      const result = await tx.insert(...).returning();

      // Publish success audit inside the transaction (safe since transaction will commit)
      await this.auditService.entityCreated(result);

      return result;
    });
  } catch (error) {
    // Publish FAIL audit outside the transaction (transaction already rolled back)
    await this.auditService.entityCreateFailed({ /* ... */ }, previousStatus, error);
    throw error;
  }
}
```

## Recommended Project Layout

```
src/
  audit/
    <domain>-audit.module.ts     # Module with token export
    <domain>-audit.service.ts    # Audit facade
    <domain>-audit.tokens.ts     # DI token symbol
  feature-a/
    feature-a.module.ts          # Imports DomainAuditModule
    feature-a.service.ts         # Inject via DOMAIN_AUDIT_SERVICE token
    feature-a.controller.ts
  feature-b/
    feature-b.module.ts          # Imports DomainAuditModule
    feature-b.service.ts         # Inject via DOMAIN_AUDIT_SERVICE token
    feature-b.controller.ts
```

## Implementation Guidance

- Inject `AuditPublisher` into the audit facade/service by default.
- Use `AuditLogger` directly only for lower-level or non-request use cases.
- Avoid publishing directly from controller layer unless repo is very small or there is no better abstraction.
- Keep event/action names in `as const` objects for type safety.
- Keep feature/entity names in `as const` objects for type safety.
- Define typed payload shape interfaces for each entity type.
- Centralize payload builders near audit facade.
- Build explicit safe payload strings/maps.
- Use `AuditPayload.builder()` with null/undefined/empty filtering for compact payloads.
- Prefer small helper methods (`safeId`, `count`, `statusName`, `errorPayload`, `normalizeValue`) over hidden magic.
- If using request/response failure context, ensure stored payload is already sanitized and compact.
- If repo uses local audit DB or custom wrapper, treat that as repo-specific pattern unless it aligns with platform standard.

## Procedure

### Success event

1. Perform business operation.
2. Build compact payload from relevant identifiers and status fields using typed payload shape + `AuditPayload.builder()`.
3. Call audit facade method with standard `AuditStatus`.

### FAIL event

1. Catch business exception only where needed for meaningful FAIL audit.
2. Build compact FAIL payload with known identifiers and error summary using `errorPayload()` helper.
3. Call audit facade method with status `FAIL`.
4. Rethrow original exception.

## Review Checklist

Before finishing audit log code, verify:

- [ ] Is there a dedicated audit service with typed event constants (`as const`)?
- [ ] Are event names using `_FAILED` suffix for failure variants?
- [ ] Is there a dedicated audit module exporting a DI token (Symbol)?
- [ ] Do consuming feature modules import the audit module?
- [ ] Is injection done via `@Inject(TOKEN)` not class-based?
- [ ] Is action human and compliance-relevant?
- [ ] Is `objectId` correct for audit UI lookup in this domain?
- [ ] Does `objectId` fall back to `'unknown'` when missing?
- [ ] Is payload compact and useful?
- [ ] Are raw DTO/request/response/entity objects avoided?
- [ ] Is unnecessary PII excluded?
- [ ] Are statuses stored as string names, not raw numeric enum values?
- [ ] Does business failure publish a `FAIL` event when appropriate?
- [ ] Is the try/catch structured with success inside try, FAIL inside catch?
- [ ] Is original exception still rethrown?
- [ ] Is there no redundant transport-level try/catch around `AuditLogger`?
- [ ] Is audit logic centralized enough to stay maintainable across repo growth?
