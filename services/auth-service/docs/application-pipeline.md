# Enterprise Application CI/CD Pipeline

## Purpose

The application pipeline automates the complete software delivery lifecycle for microservices.

The pipeline validates code quality, performs security scanning, builds container images, publishes artifacts, and updates the GitOps repository.

The pipeline does not deploy directly to Kubernetes.

Deployment ownership belongs to ArgoCD.

---

## Pipeline Flow

Checkout
↓
Build
↓
Unit Tests
↓
SonarQube Analysis
↓
OWASP Dependency Check
↓
Trivy Filesystem Scan
↓
Docker Build
↓
Trivy Container Scan
↓
Push Image To ECR
↓
Update GitOps Repository
↓
ArgoCD Sync
↓
EKS Deployment

---

## Stage Explanations

### Checkout

Retrieves the latest application source code from GitHub.

---

### Build & Unit Tests

Builds the application and executes automated tests.

Purpose:

* Verify compilation
* Validate functionality
* Prevent broken code from progressing

---

### SonarQube Analysis

Performs static code analysis.

Checks:

* Code smells
* Bugs
* Security vulnerabilities
* Technical debt

Purpose:

Improve code quality before deployment.

---

### OWASP Dependency Check

Scans third-party libraries.

Checks:

* Known CVEs
* Vulnerable dependencies

Purpose:

Prevent vulnerable libraries from entering production.

---

### Trivy Filesystem Scan

Scans the application source code and filesystem.

Checks:

* Secrets
* Vulnerabilities
* Misconfigurations

Purpose:

Early security validation.

---

### Docker Build

Builds the application container image.

Output:

Application container image.

---

### Trivy Container Scan

Scans the built container image.

Checks:

* Operating system vulnerabilities
* Package vulnerabilities
* Container misconfigurations

Purpose:

Validate image security before publishing.

---

### Push To ECR

Publishes the approved image to Amazon ECR.

Purpose:

Create a trusted deployment artifact.

---

### Update GitOps Repository

Updates the image tag inside the GitOps repository.

Purpose:

Trigger ArgoCD deployment.

The application pipeline never deploys directly to EKS.

---

## GitOps Design

Jenkins
↓
Build Image
↓
Push ECR
↓
Update GitOps Repo
↓
ArgoCD
↓
Deploy To EKS

Benefits:

* Deployment auditability
* Rollback capability
* Single source of truth
* Declarative deployments

---

## Security Controls

* SonarQube
* OWASP Dependency Check
* Trivy Filesystem Scan
* Trivy Container Scan

These controls shift security left into the CI/CD process.
