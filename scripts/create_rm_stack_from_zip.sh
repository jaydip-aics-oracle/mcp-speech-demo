#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Create a new OCI Resource Manager stack from the latest local ZIP and run apply with retries.

Optional environment variables:
  COMPARTMENT_OCID       Target Resource Manager stack compartment OCID. Defaults to compartment_id from TF_VARS_JSON.
  REGION                Stack region. Defaults to region from TF_VARS_JSON.
  STACK_ZIP             ZIP file to upload. Defaults to output/oci-deploy-mcp-speech-demo-latest.zip
  TF_VARS_JSON          JSON file of Terraform variables for the stack
  STACK_DISPLAY_NAME    Stack display name. Defaults to oci-deploy-mcp-speech-demo-zip-<timestamp>
  STACK_DESCRIPTION     Stack description
  TERRAFORM_VERSION     Terraform version for the stack (default: 1.5.x)
  MAX_APPLY_ATTEMPTS    Number of apply retries (default: 3)
  STACK_WAIT_SECONDS    Wait timeout for stack creation (default: 1800)
  APPLY_WAIT_SECONDS    Wait timeout for apply job (default: 7200)
  FORCE_REBUILD         When true, always rebuild the ZIP before stack creation

Examples:
  TF_VARS_JSON=plans/mcp-stack-27.tfvars.json \
  ./scripts/create_rm_stack_from_zip.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_ZIP="${ROOT_DIR}/output/oci-deploy-mcp-speech-demo-latest.zip"

TF_VARS_JSON="${TF_VARS_JSON:-}"
STACK_ZIP="${STACK_ZIP:-${DEFAULT_ZIP}}"
TERRAFORM_VERSION="${TERRAFORM_VERSION:-1.5.x}"
MAX_APPLY_ATTEMPTS="${MAX_APPLY_ATTEMPTS:-3}"
STACK_WAIT_SECONDS="${STACK_WAIT_SECONDS:-1800}"
APPLY_WAIT_SECONDS="${APPLY_WAIT_SECONDS:-7200}"
FORCE_REBUILD="${FORCE_REBUILD:-false}"
STACK_DESCRIPTION="${STACK_DESCRIPTION:-MCP Audio + Client on OKE from ZIP-uploaded Resource Manager stack}"
STACK_DISPLAY_NAME="${STACK_DISPLAY_NAME:-oci-deploy-mcp-speech-demo-zip-$(date +%Y%m%d%H%M%S)}"

if [[ -n "${TF_VARS_JSON}" && ! -f "${TF_VARS_JSON}" ]]; then
  echo "TF_VARS_JSON file not found: ${TF_VARS_JSON}" >&2
  exit 1
fi

json_var() {
  local key="$1"
  if [[ -n "${TF_VARS_JSON}" ]]; then
    jq -r --arg key "${key}" '.[$key] // empty' "${TF_VARS_JSON}"
  fi
}

REGION="${REGION:-$(json_var region)}"
COMPARTMENT_OCID="${COMPARTMENT_OCID:-$(json_var compartment_id)}"

if [[ -z "${COMPARTMENT_OCID}" ]]; then
  echo "Missing COMPARTMENT_OCID and no compartment_id found in TF_VARS_JSON." >&2
  usage >&2
  exit 1
fi

if [[ -z "${REGION}" ]]; then
  echo "Missing REGION and no region found in TF_VARS_JSON." >&2
  usage >&2
  exit 1
fi

needs_rebuild() {
  if [[ ! -f "${STACK_ZIP}" ]]; then
    return 0
  fi

  if find "${ROOT_DIR}/terraform" "${ROOT_DIR}/orm" -type f \( -name '*.tf' -o -name 'schema.yaml' -o -name 'provider_orm.tf' \) -newer "${STACK_ZIP}" | grep -q .; then
    return 0
  fi

  return 1
}

if [[ "${FORCE_REBUILD}" == "true" ]] || needs_rebuild; then
  echo "INFO: Building fresh ORM ZIP..."
  STACK_ZIP="$("${ROOT_DIR}/scripts/build_orm_stack_zip.sh" "${ROOT_DIR}/output")"
fi

if [[ ! -f "${STACK_ZIP}" ]]; then
  echo "ZIP not found: ${STACK_ZIP}" >&2
  exit 1
fi

echo "INFO: Using stack ZIP ${STACK_ZIP}"
echo "INFO: Creating stack in ${REGION}"

create_cmd=(
  oci resource-manager stack create
  --compartment-id "${COMPARTMENT_OCID}"
  --region "${REGION}"
  --config-source "${STACK_ZIP}"
  --display-name "${STACK_DISPLAY_NAME}"
  --description "${STACK_DESCRIPTION}"
  --terraform-version "${TERRAFORM_VERSION}"
  --wait-for-state ACTIVE
  --max-wait-seconds "${STACK_WAIT_SECONDS}"
  --query 'data.{id:id,state:"lifecycle-state"}'
  --output json
)

if [[ -n "${TF_VARS_JSON}" ]]; then
  create_cmd+=(--variables "file://${TF_VARS_JSON}")
fi

stack_json="$("${create_cmd[@]}")"
echo "${stack_json}"

STACK_ID="$(jq -r '.id' <<<"${stack_json}")"
STACK_STATE="$(jq -r '.state' <<<"${stack_json}")"

if [[ -z "${STACK_ID}" || "${STACK_ID}" == "null" ]]; then
  echo "Failed to create stack or extract stack id." >&2
  exit 1
fi

if [[ "${STACK_STATE}" != "ACTIVE" ]]; then
  echo "Stack ${STACK_ID} finished in unexpected state ${STACK_STATE}" >&2
  exit 1
fi

attempt=1
while [[ "${attempt}" -le "${MAX_APPLY_ATTEMPTS}" ]]; do
  echo "INFO: Apply attempt ${attempt}/${MAX_APPLY_ATTEMPTS} for ${STACK_ID}"

  set +e
  job_json="$(
    oci resource-manager job create-apply-job \
      --stack-id "${STACK_ID}" \
      --region "${REGION}" \
      --execution-plan-strategy AUTO_APPROVED \
      --display-name "zip-create-apply-$(date +%Y%m%d%H%M%S)-a${attempt}" \
      --wait-for-state SUCCEEDED \
      --wait-for-state FAILED \
      --max-wait-seconds "${APPLY_WAIT_SECONDS}" \
      --query 'data.{id:id,state:"lifecycle-state"}' \
      --output json 2>/tmp/rm_zip_create_apply.err
  )"
  rc=$?
  set -e

  if [[ ${rc} -ne 0 ]]; then
    echo "WARN: Apply command failed before completion on attempt ${attempt}"
    sed -n '1,160p' /tmp/rm_zip_create_apply.err || true
    attempt=$((attempt + 1))
    sleep 20
    continue
  fi

  echo "${job_json}"
  job_id="$(jq -r '.id' <<<"${job_json}")"
  job_state="$(jq -r '.state' <<<"${job_json}")"

  if [[ "${job_state}" == "SUCCEEDED" ]]; then
    echo "SUCCESS: Apply succeeded with job ${job_id} for stack ${STACK_ID}"
    exit 0
  fi

  echo "WARN: Apply job ${job_id} finished in state ${job_state}"
  oci resource-manager job get-job-logs-content --job-id "${job_id}" --region "${REGION}" 2>/dev/null | tail -n 160 || true

  attempt=$((attempt + 1))
  sleep 30
done

echo "ERROR: Apply did not succeed after ${MAX_APPLY_ATTEMPTS} attempts for stack ${STACK_ID}" >&2
exit 1
