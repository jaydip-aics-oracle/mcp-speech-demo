#outputs.tf
output "mcp_server_repository_path" {
  description = "The full URL for pushing images to the OCIR repository."
  value       = "${lower(data.oci_identity_regions.current.regions[0].key)}.ocir.io/${data.oci_objectstorage_namespace.this.namespace}/${local.effective_mcp_container_repository_name}"
}

output "mcp_client_repository_path" {
  description = "The full URL for pushing MCP client images to the OCIR repository."
  value       = "${lower(data.oci_identity_regions.current.regions[0].key)}.ocir.io/${data.oci_objectstorage_namespace.this.namespace}/${local.effective_mcp_client_container_repository_name}"
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
  description = "OCI DevOps project OCID created for one-click build/deploy."
  value       = var.enable_devops_pipeline ? oci_devops_project.mcp[0].id : null
}

output "devops_build_pipeline_id" {
  description = "OCI DevOps build pipeline OCID."
  value       = var.enable_devops_pipeline ? oci_devops_build_pipeline.mcp[0].id : null
}

output "devops_deploy_pipeline_id" {
  description = "OCI DevOps deployment pipeline OCID."
  value       = var.enable_devops_pipeline ? oci_devops_deploy_pipeline.mcp[0].id : null
}

output "devops_initial_build_run_id" {
  description = "OCID of the initial OCI DevOps build run (if enabled)."
  value       = var.enable_devops_pipeline && var.devops_trigger_initial_build ? oci_devops_build_run.initial[0].id : null
}

output "devops_server_image_uri" {
  description = "OCI DevOps target server image URI."
  value       = var.enable_devops_pipeline ? local.devops_server_image_uri : null
}

output "devops_client_image_uri" {
  description = "OCI DevOps target client image URI."
  value       = var.enable_devops_pipeline ? local.devops_client_image_uri : null
}

output "client_service_name" {
  description = "Expected Kubernetes Service name for the MCP client UI."
  value       = local.client_service_name
}

output "server_service_name" {
  description = "Expected Kubernetes Service name for the MCP server."
  value       = local.server_service_name
}
