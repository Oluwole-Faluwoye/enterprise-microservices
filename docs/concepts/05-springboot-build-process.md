# Spring Boot Build Process

## Overview

Spring Boot applications are written in Java source code but cannot run directly in production environments.

The source code must first be compiled and packaged into an executable JAR file.

This process is handled by Maven.

---

# Build Flow

Java Source Code
↓
Maven Build
↓
Compiled Classes
↓
JAR Package
↓
Docker Image
↓
Container
↓
Kubernetes Pod

---

# Maven Build Command

```bash
mvn clean package
```

Purpose:

* Removes previous build artifacts
* Compiles source code
* Runs tests
* Packages application into JAR

---

# Build Output

Generated artifact:

```text
target/auth-service-1.0.0.jar
```

This executable JAR contains:

* Application classes
* Dependencies
* Spring Boot runtime

---

# Why This Matters

Containers do not execute Java source code.

Containers execute compiled artifacts.

The JAR file becomes the application payload that is packaged into a Docker image.

---

# Production Pipeline

Developer
↓
Git Push
↓
Jenkins
↓
Maven Build
↓
Docker Build
↓
ECR Push
↓
ArgoCD
↓
EKS Deployment

---

# Interview Question

Q: What does `mvn clean package` do?

A:

It removes previous build artifacts, compiles the application, executes tests, and packages the application into a deployable JAR file.
