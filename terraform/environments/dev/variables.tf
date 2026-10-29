variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
  default     = "cloud-platform-engineering-hs"
}

variable "region" {
  description = "Google Cloud deployment region"
  type        = string
  default     = "europe-west9"
}

variable "lab_enabled" {
  description = "Create the temporary management VM only during a lab session"
  type        = bool
  default     = false
}
