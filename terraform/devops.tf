check "devops_pipeline_inputs" {
  assert {
    condition = !var.enable_devops_pipeline || (
      (var.devops_repository_id == null ? "" : trimspace(var.devops_repository_id)) != "" &&
      (var.devops_repository_url == null ? "" : trimspace(var.devops_repository_url)) != "" &&
      (var.genai_model_id == null ? "" : trimspace(var.genai_model_id)) != "" &&
      (var.genai_provider == null ? "" : trimspace(var.genai_provider)) != ""
    )
    error_message = "Set devops_repository_id, devops_repository_url, genai_model_id, and genai_provider."
  }
}

check "ocir_pull_token_inputs" {
  assert {
    condition = !var.enable_devops_pipeline || (
      (var.current_user_ocid == null ? "" : trimspace(var.current_user_ocid)) != "" &&
      (local.use_provided_ocir_auth_token || local.current_user_token_count < 2)
    )
    error_message = "Set current_user_ocid. If the current user already has 2 OCI auth tokens, also provide ocir_auth_token."
  }
}

locals {
  devops_repository_id_normalized      = var.devops_repository_id == null ? "" : trimspace(var.devops_repository_id)
  devops_repository_url_normalized     = var.devops_repository_url == null ? "" : trimspace(var.devops_repository_url)
  devops_project_name_normalized       = var.devops_project_name == null ? "" : trimspace(var.devops_project_name)
  devops_notification_topic_normalized = var.devops_notification_topic_id == null ? "" : trimspace(var.devops_notification_topic_id)
  current_user_ocid_normalized         = var.current_user_ocid == null ? "" : trimspace(var.current_user_ocid)
  ocir_auth_token_normalized           = var.ocir_auth_token == null ? "" : trimspace(var.ocir_auth_token)
  genai_model_id_normalized            = var.genai_model_id == null ? "" : trimspace(var.genai_model_id)
  genai_provider_normalized            = var.genai_provider == null ? "" : trimspace(var.genai_provider)
  genai_service_endpoint_normalized    = var.genai_service_endpoint == null ? "" : trimspace(var.genai_service_endpoint)

  devops_project_name_effective    = local.devops_project_name_normalized != "" ? local.devops_project_name_normalized : local.devops_project_name_default
  devops_server_image_uri          = "${lower(data.oci_identity_regions.current.regions[0].key)}.ocir.io/${data.oci_objectstorage_namespace.this.namespace}/${local.effective_mcp_container_repository_name}:${var.devops_image_tag}"
  devops_client_image_uri          = "${lower(data.oci_identity_regions.current.regions[0].key)}.ocir.io/${data.oci_objectstorage_namespace.this.namespace}/${local.effective_mcp_client_container_repository_name}:${var.devops_image_tag}"
  effective_genai_service_endpoint = local.genai_service_endpoint_normalized != "" ? local.genai_service_endpoint_normalized : "https://inference.generativeai.${var.region}.oci.oraclecloud.com"
  use_provided_ocir_auth_token     = local.ocir_auth_token_normalized != ""
  current_user_token_count         = var.enable_devops_pipeline ? try(length(data.oci_identity_auth_tokens.current_user_tokens[0].tokens), 0) : 0
  create_ocir_auth_token           = var.enable_devops_pipeline && !local.use_provided_ocir_auth_token && local.current_user_token_count < 2
  ocir_username                    = var.enable_devops_pipeline ? "${data.oci_objectstorage_namespace.this.namespace}/${data.oci_identity_user.current_user[0].name}" : ""
  ocir_password                    = local.use_provided_ocir_auth_token ? local.ocir_auth_token_normalized : (local.create_ocir_auth_token ? oci_identity_auth_token.ocir_pull[0].token : "")
  use_ocir_pull_secret             = var.enable_devops_pipeline && (local.use_provided_ocir_auth_token || local.create_ocir_auth_token)
  devops_logging_log_group_name    = "${local.resource_name_prefix}-devops-logs-${local.generated_name_suffix}"
  devops_logging_log_name          = "${local.resource_name_prefix}-devops-log-${local.generated_name_suffix}"
}

data "oci_identity_user" "current_user" {
  count   = var.enable_devops_pipeline ? 1 : 0
  user_id = local.current_user_ocid_normalized
}

