# Application Configuration, Environment Profiles & Code Quality

## 1. Overview

The Auth Service uses environment-specific configuration and credential providers so that the same application can run across local development and AWS environments without hard-coding environment-specific credential logic into the application.

The design separates:

* **What the application needs** — database credentials
* **How credentials are obtained** — environment variables locally or AWS Secrets Manager in AWS
* **How the application is tested** — focused unit tests
* **How code quality is verified** — JaCoCo coverage and SonarQube quality gates

The overall design is:

```text
                    DatabaseCredentialProvider
                              |
                 +------------+------------+
                 |                         |
              LOCAL                       AWS
                 |                         |
                 v                         v
LocalEnvironmentCredentialProvider   AwsSecretsManagerCredentialProvider
                 |                         |
                 v                         v
        Environment Variables        AWS Secrets Manager
```

---

# 2. Environment Profiles

Spring profiles are used to activate environment-specific components.

## Local Environment

The local credential provider is activated with:

```java
@Component
@Profile("local")
public class LocalEnvironmentCredentialProvider
        implements DatabaseCredentialProvider
```

When the `local` profile is active, database credentials are obtained from:

```text
DB_USERNAME
DB_PASSWORD
```

This allows the service to run locally without requiring AWS Secrets Manager, IAM, EKS, or other AWS infrastructure.

## AWS Environment

In AWS environments, the service uses the AWS Secrets Manager credential provider.

The application therefore does not need to know where the credentials originated. It depends on the common:

```java
DatabaseCredentialProvider
```

interface.

This keeps environment-specific credential retrieval separate from the application's database configuration.

---

# 3. Database Credential Provider Architecture

The service uses an abstraction for database credentials:

```text
DatabaseCredentialProvider
        |
        +-----------------------------+
        |                             |
        v                             v
LocalEnvironmentCredentialProvider    AwsSecretsManagerCredentialProvider
        |                             |
        v                             v
Environment Variables                 AWS Secrets Manager
```

The purpose is to prevent database configuration from containing environment-specific logic such as:

```text
if local:
    read environment variables

if AWS:
    call Secrets Manager
```

Instead, `DatabaseConfig` depends on the abstraction:

```java
DatabaseCredentials credentials =
        credentialProvider.getCredentials();
```

This makes the database configuration independent of the credential source.

---

# 4. Database Configuration

`DatabaseConfig` is responsible for creating the application's `DataSource`.

It resolves:

```text
DB_HOST
DB_PORT
DB_NAME
```

and obtains credentials through:

```java
DatabaseCredentialProvider
```

The resulting flow is:

```text
DatabaseConfig
      |
      v
DatabaseCredentialProvider
      |
      +-----------------------------+
      |                             |
      v                             v
Local provider                 AWS provider
      |                             |
      v                             v
Environment variables        AWS Secrets Manager
```

The database connection configuration and credential retrieval therefore remain separate concerns.

---

# 5. Local Credential Validation

`LocalEnvironmentCredentialProvider` requires:

```text
DB_USERNAME
DB_PASSWORD
```

The provider validates that each value exists and is not blank.

If a required value is missing or blank, it throws:

```java
IllegalStateException
```

This prevents the application from continuing with incomplete local database credentials.

---

# 6. Testability Design

The provider originally accessed the operating-system environment directly through:

```java
System.getenv(name)
```

Direct access makes deterministic unit testing difficult because normal unit tests should not depend on manipulating the JVM's operating-system environment.

A small abstraction was therefore introduced:

```java
@FunctionalInterface
public interface EnvironmentProvider {

    String get(String name);
}
```

Production uses:

```java
System::getenv
```

while tests can provide controlled values.

The production behavior remains unchanged:

```text
Production
    ↓
EnvironmentProvider
    ↓
System.getenv()
```

Tests can instead provide:

```text
Test
    ↓
EnvironmentProvider
    ↓
Controlled test values
```

This improves testability without changing the application's environment/profile architecture.

---

# 7. Unit Testing

A dedicated test class was added:

```text
src/test/java/com/platform/auth/config/
└── LocalEnvironmentCredentialProviderTest.java
```

The tests cover the provider's important execution paths.

| Scenario                    | Expected result         |
| --------------------------- | ----------------------- |
| Username and password exist | Credentials returned    |
| Username missing            | `IllegalStateException` |
| Password missing            | `IllegalStateException` |
| Username blank              | `IllegalStateException` |
| Password blank              | `IllegalStateException` |

The existing Spring Boot context test remains separate:

```text
AuthSeApplicationTests
```

Its purpose is to verify that the application context can start.

The provider unit test has a different responsibility: it verifies the actual credential-resolution behavior.

This separation keeps tests focused.

---

# 8. Code Coverage with JaCoCo

SonarQube previously reported uncovered new code in:

```text
src/main/java/com/platform/auth/config/LocalEnvironmentCredentialProvider.java
```

