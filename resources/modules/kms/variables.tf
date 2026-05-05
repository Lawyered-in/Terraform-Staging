variable "alias_name" {
  type        = string
  description = "KMS alias name (without the 'alias/' prefix)"
}

variable "description" {
  type        = string
  description = "Description of the KMS key"
  default     = "Managed by Terraform"
}

variable "deletion_window_in_days" {
  type        = number
  description = "Number of days before the key is deleted after being scheduled for deletion (7-30)"
  default     = 30
}

variable "enable_key_rotation" {
  type        = bool
  description = "Enable automatic annual key rotation"
  default     = true
}

variable "multi_region" {
  type        = bool
  description = "Whether the key is a multi-region key"
  default     = false
}

variable "policy" {
  type        = string
  description = "JSON key policy. If null, AWS default key policy is used"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the KMS key"
  default     = {}
}
