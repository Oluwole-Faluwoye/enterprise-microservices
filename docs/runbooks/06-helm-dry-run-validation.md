# Runbook 06 - Helm Dry Run Validation

## Objective

Simulate a Helm deployment before installing resources into Kubernetes.

Dry runs allow engineers to verify:

* Deployment manifests
* Service configuration
* Resource limits
* Image references
* Helm values

without modifying the cluster.

---

# Why Use Dry Run?

Without dry run:

```bash
helm install
```

may fail inside the cluster.

With dry run:

```bash
helm install --dry-run --debug
```

problems are discovered before deployment.

---

# Step 1 - Execute Dry Run

Command:

```bash
helm install auth-service helm/auth-service \
--dry-run --debug
```

Purpose:

Simulate deployment and display all rendered resources.

No resources are created.

---

# Step 2 - Review Computed Values

Verify:

```yaml
image:
  repository: 761018849945.dkr.ecr.ca-central-1.amazonaws.com/auth-service
  tag: v1
```

Purpose:

Confirm Helm is using the expected container image.

---

# Step 3 - Verify Deployment

Expected:

```yaml
kind: Deployment
```

Checks:

* Image URI
* Port 8080
* Resource limits
* Health probes

---

# Step 4 - Verify Service

Expected:

```yaml
kind: Service
```

Checks:

* Service Type
* Service Port
* Target Port

---

# Step 5 - Verify HPA

Expected:

```yaml
kind: HorizontalPodAutoscaler
```

Checks:

* minReplicas
* maxReplicas
* CPU target

---

# Verification Checklist

✓ Helm lint successful

✓ Templates render successfully

✓ Dry run successful

✓ ECR image configured

✓ Service configured

✓ HPA configured

✓ Resource limits configured

---

# Interview Questions

Q: What is the purpose of helm install --dry-run?

A: It simulates installation and validates resources without deploying anything.

Q: Why use --debug?

A: It displays rendered manifests and computed values for troubleshooting.

Q: What should be checked during a dry run?

A: Images, ports, resource limits, probes, autoscaling, and Kubernetes resources.

---

# Skills Learned

* Helm Validation
* Dry Run Deployment
* Kubernetes Manifest Review
* Release Verification
* Production Deployment Preparation
