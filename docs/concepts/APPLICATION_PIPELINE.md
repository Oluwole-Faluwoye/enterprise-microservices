# Application Pipeline

## Purpose

Builds, scans, containers, and releases applications.

This pipeline does NOT deploy directly to Kubernetes.

Deployment is handled through ArgoCD using GitOps.

---

## Repository

auth-service

---

## Jenkinsfile Location

auth-service/Jenkinsfile

---

## Pipeline Flow

GitHub
↓
Jenkins
↓
Build Application
↓
Unit Tests
↓
SonarQube Analysis
↓
Trivy Scan
↓
Docker Build
↓
Push Image To ECR
↓
Update GitOps Repository
↓
Commit
↓
Push

ArgoCD Detects Change

↓

Deploys To EKS

---

## Security Scanning

### SonarQube

Used for:

- Code Quality
- Code Smells
- Vulnerabilities
- Technical Debt

### Trivy

Used for:

- Container Vulnerability Scanning
- Dependency Scanning
- Security Compliance

---

## GitOps Model

Traditional CI/CD:

Jenkins
↓
kubectl apply
↓
EKS

GitOps:

Jenkins
↓
Push Image
↓
Update GitOps Repository
↓
ArgoCD
↓
EKS

---

## Why ArgoCD

Benefits:

- Declarative Deployments
- Drift Detection
- Automatic Reconciliation
- Rollback Support
- Audit Trail
- Separation of Build and Deploy Responsibilities

---

## Build Containers

Application tooling is executed using ephemeral containers.

Examples:

Node.js Builds:

node:22

Java Builds:

maven:3.9-eclipse-temurin-21

Python Builds:

python:3.12

This keeps the Jenkins Platform Image lightweight and focused on infrastructure tooling.

---

## Outcome

Produces:

Amazon ECR Images

Example:

761018849945.dkr.ecr.us-east-1.amazonaws.com/auth-service:25

and updates the GitOps repository with the new image version.