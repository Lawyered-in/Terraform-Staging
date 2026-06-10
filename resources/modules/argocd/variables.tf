variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "tags" {
  type        = map(string)
  description = "Common tags"
  default     = {}
}
