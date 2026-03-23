# MCP Speech Demo on OCI OKE

This repo supports three deployment modes from the same OCI Resource Manager stack ZIP.

- `infra_only`: create OCI infrastructure only
- `quick_deploy`: create infrastructure and deploy prebuilt public images
- `oci_devops`: create infrastructure, rebuild from your OCI DevOps repo, and deploy

## Choose a button

### 1. Infrastructure only

[![Deploy Infra Only](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https%3A%2F%2Fobjectstorage.us-chicago-1.oraclecloud.com%2Fp%2FRwI5kCL81FFO7kO3NWo_FLx4U3kGx1SBJ-VDm01UGGB_fn5wlRvmBQ7cC8j6dKI_%2Fn%2Fax6ymbvwiimc%2Fb%2Fresult-artifact-mcp-oke%2Fo%2Fcode-release%252Foci-deploy-mcp-speech-demo-latest.zip&zipUrlVariables=%7B%22deployment_mode%22%3A%22infra_only%22%7D)

Use this when you only want:

- VCN and subnets
- OKE cluster and virtual node pool
- speech bucket
- IAM policies needed by the stack

This mode does not deploy the app.

### 2. Quick deploy using public images

[![Deploy Quick Mode](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https%3A%2F%2Fobjectstorage.us-chicago-1.oraclecloud.com%2Fp%2FRwI5kCL81FFO7kO3NWo_FLx4U3kGx1SBJ-VDm01UGGB_fn5wlRvmBQ7cC8j6dKI_%2Fn%2Fax6ymbvwiimc%2Fb%2Fresult-artifact-mcp-oke%2Fo%2Fcode-release%252Foci-deploy-mcp-speech-demo-latest.zip&zipUrlVariables=%7B%22deployment_mode%22%3A%22quick_deploy%22%7D)

Use this when you want the fastest public one-click path.

This mode:

- creates infrastructure
- deploys prebuilt public images
- does not require an OCI DevOps source repository

Default public images:

- server: `ghcr.io/jaydip-aics-oracle/mcp-speech-demo-audio:latest`
- client: `ghcr.io/jaydip-aics-oracle/mcp-speech-demo-client:latest`

### 3. Advanced OCI DevOps source build

[![Deploy OCI DevOps Mode](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https%3A%2F%2Fobjectstorage.us-chicago-1.oraclecloud.com%2Fp%2FRwI5kCL81FFO7kO3NWo_FLx4U3kGx1SBJ-VDm01UGGB_fn5wlRvmBQ7cC8j6dKI_%2Fn%2Fax6ymbvwiimc%2Fb%2Fresult-artifact-mcp-oke%2Fo%2Fcode-release%252Foci-deploy-mcp-speech-demo-latest.zip&zipUrlVariables=%7B%22deployment_mode%22%3A%22oci_devops%22%7D)

Use this when you want the stack to rebuild your own source from an OCI DevOps mirror.

This mode:

- creates infrastructure
- creates OCI DevOps build and deploy automation
- rebuilds images from your OCI DevOps repository
- deploys the rebuilt app to OKE

## Which mode should I use?

| Goal | Mode |
| --- | --- |
| I only want network, OKE, bucket, and IAM | `infra_only` |
| I want a public one-click demo deployment | `quick_deploy` |
| I want my own OCI DevOps repo to rebuild and deploy my source | `oci_devops` |

## What each mode needs

### `infra_only`

Required inputs:

- `compartment_id`
- `region`

Usually optional:

- `home_region`
- `cluster_name`
- `resource_name_prefix`
- naming overrides for repo and bucket base names
- subnet CIDRs

Ignore these in this mode:

- `devops_repository_id`
- `devops_repository_url`
- `current_user_ocid`
- `ocir_auth_token`
- prebuilt image overrides

### `quick_deploy`

Required inputs:

- `compartment_id`
- `region`

Usually optional:

- `home_region`
- `cluster_name`
- `resource_name_prefix`
- `prebuilt_server_image_uri`
- `prebuilt_client_image_uri`
- `devops_deploy_namespace`
- app secret JSON fields
- GenAI settings
- subnet CIDRs

Ignore these in this mode:

- `devops_repository_id`
- `devops_repository_url`
- `current_user_ocid`
- `ocir_auth_token`

### `oci_devops`

Required inputs:

- `compartment_id`
- `region`
- `devops_repository_id`
- `devops_repository_url`
- `current_user_ocid`
- `genai_model_id`
- `genai_provider`

Conditionally required:

- `ocir_auth_token` only if the current OCI user has already reached the OCI auth token quota

Usually optional:

- `devops_source_branch` default is `one-click-deployment`
- `devops_build_spec_path` default is `build_spec.yaml`
- `devops_deploy_namespace`
- `devops_image_tag`
- app secret JSON fields
- subnet CIDRs

## What the stack ZIP actually contains

The public `zipUrl` is a Resource Manager stack ZIP. It contains:

- Terraform files
- Terraform modules
- Resource Manager `schema.yaml`
- Resource Manager provider shim

It does not contain a runnable application bundle by itself.

How the app gets deployed depends on mode:

- `infra_only`: no app deployment
- `quick_deploy`: Terraform deploys prebuilt container images
- `oci_devops`: OCI DevOps builds from your OCI DevOps repository, then deploys the result

## Runtime env handling

Application envs are still stack-managed in deploy modes.

In both `quick_deploy` and `oci_devops`, Terraform generates:

- namespace manifest
- service accounts
- Kubernetes secrets
- Deployments
- LoadBalancer Services

That is where app runtime settings are injected, including:

- region and compartment
- speech bucket name
- MCP internal URL wiring
- model/provider settings
- server and client tuning values

In `infra_only`, these app manifests are skipped.

## End-user deploy steps

### For `infra_only`

1. Click the infra-only button.
2. Fill `compartment_id` and `region`.
3. Create the stack.
4. Run `Plan`.
5. Run `Apply`.

Expected result:

- stack apply succeeds
- OKE and related infrastructure exist
- no app LoadBalancers are created

### For `quick_deploy`

1. Click the quick-deploy button.
2. Fill `compartment_id` and `region`.
3. Create the stack.
4. Run `Plan`.
5. Run `Apply`.

Expected result:

- stack apply succeeds
- deployment pipeline runs
- server and client LoadBalancers are created

### For `oci_devops`

1. Click the OCI DevOps button.
2. Fill `compartment_id`, `region`, `devops_repository_id`, `devops_repository_url`, `current_user_ocid`.
3. Add `ocir_auth_token` only when needed.
4. Create the stack.
5. Run `Plan`.
6. Run `Apply`.

Expected result:

- stack apply succeeds
- build pipeline runs
- images are delivered
- deployment pipeline runs
- server and client LoadBalancers are created

## What you do after code changes

### If you changed Terraform, schema, or README only

1. Commit and push your branch.
2. Merge when ready.
3. Publish a release or run the packaging workflow if you need the public ZIP updated.

### If you changed app code and want public quick deploy to use it

1. Commit and push your branch.
2. Merge when ready.
3. Publish a GitHub release, or run the packaging workflow manually if you use that path.
4. Confirm the workflow pushed:
   - updated stack ZIP
   - updated server image
   - updated client image
5. Confirm both GHCR packages are public.
6. Re-test the quick-deploy button.

### If you changed app code and want source-build users to get it

1. Commit and push your branch.
2. Mirror the updated branch into OCI DevOps.
3. Use the `oci_devops` button or update an existing OCI DevOps-backed stack.

## Local testing

Build the local uploadable ZIP:

```bash
./scripts/build_orm_stack_zip.sh
```

That creates:

```text
output/oci-deploy-mcp-speech-demo-latest.zip
```

Then upload it in Resource Manager using **Create stack -> My configuration**.

## Maintainer notes

The public quick-deploy path depends on two things being published:

- the stack ZIP at the public `zipUrl`
- the public container images used by `quick_deploy`

The GitHub workflow responsible for this is:

- [build-orm-stack-zip.yml](./.github/workflows/build-orm-stack-zip.yml)

Detailed Terraform and stack packaging notes are in:

- [terraform/README.md](./terraform/README.md)
