variable "environment" {
  type        = string
  description = "The deployment environment (e.g., stage, prod)"
}

variable "aws_region" {
  type        = string
  description = "The target AWS region for Bedrock service invocation"
}

variable "create_iam_user" {
  type        = bool
  default     = true
  description = "Set to true to generate a dedicated IAM User with long-term API access credentials"
}

variable "model_id" {
  type        = string
  default     = "minimax.minimax-m2.5"
  description = "The specific AWS Bedrock model identifier to allow in the IAM policy"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags to apply to all provisioned infrastructure resources"
}
