---
name: alpha-ci-cd-expert
description: Deploy, diagnose, and fix CI/CD for any alpha-backend service (NestJS and Quarkus). Covers new microservice setup, existing repo troubleshooting, template chain understanding, build-vs-runtime variable distinctions, and ArgoCD Helm deployments.
---

# Alpha CI/CD Expert

## Scope

This skill covers the **alpha-backend** CI/CD ecosystem at AND Global:

- **Quarkus (Java 21 / Maven)** services — uses `quarkus-maven-auto-devops.gitlab-ci.yml` template
- **NestJS (Node.js / TypeScript)** services — uses `singlec-auto-devops.gitlab-ci.yml` template
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
singlec-auto-devops.gitlab-ci.yml  (internal — for single-container apps; NestJS, simple Quarkus)
or
quarkus-maven-auto-devops.gitlab-ci.yml  (internal — Quarkus/Maven with BuildKit cache, MR jobs, auto SAST)
  ↑
argocd-auto-devops-release.gitlab-ci.yaml  (internal — ArgoCD deploy stages; transitively included by quarkus template)
  ↑
<your-project>/.gitlab-ci.yml  (project-specific — defines per-environment builds, deploy jobs, variables)
```

### Key difference: Quarkus template transitively includes the ArgoCD template

The `quarkus-maven-auto-devops.gitlab-ci.yml` template **already includes** `argocd-auto-devops-release.gitlab-ci.yaml` internally. So a Quarkus project **only includes one template**:

```yaml
include:
  - project: "internal/gitlab-ci/templates"
    ref: main
    file: "quarkus-maven-auto-devops.gitlab-ci.yml"
