provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.eks["eks-cluster-np"].cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks["eks-cluster-np"].cluster_certificate_authority)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks["eks-cluster-np"].cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks["eks-cluster-np"].cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks["eks-cluster-np"].cluster_certificate_authority)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks["eks-cluster-np"].cluster_name]
      command     = "aws"
    }
  }
}

provider "kubectl" {
  host                   = module.eks["eks-cluster-np"].cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks["eks-cluster-np"].cluster_certificate_authority)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks["eks-cluster-np"].cluster_name]
    command     = "aws"
  }
}


# -------------------------------------------------------------------
# VPC Module — for_each over var.vpcs
# Provisions VPC, public/private subnets, IGW, NAT GW, route tables
# -------------------------------------------------------------------
module "vpc" {
  source   = "../modules/vpc"
  for_each = var.vpcs

  vpc_name         = each.key
  cidr_block       = each.value.cidr_block
  public_subnets   = each.value.public_subnets
  private_subnets  = each.value.private_subnets
  database_subnets = each.value.database_subnets
  nat_subnet_key   = each.value.nat_subnet_key
  tags             = each.value.tags
}

# -------------------------------------------------------------------
# Key Pairs — Auto-create any key pairs defined in ec2_instances
# -------------------------------------------------------------------
locals {
  key_names = toset(compact([for k, v in var.ec2_instances : v.key_name]))
}

