# MCP Audio + Client on OCI OKE

This repository deploys the MCP audio server and MCP client on OCI Kubernetes Engine (OKE), pushes both container images to OCIR, and wires the client to the server MCP endpoint.

## What’s included

- `terraform/` – OCI infrastructure for networking, OKE, OCIR repositories, bucket, and related resources
- `mcp-audio/` – MCP audio server source, Dockerfile, env template, and Kubernetes manifest
- `mcp-client/` – Gradio-based MCP client app
- `Makefile` – guided deployment, redeploy, validation, and cleanup helpers
- `blog/oci-oke-mcp-audio-deployment-guide.md` – full manual deployment runbook

---

## Easy deployment options

You have **3 ways** to deploy.

### Option 1: Direct stack from the OCI DevOps repo

Use this when you want to keep the source private and create the Resource Manager stack from the OCI DevOps repository itself.

Behavior summary:

- stack apply creates infrastructure
- stack apply also creates DevOps build/deploy automation
- the first build run is optional and is disabled by default, so stack apply can finish cleanly before you trigger the OCI DevOps build/deploy flow

Before you press **Create** or **Apply**, make sure these already exist:

- the OCI DevOps project
- the OCI DevOps repository
- the `master` branch in that repository
- a valid `devops_repository_id` / `devops_repository_url` pair for the same repository
- your OCIR username and auth token for the image pull secret

Current repo details for this environment:

```text
Repository URL: https://devops.scmservice.us-chicago-1.oci.oraclecloud.com/namespaces/ax6ymbvwiimc/projects/hosted-mcp-oke/repositories/selfhosted-mcp-oke
Branch: master
Working directory: terraform
```

What changed in this repo to support that path:

- `terraform/schema.yaml` now sits in the same working directory as the Terraform code, so Resource Manager can load the schema directly from the repo-backed stack source.
- `terraform/provider.tf` is now the same provider file used both locally and in the packaged ZIP flow.
- `scripts/create_rm_stack_from_devops_repo.sh` wraps the OCI CLI command for creating a stack from an OCI DevOps repository source.
- `scripts/update_rm_stack_from_zip.sh` rebuilds the ZIP when needed, updates an existing ZIP-backed stack, and retries apply jobs from the CLI.
- The existing ZIP/ORM packaging path remains in `orm/` for local ZIP upload and public quick-create packaging.

Console flow:

1. Open **Resource Manager**
2. Choose **Create stack**
3. Select **Source code control system**
4. Choose **DevOps**
5. Select project `hosted-mcp-oke`, repository `selfhosted-mcp-oke`, branch `master`
6. Set **Working directory** to `terraform`
7. Review variables from `terraform/schema.yaml`, then create the stack
8. Run **Plan** and **Apply**

CLI flow:

```bash
cp terraform/stack.auto.tfvars.json.example terraform/stack.auto.tfvars.json

COMPARTMENT_OCID="<COMPARTMENT_OCID>" \
DEVOPS_PROJECT_ID="<DEVOPS_PROJECT_OCID>" \
DEVOPS_REPOSITORY_ID="<DEVOPS_REPOSITORY_OCID>" \
TF_VARS_JSON="terraform/stack.auto.tfvars.json" \
./scripts/create_rm_stack_from_devops_repo.sh
```

For the full build-and-deploy path from that stack, set:

```hcl
devops_repository_id    = "<DEVOPS_REPOSITORY_OCID>"
devops_repository_url   = "https://devops.scmservice.us-chicago-1.oci.oraclecloud.com/namespaces/ax6ymbvwiimc/projects/hosted-mcp-oke/repositories/selfhosted-mcp-oke"
devops_source_branch    = "master"
devops_deploy_namespace = "mcp"
```

With those values, Terraform creates:

- the DevOps project
- the build pipeline
- the deployment pipeline
- the OKE deployment environment
- an inline Kubernetes manifest for both app components
- an optional initial build run only when `devops_trigger_initial_build = true`

### Option 2: Public one-click from OCI Resource Manager (Deploy to Oracle Cloud)

Use this when you want OCI Stack creation directly from a public release ZIP.

Behavior summary:

- stack apply creates infrastructure
- stack apply also creates DevOps build/deploy automation
- the first build run is optional and is disabled by default, so stack apply can finish before any OCI DevOps build starts

