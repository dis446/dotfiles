---
name: alpha-ci-cd-expert
description: Deploy, diagnose, and fix CI/CD for any alpha-backend service (NestJS and Quarkus). Covers new microservice setup, existing repo troubleshooting, template chain understanding, build-vs-runtime variable distinctions, and ArgoCD Helm deployments.
---

# Alpha CI/CD Expert

## Scope

This skill covers the **alpha-backend** CI/CD ecosystem at AND Global:

- **Quarkus (Java 21 / Maven)** services — e.g. `auth`, `relation-store`, `integration-service`
- **NestJS (Node.js / TypeScript)** services — e.g. `notification-service`, `mdm`, `borrower-api`
- **Symfony (PHP)** services — separate template tree, not covered here

All services deploy to **Kubernetes** via **GitLab CI/CD** + **ArgoCD** with Helm charts.

---

## Finding the Internal CI Templates Repo

The CI templates repo is at `internal/gitlab-ci/templates` on `git.and.global`. It **must not** be hardcoded by absolute path because it needs to work on any developer machine.

**Algorithm to find it:**

1. **Check common locations** under the user's `Code/and/` workspace:
   - `$HOME/Code/and/internal/gitlab-ci/templates`
   - `$HOME/work/and/internal/gitlab-ci/templates`
   - `$HOME/repos/internal/gitlab-ci/templates`
2. **Search via `find`** if not found:
   ```bash
   find "$HOME" -maxdepth 5 -type d -path "*/internal/gitlab-ci/templates" 2>/dev/null | head -1
   ```
3. **Clone if not present locally**:
   ```bash
   glab repo clone internal/gitlab-ci/templates --dir "$HOME/Code/and/internal/gitlab-ci/templates"
   ```
4. Set a shell variable for convenience:
   ```bash
   CI_TEMPLATES_DIR="$(find "$HOME" -maxdepth 5 -type d -path '*/internal/gitlab-ci/templates' 2>/dev/null | head -1)"
   ```

---

## CI/CD Architecture

### Template Chain

```
Auto-DevOps.gitlab-ci.yml  (official GitLab template — defines `build`, `production`, `.auto-deploy`)
  ↑
singlec-auto-devops.gitlab-ci.yml  (internal — for single-container apps)
or
quarkus-maven-auto-devops.gitlab-ci.yml  (internal — Quarkus/Maven with extra build/test/deploy jobs)
  ↑
argocd-auto-devops-release.gitlab-ci.yaml  (internal — ArgoCD deploy stages)
  ↑
<your-project>/.gitlab-ci.yml  (project-specific — defines environments, overrides variables)
```

### What the templates provide

| Template | Use case |
|---|---|
| `singlec-auto-devops.gitlab-ci.yml` | Simple single-container builds via official Auto-DevOps `build` job. Good for NestJS, simple Quarkus. |
| `quarkus-maven-auto-devops.gitlab-ci.yml` | Full Quarkus pipeline: `prepare-maven-deps`, `build` (buildx), `unit-test`, `code-style`, `sonarqube-check`, `extract-openapi`, `autodevops-chart`, deploy jobs. |
| `argocd-auto-devops-release.gitlab-ci.yaml` | ArgoCD deploy stages: `.dev_deploy`, `.sit_deploy`, `.test_deploy`, `.prod_deploy`. Each renders Helm values, prepares chart, generates APISIX config, publishes chart. |

### Deploy stages from `argocd-auto-devops-release.gitlab-ci.yaml`

| Template job | Stage | Purpose |
|---|---|---|
| `.dev_deploy` | deploy | Pulls image from `build` job's dotenv (`CI_APPLICATION_TAG`), renders `.gitlab/alpha-dev.yaml` |
| `.sit_deploy` | deploy | Same process, uses `.gitlab/alpha-ptf-sit.yaml` |
| `.test_deploy` | deploy | Same process, uses `.gitlab/alpha-test.yaml` |
| `.prod_deploy` | deploy | For tag-based prod releases, reuses image from source branch |

### Build jobs

| Job | Extends | Tag | Purpose |
|---|---|---|---|
| `build` (from template) | — | `$CI_COMMIT_SHA` | Base Docker build for the current branch |
| `build-sit` (project-defined) | `build` | `${CI_COMMIT_SHA}-sit` | Separate SIT build with different build args (e.g. `AUDIT_LOG_BACKEND=log`) |
| `build-mariadb` (project-defined) | `build` | `mariadb-${CI_COMMIT_SHA}` | Multi-profile variant (e.g. `auth` service) |

---

## Common CI/CD Variables

### Global variables (set in `.gitlab-ci.yml`)