data "oci_identity_auth_tokens" "current_user_tokens" {
  count   = var.enable_devops_pipeline ? 1 : 0
  user_id = local.current_user_ocid_normalized
}

resource "oci_identity_auth_token" "ocir_pull" {
  count       = local.create_ocir_auth_token ? 1 : 0
  provider    = oci.home
  description = "${local.resource_name_prefix}-ocir-pull-${local.generated_name_suffix}"
  user_id     = data.oci_identity_user.current_user[0].id
}

locals {
  effective_devops_server_secret_data = length(var.devops_server_secret_data) > 0 ? var.devops_server_secret_data : {
    STACK_BOOTSTRAP = "true"
  }
  effective_devops_client_secret_data = length(var.devops_client_secret_data) > 0 ? var.devops_client_secret_data : {
    STACK_BOOTSTRAP = "true"
  }

  server_secret_string_data_yaml = indent(2, chomp(yamlencode(local.effective_devops_server_secret_data)))
  client_secret_string_data_yaml = indent(2, chomp(yamlencode(local.effective_devops_client_secret_data)))

  ocir_auth_b64 = local.use_ocir_pull_secret ? base64encode("${local.ocir_username}:${local.ocir_password}") : ""

  ocir_secret_yaml = local.use_ocir_pull_secret ? chomp(<<-YAML
---
apiVersion: v1
kind: Secret
metadata:
  name: ocirsecret
  namespace: ${var.devops_deploy_namespace}
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ${base64encode(jsonencode({
    auths = {
      ("${lower(data.oci_identity_regions.current.regions[0].key)}.ocir.io") = {
        username = local.ocir_username
        password = local.ocir_password
        auth     = local.ocir_auth_b64
      }
    }
}))}
YAML
) : ""

image_pull_secrets_yaml = local.use_ocir_pull_secret ? chomp(<<-YAML
      imagePullSecrets:
        - name: ocirsecret
YAML
) : ""

devops_manifest_inline = <<-YAML
apiVersion: v1
kind: Namespace
metadata:
  name: ${var.devops_deploy_namespace}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fastmcp-server-sa
  namespace: ${var.devops_deploy_namespace}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fastmcp-client-sa
  namespace: ${var.devops_deploy_namespace}
---
apiVersion: v1
kind: Secret
metadata:
  name: mcp-secrets
  namespace: ${var.devops_deploy_namespace}
type: Opaque
stringData:
${local.server_secret_string_data_yaml}
---
apiVersion: v1
kind: Secret
metadata:
  name: mcp-client-secrets
  namespace: ${var.devops_deploy_namespace}
type: Opaque
stringData:
${local.client_secret_string_data_yaml}
${local.ocir_secret_yaml}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${local.server_service_name}
  namespace: ${var.devops_deploy_namespace}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${local.server_service_name}
  template:
    metadata:
      labels:
        app: ${local.server_service_name}
    spec:
      serviceAccountName: fastmcp-server-sa
${local.image_pull_secrets_yaml}
      containers:
        - name: fastmcp-server
          image: ${local.devops_server_image_uri}
          imagePullPolicy: Always
          envFrom:
            - secretRef:
                name: mcp-secrets
          env:
            - name: FASTMCP_APP_NAME
              value: mcp-audio
            - name: FASTMCP_HOST
              value: 0.0.0.0
            - name: FASTMCP_PORT
              value: "8080"
            - name: FASTMCP_TRANSPORT
              value: http
            - name: ENVIRONMENT
              value: PRD
            - name: OCI_REGION
              value: ${var.region}
            - name: COMPARTMENT_ID
              value: ${var.compartment_id}
            - name: OCI_NAMESPACE
              value: ${data.oci_objectstorage_namespace.this.namespace}
            - name: SPEECH_BUCKET
              value: ${local.effective_speech_bucket_name}
          ports:
            - name: http
              containerPort: 8080
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: ${local.server_service_name}
  namespace: ${var.devops_deploy_namespace}
spec:
  selector:
    app: ${local.server_service_name}
  ports:
    - name: http
      port: 80
      targetPort: http
  type: LoadBalancer
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${local.client_service_name}
  namespace: ${var.devops_deploy_namespace}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${local.client_service_name}
  template:
    metadata:
      labels:
        app: ${local.client_service_name}
    spec:
      serviceAccountName: fastmcp-client-sa
${local.image_pull_secrets_yaml}
      containers:
        - name: fastmcp-client
          image: ${local.devops_client_image_uri}
          imagePullPolicy: Always
          envFrom:
            - secretRef:
                name: mcp-client-secrets
          env:
            - name: ENVIRONMENT
              value: PRD
            - name: OCI_REGION
              value: ${var.region}
            - name: COMPARTMENT_ID
              value: ${var.compartment_id}
            - name: OCI_NAMESPACE
              value: ${data.oci_objectstorage_namespace.this.namespace}
            - name: SPEECH_BUCKET
              value: ${local.effective_speech_bucket_name}
            - name: MCP_URL
              value: http://${local.server_service_name}.${var.devops_deploy_namespace}.svc.cluster.local/mcp/
            - name: MCP_PUBLIC_URL
              value: http://${local.server_service_name}.${var.devops_deploy_namespace}.svc.cluster.local/mcp/
            - name: GRADIO_SERVER_NAME
              value: 0.0.0.0
            - name: GRADIO_SERVER_PORT
              value: "7860"
            - name: MODEL_ID
              value: ${var.genai_model_id}
            - name: PROVIDER
              value: ${var.genai_provider}
            - name: SERVICE_ENDPOINT
              value: ${local.effective_genai_service_endpoint}
            - name: MODEL_TEMPERATURE
              value: "0.0"
            - name: MODEL_MAX_TOKENS
              value: "8192"
          ports:
            - name: http
              containerPort: 7860
          readinessProbe:
            httpGet:
              path: /
              port: 7860
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 5
          livenessProbe:
            httpGet:
              path: /
              port: 7860
            initialDelaySeconds: 20
            periodSeconds: 20
            timeoutSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: ${local.client_service_name}
  namespace: ${var.devops_deploy_namespace}
spec:
  selector:
    app: ${local.client_service_name}
  ports:
    - name: http
      port: 80
      targetPort: http
  type: LoadBalancer
YAML
}

