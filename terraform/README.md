# Terraform Infrastructure (OCI OKE MCP Stack)

This folder contains all Terraform code for provisioning infrastructure used by the MCP server + MCP client deployment.

For OCI Resource Manager one-click stack packaging, this Terraform directory is bundled with root-level stack files:

- `terraform/schema.yaml` -> used when Resource Manager reads directly from the OCI DevOps repository with working directory `terraform`
- `orm/schema.yaml` -> packaged as `schema.yaml` for ZIP upload and public quick-create links
- `orm/provider_orm.tf` -> packaged as `provider.tf`
- `release_files.json` -> packaging manifest
- `.github/workflows/build-orm-stack-zip.yml` -> builds `oci-deploy-mcp-speech-demo-latest.zip`

## Files

- `main.tf` - core resources (OKE, workload policies, OCIR repos)
- `bucket.tf` - Terraform-managed Object Storage bucket
- `naming.tf` - generated resource naming (prefix + compartment-based suffix)
- `network.tf` - VCN/subnet/security wiring
- `data.tf` - OCI data sources (including Object Storage namespace)
- `provider.tf` - provider and version constraints
- `variables.tf` - input variables
- `outputs.tf` - outputs consumed by deployment flow
- `terraform.tfvars.example` - user-specific placeholder template

## First-time setup

```bash
cd /mcp-speech-demo/terraform
cp terraform.tfvars.example terraform.tfvars
```

Update `terraform.tfvars` with your tenancy-specific values.

Minimum:

```hcl
tenancy_ocid   = "<TENANCY_OCID>"
compartment_id = "<COMPARTMENT_OCID>"
region         = "<OCI_REGION>"
resource_name_prefix                 = "mcp"
mcp_container_repository_name        = "audio-repo"
mcp_client_container_repository_name = "client-repo"
speech_bucket_name                   = "audio-bucket"
```

`home_region` is optional. When omitted, Terraform derives the tenancy home region automatically and uses it for IAM resources.
The stack is now opinionated toward the end-to-end OCI DevOps flow by default.
The workload identity policy is created automatically when it does not already exist for the target compartment naming pattern.
The stack creates OCI DevOps resources for both the MCP server and MCP client, and the end-to-end build/deploy flow is enabled by default when DevOps is enabled.
`genai_model_id` and `genai_provider` already default to the repo's standard values.

By default, Terraform generates stable names such as `mcp-audio-repo-hronz`, `mcp-client-repo-hronz`, and `mcp-audio-bucket-hronz` using `resource_name_prefix`, a base name, and the last 5 characters of the compartment OCID.

Those naming values are already present in `terraform.tfvars.example`, so when you copy it they are included automatically. If you want custom base names instead, edit them in `terraform.tfvars`:

```hcl
mcp_container_repository_name        = "team-audio-repo"
mcp_client_container_repository_name = "team-client-repo"
speech_bucket_name                   = "team-audio-bucket"
```

Those values are treated as base names, so the final names still include the shared prefix and compartment suffix. The generated bucket name is exposed as a Terraform output, and the bucket itself is created by Terraform during `terraform apply`.

## Run

```bash
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Deploy to Oracle Cloud (Resource Manager)

### Direct from OCI DevOps repository

Use this when you mirror this GitHub repository into OCI DevOps and want Resource Manager to read Terraform directly from that repository.

This repo is Resource Manager-ready directly from source control:

- working directory: `terraform`
- schema file: `terraform/schema.yaml`
- current OCI DevOps branch for this repo: `one-click-deployment`

In the OCI Console:

1. Open **Resource Manager**
2. Choose **Create stack**
3. Select **Source code control system**
4. Choose **DevOps**
5. Select your OCI DevOps project and the mirrored `mcp-speech-demo` repository
6. Set branch to `one-click-deployment`
7. Set working directory to `terraform`
8. Review the schema-driven form and create the stack

Expected result:

- the stack creates infrastructure
- the stack creates OCI DevOps build/deploy automation
- the stack apply creates infrastructure and DevOps resources
- each apply reruns the end-to-end DevOps build/deploy flow when DevOps is enabled

For CLI-based creation from the same repo source:

```bash
cp terraform/stack.auto.tfvars.json.example terraform/stack.auto.tfvars.json

