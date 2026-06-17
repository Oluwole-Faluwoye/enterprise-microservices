# Runbook 05 - Helm Validation

## Objective

Validate Helm charts before deployment.

Validation ensures Kubernetes manifests can be generated successfully before they are deployed to a cluster.

---

# Why Validate Helm Charts?

Validation helps detect:

* YAML syntax issues
* Missing values
* Invalid templates
* Incorrect references
* Rendering errors

before deployment.

---

# Step 1 - Lint The Chart

Command:

```bash
helm lint helm/auth-service
```

Purpose:

Validate Helm chart structure and syntax.

Expected Output:

```text
1 chart(s) linted, 0 chart(s) failed
```

Verification:

Chart passes validation.

---

# Step 2 - Render Templates

Command:

```bash
helm template auth-service helm/auth-service
```

Purpose:

Render Kubernetes manifests locally.

No deployment occurs.

Expected Resources:

* ServiceAccount
* Service
* Deployment
* HorizontalPodAutoscaler

---

# Step 3 - Verify Image

Expected:

```yaml
image: 761018849945.dkr.ecr.ca-central-1.amazonaws.com/auth-service:v1
```

Purpose:

Confirm deployment uses the correct ECR image.

---

# Step 4 - Verify Resources

Expected:

```yaml
requests:
  cpu: 250m
  memory: 256Mi

limits:
  cpu: 500m
  memory: 512Mi
```

Purpose:

Ensure resource management is configured.

---

# Step 5 - Verify Health Checks

Expected:

```yaml
livenessProbe:
  httpGet:
    path: /health

readinessProbe:
  httpGet:
    path: /health
```

Purpose:

Verify Kubernetes can determine application health.

---

# Verification Checklist

✓ Helm chart lints successfully

✓ Templates render successfully

✓ ECR image configured

✓ Resource limits configured

✓ Health checks configured

✓ HPA configured

---

# Interview Questions

Q: What does helm lint do?

A: Validates chart syntax and structure.

Q: What does helm template do?

A: Renders Kubernetes manifests locally without deploying.

Q: Why validate before deployment?

A: To detect configuration errors before they reach a Kubernetes cluster.

---

# Skills Learned

* Helm Linting
* Template Rendering
* Kubernetes Manifest Validation
* Deployment Verification
