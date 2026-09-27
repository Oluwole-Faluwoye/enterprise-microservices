# Auth Service — Flyway Database Migration Documentation

**Service:** `auth-service`
**Technology:** Spring Boot 3.3.1 / Java 17
**Database:** PostgreSQL 16
**Migration Tool:** Flyway Community Edition 10.10.0
**Document Status:** Current Implementation
**Last Updated:** September 19, 2026

---

# 1. Purpose

This document records the implementation, configuration, validation, and architectural decisions for database schema migrations in the Auth Service using Flyway.

The purpose of introducing Flyway is to ensure that database schema changes are:

* Version controlled
* Repeatable and auditable
* Applied automatically
* Executed in a deterministic order
* Associated with the application version/lifecycle
* Suitable for eventual integration into the enterprise platform's reusable service template and GitOps deployment model

This document describes the implementation that has been successfully tested locally.

It should be updated as the Flyway implementation evolves from the current service-level implementation into the platform-managed database migration lifecycle.

---

# 2. Current Implementation Status

The Auth Service currently has a working Flyway integration.

The following has been successfully implemented and verified:

* Flyway dependencies added to the Maven project
* PostgreSQL Flyway database support added
* Flyway migration directory established
* Custom application `DataSource` successfully integrated with Flyway
* Local database credentials supplied through environment variables
* Local PostgreSQL database running in Docker
* Initial schema migration (`V1`) successfully validated
* Second migration (`V2`) successfully detected and applied
* Database schema verified directly using PostgreSQL
* Flyway migration history verified directly in PostgreSQL
* Spring Boot application successfully starts after migrations are applied

Current database migration version:

```text
V2
```

---

# 3. Current Architecture

The current database and migration flow is:

```text
                    Auth Service
                         │
                         │ Spring Boot startup
                         ▼
                 DatabaseConfig
                         │
                         ▼
             DatabaseCredentialProvider
                    /            \
                   /              \
          Local Environment      AWS
          (current test)       (target)
                │                  │
                ▼                  ▼
        Environment Vars     Secrets Manager
                │
                ▼
          PostgreSQL
                │
                ▼
             Flyway
                │
        ┌───────┴────────┐
        │                │
     Validate         Migrate
        │                │
        └───────┬────────┘
                ▼
       Database Schema
                │
                ▼
         Auth Service
```

The current implementation uses environment variables for local credentials.

The AWS credential integration is handled separately by the application's credential-provider abstraction and is intended for the AWS deployment environment.

---

# 4. Database Environment

The local development database is PostgreSQL running in Docker.

Container:

```text
auth-service-postgres
```

Image:

```text
postgres:16
```

Database:

```text
authdb
```

Database user:

```text
authuser
```

Host:

```text
localhost
```

Port:

```text
5432
```

The local database is intentionally isolated from the developer's host PostgreSQL installation.

---

# 5. Flyway Maven Dependencies

Flyway is included in the Auth Service Maven project.

The project uses:

```text
org.flywaydb:flyway-core:10.10.0
org.flywaydb:flyway-database-postgresql:10.10.0
```

The PostgreSQL-specific Flyway module is included because the application uses PostgreSQL.

The PostgreSQL JDBC driver is also included as the database driver used by the application.

---

# 6. Migration Directory

Flyway migrations are stored under:

```text
src/main/resources/db/migration/
```

Current migrations:

```text
src/main/resources/db/migration/
├── V1__initial_auth_schema.sql
└── V2__add_phone_number.sql
```

Flyway automatically discovers migration files in this location.

Migration filenames follow the Flyway versioned migration convention:

```text
V<version>__<description>.sql
```

For example:

```text
V1__initial_auth_schema.sql
V2__add_phone_number.sql
V3__future_change.sql
```

Migration versions must be ordered correctly and migration files that have already been successfully applied should not be modified.

---

# 7. V1 — Initial Auth Schema

Migration:

```text
V1__initial_auth_schema.sql
```

V1 creates the initial Auth Service database schema.

The schema includes:

```text
users
roles
user_roles
sessions
audit_events
```

## Users

The `users` table contains:

* User ID
* Email
* Password hash
* Account status
* Created timestamp
* Updated timestamp
* Last login timestamp

The email field has a unique constraint.

An index exists on user status.

## Roles

The `roles` table contains:

* Role ID
* Role name
* Role description
* Created timestamp

The role name has a unique constraint.

## User Roles

The `user_roles` table establishes the relationship between users and roles.

It uses a composite primary key:

```text
user_id + role_id
```

Foreign keys reference the `users` and `roles` tables.

## Sessions

The `sessions` table stores authentication session information.

It contains:

* Session ID
* User ID
* Token reference
* Expiration time
* Creation time
* Revocation time