COMPARTMENT_OCID="<COMPARTMENT_OCID>" \
DEVOPS_PROJECT_ID="<DEVOPS_PROJECT_OCID>" \
DEVOPS_REPOSITORY_ID="<DEVOPS_REPOSITORY_OCID>" \
TF_VARS_JSON="terraform/stack.auto.tfvars.json" \
./scripts/create_rm_stack_from_devops_repo.sh
```

Pre-existing requirements for this path:

- OCI DevOps project exists
- OCI DevOps repository exists
- branch `one-click-deployment` exists in that repository (or set your own branch explicitly)
- `devops_repository_id` and `devops_repository_url` point to that same repository
- `current_user_ocid` is explicitly set in stack variables
- `ocir_auth_token` is set only when the current user already has 2 auth tokens

UI parity note:

- Earlier UI runs often diverged from CLI runs because UI users relied on defaults (`master`, no explicit user/token), while CLI runs passed all variables explicitly.
- The schema defaults are now aligned for end-to-end behavior: `devops_source_branch = one-click-deployment` and `devops_build_spec_path = build_spec.yaml`. When DevOps is enabled, the stack reruns the pipeline automatically on each apply.

The one-click stack ZIP is built from `terraform/` and `terraform/modules/` plus `orm/schema.yaml` and `orm/provider_orm.tf`.
For ZIP-backed stacks that already exist, `scripts/update_rm_stack_from_zip.sh` rebuilds the latest ZIP if needed, updates the stack source, and retries apply jobs from the CLI.

Expected quick-create URL format after you create a long-lived read PAR for the Object Storage object:

```text
https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=<URL_ENCODED_OCI_PAR_URL>
```

The `zipUrl` must be a direct URL to a `.zip` file. The recommended pattern for this repo is:

- GitHub builds the ZIP with `.github/workflows/build-orm-stack-zip.yml`
- the workflow uploads the ZIP to a fixed Object Storage object key
- a long-lived PAR points to that object
- the public button uses the URL-encoded PAR value

Required GitHub configuration for the publish step:

- repository variables:
  `OCI_ORM_STACK_BUCKET`, `OCI_ORM_STACK_NAMESPACE`, `OCI_ORM_STACK_REGION`
- optional repository variables:
  `OCI_ORM_STACK_OBJECT_NAME`, `OCI_ORM_STACK_PAR_URL`
- repository secrets:
  `OCI_CLI_USER_OCID`, `OCI_CLI_TENANCY_OCID`, `OCI_CLI_FINGERPRINT`, `OCI_CLI_PRIVATE_KEY`
- optional repository secret:
  `OCI_CLI_PRIVATE_KEY_PASSPHRASE`

To build the ZIP in GitHub Actions:

- Run `.github/workflows/build-orm-stack-zip.yml` manually, or
- Publish a GitHub release to attach the ZIP asset automatically.
- When the OCI variables are configured, the same workflow uploads the ZIP to Object Storage.
- When `OCI_ORM_STACK_PAR_URL` is configured, the workflow emits `deploy-to-oracle-cloud-url.txt` with the fully encoded launch URL.

Manual fallback remains available through the repo Makefile-based flow documented in the root README.

For local verification without publishing a release ZIP:

```bash
./scripts/build_orm_stack_zip.sh
```

This creates:

```text
output/oci-deploy-mcp-speech-demo-latest.zip
```

Upload that ZIP in OCI Resource Manager using **Create stack -> My configuration**.

If you enable the OCI DevOps one-click path, also set:

```hcl
devops_repository_id   = "<DEVOPS_REPOSITORY_OCID>"
devops_repository_url  = "https://devops.scmservice.<region>.oci.oraclecloud.com/namespaces/<namespace>/projects/<project>/repositories/<repo>"
devops_source_branch   = "one-click-deployment"
devops_build_spec_path = "build_spec.yaml"
devops_deploy_namespace = "mcp"
genai_model_id         = "<GENERATIVE_AI_MODEL_ID>"
genai_provider         = "<GENERATIVE_AI_PROVIDER>"
```

`genai_service_endpoint` is optional. When omitted, Terraform derives `https://inference.generativeai.<region>.oci.oraclecloud.com`.

## Useful outputs

```bash
terraform output -raw mcp_server_repository_path
terraform output -raw mcp_client_repository_path
terraform output -raw cluster_id
terraform output -raw oci_namespace
terraform output -raw speech_bucket_name
terraform output -raw resource_name_prefix
```

## Destroy

```bash
terraform destroy -var-file=terraform.tfvars -auto-approve
```

> Note: Destroy removes resources managed by this stack. It does **not** delete your tenancy or Object Storage namespace.

## If you deploy to a different compartment

Changing `compartment_id` does not automatically wipe a previous compartment by itself.
What Terraform changes/destroys depends on the current state + new configuration.

Always run:

```bash
terraform plan -var-file=terraform.tfvars
```

and verify planned actions before `apply` or `destroy`.