| Variable | Typical value | Meaning |
|---|---|---|
| `AUDIT_LOG_BACKEND` | `"azure"` or `"log"` | Build-time Maven property selecting audit log backend (controls which dependencies are compiled into the JAR) |
| `OTEL_ENABLED` | `"true"` / `"false"` | Build-time: enable OpenTelemetry during Maven compile |
| `OTEL_TRACES_ENABLED` | `"true"` / `"false"` | Build-time: Quarkus OTEL traces |
| `OTEL_METRICS_ENABLED` | `"true"` / `"false"` | Build-time: Quarkus OTEL metrics |
| `OTEL_METRICS_EXPORTER` | `"cdi"` / `"otlp"` | Build-time: which OTEL metrics exporter to compile |
| `OTEL_TRACES_EXPORTER` | `"cdi"` / `"otlp"` | Build-time: which OTEL traces exporter to compile |
| `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS` | `--build-arg ...` | Passed to `docker buildx build` by the official `build` job |
| `CI_APPLICATION_TAG` | `$CI_COMMIT_SHA` | Docker image tag produced by the `build` job |
| `CI_APPLICATION_REPOSITORY` | `$CI_REGISTRY_IMAGE/$CI_COMMIT_REF_SLUG` | Docker image repository |
| `BASE_PATH` | e.g. `"/relation-store"` | URL prefix for the service |
| `OPENAPI_PATH` | `"/deployments/generated/openapi.yaml"` | Path to OpenAPI spec inside the Docker image |
| `DOCKERFILE_PATH` | `docker/Dockerfile` | Custom Dockerfile location |

### Runtime variables (set in Helm values e.g. `alpha-dev.yaml`)

These are injected as Kubernetes pod environment variables and consumed at application startup:

| Variable | Meaning |
|---|---|
| `AUDIT_LOG_BACKEND` | Runtime: selects which audit backend bean Quarkus activates |
| `DB_*` | Database connection |
| `AZ_SB_CONNECTION_STRING` | Azure Service Bus connection |
| `OTEL_*` | OpenTelemetry config |
| `LOG_LEVEL` | Application log level |
| `SCHEDULER_ENABLED` | Whether to enable cron-like scheduled jobs |

---

## The Critical Build-Time vs Runtime Distinction

This is the most common source of CI/CD bugs.

| Phase | When | Where | How `AUDIT_LOG_BACKEND` is consumed |
|---|---|---|---|
| **Build-time** | During `docker build` → Maven compile | `.gitlab-ci.yml` → `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS` → Docker `--build-arg` → Dockerfile `ARG` → Maven `-Dproperty` | Controls which classes/dependencies from `mn.and.common.logging.audit` are compiled into the JAR |
| **Runtime** | When the pod starts | `alpha-dev.yaml` → Kubernetes `env:` → Quarkus config property | Controls which backend bean is activated at startup |

**These are independent.** Changing the Helm values file does NOT change the Docker image, and vice versa.

**Rule of thumb:**
- The **Helm env var** and the **Docker build arg** for the same property name (`AUDIT_LOG_BACKEND`) must be consistent for a given environment.
- If `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS` uses `${AUDIT_LOG_BACKEND}`, the resolution depends on which CI variable is in scope for that job.

---

## How `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS` Works

The official `Auto-DevOps.gitlab-ci.yml` template defines the `build` job like this (simplified):

```yaml
build:
  script:
    - docker buildx build \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        ${AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS:-} \
        --push \
        "${AUTO_DEVOPS_BUILD_IMAGE_CONTEXT:-.}"
```

So `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS` is directly interpolated into the `docker buildx build` command line. Everything in it is passed as `--build-arg KEY=VALUE` to the Dockerfile.

### Variable resolution rules for `build-sit`

When a job `extends: build`, GitLab merges variables. The job's own variables override global ones:

```
Global scope:   AUDIT_LOG_BACKEND: "azure"
build-sit job:  AUDIT_LOG_BACKEND: "log"    <-- overrides global for this job only
```

So `${AUDIT_LOG_BACKEND}` inside `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS` resolves to `"log"` for `build-sit` and `"azure"` for the base `build` job.

---

## Quarkus Service: Complete CI/CD Pattern

### `.gitlab-ci.yml` structure