resource "tls_private_key" "keys" {
  for_each  = local.key_names
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "keys" {
  for_each   = local.key_names
  key_name   = each.value
  public_key = tls_private_key.keys[each.value].public_key_openssh
}

# -------------------------------------------------------------------
# Save Private Keys to Local Files
# -------------------------------------------------------------------
resource "local_file" "private_keys" {
  for_each = local.key_names

  content         = tls_private_key.keys[each.value].private_key_pem
  filename        = "${path.module}/keys/${each.value}.pem"
  file_permission = "0400"
}

# -------------------------------------------------------------------
# EC2 IAM Roles — for_each over var.ec2_instances
# Creates an IAM role and instance profile for each EC2 instance
# -------------------------------------------------------------------
module "ec2_iam_roles" {
  source   = "../modules/iam"
  for_each = var.ec2_instances

  role_name              = "${each.key}-role"
  additional_policy_arns = each.value.additional_policy_arns
  inline_policy_json     = each.value.inline_policy_json
  tags                   = each.value.tags
}

# -------------------------------------------------------------------
# EC2 Module — for_each over var.ec2_instances
# subnet_id resolved dynamically from the VPC module's private_subnet_ids
# iam_instance_profile linked from the corresponding ec2_iam_roles module
# -------------------------------------------------------------------
module "ec2" {
  source   = "../modules/ec2"
  for_each = var.ec2_instances

  instance_name        = each.key
  ami_id               = each.value.ami_id
  instance_type        = each.value.instance_type
  vpc_id               = module.vpc[each.value.vpc_key].vpc_id
  subnet_id            = module.vpc[each.value.vpc_key].private_subnet_ids[each.value.subnet_key]
  key_name             = each.value.key_name
  security_group_ids   = each.value.security_group_ids
  associate_public_ip  = each.value.associate_public_ip
  iam_instance_profile = module.ec2_iam_roles[each.key].instance_profile_name
  root_volume_size     = each.value.root_volume_size
  root_volume_type     = each.value.root_volume_type
  tags                 = each.value.tags

  depends_on = [module.vpc, aws_key_pair.keys]
}

# -------------------------------------------------------------------
# RDS Module — for_each over var.rds_instances
# subnet_ids resolved dynamically from VPC module private_subnet_ids
# -------------------------------------------------------------------
module "rds" {
  source   = "../modules/rds"
  for_each = var.rds_instances

  identifier            = each.key
  engine                = each.value.engine
  engine_version        = each.value.engine_version
  instance_class        = each.value.instance_class
  allocated_storage     = each.value.allocated_storage
  max_allocated_storage = each.value.max_allocated_storage
  storage_type          = each.value.storage_type
  storage_encrypted     = each.value.storage_encrypted
  db_name               = each.value.db_name
  username              = each.value.username
  # Pull the password from Secrets Manager if it's managed there, otherwise use the password from tfvars.
  password = contains(keys(aws_secretsmanager_secret_version.rds_secrets), each.key) ? aws_secretsmanager_secret_version.rds_secrets[each.key].secret_string : each.value.password
  vpc_id   = module.vpc[each.value.vpc_key].vpc_id
  subnet_ids = [for k in each.value.subnet_keys : try(
    module.vpc[each.value.vpc_key].database_subnet_ids[k],
    module.vpc[each.value.vpc_key].private_subnet_ids[k],
    module.vpc[each.value.vpc_key].public_subnet_ids[k]
  )]
  vpc_security_group_ids      = each.value.vpc_security_group_ids
  multi_az                    = each.value.multi_az
  backup_retention_period     = each.value.backup_retention_period
  deletion_protection         = each.value.deletion_protection
  skip_final_snapshot         = each.value.skip_final_snapshot
  apply_immediately           = each.value.apply_immediately
  allow_major_version_upgrade = each.value.allow_major_version_upgrade
  publicly_accessible         = each.value.publicly_accessible
  db_subnet_group_name        = each.value.db_subnet_group_name
  parameter_group_name        = each.value.parameter_group_name != null ? aws_db_parameter_group.rds[each.key].name : null
  tags                        = each.value.tags

  depends_on = [module.vpc, aws_db_parameter_group.rds]
}

# -------------------------------------------------------------------
# RDS Parameter Groups — for_each over var.rds_instances
# Only creates a parameter group if parameter_group_name is provided
# -------------------------------------------------------------------
resource "aws_db_parameter_group" "rds" {
  for_each = { for k, v in var.rds_instances : k => v if v.parameter_group_name != null && v.parameter_group_family != null }

  name        = each.value.parameter_group_name
  family      = each.value.parameter_group_family
  description = "Custom parameter group for ${each.key}"

  tags = each.value.tags
}

# -------------------------------------------------------------------
# ECR Module — for_each over var.ecr_repositories
# -------------------------------------------------------------------
module "ecr" {
  source   = "../modules/ecr"
  for_each = var.ecr_repositories

  name                 = each.value.name
  image_tag_mutability = each.value.image_tag_mutability
  scan_on_push         = each.value.scan_on_push

  tags = each.value.tags
}

# -------------------------------------------------------------------
# Aurora Module — for_each over var.aurora_clusters
# -------------------------------------------------------------------
module "aurora" {
  source   = "../modules/aurora"
  for_each = var.aurora_clusters

  cluster_identifier = each.key
  engine             = each.value.engine
  engine_version     = each.value.engine_version
  instance_class     = each.value.instance_class
  database_name      = each.value.database_name
  master_username    = each.value.master_username
  master_password    = each.value.master_password
  vpc_id             = module.vpc[each.value.vpc_key].vpc_id
  subnet_ids = [for k in each.value.subnet_keys : try(
    module.vpc[each.value.vpc_key].database_subnet_ids[k],
    module.vpc[each.value.vpc_key].private_subnet_ids[k],
    module.vpc[each.value.vpc_key].public_subnet_ids[k]
  )]
  preferred_az            = each.value.preferred_az
  backup_retention_period = each.value.backup_retention_period
  deletion_protection     = each.value.deletion_protection
  skip_final_snapshot     = each.value.skip_final_snapshot
  db_subnet_group_name    = each.value.db_subnet_group_name
  tags                    = each.value.tags

  depends_on = [module.vpc]
}

# -------------------------------------------------------------------
# EKS Module — for_each over var.eks_clusters
# subnet_ids resolved dynamically from VPC module private_subnet_ids
# Each cluster manages its own node groups via an inner for_each
# -------------------------------------------------------------------
module "eks" {
  source   = "../modules/eks"
  for_each = var.eks_clusters

  cluster_name            = each.key
  kubernetes_version      = each.value.kubernetes_version
  subnet_ids              = [for k in each.value.subnet_keys : try(module.vpc[each.value.vpc_key].private_subnet_ids[k], module.vpc[each.value.vpc_key].public_subnet_ids[k])]
  endpoint_private_access = each.value.endpoint_private_access
  endpoint_public_access  = each.value.endpoint_public_access
  public_access_cidrs     = each.value.public_access_cidrs
  cluster_log_types       = each.value.cluster_log_types
  node_groups             = each.value.node_groups
  tags                    = each.value.tags

  depends_on = [module.vpc]
}

# -------------------------------------------------------------------
# EKS Addons Module — Provisions managed addons (CNI, CoreDNS, Proxy, Metrics)
# -------------------------------------------------------------------
module "eks_addons" {
  source   = "../modules/eks-addons"
  for_each = var.eks_clusters

  cluster_name      = each.key
  oidc_provider_arn = module.eks[each.key].oidc_provider_arn
  oidc_provider_url = module.eks[each.key].oidc_provider_url

  tags = each.value.tags

  depends_on = [module.eks]
}

# -------------------------------------------------------------------
# Helm Scaling Addons (Cluster Autoscaler)
# -------------------------------------------------------------------
module "helm_scaling_addons" {
  source   = "../modules/helm-addons"
  for_each = var.eks_clusters

  cluster_name = each.key
  aws_region   = var.aws_region
  role_arn     = module.eks[each.key].cluster_autoscaler_role_arn

  vpc_id            = module.vpc[each.value.vpc_key].vpc_id
  oidc_provider_arn = module.eks[each.key].oidc_provider_arn
  oidc_provider_url = module.eks[each.key].oidc_provider_url

  tags = each.value.tags

  depends_on = [module.eks]
}

# -------------------------------------------------------------------
# Argo CD — Apps/Service
# -------------------------------------------------------------------
module "argocd_apps" {
  source   = "../modules/argocd"
  for_each = var.eks_clusters

  cluster_name = each.key
  tags         = each.value.tags

  depends_on = [module.eks, module.helm_scaling_addons]
}

# -------------------------------------------------------------------
# GitHub Shared Connection
# -------------------------------------------------------------------
resource "aws_codeconnections_connection" "github" {
  name          = "lawyered-github-repository"
  provider_type = "GitHub"
}

# -------------------------------------------------------------------
# GitHub SSH Key — Secrets Manager
# Store the private SSH key manually in AWS Console after terraform apply.
# Terraform creates the secret shell but will NEVER overwrite your value.
# -------------------------------------------------------------------
resource "aws_secretsmanager_secret" "github_ssh_key" {
  name                    = "github-connection-key"
  description             = "SSH private key for CodeBuild to push to Lawyered-in/k8s-manifest repo"
  recovery_window_in_days = 0

  tags = {
    Environment = "stage"
    Project     = "lawyered"
    Purpose     = "codebuild-github-push"
  }
}

resource "aws_secretsmanager_secret_version" "github_ssh_key" {
  secret_id     = aws_secretsmanager_secret.github_ssh_key.id
  secret_string = "PLACEHOLDER — replace this with your actual SSH private key in AWS Console"

  lifecycle {
    ignore_changes = [secret_string] # Terraform will never overwrite your manually set value
  }
}

# -------------------------------------------------------------------
# RDS Password Management
# Creates Secrets Manager resources for specific databases (finvica, lawyered-backend-new)
# -------------------------------------------------------------------

locals {
  managed_secret_instances = ["finvica", "lawyered-backend-new"]
}

# 1. Create the Secret containers in Secrets Manager
resource "aws_secretsmanager_secret" "rds_secrets" {
  for_each                = toset([for k in local.managed_secret_instances : k if contains(keys(var.rds_instances), k)])
  name                    = "${each.key}-db-secrets"
  description             = "Master password for the ${each.key} RDS instance (Staging)"
  recovery_window_in_days = 0

  tags = merge(var.rds_instances[each.key].tags, {
    Purpose = "rds-authentication"
  })
}

moved {
  from = aws_secretsmanager_secret.finvica_db_secrets[0]
  to   = aws_secretsmanager_secret.rds_secrets["finvica"]
}

moved {
  from = aws_secretsmanager_secret_version.finvica_db_secrets[0]
  to   = aws_secretsmanager_secret_version.rds_secrets["finvica"]
}

# 2. Store the actual password value in the Secret Version
resource "aws_secretsmanager_secret_version" "rds_secrets" {
  for_each      = aws_secretsmanager_secret.rds_secrets
  secret_id     = each.value.id
  secret_string = var.rds_instances[each.key].password
}

# -------------------------------------------------------------------
# Production Application Secrets Management
# Creates Secrets Manager resources for all 5 production microservices
# -------------------------------------------------------------------

locals {
  prod_apps = [
    "core-platform-be",
    "coworking-platform-be",
    "prosper-be",
    "admin-lawyered",
    "lawyered-be"
  ]
}

# 1. Create the Secret containers in Secrets Manager under the prod/ prefix
resource "aws_secretsmanager_secret" "prod_app_secrets" {
  for_each                = toset(local.prod_apps)
  name                    = "prod/${each.key}"
  description             = "Production credentials and configurations for ${each.key}"
  recovery_window_in_days = 0

  tags = {
    Environment = "prod"
    Project     = "lawyered"
    ManagedBy   = "terraform"
  }
}

# 2. Store the actual JSON payload loaded from local file to the Secret Version
resource "aws_secretsmanager_secret_version" "prod_app_secrets" {
  for_each      = aws_secretsmanager_secret.prod_app_secrets
  secret_id     = each.value.id
  secret_string = fileexists("${path.module}/secrets/${each.key}.json") ? file("${path.module}/secrets/${each.key}.json") : "{\"DUMMY_KEY\":\"PLACEHOLDER_VALUE\"}"

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# -------------------------------------------------------------------
# Staging Application Secrets Management
# Creates Secrets Manager resources for the 10 missing staging microservices
# (The other 5 backend secrets already exist in AWS and are skipped here)
# -------------------------------------------------------------------

locals {
  stg_apps = [
    "admin-lawyered-fe",
    "api-challans",
    "challanpay-fe-next",
    "challanpay-react",
    "core-platform-fe",
    "coworking-platform-fe",
    "faas-be",
    "faas-fe",
    "laravel-api",
    "lawyered-in-website",
    "lots247-in",
    "partners-portal-fe",
    "partners-portal-fe-feature",
    "prosper-fe",
    "qr-api",
    "subscriber-fe"
  ]
}

# 1. Create the Secret containers in Secrets Manager under the staging/ prefix
resource "aws_secretsmanager_secret" "stg_app_secrets" {
  for_each                = toset(local.stg_apps)
  name                    = "staging/${each.key}"
  description             = "Staging credentials and configurations for ${each.key}"
  recovery_window_in_days = 0

  tags = {
    Environment = "staging"
    Project     = "lawyered"
    ManagedBy   = "terraform"
  }
}

# 2. Store the actual JSON payload or a placeholder to the Secret Version
resource "aws_secretsmanager_secret_version" "stg_app_secrets" {
  for_each      = aws_secretsmanager_secret.stg_app_secrets
  secret_id     = each.value.id
  secret_string = fileexists("${path.module}/secrets/${each.key}.json") ? file("${path.module}/secrets/${each.key}.json") : "{\"DUMMY_KEY\":\"PLACEHOLDER_VALUE\"}"

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# -------------------------------------------------------------------
# External Secrets Operator (ESO) Staging Setup
# -------------------------------------------------------------------

# 1. Kubernetes Namespace 'stg'
resource "kubernetes_namespace" "stg" {
  metadata {
    name = "stg"
    labels = {
      environment = "staging"
    }
  }
}

# 2. IAM Policy for ESO to access Staging Secrets in Secrets Manager
resource "aws_iam_policy" "eso_stg_policy" {
  name = "ESOStagingSecretsPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:ap-south-1:344367180480:secret:staging/*"
      }
    ]
  })
}

