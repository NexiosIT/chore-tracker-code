---
id: STD-020
name: "Service README"
version: "1.0.0"
category: general
status: active
last_reviewed: "2026-05-27"
---

# Service README

> Every service repository MUST contain a README.md with clear instructions on how to start the application, including required profiles, environment variables, and prerequisites. A new developer must be able to run the service by following the README alone.

## Motivation

Without a reliable README, onboarding stalls. Developers waste time reverse-engineering startup procedures from config files, Docker Compose definitions, or tribal knowledge. Generated services that ship without run instructions create immediate friction in Phase 6 review. A standard README structure eliminates "works on my machine" handoffs.

## Rules

1. **Every service repository MUST have a `README.md` at the root.** It is a generation artifact — created or updated during the Foundation phase and kept current through subsequent features.

2. **Required sections** (in order):

   | Section | Content |
   |---------|---------|
   | **Overview** | One-paragraph description of what the service does and its role in the system. |
   | **Prerequisites** | Runtime versions (Java, Node, Python), required tools (Docker, Maven, pnpm), and any system-level dependencies. Pin major versions. |
   | **Getting Started** | Step-by-step commands to clone, install dependencies, configure, and start the application for local development. |
   | **Profiles / Environments** | Which profiles or environment modes exist (e.g., `local`, `dev`, `test`, `prod`), what each activates, and which profile to use for local development. Include the exact flag or env var needed (e.g., `--spring.profiles.active=local`, `NODE_ENV=development`). |
   | **Environment Variables** | Table of required and optional env vars with description, example value, and whether a default exists. Secrets get a placeholder, never a real value. |
   | **Running Tests** | Commands to run unit tests, integration tests, and the full suite. |

3. **The Getting Started section MUST be copy-pasteable.** A developer should be able to execute the listed commands in sequence and have a running service. No implicit steps, no "you probably also need to..." footnotes.

4. **Profile documentation MUST specify the default profile** used when none is explicitly set, and MUST explain any profile-specific behavior (e.g., "the `local` profile uses an in-memory H2 database; `dev` connects to the shared PostgreSQL instance").

5. **The README MUST be kept in sync with the codebase.** When a feature adds a new env var, profile, or dependency, the README MUST be updated in the same changeset.

## Examples

### Compliant: Spring Boot service

```markdown
# Order Service

Handles order creation, lifecycle management, and payment integration for the platform.

## Prerequisites

- Java 21+
- Maven 3.9+
- Docker (for local PostgreSQL)

## Getting Started

1. Start the local database:
   ```bash
   docker compose up -d postgres
   ```

2. Run the application with the local profile:
   ```bash
   ./mvnw spring-boot:run -Dspring-boot.run.profiles=local
   ```

   The service starts on `http://localhost:8080`.

## Profiles

| Profile | Purpose | Database | Notes |
|---------|---------|----------|-------|
| `local` | Local development | H2 in-memory | Default when no profile is set |
| `dev` | Shared dev environment | PostgreSQL (remote) | Requires VPN |
| `test` | CI test runs | H2 in-memory | Used by `mvn test` |
| `prod` | Production | PostgreSQL (RDS) | Never run locally |

**Local development:** use `local` profile via `-Dspring-boot.run.profiles=local`.

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DB_URL` | Yes (dev/prod) | H2 URL (local) | JDBC connection string |
| `DB_USERNAME` | Yes (dev/prod) | `sa` (local) | Database user |
| `DB_PASSWORD` | Yes (dev/prod) | — | Database password |
| `JWT_SECRET` | Yes | — | Token signing key |

## Running Tests

```bash
./mvnw test                    # Unit tests
./mvnw verify                  # Unit + integration tests
```
```

### Non-Compliant

```markdown
# Order Service

Run `mvn spring-boot:run` to start.
```

Problems: no prerequisites, no profile specified, no env vars, no test commands. A new developer has no idea which Java version, which profile, or what database to configure.

## Applicability

- **Service types:** all (backend, frontend, gateway)
- **Domains:** all
- **Exceptions:** Shared libraries and packages that are not independently runnable may omit the Getting Started and Profiles sections but MUST still document prerequisites, installation, and testing.

## References

- STD-003: Naming Conventions (env var naming follows Rule 11)
