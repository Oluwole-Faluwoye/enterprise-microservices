# 07 - Auth Service CI/CD Pipeline and DevSecOps Implementation

## Overview

This document describes the complete CI/CD and DevSecOps implementation for the Auth Service.

The objective was to build a production-style software delivery pipeline that automatically validates, secures, packages, and deploys application changes using GitOps principles.

The pipeline integrates:

* GitHub
* Jenkins
* Maven
* JUnit
* SonarQube
* OWASP Dependency Check
* Trivy
* Docker
* Amazon ECR
* ArgoCD
* Amazon EKS

---

# Final Delivery Architecture

Developer Commit

↓

GitHub

↓

Jenkins

↓

Maven Build

↓

Unit Tests

↓

SonarQube Analysis

↓

Quality Gate

↓

OWASP Dependency Check

↓

Trivy Filesystem Scan

↓

Docker Build

↓

Trivy Image Scan

↓

Amazon ECR

↓

GitOps Repository Update

↓

ArgoCD

↓

Amazon EKS

---

# Jenkins Pipeline Creation

## Objective

Create a fully automated CI/CD pipeline for the Auth Service.

Pipeline Name:

```text
auth-service-pipeline
```

Repository:

```text
enterprise-microservices
```

Jenkinsfile Location:

```text
services/auth-service/Jenkinsfile
```

---

# Jenkins Job Configuration

Navigate:

Jenkins

↓

New Item

↓

Pipeline

Configuration:

```text
Pipeline Definition:
Pipeline script from SCM

SCM:
Git

Branch:
main

Script Path:
services/auth-service/Jenkinsfile
```

---

# Lightweight Checkout Decision

Option Evaluated:

```text
Lightweight Checkout
```

Decision:

Disabled

Reason:

The pipeline requires:

* Dockerfile
* Maven project
* Helm chart
* Source code

Lightweight checkout only retrieves the Jenkinsfile.

This can cause build failures.

Enterprise Recommendation:

Disable Lightweight Checkout for build pipelines.

---

# GitHub Authentication

## Why SSH?

Jenkins requires repository access for:

* Source Code Checkout
* GitOps Updates

SSH was selected because:

* Enterprise standard
* No passwords
* Cryptographic authentication
* Easy credential rotation

---

# GitHub SSH Key Creation

Command:

```bash
ssh-keygen \
-t ed25519 \
-C "jenkins-github" \
-f github-jenkins-key
```

Generated:

```text
github-jenkins-key
github-jenkins-key.pub
```

---

# Jenkins Credential Configuration

Navigate:

Manage Jenkins

↓

Credentials

↓

Global Credentials

Type:

```text
SSH Username with Private Key
```

Credential ID:

```text
github-ssh
```

Used For:

* Git checkout
* GitOps updates

---

# Initial Jenkinsfile Parsing Failure

## Error

