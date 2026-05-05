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
}
# -------------------------------------------------------------------
# Aurora Cluster Configurations
# -------------------------------------------------------------------
aurora_clusters = {
  lawyered-database = {
    database_name   = "lawyered_db" # DB name cannot contain hyphens in some engines, using underscore
    master_username = "admin"
    vpc_key         = "stg-mb-vpc01"
    subnet_keys     = ["stg-mb-database-subnet01", "stg-mb-database-subnet02", "stg-mb-database-subnet03"]
    preferred_az    = "ap-south-1a"
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
    engine                = "postgres"
    engine_version        = "15" # More flexible version identifier
    instance_class        = "db.t4g.medium"
    allocated_storage     = 30
    max_allocated_storage = 500
    db_name               = "core_uat_db"
    username              = "dbadmin"
    password              = "SecureTempPassword123!" # Changed to remove forbidden characters
    vpc_key               = "stg-mb-vpc01"
    subnet_keys           = ["stg-mb-database-subnet01", "stg-mb-database-subnet02", "stg-mb-database-subnet03"]
    multi_az              = false
    skip_final_snapshot   = true
    tags = {
      Environment = "uat"
      Project     = "core"
      Role        = "database-rds"
    }
  }
}

github_connection_arn = "arn:aws:codeconnections:ap-south-1:344367180480:connection/57bb41a6-94e5-4be9-9364-73bc9da899d3"

codepipelines = {
  admin-lawyered-fe = {
    repository_id      = "Lawyered-in/admin-lawyered-fe"
    branch_name        = "staging"
    ecr_key            = "admin-lawyered-fe"
    prefetch_images    = ["node:20-alpine"]
    manifest_file_path = "deployments/stg-admin-lawyered-fe"
    build_args = {
      VITE_API_URL          = "https://api-staging.lawyered.in"
      VITE_ENV              = "production"
      VITE_ENABLE_TELEMETRY = "false"
    }
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  admin-lawyered = {
    repository_id      = "Lawyered-in/admin-lawyered"
    branch_name        = "staging"
    ecr_key            = "admin-lawyered"
    prefetch_images    = ["node:20-alpine"]
    manifest_file_path = "deployments/stg-admin-lawyered"
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  lawyered-in-website = {
    repository_id      = "Lawyered-in/lawyered.in-website"
    branch_name        = "staging"
    ecr_key            = "lawyered-in-website"
    prefetch_images    = ["node:20-alpine"]
    manifest_file_path = "deployments/stg-lawyered-in-website"
    build_args = {
      NEXT_PUBLIC_R2_STORAGE_URL = "https://pub-ac446d6e98cd462ba35be4f49108d1b8.r2.dev/lawyered-website-assets"
    }
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  partners-portal-fe = {
    repository_id      = "Lawyered-in/partners-portal-fe"
    branch_name        = "staging"
    ecr_key            = "partners-portal-fe"
    prefetch_images    = ["node:20-alpine"]
    manifest_file_path = "deployments/stg-partners-portal-fe"
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  challanpay-fe-next = {
    repository_id      = "Lawyered-in/challanpay-fe-next"
    branch_name        = "staging"
    ecr_key            = "challanpay-fe-next"
    prefetch_images    = ["node:20-alpine"]
    manifest_file_path = "deployments/stg-challanpay-fe-next"
    build_args = {
      NEXT_PUBLIC_R2_STORAGE_URL = "https://pub-ac446d6e98cd462ba35be4f49108d1b8.r2.dev/challanpay-website-assets"
    }
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  api-challans = {
    repository_id      = "Lawyered-in/api-challans"
    branch_name        = "staging"
    ecr_key            = "api-challans"
    prefetch_images    = ["node:20-alpine"]
    manifest_file_path = "deployments/stg-api-challans"
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  qr-api = {
    repository_id      = "Lawyered-in/qr-api"
    branch_name        = "staging"
    ecr_key            = "qr-api"
    prefetch_images    = ["node:20-alpine"]
    manifest_file_path = "deployments/stg-qr-api"
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
    branch_name        = "development-branch"                 # Correct branch for core
    ecr_key            = "core-platform-be"                   # References ecr_repositories key above
    prefetch_images    = ["node:22-alpine"]                   # Pre-pull to avoid Docker Hub rate limits
    manifest_file_path = "deployments/stg-core-platform-be"   # Path in k8s-manifest repo to update
    connection_arn     = "arn:aws:codeconnections:ap-south-1:344367180480:connection/a0fa3689-09c2-43c4-8dc3-0ffc90e7bbb0"
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
    branch_name        = "development-branch"                 # Correct branch for core
    ecr_key            = "core-platform-fe"                   # References ecr_repositories key above
    prefetch_images    = ["node:22-bullseye"]                 # Pre-pull to avoid Docker Hub rate limits
    manifest_file_path = "deployments/stg-core-platform-fe"   # Path in k8s-manifest repo to update
    connection_arn     = "arn:aws:codeconnections:ap-south-1:344367180480:connection/a0fa3689-09c2-43c4-8dc3-0ffc90e7bbb0"
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
    branch_name        = "develop"                               # Using develop branch
    ecr_key            = "coworking-platform-be"                 # References ecr_repositories key above
    prefetch_images    = ["node:20-alpine"]                      # Pre-pull to avoid Docker Hub rate limits
    manifest_file_path = "deployments/stg-coworking-platform-be" # Path in k8s-manifest repo to update
    connection_arn     = "arn:aws:codeconnections:ap-south-1:344367180480:connection/2d23ed7b-a5f6-4e52-ac83-049adcf66c2a"
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
    branch_name        = "develop"                               # Using develop branch
    ecr_key            = "coworking-platform-fe"                 # References ecr_repositories key above
    prefetch_images    = ["node:20-alpine"]                      # Pre-pull to avoid Docker Hub rate limits
    manifest_file_path = "deployments/stg-coworking-platform-fe" # Path in k8s-manifest repo to update
    connection_arn     = "arn:aws:codeconnections:ap-south-1:344367180480:connection/2d23ed7b-a5f6-4e52-ac83-049adcf66c2a"
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
    branch_name        = "staging"
    ecr_key            = "prosper-be"
    prefetch_images    = ["node:22-alpine"]
    manifest_file_path = "deployments/stg-prosper-be"
    connection_arn     = "arn:aws:codeconnections:ap-south-1:344367180480:connection/c262ed12-f5b1-493e-b971-52d70e33bfca"
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
    branch_name        = "staging"
    ecr_key            = "prosper-fe"
    prefetch_images    = ["node:20-alpine"]
    manifest_file_path = "deployments/stg-prosper-fe"
    connection_arn     = "arn:aws:codeconnections:ap-south-1:344367180480:connection/c262ed12-f5b1-493e-b971-52d70e33bfca"
    tags = {
      Environment = "stage"
      Project     = "prosper-wealth"
      Service     = "pipeline"
    }
  }
}