resource "oci_identity_policy" "devops_runtime_policy" {
  count    = var.enable_devops_pipeline && length(data.oci_identity_policies.devops_runtime_policy_lookup.policies) == 0 ? 1 : 0
  provider = oci.home

  # Keep DevOps service permissions scoped to the deployment compartment so
  # the stack can manage everything it is allowed to from Resource Manager.
  compartment_id = var.compartment_id
  name           = local.devops_runtime_policy_name
  description    = "Allow OCI DevOps managed build and deployment stages to operate in the MCP stack compartment."

  statements = [
    "Allow dynamic-group DevOpsDynamicGroup to manage repos in compartment id ${var.compartment_id}",
    "Allow dynamic-group DevOpsDynamicGroup to inspect repos in compartment id ${var.compartment_id}",
    "Allow dynamic-group DevOpsDynamicGroup to use repos in compartment id ${var.compartment_id}",
    "Allow dynamic-group DevOpsDynamicGroup to manage devops-family in compartment id ${var.compartment_id}",
    "Allow dynamic-group DevOpsDynamicGroup to read all-artifacts in compartment id ${var.compartment_id}",
    "Allow dynamic-group DevOpsDynamicGroup to manage cluster in compartment id ${var.compartment_id}",
    "Allow dynamic-group DevOpsDynamicGroup to use ons-topics in compartment id ${var.compartment_id}",
  ]
}

resource "oci_devops_project" "mcp" {
  count = var.enable_devops_pipeline ? 1 : 0

  compartment_id = var.compartment_id
  name           = local.devops_project_name_effective
  description    = "OCI DevOps project for MCP one-click build and deploy flow"

  notification_config {
    topic_id = local.devops_notification_topic_normalized != "" ? local.devops_notification_topic_normalized : oci_ons_notification_topic.devops[0].id
  }
}

resource "oci_ons_notification_topic" "devops" {
  count = var.enable_devops_pipeline && local.devops_notification_topic_normalized == "" ? 1 : 0

  compartment_id = var.compartment_id
  name           = "${local.resource_name_prefix}-devops-topic-${local.generated_name_suffix}"
  description    = "Notification topic for MCP OCI DevOps project events"
}

