locals {
  resource_name_prefix                            = lower(trimspace(var.resource_name_prefix))
  generated_name_suffix                           = substr(var.compartment_id, max(length(var.compartment_id) - 5, 0), 5)
  mcp_container_repository_name_normalized        = var.mcp_container_repository_name == null ? "" : trimspace(var.mcp_container_repository_name)
  mcp_client_container_repository_name_normalized = var.mcp_client_container_repository_name == null ? "" : trimspace(var.mcp_client_container_repository_name)
  speech_bucket_name_normalized                   = var.speech_bucket_name == null ? "" : trimspace(var.speech_bucket_name)

  mcp_container_repository_base_name        = local.mcp_container_repository_name_normalized != "" ? local.mcp_container_repository_name_normalized : "audio-repo"
  mcp_client_container_repository_base_name = local.mcp_client_container_repository_name_normalized != "" ? local.mcp_client_container_repository_name_normalized : "client-repo"
  speech_bucket_base_name                   = local.speech_bucket_name_normalized != "" ? local.speech_bucket_name_normalized : "audio-bucket"

  effective_mcp_container_repository_name        = "${local.resource_name_prefix}-${local.mcp_container_repository_base_name}-${local.generated_name_suffix}"
  effective_mcp_client_container_repository_name = "${local.resource_name_prefix}-${local.mcp_client_container_repository_base_name}-${local.generated_name_suffix}"
  effective_speech_bucket_name                   = "${local.resource_name_prefix}-${local.speech_bucket_base_name}-${local.generated_name_suffix}"

  workload_policy_name              = "${local.resource_name_prefix}-workload-${local.generated_name_suffix}"
  devops_build_runtime_policy_name  = "${local.resource_name_prefix}-devops-build-rp-${local.generated_name_suffix}"
  devops_deploy_runtime_policy_name = "${local.resource_name_prefix}-devops-deploy-rp-${local.generated_name_suffix}"
  devops_project_name_default       = "${local.resource_name_prefix}-devops-${local.generated_name_suffix}"
  server_service_name               = "fastmcp-server"
  client_service_name               = "fastmcp-client"
}