```

NestJS projects still need both includes explicitly.

### What the templates provide

| Template | Use case |
|---|---|
| `singlec-auto-devops.gitlab-ci.yml` | Simple single-container builds via official Auto-DevOps `build` job. Good for NestJS, simple Quarkus. |
| `quarkus-maven-auto-devops.gitlab-ci.yml` | Full Quarkus pipeline: `prepare-maven-deps`, `build` (buildx with registry layer cache), `unit-test`, `code-style`, `sonarqube-check`, SAST, `extract-openapi`, `autodevops-chart`, deploy jobs. Automatically includes `argocd-auto-devops-release.gitlab-ci.yaml`. |
| `argocd-auto-devops-release.gitlab-ci.yaml` | ArgoCD deploy stages: `.dev_deploy`, `.sit_deploy`, `.test_deploy`, `.prod_deploy`. Each renders Helm values, prepares chart, generates APISIX config, publishes chart. |

### What the Quarkus template provides (automatically)

| Job | Stage | When | Purpose |
|---|---|---|---|
| `prepare-maven-deps` | build | MR only | Pre-warms Maven dependency cache (POM + settings keyed) so downstream MR jobs hit a hot cache |
| `build` | build | branch pushes | BuildKit build with registry layer cache, pushes to GitLab registry |
| `unit-test` | test | MR only | Runs `mvnw test` with JaCoCo coverage, parses CSV for coverage regex |
| `code-style` | test | MR only | Runs `mvnw spotless:check` |
| `sonarqube-check` | test | MR only | Runs SonarQube scan with quality gate |
| SAST / SAST-IaC | test | MR only | From GitLab templates, constrained to MRs |
| `extract-openapi` | deploy | branch pushes | Pulls OpenAPI spec from built image for APISIX route generation |
| `.dev_deploy` / `.sit_deploy` / `.test_deploy` / `.prod_deploy` | deploy | branch pushes | ArgoCD Helm deploy stages |

### Deploy stages from `argocd-auto-devops-release.gitlab-ci.yaml`

| Template job | Stage | Purpose |
|---|---|---|
| `.dev_deploy` | deploy | Pulls image from `build` job's dotenv (`CI_APPLICATION_TAG`), renders `.gitlab/alpha-dev.yaml` |
| `.sit_deploy` | deploy | Same process, uses `.gitlab/alpha-ptf-sit.yaml` |
| `.test_deploy` | deploy | Same process, uses `.gitlab/alpha-test.yaml` |
| `.prod_deploy` | deploy | For tag-based prod releases, reuses image from source branch |

---

## The `BUILD_*` Variable Convention (Canonical Pattern)

This is the **most important distinction** between old and canonical patterns.

The canonical Quarkus pattern uses `BUILD_*` prefixed variables for build-time knobs instead of the bare variable names. This cleanly separates build-time concerns from runtime concerns and prevents accidental collisions.

| Old pattern (bare vars) | Canonical pattern (`BUILD_*` prefix) |
|---|---|
| `AUDIT_LOG_BACKEND: "azure"` | `BUILD_AUDIT_LOG_BACKEND: "amqp"` |
| `OTEL_ENABLED: "true"` | `BUILD_OTEL_ENABLED: "true"` |
| `OTEL_TRACES_ENABLED: "false"` | `BUILD_OTEL_TRACES_ENABLED: "false"` |
| `OTEL_METRICS_EXPORTER: "cdi"` | `BUILD_OTEL_METRICS_EXPORTER: "cdi"` |

### Why `BUILD_*`?

1. **No name collision** — the Dockerfile `ARG` name matches exactly (`ARG BUILD_AUDIT_LOG_BACKEND` → `${BUILD_AUDIT_LOG_BACKEND}`). No mapping layer.
2. **Obvious scope** — any variable prefixed `BUILD_` is consumed at Docker build time, never at pod runtime.
3. **Template-managed mapping** — the `quarkus-maven-auto-devops.gitlab-ci.yml` template already defines `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS` with `--build-arg BUILD_*=${BUILD_*}` entries. Projects **do not** define `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS` themselves — they just set `BUILD_*` variables.

## Common CI/CD Variables

### Build-time variables (set in `.gitlab-ci.yml` — `BUILD_*` prefix)

These are passed as Docker `--build-arg` entries by the template's `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS`:

| Variable | Typical value | Meaning |
|---|---|---|
| `BUILD_AUDIT_LOG_BACKEND` | `"amqp"` / `"log"` / `"azure"` | Build-time Maven property selecting audit log backend |
| `BUILD_OTEL_ENABLED` | `"true"` / `"false"` | Enable OpenTelemetry during Maven compile |
| `BUILD_OTEL_TRACES_ENABLED` | `"true"` / `"false"` | Quarkus OTEL traces |
| `BUILD_OTEL_METRICS_ENABLED` | `"true"` / `"false"` | Quarkus OTEL metrics |
| `BUILD_OTEL_METRICS_EXPORTER` | `"cdi"` / `"otlp"` | Which OTEL metrics exporter to compile |
| `BUILD_OTEL_TRACES_EXPORTER` | `"cdi"` / `"otlp"` | Which OTEL traces exporter to compile |

### Project variables (set in `.gitlab-ci.yml`)

| Variable | Typical value | Meaning |
|---|---|---|
| `CI_APPLICATION_TAG` | `$CI_COMMIT_SHA` | Docker image tag produced by the `build` job |
| `CI_APPLICATION_REPOSITORY` | `$CI_REGISTRY_IMAGE/$CI_COMMIT_REF_SLUG` | Docker image repository |
| `BASE_PATH` | e.g. `"/anti-fraud"` | URL prefix for the service |
| `OPENAPI_PATH` | `"/deployments/generated/openapi.yaml"` | Path to OpenAPI spec inside the Docker image |
| `DOCKERFILE_PATH` | `Dockerfile` | Path to Dockerfile (default: `Dockerfile` in root) |
| `COVERAGE_AWK_PATTERN` | `"mn[.\\/]and[.\\/]myservice[.\\/]service"` | Regex scoping coverage to your package |

### Runtime variables (set in Helm values e.g. `alpha-dev.yaml`)

These are injected as Kubernetes pod environment variables and consumed at application startup:

| Variable | Meaning |
|---|---|
| `AUDIT_LOG_BACKEND` | Runtime: selects which audit backend bean Quarkus activates |
| `AUDIT_LOG_*` (AMQP/Azure) | Runtime: audit log connection details |
| `DB_*` | Database connection |
| `OTEL_ENDPOINT`, `OTEL_EXPORTER_*` | OpenTelemetry config |
| `LOG_LEVEL` | Application log level |
| `LOG_FILE_ENABLE` | Whether to enable file logging |
| `SCHEDULER_ENABLED` | Whether to enable cron-like scheduled jobs |
| `FLYWAY_MIGRATE_AT_START` | Whether Flyway runs migrations on startup |
| `DB_GENERATION` | Quarkus DB schema generation (`"none"` for production) |

---

## The Critical Build-Time vs Runtime Distinction

This is the most common source of CI/CD bugs.

| Phase | When | Where | How `AUDIT_LOG_BACKEND` is consumed |
|---|---|---|---|
| **Build-time** | During `docker build` → Maven compile | Dockerfile `ARG BUILD_AUDIT_LOG_BACKEND` → Maven `-DAUDIT_LOG_BACKEND=...` | Controls which classes/dependencies from `mn.and.common.logging.audit` are compiled into the JAR |
| **Runtime** | When the pod starts | `alpha-dev.yaml` → Kubernetes `env:` → Quarkus config property | Controls which backend bean is activated at startup |

**These are independent.** Changing the Helm values file does NOT change the Docker image, and vice versa.

**Rule of thumb:**
- The **Helm env var** (`AUDIT_LOG_BACKEND`) and the **Docker build arg** (`BUILD_AUDIT_LOG_BACKEND`) for the same logical property must be consistent for a given environment.
- In the canonical pattern, `BUILD_AUDIT_LOG_BACKEND` and the Helm `AUDIT_LOG_BACKEND` can differ if the image is built with all backends compiled in — but typically they match.

---

## How the Quarkus Template Handles Build Args

The `quarkus-maven-auto-devops.gitlab-ci.yml` template defines `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS` globally:

```yaml
variables:
  AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS: >-
    --build-arg BUILD_OTEL_ENABLED=${BUILD_OTEL_ENABLED}
    --build-arg BUILD_OTEL_TRACES_ENABLED=${BUILD_OTEL_TRACES_ENABLED}
    --build-arg BUILD_OTEL_METRICS_ENABLED=${BUILD_OTEL_METRICS_ENABLED}
    --build-arg BUILD_OTEL_METRICS_EXPORTER=${BUILD_OTEL_METRICS_EXPORTER}
    --build-arg BUILD_OTEL_TRACES_EXPORTER=${BUILD_OTEL_TRACES_EXPORTER}
    --build-arg BUILD_AUDIT_LOG_BACKEND=${BUILD_AUDIT_LOG_BACKEND}