## Audit Events

The `audit_events` table provides the initial audit-event persistence structure.

It contains:

* Event ID
* Optional user ID
* Event type
* Resource
* IP address
* JSON metadata
* Creation timestamp

---

# 8. V2 — Add Phone Number

Migration:

```text
V2__add_phone_number.sql
```

The migration adds:

```sql
ALTER TABLE users
ADD COLUMN phone_number VARCHAR(30);
```

The migration was deliberately introduced as a test of incremental schema evolution.

The database initially existed at:

```text
V1
```

After restarting the application with V2 present, Flyway detected the pending migration and automatically upgraded the schema to:

```text
V2
```

---

# 9. Spring Boot Flyway Configuration

Flyway is enabled through Spring Boot configuration.

The application uses:

```yaml
spring:
  flyway:
    enabled: true
    locations: classpath:db/migration
```

This tells Spring Boot to:

1. Enable Flyway
2. Look for migrations in:

```text
classpath:db/migration
```

Because the migration files are stored under:

```text
src/main/resources/db/migration/
```

they are packaged into the application classpath during the Maven build.

---

# 10. Database Configuration

The Auth Service does not rely on a conventional hardcoded `spring.datasource` configuration.

Instead, it uses a custom:

```text
DatabaseConfig
```

The configuration creates a `DataSource` using:

```text
DatabaseCredentialProvider
```

The DataSource uses:

```text
DB_HOST
DB_PORT
DB_NAME
```

for connection information and obtains database credentials from the credential-provider abstraction.

The resulting JDBC connection is:

```text
jdbc:postgresql://localhost:5432/authdb
```

during local development.

This separation is intentional because the application is designed to support different credential sources in different environments.

---

# 11. Credential Flow

## Local Environment

The local environment supplies:

```text
DB_HOST=localhost
DB_PORT=5432
DB_NAME=authdb
DB_USERNAME=authuser
DB_PASSWORD=<local PostgreSQL password>
```

The password must not be committed to Git.

The local PostgreSQL password corresponds to the PostgreSQL `authuser` role used by the local Docker database.

## AWS Environment

The application uses the credential-provider abstraction so that AWS deployments can obtain database credentials from the appropriate AWS secret-management mechanism.

The architecture therefore separates:

```text
Database connection configuration
```

from:

```text
Credential retrieval
```

This allows local development and AWS deployments to use different credential sources without changing the core database configuration.

---

# 12. Local Profile

The application currently has:

```text
application-local.yml
```

with:

```yaml
app:
  database:
    enabled: true
```

The local application can be started with:

```bash
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

The `local` profile selects local environment-specific configuration.

The profile itself does not contain the database password.

The database password is supplied separately through the environment:

```bash
export DB_PASSWORD='...'
```

Therefore:

```text
Spring Profile
     │
     └── selects environment-specific configuration

Environment Variables
     │
     └── provide database connection/credential values
```

These are separate concerns.

---

# 13. Local Startup Procedure

Before starting the application, the local PostgreSQL container must be running.

Expected container:

```text
auth-service-postgres
```

Set the required local database variables:

```bash
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=authdb
export DB_USERNAME=authuser
export DB_PASSWORD='<local PostgreSQL password>'
```

Do not commit these values to source control.

Start the application:

```bash
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

---

# 14. Flyway Startup Lifecycle

When the Auth Service starts, the effective lifecycle is:

```text
Spring Boot starts
       │
       ▼
Application configuration loaded
       │
       ▼
DataSource created
       │
       ▼
PostgreSQL connection established
       │
       ▼
Flyway initializes
       │
       ▼
Flyway discovers migration files
       │
       ▼
Flyway validates migration history
       │
       ▼
Flyway compares local migrations
against database migration history
       │
       ├── No pending migrations
       │       │
       │       ▼
       │   Application continues
       │
       └── Pending migration
               │
               ▼
          Apply migration
               │
               ▼
       Record migration history
               │
               ▼
        Application continues
```

---

# 15. Flyway Migration History

Flyway maintains its migration metadata in:

```text
flyway_schema_history
```

This table records which migrations have been applied.

The following query can be used to inspect migration history:

```sql
SELECT installed_rank,
       version,
       description,
       script,
       success
FROM flyway_schema_history
ORDER BY installed_rank;
```

The verified result after V2 was:

```text
installed_rank | version | description        | script                         | success
---------------+---------+--------------------+--------------------------------+--------
1              | 1       | initial auth schema | V1__initial_auth_schema.sql    | t
2              | 2       | add phone number    | V2__add_phone_number.sql       | t
```

This confirms that both migrations were successfully applied.

---

# 16. Verification Performed

The Flyway implementation was tested in two stages.

