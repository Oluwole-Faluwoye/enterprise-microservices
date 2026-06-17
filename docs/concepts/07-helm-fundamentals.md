# Helm Fundamentals

## What Is Helm?

Helm is the package manager for Kubernetes.

Think of Helm the same way:

Linux
↓
apt / yum

Java
↓
Maven

Node.js
↓
npm

Kubernetes
↓
Helm

Helm packages Kubernetes resources into reusable deployment artifacts called Charts.

---

# Why Helm Exists

Without Helm:

* Large YAML files
* Repeated configurations
* Difficult upgrades
* Difficult rollbacks

With Helm:

* Templates
* Variables
* Versioning
* Reusable deployments
* Easier upgrades
* Easier rollbacks

---

# Helm Architecture

Chart.yaml
↓
values.yaml
↓
templates/
↓
Rendered Kubernetes Manifests

---

# Helm Chart Structure

auth-service/
├── Chart.yaml
├── values.yaml
├── charts/
└── templates/
├── deployment.yaml
├── service.yaml
├── ingress.yaml
├── hpa.yaml
└── serviceaccount.yaml

---

# Chart.yaml

Purpose:

Stores metadata about the chart.

Example:

```yaml
apiVersion: v2
name: auth-service
description: Enterprise Platform Authentication Service
type: application
version: 1.0.0
appVersion: "1.0.0"
```

---

# values.yaml

Purpose:

Stores configurable values.

Examples:

* Image repository
* Image tag
* Replica count
* Service port
* Resource limits

Instead of hardcoding values inside templates, Helm reads them from values.yaml.

---

# templates/

Purpose:

Contains Kubernetes resource templates.

Examples:

* Deployment
* Service
* Ingress
* HPA
* ServiceAccount

Templates reference values.yaml variables.

Example:

```yaml
image:
  repository: {{ .Values.image.repository }}
```

---

# Helm Workflow

Developer
↓
Update values.yaml
↓
helm install
↓
Helm renders templates
↓
Kubernetes resources created

---

# Common Commands

Verify Helm:

```bash
helm version
```

Create Chart:

```bash
helm create auth-service
```

Render Templates:

```bash
helm template auth-service helm/auth-service
```

Install Chart:

```bash
helm install auth-service helm/auth-service
```

Upgrade Chart:

```bash
helm upgrade auth-service helm/auth-service
```

List Releases:

```bash
helm list
```

Uninstall Release:

```bash
helm uninstall auth-service
```

---

# Helm vs Raw Kubernetes YAML

Without Helm:

deployment.yaml
service.yaml
ingress.yaml

Each file edited manually.

With Helm:

values.yaml
↓
Templates
↓
Generated YAML

More scalable and maintainable.

---

# Skills Learned

* Helm
* Charts
* Templates
* values.yaml
* Kubernetes Package Management
* Release Management
* Configuration Management