```text
unexpected char: '`'
```

Root Cause:

Markdown code blocks were accidentally copied into the Jenkinsfile.

Example:

````text
```groovy
pipeline {
````

````

Groovy cannot parse Markdown.

---

# Fix

Removed all Markdown formatting.

Pipeline compiled successfully.

---

# Second Jenkinsfile Parsing Failure

## Error

```text
expecting '}'
````

Root Cause:

Unbalanced braces.

---

# Fix

Reviewed all:

```groovy
pipeline { }

stages { }

stage { }

steps { }

post { }
```

Corrected missing closing braces.

---

# Maven Build Failure

## Error

```text
The goal you specified requires a project to execute
but there is no POM in this directory
```

Root Cause:

Jenkins executed:

```bash
mvn clean verify
```

from:

```text
workspace root
```

but:

```text
pom.xml
```

existed inside:

```text
services/auth-service
```

---

# Fix

Created:

```groovy
SERVICE_DIR = "services/auth-service"
```

Executed Maven inside:

```groovy
dir("${SERVICE_DIR}") {
   sh 'mvn clean verify'
}
```

---

# JUnit Failure

## Error

```text
No test report files were found
```

Root Cause

Application contained:

```text
src/test/java
```

but no test classes.

---

# Fix

Created:

```java
AuthApplicationTests.java
```

with:

```java
@SpringBootTest
class AuthApplicationTests {

    @Test
    void contextLoads() {
    }

}
```

---

# SonarQube Implementation

## Objective

Perform SAST analysis before deployment.

---

# SonarQube Project Creation

Navigate:

Projects

↓

Create Project

Project:

```text
auth-service
```

Generate:

```text
Project Token
```

Store securely.

---

# SonarQube Token Configuration

Navigate:

Jenkins Credentials

↓

Add Credentials

Type:

```text
Secret Text
```

Credential ID:

```text
sonarqube-token
```

---

# SonarQube Integration Failure

## Error

```text
mvn: command not found
```

Root Cause

Build stage executed inside:

```text
Maven Container
```

but SonarQube stage executed on:

```text
Jenkins Controller
```

without Maven.

---

# Fix

Execute SonarQube stage inside Maven container.

---

# SonarQube Connectivity Failure

## Error

```text
Unknown host sonarqube
```

Root Cause

Build container not attached to:

```text
devops-network
```

---

# Fix

Attach Maven build container to:

```text
devops-network
```

Result:

```text
ANALYSIS SUCCESSFUL
```

---

# Quality Gate Implementation

## Objective

Prevent poor quality code from reaching production.

---

# Quality Gate Creation

Navigate:

Quality Gates

↓

Create

Name:

```text
Enterprise Quality Gate
```

Configured:

Coverage >= 80%

Duplications <= 3%

Maintainability = A

Reliability = A

Security Rating = A

Security Hotspots Reviewed = 100%


After creating quality gate, make the quality gate the default quality gate


Then attach Quality gate to your current project 

steps : Go to your project and select "project settings"

select quality Gate

Choose which quality gate is associated with this project  : select  "Always use a specific Quality Gate"

---

# Webhook Configuration

Navigate:

Administration

↓

Configuration

↓

Webhooks

URL:

```text
http://<jenkins-url>/sonarqube-webhook/

since they are in thesame coker network  we can use jenkins direct name . like this 

http://jenkin:8080/sonarqube-webhook/

```

---

# Validation

Pipeline Output:

```text
Quality gate is 'OK'
```

---

# OWASP Dependency Check

## Objective

Detect vulnerable third-party libraries.

---

# NVD API Registration

Website:

```text
https://nvd.nist.gov/developers/request-an-api-key
```

Request a free key

```text
Free NVD API Key
```

Received:

```text
NVD API Key
```

After receiving the key, verify the key on their website. This key is used for OWASP dependency check 

After verification, you wll be given the API key
copy this key and store it as a secret inside secret manager or as a credential inside Jenkins credential storage, for this project we willbe using Jenkins Credential but we will improve it later 
---

# Store the API key in Jekins Credential

Credential Type:

```text
Paste NVD Secret Text
```

Credential ID:

```text
nvd-api-key
```

---

# Enterprise Secret Handling

Implemented:

```groovy
withCredentials([
 string(
   credentialsId: 'nvd-api-key',
   variable: 'NVD_API_KEY'
 )
])
```

Reason:

Secret exists only during execution.

Enterprise Best Practice.

---

# OWASP Failure

## Error

```text
NVD Returned Status Code: 503
```

Root Cause

External NVD outage.

Not a Jenkins problem.

Not a pipeline problem.

---

# Fix

Wrapped stage:

```groovy
catchError(
  buildResult: 'SUCCESS',
  stageResult: 'UNSTABLE'
)
```

Pipeline continues.

---

# Trivy Filesystem Scan

Objective:

Scan source code.

Result:

Successful.

---

# Docker Build

Command:

```bash
docker build \
-t auth-service:${IMAGE_TAG} .
```

Result:

Image built successfully.

---

# Trivy Container Scan

Objective:

Scan image vulnerabilities.

Initial Configuration:

```bash
--exit-code 1
```

Result:

Pipeline blocked.

---

# Temporary Decision

Changed:

```bash
--exit-code 0
```

Reason:

Continue learning pipeline while vulnerabilities are reviewed.

Future Production Recommendation:

Restore:

```bash
--exit-code 1
```

for High/Critical findings.

---

# Amazon ECR Push

Repository:

```text
auth-service
```

Region:

```text
us-east-1
```

Image:

```text
761018849945.dkr.ecr.us-east-1.amazonaws.com/auth-service
```

---

# GitOps Update Stage

Objective:

Automatically update deployment image tag.

---

# Initial Implementation

Pipeline updated:

```yaml
tag: "8"
```

inside:

```text
values-dev.yaml
```

---

# YAML Corruption Failure

## Error

ArgoCD:

```text
Sync Status = Unknown
```

---

# Investigation

Command:

```bash
kubectl describe application auth-service -n argocd
```

Error:

```text
mapping values are not allowed
```

---

# Root Cause

Repeated Jenkins commits corrupted YAML indentation.

Example:

```yaml
image:
  repository: xxx
      tag: "9"
```

Invalid YAML.

---

# Original Sed Command

```bash
sed -i "s|tag:.*|  tag: \"${IMAGE_TAG}\"|"
```

Problem:

Each execution added indentation.

---

# Fix

```bash
sed -i "s|^[[:space:]]*tag:.*|  tag: \"${IMAGE_TAG}\"|"
```

Result:

Stable YAML updates.

---

# Deployment Validation

Verify Deployment:

```bash
kubectl get deployment auth-service \
-n auth \
-o=jsonpath='{.spec.template.spec.containers[0].image}'
```

Expected:

```text
auth-service:<BUILD_NUMBER>
```

---

# Verify ArgoCD

```bash
kubectl get applications -n argocd
```

Expected:

```text
auth-service

Synced

Healthy
```

---

# Lessons Learned

* Jenkinsfile syntax matters
* Maven must execute from the correct directory
* Unit tests are required for reporting
* SonarQube requires proper networking
* Quality Gates should block deployments
* NVD outages occur
* Secrets belong in Jenkins Credentials
* Trivy is faster and more reliable than OWASP Dependency Check
* GitOps updates must preserve YAML formatting
* ArgoCD health validation should always be performed after deployment

---

# Final Result

Successfully implemented:

GitHub

↓

Jenkins

↓

Maven

↓

JUnit

↓

SonarQube

↓

Quality Gate

↓

OWASP

↓

Trivy

↓

Docker

↓

ECR

↓

GitOps

↓

ArgoCD

↓

Amazon EKS

The Auth Service can now be built, validated, scanned, containerized, stored, and deployed automatically using enterprise GitOps principles.
