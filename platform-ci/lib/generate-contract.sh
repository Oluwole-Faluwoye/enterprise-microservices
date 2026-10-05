#!/usr/bin/env bash

set -euo pipefail

PLATFORM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVICES_DIR="${PLATFORM_ROOT}/services"
OUTPUT_FILE="${1:-${PLATFORM_ROOT}/platform-contract.json}"

if ! command -v yq >/dev/null 2>&1; then
    echo "ERROR: yq is required."
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required."
    exit 1
fi

echo "======================================="
echo "ENTERPRISE PLATFORM"
echo "PLATFORM CONTRACT GENERATION"
echo "======================================="

if [ ! -d "${SERVICES_DIR}" ]; then
    echo "ERROR: Services directory not found: ${SERVICES_DIR}"
    exit 1
fi

TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "${TMP_DIR}"
}

trap cleanup EXIT

CONTRACT_COUNT=0

echo ""
echo "Discovering service contracts..."

for MANIFEST in "${SERVICES_DIR}"/*/platform.yaml; do

    [ -f "${MANIFEST}" ] || continue

    SERVICE_DIR="$(dirname "${MANIFEST}")"

    echo ""
    echo "Processing: ${MANIFEST}"

    "${PLATFORM_ROOT}/platform-ci/lib/validate-service.sh" "${SERVICE_DIR}"

    SERVICE_NAME="$(yq e -r '.service.name // ""' "${MANIFEST}")"

    if [ -z "${SERVICE_NAME}" ] || [ "${SERVICE_NAME}" = "null" ]; then
        echo "ERROR: Missing service.name in ${MANIFEST}"
        exit 1
    fi

    if [ -f "${TMP_DIR}/${SERVICE_NAME}.json" ]; then
        echo "ERROR: Duplicate service name: ${SERVICE_NAME}"
        exit 1
    fi

    echo "Normalizing contract..."

    yq e -o=json '.' "${MANIFEST}" > "${TMP_DIR}/${SERVICE_NAME}.raw.json"

    jq '
        {
            runtime: {
                type: .runtime.type,
                version: .runtime.version
            },
            team: .service.team,
            persistence: {
                enabled: (.persistence.enabled // false),
                mode: (.persistence.mode // "none"),
                engine: (.persistence.engine // null),
                size: (.persistence.size // null),
                database_name: (.persistence.database_name // null),
                access: (.persistence.access // null)
            },
            migration: {
                enabled: (.migration.enabled // false),
                engine: (.migration.engine // null)
            }
        }
    ' "${TMP_DIR}/${SERVICE_NAME}.raw.json" \
        > "${TMP_DIR}/${SERVICE_NAME}.json"

    rm -f "${TMP_DIR}/${SERVICE_NAME}.raw.json"

    CONTRACT_COUNT=$((CONTRACT_COUNT + 1))

done

if [ "${CONTRACT_COUNT}" -eq 0 ]; then
    echo "ERROR: No service contracts found."
    exit 1
fi

echo ""
echo "Building normalized platform contract..."

SERVICES_JSON="{}"

for CONTRACT in "${TMP_DIR}"/*.json; do

    SERVICE_NAME="$(basename "${CONTRACT}" .json)"

    SERVICES_JSON="$(
        jq \
            --arg name "${SERVICE_NAME}" \
            --slurpfile service "${CONTRACT}" \
            '. + {($name): $service[0]}' \
            <<< "${SERVICES_JSON}"
    )"

done

jq \
    --arg generated_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg source "enterprise-microservices" \
    '{
        contract_version: "1",
        source: $source,
        generated_at: $generated_at,
        services: .
    }' \
    <<< "${SERVICES_JSON}" > "${OUTPUT_FILE}"

echo ""
echo "======================================="
echo "PLATFORM CONTRACT GENERATED"
echo "======================================="

echo "Services discovered : ${CONTRACT_COUNT}"
echo "Output              : ${OUTPUT_FILE}"

echo ""
echo "Services:"

jq -r '.services | keys[]' "${OUTPUT_FILE}"

echo ""
echo "Contract generated successfully."