1. Click your public deploy button (replace `<org>/<repo>` with your public mirror):

```html
<a href="https://cloud.oracle.com/resourcemanager/stacks/create?region=home&zipUrl=https://github.com/<org>/<repo>/releases/latest/download/oci-deploy-selfhosted-mcp-oke-latest.zip" target="_blank"><img src="https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg" alt="Deploy to Oracle Cloud"/></a>
```

2. On **Create Stack**, review variables from the ZIP-packaged `schema.yaml` and create the stack.
3. Run **Plan** and **Apply** from Resource Manager.
4. For the full one-click flow, provide the OCI DevOps repository OCID/URL plus the GenAI model/provider variables so the stack can create the pipelines. If you want the first build/deploy to start during stack apply, explicitly set `devops_trigger_initial_build = true`. The stack auto-creates the OCIR auth token unless the current user has already hit the token quota, in which case you provide one fallback token value only.
5. Use stack outputs such as `cluster_id`, `mcp_server_repository_path`, `mcp_client_repository_path`, `oci_namespace`, `speech_bucket_name`, `devops_build_pipeline_id`, and `devops_deploy_pipeline_id`.

Notes:
- The ZIP packaging config is in `release_files.json`.
- Resource Manager ZIP-specific files remain under `orm/`.
- This flow packages Terraform from `terraform/` and maps `orm/schema.yaml` and `orm/provider_orm.tf` to root `schema.yaml` and `provider.tf` in the ZIP.
- OCI DevOps build automation uses `devops/build_spec.yaml` from the current OCI DevOps repository branch.
- The button must point to a real public `.zip` file. A GitHub directory such as `oracle-devrel/ai-solutions/tree/main/apps/oracle-mcp-oke` is not a valid `zipUrl`.
- The DevOps build step builds the two container images only; user-specific env values still come from Terraform and are injected at deploy time into Kubernetes secrets and pod env vars.

### Local ZIP verification

If you want to test before publishing any button or public mirror:

```bash
./scripts/build_orm_stack_zip.sh
```

That creates a local uploadable stack ZIP at:

```text
output/oci-deploy-selfhosted-mcp-oke-latest.zip
```

Then in OCI Console:

1. Open **Resource Manager**
2. Choose **Create stack**
3. Select **My configuration**
4. Upload `output/oci-deploy-selfhosted-mcp-oke-latest.zip`
5. Provide the OCI DevOps repository OCID/URL and let the stack run the default end-to-end flow

Based on your current environment, the initial values to use are:

```text
region      = us-chicago-1
home_region = us-chicago-1
```

### End-to-end verification

For the full DevOps-enabled flow, verify in this order after stack apply:

1. Resource Manager apply succeeds
2. OCI DevOps build pipeline run starts
3. both images are delivered to OCIR
4. deployment pipeline run succeeds
5. the `fastmcp-server` and `fastmcp-client` services appear in namespace `mcp`
6. the server `/health` endpoint and client LoadBalancer both become reachable

### Option 3: Easy mode with Makefile (manual fallback)

If you want the simplest path, use this option.

#### Step 1: Create your Terraform values file

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

#### Step 2: Open `terraform/terraform.tfvars` and replace these values

```hcl
tenancy_ocid       = "<TENANCY_OCID>"
compartment_id     = "<COMPARTMENT_OCID>"
region             = "<OCI_REGION>"
resource_name_prefix                 = "mcp"
mcp_container_repository_name        = "audio-repo"
mcp_client_container_repository_name = "client-repo"
speech_bucket_name                   = "audio-bucket"
```

Terraform now builds OCIR repository and speech bucket names from three parts: `resource_name_prefix`, a base name, and the last 5 characters of your compartment OCID. For example, the default server repo becomes `mcp-audio-repo-hronz`.

Those naming values are already present in `terraform.tfvars.example`, so when you copy it they come along automatically. If you want custom base names instead of the defaults, edit them in `terraform.tfvars`:

```hcl
resource_name_prefix                 = "mcp"
mcp_container_repository_name        = "team-audio-repo"
mcp_client_container_repository_name = "team-client-repo"
speech_bucket_name                   = "team-audio-bucket"
```