# 3. IAM Role for ESO with OIDC trust relationship
locals {
  eks_cluster_key = "eks-cluster-np"
  stg_oidc_id     = replace(module.eks[local.eks_cluster_key].oidc_provider_url, "https://", "")
}

resource "aws_iam_role" "eso_stg_role" {
  name = "ESOStagingSharedRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks[local.eks_cluster_key].oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.stg_oidc_id}:sub" : "system:serviceaccount:stg:eso-staging-shared",
            "${local.stg_oidc_id}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# 4. Attach Policy to IAM Role
resource "aws_iam_role_policy_attachment" "eso_stg_attach" {
  role       = aws_iam_role.eso_stg_role.name
  policy_arn = aws_iam_policy.eso_stg_policy.arn
}

# 5. Kubernetes ServiceAccount for ESO in the 'stg' namespace
resource "kubernetes_service_account" "eso_stg_sa" {
  metadata {
    name      = "eso-staging-shared"
    namespace = kubernetes_namespace.stg.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.eso_stg_role.arn
    }
  }
}

# 6. Import existing manual staging resources to prevent conflicts
import {
  to = kubernetes_namespace.stg
  id = "stg"
}

import {
  to = aws_iam_policy.eso_stg_policy
  id = "arn:aws:iam::344367180480:policy/ESOStagingSecretsPolicy"
}

