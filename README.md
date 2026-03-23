# MCP Audio + Client on OCI OKE

This repository deploys the MCP audio server and MCP client on OCI Kubernetes Engine (OKE). The stack supports three deployment modes from the same button and same ZIP:

- `infra_only` for infrastructure only
- `quick_deploy` using prebuilt public images
- `oci_devops` using a user-provided OCI DevOps source repository that rebuilds and deploys the app

## Deploy to OCI

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https%3A%2F%2Fobjectstorage.us-chicago-1.oraclecloud.com%2Fp%2FRwI5kCL81FFO7kO3NWo_FLx4U3kGx1SBJ-VDm01UGGB_fn5wlRvmBQ7cC8j6dKI_%2Fn%2Fax6ymbvwiimc%2Fb%2Fresult-artifact-mcp-oke%2Fo%2Fcode-release%252Foci-deploy-mcp-speech-demo-latest.zip)

## What’s included

- `terraform/` – OCI infrastructure for networking, OKE, OCIR repositories, bucket, and related resources
- `mcp-audio/` – MCP audio server source, Dockerfile, env template, and Kubernetes manifest
- `mcp-client/` – Gradio-based MCP client app
- `Makefile` – guided deployment, redeploy, validation, and cleanup helpers
- `blog/oci-oke-mcp-audio-deployment-guide.md` – full manual deployment runbook

---

## Easy deployment options

You have **3 ways** to deploy.

### Option 1: Advanced source build from an OCI DevOps mirror

Use this when you mirror this GitHub repository into OCI DevOps and want Resource Manager to rebuild and deploy your own source from that repository.

Behavior summary:

- stack apply creates infrastructure
- stack apply also creates DevOps build/deploy automation
- with `deployment_mode = oci_devops`, each apply reruns the end-to-end build/deploy flow
- UI and CLI stay aligned when you provide `current_user_ocid` explicitly and keep `devops_source_branch` plus `devops_build_spec_path` pointed at the same branch content

Before you press **Create** or **Apply**, make sure these already exist:

- the OCI DevOps project
- an OCI DevOps repository containing this repo's contents
- the `one-click-deployment` branch in that repository, or another branch you set explicitly
- a valid `devops_repository_id` / `devops_repository_url` pair for that same repository
- your OCIR username and auth token for the image pull secret

Recommended repository shape:

```text
Repository URL: https://devops.scmservice.<region>.oci.oraclecloud.com/namespaces/<namespace>/projects/<project>/repositories/mcp-speech-demo
Branch: one-click-deployment
Working directory: terraform
```

What this repo includes for that path:

- `terraform/schema.yaml` in the Terraform working directory for repo-backed Resource Manager stacks
- `scripts/create_rm_stack_from_devops_repo.sh` for CLI creation from an OCI DevOps source
- `scripts/update_rm_stack_from_zip.sh` for updating an existing ZIP-backed stack and retrying apply jobs
- the same `build_spec.yaml` path used by OCI DevOps and the ZIP-packaged Resource Manager flow

Console flow:

1. Open **Resource Manager**
2. Choose **Create stack**
3. Select **Source code control system**
4. Choose **DevOps**
5. Select your project, repository, and branch `one-click-deployment`
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
deployment_mode       = "oci_devops"
devops_repository_id    = "<DEVOPS_REPOSITORY_OCID>"
devops_repository_url   = "https://devops.scmservice.<region>.oci.oraclecloud.com/namespaces/<namespace>/projects/<project>/repositories/mcp-speech-demo"
devops_source_branch    = "one-click-deployment"
devops_build_spec_path  = "build_spec.yaml"
devops_deploy_namespace = "mcp"
```

With those values, Terraform creates:

- the DevOps project
- the build pipeline
- the deployment pipeline
- the OKE deployment environment
- an inline Kubernetes manifest for both app components
- an OCI DevOps build/deploy rerun on every apply when DevOps is enabled

### Option 2: Public one-click from OCI Resource Manager (Deploy to Oracle Cloud)

Use this when you want a public one-click launch from README into OCI Resource Manager without asking the user for an OCI DevOps repository mirror.

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https%3A%2F%2Fobjectstorage.us-chicago-1.oraclecloud.com%2Fp%2FRwI5kCL81FFO7kO3NWo_FLx4U3kGx1SBJ-VDm01UGGB_fn5wlRvmBQ7cC8j6dKI_%2Fn%2Fax6ymbvwiimc%2Fb%2Fresult-artifact-mcp-oke%2Fo%2Fcode-release%252Foci-deploy-mcp-speech-demo-latest.zip)

User steps:

1. Click **Deploy to Oracle Cloud**.
2. In OCI Resource Manager, review stack variables and create the stack.
3. Run **Plan** and then **Apply**.

Modes from the same button:

1. `infra_only`
   - creates only infrastructure
   - no app deployment
   - no load balancers for the app
2. `quick_deploy`
   - deploys prebuilt public images
   - no OCI DevOps source repository input required
3. `oci_devops`
   - rebuilds from your OCI DevOps source repository
   - requires OCI DevOps repository inputs and OCI user/auth details

Default public-button behavior:

- infrastructure is created
- public prebuilt images are deployed to OKE
- OCI DevOps is used only for the deployment action, not for source builds
- no `devops_repository_id` or `devops_repository_url` is required unless you switch to `deployment_mode = oci_devops`

Default public images:

- server: `ghcr.io/jaydip-aics-oracle/mcp-speech-demo-audio:latest`
- client: `ghcr.io/jaydip-aics-oracle/mcp-speech-demo-client:latest`

Maintainer note:

- the GitHub release workflow now publishes those images to GHCR
- the GHCR packages must be public for anonymous cluster image pulls to work


### Local ZIP verification

If you want to test before publishing any button or public mirror:

```bash
./scripts/build_orm_stack_zip.sh
```

That creates a local uploadable stack ZIP at:

```text
output/oci-deploy-mcp-speech-demo-latest.zip
```

Then in OCI Console:

1. Open **Resource Manager**
2. Choose **Create stack**
3. Select **My configuration**
4. Upload `output/oci-deploy-mcp-speech-demo-latest.zip`
5. Choose one of:
   - `deployment_mode = infra_only`
   - `deployment_mode = quick_deploy`
   - `deployment_mode = oci_devops`

Based on your current environment, the initial values to use are:

```text
region      = us-chicago-1
home_region = us-chicago-1
```

### End-to-end verification

For verification after stack apply:

1. Resource Manager apply succeeds
2. if `deployment_mode = oci_devops`, the OCI DevOps build pipeline run starts
3. if `deployment_mode = oci_devops`, both images are delivered to OCIR
4. if `deployment_mode != infra_only`, deployment pipeline run succeeds
5. if `deployment_mode != infra_only`, the `fastmcp-server` and `fastmcp-client` services appear in namespace `mcp`
6. if `deployment_mode != infra_only`, the server `/health` endpoint and client LoadBalancer both become reachable

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
For a direct stack from the OCI DevOps repo, use branch `one-click-deployment` (or your current fix branch) and working directory `terraform`.
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
