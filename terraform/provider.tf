terraform {
  required_version = ">= 1.5.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 7.14.0"
    }
  }
}

locals {
  configured_home_region = var.home_region == null ? "" : trimspace(var.home_region)
  effective_home_region = local.configured_home_region != "" ? local.configured_home_region : lookup({
    for r in data.oci_identity_regions.all.regions : r.key => r.name
  }, data.oci_identity_tenancy.current.home_region_key, var.region)
}

provider "oci" {
  region = var.region
}

# Identity operations must run in the tenancy's home region.
provider "oci" {
  alias  = "home"
  region = local.effective_home_region
}