import {
  to = aws_iam_role.eso_stg_role
  id = "ESOStagingSharedRole"
}

import {
  to = kubernetes_service_account.eso_stg_sa
  id = "stg/eso-staging-shared"
}

# 7. Import existing manual RDS DB Subnet Groups to prevent conflicts
import {
  to = module.rds["finvica"].aws_db_subnet_group.this
  id = "finvica-pub-subnet-group"
}

import {
  to = module.rds["lawyered-backend-new"].aws_db_subnet_group.this
  id = "lawyered-backend-new-pub-subnet-group"
}


# -------------------------------------------------------------------
# DevSecOps Shared IAM Role for CodeBuild Security Scanning
# -------------------------------------------------------------------
resource "aws_iam_role" "devsecops_role" {
  name = "devsecops-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = "stage"
    Project     = "lawyered"
    Role        = "security"
  }
}

resource "aws_iam_role_policy" "devsecops" {
  name = "devsecops-policy"
  role = aws_iam_role.devsecops_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::*-artifacts-*",
          "arn:aws:s3:::*-artifacts-*/*",
          "arn:aws:s3:::devsecops-reports-storage-bucket",
          "arn:aws:s3:::devsecops-reports-storage-bucket/*"
        ]
      },
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect = "Allow"
        Resource = [
          aws_secretsmanager_secret.slack_webhook.arn,
          aws_secretsmanager_secret.github_ssh_key.arn
        ]
      }
    ]
  })
}

