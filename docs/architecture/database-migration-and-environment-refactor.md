# Database Migration and Environment Refactor

**Repository:** `enterprise-microservices`  
**Service:** `auth-service`  
**Status:** Implemented and end-to-end verified  
**Date:** September 2026

## 1. Purpose

This document extends the existing application configuration/environment-profile/quality documentation with the managed database integration, migration validation, credential-provider refactor, and platform environment abstraction.

The application owns migration SQL and schema evolution. The platform owns infrastructure and migration execution.

## 2. Flyway

The service uses Flyway with:

```text
flyway-core
flyway-database-postgresql
Flyway 10.10.0
```

The migration files are:

```text
V1__initial_auth_schema.sql
V2__add_phone_number.sql
```

## 3. Local PostgreSQL Validation

Local development uses PostgreSQL 16 in Docker. Flyway successfully applied V1 and V2 locally.

Verification confirmed `users.phone_number` exists as `varchar(30)` and Flyway schema history contains V1 and V2.

## 4. Database Configuration Boundary

The application retains its custom `DatabaseConfig` and `DatabaseCredentialProvider` abstraction rather than replacing the design with framework-specific datasource configuration.

The DataSource consumes:

```text
DB_HOST
DB_PORT
DB_NAME
DatabaseCredentialProvider
```

## 5. Credential Provider Abstraction

The application separates credential retrieval from DataSource construction through:

```java
DatabaseCredentialProvider
```

There are two conceptual modes:

```text
local credentials
managed credentials
```

## 6. Local Provider Testability

The local provider originally called `System.getenv()` directly. To make it testable without changing the architecture, an `EnvironmentProvider` functional interface was introduced:

```java
@FunctionalInterface
public interface EnvironmentProvider {
    String get(String name);
}
```

Production uses `System::getenv`; tests inject controlled values.

## 7. Unit Tests and Quality

The local provider gained tests for:

- valid credentials
- missing username
- missing password
- blank username
- blank password

Validation completed with:

```text
6 tests
0 failures
0 errors
```

JaCoCo was added so coverage is produced during `mvn verify`, allowing SonarQube to consume coverage.

The SonarQube quality gate passed after the change.

## 8. Managed Credential Provider Refactor

The managed credential provider originally used:

```java
@Profile("aws")
```

This was changed to capability-based configuration:

```java
@ConditionalOnProperty(
    name = "app.database.credential-provider",
    havingValue = "managed"
)
```

Local configuration uses:

```yaml
app:
  database:
    enabled: true
    credential-provider: local
```

General application configuration uses the managed provider capability.

## 9. Why `aws` Is Not the Environment

The platform environment represents lifecycle context:

```text
dev
staging
prod
```

The cloud provider is an implementation detail.

Using `aws` as a universal Spring profile would mix environment identity with credential/provider implementation. The refactor separates those concepts.

## 10. APP_ENV

The generic GitOps deployment now exposes:

```text
APP_ENV=dev
```

instead of using:

```text
SPRING_PROFILES_ACTIVE=dev
```

Spring profiles remain available for application-local concerns. The platform does not use Spring profiles as its universal environment contract.

## 11. Managed Database Startup

After the refactor, the application pipeline successfully deployed `auth-service` against the platform-provisioned PostgreSQL database.

Application logs showed:

```text
Successfully validated 2 migrations
Current version of schema "public": 2
Schema "public" is up to date. No migration necessary.
```

Tomcat then started and Spring Boot completed startup.

## 12. End-to-End Runtime Path

```text
auth-service Pod
      ↓
EKS workload identity
      ↓
managed credential provider
      ↓
platform database secret
      ↓
PostgreSQL
      ↓
Flyway schema history
      ↓
Spring Boot DataSource
```

This is live runtime validation rather than a Terraform-only plan.

## 13. Ownership Boundary

Application-owned:

- migration SQL
- schemas
- tables
- indexes
- constraints
- application-specific data
- schema evolution

Platform-owned:

- RDS
- networking
- Security Groups
- Secrets Manager
- workload identity
- migration execution
- Kubernetes delivery

## 14. Existing Documentation

The previously created application configuration/environment-profile/quality document remains the focused record for environment profiles, credential-provider architecture, testability, JaCoCo, and SonarQube. This document should be kept as an extension rather than duplicated into another competing document.

## 15. Next Application Direction

The next validation should use a second runtime so that the generic service Golden Path is tested rather than simply deploying another Spring Boot service.
