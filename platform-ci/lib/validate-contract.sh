#!/usr/bin/env bash

set -euo pipefail

CONTRACT_FILE="${1:?Usage: validate-contract.sh <contract.json>}"

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required."
    exit 1
fi

if [[ ! -f "${CONTRACT_FILE}" ]]; then
    echo "ERROR: Contract file not found: ${CONTRACT_FILE}"
    exit 1
fi

if ! jq -e '
    type == "object"
    and .contract_version == "1"
    and (.source | type == "string" and length > 0)
    and (.services | type == "object" and length > 0)
    and all(
        .services[];
        (.runtime | type == "object")
        and (.runtime.type | type == "string" and length > 0)
        and (.runtime.version | type == "string" and length > 0)
        and (.team | type == "string" and length > 0)
        and (.persistence | type == "object")
        and (.persistence.enabled | type == "boolean")
        and (.persistence.mode | type == "string" and length > 0)
        and (.migration | type == "object")
        and (.migration.enabled | type == "boolean")
    )
' "${CONTRACT_FILE}" >/dev/null; then
    echo "ERROR: Contract schema validation failed: ${CONTRACT_FILE}"
    exit 1
fi

echo "Contract schema validation passed: ${CONTRACT_FILE}"
