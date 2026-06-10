variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for the EKS cluster (e.g. '1.29')"
  default     = "1.29"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for the EKS control plane and node groups"
}

variable "endpoint_private_access" {
  type        = bool
  description = "Enable private API server endpoint"
  default     = true
}

variable "endpoint_public_access" {
  type        = bool
  description = "Enable public API server endpoint"
  default     = false
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "Public CIDR blocks for EKS API access"
  default     = ["0.0.0.0/0"]
}

variable "cluster_log_types" {
  type        = list(string)
  description = "EKS control plane log types to enable"
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "node_groups" {
  description = "Map of node group configurations"
  type = map(object({
    instance_types  = list(string)
    capacity_type   = optional(string, "ON_DEMAND")
    disk_size       = optional(number, 50)
    desired_size    = number
    min_size        = number
    max_size        = number
    max_unavailable = optional(number, 1)
    labels          = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  type        = map(string)
  description = "Common tags to apply to all EKS resources"
  default     = {}
}