data "oci_logging_log_groups" "devops" {
  compartment_id = var.compartment_id
  display_name   = local.devops_logging_log_group_name
}

locals {
  devops_logging_log_group_exists = length(data.oci_logging_log_groups.devops.log_groups) > 0
  devops_logging_log_group_id     = local.devops_logging_log_group_exists ? data.oci_logging_log_groups.devops.log_groups[0].id : oci_logging_log_group.devops[0].id
}

resource "oci_logging_log_group" "devops" {
  count          = var.enable_devops_pipeline && !local.devops_logging_log_group_exists ? 1 : 0
  compartment_id = var.compartment_id
  display_name   = local.devops_logging_log_group_name
  description    = "Log group for MCP OCI DevOps project logs"
}

data "oci_logging_logs" "devops" {
  count          = local.devops_logging_log_group_exists ? 1 : 0
  log_group_id   = local.devops_logging_log_group_id
  display_name   = local.devops_logging_log_name
  log_type       = "SERVICE"
  source_service = "devops"
  state          = "ACTIVE"
}

locals {
  devops_logging_log_exists = local.devops_logging_log_group_exists ? length(data.oci_logging_logs.devops[0].logs) > 0 : false
}

resource "oci_logging_log" "devops" {
  count        = var.enable_devops_pipeline && !local.devops_logging_log_exists ? 1 : 0
  display_name = local.devops_logging_log_name
  log_group_id = local.devops_logging_log_group_id
  log_type     = "SERVICE"
  is_enabled   = true

  configuration {
    compartment_id = var.compartment_id
    source {
      category    = "all"
      resource    = oci_devops_project.mcp[0].id
      service     = "devops"
      source_type = "OCISERVICE"
    }
  }
}

resource "oci_devops_deploy_environment" "oke" {
  count = var.enable_devops_pipeline ? 1 : 0

  project_id              = oci_devops_project.mcp[0].id
  deploy_environment_type = "OKE_CLUSTER"
  display_name            = "${local.resource_name_prefix}-oke-env-${local.generated_name_suffix}"
  description             = "OKE deployment environment for MCP workloads"
  cluster_id              = module.oke_virtual_nodes.cluster_id
}

resource "oci_devops_deploy_artifact" "server_image" {
  count = var.enable_devops_pipeline ? 1 : 0

  project_id                 = oci_devops_project.mcp[0].id
  display_name               = "${local.resource_name_prefix}-server-image-${local.generated_name_suffix}"
  description                = "Target OCIR artifact for the MCP server image"
  deploy_artifact_type       = "DOCKER_IMAGE"
  argument_substitution_mode = "NONE"

  deploy_artifact_source {
    deploy_artifact_source_type = "OCIR"
    image_uri                   = local.devops_server_image_uri
  }
}

resource "oci_devops_deploy_artifact" "client_image" {
  count = var.enable_devops_pipeline ? 1 : 0

  project_id                 = oci_devops_project.mcp[0].id
  display_name               = "${local.resource_name_prefix}-client-image-${local.generated_name_suffix}"
  description                = "Target OCIR artifact for the MCP client image"
  deploy_artifact_type       = "DOCKER_IMAGE"
  argument_substitution_mode = "NONE"

  deploy_artifact_source {
    deploy_artifact_source_type = "OCIR"
    image_uri                   = local.devops_client_image_uri
  }
}

resource "oci_devops_deploy_artifact" "k8s_manifest" {
  count = var.enable_devops_pipeline ? 1 : 0

  project_id                 = oci_devops_project.mcp[0].id
  display_name               = "${local.resource_name_prefix}-k8s-manifest-${local.generated_name_suffix}"
  description                = "Kubernetes manifest artifact for MCP server and client"
  deploy_artifact_type       = "KUBERNETES_MANIFEST"
  argument_substitution_mode = "NONE"

  deploy_artifact_source {
    deploy_artifact_source_type = "INLINE"
    base64encoded_content       = base64encode(local.devops_manifest_inline)
  }
}

resource "oci_devops_deploy_pipeline" "mcp" {
  count = var.enable_devops_pipeline ? 1 : 0

  project_id   = oci_devops_project.mcp[0].id
  display_name = var.devops_deploy_pipeline_name
  description  = "Deploy pipeline for MCP workloads on OKE"
}

