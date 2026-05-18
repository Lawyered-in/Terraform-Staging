aws_region = "ap-south-1"

# -------------------------------------------------------------------
# VPC Configuration
# Single VPC with 3 public subnets + 3 private subnets across 3 AZs
# nat_subnet_key picks which public subnet hosts the NAT Gateway
# -------------------------------------------------------------------
vpcs = {
  stg-mb-vpc01 = {
    cidr_block = "10.100.0.0/16"

    public_subnets = {
      stg-mb-public-subnet01 = { cidr_block = "10.100.0.0/24", availability_zone = "ap-south-1a" }
      stg-mb-public-subnet02 = { cidr_block = "10.100.16.0/24", availability_zone = "ap-south-1b" }
      stg-mb-public-subnet03 = { cidr_block = "10.100.32.0/24", availability_zone = "ap-south-1c" }

    }

    private_subnets = {
      stg-mb-app-subnet01 = { cidr_block = "10.100.48.0/23", availability_zone = "ap-south-1a" }
      stg-mb-app-subnet02 = { cidr_block = "10.100.64.0/23", availability_zone = "ap-south-1b" }
      stg-mb-app-subnet03 = { cidr_block = "10.100.80.0/23", availability_zone = "ap-south-1c" }
    }

    database_subnets = {
      stg-mb-database-subnet01 = { cidr_block = "10.100.96.0/24", availability_zone = "ap-south-1a" }
      stg-mb-database-subnet02 = { cidr_block = "10.100.112.0/24", availability_zone = "ap-south-1b" }
      stg-mb-database-subnet03 = { cidr_block = "10.100.128.0/24", availability_zone = "ap-south-1c" }
    }

    nat_subnet_key = "stg-mb-public-subnet01"

    tags = {
      Environment = "stage"
      Owner       = "infra-team"
      Project     = "lawyered"
      Service     = "vpc"
    }
  }
}
# vpc_key    : references a key in var.vpcs above
# subnet_key : references a key in that VPC's private_subnets map
# Subnet ID is resolved dynamically in main.tf — no hardcoded IDs
# -------------------------------------------------------------------
ec2_instances = {
  eks-bastion-jumpbox = {
    ami_id              = "ami-0f11fb0f6d8b520d4" # Ubuntu 24.04 ap-south-1
    instance_type       = "t3a.medium"
    vpc_key             = "stg-mb-vpc01"
    subnet_key          = "stg-mb-app-subnet01"
    key_name            = "stg-mb-eks-bastion"
    security_group_ids  = []
    associate_public_ip = false
    root_volume_size    = 30
    root_volume_type    = "gp3"
    additional_policy_arns = [
      "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
      "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    ]
    inline_policy_json = null
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Purpose     = "eks-administration"
    }
  }
}
# -------------------------------------------------------------------
# EKS Cluster Configuration - 1 Cluster
# vpc_key     : references a key in var.vpcs
# subnet_keys : private subnet keys (control plane + node groups run in private subnets)
# node_groups : inner map — each entry becomes an aws_eks_node_group via for_each
# -------------------------------------------------------------------
eks_clusters = {
  eks-cluster-np = {
    kubernetes_version      = "1.35"
    vpc_key                 = "stg-mb-vpc01"
    subnet_keys             = ["stg-mb-app-subnet01", "stg-mb-app-subnet02", "stg-mb-app-subnet03"]
    endpoint_private_access = true
    endpoint_public_access  = true

    cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

    node_groups = {
      eks-nodegroup-np = {
        desired_size   = 3
        min_size       = 1
        max_size       = 5
        instance_types = ["m6a.large"]
        capacity_type  = "ON_DEMAND"
        disk_size      = 50

        tags = {
          Name        = "eks-node-1"
          Environment = "stage"
          Project     = "lawyered"
          Service     = "eks"
        }
      }
    }
  }

}

# -------------------------------------------------------------------
# S3 Bucket Configurations
# kms_key references a key in kms_keys above for SSE-KMS encryption
# Bucket names must be globally unique — update with your account prefix
# -------------------------------------------------------------------
s3_buckets = {
  stg-mb-vpc01-flow-logs = {
    bucket_name        = "stg-mb-vpc01-flow-logs"
    force_destroy      = true
    versioning_enabled = false
    kms_key            = null
    lifecycle_rules    = {}
    tags = {
      Environment = "stage"
      Role        = "flow-logs"
      Owner       = "infra-team"
      Project     = "lawyered"
    }
  }
}