If you keep the defaults, Terraform uses `audio-repo`, `client-repo`, and `audio-bucket` as the base names, and still outputs the final names for the rest of the deployment flow to use.
`home_region` is optional and acts as an override; when omitted, Terraform derives your tenancy home region automatically for IAM resources.
The stack now expects the OCI DevOps repository inputs as part of the default end-to-end deployment path.
For a direct stack from the OCI DevOps repo, use branch `master` and working directory `terraform`.
The workload identity policy is created automatically by Terraform for the generated service accounts.
`genai_model_id` and `genai_provider` default to the repo's standard OCI Generative AI values if you do not override them.

#### Step 3: Create your env files

```bash
cp mcp-audio/.env.example mcp-audio/.env
cp mcp-client/.env.example mcp-client/.env
```

#### Step 4: Run the guided deployment

Before you run it, set variables in 2 parts at the top of `Makefile`:

### Required (mandatory)

```make
TENANCY_OCID         ?= <your-tenancy-ocid>
COMPARTMENT_OCID     ?= <your-compartment-ocid>
REGION               ?= us-chicago-1
```

### Optional (can be left as default / prompted at runtime where applicable)

```make
DOCKER_USER          ?= <your-namespace>/<your-oci-username>
DOCKER_EMAIL         ?= <your-email>
DOCKER_PASS          ?= <your-ocir-auth-token>
IMAGE_VERSION        ?= latest
CLIENT_IMAGE_VERSION ?= latest
RESOURCE_NAME_PREFIX ?= mcp
MCP_CONTAINER_REPOSITORY_NAME        ?=
MCP_CLIENT_CONTAINER_REPOSITORY_NAME ?=
SPEECH_BUCKET_NAME                   ?=
```

Main values to replace there:

- `TENANCY_OCID`
- `COMPARTMENT_OCID`
- `REGION`

Optional (name overrides):
- `RESOURCE_NAME_PREFIX`
- `MCP_CONTAINER_REPOSITORY_NAME`
- `MCP_CLIENT_CONTAINER_REPOSITORY_NAME`
- `SPEECH_BUCKET_NAME`

The Makefile deployment flow uses the fixed Kubernetes namespace `mcp`.

These override values are treated as base names. The final resource names still include `RESOURCE_NAME_PREFIX` and the compartment-based suffix.

Helpful mapping:

- `DOCKER_USER` → usually `OCI_NAMESPACE/<oci-username>`
- `DOCKER_PASS` → your OCIR auth token
- `REGION` → usually `us-chicago-1`
- `TENANCY_OCID` / `COMPARTMENT_OCID` → from OCI Console
- `IMAGE_VERSION` / `CLIENT_IMAGE_VERSION` → usually `latest`
- `RESOURCE_NAME_PREFIX` → base prefix for generated repo and bucket names


During this step, the flow asks only when values are missing. Specifically:

- If `compartment_id` is already present in `terraform/terraform.tfvars`, it is reused (no prompt)
- If `region` is already present in `terraform/terraform.tfvars` (or `REGION` in Makefile), it is reused (no prompt)
- You may still be prompted for OCIR username/auth token and image tag when those are not preset

When Terraform has already been applied, the deploy helpers resolve the active OCI region from `terraform output -raw oci_region` first and only fall back to `terraform/terraform.tfvars` if outputs are not available yet.

So prompts may include:

- `COMPARTMENT_OCID`
- region
- OCIR username
- OCIR auth token
- image tag

Here is what each value means and where to get it:

| Value | What it is | Where to get it | Sample |
|---|---|---|---|
| `COMPARTMENT_OCID` | OCI compartment where you deploy | OCI Console → Identity & Security → Compartments | `ocid1.compartment.oc1..aaaa...` |
| `region` | OCI region | Same region you use in `terraform.tfvars` | `us-chicago-1` |
| `OCIR username` | Username used for OCIR login | Usually `<oci-username>` | `<namespace>/user@oracle.com` |
| `OCIR auth token` | OCI auth token for Docker login | OCI Console → User Settings → Auth Tokens | `<paste-token-here>` |
| `image tag` | Docker tag for server/client images | Your choice | `latest` |

Simple sample values based on this repo flow:

```text
COMPARTMENT_OCID = ocid1.compartment.oc1..aaaa...
region           = <your-deployment-region>
OCI_NAMESPACE    = output of `oci os ns get`
OCIR username    = ?/<oci-username>
image tag        = latest
```

How to quickly get/fill some of them:

```bash
# get OCI namespace
oci os ns get

```