```

**Projects do NOT redefine `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS`.** They only set `BUILD_*` variables and the template handles the mapping to Docker build args.

### Variable resolution for per-environment builds

When a job `extends: build` with overridden `BUILD_*` variables, GitLab merges them:

```
Global scope:         BUILD_AUDIT_LOG_BACKEND: "amqp"
build-sit job scope:  BUILD_AUDIT_LOG_BACKEND: "amqp"    <-- same as global, no override needed
```

Since the template resolves `$BUILD_AUDIT_LOG_BACKEND` inside `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS` at job runtime, the per-environment job's variable value is picked up automatically.

---

## Quarkus Service: Complete CI/CD Pattern (Canonical)

### Architecture

The canonical Quarkus pattern:

1. **Includes only `quarkus-maven-auto-devops.gitlab-ci.yml`** — it transitively pulls in `argocd-auto-devops-release.gitlab-ci.yaml`.
2. **Disables the base `build` job** with `when: never` — the template's generic build job is never triggered by branch rules.
3. **Defines per-environment build jobs** (`build-dev`, `build-sit`, `build-test`) each extending `build` with environment-specific tags and `BUILD_*` variables.
4. **Deploy jobs** extend `.dev_deploy` / `.sit_deploy` / `.test_deploy` and reference per-environment Helm values.
5. **MR-only test jobs** (`unit-test`, `code-style`, `sonarqube-check`, SAST) come from the template automatically.

### `.gitlab-ci.yml` structure

```yaml
include:
  - project: "internal/gitlab-ci/templates"
    ref: main
    file: "quarkus-maven-auto-devops.gitlab-ci.yml"

# Disable the base build job — we define per-environment builds below.
build:
  rules:
    - when: never

# --- Per-environment image builds ---
build-dev:
  extends: build
  variables:
    CI_APPLICATION_TAG: "${CI_COMMIT_SHA}-dev"
    BUILD_OTEL_ENABLED: "true"
    BUILD_OTEL_TRACES_ENABLED: "true"
    BUILD_OTEL_METRICS_ENABLED: "true"
    BUILD_AUDIT_LOG_BACKEND: "amqp"
  rules:
    - if: '$CI_COMMIT_BRANCH == "dev"'

build-sit:
  extends: build
  variables:
    CI_APPLICATION_TAG: "${CI_COMMIT_SHA}-sit"
    BUILD_OTEL_ENABLED: "false"
    BUILD_OTEL_TRACES_ENABLED: "false"
    BUILD_OTEL_METRICS_ENABLED: "false"
    BUILD_AUDIT_LOG_BACKEND: "amqp"
  rules:
    - if: '$CI_COMMIT_BRANCH == "dev"'

build-test:
  extends: build
  variables:
    CI_APPLICATION_TAG: "${CI_COMMIT_SHA}-test"
    BUILD_OTEL_ENABLED: "false"
    BUILD_OTEL_TRACES_ENABLED: "false"
    BUILD_OTEL_METRICS_ENABLED: "false"
    BUILD_AUDIT_LOG_BACKEND: "amqp"
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'

# --- Static checks ---
gitleaks-secret-check:
  stage: test
  image:
    name: ghcr.io/gitleaks/gitleaks:v8.27.2
    entrypoint: [""]
  script:
    - gitleaks detect -c gitleaks.toml --source . --no-git --verbose --redact=0 --exit-code=0

# --- Deploy jobs ---
alpha-dev:
  extends: ".dev_deploy"
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
  extends: ".test_deploy"
  variables:
    VALUES_FILE: ".gitlab/alpha-test.yaml"
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
  environment:
    name: alpha-test

# --- Prevent default production job ---
production:
  stage: production
  script:
    - echo "Skipping production deployment"
  rules:
    - when: never

# --- Global variables at the bottom ---
variables:
  BASE_PATH: "/my-service"
  OPENAPI_PATH: "/deployments/generated/openapi.yaml"
  COVERAGE_AWK_PATTERN: "mn[.\\/]and[.\\/]myservice[.\\/]service"
  BUILD_AUDIT_LOG_BACKEND: "amqp"
```

Key details about this pattern:

- **`build` is disabled** — the template's `build` job would trigger on any branch push. We disable it and define per-environment builds with explicit tags and `BUILD_*` overrides.
- **Each build gets a distinct tag** — `-dev`, `-sit`, `-test` suffixes so deploy jobs pull the correct image.
- **No `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS`** in the project — the template handles the Docker build arg mapping. Projects only set `BUILD_*` variables.
- **MR jobs** (`prepare-maven-deps`, `unit-test`, `code-style`, `sonarqube-check`) come from the template automatically — no need to redefine them.
- **`COVERAGE_AWK_PATTERN`** scopes JaCoCo coverage regex to your service's packages.

### Quarkus Dockerfile pattern (canonical — `Dockerfile` in repo root)

This is the gold-standard Dockerfile with POM-first layer caching and clear `BUILD_*` args:

```dockerfile
# Stage 1 : build with maven builder image with native capabilities
FROM quay.io/quarkus/ubi-quarkus-mandrel-builder-image:jdk-21 AS build

