variable "aws_region" {
  type        = string
  description = "AWS Region to deploy resources in"
}

# -------------------------------------------------------------------
# VPC variable — map of VPC configurations
# Each VPC defines public_subnets, private_subnets, nat_subnet_key, tags
# -------------------------------------------------------------------
variable "vpcs" {
  description = "Map of VPC configurations. Each entry creates a VPC with public/private subnets, IGW, NAT GW, and route tables."
  type = map(object({
    cidr_block = string
    public_subnets = map(object({
      cidr_block        = string
      availability_zone = string
    }))
    private_subnets = map(object({
      cidr_block        = string
      availability_zone = string
    }))
    database_subnets = optional(map(object({
      cidr_block        = string
      availability_zone = string
    })), {})
    nat_subnet_key = string
    tags           = map(string)
  }))
}

# -------------------------------------------------------------------
# EC2 variable — map of instance configurations
# vpc_key  : key of the VPC in var.vpcs to look up private subnet IDs from
# subnet_key: key within the VPC's private_subnets map
# -------------------------------------------------------------------
variable "ec2_instances" {
  description = "Map of EC2 instance configurations. subnet_id is resolved dynamically from the VPC module using vpc_key and subnet_key."
  type = map(object({
    ami_id                 = string
    instance_type          = string
    vpc_key                = string
    subnet_key             = string
    key_name               = optional(string, null)
    security_group_ids     = optional(list(string), [])
    associate_public_ip    = optional(bool, false)
    additional_policy_arns = optional(list(string), [])
    inline_policy_json     = optional(string, null)
    root_volume_size       = optional(number, 20)
    root_volume_type       = optional(string, "gp3")
    tags                   = optional(map(string), {})
  }))
  default = {}
}

# -------------------------------------------------------------------
# RDS variable — map of RDS instance configurations
# vpc_key    : references a key in var.vpcs
# subnet_keys: list of private subnet keys in that VPC (min 2 for Multi-AZ)
# -------------------------------------------------------------------
variable "rds_instances" {
  description = "Map of RDS instance configurations. subnet_ids resolved dynamically from VPC module using vpc_key and subnet_keys."
  type = map(object({
    engine                  = optional(string, "mysql")
    engine_version          = optional(string, "8.0")
    instance_class          = optional(string, "db.t3.micro")
    allocated_storage       = optional(number, 20)
    max_allocated_storage   = optional(number, 0)
    storage_type            = optional(string, "gp3")
    storage_encrypted       = optional(bool, true)
    db_name                 = string
    username                = string
    password                = string
    vpc_key                 = string
    subnet_keys             = list(string)
    vpc_security_group_ids  = optional(list(string), [])
    multi_az                = optional(bool, false)
    backup_retention_period = optional(number, 7)
    deletion_protection     = optional(bool, false)
    skip_final_snapshot     = optional(bool, true)
    apply_immediately       = optional(bool, false)
    allow_major_version_upgrade = optional(bool, false)
    parameter_group_name    = optional(string, null)
    parameter_group_family  = optional(string, null)
    tags                    = optional(map(string), {})
  }))
  default = {}
}

# -------------------------------------------------------------------
# EKS variable — map of EKS cluster configurations
# vpc_key    : references a key in var.vpcs
# subnet_keys: private subnet keys to place control plane + node groups
# node_groups: inner map of node group configurations (handled inside the module)
# -------------------------------------------------------------------
variable "eks_clusters" {
  description = "Map of EKS cluster configurations. subnet_ids are resolved dynamically from the VPC module using vpc_key and subnet_keys."
  type = map(object({
    kubernetes_version      = optional(string, "1.29")
    vpc_key                 = string
    subnet_keys             = list(string)
    endpoint_private_access = optional(bool, true)
    endpoint_public_access  = optional(bool, false)
    public_access_cidrs     = optional(list(string), ["0.0.0.0/0"])
    cluster_log_types       = optional(list(string), ["api", "audit", "authenticator", "controllerManager", "scheduler"])
    node_groups = map(object({
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
    tags = optional(map(string), {})
  }))
  default = {}
}

# -------------------------------------------------------------------
# KMS variable — map of KMS key configurations
# -------------------------------------------------------------------
variable "kms_keys" {
  description = "Map of KMS key configurations. Each key in the map becomes an alias name."
  type = map(object({
    description             = optional(string, "Managed by Terraform")
    deletion_window_in_days = optional(number, 30)
    enable_key_rotation     = optional(bool, true)
    multi_region            = optional(bool, false)
    policy                  = optional(string, null)
    tags                    = optional(map(string), {})
  }))
  default = {}
}

# -------------------------------------------------------------------
# S3 variable — map of S3 bucket configurations
# kms_key : optional key from var.kms_keys to use for SSE-KMS encryption
#           if null, AES256 (SSE-S3) is used
# -------------------------------------------------------------------
variable "s3_buckets" {
  description = "Map of S3 bucket configurations."
  type = map(object({
    bucket_name        = string
    force_destroy      = optional(bool, false)
    versioning_enabled = optional(bool, true)
    kms_key            = optional(string, null)
    lifecycle_rules = optional(map(object({
      enabled = optional(bool, true)
      transitions = optional(list(object({
        days          = number
        storage_class = string
      })), [])
      expiration_days                    = optional(number, null)
      noncurrent_version_expiration_days = optional(number, null)
    })), {})
    tags = optional(map(string), {})
  }))
  default = {}
}

# -------------------------------------------------------------------
# ECR variable — map of ECR repository configurations
# -------------------------------------------------------------------
variable "ecr_repositories" {
  description = "Map of ECR repository configurations."
  type = map(object({
    name                 = string
    image_tag_mutability = optional(string, "MUTABLE")
    scan_on_push         = optional(bool, true)
    tags                 = optional(map(string), {})
  }))
  default = {}
}
# -------------------------------------------------------------------
# Aurora variable — map of Aurora cluster configurations
# -------------------------------------------------------------------
variable "aurora_clusters" {
  description = "Map of Aurora cluster configurations."
  type = map(object({
    engine                  = optional(string, "aurora-mysql")
    engine_version          = optional(string, "8.0.mysql_aurora.3.12.0")
    instance_class          = optional(string, "db.t4g.large")
    database_name           = string
    master_username         = string
    master_password         = optional(string, null)
    vpc_key                 = string
    subnet_keys             = list(string)
    preferred_az            = optional(string, "ap-south-1a")
    backup_retention_period = optional(number, 7)
    deletion_protection     = optional(bool, false)
    skip_final_snapshot     = optional(bool, true)
    tags                    = optional(map(string), {})
  }))
  default = {}
}

variable "global_github_token_secret_name" {
  type        = string
  description = "Global default secret name for GitHub token"
  default     = "github-connection-key"
}

variable "github_connection_arn" {
  type        = string
  description = "ARN of the AWS CodeStar connection to GitHub"
}

variable "codepipelines" {
  type = map(object({
    pipeline_name            = optional(string)
    repository_id            = string
    branch_name              = optional(string, "staging")
    ecr_key                  = string
    prefetch_images          = optional(list(string), [])
    build_args               = optional(map(string), {})
    manifest_file_path       = optional(string, "")
    github_token_secret_name = optional(string)
    connection_arn           = optional(string)
    tags                     = optional(map(string), {})
  }))
  description = "Map of CodePipelines to create"
  default     = {}
}
