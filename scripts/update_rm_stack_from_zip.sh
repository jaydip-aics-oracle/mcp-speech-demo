#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Update an existing OCI Resource Manager ZIP stack from the latest local ZIP and run apply with retries.

Required environment variables:
  STACK_ID              Resource Manager stack OCID

Optional environment variables:
  REGION                Stack region. Defaults to the region embedded in STACK_ID.
  STACK_ZIP             ZIP file to upload. Defaults to output/oci-deploy-selfhosted-mcp-oke-latest.zip
  TF_VARS_JSON          JSON file of Terraform variables to apply to the stack during update
  MAX_APPLY_ATTEMPTS    Number of apply retries (default: 5)
  STACK_WAIT_SECONDS    Wait timeout for stack update (default: 1800)
  APPLY_WAIT_SECONDS    Wait timeout for apply job (default: 5400)
  FORCE_REBUILD         When true, always rebuild the ZIP before stack update

Examples:
  STACK_ID=ocid1.ormstack.oc1.us-chicago-1... \
  TF_VARS_JSON=terraform/stack.auto.tfvars.json \
  ./scripts/update_rm_stack_from_zip.sh
EOF
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: ${name}" >&2
    echo >&2
    usage >&2
    exit 1
  fi
}

derive_region_from_stack_id() {
  local stack_id="$1"
  awk -F'.' '{print $4}' <<<"${stack_id}"
}

needs_rebuild() {
  if [[ ! -f "${STACK_ZIP}" ]]; then
    return 0
  fi

  if find "${ROOT_DIR}/terraform" "${ROOT_DIR}/orm" -type f \( -name '*.tf' -o -name 'schema.yaml' -o -name 'provider_orm.tf' \) -newer "${STACK_ZIP}" | grep -q .; then
    return 0
  fi

  return 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_ZIP="${ROOT_DIR}/output/oci-deploy-selfhosted-mcp-oke-latest.zip"

require_env "STACK_ID"

REGION="${REGION:-$(derive_region_from_stack_id "${STACK_ID}")}"
STACK_ZIP="${STACK_ZIP:-${DEFAULT_ZIP}}"
MAX_APPLY_ATTEMPTS="${MAX_APPLY_ATTEMPTS:-5}"
STACK_WAIT_SECONDS="${STACK_WAIT_SECONDS:-1800}"
APPLY_WAIT_SECONDS="${APPLY_WAIT_SECONDS:-5400}"
FORCE_REBUILD="${FORCE_REBUILD:-false}"

if [[ -z "${REGION}" ]]; then
  echo "Unable to determine region. Set REGION explicitly." >&2
  exit 1
fi

if [[ "${FORCE_REBUILD}" == "true" ]] || needs_rebuild; then
  echo "INFO: Building fresh ORM ZIP..."
  STACK_ZIP="$("${ROOT_DIR}/scripts/build_orm_stack_zip.sh" "${ROOT_DIR}/output")"
fi

if [[ ! -f "${STACK_ZIP}" ]]; then
  echo "ZIP not found: ${STACK_ZIP}" >&2
  exit 1
fi

echo "INFO: Using stack ZIP ${STACK_ZIP}"
echo "INFO: Updating stack ${STACK_ID} in ${REGION}"

update_cmd=(
  oci resource-manager stack update
  --stack-id "${STACK_ID}"
  --region "${REGION}"
  --config-source "${STACK_ZIP}"
  --force
  --wait-for-state ACTIVE
  --max-wait-seconds "${STACK_WAIT_SECONDS}"
)

if [[ -n "${TF_VARS_JSON:-}" ]]; then
  if [[ ! -f "${TF_VARS_JSON}" ]]; then
    echo "TF_VARS_JSON file not found: ${TF_VARS_JSON}" >&2
    exit 1
  fi
  update_cmd+=(--variables "file://${TF_VARS_JSON}")
fi

"${update_cmd[@]}"

attempt=1
while [[ "${attempt}" -le "${MAX_APPLY_ATTEMPTS}" ]]; do
  echo "INFO: Apply attempt ${attempt}/${MAX_APPLY_ATTEMPTS}"

  set +e
  job_json="$(
    oci resource-manager job create-apply-job \
      --stack-id "${STACK_ID}" \
      --region "${REGION}" \
      --execution-plan-strategy AUTO_APPROVED \
      --display-name "zip-apply-$(date +%Y%m%d%H%M%S)-a${attempt}" \
      --wait-for-state SUCCEEDED \
      --wait-for-state FAILED \
      --max-wait-seconds "${APPLY_WAIT_SECONDS}" \
      --query 'data.{id:id,state:"lifecycle-state"}' \
      --output json 2>/tmp/rm_zip_apply.err
  )"
  rc=$?
  set -e

  if [[ ${rc} -ne 0 ]]; then
    echo "WARN: Apply command failed before completion on attempt ${attempt}"
    sed -n '1,120p' /tmp/rm_zip_apply.err || true
    attempt=$((attempt + 1))
    sleep 20
    continue
  fi

  echo "${job_json}"
  job_id="$(jq -r '.id' <<<"${job_json}")"
  job_state="$(jq -r '.state' <<<"${job_json}")"

  if [[ "${job_state}" == "SUCCEEDED" ]]; then
    echo "SUCCESS: Apply succeeded with job ${job_id}"
    exit 0
  fi

  echo "WARN: Apply job ${job_id} finished in state ${job_state}"
  oci resource-manager job get-job-logs-content --job-id "${job_id}" --region "${REGION}" 2>/dev/null | tail -n 120 || true

  attempt=$((attempt + 1))
  sleep 30
done

echo "ERROR: Apply did not succeed after ${MAX_APPLY_ATTEMPTS} attempts" >&2
exit 1