#### Step 5: Validate everything

First validate:

```bash
make validate-fresh
```

If validation is successful, then sync `terraform.tfvars` from top-of-Makefile values:

```bash
make update-tfvars
```

`terraform init` in the Makefile includes retry handling for transient provider registry/network failures.

`terraform apply` now creates the bucket directly as part of Terraform, using the same deterministic naming logic as the OCIR repositories.

This ensures Terraform does **not** use placeholder values like `<COMPARTMENT_OCID>`.

Now run:

```bash
make deploy-fresh-guided
```




#### Step 6: Check the app is running

```bash
kubectl -n mcp get deploy,pods,svc -o wide
```

```bash
kubectl -n mcp get pods,svc
```

#### Step 7: Cleanup / destroy when needed

For full cleanup (Kubernetes + Terraform + bucket cleanup):

```bash
make destroy-all-fresh
```

Only remove Kubernetes app resources:

```bash
make destroy-k8s
```

### Important: compartment isolation

- Terraform only manages resources tracked in **that folder's Terraform state**.
- If you change `compartment_id` to a new compartment and run apply, Terraform operates against that configuration/state.
- It will **not automatically destroy resources in another compartment** unless those resources are in the same state and Terraform plans a replacement.

Safe practice before switching compartments:

```bash
terraform -chdir=terraform plan -var-file=terraform.tfvars
```

Review plan output before apply/destroy.


### Manual guide using the blog post

If you want to do each step yourself, use:

`blog/oci-oke-mcp-audio-deployment-guide.md`

That guide walks you through Terraform, image push, secrets, placeholder replacement, deployment, and checks.

`make quick-redeploy` also resolves the OCI region dynamically from Terraform output, prints the resolved value, and falls back to `terraform/terraform.tfvars` if needed.

## Quick things to remember


### 1. If you do manual deploy, check placeholders

Before applying `mcp-audio/k8s/manifest.yaml`, make sure placeholders are replaced.

Quick check:

```bash
grep -nE '<mcp-audio-image-tag>|<mcp-server-image-tag>|<mcp-client-image-tag>|<Compartment_OCID>|<OCI_NAMESPACE>|<SPEECH_BUCKET>' mcp-audio/k8s/manifest.yaml
```

If any placeholder still appears, replace values before deployment.


### 2. If image pull fails, recreate `ocirsecret`

This is one of the most common fixes.

---

## Local development

```bash
cp mcp-audio/.env.example mcp-audio/.env
cp mcp-client/.env.example mcp-client/.env

make dev-server-setup
make dev-client-setup

make dev-server-run
# new terminal
make dev-client-run
```

### Client UI notes

When the local client starts, the top bar shows:

- `MCP URL`: the MCP server endpoint the client is connected to
- `Audio Bucket`: the currently selected Object Storage bucket used for uploads and speech jobs
- `Model`: the default speech model exposed by the MCP server config

Home screen example:

![Client home screen](blog/assets/client-ui-home-screen.png)

The `Audio Bucket` dropdown is populated from OCI Object Storage using the active client configuration.

For local runs, the client typically needs:

- `ENVIRONMENT=dev`
- `AUTH_PROFILE=<your-profile>`
- `OCI_REGION=<bucket-region>`
- `COMPARTMENT_ID=<compartment-ocid>`
- `OCI_NAMESPACE=<object-storage-namespace>`
- `SPEECH_BUCKET=<default-bucket-name>`

Notes:

- The dropdown lists buckets in the configured compartment for the selected namespace and region.
- `OCI_REGION` overrides the region from your OCI profile in local dev mode.
- If bucket discovery fails, the client falls back to the configured `SPEECH_BUCKET` when available.

Bucket list example:

![Client bucket list demo](blog/assets/client-ui-bucket-list-demo.png)

The home screen includes three quick actions:

- `Process uploaded audio`
- `Analyze sentiment`
- `help`

Typing `help` in the chat input, or clicking the `help` quick action, shows the currently available MCP tools, typically:

- `process_audio`
- `sentiment_analysis`

Help command example:

![Client help command demo](blog/assets/client-ui-help-command.png)

### Demo flows

Audio upload / transcription demo:

- select the target bucket from `Audio Bucket`
- attach a local audio file such as `sample.wav`
- click `Process uploaded audio` or type a prompt like `Process uploaded audio`
- the chat shows upload context and transcription job progress such as `IN_PROGRESS`