# -------------------------------------------------------------------
# ECR Repository Configurations
# -------------------------------------------------------------------
ecr_repositories = {
  admin-lawyered = {
    name                 = "admin-lawyered"
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    tags = {
      Environment = "stage"
      Owner       = "infra-team"
      Project     = "lawyered"
    }
  }
  lawyered-in-website = {
    name                 = "lawyered-in-website"
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    tags = {
      Environment = "stage"
      Owner       = "infra-team"
      Project     = "lawyered"
    }
  }
  partners-portal-fe = {
    name                 = "partners-portal-fe"
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    tags = {
      Environment = "stage"
      Owner       = "infra-team"
      Project     = "lawyered"
    }
  }
  admin-lawyered-fe = {
    name                 = "admin-lawyered-fe"
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    tags = {
      Environment = "stage"
      Owner       = "infra-team"
      Project     = "lawyered"
    }
  }
  challanpay-fe-next = {
    name                 = "challanpay-fe-next"
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    tags = {
      Environment = "stage"
      Owner       = "infra-team"
      Project     = "lawyered"
    }
  }
  api-challans = {
    name                 = "api-challans"
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    tags = {
      Environment = "stage"
      Owner       = "infra-team"
      Project     = "lawyered"
    }
  }
  qr-api = {
    name                 = "qr-api"
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    tags = {
      Environment = "stage"
      Owner       = "infra-team"
      Project     = "lawyered"
    }
  }
  core-platform-be = {
    name                 = "core-platform-be"
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    tags = {
      Environment = "stage"
      Owner       = "infra-team"
      Project     = "lawyered"
    }
  }
  core-platform-fe = {
    name                 = "core-platform-fe"
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    tags = {
      Environment = "stage"
      Owner       = "infra-team"
      Project     = "lawyered"
    }
  }
  coworking-platform-be = {
    name                 = "coworking-platform-be"
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    tags = {
      Environment = "stage"
      Owner       = "infra-team"
      Project     = "lawyered"
    }
  }
  coworking-platform-fe = {
    name                 = "coworking-platform-fe"
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    tags = {
      Environment = "stage"
      Owner       = "infra-team"
      Project     = "lawyered"
    }
  }
  prosper-be = {
    name                 = "prosper-be"
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    tags = {
      Environment = "stage"
      Owner       = "infra-team"
      Project     = "prosper-wealth"
    }
  }
  prosper-fe = {
    name                 = "prosper-fe"
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    tags = {
      Environment = "stage"
      Owner       = "infra-team"
      Project     = "prosper-wealth"
    }
  }
  # ------------------------------------------------------------------
  # subscriber-fe
  # ECR Repository for the Subscriber Frontend application.
  # ------------------------------------------------------------------
  subscriber-fe = {
    name                 = "subscriber-fe"
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    tags = {
      Environment = "stage"
      Owner       = "infra-team"
      Project     = "lawyered"
    }
  }
  # ------------------------------------------------------------------
  # lawyered-be
  # ECR Repository for the Lawyered Backend application.
  # ------------------------------------------------------------------
  lawyered-be = {
    name                 = "lawyered-be"
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    tags = {
      Environment = "stage"
      Owner       = "infra-team"
      Project     = "lawyered"
    }
  }
}
# -------------------------------------------------------------------
# Aurora Cluster Configurations
# -------------------------------------------------------------------
aurora_clusters = {
  lawyered-database = {
    database_name           = "lawyered_db"
    master_username         = "admin"
    vpc_key                 = "stg-mb-vpc01"
    subnet_keys             = ["stg-mb-public-subnet01", "stg-mb-public-subnet02"]
    preferred_az            = "ap-south-1a"
    backup_retention_period = 7
    deletion_protection     = true
    skip_final_snapshot     = true
    db_subnet_group_name    = "lawyered-database-pub-subnet-group"
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Role        = "database-aurora"
    }
  }
}

