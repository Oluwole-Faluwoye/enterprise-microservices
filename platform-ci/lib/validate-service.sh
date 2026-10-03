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

echo "======================================="
echo "ENTERPRISE PLATFORM"
echo "SERVICE CONTRACT VALIDATION"
echo "======================================="

yq e '.' "${MANIFEST}" >/dev/null

SERVICE_NAME=$(yq e -r '.service.name // ""' "${MANIFEST}")
SERVICE_TEAM=$(yq e -r '.service.team // ""' "${MANIFEST}")

SERVICE_RUNTIME=$(yq e -r '.runtime.type // ""' "${MANIFEST}")
RUNTIME_VERSION=$(yq e -r '.runtime.version // ""' "${MANIFEST}")

PERSISTENCE_ENABLED=$(yq e -r '.persistence.enabled // false' "${MANIFEST}")
PERSISTENCE_MODE=$(yq e -r '.persistence.mode // ""' "${MANIFEST}")
PERSISTENCE_ENGINE=$(yq e -r '.persistence.engine // ""' "${MANIFEST}")
PERSISTENCE_SIZE=$(yq e -r '.persistence.size // ""' "${MANIFEST}")
DATABASE_NAME=$(yq e -r '.persistence.database_name // ""' "${MANIFEST}")

MIGRATION_ENABLED=$(yq e -r '.migration.enabled // false' "${MANIFEST}")
MIGRATION_ENGINE=$(yq e -r '.migration.engine // ""' "${MANIFEST}")

echo ""
echo "Checking service identity..."

if [ -z "${SERVICE_NAME}" ]; then
    echo "ERROR: service.name is missing."
    exit 1
fi

if [ -z "${SERVICE_TEAM}" ]; then
    echo "ERROR: service.team is missing."
    exit 1
fi

echo "Checking runtime..."

if [ -z "${SERVICE_RUNTIME}" ]; then
    echo "ERROR: runtime.type is missing."
    exit 1
fi

if [ -z "${RUNTIME_VERSION}" ]; then
    echo "ERROR: runtime.version is missing."
    exit 1
fi

case "${SERVICE_RUNTIME}" in
    nodejs)
        ;;
    spring-boot)
        ;;
    *)
        echo "ERROR: Unsupported runtime: ${SERVICE_RUNTIME}"
        exit 1
        ;;
esac

echo "Checking persistence..."

if [ "${PERSISTENCE_ENABLED}" = "true" ]; then

    case "${PERSISTENCE_MODE}" in
        new|existing|shared|temporary)
            ;;
        *)
            echo "ERROR: Invalid persistence.mode: ${PERSISTENCE_MODE}"
            exit 1
            ;;
    esac

    case "${PERSISTENCE_ENGINE}" in
        postgres|mysql|aurora-postgres|aurora-mysql|mongodb)
            ;;
        *)
            echo "ERROR: Unsupported persistence.engine: ${PERSISTENCE_ENGINE}"
            exit 1
            ;;
    esac

    case "${PERSISTENCE_SIZE}" in
        small|medium|large|xlarge)
            ;;
        *)
            echo "ERROR: Invalid persistence.size: ${PERSISTENCE_SIZE}"
            exit 1
            ;;
    esac

    if [ -z "${DATABASE_NAME}" ]; then
        echo "ERROR: persistence.database_name is required when persistence is enabled."
        exit 1
    fi

fi

echo "Checking migration..."

if [ "${MIGRATION_ENABLED}" = "true" ]; then

    case "${MIGRATION_ENGINE}" in
        flyway)
            ;;
        *)
            echo "ERROR: Unsupported migration.engine: ${MIGRATION_ENGINE}"
            exit 1
            ;;
    esac

    if [ "${PERSISTENCE_ENABLED}" != "true" ]; then
        echo "ERROR: migration is enabled but persistence is disabled."
        exit 1
    fi

fi

echo ""
echo "======================================="
echo "SERVICE CONTRACT"
echo "======================================="

echo "Service name       : ${SERVICE_NAME}"
echo "Team               : ${SERVICE_TEAM}"
echo "Runtime            : ${SERVICE_RUNTIME}"
echo "Runtime version    : ${RUNTIME_VERSION}"
echo "Persistence        : ${PERSISTENCE_ENABLED}"
echo "Database mode      : ${PERSISTENCE_MODE}"
echo "Database engine    : ${PERSISTENCE_ENGINE}"
echo "Database size      : ${PERSISTENCE_SIZE}"
echo "Database name      : ${DATABASE_NAME}"
echo "Migration enabled  : ${MIGRATION_ENABLED}"
echo "Migration engine   : ${MIGRATION_ENGINE}"

echo ""
echo "Service contract validated successfully."