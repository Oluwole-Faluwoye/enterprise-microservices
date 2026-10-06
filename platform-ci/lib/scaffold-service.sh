#!/usr/bin/env bash

set -euo pipefail

SERVICE_NAME="${1:-}"
RUNTIME="${2:-}"
SERVICE_TEAM="${3:-}"

if [ -z "${SERVICE_NAME}" ]; then
    echo "ERROR: service name is required."
    echo "Usage: platform create-service <service-name> <runtime> <team>"
    exit 1
fi

if [ -z "${RUNTIME}" ]; then
    echo "ERROR: runtime is required."
    echo "Supported runtimes: nodejs, spring-boot"
    exit 1
fi

if [ -z "${SERVICE_TEAM}" ]; then
    echo "ERROR: service team is required."
    echo "Usage: platform create-service <service-name> <runtime> <team>"
    exit 1
fi

if [[ ! "${SERVICE_NAME}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "ERROR: Invalid service name: ${SERVICE_NAME}"
    echo "Use lowercase kebab-case, for example: payments-service"
    exit 1
fi

if [[ ! "${SERVICE_TEAM}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "ERROR: Invalid service team: ${SERVICE_TEAM}"
    exit 1
fi

case "${RUNTIME}" in
    nodejs)
        TEMPLATE_DIR="platform-runtimes/nodejs/service-template"
        RUNTIME_VERSION="22"
        ;;

    spring-boot)
        TEMPLATE_DIR="platform-runtimes/springboot/service-template"
        RUNTIME_VERSION="17"
        ;;

    *)
        echo "ERROR: Unsupported runtime: ${RUNTIME}"
        echo "Supported runtimes: nodejs, spring-boot"
        exit 1
        ;;
esac

SERVICE_DIR="services/${SERVICE_NAME}"

if [ -e "${SERVICE_DIR}" ]; then
    echo "ERROR: Service already exists: ${SERVICE_DIR}"
    exit 1
fi

if [ ! -d "${TEMPLATE_DIR}" ]; then
    echo "ERROR: Runtime template not found: ${TEMPLATE_DIR}"
    exit 1
fi

echo "======================================="
echo "ENTERPRISE PLATFORM"
echo "SERVICE SCAFFOLD"
echo "======================================="

echo ""
echo "Service : ${SERVICE_NAME}"
echo "Team    : ${SERVICE_TEAM}"
echo "Runtime : ${RUNTIME}"
echo "Target  : ${SERVICE_DIR}"

mkdir -p "${SERVICE_DIR}"

echo ""
echo "Copying runtime template..."

cp -R "${TEMPLATE_DIR}/." "${SERVICE_DIR}/"

echo "Removing template build artifacts..."

rm -rf \
    "${SERVICE_DIR}/target" \
    "${SERVICE_DIR}/node_modules"

echo "Creating platform.yaml..."

cat > "${SERVICE_DIR}/platform.yaml" <<EOF2
service:
  name: ${SERVICE_NAME}
  team: ${SERVICE_TEAM}

runtime:
  type: ${RUNTIME}
  version: "${RUNTIME_VERSION}"

persistence:
  enabled: false

migration:
  enabled: false
EOF2

if [ "${RUNTIME}" = "nodejs" ]; then

    echo "Updating Node.js package metadata..."

    node - "${SERVICE_DIR}/package.json" "${SERVICE_NAME}" <<'NODE'
const fs = require("fs");

const file = process.argv[2];
const serviceName = process.argv[3];

const packageJson = JSON.parse(
    fs.readFileSync(file, "utf8")
);

packageJson.name = serviceName;

fs.writeFileSync(
    file,
    JSON.stringify(packageJson, null, 2) + "\n"
);
NODE

fi

echo ""
echo "Service scaffold created successfully."

echo ""
echo "Next steps:"
echo "  ./platform-ci/bin/platform validate ${SERVICE_DIR}"
echo "  ./platform-ci/bin/platform test-runtime ${SERVICE_DIR}"
