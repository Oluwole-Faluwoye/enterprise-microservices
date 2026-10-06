#!/usr/bin/env bash

set -euo pipefail

SERVICE_DIR="${1:-}"

if [ -z "${SERVICE_DIR}" ]; then
    echo "ERROR: service directory is required."
    exit 1
fi

MANIFEST="${SERVICE_DIR}/platform.yaml"

if [ ! -f "${MANIFEST}" ]; then
    echo "ERROR: Missing platform.yaml: ${MANIFEST}"
    exit 1
fi

RUNTIME=$(yq e -r '.runtime.type // ""' "${MANIFEST}")

echo "======================================="
echo "ENTERPRISE PLATFORM"
echo "RUNTIME CONTRACT VALIDATION"
echo "======================================="

echo "Runtime: ${RUNTIME}"

case "${RUNTIME}" in

    nodejs)

        echo ""
        echo "Running Node.js platform contract..."

        (
            cd "${SERVICE_DIR}"

            npm ci
            npm run test:platform
        )

        ;;

    spring-boot)

        echo ""
        echo "Running Spring Boot platform contract..."

        (
            cd "${SERVICE_DIR}"

            mvn -Dtest=PlatformContractTest test
        )

        ;;

    *)

        echo ""
        echo "ERROR: Unsupported runtime: ${RUNTIME}"
        exit 1

        ;;

esac

echo ""
echo "Runtime contract validated successfully."