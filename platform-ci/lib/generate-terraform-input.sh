#!/usr/bin/env bash

set -euo pipefail

PLATFORM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

INPUT_FILE="${1:?Usage: generate-terraform-input.sh <contract.json> [output.json]}"
OUTPUT_FILE="${2:-${PLATFORM_ROOT}/terraform-services.auto.tfvars.json}"

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required."
    exit 1
fi

if [[ ! -f "${INPUT_FILE}" ]]; then
    echo "ERROR: Platform contract not found: ${INPUT_FILE}"
    exit 1
fi

echo "======================================="
echo "ENTERPRISE PLATFORM"
echo "TERRAFORM INPUT GENERATION"
echo "======================================="

echo
echo "Input  : ${INPUT_FILE}"
echo "Output : ${OUTPUT_FILE}"

"${PLATFORM_ROOT}/platform-ci/lib/validate-contract.sh" "${INPUT_FILE}"

echo
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

echo
echo "Validating generated Terraform input..."
jq -e '
    type == "object"
    and (.services | type == "object" and length > 0)
' "${OUTPUT_FILE}" >/dev/null

echo "Generated Terraform input:"
cat "${OUTPUT_FILE}"

echo
echo "Services:"
jq -r '.services | keys[]' "${OUTPUT_FILE}"

echo "Terraform input generated successfully."
