variable "region" {
  type        = string
  description = "AWS Region approved for this deployment. The example uses us-east-2."
  default     = "us-east-2"
}

variable "project_name" {
  type        = string
  description = "Short project identifier used in bucket names and the Project tag."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name must be 3-21 lowercase alphanumerics or hyphens, starting with a letter."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment; also used as the Environment tag."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "allow_force_destroy" {
  type        = bool
  description = "LAB CLEANUP ONLY: allow Terraform to delete nonempty buckets, including object versions."
  default     = false
}
