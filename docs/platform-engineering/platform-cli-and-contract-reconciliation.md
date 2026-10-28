# Shared Platform CLI, Contracts, and GitOps Reconciliation

**Updated:** 14 October 2026  
**Repository:** `enterprise-microservices`

## Purpose

This repository now contains the service declarations and shared platform CI tooling. The intent is to let a service describe its platform requirements once and reuse the same validation, contract-generation, and GitOps reconciliation logic across CI pipelines.

## Key components

| Path | Responsibility |
|---|---|
| `services/<service>/platform.yaml` | Developer-owned declaration of service runtime, team, persistence, and migration intent. |
| `platform-ci/lib/generate-contract.sh` | Converts service declarations into the intent contract, `platform-contract.json`. |
| `platform-ci/lib/generate-terraform-input.sh` | Adapts the intent contract into Terraform service inputs. |
| `platform-ci/lib/publish-contract.sh` | Publishes the intent contract to S3 for the selected platform environment. |
| `platform-ci/bin/platform` | Shared command-line entry point for platform workflows, including GitOps reconciliation. |
| `platform-ci/lib/reconcile-gitops.sh` | Shared logic that maps the resolved service contract into the appropriate GitOps Helm values. |
| `platform-ci/Jenkinsfile` | Platform contract pipeline, separate from the auth-service application build pipeline. |
| `services/auth-service/Jenkinsfile` | Auth-service build, checks, image/migration artifact work, and the current dry-run reconciliation stage. |

## Contract lifecycle

### 1. Declare intent

A service's `platform.yaml` is the source of developer intent. It should describe the requested capability, not hard-code environment-specific AWS identifiers.

2. Generate and publish intent

The contract generator produces `platform-contract.json`. Its top-level structure includes `contract_version`, `source`, `generated_at`, and a `services` map. Each service entry captures runtime, team, persistence, and migration settings.

The platform CI pipeline is intended to validate the declaration, generate the contract, adapt it for Terraform, and publish it. This pipeline is separate from the auth-service build pipeline and is not intended to apply Terraform or create EKS infrastructure by itself.

### 3. Consume the resolved contract

The infra pipeline can publish a second artifact, `gitops-service-contract.json`, containing resolved values needed by GitOps. Unlike the intent contract, the resolved output is a direct service-name map, for example `."auth-service"`.

The auth-service pipeline downloads this resolved artifact from:

` s3://<artifact-bucket>/platform-contract/<PLATFORM_ENVIRONMENT>/gitops-service-contract.json `

The bucket is resolved from the GitOps environment configuration in the earlier `Resolve Platform Environment` stage and saved in the workspace as `.artifact_bucket`.

## Reconciliation CLI

Usage:

```bash
./platform-ci/bin/platform reconcile-gitops \
  <resolved-contract.json> \
  <gitops-repository-path> \
  [--dry-run|--write] \
  [--image-tag TAG] \
  [--migration-artifact-key KEY]
```

### Modes and overrides

- **Dry-run:** default. Stages the intended edits, validates the Helm chart/values, and previews the diff without writing the target GitOps files.
- **Write:** writes the reconciled values to the local repository path. It does not create a Git commit, push to a remote, or trigger Argo CD.
- **Image override:** `--image-tag` supplies the current CI build's image tag so the GitOps values match the image built by that pipeline.
- **Migration override:** `--migration-artifact-key` supplies the migration artifact key for that build. It is only passed by the auth-service stage when the resolved contract says migrations are enabled.

The reconciler stages changes before applying them, uses `yq` to update values, and validates the resulting Helm values/chart. The chart shape differs between a service-specific chart and a shared chart, so the implementation handles both value paths.

## Auth-service Jenkinsfile refactor

The former large `Update GitOps Repository` block contained service-specific GitOps update logic. It has been replaced with a smaller stage that delegates mapping to the shared CLI.

Current stage behavior:

1. Uses the `github-ssh` credential to clone the GitOps repository into a temporary directory.
2. Downloads and parses the resolved contract; verifies `auth-service` exists.
3. Reads `auth-service.migration.enabled`.
4. Derives the migration key as `${IMAGE_NAME}/migrations/${GIT_COMMIT}/db/migration`.
5. Runs `platform reconcile-gitops` in `--dry-run` mode, with the image tag and optional migration key.
6. Checks `git status --porcelain` to confirm that dry-run did not change the clone.
7. Removes the temporary directory on exit.

There is intentionally no `git add`, `git commit`, or `git push` in this stage. Although the clone currently uses `sshagent`, the stage is not pushing changes.

The pipeline environment currently includes `AWS_REGION`, `ACCOUNT_ID`, `IMAGE_NAME`, `IMAGE_TAG`, `ECR_REPO`, `MIGRATION_PATH`, `GITOPS_REPO`, `SONARQUBE_ENV`, and `SERVICE_DIR`; `PLATFORM_ENVIRONMENT` is a parameter. The stage also relies on the earlier stage writing `.artifact_bucket` and on the resolved contract artifact having been published.

## Test record

Completed against disposable local fixtures, not live AWS:

- Shared CLI and reconciler passed `bash -n`.
- `git diff --check` passed after whitespace cleanup.
- Dry-run reconciliation passed with a test image tag and migration artifact key; Helm validation passed and no GitOps files were changed.
- Write-mode reconciliation updated a disposable local clone. Re-running in dry-run mode showed no further `NEW` or `UPDATE` entries, confirming idempotency for that fixture.

## Not yet validated

- Jenkins Declarative Pipeline lint.
- An actual run of the refactored auth-service Jenkins pipeline.
- The end-to-end availability and compatibility of the resolved S3 contract in a real infra pipeline run.
- Any write/commit/push to the real GitOps repository from Jenkins.

## Safe next steps

1. Run the Jenkins Declarative Pipeline Linter against this Jenkinsfile.
2. Run a controlled Jenkins build while retaining the dry-run stage.
3. Inspect the console log for successful S3 download, JSON checks, CLI execution, Helm validation, and a clean GitOps working tree.
4. Only after those checks pass, decide separately whether to introduce a guarded write/promotion stage.

Do not reset the working tree: there are existing uncommitted changes in this repository, including `platform-ci/bin/platform`, `platform-ci/lib/reconcile-gitops.sh`, `platform-contract.json`, `terraform-services.auto.tfvars.json`, and `services/payments-service/platform.yaml`.