## Stage 1 — Existing V1

The application was started with only V1 available.

Flyway reported:

```text
Successfully validated 1 migration
Current version of schema "public": 1
Schema "public" is up to date. No migration necessary.
```

This confirmed:

* Database connectivity worked
* Flyway was active
* V1 was recognized
* Existing migration history was valid
* No unnecessary migration was executed

## Stage 2 — V2

V2 was then added:

```text
V2__add_phone_number.sql
```

The application was restarted.

Flyway reported:

```text
Successfully validated 2 migrations
Current version of schema "public": 1
Migrating schema "public" to version "2 - add phone number"
Successfully applied 1 migration to schema "public", now at version v2
```

This confirmed that Flyway successfully detected and applied a pending migration.

---

# 17. Direct Database Verification

The database was inspected directly using:

```bash
docker exec -it auth-service-postgres psql -U authuser -d authdb
```

The `users` table was inspected using:

```sql
\d users
```

The resulting schema included:

```text
phone_number | character varying(30)
```

This independently confirmed that V2 changed the actual PostgreSQL schema.

The migration history was also queried directly and confirmed:

```text
V1 → success
V2 → success
```

Therefore, the implementation has been verified at both:

1. Application level
2. Database level

---

# 18. Important Design Decisions

## 18.1 Migration files are source controlled

Database schema changes are treated as application source code.

A schema change should therefore be represented by a new migration file and committed to Git.

Example:

```text
V3__add_account_lock_status.sql
```

rather than manually changing the database.

---

## 18.2 Applied migrations should not be modified

Once a migration has successfully reached a shared environment, it should be treated as immutable.

For example, do not modify:

```text
V1__initial_auth_schema.sql
```

after V1 has already been applied.

Instead, create:

```text
V3__correct_previous_schema.sql
```

for a subsequent change.

---

## 18.3 Credentials are not stored in migration files

Migration SQL must not contain passwords, credentials, API keys, or other secrets.

Secrets belong to the credential-management mechanism.

---

## 18.4 Flyway is responsible for schema versioning

Application code should not manually determine whether a schema change has already been applied.

Flyway owns migration ordering and migration history.

---

# 19. What We Deliberately Did Not Implement Yet

The current implementation is intentionally limited to proving the service-level Flyway lifecycle.

The following have **not yet been finalized as platform-wide capabilities**:

* Reusable Flyway configuration in the service template
* Automated database provisioning for arbitrary services
* Platform-wide database migration orchestration
* GitOps-managed migration lifecycle
* Migration Jobs in Kubernetes
* Migration ordering relative to application deployment
* Automated rollback strategy
* Production migration approval workflow
* Database backup/restore automation
* Migration observability and alerting
* Migration failure remediation
* Platform-level migration policy enforcement

These are future architectural concerns.

They should not be considered implemented merely because the Auth Service can currently execute Flyway migrations.

---

# 20. Current State vs Target State

## Current State

```text
Developer
    │
    ▼
Auth Service repository
    │
    ▼
Migration SQL
    │
    ▼
Spring Boot startup
    │
    ▼
Flyway
    │
    ▼
PostgreSQL
```

This implementation has been successfully tested.

## Target Platform State

The enterprise platform is intended to eventually provide a reusable lifecycle similar to:

```text
Developer declares service
        │
        ▼
Reusable service template
        │
        ├── Application configuration
        ├── Database configuration
        ├── Credential integration
        └── Migration capability
                │
                ▼
             GitOps
                │
                ▼
       Deployment lifecycle
                │
                ▼
       Database migration lifecycle
                │
                ▼
             Flyway
                │
                ▼
            Database
                │
                ▼
          Application
```

The exact production orchestration mechanism is still an architectural decision and should be documented once implemented and tested.

---

# 21. Future Platform Integration

The long-term objective is to make database migration capability part of the reusable platform service pattern.

A new service should not require an engineer to manually reconstruct the entire Flyway configuration.

The platform should eventually provide the appropriate defaults for:

* Flyway dependency
* Migration directory
* Migration configuration
* Database connection
* Credential integration
* Deployment configuration
* Observability
* GitOps integration

The service developer should primarily be responsible for the service's schema migration files.

Conceptually:

```text
Platform owns:
    How migrations execute

Service owns:
    What schema changes are required
```

---

# 22. Expected Developer Workflow

Once the reusable platform pattern is implemented, the intended developer workflow should be approximately:

```text
1. Developer changes application data model
            │
            ▼
2. Developer creates new migration
            │
            ▼
3. Migration committed to Git
            │
            ▼
4. CI validates/builds service
            │
            ▼
5. GitOps deployment updated
            │
            ▼
6. Migration lifecycle executes
            │
            ▼
7. Database reaches required schema version
            │
            ▼
8. Application deploys/starts
```

