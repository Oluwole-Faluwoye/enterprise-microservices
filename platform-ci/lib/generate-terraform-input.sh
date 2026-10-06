#!/usr/bin/env bash

set -euo pipefail

PLATFORM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

INPUT_FILE="${1:-${PLATFORM_ROOT}/platform-contract.json}"
OUTPUT_FILE="${2:-${PLATFORM_ROOT}/terraform-services.auto.tfvars.json}"

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required."
    exit 1
fi

if [ ! -f "${INPUT_FILE}" ]; then
    echo "ERROR: Platform contract not found: ${INPUT_FILE}"
    exit 1
fi

echo "======================================="
echo "ENTERPRISE PLATFORM"
echo "TERRAFORM INPUT GENERATION"
echo "======================================="

echo ""
echo "Input  : ${INPUT_FILE}"
echo "Output : ${OUTPUT_FILE}"

jq empty "${INPUT_FILE}"

echo ""
echo "Generating Terraform service input..."

jq '
{
  services:
    (
      .services
      | with_entries(
          .value = {
            runtime: .value.runtime.type,
            team: .value.team,

            persistence: {
              enabled: .value.persistence.enabled,
              mode: .value.persistence.mode,
              engine: .value.persistence.engine,
              size: .value.persistence.size,
              database_name: .value.persistence.database_name,
              access: .value.persistence.access
            },

            migration: {
              enabled: .value.migration.enabled,
              engine: .value.migration.engine
            }
          }
        )
    )
}
' "${INPUT_FILE}" > "${OUTPUT_FILE}"

echo ""
echo "Generated Terraform input:"

cat "${OUTPUT_FILE}"

echo ""
echo "======================================="
echo "TERRAFORM INPUT GENERATED"
echo "======================================="

echo ""
echo "Services:"
jq -r '.services | keys[]' "${OUTPUT_FILE}"

echo ""
echo "Terraform input generated successfully."