# -------------------------------------------------------------------
# RDS Instance Configurations
# -------------------------------------------------------------------
rds_instances = {
  core-uat-db = {
    engine                      = "postgres"
    engine_version              = "18.3"
    instance_class              = "db.t4g.medium"
    allocated_storage           = 30
    max_allocated_storage       = 500
    db_name                     = "core_uat_db"
    username                    = "dbadmin"
    password                    = "SecureTempPassword123!"
    vpc_key                     = "stg-mb-vpc01"
    subnet_keys                 = ["stg-mb-public-subnet01", "stg-mb-public-subnet02"]
    backup_retention_period     = 7
    deletion_protection         = true
    publicly_accessible         = true
    db_subnet_group_name        = "core-uat-db-pub-subnet-group"
    allow_major_version_upgrade = true
    tags = {
      Environment = "uat"
      Project     = "core"
    }
  }

  finvica = {
    engine                      = "postgres"
    engine_version              = "18.3"
    instance_class              = "db.t4g.medium"
    allocated_storage           = 30
    max_allocated_storage       = 100
    db_name                     = "finvica"
    username                    = "dbadmin"
    password                    = "F1nvic4-Stg-2026-S3cur3#"
    vpc_key                     = "stg-mb-vpc01"
    subnet_keys                 = ["stg-mb-public-subnet01", "stg-mb-public-subnet02"]
    backup_retention_period     = 7
    deletion_protection         = true
    publicly_accessible         = true
    db_subnet_group_name        = "finvica-pub-subnet-group"
    allow_major_version_upgrade = true
    tags = {
      Environment = "staging"
      Project     = "finvica"
    }
  }

  lawyered-backend-new = {
    engine                      = "postgres"
    engine_version              = "18.3"
    instance_class              = "db.t4g.medium"
    allocated_storage           = 30
    max_allocated_storage       = 100
    db_name                     = "lawyered_backend_new"
    username                    = "dbadmin"
    password                    = "Lawyered-Backend-2026-Secure#91^"
    vpc_key                     = "stg-mb-vpc01"
    subnet_keys                 = ["stg-mb-public-subnet01", "stg-mb-public-subnet02"]
    backup_retention_period     = 7
    deletion_protection         = true
    publicly_accessible         = true
    db_subnet_group_name        = "lawyered-backend-new-pub-subnet-group"
    allow_major_version_upgrade = true
    tags = {
      Environment = "staging"
      Project     = "lawyered"
    }
  }
}

github_connection_arn = "arn:aws:codeconnections:ap-south-1:344367180480:connection/57bb41a6-94e5-4be9-9364-73bc9da899d3"

