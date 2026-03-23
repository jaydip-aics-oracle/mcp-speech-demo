#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Create an OCI Resource Manager stack directly from an OCI DevOps repository.

Required environment variables:
  COMPARTMENT_OCID       Target Resource Manager stack compartment OCID
  DEVOPS_PROJECT_ID      OCI DevOps project OCID
  DEVOPS_REPOSITORY_ID   OCI DevOps repository OCID

Optional environment variables:
  STACK_DISPLAY_NAME     Stack display name
  STACK_DESCRIPTION      Stack description
  DEVOPS_BRANCH          Repo branch to use (default: one-click-deployment)
  STACK_WORKING_DIR      Terraform working directory in the repo (default: terraform)
  TERRAFORM_VERSION      Terraform version for the stack (default: 1.5.x)
  TF_VARS_JSON           Path to a JSON file of Terraform variables for the stack
  WAIT_FOR_STATE         Work request state to wait for (default: SUCCEEDED)
  MAX_WAIT_SECONDS       Wait timeout in seconds (default: 1800)

Example:
  cp terraform/stack.auto.tfvars.json.example terraform/stack.auto.tfvars.json
  # edit terraform/stack.auto.tfvars.json with your tenancy values

  COMPARTMENT_OCID=ocid1.compartment.oc1..example \
  DEVOPS_PROJECT_ID=ocid1.devopsproject.oc1..example \
  DEVOPS_REPOSITORY_ID=ocid1.devopsrepository.oc1..example \
  TF_VARS_JSON=terraform/stack.auto.tfvars.json \
  ./scripts/create_rm_stack_from_devops_repo.sh
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

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_env "COMPARTMENT_OCID"
require_env "DEVOPS_PROJECT_ID"
require_env "DEVOPS_REPOSITORY_ID"

STACK_DISPLAY_NAME="${STACK_DISPLAY_NAME:-mcp-speech-demo-devops-stack}"
STACK_DESCRIPTION="${STACK_DESCRIPTION:-MCP Audio + Client on OKE from OCI DevOps repository}"
DEVOPS_BRANCH="${DEVOPS_BRANCH:-one-click-deployment}"
STACK_WORKING_DIR="${STACK_WORKING_DIR:-terraform}"
TERRAFORM_VERSION="${TERRAFORM_VERSION:-1.5.x}"
WAIT_FOR_STATE="${WAIT_FOR_STATE:-SUCCEEDED}"
MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-1800}"

cmd=(
  oci resource-manager stack create-stack-create-dev-ops-config-source-details
  --compartment-id "${COMPARTMENT_OCID}"
  --config-source-project-id "${DEVOPS_PROJECT_ID}"
  --config-source-repository-id "${DEVOPS_REPOSITORY_ID}"
  --config-source-branch-name "${DEVOPS_BRANCH}"
  --config-source-working-directory "${STACK_WORKING_DIR}"
  --display-name "${STACK_DISPLAY_NAME}"
  --description "${STACK_DESCRIPTION}"
  --terraform-version "${TERRAFORM_VERSION}"
  --wait-for-state "${WAIT_FOR_STATE}"
  --max-wait-seconds "${MAX_WAIT_SECONDS}"
)

if [[ -n "${TF_VARS_JSON:-}" ]]; then
  if [[ ! -f "${TF_VARS_JSON}" ]]; then
    echo "TF_VARS_JSON file not found: ${TF_VARS_JSON}" >&2
    exit 1
  fi
  cmd+=(--variables "file://${TF_VARS_JSON}")
fi

"${cmd[@]}"