```yaml
include:
  - project: "internal/gitlab-ci/templates"
    ref: main
    file: "singlec-auto-devops.gitlab-ci.yml"
  - project: "internal/gitlab-ci/templates"
    ref: main
    file: "argocd-auto-devops-release.gitlab-ci.yaml"

alpha-dev:
  extends: .dev_deploy
  variables:
    VALUES_FILE: ".gitlab/alpha-dev.yaml"
  rules:
    - if: '$CI_COMMIT_BRANCH == "dev"'
  environment:
    name: alpha-dev

alpha-sit:
  extends: .sit_deploy
  variables:
    VALUES_FILE: ".gitlab/alpha-ptf-sit.yaml"
  rules:
    - if: '$CI_COMMIT_BRANCH == "dev"'
  environment:
    name: alpha-ptf-sit

alpha-test:
  extends: .test_deploy
  variables:
    VALUES_FILE: ".gitlab/alpha-test.yaml"
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
  environment:
    name: alpha-test

# --- SIT-specific build (separate Docker image tag, different build args) ---
build-sit:
  extends: build
  variables:
    CI_APPLICATION_TAG: "${CI_COMMIT_SHA}-sit"
    AUDIT_LOG_BACKEND: "log"
    AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS: "--build-arg MAVEN_BUILD_ARGS=$MAVEN_BUILD_ARGS --build-arg OTEL_ENABLED=true --build-arg OTEL_TRACES_ENABLED=true --build-arg OTEL_METRICS_ENABLED=true --build-arg OTEL_METRICS_EXPORTER=cdi --build-arg OTEL_TRACES_EXPORTER=cdi --build-arg AUDIT_LOG_BACKEND=${AUDIT_LOG_BACKEND}"

# --- Optional: custom build for a different DB profile ---
build-mariadb:
  extends: build
  variables:
    CI_APPLICATION_TAG: "mariadb-${CI_COMMIT_SHA}"
    AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS: "--build-arg DB_PROFILE=mariadb"

# --- Static checks ---
gitleaks-secret-check:
  stage: test
  image:
    name: ghcr.io/gitleaks/gitleaks:v8.27.2
    entrypoint: [""]
  script:
    - gitleaks detect -c gitleaks.toml --source . --no-git --verbose --redact=0 --exit-code=0

# --- Prevent default production job ---
production:
  script:
    - echo "Skipping production deployment"
  rules:
    - when: never

variables:
  BASE_PATH: "/my-service"
  OPENAPI_PATH: "/deployments/generated/openapi.yaml"
  DOCKERFILE_PATH: docker/Dockerfile
  OTEL_ENABLED: "false"
  OTEL_TRACES_ENABLED: "false"
  OTEL_METRICS_ENABLED: "false"
  OTEL_METRICS_EXPORTER: "otlp"
  OTEL_TRACES_EXPORTER: "otlp"
  AUDIT_LOG_BACKEND: "azure"
  AUTO_DEVOPS_DEPLOY_DEBUG: "true"
  AUTO_DEVOPS_COMMON_NAME: "false"
  AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS: "--build-arg MAVEN_BUILD_ARGS=$MAVEN_BUILD_ARGS --build-arg OTEL_ENABLED=${OTEL_ENABLED} --build-arg OTEL_TRACES_ENABLED=${OTEL_TRACES_ENABLED} --build-arg OTEL_METRICS_ENABLED=${OTEL_METRICS_ENABLED} --build-arg OTEL_METRICS_EXPORTER=${OTEL_METRICS_EXPORTER} --build-arg OTEL_TRACES_EXPORTER=${OTEL_TRACES_EXPORTER} --build-arg AUDIT_LOG_BACKEND=${AUDIT_LOG_BACKEND}"
```

### Quarkus Dockerfile pattern (`docker/Dockerfile`)

```dockerfile
# syntax=docker/dockerfile:1.7
FROM quay.io/quarkus/ubi-quarkus-mandrel-builder-image:jdk-21 AS build

ARG MAVEN_BUILD_ARGS=""
ARG OTEL_ENABLED=false
ARG OTEL_TRACES_ENABLED=false
ARG OTEL_METRICS_ENABLED=false
ARG OTEL_METRICS_EXPORTER="otlp"
ARG OTEL_TRACES_EXPORTER="otlp"
ARG AUDIT_LOG_BACKEND=log

ENV MAVEN_CLI_OPTS='-s /opt/app/.m2/settings.xml --batch-mode'

USER root
COPY . /opt/app/
COPY --chmod=755 mvnw /opt/app/mvnw
WORKDIR /opt/app

RUN echo "AUDIT_LOG_BACKEND = ${AUDIT_LOG_BACKEND}"
RUN echo "OTEL_ENABLED = ${OTEL_ENABLED}"

RUN if [ -d target/quarkus-app ] ; then \
    echo "Using prebuilt Quarkus app from build context" ; \
  else \
    ./mvnw $MAVEN_CLI_OPTS package -Dmaven.test.skip=true $MAVEN_BUILD_ARGS \
    -DOTEL_ENABLED=${OTEL_ENABLED} \
    -DOTEL_TRACES_ENABLED=${OTEL_TRACES_ENABLED} \
    -DOTEL_METRICS_ENABLED=${OTEL_METRICS_ENABLED} \
    -DOTEL_METRICS_EXPORTER=${OTEL_METRICS_EXPORTER} \
    -DOTEL_TRACES_EXPORTER=${OTEL_TRACES_EXPORTER} \
    -DAUDIT_LOG_BACKEND=${AUDIT_LOG_BACKEND} ; \
  fi

FROM registry.access.redhat.com/ubi8/openjdk-21:1.20
USER root
RUN microdnf install -y curl && microdnf clean all
USER 1001
WORKDIR /app

COPY --from=build --chown=185 /opt/app/target/quarkus-app/lib/ /deployments/lib/
COPY --from=build --chown=185 /opt/app/target/quarkus-app/*.jar /deployments/
COPY --from=build --chown=185 /opt/app/target/quarkus-app/app/ /deployments/app/
COPY --from=build --chown=185 /opt/app/target/quarkus-app/quarkus/ /deployments/quarkus/
COPY --from=build --chown=185 /opt/app/target/generated/openapi.yaml /deployments/generated/openapi.yaml

EXPOSE 8080
USER 185
ENV JAVA_OPTS_APPEND="-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager"
ENV JAVA_APP_JAR="/deployments/quarkus-run.jar"
ENTRYPOINT [ "/opt/jboss/container/java/run/run-java.sh" ]
```

