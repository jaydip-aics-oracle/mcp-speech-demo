check "devops_pipeline_inputs" {
  assert {
    condition = !local.use_devops_build_pipeline || (
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
    condition = !local.use_devops_build_pipeline || (
      (var.current_user_ocid == null ? "" : trimspace(var.current_user_ocid)) != "" &&
      (local.use_provided_ocir_auth_token || local.current_user_token_count < 2)
    )
    error_message = "Set current_user_ocid. If the current user already has 2 OCI auth tokens, also provide ocir_auth_token."
  }
}

check "quick_deploy_image_inputs" {
  assert {
    condition = !local.use_quick_deploy_mode || (
      local.prebuilt_server_image_uri_normalized != "" &&
      local.prebuilt_client_image_uri_normalized != ""
    )
    error_message = "Set prebuilt_server_image_uri and prebuilt_client_image_uri for quick_deploy mode."
  }
}

locals {
  deployment_mode_normalized          = lower(trimspace(var.deployment_mode))
  use_infra_only_mode                 = local.deployment_mode_normalized == "infra_only"
  use_devops_build_pipeline           = !local.use_infra_only_mode && (local.deployment_mode_normalized == "oci_devops" || var.enable_devops_pipeline)
  use_quick_deploy_mode               = !local.use_infra_only_mode && !local.use_devops_build_pipeline
  use_app_deploy                      = local.use_quick_deploy_mode || local.use_devops_build_pipeline
  use_devops_deploy_pipeline          = local.use_app_deploy
  devops_repository_id_normalized      = var.devops_repository_id == null ? "" : trimspace(var.devops_repository_id)
  devops_repository_url_normalized     = var.devops_repository_url == null ? "" : trimspace(var.devops_repository_url)
  devops_project_name_normalized       = var.devops_project_name == null ? "" : trimspace(var.devops_project_name)
  devops_notification_topic_normalized = var.devops_notification_topic_id == null ? "" : trimspace(var.devops_notification_topic_id)
  current_user_ocid_normalized         = var.current_user_ocid == null ? "" : trimspace(var.current_user_ocid)
  ocir_auth_token_normalized           = var.ocir_auth_token == null ? "" : trimspace(var.ocir_auth_token)
  genai_model_id_normalized            = var.genai_model_id == null ? "" : trimspace(var.genai_model_id)
  genai_provider_normalized            = var.genai_provider == null ? "" : trimspace(var.genai_provider)
  genai_service_endpoint_normalized    = var.genai_service_endpoint == null ? "" : trimspace(var.genai_service_endpoint)
  prebuilt_server_image_uri_normalized = trimspace(var.prebuilt_server_image_uri)
  prebuilt_client_image_uri_normalized = trimspace(var.prebuilt_client_image_uri)

  devops_project_name_effective    = local.devops_project_name_normalized != "" ? local.devops_project_name_normalized : local.devops_project_name_default
  devops_server_image_uri          = "${lower(data.oci_identity_regions.current.regions[0].key)}.ocir.io/${data.oci_objectstorage_namespace.this.namespace}/${local.effective_mcp_container_repository_name}:${var.devops_image_tag}"
  devops_client_image_uri          = "${lower(data.oci_identity_regions.current.regions[0].key)}.ocir.io/${data.oci_objectstorage_namespace.this.namespace}/${local.effective_mcp_client_container_repository_name}:${var.devops_image_tag}"
  effective_server_image_uri       = local.use_devops_build_pipeline ? local.devops_server_image_uri : (local.use_quick_deploy_mode ? local.prebuilt_server_image_uri_normalized : "")
  effective_client_image_uri       = local.use_devops_build_pipeline ? local.devops_client_image_uri : (local.use_quick_deploy_mode ? local.prebuilt_client_image_uri_normalized : "")
  effective_genai_service_endpoint = local.genai_service_endpoint_normalized != "" ? local.genai_service_endpoint_normalized : "https://inference.generativeai.${var.region}.oci.oraclecloud.com"
  use_provided_ocir_auth_token     = local.ocir_auth_token_normalized != ""
  current_user_token_count         = local.use_devops_build_pipeline ? try(length(data.oci_identity_auth_tokens.current_user_tokens[0].tokens), 0) : 0
  create_ocir_auth_token           = local.use_devops_build_pipeline && !local.use_provided_ocir_auth_token && local.current_user_token_count < 2
  ocir_username                    = local.use_devops_build_pipeline ? "${data.oci_objectstorage_namespace.this.namespace}/${data.oci_identity_user.current_user[0].name}" : ""
  ocir_password                    = local.use_provided_ocir_auth_token ? local.ocir_auth_token_normalized : (local.create_ocir_auth_token ? oci_identity_auth_token.ocir_pull[0].token : "")
  use_ocir_pull_secret             = local.use_devops_build_pipeline && (local.use_provided_ocir_auth_token || local.create_ocir_auth_token)
  devops_logging_log_group_name    = "${local.resource_name_prefix}-devops-logs-${local.generated_name_suffix}"
  devops_logging_log_name          = "${local.resource_name_prefix}-devops-log-${local.generated_name_suffix}"
}

data "oci_identity_user" "current_user" {
  count   = local.use_devops_build_pipeline ? 1 : 0
  user_id = local.current_user_ocid_normalized
}

data "oci_identity_auth_tokens" "current_user_tokens" {
  count   = local.use_devops_build_pipeline ? 1 : 0
  user_id = local.current_user_ocid_normalized
}

resource "oci_identity_auth_token" "ocir_pull" {
  count       = local.create_ocir_auth_token ? 1 : 0
  provider    = oci.home
  description = "${local.resource_name_prefix}-ocir-pull-${local.generated_name_suffix}"
  user_id     = data.oci_identity_user.current_user[0].id
}

locals {
  devops_server_secret_json_normalized = var.devops_server_secret_json == null ? "" : trimspace(var.devops_server_secret_json)
  devops_client_secret_json_normalized = var.devops_client_secret_json == null ? "" : trimspace(var.devops_client_secret_json)

  devops_server_secret_json_data = local.devops_server_secret_json_normalized != "" ? {
    for key, value in tomap(jsondecode(local.devops_server_secret_json_normalized)) :
    tostring(key) => tostring(value)
  } : {}
  devops_client_secret_json_data = local.devops_client_secret_json_normalized != "" ? {
    for key, value in tomap(jsondecode(local.devops_client_secret_json_normalized)) :
    tostring(key) => tostring(value)
  } : {}

  server_default_secret_data = {
    STACK_BOOTSTRAP            = "true"
    SPEECH_MODEL_TYPE          = "WHISPER_LARGE_V3T"
    SPEECH_LANGUAGE_CODE       = "auto"
    SPEECH_WHISPER_PROMPT      = "This is a customer support conversation."
    SPEECH_DIARIZATION_ENABLED = "true"
  }
  server_runtime_secret_data = {
    FASTMCP_APP_NAME  = "mcp-audio"
    FASTMCP_HOST      = "0.0.0.0"
    FASTMCP_PORT      = "8080"
    FASTMCP_TRANSPORT = "http"
    ENVIRONMENT       = "PRD"
    OCI_REGION        = var.region
    COMPARTMENT_ID    = var.compartment_id
    OCI_NAMESPACE     = data.oci_objectstorage_namespace.this.namespace
    SPEECH_BUCKET     = local.effective_speech_bucket_name
  }
  effective_devops_server_secret_data = merge(
    local.server_default_secret_data,
    var.devops_server_secret_data,
    local.devops_server_secret_json_data,
    local.server_runtime_secret_data,
  )

  client_default_secret_data = {
    STACK_BOOTSTRAP       = "true"
    MODEL_TEMPERATURE     = tostring(var.genai_model_temperature)
    MODEL_MAX_TOKENS      = tostring(var.genai_model_max_tokens)
    AGENT_RECURSION_LIMIT = "40"
    AGENT_MAX_CONCURRENCY = "8"
    AGENT_TOOL_RUN_LIMIT  = "36"
  }
  client_runtime_secret_data = {
    ENVIRONMENT        = "PRD"
    OCI_REGION         = var.region
    COMPARTMENT_ID     = var.compartment_id
    OCI_NAMESPACE      = data.oci_objectstorage_namespace.this.namespace
    SPEECH_BUCKET      = local.effective_speech_bucket_name
    MCP_URL            = "http://${local.server_service_name}.${var.devops_deploy_namespace}.svc.cluster.local/mcp/"
    MCP_PUBLIC_URL     = "http://${local.server_service_name}.${var.devops_deploy_namespace}.svc.cluster.local/mcp/"
    GRADIO_SERVER_NAME = "0.0.0.0"
    GRADIO_SERVER_PORT = "7860"
    MODEL_ID           = var.genai_model_id
    PROVIDER           = var.genai_provider
    SERVICE_ENDPOINT   = local.effective_genai_service_endpoint
  }
  effective_devops_client_secret_data = merge(
    local.client_default_secret_data,
    var.devops_client_secret_data,
    local.devops_client_secret_json_data,
    local.client_runtime_secret_data,
  )

  server_secret_string_data_yaml = join("\n", [
    for line in split("\n", chomp(yamlencode(local.effective_devops_server_secret_data))) :
    "  ${line}"
  ])
  client_secret_string_data_yaml = join("\n", [
    for line in split("\n", chomp(yamlencode(local.effective_devops_client_secret_data))) :
    "  ${line}"
  ])

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

image_pull_secrets_yaml = local.use_ocir_pull_secret ? join("\n", [
  "      imagePullSecrets:",
  "        - name: ocirsecret",
]) : ""

devops_namespace_manifest_inline = <<-YAML
apiVersion: v1
kind: Namespace
metadata:
  name: ${var.devops_deploy_namespace}
YAML

devops_workload_manifest_inline = <<-YAML
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
          image: ${local.effective_server_image_uri}
          imagePullPolicy: Always
          envFrom:
            - secretRef:
                name: mcp-secrets
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
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
      protocol: TCP
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
          image: ${local.effective_client_image_uri}
          imagePullPolicy: Always
          envFrom:
            - secretRef:
                name: mcp-client-secrets
          ports:
            - name: http
              containerPort: 7860
              protocol: TCP
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
      protocol: TCP
  type: LoadBalancer
YAML
}

resource "oci_identity_policy" "devops_build_runtime_policy" {
  count    = local.use_devops_build_pipeline ? 1 : 0
  provider = oci.home

  compartment_id = var.compartment_id
  name           = local.devops_build_runtime_policy_name
  description    = "Allow the OCI DevOps build pipeline principal to build and deliver MCP images within the deployment compartment."

  statements = [
    "Allow any-user to inspect repos in compartment id ${var.compartment_id} where all { request.principal.type = 'devopsbuildpipeline', request.principal.id = '${oci_devops_build_pipeline.mcp[0].id}' }",
    "Allow any-user to use repos in compartment id ${var.compartment_id} where all { request.principal.type = 'devopsbuildpipeline', request.principal.id = '${oci_devops_build_pipeline.mcp[0].id}' }",
    "Allow any-user to manage repos in compartment id ${var.compartment_id} where all { request.principal.type = 'devopsbuildpipeline', request.principal.id = '${oci_devops_build_pipeline.mcp[0].id}' }",
    "Allow any-user to manage devops-family in compartment id ${var.compartment_id} where all { request.principal.type = 'devopsbuildpipeline', request.principal.id = '${oci_devops_build_pipeline.mcp[0].id}' }",
    "Allow any-user to read all-artifacts in compartment id ${var.compartment_id} where all { request.principal.type = 'devopsbuildpipeline', request.principal.id = '${oci_devops_build_pipeline.mcp[0].id}' }",
    "Allow any-user to use ons-topics in compartment id ${var.compartment_id} where all { request.principal.type = 'devopsbuildpipeline', request.principal.id = '${oci_devops_build_pipeline.mcp[0].id}' }",
    "Allow any-user to manage cluster in compartment id ${var.compartment_id} where all { request.principal.type = 'devopsbuildpipeline', request.principal.id = '${oci_devops_build_pipeline.mcp[0].id}' }",
  ]
}

resource "oci_identity_policy" "devops_deploy_runtime_policy" {
  count    = local.use_devops_deploy_pipeline ? 1 : 0
  provider = oci.home

  compartment_id = var.compartment_id
  name           = local.devops_deploy_runtime_policy_name
  description    = "Allow the OCI DevOps deploy pipeline principal to deploy the MCP workload to OKE within the deployment compartment."

  statements = [
    "Allow any-user to read all-artifacts in compartment id ${var.compartment_id} where all { request.principal.type = 'devopsdeploypipeline', request.principal.id = '${oci_devops_deploy_pipeline.mcp[0].id}' }",
    "Allow any-user to manage cluster in compartment id ${var.compartment_id} where all { request.principal.type = 'devopsdeploypipeline', request.principal.id = '${oci_devops_deploy_pipeline.mcp[0].id}' }",
  ]
}

resource "oci_devops_project" "mcp" {
  count = local.use_devops_deploy_pipeline ? 1 : 0

  compartment_id = var.compartment_id
  name           = local.devops_project_name_effective
  description    = "OCI DevOps project for MCP one-click build and deploy flow"

  notification_config {
    topic_id = local.devops_notification_topic_normalized != "" ? local.devops_notification_topic_normalized : oci_ons_notification_topic.devops[0].id
  }
}

resource "oci_ons_notification_topic" "devops" {
  count = local.use_devops_deploy_pipeline && local.devops_notification_topic_normalized == "" ? 1 : 0

  compartment_id = var.compartment_id
  name           = "${local.resource_name_prefix}-devops-topic-${local.generated_name_suffix}"
  description    = "Notification topic for MCP OCI DevOps project events"
}

resource "oci_logging_log_group" "devops" {
  count          = local.use_devops_deploy_pipeline ? 1 : 0
  compartment_id = var.compartment_id
  display_name   = local.devops_logging_log_group_name
  description    = "Log group for MCP OCI DevOps project logs"
}

resource "oci_logging_log" "devops" {
  count        = local.use_devops_deploy_pipeline ? 1 : 0
  display_name = local.devops_logging_log_name
  log_group_id = oci_logging_log_group.devops[0].id
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
  count = local.use_devops_deploy_pipeline ? 1 : 0

  project_id              = oci_devops_project.mcp[0].id
  deploy_environment_type = "OKE_CLUSTER"
  display_name            = "${local.resource_name_prefix}-oke-env-${local.generated_name_suffix}"
  description             = "OKE deployment environment for MCP workloads"
  cluster_id              = module.oke_virtual_nodes.cluster_id
}

resource "oci_devops_deploy_artifact" "server_image" {
  count = local.use_devops_build_pipeline ? 1 : 0

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
  count = local.use_devops_build_pipeline ? 1 : 0

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
  count = local.use_devops_deploy_pipeline ? 1 : 0

  project_id                 = oci_devops_project.mcp[0].id
  display_name               = "${local.resource_name_prefix}-k8s-manifest-${local.generated_name_suffix}"
  description                = "Kubernetes manifest artifact for MCP server and client"
  deploy_artifact_type       = "KUBERNETES_MANIFEST"
  argument_substitution_mode = "NONE"

  deploy_artifact_source {
    deploy_artifact_source_type = "INLINE"
    base64encoded_content       = base64encode(local.devops_workload_manifest_inline)
  }
}

resource "oci_devops_deploy_artifact" "k8s_namespace_manifest" {
  count = local.use_devops_deploy_pipeline ? 1 : 0

  project_id                 = oci_devops_project.mcp[0].id
  display_name               = "${local.resource_name_prefix}-k8s-namespace-${local.generated_name_suffix}"
  description                = "Kubernetes namespace manifest artifact for MCP workloads"
  deploy_artifact_type       = "KUBERNETES_MANIFEST"
  argument_substitution_mode = "NONE"

  deploy_artifact_source {
    deploy_artifact_source_type = "INLINE"
    base64encoded_content       = base64encode(local.devops_namespace_manifest_inline)
  }
}

resource "oci_devops_deploy_pipeline" "mcp" {
  count = local.use_devops_deploy_pipeline ? 1 : 0

  project_id   = oci_devops_project.mcp[0].id
  display_name = var.devops_deploy_pipeline_name
  description  = "Deploy pipeline for MCP workloads on OKE"
}

resource "oci_devops_deploy_stage" "oke_namespace" {
  count = local.use_devops_deploy_pipeline ? 1 : 0

  deploy_pipeline_id                      = oci_devops_deploy_pipeline.mcp[0].id
  deploy_stage_type                       = "OKE_DEPLOYMENT"
  display_name                            = "create-mcp-namespace"
  description                             = "Creates the Kubernetes namespace used for MCP workloads"
  oke_cluster_deploy_environment_id       = oci_devops_deploy_environment.oke[0].id
  kubernetes_manifest_deploy_artifact_ids = [oci_devops_deploy_artifact.k8s_namespace_manifest[0].id]
  namespace                               = "default"

  deploy_stage_predecessor_collection {
    items {
      id = oci_devops_deploy_pipeline.mcp[0].id
    }
  }
}

resource "oci_devops_deploy_stage" "oke_deploy" {
  count = local.use_devops_deploy_pipeline ? 1 : 0

  deploy_pipeline_id                      = oci_devops_deploy_pipeline.mcp[0].id
  deploy_stage_type                       = "OKE_DEPLOYMENT"
  display_name                            = "deploy-mcp-to-oke"
  description                             = "Deploys MCP workloads to the configured OKE cluster"
  oke_cluster_deploy_environment_id       = oci_devops_deploy_environment.oke[0].id
  kubernetes_manifest_deploy_artifact_ids = [oci_devops_deploy_artifact.k8s_manifest[0].id]
  namespace                               = var.devops_deploy_namespace

  deploy_stage_predecessor_collection {
    items {
      id = oci_devops_deploy_stage.oke_namespace[0].id
    }
  }
}

resource "oci_devops_build_pipeline" "mcp" {
  count = local.use_devops_build_pipeline ? 1 : 0

  project_id   = oci_devops_project.mcp[0].id
  display_name = var.devops_build_pipeline_name
  description  = "Build pipeline for MCP container images"
}

resource "oci_devops_build_pipeline_stage" "build_images" {
  count = local.use_devops_build_pipeline ? 1 : 0

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
  count = local.use_devops_build_pipeline ? 1 : 0

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
  count = local.use_devops_build_pipeline ? 1 : 0

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

resource "terraform_data" "initial_build_run_nonce" {
  count = local.use_devops_build_pipeline ? 1 : 0

  input = plantimestamp()
}

resource "oci_devops_build_run" "initial" {
  count = local.use_devops_build_pipeline ? 1 : 0

  build_pipeline_id = oci_devops_build_pipeline.mcp[0].id
  display_name      = "initial-mcp-build-run"

  lifecycle {
    replace_triggered_by = [terraform_data.initial_build_run_nonce[0]]
  }

  depends_on = [
    oci_logging_log.devops,
    oci_identity_policy.devops_build_runtime_policy,
    oci_identity_policy.devops_deploy_runtime_policy,
    module.oke_virtual_nodes,
    oci_devops_deploy_environment.oke,
    oci_devops_deploy_stage.oke_namespace,
    oci_devops_deploy_stage.oke_deploy,
    oci_devops_build_pipeline_stage.trigger_deploy,
  ]
}

resource "terraform_data" "initial_deployment_nonce" {
  count = local.use_quick_deploy_mode ? 1 : 0

  input = plantimestamp()
}

resource "oci_devops_deployment" "initial" {
  count = local.use_quick_deploy_mode ? 1 : 0

  deploy_pipeline_id            = oci_devops_deploy_pipeline.mcp[0].id
  deployment_type               = "PIPELINE_DEPLOYMENT"
  display_name                  = "initial-mcp-quick-deployment"
  trigger_new_devops_deployment = true

  lifecycle {
    replace_triggered_by = [terraform_data.initial_deployment_nonce[0]]
  }

  depends_on = [
    oci_logging_log.devops,
    oci_identity_policy.devops_deploy_runtime_policy,
    module.oke_virtual_nodes,
    oci_devops_deploy_environment.oke,
    oci_devops_deploy_stage.oke_namespace,
    oci_devops_deploy_stage.oke_deploy,
  ]
}
