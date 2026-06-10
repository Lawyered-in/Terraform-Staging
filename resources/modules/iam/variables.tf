variable "role_name" {
  type        = string
  description = "Name of the IAM role and instance profile"
}

variable "description" {
  type        = string
  description = "Description of the IAM role"
  default     = "EC2 IAM role managed by Terraform"
}

variable "max_session_duration" {
  type        = number
  description = "Maximum session duration (in seconds) for the IAM role (3600–43200)"
  default     = 3600
}

variable "additional_policy_arns" {
  type        = list(string)
  description = "List of additional managed policy ARNs to attach beyond AmazonSSMManagedInstanceCore"
  default     = []
}

variable "inline_policy_json" {
  type        = string
  description = "JSON string of an inline policy to attach. If null, no inline policy is created."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the IAM role and instance profile"
  default     = {}
}