codepipelines = {
  admin-lawyered-fe = {
    repository_id      = "Lawyered-in/admin-lawyered-fe"
    branch_name        = "main"
    ecr_key            = "admin-lawyered-fe"
    prefetch_images    = ["node:20-alpine"]
    manifest_file_path = "deployments/stg-admin-lawyered-fe"
    build_image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace    = "StagingBuildNamespace"
    exported_variables = ["IMAGE_TAG", "REPOS_URL"]
    build_args = {
      VITE_API_URL          = "https://api-staging.lawyered.in"
      VITE_ENV              = "production"
      VITE_ENABLE_TELEMETRY = "false"
    }
    extra_stages = [
      {
        name = "ApproveForProduction"
        action = [
          {
            name     = "ManualApproval"
            category = "Approval"
            owner    = "AWS"
            provider = "Manual"
            version  = "1"
          }
        ]
      },
      {
        name = "PromoteToProduction"
        action = [
          {
            name            = "ProdPromotion"
            category        = "Build"
            owner           = "AWS"
            provider        = "CodeBuild"
            version         = "1"
            input_artifacts = ["source_output"]
            configuration = {
              ProjectName          = "prod-build-promotion"
              EnvironmentVariables = "[{\"name\":\"IMAGE_TAG\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.IMAGE_TAG}\"},{\"name\":\"REPOS_URL\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.REPOS_URL}\"},{\"name\":\"SERVICE_NAME\",\"type\":\"PLAINTEXT\",\"value\":\"admin-lawyered-fe\"}]"
            }
          }
        ]
      }
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  admin-lawyered = {
    repository_id      = "Lawyered-in/admin-lawyered"
    branch_name        = "main"
    ecr_key            = "admin-lawyered"
    prefetch_images    = ["node:20-alpine"]
    manifest_file_path = "deployments/stg-admin-lawyered"
    build_image        = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    build_namespace    = "StagingBuildNamespace"
    exported_variables = ["IMAGE_TAG", "REPOS_URL"]
    build_args = {
      DATABASE_URL = "mysql://admin:E7mshc5M7L3fkAVPc2<5qRT6o6i2@lawyered-database.cluster-cj446ammul0i.ap-south-1.rds.amazonaws.com:3306/proddblawyered"
    }
    custom_build_commands = [
      "echo Build started on `date`",
      "echo Using DATABASE_URL from environment variables...",
      "npm install",
      "echo Installing dependencies...",
      "npm run generate",
      "echo Building the Docker image...",
      "docker build -t $REPOS_URL:latest .",
      "docker tag $REPOS_URL:latest $REPOS_URL:$IMAGE_TAG"
    ]
    extra_stages = [
      {
        name = "ApproveForProduction"
        action = [
          {
            name     = "ManualApproval"
            category = "Approval"
            owner    = "AWS"
            provider = "Manual"
            version  = "1"
          }
        ]
      },
      {
        name = "PromoteToProduction"
        action = [
          {
            name            = "ProdPromotion"
            category        = "Build"
            owner           = "AWS"
            provider        = "CodeBuild"
            version         = "1"
            input_artifacts = ["source_output"]
            configuration = {
              ProjectName          = "prod-build-promotion"
              EnvironmentVariables = "[{\"name\":\"IMAGE_TAG\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.IMAGE_TAG}\"},{\"name\":\"REPOS_URL\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.REPOS_URL}\"},{\"name\":\"SERVICE_NAME\",\"type\":\"PLAINTEXT\",\"value\":\"admin-lawyered\"}]"
            }
          }
        ]
      }
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  lawyered-in-website = {
    repository_id      = "Lawyered-in/lawyered.in-website"
    branch_name        = "main"
    ecr_key            = "lawyered-in-website"
    prefetch_images    = ["node:20-alpine"]
    manifest_file_path = "deployments/stg-lawyered-in-website"
    build_image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace    = "StagingBuildNamespace"
    exported_variables = ["IMAGE_TAG", "REPOS_URL"]
    build_args = {
      NEXT_PUBLIC_R2_STORAGE_URL = "https://pub-ac446d6e98cd462ba35be4f49108d1b8.r2.dev/lawyered-website-assets"
    }
    extra_stages = [
      {
        name = "ApproveForProduction"
        action = [
          {
            name     = "ManualApproval"
            category = "Approval"
            owner    = "AWS"
            provider = "Manual"
            version  = "1"
          }
        ]
      },
      {
        name = "PromoteToProduction"
        action = [
          {
            name            = "ProdPromotion"
            category        = "Build"
            owner           = "AWS"
            provider        = "CodeBuild"
            version         = "1"
            input_artifacts = ["source_output"]
            configuration = {
              ProjectName          = "prod-build-promotion"
              EnvironmentVariables = "[{\"name\":\"IMAGE_TAG\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.IMAGE_TAG}\"},{\"name\":\"REPOS_URL\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.REPOS_URL}\"},{\"name\":\"SERVICE_NAME\",\"type\":\"PLAINTEXT\",\"value\":\"lawyered-in-website\"}]"
            }
          }
        ]
      }
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  partners-portal-fe = {
    repository_id      = "Lawyered-in/partners-portal-fe"
    branch_name        = "main"
    ecr_key            = "partners-portal-fe"
    prefetch_images    = ["node:20-alpine"]
    manifest_file_path = "deployments/stg-partners-portal-fe"
    build_image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace    = "StagingBuildNamespace"
    exported_variables = ["IMAGE_TAG", "REPOS_URL"]
    extra_stages = [
      {
        name = "ApproveForProduction"
        action = [
          {
            name     = "ManualApproval"
            category = "Approval"
            owner    = "AWS"
            provider = "Manual"
            version  = "1"
          }
        ]
      },
      {
        name = "PromoteToProduction"
        action = [
          {
            name            = "ProdPromotion"
            category        = "Build"
            owner           = "AWS"
            provider        = "CodeBuild"
            version         = "1"
            input_artifacts = ["source_output"]
            configuration = {
              ProjectName          = "prod-build-promotion"
              EnvironmentVariables = "[{\"name\":\"IMAGE_TAG\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.IMAGE_TAG}\"},{\"name\":\"REPOS_URL\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.REPOS_URL}\"},{\"name\":\"SERVICE_NAME\",\"type\":\"PLAINTEXT\",\"value\":\"partners-portal-fe\"}]"
            }
          }
        ]
      }
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  challanpay-fe-next = {
    repository_id      = "Lawyered-in/challanpay-fe-next"
    branch_name        = "main"
    ecr_key            = "challanpay-fe-next"
    prefetch_images    = ["node:20-alpine"]
    manifest_file_path = "deployments/stg-challanpay-fe-next"
    build_image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace    = "StagingBuildNamespace"
    exported_variables = ["IMAGE_TAG", "REPOS_URL"]
    build_args = {
      NEXT_PUBLIC_R2_STORAGE_URL = "https://pub-ac446d6e98cd462ba35be4f49108d1b8.r2.dev/challanpay-website-assets"
    }
    extra_stages = [
      {
        name = "ApproveForProduction"
        action = [
          {
            name     = "ManualApproval"
            category = "Approval"
            owner    = "AWS"
            provider = "Manual"
            version  = "1"
          }
        ]
      },
      {
        name = "PromoteToProduction"
        action = [
          {
            name            = "ProdPromotion"
            category        = "Build"
            owner           = "AWS"
            provider        = "CodeBuild"
            version         = "1"
            input_artifacts = ["source_output"]
            configuration = {
              ProjectName          = "prod-build-promotion"
              EnvironmentVariables = "[{\"name\":\"IMAGE_TAG\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.IMAGE_TAG}\"},{\"name\":\"REPOS_URL\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.REPOS_URL}\"},{\"name\":\"SERVICE_NAME\",\"type\":\"PLAINTEXT\",\"value\":\"challanpay-fe-next\"}]"
            }
          }
        ]
      }
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  api-challans = {
    repository_id      = "Lawyered-in/api-challans"
    branch_name        = "main"
    ecr_key            = "api-challans"
    prefetch_images    = ["node:20-alpine"]
    manifest_file_path = "deployments/stg-api-challans"
    build_image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace    = "StagingBuildNamespace"
    exported_variables = ["IMAGE_TAG", "REPOS_URL"]
    extra_stages = [
      {
        name = "ApproveForProduction"
        action = [
          {
            name     = "ManualApproval"
            category = "Approval"
            owner    = "AWS"
            provider = "Manual"
            version  = "1"
          }
        ]
      },
      {
        name = "PromoteToProduction"
        action = [
          {
            name            = "ProdPromotion"
            category        = "Build"
            owner           = "AWS"
            provider        = "CodeBuild"
            version         = "1"
            input_artifacts = ["source_output"]
            configuration = {
              ProjectName          = "prod-build-promotion"
              EnvironmentVariables = "[{\"name\":\"IMAGE_TAG\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.IMAGE_TAG}\"},{\"name\":\"REPOS_URL\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.REPOS_URL}\"},{\"name\":\"SERVICE_NAME\",\"type\":\"PLAINTEXT\",\"value\":\"api-challans\"}]"
            }
          }
        ]
      }
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  qr-api = {
    repository_id      = "Lawyered-in/qr-api"
    branch_name        = "main"
    ecr_key            = "qr-api"
    prefetch_images    = ["node:20-alpine"]
    manifest_file_path = "deployments/stg-qr-api"
    build_image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace    = "StagingBuildNamespace"
    exported_variables = ["IMAGE_TAG", "REPOS_URL"]
    extra_stages = [
      {
        name = "ApproveForProduction"
        action = [
          {
            name     = "ManualApproval"
            category = "Approval"
            owner    = "AWS"
            provider = "Manual"
            version  = "1"
          }
        ]
      },
      {
        name = "PromoteToProduction"
        action = [
          {
            name            = "ProdPromotion"
            category        = "Build"
            owner           = "AWS"
            provider        = "CodeBuild"
            version         = "1"
            input_artifacts = ["source_output"]
            configuration = {
              ProjectName          = "prod-build-promotion"
              EnvironmentVariables = "[{\"name\":\"IMAGE_TAG\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.IMAGE_TAG}\"},{\"name\":\"REPOS_URL\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.REPOS_URL}\"},{\"name\":\"SERVICE_NAME\",\"type\":\"PLAINTEXT\",\"value\":\"qr-api\"}]"
            }
          }
        ]
      }
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }

  # ------------------------------------------------------------------
  # core-platform-be
  # GitHub Org : india-accelerator
  # Branch     : development-branch
  # ECR Repo   : core-platform-be (already created)
  # k8s path   : deployments/stg-core-platform-be in k8s-manifest repo
  # ------------------------------------------------------------------
  core-platform-be = {
    repository_id      = "india-accelerator/core-platform-be" # Full GitHub org/repo path
    branch_name        = "Deployment-production"                 # Dedicated deployment branch
    ecr_key            = "core-platform-be"                   # References ecr_repositories key above
    prefetch_images    = ["node:22-alpine"]                   # Pre-pull to avoid Docker Hub rate limits
    manifest_file_path = "deployments/stg-core-platform-be"   # Path in k8s-manifest repo to update
    build_image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace    = "StagingBuildNamespace"
    exported_variables = ["IMAGE_TAG", "REPOS_URL"]
    extra_stages = [
      {
        name = "ApproveForProduction"
        action = [
          {
            name     = "ManualApproval"
            category = "Approval"
            owner    = "AWS"
            provider = "Manual"
            version  = "1"
          }
        ]
      },
      {
        name = "PromoteToProduction"
        action = [
          {
            name            = "ProdPromotion"
            category        = "Build"
            owner           = "AWS"
            provider        = "CodeBuild"
            version         = "1"
            input_artifacts = ["source_output"]
            configuration = {
              ProjectName          = "prod-build-promotion"
              EnvironmentVariables = "[{\"name\":\"IMAGE_TAG\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.IMAGE_TAG}\"},{\"name\":\"REPOS_URL\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.REPOS_URL}\"},{\"name\":\"SERVICE_NAME\",\"type\":\"PLAINTEXT\",\"value\":\"core-platform-be\"}]"
            }
          }
        ]
      }
    ]
    connection_arn = "arn:aws:codeconnections:ap-south-1:344367180480:connection/a0fa3689-09c2-43c4-8dc3-0ffc90e7bbb0"
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }

  # ------------------------------------------------------------------
  # core-platform-fe
  # GitHub Org : india-accelerator
  # Branch     : development-branch
  # ECR Repo   : core-platform-fe (already created)
  # k8s path   : deployments/stg-core-platform-fe in k8s-manifest repo
  # ------------------------------------------------------------------
  core-platform-fe = {
    repository_id      = "india-accelerator/core-platform-fe" # Full GitHub org/repo path
    branch_name        = "production"                 # Dedicated deployment branch
    ecr_key            = "core-platform-fe"                   # References ecr_repositories key above
    prefetch_images    = ["node:22-bullseye"]                 # Pre-pull to avoid Docker Hub rate limits
    manifest_file_path = "deployments/stg-core-platform-fe"   # Path in k8s-manifest repo to update
    build_image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace    = "StagingBuildNamespace"
    exported_variables = ["IMAGE_TAG", "REPOS_URL"]
    extra_stages = [
      {
        name = "ApproveForProduction"
        action = [
          {
            name     = "ManualApproval"
            category = "Approval"
            owner    = "AWS"
            provider = "Manual"
            version  = "1"
          }
        ]
      },
      {
        name = "PromoteToProduction"
        action = [
          {
            name            = "ProdPromotion"
            category        = "Build"
            owner           = "AWS"
            provider        = "CodeBuild"
            version         = "1"
            input_artifacts = ["source_output"]
            configuration = {
              ProjectName          = "prod-build-promotion"
              EnvironmentVariables = "[{\"name\":\"IMAGE_TAG\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.IMAGE_TAG}\"},{\"name\":\"REPOS_URL\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.REPOS_URL}\"},{\"name\":\"SERVICE_NAME\",\"type\":\"PLAINTEXT\",\"value\":\"core-platform-fe\"}]"
            }
          }
        ]
      }
    ]
    connection_arn = "arn:aws:codeconnections:ap-south-1:344367180480:connection/a0fa3689-09c2-43c4-8dc3-0ffc90e7bbb0"
    build_image    = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    build_args = {
      VITE_API_URL = "https://core-platform-be-dev.indiaaccelerator.co/api"
    }
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }

  # ------------------------------------------------------------------
  # coworking-platform-be
  # GitHub Org : IA-COW
  # Branch     : main
  # ECR Repo   : coworking-platform-be (already created)
  # k8s path   : deployments/stg-coworking-platform-be in k8s-manifest repo
  # ------------------------------------------------------------------
  coworking-platform-be = {
    repository_id      = "IA-COW/coworking-platform-be"          # Full GitHub org/repo path
    branch_name        = "main"                                  # Developer push branch
    ecr_key            = "coworking-platform-be"                 # References ecr_repositories key above
    prefetch_images    = ["node:20-alpine"]                      # Pre-pull to avoid Docker Hub rate limits
    manifest_file_path = "deployments/stg-coworking-platform-be" # Path in k8s-manifest repo to update
    build_image        = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    build_namespace    = "StagingBuildNamespace"
    exported_variables = ["IMAGE_TAG", "REPOS_URL"]
    build_args = {
      DB_DATABASE = "cow_dev_db"
      DB_USERNAME = "dbadmin"
      DB_HOST     = "core-uat-db.cj446ammul0i.ap-south-1.rds.amazonaws.com"
      DB_PASSWORD = "SecureTempPassword123!"
      DB_PORT     = "5432"
      PGSSLMODE   = "require"
    }
    custom_build_commands = [
      "echo Build started on `date`",
      "npm install",
      "echo Building the Docker image...",
      "docker build  -t $REPOS_URL:latest .",
      "docker tag $REPOS_URL:latest $REPOS_URL:$IMAGE_TAG"
    ]
    extra_stages = [
      {
        name = "ApproveForProduction"
        action = [
          {
            name     = "ManualApproval"
            category = "Approval"
            owner    = "AWS"
            provider = "Manual"
            version  = "1"
          }
        ]
      },
      {
        name = "PromoteToProduction"
        action = [
          {
            name            = "ProdPromotion"
            category        = "Build"
            owner           = "AWS"
            provider        = "CodeBuild"
            version         = "1"
            input_artifacts = ["source_output"]
            configuration = {
              ProjectName          = "prod-build-promotion"
              EnvironmentVariables = "[{\"name\":\"IMAGE_TAG\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.IMAGE_TAG}\"},{\"name\":\"REPOS_URL\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.REPOS_URL}\"},{\"name\":\"SERVICE_NAME\",\"type\":\"PLAINTEXT\",\"value\":\"coworking-platform-be\"}]"
            }
          }
        ]
      }
    ]
    connection_arn = "arn:aws:codeconnections:ap-south-1:344367180480:connection/5fb5e82a-dcb4-4f0b-b5e5-10ab4496e9af"
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }

  # ------------------------------------------------------------------
  # coworking-platform-fe
  # GitHub Org : IA-COW
  # Branch     : main
  # ECR Repo   : coworking-platform-fe (already created)
  # k8s path   : deployments/stg-coworking-platform-fe in k8s-manifest repo
  # ------------------------------------------------------------------
  coworking-platform-fe = {
    repository_id      = "IA-COW/coworking-platform-fe"          # Full GitHub org/repo path
    branch_name        = "main"                                  # Developer push branch
    ecr_key            = "coworking-platform-fe"                 # References ecr_repositories key above
    prefetch_images    = ["node:20-alpine"]                      # Pre-pull to avoid Docker Hub rate limits
    manifest_file_path = "deployments/stg-coworking-platform-fe" # Path in k8s-manifest repo to update
    connection_arn     = "arn:aws:codeconnections:ap-south-1:344367180480:connection/5fb5e82a-dcb4-4f0b-b5e5-10ab4496e9af"
    build_image        = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    build_namespace    = "StagingBuildNamespace"
    exported_variables = ["IMAGE_TAG", "REPOS_URL"]
    build_args = {
      API_URL             = "https://cow-dev-be.indiaaccelerator.co/api"
      NEXT_PUBLIC_API_URL = "https://cow-dev-be.indiaaccelerator.co/api"
    }
    extra_stages = [
      {
        name = "ApproveForProduction"
        action = [
          {
            name     = "ManualApproval"
            category = "Approval"
            owner    = "AWS"
            provider = "Manual"
            version  = "1"
          }
        ]
      },
      {
        name = "PromoteToProduction"
        action = [
          {
            name            = "ProdPromotion"
            category        = "Build"
            owner           = "AWS"
            provider        = "CodeBuild"
            version         = "1"
            input_artifacts = ["source_output"]
            configuration = {
              ProjectName          = "prod-build-promotion"
              EnvironmentVariables = "[{\"name\":\"IMAGE_TAG\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.IMAGE_TAG}\"},{\"name\":\"REPOS_URL\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.REPOS_URL}\"},{\"name\":\"SERVICE_NAME\",\"type\":\"PLAINTEXT\",\"value\":\"coworking-platform-fe\"}]"
            }
          }
        ]
      }
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  # ------------------------------------------------------------------
  # prosper-be
  # GitHub Org : prosper-wealth
  # Branch     : staging
  # ------------------------------------------------------------------
  prosper-be = {
    repository_id      = "prosper-wealth/prosper-be"
    branch_name        = "main"
    ecr_key            = "prosper-be"
    prefetch_images    = ["node:22-alpine"]
    manifest_file_path = "deployments/stg-prosper-be"
    build_image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace    = "StagingBuildNamespace"
    exported_variables = ["IMAGE_TAG", "REPOS_URL"]
    extra_stages = [
      {
        name = "ApproveForProduction"
        action = [
          {
            name     = "ManualApproval"
            category = "Approval"
            owner    = "AWS"
            provider = "Manual"
            version  = "1"
          }
        ]
      },
      {
        name = "PromoteToProduction"
        action = [
          {
            name            = "ProdPromotion"
            category        = "Build"
            owner           = "AWS"
            provider        = "CodeBuild"
            version         = "1"
            input_artifacts = ["source_output"]
            configuration = {
              ProjectName          = "prod-build-promotion"
              EnvironmentVariables = "[{\"name\":\"IMAGE_TAG\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.IMAGE_TAG}\"},{\"name\":\"REPOS_URL\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.REPOS_URL}\"},{\"name\":\"SERVICE_NAME\",\"type\":\"PLAINTEXT\",\"value\":\"prosper-be\"}]"
            }
          }
        ]
      }
    ]
    connection_arn = "arn:aws:codeconnections:ap-south-1:344367180480:connection/c262ed12-f5b1-493e-b971-52d70e33bfca"
    tags = {
      Environment = "stage"
      Project     = "prosper-wealth"
      Service     = "pipeline"
    }
  }

  # ------------------------------------------------------------------
  # prosper-fe
  # GitHub Org : prosper-wealth
  # Branch     : staging
  # ------------------------------------------------------------------
  prosper-fe = {
    repository_id      = "prosper-wealth/prosper-fe"
    branch_name        = "main"
    ecr_key            = "prosper-fe"
    prefetch_images    = ["node:20-alpine"]
    manifest_file_path = "deployments/stg-prosper-fe"
    build_image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace    = "StagingBuildNamespace"
    exported_variables = ["IMAGE_TAG", "REPOS_URL"]
    extra_stages = [
      {
        name = "ApproveForProduction"
        action = [
          {
            name     = "ManualApproval"
            category = "Approval"
            owner    = "AWS"
            provider = "Manual"
            version  = "1"
          }
        ]
      },
      {
        name = "PromoteToProduction"
        action = [
          {
            name            = "ProdPromotion"
            category        = "Build"
            owner           = "AWS"
            provider        = "CodeBuild"
            version         = "1"
            input_artifacts = ["source_output"]
            configuration = {
              ProjectName          = "prod-build-promotion"
              EnvironmentVariables = "[{\"name\":\"IMAGE_TAG\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.IMAGE_TAG}\"},{\"name\":\"REPOS_URL\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.REPOS_URL}\"},{\"name\":\"SERVICE_NAME\",\"type\":\"PLAINTEXT\",\"value\":\"prosper-fe\"}]"
            }
          }
        ]
      }
    ]
    connection_arn = "arn:aws:codeconnections:ap-south-1:344367180480:connection/c262ed12-f5b1-493e-b971-52d70e33bfca"
    build_args = {
      VITE_API_URL = "https://staging-api.finvica.com/api/v1"
    }
    tags = {
      Environment = "stage"
      Project     = "prosper-wealth"
      Service     = "pipeline"
    }
  }

  # ------------------------------------------------------------------
  # subscriber-fe Pipeline
  # Manages CI/CD for subscriber-fe.
  # Source: Lawyered-in/subscriber-fe (staging branch)
  # Destination: ECR (subscriber-fe) & k8s-manifests (deployments/stg-subscriber-fe)
  # ------------------------------------------------------------------
  subscriber-fe = {
    repository_id      = "Lawyered-in/subscriber-fe"
    branch_name        = "main"
    ecr_key            = "subscriber-fe"
    prefetch_images    = ["node:20-alpine"]
    manifest_file_path = "deployments/stg-subscriber-fe"
    build_image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace    = "StagingBuildNamespace"
    exported_variables = ["IMAGE_TAG", "REPOS_URL"]
    extra_stages = [
      {
        name = "ApproveForProduction"
        action = [
          {
            name     = "ManualApproval"
            category = "Approval"
            owner    = "AWS"
            provider = "Manual"
            version  = "1"
          }
        ]
      },
      {
        name = "PromoteToProduction"
        action = [
          {
            name            = "ProdPromotion"
            category        = "Build"
            owner           = "AWS"
            provider        = "CodeBuild"
            version         = "1"
            input_artifacts = ["source_output"]
            configuration = {
              ProjectName          = "prod-build-promotion"
              EnvironmentVariables = "[{\"name\":\"IMAGE_TAG\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.IMAGE_TAG}\"},{\"name\":\"REPOS_URL\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.REPOS_URL}\"},{\"name\":\"SERVICE_NAME\",\"type\":\"PLAINTEXT\",\"value\":\"subscriber-fe\"}]"
            }
          }
        ]
      }
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }

  # ------------------------------------------------------------------
  # lawyered-be Pipeline
  # Manages CI/CD for lawyered-be.
  # Source: Lawyered-in/lawyered-be (staging branch)
  # Destination: ECR (lawyered-be) & k8s-manifests (deployments/stg-lawyered-be)
  # ------------------------------------------------------------------
  lawyered-be = {
    repository_id      = "Lawyered-in/lawyered-be"
    branch_name        = "main"
    ecr_key            = "lawyered-be"
    prefetch_images    = ["node:20-alpine"]
    manifest_file_path = "deployments/stg-lawyered-be"
    build_image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace    = "StagingBuildNamespace"
    exported_variables = ["IMAGE_TAG", "REPOS_URL"]
    extra_stages = [
      {
        name = "ApproveForProduction"
        action = [
          {
            name     = "ManualApproval"
            category = "Approval"
            owner    = "AWS"
            provider = "Manual"
            version  = "1"
          }
        ]
      },
      {
        name = "PromoteToProduction"
        action = [
          {
            name            = "ProdPromotion"
            category        = "Build"
            owner           = "AWS"
            provider        = "CodeBuild"
            version         = "1"
            input_artifacts = ["source_output"]
            configuration = {
              ProjectName          = "prod-build-promotion"
              EnvironmentVariables = "[{\"name\":\"IMAGE_TAG\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.IMAGE_TAG}\"},{\"name\":\"REPOS_URL\",\"type\":\"PLAINTEXT\",\"value\":\"#{StagingBuildNamespace.REPOS_URL}\"},{\"name\":\"SERVICE_NAME\",\"type\":\"PLAINTEXT\",\"value\":\"lawyered-be\"}]"
            }
          }
        ]
      }
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
}
