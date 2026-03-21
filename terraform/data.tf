# Get a list of availability domains in the region
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_identity_tenancy" "current" {
  tenancy_id = var.tenancy_ocid
}

data "oci_identity_regions" "all" {}

data "oci_identity_regions" "current" {
  filter {
    name   = "name"
    values = [var.region]
  }
}

data "oci_core_services" "all_services" {}

data "oci_objectstorage_namespace" "this" {}

data "oci_identity_policies" "workload_policy_lookup" {
  provider       = oci.home
  compartment_id = var.compartment_id
  name           = local.workload_policy_name
  state          = "ACTIVE"
}

data "oci_identity_policies" "devops_runtime_policy_lookup" {
  provider       = oci.home
  compartment_id = var.compartment_id
  name           = local.devops_runtime_policy_name
  state          = "ACTIVE"
}
