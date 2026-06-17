# Runbook 03 - Create Helm Chart

## Objective

Package the Auth Service application for Kubernetes deployment using Helm.

Helm provides reusable, versioned, and configurable deployment templates for Kubernetes.

Without Helm:

* deployment.yaml
* service.yaml
* ingress.yaml

must be maintained manually.

With Helm:

* Templates are reusable.
* Configuration is centralized.
* Upgrades and rollbacks are easier.

---

# Prerequisites

Verify tools:

```bash
helm version

kubectl version --client

docker version
```

Expected:

```text
Helm Installed
kubectl Installed
Docker Installed
```

---

# Step 1 - Navigate To Repository

Command:

```bash
cd enterprise-microservices
```

Purpose:

Move into the microservices repository where application code and Helm charts are stored.

Verify:

```bash
pwd
```

Expected:

```text
.../enterprise-microservices
```

---

# Step 2 - Create Helm Chart

Command:

```bash
helm create auth-service
```

Purpose:

Generate a starter Helm chart for the Auth Service.

Generated Structure:

```text
auth-service/
├── Chart.yaml
├── values.yaml
├── charts/
└── templates/
```

Verify:

```bash
ls auth-service
```

Expected:

```text
Chart.yaml
charts
templates
values.yaml
```

---

# Step 3 - Move Chart Into Helm Directory

Command:

```bash
mv auth-service/* helm/auth-service/
```

Purpose:

Separate Helm deployment artifacts from Java source code.

Verify:

```bash
find helm/auth-service -maxdepth 2
```

Expected:

```text
helm/auth-service
helm/auth-service/Chart.yaml
helm/auth-service/values.yaml
helm/auth-service/templates
```

---

# Step 4 - Update Chart Metadata

Open:

```text
helm/auth-service/Chart.yaml
```

Replace contents with:

```yaml
apiVersion: v2

name: auth-service

description: Enterprise Platform Authentication Service

type: application

version: 1.0.0

appVersion: "1.0.0"
```

Purpose:

Defines chart metadata and application version.

---

# Verification

View file:

```bash
cat helm/auth-service/Chart.yaml
```

Expected:

```yaml
apiVersion: v2
name: auth-service
description: Enterprise Platform Authentication Service
type: application
version: 1.0.0
appVersion: "1.0.0"
```

---

# Interview Questions

Q: What is Helm?

A: Helm is the package manager for Kubernetes used to package, deploy, upgrade, and manage Kubernetes applications.

Q: What is a Helm Chart?

A: A Helm Chart is a collection of files that describe a related set of Kubernetes resources.

Q: What is Chart.yaml?

A: The metadata file that defines chart name, version, type, and description.

---

# Skills Learned

* Helm
* Chart Creation
* Chart Structure
* Kubernetes Packaging
* Application Versioning