### Helm values pattern (`.gitlab/alpha-dev.yaml`)

```yaml
application:
  secretName: "my-service-secret"
  env:
    - name: AUDIT_LOG_SOURCE
      value: "my-service"
    - name: AUDIT_LOG_BACKEND
      value: "azure"
    - name: AUDIT_LOG_AZURE_CONNECTION_STRING
      value: "$AUDIT_LOG_AZURE_CONNECTION_STRING"
    - name: DB_USER
      value: "app_my_service"
    - name: DB_PASS
      value: "$DB_PASS"
    - name: LOG_LEVEL
      value: "INFO"
    - name: SCHEDULER_ENABLED
      value: "true"

image:
  repository: reg.git.and.global:443/alpha/back-end/my-service/dev
  tag: $CI_COMMIT_SHA
  pullPolicy: Always

service:
  externalPort: 9777
  internalPort: 9777

ingress:
  enabled: true
  className: "nginx"
  tls:
    enabled: true
    secretName: ""

apisix:
  enabled: true
  upstream:
    enabled: true
    spec:
      scheme: "http"
      passHost: "node"
      timeout:
        connect: "60s"
        send: "60s"
        read: "60s"
```

### Key differences for SIT values (`.gitlab/alpha-ptf-sit.yaml`)

```yaml
    - name: AUDIT_LOG_BACKEND
      value: "log"                              # SIT uses log backend at runtime
image:
  tag: ${CI_COMMIT_SHA}-sit                     # Must match build-sit's CI_APPLICATION_TAG
```

---

## NestJS Service: Complete CI/CD Pattern

### `.gitlab-ci.yml` (NestJS variant)

NestJS projects use `singlec-auto-devops.gitlab-ci.yml` (same as simple Quarkus). They typically don't pass OTEL/AUDIT build args to Docker since NestJS uses environment variables at runtime, not Maven properties.

```yaml
include:
  - project: "internal/gitlab-ci/templates"
    ref: main
    file: "singlec-auto-devops.gitlab-ci.yml"
  - project: "internal/gitlab-ci/templates"
    ref: main
    file: "argocd-auto-devops-release.gitlab-ci.yaml"

alpha-dev:
  extends: .dev_deploy
  variables:
    VALUES_FILE: ".gitlab/alpha-dev.yaml"
  rules:
    - if: '$CI_COMMIT_BRANCH == "dev"'
  environment:
    name: alpha-dev

alpha-test:
  extends: .test_deploy
  variables:
    VALUES_FILE: ".gitlab/alpha-test.yaml"
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
  environment:
    name: alpha-test

gitleaks-secret-check:
  stage: test
  image:
    name: ghcr.io/gitleaks/gitleaks:v8.27.2
    entrypoint: [""]
  script:
    - gitleaks detect -c gitleaks.toml --source . --no-git --verbose --redact=0 --exit-code=0

production:
  script:
    - echo "Skipping production deployment"
  rules:
    - when: never

variables:
  BASE_PATH: "/my-nestjs-service"
  DOCKERFILE_PATH: docker/Dockerfile
  AUTO_DEVOPS_DEPLOY_DEBUG: "true"
  AUTO_DEVOPS_COMMON_NAME: "false"
```

### NestJS Dockerfile pattern

```dockerfile
# ---------------------------------------------------
# STAGE 1: Development target
# ---------------------------------------------------
FROM node:24-alpine AS development
WORKDIR /usr/src/app
ARG NEXUS_TOKEN
COPY package*.json .npmrc ./
RUN NEXUS_TOKEN=${NEXUS_TOKEN} npm install
COPY . .
CMD ["npm", "run", "start:dev"]

# ---------------------------------------------------
# STAGE 2: Builder
# ---------------------------------------------------
FROM node:24-alpine AS builder
WORKDIR /usr/src/app
ARG NEXUS_TOKEN
COPY package*.json .npmrc ./
RUN NEXUS_TOKEN=${NEXUS_TOKEN} npm ci
COPY . .
RUN NEXUS_TOKEN=${NEXUS_TOKEN} npm run build && npm run openapi:generate

# ---------------------------------------------------
# STAGE 3: Production dependencies
# ---------------------------------------------------
FROM node:24-alpine AS deps
WORKDIR /usr/src/app
ARG NEXUS_TOKEN
COPY package*.json .npmrc ./
RUN NEXUS_TOKEN=${NEXUS_TOKEN} npm ci --omit=dev

# ---------------------------------------------------
# STAGE 4: Production runtime
# ---------------------------------------------------
FROM node:24-alpine AS production
WORKDIR /usr/src/app
USER node
COPY --chown=node:node package*.json ./
COPY --chown=node:node --from=deps /usr/src/app/node_modules ./node_modules
COPY --chown=node:node --from=builder /usr/src/app/dist ./dist
COPY --chown=node:node --from=builder /usr/src/app/openapi.yaml ./openapi.yaml
COPY healthcheck.js ./
EXPOSE 3000
CMD ["node", "dist/main.js"]
```

If the NestJS service uses the `NEXUS_TOKEN` build arg for private npm packages, the `.gitlab-ci.yml` must pass it:

```yaml
variables:
  AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS: "--build-arg NEXUS_TOKEN=$NEXUS_TOKEN"
```

---

## Setting Up a Brand New Microservice

### Step-by-step checklist

1. **Create the GitLab repo** and push initial code.

2. **Create `.gitlab-ci.yml`** by copying from an existing service of the same type (Quarkus → `relation-store`; NestJS → `notification-service`). Adjust:
   - `BASE_PATH` — URL prefix
   - `OPENAPI_PATH` — where the OpenAPI spec lives in the image
   - `DOCKERFILE_PATH` — path to the Dockerfile
   - `AUDIT_LOG_BACKEND` — `"azure"` for dev, `"log"` for SIT
   - Add `build-sit` job with `AUDIT_LOG_BACKEND: "log"` if the service has build-time compile differences
   - Add `gitleaks-secret-check` job
   - Add `production` dummy job that `when: never`

3. **Create `.gitlab/alpha-dev.yaml`**, `.gitlab/alpha-ptf-sit.yaml`, `.gitlab/alpha-test.yaml`:
   - Set correct DB credentials, image tag, ports
   - `alpha-dev.yaml`: tag `$CI_COMMIT_SHA`, `AUDIT_LOG_BACKEND: "azure"` (or `"log"` if not using Azure)
   - `alpha-ptf-sit.yaml`: tag `${CI_COMMIT_SHA}-sit`, `AUDIT_LOG_BACKEND: "log"`
   - `alpha-test.yaml`: tag `$CI_COMMIT_SHA`, `AUDIT_LOG_BACKEND: "azure"`

4. **Create `gitleaks.toml`** (copy from an existing service).

5. **Ensure the `image.repository` path matches** the GitLab project path:
   ```
   reg.git.and.global:443/alpha/back-end/<service-name>/dev
   ```

6. **Push to `dev` branch** and verify pipeline runs:
   - `build` job succeeds (image tagged `$CI_COMMIT_SHA`)
   - `build-sit` job succeeds (image tagged `${CI_COMMIT_SHA}-sit`)
   - `alpha-dev` deploy job succeeds
   - `alpha-sit` deploy job succeeds (if `.sit_deploy` is set up)

7. **For Quarkus services**: verify the Quarkus template specific jobs:
   - `prepare-maven-deps` succeeds (pulls Maven dependencies into cache)
   - `extract-openapi` succeeds (extracts OpenAPI spec from Docker image for APISIX)

---

## Diagnosing CI/CD Problems

### Step 1: Identify the failing job

```bash
glab ci get --pipeline-id <ID> --status=failed --with-job-details
# or
glab ci status --branch dev
```

### Step 2: Read the job trace

```bash
glab ci trace <job-id>
```

### Step 3: Common failure patterns and fixes

#### Pattern A: SIT deployment pulls stale/wrong image

**Symptoms:**
- SIT deploy succeeds but uses old code
- `alpha-ptf-sit.yaml` image tag doesn't match what `build-sit` produces

**Diagnosis:**
```bash
# Check what build-sit tags
grep "CI_APPLICATION_TAG" .gitlab-ci.yml
# Check what SIT deploy expects
grep "tag:" .gitlab/alpha-ptf-sit.yaml
```

**Fix:** Ensure `alpha-ptf-sit.yaml`'s `tag` matches `build-sit`'s `CI_APPLICATION_TAG`.

#### Pattern B: Wrong audit log backend at runtime

**Symptoms:**
- `AUDIT_LOG_BACKEND=azure` errors in SIT (e.g. Azure Service Bus connection failures)
- SIT should use `log` backend but tries to connect to Azure

**Diagnosis:**
```bash
# Check build-time value
glab ci trace <build-sit-job-id> | grep "AUDIT_LOG_BACKEND"
# Check runtime value
grep "AUDIT_LOG_BACKEND" .gitlab/alpha-ptf-sit.yaml
```

**Fix:** Both must be consistent. If SIT should use `log`:
- `.gitlab-ci.yml`: add `AUDIT_LOG_BACKEND: "log"` to `build-sit` job's `variables:`
- `.gitlab/alpha-ptf-sit.yaml`: set `AUDIT_LOG_BACKEND: "log"` in the env section

#### Pattern C: Build uses wrong OTEL configuration

**Symptoms:**
- Quarkus app fails to start in dev with `cdi` exporter errors
- Dev environment shows OTEL connectivity errors
- OTEL endpoint is expected in SIT but not configured

**Diagnosis:**
```bash
# Check what OTEL args were passed at build time
glab ci trace <build-job-id> | grep "OTEL"
# Check what OTEL env vars are set at runtime
grep "OTEL" .gitlab/alpha-dev.yaml
```

**Fix:** Align build args and runtime env vars per environment:
- Dev: `OTEL_ENABLED=true`, `OTEL_*_EXPORTER=cdi` (no external collector needed)
- Test/Prod: `OTEL_ENABLED=false` or `OTEL_*=otlp` with actual collector endpoint

#### Pattern D: `extract-openapi` fails

**Symptoms:**
- `extract-openapi` job fails with image not found
- `extract-openapi` artifact missing

