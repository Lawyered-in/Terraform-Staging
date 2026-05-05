variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket (must be globally unique)"
}

variable "force_destroy" {
  type        = bool
  description = "Allow bucket deletion even with objects inside"
  default     = false
}

variable "versioning_enabled" {
  type        = bool
  description = "Enable S3 versioning"
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key for SSE-KMS encryption. If null, AES256 (SSE-S3) is used"
  default     = null
}

variable "lifecycle_rules" {
  description = "Map of lifecycle rule configurations"
  type = map(object({
    enabled     = optional(bool, true)
    transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])
    expiration_days                    = optional(number, null)
    noncurrent_version_expiration_days = optional(number, null)
  }))
  default = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the S3 bucket"
  default     = {}
}