ENV MAVEN_CLI_OPTS='-s /opt/app/.m2/settings.xml --batch-mode'
ARG BUILD_OTEL_ENABLED=false
ARG BUILD_OTEL_TRACES_ENABLED=false
ARG BUILD_OTEL_METRICS_ENABLED=false
ARG BUILD_OTEL_METRICS_EXPORTER="cdi"
ARG BUILD_OTEL_TRACES_EXPORTER="cdi"
ARG BUILD_AUDIT_LOG_BACKEND=amqp

# Copy only the POM file first to cache dependencies
COPY --chown=1001 mvnw /opt/app/mvnw
COPY .mvn /opt/app/.mvn
COPY .m2/settings.xml /opt/app/.m2/
COPY pom.xml /opt/app/
WORKDIR /opt/app

# Debug output (helpful)
RUN echo "=== Docker Build Args ===" && \
    echo "BUILD_OTEL_ENABLED = ${BUILD_OTEL_ENABLED}" && \
    echo "BUILD_AUDIT_LOG_BACKEND = ${BUILD_AUDIT_LOG_BACKEND}" && \
    echo "========================="

# Download dependencies. This layer will be cached unless pom.xml changes
RUN chmod +x mvnw && \
  ./mvnw $MAVEN_CLI_OPTS dependency:go-offline

# Copy the rest of the application and build
COPY src /opt/app/src
RUN ./mvnw $MAVEN_CLI_OPTS clean package -DskipTests \
  -DOTEL_ENABLED=${BUILD_OTEL_ENABLED} \
  -DOTEL_TRACES_ENABLED=${BUILD_OTEL_TRACES_ENABLED} \
  -DOTEL_METRICS_ENABLED=${BUILD_OTEL_METRICS_ENABLED} \
  -DOTEL_METRICS_EXPORTER=${BUILD_OTEL_METRICS_EXPORTER} \
  -DOTEL_TRACES_EXPORTER=${BUILD_OTEL_TRACES_EXPORTER} \
  -DAUDIT_LOG_BACKEND=${BUILD_AUDIT_LOG_BACKEND}

# Stage 2: Create the docker final image
FROM registry.access.redhat.com/ubi8/openjdk-21:1.20

ENV LANGUAGE='en_US:en'

