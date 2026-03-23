#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-${ROOT_DIR}/output}"
ZIP_NAME="oci-deploy-mcp-speech-demo-latest.zip"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mcp-orm-stack.XXXXXX")"

cleanup() {
  rm -rf "${STAGING_DIR}"
}
trap cleanup EXIT

mkdir -p "${OUTPUT_DIR}" "${STAGING_DIR}/modules"

cp "${ROOT_DIR}"/terraform/*.tf "${STAGING_DIR}/"
rm -f "${STAGING_DIR}/provider.tf"
cp -R "${ROOT_DIR}"/terraform/modules/* "${STAGING_DIR}/modules/"
cp "${ROOT_DIR}/orm/schema.yaml" "${STAGING_DIR}/schema.yaml"
cp "${ROOT_DIR}/orm/provider_orm.tf" "${STAGING_DIR}/provider.tf"

(
  cd "${STAGING_DIR}"
  rm -f "${OUTPUT_DIR}/${ZIP_NAME}"
  zip -rq "${OUTPUT_DIR}/${ZIP_NAME}" .
)

echo "${OUTPUT_DIR}/${ZIP_NAME}"
