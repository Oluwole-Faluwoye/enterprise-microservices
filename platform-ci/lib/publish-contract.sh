#!/usr/bin/env bash

set -euo pipefail

PLATFORM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

INPUT_FILE="${1:?Usage: publish-contract.sh <contract.json>}"
ARTIFACT_BUCKET="${PLATFORM_ARTIFACT_BUCKET:-}"
PLATFORM_ENV="${PLATFORM_ENV:-dev}"
CONTRACT_KEY="${PLATFORM_CONTRACT_KEY:-platform-contract/${PLATFORM_ENV}/service-contract.json}"

if ! command -v aws >/dev/null 2>&1; then
    echo "ERROR: AWS CLI is required."
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required."
    exit 1
fi

if [[ ! -f "${INPUT_FILE}" ]]; then
    echo "ERROR: Platform contract not found: ${INPUT_FILE}"
    exit 1
fi

if [[ -z "${ARTIFACT_BUCKET}" ]]; then
    echo "ERROR: PLATFORM_ARTIFACT_BUCKET is required."
    exit 1
fi

echo "======================================="
echo "ENTERPRISE PLATFORM"
echo "SERVICE CONTRACT HANDOFF"
echo "======================================="

echo
echo "Contract : ${INPUT_FILE}"
echo "Bucket   : ${ARTIFACT_BUCKET}"
echo "Key      : ${CONTRACT_KEY}"

echo
echo "Validating contract..."
"${PLATFORM_ROOT}/platform-ci/lib/validate-contract.sh" "${INPUT_FILE}"

echo
echo "Publishing developer service contract..."

aws s3 cp \
    "${INPUT_FILE}" \
    "s3://${ARTIFACT_BUCKET}/${CONTRACT_KEY}" \
    --content-type application/json

echo
echo "Verifying uploaded contract syntax..."

aws s3 cp \
    "s3://${ARTIFACT_BUCKET}/${CONTRACT_KEY}" \
    - \
    | jq -e '
        type == "object"
        and .contract_version == "1"
        and (.services | type == "object" and length > 0)
    ' >/dev/null

echo
echo "SERVICE CONTRACT HANDOFF COMPLETE"
echo "Published: s3://${ARTIFACT_BUCKET}/${CONTRACT_KEY}"
