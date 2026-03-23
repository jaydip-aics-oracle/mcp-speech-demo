#outputs.tf
output "mcp_server_repository_path" {
  description = "The full URL for pushing images to the OCIR repository."
  value       = local.use_devops_build_pipeline ? "${lower(data.oci_identity_regions.current.regions[0].key)}.ocir.io/${data.oci_objectstorage_namespace.this.namespace}/${local.effective_mcp_container_repository_name}" : null
}

output "mcp_client_repository_path" {
  description = "The full URL for pushing MCP client images to the OCIR repository."
  value       = local.use_devops_build_pipeline ? "${lower(data.oci_identity_regions.current.regions[0].key)}.ocir.io/${data.oci_objectstorage_namespace.this.namespace}/${local.effective_mcp_client_container_repository_name}" : null
}

output "cluster_id" {
  value = module.oke_virtual_nodes.cluster_id
}

output "oci_namespace" {
  description = "Object Storage namespace for this tenancy"
  value       = data.oci_objectstorage_namespace.this.namespace
}

output "oci_region" {
  description = "OCI region for this stack"
  value       = var.region
}

output "speech_bucket_name" {
  description = "Speech/Object Storage bucket name"
  value       = local.effective_speech_bucket_name
}

output "resource_name_prefix" {
  description = "Prefix used for generated resource names"
  value       = local.resource_name_prefix
}

output "devops_project_id" {
  description = "OCI DevOps project OCID created for quick deploy or advanced build/deploy."
  value       = local.use_app_deploy ? oci_devops_project.mcp[0].id : null
}

output "devops_build_pipeline_id" {
  description = "OCI DevOps build pipeline OCID."
  value       = local.use_devops_build_pipeline ? oci_devops_build_pipeline.mcp[0].id : null
}

output "devops_deploy_pipeline_id" {
  description = "OCI DevOps deployment pipeline OCID."
  value       = local.use_app_deploy ? oci_devops_deploy_pipeline.mcp[0].id : null
}

output "devops_initial_build_run_id" {
  description = "OCID of the OCI DevOps build run launched by the current stack apply."
  value       = local.use_devops_build_pipeline ? oci_devops_build_run.initial[0].id : null
}

output "devops_initial_deployment_id" {
  description = "OCID of the OCI DevOps deployment launched by the current stack apply in quick_deploy mode."
  value       = local.use_quick_deploy_mode ? oci_devops_deployment.initial[0].id : null
}

output "devops_server_image_uri" {
  description = "Server image URI used by the current stack apply."
  value       = local.use_app_deploy ? local.effective_server_image_uri : null
}

output "devops_client_image_uri" {
  description = "Client image URI used by the current stack apply."
  value       = local.use_app_deploy ? local.effective_client_image_uri : null
}

output "deployment_mode" {
  description = "Effective application deployment mode."
  value       = local.use_infra_only_mode ? "infra_only" : (local.use_devops_build_pipeline ? "oci_devops" : "quick_deploy")
}

output "client_service_name" {
  description = "Expected Kubernetes Service name for the MCP client UI."
  value       = local.client_service_name
}

output "server_service_name" {
  description = "Expected Kubernetes Service name for the MCP server."
  value       = local.server_service_name
}
