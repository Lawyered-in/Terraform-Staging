output "vpc_ids" {
  description = "Map of VPC name => VPC ID"
  value = {
    for k, v in module.vpc : k => v.vpc_id
  }
}

output "vpc_arns" {
  description = "Map of VPC name => VPC ARN"
  value = {
    for k, v in module.vpc : k => v.vpc_arn
  }
}

output "public_subnet_ids" {
  description = "Map of VPC name => map of public subnet key => subnet ID"
  value = {
    for k, v in module.vpc : k => v.public_subnet_ids
  }
}

output "private_subnet_ids" {
  description = "Map of VPC name => map of private subnet key => subnet ID"
  value = {
    for k, v in module.vpc : k => v.private_subnet_ids
  }
}

output "nat_gateway_ids" {
  description = "Map of VPC name => NAT Gateway ID"
  value = {
    for k, v in module.vpc : k => v.nat_gateway_id
  }
}

output "igw_ids" {
  description = "Map of VPC name => Internet Gateway ID"
  value = {
    for k, v in module.vpc : k => v.igw_id
  }
}

output "ec2_instance_ids" {
  description = "Map of EC2 instance name => Instance ID"
  value = {
    for k, v in module.ec2 : k => v.instance_id
  }
}

output "ec2_private_ips" {
  description = "Map of EC2 instance name => Private IP"
  value = {
    for k, v in module.ec2 : k => v.private_ip
  }
}

output "ec2_public_ips" {
  description = "Map of EC2 instance name => Public IP (if applicable)"
  value = {
    for k, v in module.ec2 : k => v.public_ip
  }
}

output "private_keys_pem" {
  description = "Map of Key Pair Name => RSA Private Key in PEM format (sensitive)"
  value = {
    for k, v in tls_private_key.keys : k => v.private_key_pem
  }
  sensitive = true
}

output "ec2_iam_role_arns" {
  description = "Map of EC2 instance name => IAM Role ARN"
  value = {
    for k, v in module.ec2_iam_roles : k => v.role_arn
  }
}

output "ec2_iam_role_names" {
  description = "Map of EC2 instance name => IAM Role Name"
  value = {
    for k, v in module.ec2_iam_roles : k => v.role_name
  }
}

# -------------------------------------------------------------------
# RDS Outputs
# -------------------------------------------------------------------
output "rds_endpoints" {
  description = "Map of RDS instance name => connection endpoint (host:port)"
  value = {
    for k, v in module.rds : k => v.db_instance_endpoint
  }
}

output "rds_addresses" {
  description = "Map of RDS instance name => hostname"
  value = {
    for k, v in module.rds : k => v.db_instance_address
  }
}

output "rds_ports" {
  description = "Map of RDS instance name => port"
  value = {
    for k, v in module.rds : k => v.db_instance_port
  }
}

output "rds_arns" {
  description = "Map of RDS instance name => ARN"
  value = {
    for k, v in module.rds : k => v.db_instance_arn
  }
}

# -------------------------------------------------------------------
# EKS Outputs
# -------------------------------------------------------------------
output "eks_cluster_endpoints" {
  description = "Map of EKS cluster name => API server endpoint"
  value = {
    for k, v in module.eks : k => v.cluster_endpoint
  }
}

output "eks_cluster_arns" {
  description = "Map of EKS cluster name => cluster ARN"
  value = {
    for k, v in module.eks : k => v.cluster_arn
  }
}

output "eks_cluster_versions" {
  description = "Map of EKS cluster name => Kubernetes version"
  value = {
    for k, v in module.eks : k => v.cluster_version
  }
}

output "eks_node_group_arns" {
  description = "Map of EKS cluster name => map of node group name => ARN"
  value = {
    for k, v in module.eks : k => v.node_group_arns
  }
}

output "eks_node_group_statuses" {
  description = "Map of EKS cluster name => map of node group name => status"
  value = {
    for k, v in module.eks : k => v.node_group_statuses
  }
}

# -------------------------------------------------------------------
# KMS Outputs
# -------------------------------------------------------------------
output "kms_key_arns" {
  description = "Map of KMS key alias => key ARN"
  value = {
    for k, v in module.kms : k => v.key_arn
  }
}

output "kms_alias_arns" {
  description = "Map of KMS key alias => alias ARN"
  value = {
    for k, v in module.kms : k => v.alias_arn
  }
}

# -------------------------------------------------------------------
# S3 Outputs
# -------------------------------------------------------------------
output "s3_bucket_ids" {
  description = "Map of S3 bucket logical name => bucket ID"
  value = {
    for k, v in module.s3 : k => v.bucket_id
  }
}

output "s3_bucket_arns" {
  description = "Map of S3 bucket logical name => bucket ARN"
  value = {
    for k, v in module.s3 : k => v.bucket_arn
  }
}

output "s3_bucket_domain_names" {
  description = "Map of S3 bucket logical name => bucket domain name"
  value = {
    for k, v in module.s3 : k => v.bucket_domain_name
  }
}
# -------------------------------------------------------------------
# ECR Outputs
# -------------------------------------------------------------------
# -------------------------------------------------------------------
# ECR Outputs
# -------------------------------------------------------------------
output "ecr_repository_urls" {
  description = "Map of repository name => URL"
  value       = { for k, v in module.ecr : k => v.repository_url }
}

output "ecr_repository_arns" {
  description = "Map of repository name => ARN"
  value       = { for k, v in module.ecr : k => v.repository_arn }
}

# -------------------------------------------------------------------
# Aurora Outputs
# -------------------------------------------------------------------
output "aurora_cluster_endpoints" {
  description = "Map of Aurora cluster name => endpoint"
  value = {
    for k, v in module.aurora : k => v.cluster_endpoint
  }
}

output "aurora_cluster_reader_endpoints" {
  description = "Map of Aurora cluster name => reader endpoint"
  value = {
    for k, v in module.aurora : k => v.cluster_reader_endpoint
  }
}

output "aurora_master_secret_arns" {
  description = "Map of Aurora cluster name => Master User Secret ARN in AWS Secrets Manager"
  value = {
    for k, v in module.aurora : k => v.master_user_secret_arn
  }
}
