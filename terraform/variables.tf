# variables.tf

variable "tenancy_ocid" {
  description = "The OCID of your tenancy."
}

variable "region" {
  description = "The OCI region where resources will be created."
  type        = string
}

variable "home_region" {
  description = "Optional OCI home region override for identity resources. When omitted, Terraform derives the tenancy home region automatically."
  type        = string
  default     = null
  nullable    = true
}

variable "compartment_id" {
  description = "The OCID of the compartment to create resources in."
  type        = string
}

variable "resource_name_prefix" {
  description = "Prefix used for generated repository and bucket names."
  type        = string
  default     = "mcp"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.resource_name_prefix))
    error_message = "resource_name_prefix must start with a lowercase letter or digit and contain only lowercase letters, digits, and hyphens."
  }
}

variable "mcp_container_repository_name" {
  description = "Optional base name for the MCP server OCIR repository. The final name always includes the shared prefix and compartment suffix."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = (var.mcp_container_repository_name == null ? "" : trimspace(var.mcp_container_repository_name)) == "" || can(regex("^[a-z0-9][a-z0-9-]*$", var.mcp_container_repository_name == null ? "" : trimspace(var.mcp_container_repository_name)))
    error_message = "mcp_container_repository_name must be lowercase letters, digits, and hyphens when provided."
  }
}

variable "mcp_client_container_repository_name" {
  description = "Optional base name for the MCP client OCIR repository. The final name always includes the shared prefix and compartment suffix."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = (var.mcp_client_container_repository_name == null ? "" : trimspace(var.mcp_client_container_repository_name)) == "" || can(regex("^[a-z0-9][a-z0-9-]*$", var.mcp_client_container_repository_name == null ? "" : trimspace(var.mcp_client_container_repository_name)))
    error_message = "mcp_client_container_repository_name must be lowercase letters, digits, and hyphens when provided."
  }
}

variable "kubernetes_version" {
  description = "The version of Kubernetes to use for the OKE cluster."
  default     = "v1.33.1"
}

variable "cluster_name" {
  description = "The name of the OKE cluster."
  default     = "oke-cluster"
}

variable "control_subnet_cidr_block" {
  description = "The CIDR block for the control subnet."
  default     = "10.0.0.0/28"
}

variable "data_subnet_cidr_block" {
  description = "The CIDR block for the data subnet."
  default     = "10.0.16.0/20"
}

variable "load_balancer_subnet_cidr_block" {
  description = "The CIDR block for the public subnet."
  default     = "10.0.32.0/24"
}

variable "speech_bucket_name" {
  description = "Optional base name for the Speech Object Storage bucket. The final name always includes the shared prefix and compartment suffix."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = (var.speech_bucket_name == null ? "" : trimspace(var.speech_bucket_name)) == "" || can(regex("^[a-z0-9][a-z0-9-]*$", var.speech_bucket_name == null ? "" : trimspace(var.speech_bucket_name)))
    error_message = "speech_bucket_name must be lowercase letters, digits, and hyphens when provided."
  }
}

variable "deployment_mode" {
  description = "Application deployment mode. infra_only provisions only infrastructure, quick_deploy uses prebuilt public images, and oci_devops rebuilds from a user-provided OCI DevOps repository."
  type        = string
  default     = "quick_deploy"

  validation {
    condition     = contains(["infra_only", "quick_deploy", "oci_devops"], lower(trimspace(var.deployment_mode)))
    error_message = "deployment_mode must be one of infra_only, quick_deploy, or oci_devops."
  }
}

variable "prebuilt_server_image_uri" {
  description = "Public image URI used for quick_deploy mode for the MCP server."
  type        = string
  default     = "ghcr.io/jaydip-aics-oracle/mcp-speech-demo-audio:latest"
}

variable "prebuilt_client_image_uri" {
  description = "Public image URI used for quick_deploy mode for the MCP client."
  type        = string
  default     = "ghcr.io/jaydip-aics-oracle/mcp-speech-demo-client:latest"
}

variable "enable_devops_pipeline" {
  description = "Deprecated compatibility toggle for advanced OCI DevOps source builds. Prefer deployment_mode."
  type        = bool
  default     = false
}

variable "devops_project_name" {
  description = "Optional name override for the OCI DevOps project."
  type        = string
  default     = null
  nullable    = true
}

variable "devops_notification_topic_id" {
  description = "Optional existing ONS topic OCID for OCI DevOps project notifications. When omitted and DevOps is enabled, a topic is created."
  type        = string
  default     = null
  nullable    = true
}

variable "devops_build_pipeline_name" {
  description = "Display name for the OCI DevOps build pipeline."
  type        = string
  default     = "mcp-build-pipeline"
}

variable "devops_deploy_pipeline_name" {
  description = "Display name for the OCI DevOps deployment pipeline."
  type        = string
  default     = "mcp-deploy-pipeline"
}

variable "devops_repository_id" {
  description = "OCI DevOps repository OCID used as source for build pipeline stages."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = (var.devops_repository_id == null ? "" : trimspace(var.devops_repository_id)) == "" || can(regex("^ocid1\\.devopsrepository\\.", var.devops_repository_id == null ? "" : trimspace(var.devops_repository_id)))
    error_message = "devops_repository_id must be an OCI DevOps repository OCID."
  }
}