# -------------------------------------------------------------------
# Central S3 Bucket for DevSecOps Security Reports
# -------------------------------------------------------------------
resource "aws_s3_bucket" "devsecops_reports" {
  bucket        = "devsecops-reports-storage-bucket"
  force_destroy = true

  tags = {
    Environment = "stage"
    Project     = "lawyered"
    Role        = "security"
  }
}

resource "aws_s3_bucket_public_access_block" "devsecops_reports" {
  bucket = aws_s3_bucket.devsecops_reports.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "devsecops_public" {
  bucket = aws_s3_bucket.devsecops_reports.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadForReports"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.devsecops_reports.arn}/*"
      }
    ]
  })
}

# -------------------------------------------------------------------
# CodePipeline Module — for_each over var.codepipelines
# -------------------------------------------------------------------
module "codepipeline" {
  source   = "../modules/codepipeline"
  for_each = var.codepipelines

  pipeline_name                = try(coalesce(each.value.pipeline_name, "${each.key}-pipeline"), "${each.key}-pipeline")
  github_connection_arn        = try(coalesce(each.value.connection_arn, var.github_connection_arn, aws_codeconnections_connection.github.arn), aws_codeconnections_connection.github.arn)
  repository_id                = each.value.repository_id
  branch_name                  = each.value.branch_name
  manifest_branch              = each.value.manifest_branch
  ecr_repository_url           = module.ecr[each.value.ecr_key].repository_url
  prefetch_images              = each.value.prefetch_images
  build_args                   = each.value.build_args
  manifest_file_path           = each.value.manifest_file_path
  github_token_secret_name     = try(coalesce(each.value.github_token_secret_name, var.global_github_token_secret_name), var.global_github_token_secret_name)
  build_image                  = coalesce(each.value.build_image, "aws/codebuild/amazonlinux2-x86_64-standard:5.0")
  extra_stages                 = each.value.extra_stages != null ? each.value.extra_stages : []
  build_namespace              = each.value.build_namespace
  exported_variables           = each.value.exported_variables
  custom_pre_build_commands    = each.value.custom_pre_build_commands
  custom_build_commands        = each.value.custom_build_commands
  custom_post_build_commands   = each.value.custom_post_build_commands
  enable_security_scan         = try(each.value.enable_security_scan, false)
  security_scan_role_arn       = aws_iam_role.devsecops_role.arn
  security_reports_bucket_name = aws_s3_bucket.devsecops_reports.bucket
  build_compute_type           = each.value.build_compute_type
  security_scan_compute_type   = try(each.value.security_scan_compute_type, "BUILD_GENERAL1_SMALL")
  tags                         = each.value.tags
}