resource "oci_devops_deploy_stage" "oke_deploy" {
  count = var.enable_devops_pipeline ? 1 : 0

  deploy_pipeline_id                      = oci_devops_deploy_pipeline.mcp[0].id
  deploy_stage_type                       = "OKE_DEPLOYMENT"
  display_name                            = "deploy-mcp-to-oke"
  description                             = "Deploys MCP workloads to the configured OKE cluster"
  oke_cluster_deploy_environment_id       = oci_devops_deploy_environment.oke[0].id
  kubernetes_manifest_deploy_artifact_ids = [oci_devops_deploy_artifact.k8s_manifest[0].id]
  namespace                               = var.devops_deploy_namespace

  deploy_stage_predecessor_collection {
    items {
      id = oci_devops_deploy_pipeline.mcp[0].id
    }
  }
}

resource "oci_devops_build_pipeline" "mcp" {
  count = var.enable_devops_pipeline ? 1 : 0

  project_id   = oci_devops_project.mcp[0].id
  display_name = var.devops_build_pipeline_name
  description  = "Build pipeline for MCP container images"
}

resource "oci_devops_build_pipeline_stage" "build_images" {
  count = var.enable_devops_pipeline ? 1 : 0

  build_pipeline_id                  = oci_devops_build_pipeline.mcp[0].id
  build_pipeline_stage_type          = "BUILD"
  display_name                       = "build-images"
  description                        = "Builds the MCP server and client container images"
  build_spec_file                    = var.devops_build_spec_path
  image                              = var.devops_build_stage_image
  primary_build_source               = "app-repo"
  stage_execution_timeout_in_seconds = var.devops_stage_timeout_seconds

  build_pipeline_stage_predecessor_collection {
    items {
      id = oci_devops_build_pipeline.mcp[0].id
    }
  }

  build_source_collection {
    items {
      connection_type = "DEVOPS_CODE_REPOSITORY"
      repository_id   = local.devops_repository_id_normalized
      repository_url  = local.devops_repository_url_normalized
      branch          = var.devops_source_branch
      name            = "app-repo"
    }
  }
}

resource "oci_devops_build_pipeline_stage" "deliver_images" {
  count = var.enable_devops_pipeline ? 1 : 0

  build_pipeline_id         = oci_devops_build_pipeline.mcp[0].id
  build_pipeline_stage_type = "DELIVER_ARTIFACT"
  display_name              = "deliver-images"
  description               = "Delivers the built server and client images to OCIR"

  build_pipeline_stage_predecessor_collection {
    items {
      id = oci_devops_build_pipeline_stage.build_images[0].id
    }
  }

  deliver_artifact_collection {
    items {
      artifact_id   = oci_devops_deploy_artifact.server_image[0].id
      artifact_name = "mcp-server-image"
    }
    items {
      artifact_id   = oci_devops_deploy_artifact.client_image[0].id
      artifact_name = "mcp-client-image"
    }
  }
}

resource "oci_devops_build_pipeline_stage" "trigger_deploy" {
  count = var.enable_devops_pipeline ? 1 : 0

  build_pipeline_id              = oci_devops_build_pipeline.mcp[0].id
  build_pipeline_stage_type      = "TRIGGER_DEPLOYMENT_PIPELINE"
  display_name                   = "trigger-deploy-pipeline"
  description                    = "Triggers OKE deployment after image delivery"
  deploy_pipeline_id             = oci_devops_deploy_pipeline.mcp[0].id
  is_pass_all_parameters_enabled = false

  build_pipeline_stage_predecessor_collection {
    items {
      id = oci_devops_build_pipeline_stage.deliver_images[0].id
    }
  }
}

resource "oci_devops_build_run" "initial" {
  count = var.enable_devops_pipeline && var.devops_trigger_initial_build ? 1 : 0

  build_pipeline_id = oci_devops_build_pipeline.mcp[0].id
  display_name      = "initial-mcp-build-run"

  depends_on = [
    oci_logging_log.devops,
    oci_identity_policy.devops_runtime_policy,
    oci_devops_build_pipeline_stage.trigger_deploy,
  ]
}