**Diagnosis:**
```bash
glab ci trace <extract-openapi-job-id>
```

**Common causes:**
- Image was tagged with `-sit` suffix but `OPENAPI_PATH` job uses `$CI_COMMIT_SHA` (no suffix)
- Docker image doesn't contain openapi.yaml at `OPENAPI_PATH`

**Fix:** The `extract-openapi` job from `argocd-auto-devops-release.gitlab-ci.yaml` pulls `$CI_APPLICATION_REPOSITORY:$CI_APPLICATION_TAG` which comes from the `build` job's dotenv artifact — so it gets the base `$CI_COMMIT_SHA` tag, not the `-sit` tagged image. This is intentional; the OpenAPI spec is identical regardless of build args.

#### Pattern E: Image tag mismatch between build and deploy

**Symptoms:**
- Deploy job fails with `ImagePullBackOff`
- Kubernetes can't find the image tag

**Diagnosis:**
```bash
# What the deploy job expects
grep "tag:" .gitlab/alpha-*.yaml
# What the build job produces
grep "CI_APPLICATION_TAG" .gitlab-ci.yml
```

**Fix:** Ensure the tag in the Helm values file exactly matches what the `build` or `build-sit` job produces.

#### Pattern F: Pipeline doesn't trigger on push

**Symptoms:**
- Pushing to `dev` doesn't start a pipeline
- Jobs show as skipped

**Diagnosis:**
```bash
# Check workflow rules
grep -A5 "workflow:" .gitlab-ci.yml
# Check job rules
grep -B2 -A5 "rules:" .gitlab-ci.yml | head -40
```

**Fix:** Ensure `workflow:rules:` (if present) includes `$CI_COMMIT_BRANCH == "dev"`. Ensure each job's `rules:` matches the target branch.

#### Pattern G: `build-sit` job uses same build args as base `build`

**Symptoms:**
- `build-sit` trace shows `AUDIT_LOG_BACKEND=azure` when it should show `log`
- SIT and dev images are identical despite different `AUDIT_LOG_BACKEND` expected

**Diagnosis:**
```bash
# Check if build-sit overrides AUDIT_LOG_BACKEND
grep -A5 "build-sit:" .gitlab-ci.yml
```

**Fix:** Add `AUDIT_LOG_BACKEND: "log"` to the `build-sit` job's `variables:`. Simply having it in the Helm values file is NOT enough — the Docker build arg is independent from the runtime env var.

#### Pattern H: Quarkus `build` fails on Maven dependency resolution

**Symptoms:**
- `[ERROR] Failed to execute goal on project ... Could not resolve dependencies`
- Maven build fails in Docker

**Diagnosis:**
```bash
glab ci trace <build-job-id> | grep "ERROR" | head -20
```

**Common causes:**
- `.m2/settings.xml` references internal repos that aren't available during Docker build
- The Docker build runs inside Docker-in-Docker and doesn't have access to the CI runner's Maven cache
- The `mvnw` file isn't executable or is corrupted

**Fix:**
- Ensure Dockerfile copies `.m2/settings.xml` into the builder stage
- Ensure the `mvnw` has `+x` permission in the repo (`COPY --chmod=755 mvnw /opt/app/mvnw`)
- Use the `target/quarkus-app` prebuilt path: if `prepare-maven-deps` or another job builds the app in CI, the Dockerfile can skip the Maven step

#### Pattern I: ArgoCD deployment stuck or failing

**Symptoms:**
- Deploy job succeeds but no new pods are rolled out
- ArgoCD shows `OutOfSync` or `Progressing`

**Diagnosis:**
```bash
# Check ArgoCD app status via glab
argocd app get <app-name>
```

**Common causes:**
- Helm values rendering failed — check `deploy-utils` output in the deploy job trace
- APISIX route generation failed — OpenAPI file is malformed
- ImagePullBackOff — check the image tag in the rendered values

---

## Refactoring Existing CI/CD Configs

When a service's `.gitlab-ci.yml` needs to be brought inline with the canonical pattern (auth / relation-store), apply this checklist. The goal is structural consistency so all alpha-backend services are maintainable by the same mental model.

### Canonical Pattern (Reference: auth, relation-store)