The provider contained executable logic that the existing test suite did not exercise.

The solution was to add dedicated unit tests rather than weaken the SonarQube quality gate.

JaCoCo was also added to the Maven build so that test execution produces a code-coverage report.

The Maven build now follows this general flow:

```text
mvn clean verify
      |
      +-- Compile
      |
      +-- Run tests
      |
      +-- JaCoCo collects coverage
      |
      +-- Generate coverage report
      |
      v
target/site/jacoco/jacoco.xml
```

The JaCoCo Maven plugin is configured in `pom.xml` with:

```xml
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.8.13</version>

    <executions>
        <execution>
            <id>prepare-agent</id>
            <goals>
                <goal>prepare-agent</goal>
            </goals>
        </execution>

        <execution>
            <id>report</id>
            <phase>verify</phase>
            <goals>
                <goal>report</goal>
            </goals>
        </execution>
    </executions>
</plugin>
```

The important coverage artifact is:

```text
target/site/jacoco/jacoco.xml
```

This allows SonarQube to consume test coverage generated by the standard Maven build.

---

# 9. SonarQube Quality Gate

The Auth Service Jenkins pipeline runs:

```text
Build & Unit Tests
        |
        v
mvn clean verify
        |
        v
SonarQube Analysis
        |
        v
Quality Gate
```

The quality gate is intentionally configured to stop the pipeline when the quality requirements are not met:

```groovy
waitForQualityGate(
    abortPipeline: true
)
```

This means code does not proceed to later deployment-related stages when the quality gate fails.

The preferred approach is to resolve the underlying code-quality or coverage issue rather than bypassing the quality gate.

---

# 10. CI/CD Flow

The application build and quality process is:

```text
Developer changes code
        |
        v
Git
        |
        v
Jenkins
        |
        v
mvn clean verify
        |
        +--> Compile
        |
        +--> Unit Tests
        |
        +--> JaCoCo Coverage
        |
        v
SonarQube Analysis
        |
        v
Quality Gate
        |
        +---- FAILED ----> Stop pipeline
        |
        +---- PASSED ----> Continue
                         |
                         v
                    Later CI/CD stages
```

Coverage generation belongs to the Maven project rather than being implemented as custom Jenkins logic.

This keeps the application build self-contained and allows the same command to work locally and in CI:

```bash
mvn clean verify
```

---

# 11. Validation Performed

The changes were validated locally.

### Complete test suite

```bash
mvn test
```

Result:

```text
Tests run: 6
Failures: 0
Errors: 0
BUILD SUCCESS
```

### Focused provider test

```bash
mvn -Dtest=LocalEnvironmentCredentialProviderTest test
```

Result:

```text
Tests run: 5
Failures: 0
Errors: 0
BUILD SUCCESS
```

### Full Maven verification

```bash
mvn clean verify
```

Result:

```text
Tests run: 6
Failures: 0
Errors: 0
BUILD SUCCESS
```

The application JAR was successfully created and repackaged by Spring Boot.

---

# 12. Design Principles

The current design follows these principles:

1. **Separate application behavior from environment-specific credential retrieval.**
2. **Use Spring profiles to select environment-specific implementations.**
3. **Keep local development independent from AWS infrastructure.**
4. **Use AWS Secrets Manager for AWS database credentials.**
5. **Keep `DatabaseConfig` independent of the credential source.**
6. **Make environment-dependent code testable through small abstractions.**
7. **Test actual application behavior rather than bypassing quality checks.**
8. **Generate code coverage as part of the Maven build.**
9. **Use SonarQube as a quality gate before later CI/CD stages.**
10. **Prefer reusable patterns that can be applied to additional services.**

---

# 13. Related Components

### Production code

```text
src/main/java/com/platform/auth/config/
├── DatabaseConfig.java
├── DatabaseCredentialProvider.java
├── DatabaseCredentials.java
├── EnvironmentProvider.java
├── LocalEnvironmentCredentialProvider.java
└── AwsSecretsManagerCredentialProvider.java
```

### Tests

```text
src/test/java/com/platform/auth/
├── AuthSeApplicationTests.java
└── config/
    └── LocalEnvironmentCredentialProviderTest.java
```

### Build configuration

```text
pom.xml
```

### Coverage output

```text
target/site/jacoco/
└── jacoco.xml
```

---

# 14. Decision Summary

The Auth Service intentionally separates **environment selection**, **credential retrieval**, **database configuration**, **testing**, and **code-quality verification**.

The local profile provides a simple development path using environment variables, while AWS uses managed secrets.

The credential provider abstraction prevents environment-specific logic from leaking into database configuration.

The provider is independently unit tested, and JaCoCo integrates coverage reporting into the Maven lifecycle so the same build can be used locally and by Jenkins.

This establishes a reusable pattern for future services in the platform.