# We make four distinct layers so if there are application changes
# the library layers can be re-used
COPY --from=build  --chown=185 opt/app/target/quarkus-app/lib/ /deployments/lib/
COPY --from=build  --chown=185 opt/app/target/quarkus-app/*.jar /deployments/
COPY --from=build  --chown=185 opt/app/target/quarkus-app/app/ /deployments/app/
COPY --from=build  --chown=185 opt/app/target/quarkus-app/quarkus/ /deployments/quarkus/
COPY --from=build --chown=185 /opt/app/target/generated/openapi.yaml /deployments/generated/openapi.yaml

EXPOSE 8080
USER 185
ENV JAVA_OPTS_APPEND="-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager"
ENV JAVA_APP_JAR="/deployments/quarkus-run.jar"

ENTRYPOINT [ "/opt/jboss/container/java/run/run-java.sh" ]
```

Key Dockerfile practices:

- **POM-first copy** — `pom.xml`, `mvnw`, `.m2/settings.xml` copied before `src/`. The `dependency:go-offline` layer only invalidates when POM or settings change.
- **`ARG` names match `BUILD_*` variables** — the CI template passes `--build-arg BUILD_AUDIT_LOG_BACKEND=${BUILD_AUDIT_LOG_BACKEND}` which maps directly to `ARG BUILD_AUDIT_LOG_BACKEND=...` in the Dockerfile.
- **Debug echo** at build time so pipeline traces show the effective args.
- **Four distinct runtime layers** — `lib/`, `*.jar`, `app/`, `quarkus/` so library layers cache across app changes.
- **OpenAPI spec** is copied out of the build stage for the `extract-openapi` job.

### Helm values pattern (`.gitlab/alpha-dev.yaml`)

Canonical Helm values file with health probes, registry pull secrets, and full env configuration:

```yaml
application:
  secretName: "my-service-secret"
  env:
    # Database Configuration
    - name: DB_USER
      value: "app_my_service"
    - name: DB_PASS
      value: "$DB_PASS"
    - name: DB_NAME
      value: "my_service"
    - name: DB_SCHEMA
      value: "my_service"
    - name: DB_HOST
      value: "postgres-alpha-dev-03.postgres.database.azure.com"
    - name: DB_PORT
      value: "6432"
    - name: FLYWAY_MIGRATE_AT_START
      value: "true"
    - name: DB_GENERATION
      value: "none"

    # OTEL Configuration
    - name: OTEL_ENDPOINT
      value: "${OTEL_ENDPOINT}"
    - name: OTEL_EXPORTER_OTLP_HEADERS
      value: "${OTEL_EXPORTER_OTLP_HEADERS}"
    - name: OTEL_DEPLOYMENT_ENVIRONMENT
      value: "${OTEL_DEPLOYMENT_ENVIRONMENT}"
    - name: OTEL_METRICS_ENDPOINT
      value: "${OTEL_METRICS_ENDPOINT}"

    # Logging Configuration
    - name: LOG_LEVEL
      value: "INFO"
    - name: LOG_FILE_ENABLE
      value: "false"

    # Audit Log Configuration
    - name: AUDIT_LOG_SOURCE
      value: "my-service"
    - name: AUDIT_LOG_BACKEND
      value: "amqp"
    - name: AUDIT_LOG_AMQP_HOST
      value: "sb-alpha-dev-02.servicebus.windows.net"
    - name: AUDIT_LOG_AMQP_PORT
      value: "5671"
    - name: AUDIT_LOG_AMQP_USE_SSL
      value: "true"
    - name: AUDIT_LOG_AMQP_VHOST
      value: "sb-alpha-dev-02.servicebus.windows.net"
    - name: AUDIT_LOG_AMQP_ADDRESS
      value: "audit-queue"
    - name: AUDIT_LOG_AMQP_USERNAME
      value: "app_log_mgmt"
    - name: AUDIT_LOG_AMQP_PASSWORD
      value: "$AUDIT_LOG_AMQP_PASSWORD"

    # Scheduler Configuration
    - name: SCHEDULER_ENABLED
      value: "true"

image:
  repository: reg.git.and.global:443/alpha/back-end/my-service/dev
  tag: ${CI_COMMIT_SHA}-dev
  pullPolicy: Always
  secrets:
    - name: gitlab-registry-my-service
  pullSecrets: |
    {
      "auths": {
        "https://reg.git.and.global:443": {
          "username": "gitlab-deploy-token",
          "password": "$GIT_DEPLOY_TOKEN",
          "email": "SRE@andsystems.tech"
        }
      }
    }

service:
  externalPort: 9494
  internalPort: 9494
  url: https://my-service-dev.alpha.looms.cloud

ingress:
  enabled: true
  path: "/"
  className: "nginx"
  tls:
    enabled: true
    secretName: ""
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.org/client-max-body-size: "100m"
    acme.cert-manager.io/http01-edit-in-place: "true"

livenessProbe:
  path: "/q/health/live"
  initialDelaySeconds: 15
  timeoutSeconds: 15
  scheme: "HTTP"
  probeType: "httpGet"
readinessProbe:
  path: "/q/health/live"
  initialDelaySeconds: 5
  timeoutSeconds: 3
  scheme: "HTTP"
  probeType: "httpGet"

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

### SIT values pattern (`.gitlab/alpha-ptf-sit.yaml`)

Differences from dev:

```yaml
application:
  secretName: "my-service-secret"
  env:
    # Database uses internal cluster IP, not Azure
    - name: DB_HOST
      value: "10.5.110.11"
    - name: DB_PORT
      value: "5432"
    # Audit log uses log backend (no Azure Service Bus needed)
    - name: AUDIT_LOG_BACKEND
      value: "log"
    - name: AUDIT_LOG_AMQP_HOST
      value: "rabbitmq.rabbitmq.svc.cluster.local"
    - name: AUDIT_LOG_AMQP_PORT
      value: "5672"
    - name: AUDIT_LOG_AMQP_ADDRESS
      value: "audit-queue"
    - name: AUDIT_LOG_AMQP_USERNAME
      value: "app_notification_service"
    - name: AUDIT_LOG_AMQP_PASSWORD
      value: "$AUDIT_LOG_AMQP_PASSWORD"
    # No OTEL, no SONAR in SIT
    # No ingress in SIT (internal only)
image:
  repository: reg.git.and.global:443/alpha/back-end/my-service/dev
  tag: ${CI_COMMIT_SHA}-sit           # Must match build-sit's CI_APPLICATION_TAG

ingress:
  enabled: false                       # SIT is internal-only
```

### Test values pattern (`.gitlab/alpha-test.yaml`)

Same shape as dev but with test environment endpoints:

```yaml
image:
  repository: reg.git.and.global:443/alpha/back-end/my-service/main  # main branch
  tag: ${CI_COMMIT_SHA}-test           # Must match build-test's CI_APPLICATION_TAG
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

2. **Create `.gitlab-ci.yml`** using the canonical pattern above. Adjust:
   - `BASE_PATH` — URL prefix for the service
   - `OPENAPI_PATH` — where the OpenAPI spec lives in the image
   - `COVERAGE_AWK_PATTERN` — regex for your service's Java package
   - `BUILD_AUDIT_LOG_BACKEND` — the default audit backend for your service
   - Per-environment build jobs (`build-dev`, `build-sit`, `build-test`) — set environment-specific `BUILD_*` variables
   - Deploy jobs (`alpha-dev`, `alpha-sit`, `alpha-test`) — set correct branch rules
   - Add `gitleaks-secret-check` job
   - Add `production` dummy job that `when: never`

3. **Create `.gitlab/alpha-dev.yaml`**, `.gitlab/alpha-ptf-sit.yaml`, `.gitlab/alpha-test.yaml`:
   - Set correct DB credentials, image tag, ports
   - `alpha-dev.yaml`: tag `${CI_COMMIT_SHA}-dev`, `AUDIT_LOG_BACKEND: "amqp"` (or `"azure"`), with OTEL endpoints, ingress, health probes, pull secrets
   - `alpha-ptf-sit.yaml`: tag `${CI_COMMIT_SHA}-sit`, `AUDIT_LOG_BACKEND: "log"`, no ingress, internal DB
   - `alpha-test.yaml`: tag `${CI_COMMIT_SHA}-test`, same shape as dev with test endpoints

4. **Create `gitleaks.toml`** (copy from an existing service).

5. **Create `Dockerfile`** with POM-first layer caching and `BUILD_*` args.

6. **Ensure the `image.repository` path matches** the GitLab project path:
   ```
   reg.git.and.global:443/alpha/back-end/<service-name>/dev
   ```

7. **Push to `dev` branch** and verify pipeline runs:
   - `prepare-maven-deps` succeeds (pulls Maven dependencies into cache)
   - `build-dev` job succeeds (image tagged `${CI_COMMIT_SHA}-dev`)
   - `build-sit` job succeeds (image tagged `${CI_COMMIT_SHA}-sit`)
   - `alpha-dev` deploy job succeeds
   - `alpha-sit` deploy job succeeds
   - `extract-openapi` succeeds (extracts OpenAPI spec from Docker image)

8. **Push to `main`** and verify:
   - `build-test` job succeeds (image tagged `${CI_COMMIT_SHA}-test`)
   - `alpha-test` deploy job succeeds

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

**Fix:** Ensure `alpha-ptf-sit.yaml`'s `tag` matches `build-sit`'s `CI_APPLICATION_TAG`. In the canonical pattern, both use `${CI_COMMIT_SHA}-sit`.

#### Pattern B: Wrong audit log backend at runtime

**Symptoms:**
- `AUDIT_LOG_BACKEND=amqp` errors in SIT (e.g. Azure Service Bus connection failures)
- SIT should use `log` backend but tries to connect to AMQP

**Diagnosis:**
```bash
# Check build-time value (BUILD_AUDIT_LOG_BACKEND in canonical pattern)
glab ci trace <build-sit-job-id> | grep "BUILD_AUDIT_LOG_BACKEND"
# Check runtime value
grep "AUDIT_LOG_BACKEND" .gitlab/alpha-ptf-sit.yaml
```

**Fix:** Both must be consistent. If SIT should use `log`:
- `.gitlab-ci.yml`: set `BUILD_AUDIT_LOG_BACKEND: "log"` on the `build-sit` job (if the image needs to compile a different backend)
- `.gitlab/alpha-ptf-sit.yaml`: set `AUDIT_LOG_BACKEND: "log"` in the env section

#### Pattern C: Build uses wrong OTEL configuration

**Symptoms:**
- Quarkus app fails to start in dev with `cdi` exporter errors
- Dev environment shows OTEL connectivity errors
- OTEL endpoint is expected in SIT but not configured

**Diagnosis:**
```bash
# Check what OTEL args were passed at build time
glab ci trace <build-job-id> | grep "BUILD_OTEL"
# Check what OTEL env vars are set at runtime
grep "OTEL" .gitlab/alpha-dev.yaml
```

**Fix:** Align build args and runtime env vars per environment:
- Dev: `BUILD_OTEL_ENABLED=true`, `BUILD_OTEL_*_EXPORTER=cdi` (no external collector needed) + OTEL helm env vars pointing to collector
- SIT/Test: `BUILD_OTEL_ENABLED=false` or `BUILD_OTEL_*=otlp` with actual collector endpoint

#### Pattern D: `extract-openapi` fails

**Symptoms:**
- `extract-openapi` job fails with image not found
- `extract-openapi` artifact missing

**Diagnosis:**
```bash
glab ci trace <extract-openapi-job-id>
```

**Common causes:**
- Image was tagged with `-dev` suffix but `extract-openapi` uses the base `$CI_COMMIT_SHA` (no suffix). In the canonical pattern with per-environment builds, the `build` job is disabled so no image with the bare `$CI_COMMIT_SHA` tag exists.
- The `extract-openapi` job pulls `$CI_APPLICATION_REPOSITORY:$CI_APPLICATION_TAG` from the dotenv artifact of whichever `build` job ran.

**Fix:** The canonical pattern disables the base `build` job and defines per-environment builds. The `extract-openapi` job runs once per pipeline, reading the dotenv of the last `build` variant that ran. If multiple builds run on the same branch (e.g., `build-dev` and `build-sit` both on `dev`), the dotenv may come from whichever finished last. Ensure all per-environment builds produce the same OpenAPI spec (they should, since OpenAPI is independent of build args).

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

**Fix:** Ensure the tag in the Helm values file exactly matches what the per-environment build job produces. Canonical mapping:
- `build-dev` → `alpha-dev.yaml`: `${CI_COMMIT_SHA}-dev`
- `build-sit` → `alpha-ptf-sit.yaml`: `${CI_COMMIT_SHA}-sit`
- `build-test` → `alpha-test.yaml`: `${CI_COMMIT_SHA}-test`

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

**Fix:** Ensure no `workflow:rules:` block excludes branch pushes. The canonical pattern relies on each job's `rules:` rather than a global workflow rule. If a `workflow:rules:` exists, it must include `$CI_COMMIT_BRANCH == "dev"` and `$CI_COMMIT_BRANCH == "main"`.

#### Pattern G: Per-environment builds have same image

**Symptoms:**
- `build-dev` and `build-sit` produce identical images despite different `BUILD_*` variables expected
- Running `build-dev` trace shows same `BUILD_AUDIT_LOG_BACKEND` as `build-sit`

**Diagnosis:**
```bash
# Check per-job variable overrides
grep -A6 "build-dev:" .gitlab-ci.yml
grep -A6 "build-sit:" .gitlab-ci.yml
```

**Fix:** Ensure each per-environment build job overrides the `BUILD_*` variables it needs to differ. Inheriting the global default silently is the most common bug. In the canonical pattern, all three builds set `BUILD_AUDIT_LOG_BACKEND: "amqp"` explicitly — they don't rely on the global default.

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
- Ensure Dockerfile copies `.m2/settings.xml` into the builder stage (the canonical Dockerfile does this before POM copy)
- Ensure the `mvnw` has `+x` permission in the repo (`COPY --chown=1001 mvnw /opt/app/mvnw`)
- Use `dependency:go-offline` to pre-cache dependencies (the canonical Dockerfile does this)

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
- Registry pull secret missing or wrong — verify `image.secrets` and `image.pullSecrets` in the Helm values

#### Pattern J: `unit-test` / `code-style` / `sonarqube-check` missing from pipeline

**Symptoms:**
- MR pipeline shows only `prepare-maven-deps` and SAST jobs, no test/style/sonar
- MR pipeline is green but no test results

**Diagnosis:**
```bash
# Check if template jobs are disabled via feature flags
grep "UNIT_TEST_DISABLED\|CODE_STYLE_DISABLED\|SONAR_DISABLED" .gitlab-ci.yml
```

**Fix:** The template has feature flags (`UNIT_TEST_DISABLED`, `CODE_STYLE_DISABLED`, `SONAR_DISABLED`) that default to `"false"`. If a project sets any to `"true"`, that job is skipped. Remove or set to `"false"` to re-enable.

---

## Refactoring Existing CI/CD Configs

When a service's `.gitlab-ci.yml` needs to be brought inline with the canonical Quarkus pattern, apply this checklist. The goal is structural consistency so all alpha-backend Quarkus services are maintainable by the same mental model.

### Old pattern → Canonical pattern migration

| Old pattern | Canonical pattern |
|---|---|
| Two includes (`singlec-auto-devops` + `argocd-auto-devops-release`) | Single include (`quarkus-maven-auto-devops.gitlab-ci.yml`) |
| `build-sit` extends `build` with overrides | Base `build` disabled; per-environment builds (`build-dev`, `build-sit`, `build-test`) |
| Bare variable names (`AUDIT_LOG_BACKEND`, `OTEL_ENABLED`) | `BUILD_*` prefix (`BUILD_AUDIT_LOG_BACKEND`, `BUILD_OTEL_ENABLED`) |
| Project defines `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS` | Template handles it; project only sets `BUILD_*` vars |
| Inline `sonarqube-check`, `code-style`, `unit-test` jobs | Provided by template automatically |
| `unit-test` may use `maven:3.9-eclipse-temurin-21` image directly | Template provides Docker-in-Docker services for Testcontainers |
| Simple Helm values (no probes, no pull secrets) | Full Helm values with health probes, pull secrets, registry secrets |

### Refactoring Checklist

Apply these changes in order when bringing a Quarkus `.gitlab-ci.yml` into the canonical pattern:

| # | Change | Why |
|---|---|---|
| 1 | **Replace includes** with single `file: "quarkus-maven-auto-devops.gitlab-ci.yml"` | The quarkus template transitively includes argocd, auto-devops, and SAST. It also provides MR test jobs so you don't need inline ones. |
| 2 | **Remove inline MR test jobs** (`unit-test`, `code-style`, `sonarqube-check`) | These are now provided by the template with proper caching, Docker-in-Docker support, and feature flags. |
| 3 | **Add `COVERAGE_AWK_PATTERN`** to scope coverage regex to your package | The template's `unit-test` job parses JaCoCo CSV and applies the regex. Without it, coverage counts every dependency class. |
| 4 | **Remove `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS`** from project variables | The template defines it globally with `BUILD_*` variable references. If you redefine it, you override the template's mapping and break per-environment builds. |
| 5 | **Rename all build variables** to `BUILD_*` prefix | `AUDIT_LOG_BACKEND` → `BUILD_AUDIT_LOG_BACKEND`, `OTEL_ENABLED` → `BUILD_OTEL_ENABLED`, etc. The Dockerfile `ARG` names must match. |
| 6 | **Disable base `build` job** with `when: never` | The template's `build` job runs on any branch push. In the canonical pattern, only per-environment builds run. |
| 7 | **Replace `build-sit`** with per-environment builds (`build-dev`, `build-sit`, `build-test`) | Each gets its own tag suffix and `BUILD_*` overrides. `build-dev` and `build-sit` both trigger on `dev`; `build-test` triggers on `main`. |
| 8 | **Update deploy jobs** to reference per-environment tags | `alpha-dev.yaml` uses `${CI_COMMIT_SHA}-dev`, `alpha-ptf-sit.yaml` uses `${CI_COMMIT_SHA}-sit`, `alpha-test.yaml` uses `${CI_COMMIT_SHA}-test`. |
| 9 | **Update Dockerfile** to POM-first layer caching with `BUILD_*` args | The old pattern copies everything upfront (no cache benefit). The canonical Dockerfile copies POM first, runs `dependency:go-offline`, then copies src. |
| 10 | **Update Helm values** to include health probes, pull secrets, and registry secrets | Dev Helm values should have ingress, health probes, and pull secrets. SIT should have no ingress. Test should match dev shape with test endpoints. |
| 11 | **Add `MAVEN_SONAR_EXTRA_ARGS`** if Sonar needs extra Maven properties | Instead of adding `-DAUDIT_LOG_BACKEND` inline to a custom sonarqube job, set `MAVEN_SONAR_EXTRA_ARGS: "-DAUDIT_LOG_BACKEND=${BUILD_AUDIT_LOG_BACKEND}"` and let the template handle it. |
| 12 | **Add `MAVEN_TEST_EXTRA_ARGS`** if tests need extra Maven properties | Same pattern: set the variable, let the template inject it. |
| 13 | **Remove explicit `stages:`** if present | Stages come from the template. Defining them locally overrides template stages and can cause ordering issues. |
| 14 | **Remove `workflow:rules:`** if present | The canonical pattern relies on per-job `rules:` rather than a global workflow rule. |
| 15 | **Standardize quote style** | Use double quotes consistently (`"true"` not `'true'`). |

### SIT Helm values checklist

After refactoring `.gitlab-ci.yml`, verify `.gitlab/alpha-ptf-sit.yaml`:

```yaml
    - name: AUDIT_LOG_BACKEND
      value: "log"                         # SIT uses log backend at runtime
image:
  tag: \${CI_COMMIT_SHA}-sit                # Must match build-sit's CI_APPLICATION_TAG
ingress:
  enabled: false                            # SIT is internal-only
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
glab ci get -R alpha/back-end/my-service --pipeline-id 242169
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
glab ci trace <build-job-id> | grep -E "(BUILD_AUDIT_LOG|BUILD_OTEL|build-arg|Docker Build Args|=== Docker Build Args ==="
```

---

## Required Files Checklist Per Service

| File | Quarkus | NestJS |
|---|---|---|
| `.gitlab-ci.yml` | ✅ | ✅ |
| `.gitlab/alpha-dev.yaml` | ✅ | ✅ |
| `.gitlab/alpha-ptf-sit.yaml` | ✅ | ✅ |
| `.gitlab/alpha-test.yaml` | ✅ | ✅ |
| `Dockerfile` (repo root for Quarkus) | ✅ | ❌ |
| `docker/Dockerfile` | optional | ✅ |
| `gitleaks.toml` | ✅ | ✅ |
| `mvnw` | ✅ | ❌ |
| `.mvn/` directory | ✅ | ❌ |
| `.m2/settings.xml` | ✅ | ❌ |
| `pom.xml` | ✅ | ❌ |
| `package.json` | ❌ | ✅ |
| `.npmrc` | ❌ | ✅ |

---

## Key Rules To Remember

1. **Build-time ≠ Runtime.** Docker build args (passed via `BUILD_*` template variables) are independent from Helm values env vars. Both must be set correctly for each environment.

2. **Image tags must match per environment.** The `alpha-ptf-sit.yaml` image tag must equal what `build-sit`'s `CI_APPLICATION_TAG` produces (`${CI_COMMIT_SHA}-sit`).

3. **Quarkus services include only one template.** `quarkus-maven-auto-devops.gitlab-ci.yml` transitively includes `argocd-auto-devops-release.gitlab-ci.yaml` and `Auto-DevOps.gitlab-ci.yml`. Do not include them separately.

4. **Projects do NOT set `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS`.** The template handles the mapping from `BUILD_*` variables to Docker `--build-arg` flags. Overriding it breaks per-environment builds.

5. **`BUILD_*` variable names must match Dockerfile `ARG` names exactly.** The template passes `--build-arg BUILD_AUDIT_LOG_BACKEND=${BUILD_AUDIT_LOG_BACKEND}` and the Dockerfile declares `ARG BUILD_AUDIT_LOG_BACKEND=...`. No mapping layer.

6. **The `extract-openapi` job** pulls the image tag from the dotenv of the last `build` variant that ran. All builds produce the same OpenAPI spec, so this is safe.

7. **`gitleaks.toml` must be in repo root.** CI runs it with `--no-git` flag so the file must be present at the root.

8. **NestJS services** typically don't need per-environment builds since NestJS doesn't have Maven profiles. The same Docker image works for all environments; only runtime env vars differ.

9. **MR test jobs come from the template.** The `quarkus-maven-auto-devops.gitlab-ci.yml` template provides `prepare-maven-deps`, `unit-test`, `code-style`, and `sonarqube-check` for MRs. No need to redefine them. Use `MAVEN_TEST_EXTRA_ARGS`, `MAVEN_SONAR_EXTRA_ARGS` for customization.

10. **Coverage is scoped via `COVERAGE_AWK_PATTERN`.** Set it to a regex matching your service's Java package (e.g., `"mn[.\\/]and[.\\/]myservice[.\\/]service"`) so JaCoCo coverage counts only your code, not dependencies.

11. **When unsure why a build behaves differently than expected**, compare the trace output of `build-dev` vs `build-sit`:
    ```bash
    glab ci trace <build-dev-job-id> | grep -E "(BUILD_AUDIT_LOG|build-arg|Docker Build Args)"
    glab ci trace <build-sit-job-id> | grep -E "(BUILD_AUDIT_LOG|build-arg|Docker Build Args)"
    ```
