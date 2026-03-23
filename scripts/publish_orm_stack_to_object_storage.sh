#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Upload the ORM stack ZIP to OCI Object Storage and optionally emit a Deploy to Oracle Cloud URL.

Usage:
  ./scripts/publish_orm_stack_to_object_storage.sh [stack-zip]

Required environment variables:
  OCI_ORM_STACK_BUCKET        Object Storage bucket name
  OCI_ORM_STACK_NAMESPACE     Object Storage namespace
  OCI_ORM_STACK_REGION        Object Storage region

Optional environment variables:
  OCI_ORM_STACK_OBJECT_NAME   Object key to overwrite. Defaults to code-release/<zip-name>.
  OCI_ORM_STACK_PAR_URL       Long-lived read PAR URL for the object, or a PAR base URL ending in /o/.
  LAUNCH_URL_FILE             Output path for the generated Deploy to Oracle Cloud URL.
  SUMMARY_FILE                Output path for the publish summary.
EOF
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: ${name}" >&2
    usage >&2
    exit 1
  fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK_ZIP="${1:-${STACK_ZIP:-${ROOT_DIR}/output/oci-deploy-mcp-speech-demo-latest.zip}}"

require_env "OCI_ORM_STACK_BUCKET"
require_env "OCI_ORM_STACK_NAMESPACE"
require_env "OCI_ORM_STACK_REGION"

if [[ ! -f "${STACK_ZIP}" ]]; then
  echo "ZIP not found: ${STACK_ZIP}" >&2
  exit 1
fi

OBJECT_NAME="${OCI_ORM_STACK_OBJECT_NAME:-code-release/$(basename "${STACK_ZIP}")}"
LAUNCH_URL_FILE="${LAUNCH_URL_FILE:-${ROOT_DIR}/dist/deploy-to-oracle-cloud-url.txt}"
SUMMARY_FILE="${SUMMARY_FILE:-${ROOT_DIR}/dist/object-storage-publish-summary.txt}"

mkdir -p "$(dirname "${LAUNCH_URL_FILE}")" "$(dirname "${SUMMARY_FILE}")"

oci os object put \
  --namespace-name "${OCI_ORM_STACK_NAMESPACE}" \
  --bucket-name "${OCI_ORM_STACK_BUCKET}" \
  --name "${OBJECT_NAME}" \
  --file "${STACK_ZIP}" \
  --content-type "application/zip" \
  --force \
  --region "${OCI_ORM_STACK_REGION}" \
  >/dev/null

{
  echo "### Object Storage Publish"
  echo
  echo "- ZIP: \`${STACK_ZIP}\`"
  echo "- Bucket: \`${OCI_ORM_STACK_BUCKET}\`"
  echo "- Namespace: \`${OCI_ORM_STACK_NAMESPACE}\`"
  echo "- Region: \`${OCI_ORM_STACK_REGION}\`"
  echo "- Object: \`${OBJECT_NAME}\`"
} > "${SUMMARY_FILE}"

if [[ -n "${OCI_ORM_STACK_PAR_URL:-}" ]]; then
  mapfile -t par_lines < <(
    OCI_ORM_STACK_PAR_URL="${OCI_ORM_STACK_PAR_URL}" \
    OCI_ORM_STACK_OBJECT_NAME="${OBJECT_NAME}" \
      python3 - <<'PY'
import os
import re
import urllib.parse

par_url = os.environ["OCI_ORM_STACK_PAR_URL"].strip()
object_name = os.environ["OCI_ORM_STACK_OBJECT_NAME"].strip()

if re.search(r"/o/?$", par_url):
    direct_url = par_url.rstrip("/") + "/" + urllib.parse.quote(object_name, safe="/")
else:
    direct_url = par_url

launch_url = "https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=" + urllib.parse.quote(direct_url, safe="")
print(direct_url)
print(launch_url)
PY
  )

  PAR_DIRECT_URL="${par_lines[0]}"
  PAR_LAUNCH_URL="${par_lines[1]}"

  curl -fsSI "${PAR_DIRECT_URL}" >/dev/null
  printf '%s\n' "${PAR_LAUNCH_URL}" > "${LAUNCH_URL_FILE}"

  {
    echo "- Launch URL artifact: \`$(basename "${LAUNCH_URL_FILE}")\`"
    echo "- Direct ZIP URL: \`${PAR_DIRECT_URL}\`"
    echo "- PAR verification: succeeded with anonymous HEAD request"
  } >> "${SUMMARY_FILE}"
else
  {
    echo "- Launch URL artifact: skipped"
    echo "- Next step: set \`OCI_ORM_STACK_PAR_URL\` to a long-lived read PAR for the object or the PAR base ending in \`/o/\`"
  } >> "${SUMMARY_FILE}"
fi

cat "${SUMMARY_FILE}"
