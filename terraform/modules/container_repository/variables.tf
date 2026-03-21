variable "tenancy_ocid" {
  description = "The OCID of the tenancy (root compartment)."
  type        = string
}

variable "compartment_id" {
  description = "The OCID of the compartment."
  type        = string
}

variable "container_repository_name" {
  description = "The name of the OCI Container Repository."
  type        = string
}

variable "is_public" {
  description = "Whether anonymous pulls are allowed for the OCI Container Repository."
  type        = bool
  default     = false
}
