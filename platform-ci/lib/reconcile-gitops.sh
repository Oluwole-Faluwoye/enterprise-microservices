
#!/usr/bin/env bash
set -euo pipefail

CONTRACT="${1:-}"
GITOPS_REPO="${2:-}"
MODE="${3:---dry-run}"
IMAGE_TAG_OVERRIDE="${4:-}"
MIGRATION_ARTIFACT_KEY_OVERRIDE="${5:-}"
SERVICE_FILTER="${6:-}"
IMAGE_REPOSITORY_OVERRIDE="${7:-}"
ENVIRONMENT_OVERRIDE="${8:-}"
if [[ -n "$ENVIRONMENT_OVERRIDE" && ! "$ENVIRONMENT_OVERRIDE" =~ ^(dev|staging|prod)$ ]]; then
  echo "ERROR: Environment must be dev, staging, or prod." >&2
  exit 2
fi

usage() {
  echo "Usage: reconcile-gitops.sh <resolved-contract.json> <gitops-repo> [--dry-run|--write] [image-tag] [migration-artifact-key] [service] [image-repository]"
  exit 2
}

[[ -n "$CONTRACT" && -n "$GITOPS_REPO" ]] || usage
[[ "$MODE" == "--dry-run" || "$MODE" == "--write" ]] || usage

if [[ -n "$SERVICE_FILTER" && ! "$SERVICE_FILTER" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "ERROR: Invalid service selector: $SERVICE_FILTER" >&2
  exit 2
fi

if [[ -n "$IMAGE_TAG_OVERRIDE" && ! "$IMAGE_TAG_OVERRIDE" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]]; then
  echo "ERROR: Invalid image tag." >&2
  exit 2
fi

if [[ -n "$IMAGE_REPOSITORY_OVERRIDE" &&
      ! "$IMAGE_REPOSITORY_OVERRIDE" =~ ^[A-Za-z0-9][A-Za-z0-9._:/-]*$ ]]; then
  echo "ERROR: Invalid image repository." >&2
  exit 2
fi

if [[ -n "$MIGRATION_ARTIFACT_KEY_OVERRIDE" ]]; then
  if [[ ! "$MIGRATION_ARTIFACT_KEY_OVERRIDE" =~ ^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$ || "$MIGRATION_ARTIFACT_KEY_OVERRIDE" == *".."* ]]; then
    echo "ERROR: Invalid migration artifact key." >&2
    exit 2
  fi
fi

for tool in jq yq helm diff; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "ERROR: Required tool not found: $tool"
    exit 1
  }
done

[[ -f "$CONTRACT" ]] || {
  echo "ERROR: Contract not found: $CONTRACT"
  exit 1
}

[[ -d "$GITOPS_REPO/charts/service-template" ]] || {
  echo "ERROR: Shared chart not found: $GITOPS_REPO/charts/service-template"
  exit 1
}

jq empty "$CONTRACT"

jq -e '
  (if has("services") then .services else . end)
  | type == "object" and length > 0
' "$CONTRACT" >/dev/null || {
  echo "ERROR: Expected a non-empty service map, optionally under .services."
  exit 1
}

get_value() {
  local path="$1"
  jq -r --arg name "$SERVICE_NAME" --arg path "$path" '
    (if (.services | type) == "object"
     then .services[$name]
     else .[$name]
     end) as $service
    | ($path | split(".")) as $parts
    | (
        if $parts == ["runtime", "type"] and ($service.runtime | type) == "string"
        then $service.runtime
        else ($service | getpath($parts))
        end
      )
    | if . == null then "" else . end
  ' "$CONTRACT"
}

set_string() {
  local path="$1"
  local value="$2"
  local encoded
  encoded="$(jq -Rn --arg value "$value" '$value')"
  yq -i "${path} = ${encoded}" "$VALUES_FILE"
}