The exact ordering between migration execution and application deployment will be finalized during the platform implementation.

---

# 23. Troubleshooting

## Application reports missing `DB_USERNAME`

Verify:

```bash
env | grep '^DB_' | grep -v DB_PASSWORD
```

Expected:

```text
DB_HOST=localhost
DB_PORT=5432
DB_NAME=authdb
DB_USERNAME=authuser
```

Set the username if necessary:

```bash
export DB_USERNAME=authuser
```

---

## Application cannot connect to PostgreSQL

Verify the Docker container:

```bash
docker ps
```

Expected container:

```text
auth-service-postgres
```

Verify PostgreSQL directly:

```bash
docker exec -it auth-service-postgres psql -U authuser -d authdb
```

---

## Flyway reports the database is already up to date

This is normally expected when all migration files have already been applied.

Example:

```text
Current version of schema "public": 2
Schema "public" is up to date. No migration necessary.
```

This means Flyway has no pending migration.

---

## Flyway reports a migration validation failure

Do not immediately modify an already-applied migration.

First inspect:

```sql
SELECT installed_rank,
       version,
       description,
       script,
       success
FROM flyway_schema_history
ORDER BY installed_rank;
```

Then determine whether the migration file was changed after it was applied.

---

# 24. Useful Commands

## Start Auth Service

```bash
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

## Connect to PostgreSQL

```bash
docker exec -it auth-service-postgres psql -U authuser -d authdb
```

## Show tables

```sql
\dt
```

## Show users table

```sql
\d users
```

## Show Flyway history

```sql
SELECT installed_rank,
       version,
       description,
       script,
       success
FROM flyway_schema_history
ORDER BY installed_rank;
```

## Show Docker database container

```bash
docker ps
```

---

# 25. Security Notes

The following must never be committed to Git:

```text
DB_PASSWORD
Database passwords
AWS secret values
Access keys
Private keys
JWT signing secrets
API credentials
```

Local credentials should remain in the local environment or another appropriate secret mechanism.

Production credentials must be provided through the platform's approved secret-management mechanism.

---

# 26. Architectural Boundary

Flyway is currently an **application-level database migration capability**.

It should not be confused with database provisioning.

These are separate concerns:

```text
Infrastructure
    │
    └── Creates database infrastructure

Application/platform lifecycle
    │
    └── Applies database schema migrations

Application
    │
    └── Uses the resulting schema
```

For example:

```text
Terraform
    ↓
RDS / PostgreSQL infrastructure
    ↓
Database exists
    ↓
Flyway
    ↓
Application schema exists
    ↓
Auth Service
```

This separation should remain clear as the platform evolves.

---

# 27. Change History

## September 19, 2026 — Initial Flyway Implementation

Implemented and verified:

* Flyway Core 10.10.0
* PostgreSQL Flyway support 10.10.0
* Flyway migration configuration
* Local PostgreSQL integration
* Custom DataSource integration
* Local environment credential integration
* V1 initial Auth schema
* V2 phone-number migration
* Flyway validation
* Automatic migration execution
* Direct PostgreSQL schema verification
* Direct Flyway history verification

Verified final local migration state:

```text
V1 — successfully applied
V2 — successfully applied
Current schema version — V2
```

---

# 28. Next Architectural Step

The next implementation phase is to move from:

```text
Auth Service-specific Flyway implementation
```

to:

```text
Reusable enterprise platform database migration capability
```

The next work should focus on:

1. Identifying which Flyway configuration belongs in the reusable service template.
2. Keeping service-specific migration SQL inside each service.
3. Defining how database credentials are injected by the platform.
4. Defining how database provisioning relates to migration execution.
5. Defining the GitOps deployment sequence.
6. Determining the appropriate migration execution mechanism for Kubernetes.
7. Testing the complete lifecycle through the platform.
8. Updating this document with the resulting platform architecture.

Until those steps are implemented and verified, the architecture described in Section 20 as the **Target Platform State** should be treated as the intended design rather than the current implementation.

---

# 29. Final Verified State

As of September 19, 2026:

```text
Auth Service
    │
    ├── Spring Boot 3.3.1
    ├── Java 17
    ├── PostgreSQL 16
    └── Flyway 10.10.0
            │
            ├── V1 applied successfully
            └── V2 applied successfully
```

Database:

```text
authdb
```

Current Flyway schema version:

```text
2
```

Verified schema change:

```text
users.phone_number VARCHAR(30)
```

Verified Flyway history:

```text
V1 → success
V2 → success
```

**Status: Flyway service-level implementation successfully validated.**

This document should be maintained as the implementation evolves into the enterprise platform's reusable database migration architecture.
