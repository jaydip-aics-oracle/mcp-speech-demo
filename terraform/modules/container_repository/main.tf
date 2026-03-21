data "oci_artifacts_container_repositories" "lookup" {
  compartment_id = var.compartment_id
  display_name   = var.container_repository_name
  state          = "AVAILABLE"
}

locals {
  lookup_repository = try(data.oci_artifacts_container_repositories.lookup.container_repository_collection[0].items[0], null)
}

resource "oci_artifacts_container_repository" "container_repo" {
  count          = local.lookup_repository == null ? 1 : 0
  compartment_id = var.compartment_id
  display_name   = var.container_repository_name
  is_public      = var.is_public
}

output "container_repository_id" {
  value = local.lookup_repository != null ? local.lookup_repository.id : oci_artifacts_container_repository.container_repo[0].id
}