set_raw() {
  local path="$1"
  local value="$2"
  yq -i "${path} = ${value}" "$VALUES_FILE"
}

yaml_equal() {
  local left="$1"
  local right="$2"
  local left_json
  local right_json

  left_json="$(yq -o=json '.' "$left" | jq -S -c '.')"
  right_json="$(yq -o=json '.' "$right" | jq -S -c '.')"

  [[ "$left_json" == "$right_json" ]]
}

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/charts" "$STAGE/applications"
cp -R "$GITOPS_REPO/charts/service-template" "$STAGE/charts/"

echo "GitOps reconciliation mode: $MODE"
echo "Contract: $CONTRACT"
echo "Repository: $GITOPS_REPO"

while IFS= read -r SERVICE_NAME || [[ -n "$SERVICE_NAME" ]]; do
  SERVICE_NAME="${SERVICE_NAME%$'\r'}"
  [[ "$SERVICE_NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || {
    echo "ERROR: Unsafe service key: $SERVICE_NAME"
    exit 1
  }

  # The generated contract is keyed by service name.
  # A duplicate service.name field is not required.
  NAMESPACE="$(get_value namespace)"
  TEAM="$(get_value team)"
  # Preserve an existing Application namespace when the contract omits it.
  if [[ -z "$NAMESPACE" && -f "$GITOPS_REPO/applications/$SERVICE_NAME.yaml" ]]; then
    NAMESPACE="$(yq -r '.spec.destination.namespace // ""' "$GITOPS_REPO/applications/$SERVICE_NAME.yaml")"
  fi
  NAMESPACE="${NAMESPACE:-${TEAM:-$SERVICE_NAME}}"
  ENVIRONMENT="$(get_value environment)"
  ENVIRONMENT="${ENVIRONMENT:-dev}"
  VALUES_FILE_NAME="values-${ENVIRONMENT}.yaml"
  if [[ -n "$ENVIRONMENT_OVERRIDE" && "$ENVIRONMENT_OVERRIDE" != "$ENVIRONMENT" ]]; then
    echo "ERROR: Requested environment $ENVIRONMENT_OVERRIDE does not match contract environment $ENVIRONMENT for $SERVICE_NAME." >&2
    exit 2
  fi
  RUNTIME="$(get_value runtime.type)"

  # Accept normalized persistence intent and resolved database details.
  DB_ENABLED="$(get_value database.enabled)"
  [[ -n "$DB_ENABLED" ]] || DB_ENABLED="$(get_value persistence.enabled)"

  DB_ENGINE="$(get_value database.engine)"
  [[ -n "$DB_ENGINE" ]] || DB_ENGINE="$(get_value persistence.engine)"

  DB_HOST="$(get_value database.host)"
  DB_PORT="$(get_value database.port)"

  DB_NAME="$(get_value database.name)"
  [[ -n "$DB_NAME" ]] || DB_NAME="$(get_value persistence.database_name)"

  DB_CREDENTIAL="$(get_value database.credential_reference)"

  SA_NAME="$(get_value workload_identity.service_account_name)"
  SA_ROLE="$(get_value workload_identity.role_arn)"
  SG_ID="$(get_value security_group.id)"

  MIGRATION_ENABLED="$(get_value migration.enabled)"
  MIGRATION_ENGINE="$(get_value migration.engine)"
  MIGRATION_SA="$(get_value migration.service_account_name)"
  MIGRATION_ROLE="$(get_value migration.role_arn)"
  MIGRATION_BUCKET="$(get_value migration.artifact.bucket)"

  [[ -n "$NAMESPACE" && "$NAMESPACE" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] || {
    echo "ERROR: Missing or invalid namespace for $SERVICE_NAME"
    exit 1
  }

  [[ "$DB_ENABLED" == "true" || "$DB_ENABLED" == "false" ]] || {
    echo "ERROR: Invalid database.enabled for $SERVICE_NAME"
    exit 1
  }

  [[ "$MIGRATION_ENABLED" == "true" || "$MIGRATION_ENABLED" == "false" ]] || {
    echo "ERROR: Invalid migration.enabled for $SERVICE_NAME"
    exit 1
  }

  TARGET_CHART="$GITOPS_REPO/charts/$SERVICE_NAME"
  STAGED_CHART="$STAGE/charts/$SERVICE_NAME"
  APP_TARGET="$GITOPS_REPO/applications/$SERVICE_NAME.yaml"
  APP_STAGED="$STAGE/applications/$SERVICE_NAME.yaml"

  echo
  echo "Reconciling $SERVICE_NAME (namespace: $NAMESPACE)"

  if [[ -d "$TARGET_CHART" ]]; then
    cp -R "$TARGET_CHART" "$STAGED_CHART"
  else
    mkdir -p "$STAGED_CHART"
    cat > "$STAGED_CHART/Chart.yaml" <<EOF
apiVersion: v2
name: ${SERVICE_NAME}
description: ${SERVICE_NAME} deployment using the Enterprise Platform service template
type: application
version: 1.0.0
appVersion: "1.0.0"
dependencies:
  - name: service-template
    version: "1.0.0"
    repository: "file://../service-template"
EOF
  fi

  CHART_FILE="$STAGED_CHART/Chart.yaml"
  VALUES_FILE="$STAGED_CHART/$VALUES_FILE_NAME"

  [[ -f "$CHART_FILE" ]] || {
    echo "ERROR: Missing Chart.yaml for $SERVICE_NAME"
    exit 1
  }

  if yq -e '.dependencies[]? | select(.name == "service-template")' \
      "$CHART_FILE" >/dev/null 2>&1; then
    BASE='."service-template"'
    SHARED_CHART=true
  else
    BASE=""
    SHARED_CHART=false
  fi

  if [[ ! -f "$VALUES_FILE" ]]; then
    if [[ "$SHARED_CHART" == "true" ]]; then
      printf 'service-template: {}\n' > "$VALUES_FILE"
    else
      printf '{}\n' > "$VALUES_FILE"
    fi
  elif [[ "$SHARED_CHART" == "true" ]] &&
       yq -e '.service-template == null and .service != null' \
         "$VALUES_FILE" >/dev/null 2>&1; then
    # Migrate flat values into the dependency namespace without dropping keys.
    yq -i '. as $root | {"service-template": $root}' "$VALUES_FILE"
  fi

  # Reconcile platform-owned metadata only for the shared service template.
  # Preserve the existing values schema for legacy service charts.
  if [[ "$SHARED_CHART" == "true" ]]; then
    set_string "${BASE}.global.project" "enterprise-platform"
    set_string "${BASE}.global.environment" "$ENVIRONMENT"
    set_string "${BASE}.service.name" "$SERVICE_NAME"
    [[ -n "$TEAM" ]] && set_string "${BASE}.service.team" "$TEAM"
  fi

  # A dry run may use normalized intent. A write requires resolved details.
  if [[ "$DB_ENABLED" == "true" ]]; then
    if [[ "$MODE" == "--write" ]]; then
      for FIELD in DB_ENGINE DB_HOST DB_PORT DB_NAME DB_CREDENTIAL; do
        if [[ -z "${!FIELD:-}" ]]; then
          echo "ERROR: Database is enabled but resolved $FIELD is missing for $SERVICE_NAME; refusing --write." >&2
          exit 1
        fi
      done
    elif [[ -z "$DB_HOST" || -z "$DB_PORT" || -z "$DB_CREDENTIAL" ]]; then
      echo "  WARNING: Database intent is present, but resolved connection details are incomplete; dry-run only." >&2
    fi

    set_raw "${BASE}.database.enabled" "true"

    [[ -z "$DB_ENGINE" ]] || set_string "${BASE}.database.engine" "$DB_ENGINE"
    [[ -z "$DB_HOST" ]] || set_string "${BASE}.database.host" "$DB_HOST"

    if [[ -n "$DB_PORT" ]]; then
      if [[ ! "$DB_PORT" =~ ^[0-9]+$ ]] || (( 10#$DB_PORT < 1 || 10#$DB_PORT > 65535 )); then
        echo "ERROR: Invalid resolved database port '$DB_PORT' for $SERVICE_NAME." >&2
        exit 1
      fi
      set_raw "${BASE}.database.port" "$DB_PORT"
    fi

    [[ -z "$DB_NAME" ]] || set_string "${BASE}.database.name" "$DB_NAME"
    [[ -z "$DB_CREDENTIAL" ]] || set_string "${BASE}.database.credentialReference" "$DB_CREDENTIAL"

  elif [[ "$DB_ENABLED" == "false" ]]; then
    set_raw "${BASE}.database.enabled" "false"
    # Preserve existing connection details when the database is disabled.
  else
    echo "ERROR: Invalid persistence/database enabled setting for $SERVICE_NAME" >&2
    exit 1
  fi

  # Reconcile workload identity only when resolved values are available.
  if [[ -n "$SA_NAME" ]]; then
    set_raw "${BASE}.serviceAccount.create" "true"
    set_string "${BASE}.serviceAccount.name" "$SA_NAME"
  fi

  if [[ -n "$SA_ROLE" ]]; then
    set_string "${BASE}.serviceAccount.annotations.\"eks.amazonaws.com/role-arn\"" "$SA_ROLE"
  fi

  # Reconcile security-group policy only when the contract has a group ID.
  if [[ -n "$SG_ID" ]]; then
    set_raw "${BASE}.securityGroupPolicy.enabled" "true"
    set_string "${BASE}.securityGroupPolicy.groupId" "$SG_ID"
  fi

  if [[ -n "$MIGRATION_ENGINE" ]]; then
    set_string "${BASE}.migration.engine" "$MIGRATION_ENGINE"
  fi

  if [[ -n "$MIGRATION_BUCKET" ]]; then
    set_string "${BASE}.migration.artifact.bucket" "$MIGRATION_BUCKET"
  fi

  if [[ "$MIGRATION_ENABLED" == "true" || "$MIGRATION_ENABLED" == "false" ]]; then
    set_raw "${BASE}.migration.enabled" "$MIGRATION_ENABLED"
  fi

  if [[ "$MIGRATION_ENABLED" == "true" ]]; then
    if [[ -z "$MIGRATION_ENGINE" ]]; then
      if [[ "$MODE" == "--write" ]]; then
        echo "ERROR: Migration is enabled but engine is missing for $SERVICE_NAME." >&2
        exit 1
      fi
      echo "  WARNING: Migration engine is unresolved; dry-run only." >&2
    fi

    if [[ "$MODE" == "--write" ]]; then
      [[ -n "$MIGRATION_SA" && -n "$MIGRATION_ROLE" ]] || {
        echo "ERROR: Migration is enabled but its resolved identity is incomplete for $SERVICE_NAME; refusing --write." >&2
        exit 1
      }

      [[ -n "$MIGRATION_BUCKET" ]] || {
        echo "ERROR: Migration is enabled but artifact bucket is missing for $SERVICE_NAME; refusing --write." >&2
        exit 1
      }

      [[ -n "$DB_CREDENTIAL" ]] || {
        echo "ERROR: Migration is enabled but database credential reference is missing for $SERVICE_NAME; refusing --write." >&2
        exit 1
      }

    elif [[ -z "$MIGRATION_SA" || -z "$MIGRATION_ROLE" || -z "$MIGRATION_BUCKET" || -z "$DB_CREDENTIAL" ]]; then
      echo "  WARNING: Migration identity, artifact bucket, or database credential is unresolved; dry-run only." >&2
    fi

    [[ -z "$MIGRATION_SA" ]] || set_string "${BASE}.migration.serviceAccount.name" "$MIGRATION_SA"
    [[ -z "$MIGRATION_ROLE" ]] || set_string "${BASE}.migration.serviceAccount.roleArn" "$MIGRATION_ROLE"

    if [[ -n "$DB_CREDENTIAL" ]]; then
      set_string "${BASE}.migration.databaseSecret.name" "$SERVICE_NAME-migration-db"
      set_string "${BASE}.migration.databaseSecret.credentialReference" "$DB_CREDENTIAL"
    fi
  fi

  export SERVICE_NAME
  export APP_CHART_PATH="charts/$SERVICE_NAME"
  export APP_NAMESPACE="$NAMESPACE"
  export VALUES_FILE_NAME

  if [[ -f "$APP_TARGET" ]]; then
    cp "$APP_TARGET" "$APP_STAGED"
    yq -i '.metadata.name = strenv(SERVICE_NAME)' "$APP_STAGED"
    yq -i '.metadata.namespace = "argocd"' "$APP_STAGED"
    yq -i '.spec.source.path = strenv(APP_CHART_PATH)' "$APP_STAGED"
    yq -i '.spec.destination.namespace = strenv(APP_NAMESPACE)' "$APP_STAGED"
    yq -i '.spec.source.helm.valueFiles = [strenv(VALUES_FILE_NAME)]' "$APP_STAGED"
  else
    cat > "$APP_STAGED" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${SERVICE_NAME}
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "8"
spec:
  project: default
  source:
    repoURL: git@github.com:Oluwole-Faluwoye/enterprise-platform-gitops.git
    targetRevision: main
    path: charts/${SERVICE_NAME}
    helm:
      valueFiles:
        - ${VALUES_FILE_NAME}
  destination:
    server: https://kubernetes.default.svc
    namespace: ${NAMESPACE}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
  fi

  # Validate the staged chart and resolve its local dependency.
  if [[ "$SHARED_CHART" == "true" ]]; then
    helm dependency build "$STAGED_CHART" --skip-refresh
  fi

  # Apply build-specific overrides to staged values only.
  if [[ -n "$IMAGE_REPOSITORY_OVERRIDE" ]]; then
    if [[ "$SHARED_CHART" == "true" ]]; then
      IMAGE_REPOSITORY_OVERRIDE="$IMAGE_REPOSITORY_OVERRIDE" yq -i \
        '.["service-template"].image.repository = strenv(IMAGE_REPOSITORY_OVERRIDE)' "$VALUES_FILE"
    else
      IMAGE_REPOSITORY_OVERRIDE="$IMAGE_REPOSITORY_OVERRIDE" yq -i \
        '.image.repository = strenv(IMAGE_REPOSITORY_OVERRIDE)' "$VALUES_FILE"
    fi
  fi

  if [[ -n "$IMAGE_TAG_OVERRIDE" ]]; then
    if [[ "$SHARED_CHART" == "true" ]]; then
      IMAGE_TAG_OVERRIDE="$IMAGE_TAG_OVERRIDE" yq -i \
        '.["service-template"].image.tag = strenv(IMAGE_TAG_OVERRIDE)' "$VALUES_FILE"
    else
      IMAGE_TAG_OVERRIDE="$IMAGE_TAG_OVERRIDE" yq -i \
        '.image.tag = strenv(IMAGE_TAG_OVERRIDE)' "$VALUES_FILE"
    fi
  fi

  
  if [[ "$MIGRATION_ENABLED" == "true" && -n "$MIGRATION_ARTIFACT_KEY_OVERRIDE" ]]; then
    if [[ "$SHARED_CHART" == "true" ]]; then
      MIGRATION_ARTIFACT_KEY_OVERRIDE="$MIGRATION_ARTIFACT_KEY_OVERRIDE" yq -i \
        '.["service-template"].migration.artifact.key = strenv(MIGRATION_ARTIFACT_KEY_OVERRIDE)' "$VALUES_FILE"
    else
      MIGRATION_ARTIFACT_KEY_OVERRIDE="$MIGRATION_ARTIFACT_KEY_OVERRIDE" yq -i \
        '.migration.artifact.key = strenv(MIGRATION_ARTIFACT_KEY_OVERRIDE)' "$VALUES_FILE"
    fi
  fi


  # Shared-template services must have a complete container image reference.
  if [[ "$SHARED_CHART" == "true" ]]; then
    IMAGE_REPOSITORY="$(yq -r '.["service-template"].image.repository // ""' "$VALUES_FILE")"
    IMAGE_TAG="$(yq -r '.["service-template"].image.tag // ""' "$VALUES_FILE")"

    if [[ -z "$IMAGE_REPOSITORY" || -z "$IMAGE_TAG" ]]; then
      echo "ERROR: $SERVICE_NAME has no complete container image configuration." >&2
      echo "Set image.repository and image.tag before reconciling this service." >&2
      exit 1
    fi
  fi

  # Fail writes if enabled Flyway migration would silently omit its Job.
  if [[ "$MIGRATION_ENABLED" == "true" && "$MIGRATION_ENGINE" == "flyway" ]]; then
    if [[ "$SHARED_CHART" == "true" ]]; then
      MIGRATION_ARTIFACT_KEY="$(yq -r \
        '.["service-template"].migration.artifact.key // ""' "$VALUES_FILE")"
    else
      MIGRATION_ARTIFACT_KEY="$(yq -r '.migration.artifact.key // ""' "$VALUES_FILE")"
    fi

    if [[ -z "$MIGRATION_ARTIFACT_KEY" ]]; then
      if [[ "$MODE" == "--write" ]]; then
        echo "ERROR: Flyway migration is enabled for $SERVICE_NAME, but the artifact key is missing; refusing --write." >&2
        echo "Pass --migration-artifact-key or configure it in the chart values." >&2
        exit 1
      fi

      echo "  WARNING: Flyway migration artifact key is missing; migration output cannot be fully validated in this dry run." >&2
    fi
  fi

    # Package the local shared chart dependency without refreshing remote repositories.
  if [[ "$SHARED_CHART" == "true" ]]; then
    SHARED_CHART_SOURCE="$GITOPS_REPO/charts/service-template"
    SHARED_CHART_ARCHIVE="$STAGED_CHART/charts/service-template-1.0.0.tgz"

    if [[ ! -d "$SHARED_CHART_SOURCE" ]]; then
      echo "ERROR: Shared service-template chart not found: $SHARED_CHART_SOURCE" >&2
      exit 1
    fi

    mkdir -p "$STAGED_CHART/charts"

    # Always package the current shared chart so the staged dependency
    # cannot silently remain stale after shared-chart changes.
    rm -f "$SHARED_CHART_ARCHIVE"
    helm package "$SHARED_CHART_SOURCE" \
      --destination "$STAGED_CHART/charts" >/dev/null
  fi

  helm template "$SERVICE_NAME" "$STAGED_CHART" \
    --namespace "$NAMESPACE" \
    -f "$VALUES_FILE" >/dev/null

  echo "  Helm validation: passed"

  # Report planned differences.
  for RELATIVE_FILE in "Chart.yaml" "$VALUES_FILE_NAME"; do
    STAGED_FILE="$STAGED_CHART/$RELATIVE_FILE"
    TARGET_FILE="$TARGET_CHART/$RELATIVE_FILE"

    if [[ ! -f "$TARGET_FILE" ]]; then
      echo "  NEW: charts/$SERVICE_NAME/$RELATIVE_FILE"
      if [[ "$MODE" == "--dry-run" ]]; then
        sed 's/^/    /' "$STAGED_FILE"
      fi
    elif ! yaml_equal "$TARGET_FILE" "$STAGED_FILE"; then
      echo "  UPDATE: charts/$SERVICE_NAME/$RELATIVE_FILE"
      if [[ "$MODE" == "--dry-run" ]]; then
        diff -u "$TARGET_FILE" "$STAGED_FILE" || true
      fi
    fi
  done

  if [[ ! -f "$APP_TARGET" ]]; then
    echo "  NEW: applications/$SERVICE_NAME.yaml"
    if [[ "$MODE" == "--dry-run" ]]; then
      sed 's/^/    /' "$APP_STAGED"
    fi
  elif ! yaml_equal "$APP_TARGET" "$APP_STAGED"; then
    echo "  UPDATE: applications/$SERVICE_NAME.yaml"
    if [[ "$MODE" == "--dry-run" ]]; then
      diff -u "$APP_TARGET" "$APP_STAGED" || true
    fi
  fi

done < <(
  if [[ -n "$SERVICE_FILTER" ]]; then
    jq -er --arg name "$SERVICE_FILTER" '
      (if has("services") then .services else . end)
      | if has($name) then $name
        else error("Selected service not found in contract: " + $name)
        end
    ' "$CONTRACT"
  else
    jq -r 'if has("services") then .services | keys[] else keys[] end' "$CONTRACT"
  fi
)


if [[ "$MODE" == "--write" ]]; then
  echo
  echo "All selected services passed validation. Applying staged files..."

  while IFS= read -r SERVICE_NAME || [[ -n "$SERVICE_NAME" ]]; do
    SERVICE_NAME="${SERVICE_NAME%$'\r'}"

    TARGET_CHART="$GITOPS_REPO/charts/$SERVICE_NAME"
    STAGED_CHART="$STAGE/charts/$SERVICE_NAME"
    APP_TARGET="$GITOPS_REPO/applications/$SERVICE_NAME.yaml"
    APP_STAGED="$STAGE/applications/$SERVICE_NAME.yaml"

    VALUES_FILE_NAME="$(yq -r '.spec.source.helm.valueFiles[0]' "$APP_STAGED")"

    mkdir -p "$TARGET_CHART" "$GITOPS_REPO/applications"
    cp "$STAGED_CHART/$VALUES_FILE_NAME" "$TARGET_CHART/$VALUES_FILE_NAME"

    if [[ ! -f "$TARGET_CHART/Chart.yaml" ]]; then
      cp "$STAGED_CHART/Chart.yaml" "$TARGET_CHART/Chart.yaml"
    fi

    if [[ -f "$STAGED_CHART/charts/service-template-1.0.0.tgz" ]]; then
      mkdir -p "$TARGET_CHART/charts"
      cp "$STAGED_CHART/charts/service-template-1.0.0.tgz" "$TARGET_CHART/charts/"
    fi

    if [[ -f "$STAGED_CHART/Chart.lock" ]]; then
      cp "$STAGED_CHART/Chart.lock" "$TARGET_CHART/Chart.lock"
    fi

    cp "$APP_STAGED" "$APP_TARGET"
    echo "  Local GitOps files written for $SERVICE_NAME."
  done < <(
    if [[ -n "$SERVICE_FILTER" ]]; then
      jq -er --arg name "$SERVICE_FILTER" '
        (if has("services") then .services else . end)
        | if has($name) then $name
          else error("Selected service not found in contract: " + $name)
          end
      ' "$CONTRACT"
    else
      jq -r 'if has("services") then .services | keys[] else keys[] end' "$CONTRACT"
    fi
  )
fi

echo
if [[ "$MODE" == "--dry-run" ]]; then
  echo "DRY RUN COMPLETE. No GitOps files were changed."
  echo "Review the preview before rerunning with --write."
else
  echo "RECONCILIATION COMPLETE. Local files changed; nothing was committed or deployed."
fi
