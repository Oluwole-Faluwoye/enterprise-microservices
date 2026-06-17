# Runbook 01 - Building Auth Service v1

## Objective

Build a simple Spring Boot Auth Service that exposes a health endpoint and can later be containerized and deployed to Kubernetes.

---

# Prerequisites

Verify Java installation:

```bash
java -version
```

Expected:

```text
OpenJDK 17
```

Verify Maven installation:

```bash
mvn -version
```

Expected:

```text
Apache Maven 3.x
Java 17
```

---

# Navigate To Repository

```bash
cd enterprise-microservices
```

---

# Create Enterprise Project Structure

```bash
mkdir -p services/auth-service
mkdir -p services/user-service
mkdir -p services/payment-service
mkdir -p services/document-service
mkdir -p services/notification-service

mkdir -p docs
mkdir -p helm
mkdir -p kubernetes
mkdir -p scripts
```

---

# Verify Structure

Git Bash:

```bash
find . -maxdepth 2 -type d | sort
```

Expected:

```text
.
./docs
./helm
./kubernetes
./scripts
./services
./services/auth-service
./services/document-service
./services/notification-service
./services/payment-service
./services/user-service
```

---

# Enter Auth Service

```bash
cd services/auth-service
```

---

# Create Spring Boot Directory Structure

```bash
mkdir -p src/main/java/com/platform/auth/controller

mkdir -p src/main/java/com/platform/auth

mkdir -p src/main/resources

mkdir -p src/test/java
```

---

# Verify Structure

```bash
find src -type d | sort
```

Expected:

```text
src
src/main
src/main/java
src/main/java/com
src/main/java/com/platform
src/main/java/com/platform/auth
src/main/java/com/platform/auth/controller
src/main/resources
src/test
src/test/java
```

---

# Create pom.xml

Create:

```text
services/auth-service/pom.xml
```

Content:

```xml
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">

    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.3.1</version>
        <relativePath/>
    </parent>

    <groupId>com.platform</groupId>
    <artifactId>auth-service</artifactId>
    <version>1.0.0</version>

    <name>auth-service</name>

    <properties>
        <java.version>17</java.version>
    </properties>

    <dependencies>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>

    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>

</project>
```

---

# Create AuthApplication.java

Create:

```text
src/main/java/com/platform/auth/AuthApplication.java
```

Content:

```java
package com.platform.auth;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class AuthApplication {

    public static void main(String[] args) {
        SpringApplication.run(AuthApplication.class, args);
    }
}
```

---

# Create HealthController.java

Create:

```text
src/main/java/com/platform/auth/controller/HealthController.java
```

Content:

```java
package com.platform.auth.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class HealthController {

    @GetMapping("/health")
    public Map<String, String> health() {

        return Map.of(
                "status", "UP",
                "service", "auth-service"
        );
    }
}
```

---

# Create application.yml

Create:

```text
src/main/resources/application.yml
```

Content:

```yaml
server:
  port: 8080

spring:
  application:
    name: auth-service

management:
  endpoints:
    web:
      exposure:
        include: health,info
```

---

# Build Application

```bash
mvn clean package
```

Expected:

```text
BUILD SUCCESS
```

---

# Verify Build Artifact

```bash
ls target
```

Expected:

```text
auth-service-1.0.0.jar
```

---

# Common Mistakes

## Markdown Backticks In Files

Incorrect:

````text
```java
public class Test {}
````

````

Correct:

```java
public class Test {}
````

Never paste Markdown fences into:

* Java files
* XML files
* YAML files
* Dockerfiles

---

# Skills Learned

* Spring Boot
* Maven
* Java Project Structure
* REST Controllers
* Health Endpoints
* Build Lifecycle
* Artifact Packaging
* Production Build Process

