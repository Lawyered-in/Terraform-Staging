variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the OIDC provider for IRSA"
}

variable "oidc_provider_url" {
  type        = string
  description = "URL of the OIDC provider for IRSA"
}

variable "addon_versions" {
  type = map(string)
  description = "Map of addon versions to install"
  default = {
    vpc-cni        = null
    coredns        = null
    kube-proxy     = null
    metrics-server = null
    aws-ebs-csi-driver = null
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