```yaml
include:
  - project: "internal/gitlab-ci/templates"
    ref: main
    file: "singlec-auto-devops.gitlab-ci.yml"
  - project: "internal/gitlab-ci/templates"
    ref: main
    file: "argocd-auto-devops-release.gitlab-ci.yaml"

# --- Deploy jobs ---
alpha-dev:
  extends: .dev_deploy
  variables:
    VALUES_FILE: ".gitlab/alpha-dev.yaml"
  rules:
    - if: '$CI_COMMIT_BRANCH == "dev"'
  environment:
    name: alpha-dev

alpha-sit:
  extends: .sit_deploy
  variables:
    VALUES_FILE: ".gitlab/alpha-ptf-sit.yaml"
  rules:
    - if: '$CI_COMMIT_BRANCH == "dev"'
  environment:
    name: alpha-ptf-sit

alpha-test:
  extends: .test_deploy
  variables:
    VALUES_FILE: ".gitlab/alpha-test.yaml"
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
  environment:
    name: alpha-test

# --- SIT-specific build (separate tag, different build args) ---
build-sit:
  extends: build
  variables:
    CI_APPLICATION_TAG: "${CI_COMMIT_SHA}-sit"
    AUDIT_LOG_BACKEND: "log"
    AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS: "--build-arg MAVEN_BUILD_ARGS=$MAVEN_BUILD_ARGS --build-arg OTEL_ENABLED=true --build-arg OTEL_TRACES_ENABLED=true --build-arg OTEL_METRICS_ENABLED=true --build-arg OTEL_METRICS_EXPORTER=cdi --build-arg OTEL_TRACES_EXPORTER=cdi --build-arg AUDIT_LOG_BACKEND=${AUDIT_LOG_BACKEND}"

# --- MR-only test jobs ---
sonarqube-check:
  stage: test
  image: ${CI_DEPENDENCY_PROXY_GROUP_IMAGE_PREFIX}/maven:3.9-eclipse-temurin-21
  variables:
    GIT_DEPTH: "0"
    SONAR_USER_HOME: "${CI_PROJECT_DIR}/.sonar"
  cache:
    key: "${CI_JOB_NAME}"
    paths:
      - .sonar/cache
  before_script:
    - mkdir -p ~/.m2
    - cp $CI_PROJECT_DIR/.m2/settings.xml ~/.m2/settings.xml
    - chmod +x mvnw
  script:
    - ./mvnw compile org.sonarsource.scanner.maven:sonar-maven-plugin:4.0.0.4121:sonar -DskipTests -s ~/.m2/settings.xml -Dsonar.qualitygate.wait=true -Dsonar.projectKey=$SONAR_PROJECT_KEY -Dsonar.host.url=$SONAR_HOST_URL -Dsonar.token=$SONAR_TOKEN -DAUDIT_LOG_BACKEND=${AUDIT_LOG_BACKEND}
  allow_failure: true
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'

code-style:
  image: ${CI_DEPENDENCY_PROXY_GROUP_IMAGE_PREFIX}/maven:3.9-eclipse-temurin-21
  stage: test
  before_script:
    - mkdir -p ~/.m2
    - cp $CI_PROJECT_DIR/.m2/settings.xml ~/.m2/settings.xml
  script:
    - ./mvnw spotless:check -s ~/.m2/settings.xml -U
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
  allow_failure: false

# --- Static checks ---
gitleaks-secret-check:
  stage: test
  image:
    name: ghcr.io/gitleaks/gitleaks:v8.27.2
    entrypoint: [""] # Disable the default entrypoint
  script:
    - gitleaks detect -c gitleaks.toml --source . --no-git --verbose --redact=0 --exit-code=0

# --- Disable default production ---
production:
  script:
    - echo "Skipping production deployment"
  rules:
    - when: never

# --- Global variables at the bottom ---
variables:
  BASE_PATH: "/my-service"
  OPENAPI_PATH: "/deployments/generated/openapi.yaml"
  DOCKERFILE_PATH: docker/Dockerfile
  OTEL_ENABLED: "false"
  OTEL_TRACES_ENABLED: "false"
  OTEL_METRICS_ENABLED: "false"
  OTEL_METRICS_EXPORTER: "otlp"
  OTEL_TRACES_EXPORTER: "otlp"
  AUDIT_LOG_BACKEND: "azure"
  AUTO_DEVOPS_DEPLOY_DEBUG: "true"
  AUTO_DEVOPS_COMMON_NAME: "false"
  AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS: "--build-arg MAVEN_BUILD_ARGS=$MAVEN_BUILD_ARGS --build-arg OTEL_ENABLED=${OTEL_ENABLED} --build-arg OTEL_TRACES_ENABLED=${OTEL_TRACES_ENABLED} --build-arg OTEL_METRICS_ENABLED=${OTEL_METRICS_ENABLED} --build-arg OTEL_METRICS_EXPORTER=${OTEL_METRICS_EXPORTER} --build-arg OTEL_TRACES_EXPORTER=${OTEL_TRACES_EXPORTER} --build-arg AUDIT_LOG_BACKEND=${AUDIT_LOG_BACKEND}"
```

### Refactoring Checklist

Apply these changes in order when bringing a `.gitlab-ci.yml` into the canonical pattern:

