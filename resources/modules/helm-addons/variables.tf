variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "role_arn" {
  type        = string
  description = "IAM Role ARN for the Cluster Autoscaler"
}

variable "tags" {
  type        = map(string)
  description = "Common tags"
  default     = {}
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC where the cluster is running"
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the OIDC provider for IRSA"
}

variable "oidc_provider_url" {
  type        = string
  description = "URL of the OIDC provider for IRSA"
}