# -------------------------------------------------------------------
# Production Promotion CodeBuild Project
# Shared by all pipelines to promote images from staging to production
# -------------------------------------------------------------------

resource "aws_iam_role" "promotion_role" {
  name = "codebuild-prod-build-promotion-service-role"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "promotion_ecr" {
  role       = aws_iam_role.promotion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_role_policy_attachment" "promotion_secrets" {
  role       = aws_iam_role.promotion_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_role_policy_attachment" "promotion_s3" {
  role       = aws_iam_role.promotion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_policy" "promotion_assume_role" {
  name = "ProdECRPushAssumeRole"
  path = "/"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowAssumeProdECRPushRole"
        Action   = "sts:AssumeRole"
        Effect   = "Allow"
        Resource = "arn:aws:iam::857277800188:role/ProdECRPushRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "promotion_assume_role" {
  role       = aws_iam_role.promotion_role.name
  policy_arn = aws_iam_policy.promotion_assume_role.arn
}

resource "aws_iam_policy" "promotion_base" {
  name        = "CodeBuildBasePolicy-prod-build-promotion-ap-south-1"
  path        = "/service-role/"
  description = "Policy used in trust relationship with CodeBuild"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = ["s3:PutObject", "s3:GetObject", "s3:GetObjectVersion", "s3:GetBucketAcl", "s3:GetBucketLocation"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = ["codebuild:CreateReportGroup", "codebuild:CreateReport", "codebuild:UpdateReport", "codebuild:BatchPutTestCases", "codebuild:BatchPutCodeCoverages"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "promotion_base" {
  role       = aws_iam_role.promotion_role.name
  policy_arn = aws_iam_policy.promotion_base.arn
}

resource "aws_codebuild_project" "promotion" {
  name          = "prod-build-promotion"
  description   = "Promotes Docker images from staging to production and updates production manifests"
  build_timeout = 60
  service_role  = aws_iam_role.promotion_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "SERVICE_NAME"
      value = "coworking-platform-fe"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/buildspec_promotion.yml")
  }

  tags = {
    Environment = "stage"
    Project     = "lawyered"
    Service     = "promotion"
  }
}

# -------------------------------------------------------------------
# Argo CD Manifests Bootstrap (All YAMLs in argocd-manifests/)
# -------------------------------------------------------------------
locals {
  manifest_files = fileset("${path.root}/../argocd-manifests", "**/*.yaml")
}

resource "kubectl_manifest" "argocd_bootstrap" {
  for_each  = local.manifest_files
  yaml_body = file("${path.root}/../argocd-manifests/${each.value}")

  depends_on = [module.eks_addons]
}

# -------------------------------------------------------------------
# Migration Logic — Move existing resources from EKS module to new modules
# -------------------------------------------------------------------
moved {
  from = module.eks["eks-cluster-np"].helm_release.cluster_autoscaler
  to   = module.helm_scaling_addons["eks-cluster-np"].helm_release.cluster_autoscaler
}

moved {
  from = module.eks["eks-cluster-np"].helm_release.argo_cd
  to   = module.argocd_apps["eks-cluster-np"].helm_release.argo_cd
}


# -------------------------------------------------------------------
# KMS Module — for_each over var.kms_keys
# Global resource — no VPC dependency
# -------------------------------------------------------------------
module "kms" {
  source   = "../modules/kms"
  for_each = var.kms_keys

  alias_name              = each.key
  description             = each.value.description
  deletion_window_in_days = each.value.deletion_window_in_days
  enable_key_rotation     = each.value.enable_key_rotation
  multi_region            = each.value.multi_region
  policy                  = each.value.policy
  tags                    = each.value.tags
}

# -------------------------------------------------------------------
# S3 Module — for_each over var.s3_buckets
# kms_key_arn resolved dynamically from module.kms when kms_key is set
# -------------------------------------------------------------------
module "s3" {
  source   = "../modules/s3"
  for_each = var.s3_buckets

  bucket_name        = each.value.bucket_name
  force_destroy      = each.value.force_destroy
  versioning_enabled = each.value.versioning_enabled
  kms_key_arn        = each.value.kms_key != null ? module.kms[each.value.kms_key].key_arn : null
  lifecycle_rules    = each.value.lifecycle_rules
  tags               = each.value.tags

  depends_on = [module.kms]
}

# -------------------------------------------------------------------
# VPC Flow Logs & IAM Role (stg-mb)
# -------------------------------------------------------------------
resource "aws_iam_role" "vpc_flow_logs" {
  name = "stg-mb-vpc01-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  name = "stg-mb-vpc01-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "s3:PutObject"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "stg_mb_vpc01_logs" {
  log_destination      = module.s3["stg-mb-vpc01-flow-logs"].bucket_arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = module.vpc["stg-mb-vpc01"].vpc_id

  tags = {
    Name        = "stg-mb-vpc01-flow-logs"
    Environment = "stage"
    Project     = "lawyered"
  }
}

# -------------------------------------------------------------------
# EC2 Instance Connect Endpoint (EICE) & Security Group
# -------------------------------------------------------------------
resource "aws_security_group" "eice_sg" {
  name        = "eks-bastion-box-eice-sg2"
  description = "Security group for EC2 Instance Connect Endpoint"
  vpc_id      = module.vpc["stg-mb-vpc01"].vpc_id

  tags = {
    Name    = "eks-bastion-box-eice-sg2"
    Project = "lawyered"
  }
}

resource "aws_ec2_instance_connect_endpoint" "this" {
  subnet_id          = module.vpc["stg-mb-vpc01"].private_subnet_ids["stg-mb-app-subnet01"]
  security_group_ids = [aws_security_group.eice_sg.id]

  tags = {
    Name    = "eks-bastion-box-eice"
    Project = "lawyered"
  }
}

# Allow EICE (SG2) to talk to Bastion (SG1) on Port 22
resource "aws_security_group_rule" "allow_ssh_from_eice" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = module.ec2["eks-bastion-jumpbox"].security_group_id
  source_security_group_id = aws_security_group.eice_sg.id
  description              = "Allow SSH from EICE"
}

# Allow Bastion (SG1) to talk to EKS Cluster API (Port 443)
resource "aws_security_group_rule" "allow_bastion_to_eks" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks["eks-cluster-np"].cluster_security_group_id
  source_security_group_id = module.ec2["eks-bastion-jumpbox"].security_group_id
  description              = "Allow Bastion to communicate with EKS API"
}

# -------------------------------------------------------------------
# Argo CD Ingress — Manifest (Managed at root to avoid circularity)
# -------------------------------------------------------------------
import {
  to = kubernetes_manifest.argocd_ingress["eks-cluster-np"]
  id = "apiVersion=networking.k8s.io/v1,kind=Ingress,namespace=argo-cd,name=argocd-ingress"
}

resource "kubernetes_manifest" "argocd_ingress" {
  for_each = var.eks_clusters

  manifest = yamldecode(templatefile("${path.module}/../modules/eks/manifest/ingress.yaml.tftpl", {
    load_balancer_name = "lawyered-ingress-alb"
    group_name         = "laweryerd-np-group"
    public_subnet_ids  = join(",", [for k, v in module.vpc[each.value.vpc_key].public_subnet_ids : v])
    hostname           = "argocd-staging.lawyered.in"
    certificate_arn    = "arn:aws:acm:ap-south-1:344367180480:certificate/98c8d8d0-1e46-4a81-967a-84555529f2c3"
  }))

  depends_on = [module.eks]
}

# -------------------------------------------------------------------
# AWS Bedrock Service Integration (MiniMax M2.5 Model)
# -------------------------------------------------------------------
module "bedrock" {
  source          = "../modules/bedrock"
  environment     = "stage"
  aws_region      = var.aws_region
  model_id        = var.bedrock_model_id
  create_iam_user = var.create_bedrock_iam_user

  tags = {
    Environment = "stage"
    Project     = "lawyered"
    Service     = "deepsec"
  }
}

# -------------------------------------------------------------------
# AWS Secrets Manager Secret for Slack Alerts Webhook URL
# -------------------------------------------------------------------
resource "aws_secretsmanager_secret" "slack_webhook" {
  name                    = "devsecops/slack-webhook"
  description             = "Slack Incoming Webhook URL for DevSecOps alerts"
  recovery_window_in_days = 0
}

# -------------------------------------------------------------------
# End of Resources
# -------------------------------------------------------------------