| # | Change | Why |
|---|---|---|
| 1 | **Remove `workflow:rules:`** | Branch-specific OTEL overrides are handled by `build-sit`'s hardcoded build args instead. The base `build` job uses the global defaults (`OTEL_ENABLED=false`, `AUDIT_LOG_BACKEND=azure`). |
| 2 | **Remove explicit `stages:`** | Stages come from the included templates (`singlec-auto-devops.gitlab-ci.yml` → `Auto-DevOps.gitlab-ci.yml`). Defining them locally overrides template stages and can cause ordering issues. |
| 3 | **Remove SAST includes** | Auth/relation-store don't use `Security/SAST.gitlab-ci.yml` or `Security/SAST-IaC.latest.gitlab-ci.yml`. Remove both the `include:` entries and any `.sast-analyzer` rule anchors. |
| 4 | **Remove SAST variables** | e.g. `SAST_STAGE`, `SAST_DISABLED`. These are only relevant if SAST is included. |
| 5 | **Reorder jobs** | Canonical order: deploy jobs (`alpha-dev`, `alpha-sit`, `alpha-test`) → `build-sit` → MR test jobs (`integration-test`, `unit-test`, `sonarqube-check`, `code-style`) → `gitleaks-secret-check` → `production` → `variables`. |
| 6 | **Move `variables:` to the bottom** | This is the convention in auth and relation-store. Keeps the main job definitions readable before the configuration block. |
| 7 | **Add `-DAUDIT_LOG_BACKEND=${AUDIT_LOG_BACKEND}` to `sonarqube-check`** | The canonical pattern passes this Maven property to every `mvnw` invocation so the shared audit library resolves the correct profile. |
| 8 | **Make `code-style` MR-only** | Remove `- if: '$CI_COMMIT_BRANCH == "dev"'` from `code-style` rules. Spotless formatting should only gate MRs, not branch pushes. |
| 9 | **Remove `stage: production` from `production` job** | The canonical pattern omits the explicit `stage:` since `production` is already in the deploy stage from the template. |
| 10 | **Ensure `build-sit` overrides `AUDIT_LOG_BACKEND`** | The `build-sit` job must set `AUDIT_LOG_BACKEND: "log"` so that `${AUDIT_LOG_BACKEND}` in `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS` resolves correctly for the SIT image build. |
| 11 | **If service has an inline `unit-test` job, keep it** | Unlike relation-store (which uses `integration-test` for MRs), services that already have a working `unit-test` job providing coverage data should keep it. Add `-DAUDIT_LOG_BACKEND=${AUDIT_LOG_BACKEND}` if not already present in the Maven invocation. |
| 12 | **Standardize quote style** | Use double quotes consistently (`"true"` not `'true'`). The canonical pattern uses double quotes throughout. |

### SIT Helm values checklist

After refactoring `.gitlab-ci.yml`, verify `.gitlab/alpha-ptf-sit.yaml`:

```yaml
    - name: AUDIT_LOG_BACKEND
      value: "log"                         # Must be "log" for SIT
image:
  tag: \${CI_COMMIT_SHA}-sit                # Must match build-sit's CI_APPLICATION_TAG
```

---

## Working with `glab` for CI/CD

### View pipelines

```bash
# Latest pipeline for current branch
glab ci status --output json

# Specific pipeline
glab ci get --pipeline-id <ID> --output json

# Specific pipeline from another project
glab ci get -R alpha/back-end/relation-store --pipeline-id 242169
```

### View job logs

```bash
glab ci trace <job-id>
```

### Get pipeline for a specific commit

```bash
glab ci get -b dev
```

### View CI variables used in a pipeline

```bash
glab ci get --pipeline-id <ID> --with-variables
```

### Inspect build args used in a build job

```bash
glab ci trace <build-job-id> | grep -E "(AUDIT_LOG_BACKEND|OTEL|build-arg|Docker Build Args)"
```

---

## Required Files Checklist Per Service

| File | Quarkus | NestJS |
|---|---|---|
| `.gitlab-ci.yml` | ✅ | ✅ |
| `.gitlab/alpha-dev.yaml` | ✅ | ✅ |
| `.gitlab/alpha-ptf-sit.yaml` | ✅ | ✅ |
| `.gitlab/alpha-test.yaml` | ✅ | ✅ |
| `docker/Dockerfile` | ✅ | ✅ |
| `gitleaks.toml` | ✅ | ✅ |
| `mvnw` | ✅ | ❌ |
| `.m2/settings.xml` | ✅ | ❌ |
| `pom.xml` | ✅ | ❌ |
| `package.json` | ❌ | ✅ |
| `.npmrc` | ❌ | ✅ |

---

## Key Rules To Remember

1. **Build-time ≠ Runtime.** Docker build args (passed via `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS`) are independent from Helm values env vars. Both must be set correctly.

2. **Image tags must match.** The `alpha-ptf-sit.yaml` image tag must equal what `build-sit`'s `CI_APPLICATION_TAG` produces.

3. **`build-sit` overrides** must include the variable override (e.g. `AUDIT_LOG_BACKEND`) if differing from the global default. Inheriting the global default is the most common bug.

4. **The `extract-openapi` job** always pulls the base tag (`$CI_COMMIT_SHA`), not the `-sit` suffixed image. The OpenAPI spec is the same regardless of build args, so this is correct behavior.

5. **`gitleaks.toml` must be in repo root.** CI runs it with `--no-git` flag so the file must be present.

6. **NestJS services** typically don't need `build-sit` since NestJS doesn't have Maven profiles. The same Docker image works for all environments; only env vars differ.

7. **When unsure why a build behaves differently than expected**, compare the trace output of the `build` job vs the `build-sit` job:
   ```bash
   glab ci trace <build-job-id> | grep -E "(AUDIT_LOG_BACKEND|build-arg|Docker Build Args)"
   glab ci trace <build-sit-job-id> | grep -E "(AUDIT_LOG_BACKEND|build-arg|Docker Build Args)"
   ```