variable "devops_repository_url" {
  description = "Clone URL for the OCI DevOps repository used by the managed build stage."
  type        = string
  default     = null
  nullable    = true
}

variable "devops_source_branch" {
  description = "Repository branch used by OCI DevOps build stages."
  type        = string
  default     = "one-click-deployment"
}

variable "devops_build_spec_path" {
  description = "Path (from repository root) to OCI DevOps build spec file."
  type        = string
  default     = "build_spec.yaml"
}

variable "devops_build_stage_image" {
  description = "Managed build runner image used by OCI DevOps BUILD stage."
  type        = string
  default     = "OL8_X86_64_STANDARD_10"
}

variable "devops_stage_timeout_seconds" {
  description = "Timeout in seconds for OCI DevOps build stages."
  type        = number
  default     = 3600
}

variable "devops_deploy_namespace" {
  description = "Kubernetes namespace used by OCI DevOps OKE deployment stage."
  type        = string
  default     = "mcp"
}

variable "devops_image_tag" {
  description = "Container image tag built and deployed by OCI DevOps."
  type        = string
  default     = "latest"
}

variable "devops_trigger_initial_build" {
  description = "Deprecated compatibility flag. End-to-end reruns are controlled by deployment_mode and the generated apply nonces."
  type        = bool
  default     = true
}

variable "current_user_ocid" {
  description = "Current OCI user OCID used for OCIR auth token lookup/creation. Provide explicitly in UI/ZIP flows to avoid auto-population gaps."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = (var.current_user_ocid == null ? "" : trimspace(var.current_user_ocid)) == "" || can(regex("^ocid1\\.user\\.", var.current_user_ocid == null ? "" : trimspace(var.current_user_ocid)))
    error_message = "current_user_ocid must be an OCI user OCID."
  }
}

variable "ocir_auth_token" {
  description = "Optional existing OCIR auth token fallback. Only needed if the current user has already reached the auth token quota."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "devops_server_secret_data" {
  description = "Key/value pairs rendered into Kubernetes secret mcp-secrets for the server deployment."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "devops_server_secret_json" {
  description = "Optional JSON object of additional secret env vars for the server deployment. Useful for UI/ZIP stack inputs."
  type        = string
  default     = "{\"SPEECH_MODEL_TYPE\":\"WHISPER_LARGE_V3T\",\"SPEECH_LANGUAGE_CODE\":\"auto\",\"SPEECH_WHISPER_PROMPT\":\"This is a customer support conversation.\",\"SPEECH_DIARIZATION_ENABLED\":\"true\"}"
  nullable    = true
  sensitive   = true

  validation {
    condition     = (var.devops_server_secret_json == null ? "" : trimspace(var.devops_server_secret_json)) == "" || can(tomap(jsondecode(trimspace(var.devops_server_secret_json))))
    error_message = "devops_server_secret_json must be empty or a valid JSON object such as {\"SPEECH_LANGUAGE_CODE\":\"auto\"}."
  }
}

variable "devops_client_secret_data" {
  description = "Key/value pairs rendered into Kubernetes secret mcp-client-secrets for the client deployment."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "devops_client_secret_json" {
  description = "Optional JSON object of additional secret env vars for the client deployment. Useful for UI/ZIP stack inputs."
  type        = string
  default     = "{\"AGENT_RECURSION_LIMIT\":\"40\",\"AGENT_MAX_CONCURRENCY\":\"8\",\"AGENT_TOOL_RUN_LIMIT\":\"36\"}"
  nullable    = true
  sensitive   = true

  validation {
    condition     = (var.devops_client_secret_json == null ? "" : trimspace(var.devops_client_secret_json)) == "" || can(tomap(jsondecode(trimspace(var.devops_client_secret_json))))
    error_message = "devops_client_secret_json must be empty or a valid JSON object such as {\"AGENT_RECURSION_LIMIT\":\"40\"}."
  }
}

variable "genai_model_id" {
  description = "OCI Generative AI model identifier used by the MCP client deployment."
  type        = string
  default     = "cohere.command-a-03-2025"
  nullable    = true
}

variable "genai_provider" {
  description = "Provider name passed to the OCI Generative AI integration."
  type        = string
  default     = "cohere"
  nullable    = true
}

variable "genai_model_temperature" {
  description = "Temperature passed to the OCI Generative AI chat model."
  type        = number
  default     = 0.0
}

variable "genai_model_max_tokens" {
  description = "Maximum output tokens requested from the OCI Generative AI chat model."
  type        = number
  default     = 4096

  validation {
    condition     = var.genai_model_max_tokens > 0 && var.genai_model_max_tokens <= 4096
    error_message = "genai_model_max_tokens must be between 1 and 4096 for the current default model configuration."
  }
}

variable "genai_service_endpoint" {
  description = "Optional OCI Generative AI service endpoint override. When omitted, Terraform derives the regional inference endpoint."
  type        = string
  default     = null
  nullable    = true
}