![Client audio upload demo](blog/assets/client-ui-audio-upload-demo.png)

Sentiment analysis demo:

- after uploading or transcribing content, click `Analyze sentiment`
- you can also type prompts like `Analyze sentiment of this`
- the client calls the sentiment tool and renders the summarized sentiment result directly in the conversation panel

![Client sentiment demo](blog/assets/client-ui-sentiment-demo.png)

These two flows are useful for screenshots and walkthroughs:

- audio upload + transcription progress view
- sentiment tool result view

## Agent Tool-Call Notes (Speech)

- `process_audio` supports:
  - object mode: `object_name`
  - inline mode: `file_name` + `audio_base64` (real base64 content)
- Keep `payload` as a JSON string when used.
- For multiple attached local files, call `process_audio` once per file.
- See service-specific details in `mcp-audio/README.md`.

---

## Env settings (dev vs prod)

Use `mcp-audio/.env` and `mcp-client/.env` with these conventions.

### Dev (local machine)

- `ENVIRONMENT=dev`
- Use config-file auth profiles (`~/.oci/config`)

Example values:

```env
# mcp-audio/.env
ENVIRONMENT=dev
OCI_CONFIG_PROFILE=DEFAULT
OCI_REGION=<your-bucket-region>
COMPARTMENT_ID=<compartment_ocid>
```

```env
# mcp-client/.env
ENVIRONMENT=dev
AUTH_PROFILE=DEFAULT
OCI_REGION=<your-bucket-region>
MCP_URL=http://127.0.0.1:8080/mcp/
MCP_AUTH_ENABLED=false
# MCP_AUTH_TOKEN_URL=https://<idcs-domain>/oauth2/v1/token
# MCP_AUTH_CLIENT_ID=<oauth-client-id>
# MCP_AUTH_CLIENT_SECRET=<oauth-client-secret>
# MCP_AUTH_SCOPE=https://genaisolutions.com/read
COMPARTMENT_ID=<compartment_ocid>
MODEL_ID=<model_id>
SERVICE_ENDPOINT=https://inference.generativeai.us-chicago-1.oci.oraclecloud.com
PROVIDER=cohere
OCI_NAMESPACE=<namespace>
SPEECH_BUCKET=<bucket>
MODEL_TEMPERATURE=0.2
MODEL_MAX_TOKENS=4096
```

Notes:

- For local `oracle_agent.py`, `AUTH_PROFILE` / `OCI_CONFIG_FILE` control OCI profile auth.
- `OCI_REGION` now overrides the region from your OCI profile in dev mode, which is important for the Audio Bucket dropdown and Object Storage calls.
- The client Audio Bucket dropdown needs `COMPARTMENT_ID`, `OCI_NAMESPACE`, and `SPEECH_BUCKET` to be resolvable locally or from the MCP server config.

### Prod (OKE / Kubernetes)

- Use non-dev environment (`ENVIRONMENT=PRD` recommended)
- Workload identity is used in cluster (no local OCI config file needed in container)
- `MCP_URL` for client is injected from manifest (`fastmcp-server` service DNS)

Example values:

```env
# mcp-audio/.env
ENVIRONMENT=PRD
OCI_REGION=<your-deployment-region>
COMPARTMENT_ID=<compartment_ocid>
OCI_NAMESPACE=<namespace>
SPEECH_BUCKET=<bucket>
```

```env
# mcp-client/.env
ENVIRONMENT=PRD
MCP_AUTH_ENABLED=false
# When MCP endpoint requires OAuth, set MCP_AUTH_ENABLED=true and configure
# MCP_AUTH_TOKEN_URL, MCP_AUTH_CLIENT_ID, MCP_AUTH_CLIENT_SECRET, MCP_AUTH_SCOPE.
COMPARTMENT_ID=<compartment_ocid>
MODEL_ID=<model_id>
SERVICE_ENDPOINT=https://inference.generativeai.<your-deployment-region>.oci.oraclecloud.com
PROVIDER=cohere
OCI_NAMESPACE=<namespace>
SPEECH_BUCKET=<bucket>
```

---




Helpful validation commands:

```bash
kubectl -n mcp get deploy,pods,svc -o wide
kubectl -n mcp get deploy fastmcp-server -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n mcp get deploy fastmcp-client -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```
