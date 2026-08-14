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
        max_size       = 7
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
  lots247-in = {
    name                 = "lots247-in"
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
  challan-screening = {
    name                 = "challan-screening"
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
  faas-be = {
    name                 = "faas-be"
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    tags = {
      Environment = "stage"
      Owner       = "infra-team"
      Project     = "prosper-wealth"
    }
  }
  faas-fe = {
    name                 = "faas-fe"
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
  # ------------------------------------------------------------------
  # laravel-api
  # ECR Repository for the Laravel API application.
  # ------------------------------------------------------------------
  laravel-api = {
    name                 = "laravel-api"
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    tags = {
      Environment = "stage"
      Owner       = "infra-team"
      Project     = "lawyered"
    }
  }
  # ------------------------------------------------------------------
  # challanpay-react
  # ECR Repository for the ChallanPay React SPA application.
  # ------------------------------------------------------------------
  challanpay-react = {
    name                 = "challanpay-react"
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
aurora_clusters = {}

# -------------------------------------------------------------------
# RDS Instance Configurations
rds_instances = {

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
    parameter_group_name        = null
    parameter_group_family      = null
    allow_major_version_upgrade = false
    tags = {
      Environment = "staging"
      Project     = "finvica"
      Role        = "database-rds"
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
    parameter_group_name        = null
    parameter_group_family      = null
    allow_major_version_upgrade = false
    tags = {
      Environment = "staging"
      Project     = "lawyered"
      Role        = "database-rds"
    }
  }
}

github_connection_arn = "arn:aws:codeconnections:ap-south-1:344367180480:connection/57bb41a6-94e5-4be9-9364-73bc9da899d3"

codepipelines = {
  admin-lawyered-fe = {
    repository_id        = "Lawyered-in/admin-lawyered-fe"
    branch_name          = "staging"
    ecr_key              = "admin-lawyered-fe"
    prefetch_images      = ["node:20-alpine"]
    manifest_file_path   = "deployments/stg-admin-lawyered-fe"
    build_image          = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    build_namespace      = "StagingBuildNamespace"
    exported_variables   = ["IMAGE_TAG", "REPOS_URL"]
    enable_security_scan = true
    build_args = {
      VITE_API_URL                       = "https://staging.lawyered.in/api/v3/admin"
      VITE_METABASE_DASHBOARD_ID         = "50"
      VITE_METABASE_SECRET_KEY           = "4a875a120d779fdc5f1a9b740a3b21fa28a0c21694371ad23de0fa4cbb59f502"
      VITE_METABASE_SITE_URL             = "https://analytics.lawyered.in"
      VITE_METABASE_TOKEN_EXPIRY_SECONDS = "600"
      VITE_API_NEW_URL                   = "https://staging-be.lawyered.in/api/v1"
      VITE_RSP_COMMISSION_URL            = "http://staging.lawyered.in/api/admin/partners/rsp-commission"
      VITE_DATADOG_APP_ID                = "f7125ff3-f1c8-48c3-84a7-045797b6d34f"
      VITE_DATADOG_CLIENT_TOKEN          = "pubcf63804121a41fd6d485ba37248f3aab"
      VITE_DATADOG_SITE                  = "us5.datadoghq.com"
      VITE_DATADOG_SERVICE               = "admin-lawyered-fe"
      VITE_DATADOG_ENV                   = "development"
      VITE_DATADOG_VERSION               = "1.0.0"
    }
    custom_build_commands = [
      "echo Build started on `date`",
      "echo Building the Docker image...",
      "docker build --build-arg VITE_API_URL=$${VITE_API_URL} --build-arg VITE_METABASE_DASHBOARD_ID=$${VITE_METABASE_DASHBOARD_ID} --build-arg VITE_METABASE_SECRET_KEY=$${VITE_METABASE_SECRET_KEY} --build-arg VITE_METABASE_SITE_URL=$${VITE_METABASE_SITE_URL} --build-arg VITE_METABASE_TOKEN_EXPIRY_SECONDS=$${VITE_METABASE_TOKEN_EXPIRY_SECONDS} --build-arg VITE_API_NEW_URL=$${VITE_API_NEW_URL} --build-arg VITE_NEW_API_URL=$${VITE_API_NEW_URL} --build-arg VITE_RSP_COMMISSION_URL=$${VITE_RSP_COMMISSION_URL} --build-arg VITE_DATADOG_APP_ID=$${VITE_DATADOG_APP_ID} --build-arg VITE_DATADOG_CLIENT_TOKEN=$${VITE_DATADOG_CLIENT_TOKEN} --build-arg VITE_DATADOG_SITE=$${VITE_DATADOG_SITE} --build-arg VITE_DATADOG_SERVICE=$${VITE_DATADOG_SERVICE} --build-arg VITE_DATADOG_ENV=$${VITE_DATADOG_ENV} --build-arg VITE_DATADOG_VERSION=$${VITE_DATADOG_VERSION} -t $REPOS_URL:latest .",
      "docker tag $REPOS_URL:latest $REPOS_URL:$IMAGE_TAG"
    ]
    custom_post_build_commands = [
      "echo Build completed on `date`",
      "echo Pushing the Docker images...",
      "docker push $REPOS_URL:latest",
      "docker push $REPOS_URL:$IMAGE_TAG",
      "echo Writing image definitions file...",
      "printf '[{\"name\":\"container-name\",\"imageUri\":\"%s\"}]' $REPOS_URL:$IMAGE_TAG > imagedefinitions.json",
      "echo Setting up SSH key for manifest repo push...",
      "mkdir -p ~/.ssh",
      "aws secretsmanager get-secret-value --secret-id $GITHUB_TOKEN_SECRET_NAME --query SecretString --output text > ~/.ssh/id_rsa",
      "chmod 600 ~/.ssh/id_rsa",
      "ssh-keyscan github.com >> ~/.ssh/known_hosts",
      "echo Cloning k8s-manifest repo...",
      "git clone git@github.com:Lawyered-in/k8s-manifest.git /tmp/k8s-manifest",
      "cd /tmp/k8s-manifest && git checkout staging",
      "cd /tmp/k8s-manifest && sed -i \"s|.*$(basename $REPOS_URL):.*|          image: $REPOS_URL:$IMAGE_TAG|g; s|image: >-||g\" deployments/stg-admin-lawyered-fe/deployment.yaml",
      "cd /tmp/k8s-manifest && git config user.email 'ci@lawyered.in' && git config user.name 'CodeBuild CI'",
      "cd /tmp/k8s-manifest && git add deployments/stg-admin-lawyered-fe/deployment.yaml",
      "cd /tmp/k8s-manifest && (git diff --cached --quiet || git commit -m 'New Build id Update for Manifest via CI/CD')",
      "cd /tmp/k8s-manifest && git push origin staging"
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  lots247-in = {
    repository_id        = "Lawyered-in/lots247.com-website"
    branch_name          = "staging"
    ecr_key              = "lots247-in"
    prefetch_images      = ["node:22-alpine"]
    manifest_file_path   = "deployments/stg-lots247-in.yaml"
    build_image          = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    build_namespace      = "StagingBuildNamespace"
    exported_variables   = ["IMAGE_TAG", "REPOS_URL"]
    enable_security_scan = true
    build_args = {
      VITE_REGISTER_BASE_URL      = "https://staging-dashboard.lots247.in/register"
      VITE_QR_REDIRECTS           = "sarathi|https://pages.razorpay.com/pl_TAYfPHbjTTlXax/view?product=SARATHI_QR_REGISTRATION"
      MOENGAGE_API_KEY            = "JzBkatmnc6da7Qbx9FOLHcBU"
      MOENGAGE_BASE_URL           = "https://api-03.moengage.com"
      VITE_MOENGAGE_API_KEY       = "JzBkatmnc6da7Qbx9FOLHcBU"
      VITE_MOENGAGE_BASE_URL      = "https://api-03.moengage.com"
      VITE_MOENGAGE_CLUSTER       = "DC_3"
      VITE_DATADOG_APPLICATION_ID = "47b1cb89-6fb9-49d2-8418-74f278cee79c"
      VITE_DATADOG_CLIENT_TOKEN   = "puba2d4a609a74d1a803adca77ced5dd3d3"
      VITE_DATADOG_SITE           = "us5.datadoghq.com"
      VITE_DATADOG_ENV            = "production"
      VITE_GA4_MEASUREMENT_ID     = "G-DNDWWVFWG9"
      VITE_META_PIXEL_ID          = "1131279109198514"
      VITE_CLARITY_PROJECT_ID     = "unaw091dft"
      VITE_GTM_ID                 = "GTM-PNZZHFT6"
    }
    custom_build_commands = [
      "echo Build started on `date`",
      "echo Building the Docker image with VITE_* build args...",
      "docker build --build-arg VITE_REGISTER_BASE_URL=$${VITE_REGISTER_BASE_URL} --build-arg VITE_QR_REDIRECTS=$${VITE_QR_REDIRECTS} --build-arg MOENGAGE_API_KEY=$${MOENGAGE_API_KEY} --build-arg MOENGAGE_BASE_URL=$${MOENGAGE_BASE_URL} --build-arg VITE_MOENGAGE_API_KEY=$${VITE_MOENGAGE_API_KEY} --build-arg VITE_MOENGAGE_BASE_URL=$${VITE_MOENGAGE_BASE_URL} --build-arg VITE_MOENGAGE_CLUSTER=$${VITE_MOENGAGE_CLUSTER} --build-arg VITE_DATADOG_APPLICATION_ID=$${VITE_DATADOG_APPLICATION_ID} --build-arg VITE_DATADOG_CLIENT_TOKEN=$${VITE_DATADOG_CLIENT_TOKEN} --build-arg VITE_DATADOG_SITE=$${VITE_DATADOG_SITE} --build-arg VITE_DATADOG_ENV=$${VITE_DATADOG_ENV} --build-arg VITE_GA4_MEASUREMENT_ID=$${VITE_GA4_MEASUREMENT_ID} --build-arg VITE_META_PIXEL_ID=$${VITE_META_PIXEL_ID} --build-arg VITE_CLARITY_PROJECT_ID=$${VITE_CLARITY_PROJECT_ID} --build-arg VITE_GTM_ID=$${VITE_GTM_ID} -t $REPOS_URL:latest .",
      "docker tag $REPOS_URL:latest $REPOS_URL:$IMAGE_TAG"
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  admin-lawyered = {
    repository_id        = "Lawyered-in/admin-lawyered"
    branch_name          = "staging"
    ecr_key              = "admin-lawyered"
    prefetch_images      = ["node:20-alpine"]
    manifest_file_path   = "deployments/stg-admin-lawyered"
    build_image          = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    build_namespace      = "StagingBuildNamespace"
    exported_variables   = ["IMAGE_TAG", "REPOS_URL"]
    enable_security_scan = true
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
    custom_post_build_commands = [
      "echo Build completed on `date`",
      "echo Pushing the Docker images...",
      "docker push $REPOS_URL:latest",
      "docker push $REPOS_URL:$IMAGE_TAG",
      "echo Writing image definitions file...",
      "printf '[{\"name\":\"container-name\",\"imageUri\":\"%s\"}]' $REPOS_URL:$IMAGE_TAG > imagedefinitions.json",
      "echo Setting up SSH key for manifest repo push...",
      "mkdir -p ~/.ssh",
      "aws secretsmanager get-secret-value --secret-id $GITHUB_TOKEN_SECRET_NAME --query SecretString --output text > ~/.ssh/id_rsa",
      "chmod 600 ~/.ssh/id_rsa",
      "ssh-keyscan github.com >> ~/.ssh/known_hosts",
      "echo Cloning k8s-manifest repo...",
      "git clone git@github.com:Lawyered-in/k8s-manifest.git /tmp/k8s-manifest",
      "cd /tmp/k8s-manifest && git checkout staging",
      "cd /tmp/k8s-manifest && sed -i \"s|image: .*$(basename $REPOS_URL):.*|image: $REPOS_URL:$IMAGE_TAG|g\" deployments/stg-admin-lawyered/deployment.yaml",
      "cd /tmp/k8s-manifest && sed -i \"s|image: .*$(basename $REPOS_URL):.*|image: $REPOS_URL:$IMAGE_TAG|g\" deployments/stg-admin-lawyered/migration-job.yaml",
      "cd /tmp/k8s-manifest && sed -i \"s|name: admin-lawyered-migrate-.*|name: admin-lawyered-migrate-$IMAGE_TAG|g\" deployments/stg-admin-lawyered/migration-job.yaml",
      "cd /tmp/k8s-manifest && git config user.email 'ci@lawyered.in' && git config user.name 'CodeBuild CI'",
      "cd /tmp/k8s-manifest && git add deployments/stg-admin-lawyered/deployment.yaml deployments/stg-admin-lawyered/migration-job.yaml",
      "cd /tmp/k8s-manifest && (git diff --cached --quiet || git commit -m 'New Build id Update for Manifest via CI/CD')",
      "cd /tmp/k8s-manifest && git push origin staging"
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  lawyered-in-website = {
    repository_id        = "Lawyered-in/lawyered.in-website"
    branch_name          = "staging"
    ecr_key              = "lawyered-in-website"
    prefetch_images      = ["node:20-alpine"]
    manifest_file_path   = "deployments/stg-lawyered-in-website"
    build_image          = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace      = "StagingBuildNamespace"
    exported_variables   = ["IMAGE_TAG", "REPOS_URL"]
    enable_security_scan = true
    build_args = {
      NEXT_PUBLIC_R2_STORAGE_URL  = "https://pub-ac446d6e98cd462ba35be4f49108d1b8.r2.dev/lawyered-website-assets"
      NEXT_PUBLIC_LAWYERED_BE_URL = "https://staging-be.lawyered.in"
    }
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  partners-portal-fe = {
    repository_id        = "Lawyered-in/partners-portal-fe"
    branch_name          = "staging"
    ecr_key              = "partners-portal-fe"
    prefetch_images      = ["node:20-alpine"]
    manifest_file_path   = "deployments/stg-partners-portal-fe"
    build_image          = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace      = "StagingBuildNamespace"
    exported_variables   = ["IMAGE_TAG", "REPOS_URL"]
    enable_security_scan = true
    build_args = {
      VITE_API_BASE_URL           = "https://staging-be.lawyered.in/api/v1"
      VITE_API_STATE_CITY         = "https://lawyered.in"
      VITE_DATADOG_APPLICATION_ID = "be478f15-601d-49eb-9568-3d4529e800b9"
      VITE_DATADOG_CLIENT_TOKEN   = "pub3581edb97eb8bdd70a25888e52aabaf6"
      VITE_DATADOG_SITE           = "us5.datadoghq.com"
      VITE_MOENGAGE_APP_ID        = "QXZHRWGDAYS9LWCRKWXTV52D"
      VITE_OVERVIEW_BASE_URL      = "https://lawyered.in/uploads/location-files"
      VITE_QR_LOGO_URL            = "https://pub-ac446d6e98cd462ba35be4f49108d1b8.r2.dev/qr-logo.svg"
    }
    custom_build_commands = [
      "echo Build started on `date`",
      "echo Building the Docker image with VITE_* build args...",
      "docker build --build-arg VITE_API_BASE_URL=$${VITE_API_BASE_URL} --build-arg VITE_API_STATE_CITY=$${VITE_API_STATE_CITY} --build-arg VITE_DATADOG_APPLICATION_ID=$${VITE_DATADOG_APPLICATION_ID} --build-arg VITE_DATADOG_CLIENT_TOKEN=$${VITE_DATADOG_CLIENT_TOKEN} --build-arg VITE_DATADOG_SITE=$${VITE_DATADOG_SITE} --build-arg VITE_MOENGAGE_APP_ID=$${VITE_MOENGAGE_APP_ID} --build-arg VITE_OVERVIEW_BASE_URL=$${VITE_OVERVIEW_BASE_URL} --build-arg VITE_QR_LOGO_URL=$${VITE_QR_LOGO_URL} -t $REPOS_URL:latest .",
      "docker tag $REPOS_URL:latest $REPOS_URL:$IMAGE_TAG"
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }

  challanpay-fe-next = {
    repository_id        = "Lawyered-in/challanpay-fe-next"
    branch_name          = "staging"
    ecr_key              = "challanpay-fe-next"
    prefetch_images      = ["node:20-alpine"]
    manifest_file_path   = "deployments/stg-challanpay-fe-next"
    build_image          = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    build_namespace      = "StagingBuildNamespace"
    exported_variables   = ["IMAGE_TAG", "REPOS_URL"]
    enable_security_scan = true
    build_args = {
      NEXT_PUBLIC_R2_STORAGE_URL = "https://pub-ac446d6e98cd462ba35be4f49108d1b8.r2.dev/challanpay-website-assets"
    }
    custom_build_commands = [
      "echo Build started on `date`",
      "echo Building the Docker image...",
      "docker build --build-arg NEXT_PUBLIC_R2_STORAGE_URL=$${NEXT_PUBLIC_R2_STORAGE_URL} -t $REPOS_URL:latest .",
      "docker tag $REPOS_URL:latest $REPOS_URL:$IMAGE_TAG"
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  api-challans = {
    repository_id        = "Lawyered-in/api-challans"
    branch_name          = "staging"
    ecr_key              = "api-challans"
    prefetch_images      = ["node:20-alpine"]
    manifest_file_path   = "deployments/stg-api-challans"
    build_image          = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    build_namespace      = "StagingBuildNamespace"
    exported_variables   = ["IMAGE_TAG", "REPOS_URL"]
    enable_security_scan = true
    custom_post_build_commands = [
      "echo Build completed on `date`",
      "echo Pushing the Docker images...",
      "docker push $REPOS_URL:latest",
      "docker push $REPOS_URL:$IMAGE_TAG",
      "echo Writing image definitions file...",
      "printf '[{\"name\":\"container-name\",\"imageUri\":\"%s\"}]' $REPOS_URL:$IMAGE_TAG > imagedefinitions.json",
      "echo Setting up SSH key for manifest repo push...",
      "mkdir -p ~/.ssh",
      "aws secretsmanager get-secret-value --secret-id $GITHUB_TOKEN_SECRET_NAME --query SecretString --output text > ~/.ssh/id_rsa",
      "chmod 600 ~/.ssh/id_rsa",
      "ssh-keyscan github.com >> ~/.ssh/known_hosts",
      "echo Cloning k8s-manifest repo...",
      "git clone git@github.com:Lawyered-in/k8s-manifest.git /tmp/k8s-manifest",
      "cd /tmp/k8s-manifest && git checkout staging",
      "cd /tmp/k8s-manifest && sed -i \"s|image: .*$(basename $REPOS_URL):.*|image: $REPOS_URL:$IMAGE_TAG|g\" deployments/stg-api-challans/deployment.yaml",
      "cd /tmp/k8s-manifest && git config user.email 'ci@lawyered.in' && git config user.name 'CodeBuild CI'",
      "cd /tmp/k8s-manifest && git add deployments/stg-api-challans/deployment.yaml",
      "cd /tmp/k8s-manifest && (git diff --cached --quiet || git commit -m 'New Build id Update for Manifest via CI/CD')",
      "cd /tmp/k8s-manifest && git push origin staging"
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  challan-screening = {
    repository_id        = "Lawyered-in/challan-screening"
    branch_name          = "staging"
    ecr_key              = "challan-screening"
    prefetch_images      = ["python:3.10-slim"]
    manifest_file_path   = "deployments/stg-challan-screening"
    build_image          = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace      = "StagingBuildNamespace"
    exported_variables   = ["IMAGE_TAG", "REPOS_URL"]
    enable_security_scan = true
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
  qr-api = {
    repository_id        = "Lawyered-in/qr-api"
    branch_name          = "staging"
    ecr_key              = "qr-api"
    prefetch_images      = ["node:20-alpine"]
    manifest_file_path   = "deployments/stg-qr-api"
    build_image          = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace      = "StagingBuildNamespace"
    exported_variables   = ["IMAGE_TAG", "REPOS_URL"]
    enable_security_scan = true
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
    repository_id        = "prosper-wealth/prosper-be"
    branch_name          = "staging"
    ecr_key              = "prosper-be"
    prefetch_images      = ["node:22-alpine"]
    manifest_file_path   = "deployments/stg-prosper-be"
    build_image          = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace      = "StagingBuildNamespace"
    exported_variables   = ["IMAGE_TAG", "REPOS_URL"]
    enable_security_scan = true
    connection_arn       = "arn:aws:codeconnections:ap-south-1:344367180480:connection/c262ed12-f5b1-493e-b971-52d70e33bfca"
    custom_post_build_commands = [
      "echo Build completed on `date`",
      "echo Pushing the Docker images...",
      "docker push $REPOS_URL:latest",
      "docker push $REPOS_URL:$IMAGE_TAG",
      "echo Writing image definitions file...",
      "printf '[{\"name\":\"container-name\",\"imageUri\":\"%s\"}]' $REPOS_URL:$IMAGE_TAG > imagedefinitions.json",
      "echo Setting up SSH key for manifest repo push...",
      "mkdir -p ~/.ssh",
      "aws secretsmanager get-secret-value --secret-id $GITHUB_TOKEN_SECRET_NAME --query SecretString --output text > ~/.ssh/id_rsa",
      "chmod 600 ~/.ssh/id_rsa",
      "ssh-keyscan github.com >> ~/.ssh/known_hosts",
      "echo Cloning k8s-manifest repo...",
      "git clone git@github.com:Lawyered-in/k8s-manifest.git /tmp/k8s-manifest",
      "cd /tmp/k8s-manifest && git checkout staging",
      "cd /tmp/k8s-manifest && sed -i \"s|image: .*$(basename $REPOS_URL):.*|image: $REPOS_URL:$IMAGE_TAG|g\" deployments/stg-prosper-be/deployment.yaml",
      "cd /tmp/k8s-manifest && sed -i \"s|image: .*$(basename $REPOS_URL):.*|image: $REPOS_URL:$IMAGE_TAG|g\" deployments/stg-prosper-be/migration-job.yaml",
      "cd /tmp/k8s-manifest && sed -i \"s|name: prosper-be-migrate-.*|name: prosper-be-migrate-$IMAGE_TAG|g\" deployments/stg-prosper-be/migration-job.yaml",
      "cd /tmp/k8s-manifest && git config user.email 'ci@lawyered.in' && git config user.name 'CodeBuild CI'",
      "cd /tmp/k8s-manifest && git add deployments/stg-prosper-be/deployment.yaml deployments/stg-prosper-be/migration-job.yaml",
      "cd /tmp/k8s-manifest && (git diff --cached --quiet || git commit -m 'New Build id Update for Manifest via CI/CD')",
      "cd /tmp/k8s-manifest && git push origin staging"
    ]
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
    repository_id        = "prosper-wealth/prosper-fe"
    branch_name          = "staging"
    ecr_key              = "prosper-fe"
    prefetch_images      = ["node:20-alpine"]
    manifest_file_path   = "deployments/stg-prosper-fe"
    build_image          = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace      = "StagingBuildNamespace"
    exported_variables   = ["IMAGE_TAG", "REPOS_URL"]
    enable_security_scan = true
    connection_arn       = "arn:aws:codeconnections:ap-south-1:344367180480:connection/c262ed12-f5b1-493e-b971-52d70e33bfca"
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
  # faas-be
  # GitHub Org : prosper-wealth
  # Branch     : staging
  # ------------------------------------------------------------------
  faas-be = {
    repository_id        = "prosper-wealth/faas-be"
    branch_name          = "staging"
    ecr_key              = "faas-be"
    prefetch_images      = ["node:22-alpine"]
    manifest_file_path   = "deployments/stg-faas-be"
    build_image          = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace      = "StagingBuildNamespace"
    exported_variables   = ["IMAGE_TAG", "REPOS_URL"]
    enable_security_scan = true
    connection_arn       = "arn:aws:codeconnections:ap-south-1:344367180480:connection/c262ed12-f5b1-493e-b971-52d70e33bfca"
    custom_post_build_commands = [
      "echo Build completed on `date`",
      "echo Pushing the Docker images...",
      "docker push $REPOS_URL:latest",
      "docker push $REPOS_URL:$IMAGE_TAG",
      "echo Writing image definitions file...",
      "printf '[{\"name\":\"container-name\",\"imageUri\":\"%s\"}]' $REPOS_URL:$IMAGE_TAG > imagedefinitions.json",
      "echo Setting up SSH key for manifest repo push...",
      "mkdir -p ~/.ssh",
      "aws secretsmanager get-secret-value --secret-id $GITHUB_TOKEN_SECRET_NAME --query SecretString --output text > ~/.ssh/id_rsa",
      "chmod 600 ~/.ssh/id_rsa",
      "ssh-keyscan github.com >> ~/.ssh/known_hosts",
      "echo Cloning k8s-manifest repo...",
      "git clone git@github.com:Lawyered-in/k8s-manifest.git /tmp/k8s-manifest",
      "cd /tmp/k8s-manifest && git checkout staging",
      "cd /tmp/k8s-manifest && sed -i \"s|image: .*$(basename $REPOS_URL):.*|image: $REPOS_URL:$IMAGE_TAG|g\" deployments/stg-faas-be/deployment.yaml",
      "cd /tmp/k8s-manifest && sed -i \"s|image: .*$(basename $REPOS_URL):.*|image: $REPOS_URL:$IMAGE_TAG|g\" deployments/stg-faas-be/migration-job.yaml",
      "cd /tmp/k8s-manifest && sed -i \"s|name: faas-be-migrate-.*|name: faas-be-migrate-$IMAGE_TAG|g\" deployments/stg-faas-be/migration-job.yaml",
      "cd /tmp/k8s-manifest && git config user.email 'ci@lawyered.in' && git config user.name 'CodeBuild CI'",
      "cd /tmp/k8s-manifest && git add deployments/stg-faas-be/deployment.yaml deployments/stg-faas-be/migration-job.yaml",
      "cd /tmp/k8s-manifest && (git diff --cached --quiet || git commit -m 'New Build id Update for Manifest via CI/CD')",
      "cd /tmp/k8s-manifest && git push origin staging"
    ]
    tags = {
      Environment = "stage"
      Project     = "prosper-wealth"
      Service     = "pipeline"
    }
  }

  # ------------------------------------------------------------------
  # faas-fe
  # GitHub Org : prosper-wealth
  # Branch     : staging
  # ------------------------------------------------------------------
  faas-fe = {
    repository_id        = "prosper-wealth/faas-fe"
    branch_name          = "staging"
    ecr_key              = "faas-fe"
    prefetch_images      = ["node:20-alpine"]
    manifest_file_path   = "deployments/stg-faas-fe"
    build_image          = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace      = "StagingBuildNamespace"
    exported_variables   = ["IMAGE_TAG", "REPOS_URL"]
    enable_security_scan = true
    connection_arn       = "arn:aws:codeconnections:ap-south-1:344367180480:connection/c262ed12-f5b1-493e-b971-52d70e33bfca"
    build_args = {
      NEXT_PUBLIC_API_URL      = "https://prosper-api.staging.prosperwealth.ai/v1"
      NEXT_PUBLIC_ROOT_DOMAIN  = "staging.prosperwealth.ai"
      NEXT_PUBLIC_POSTHOG_KEY  = "phc_M1Yh3LvzlZvBrjfqpE3h7IlV7kWAONqIXzgCUMFp24F"
      NEXT_PUBLIC_POSTHOG_HOST = "https://us.i.posthog.com"
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
    repository_id        = "Lawyered-in/subscriber-fe"
    branch_name          = "staging"
    ecr_key              = "subscriber-fe"
    prefetch_images      = ["node:20-alpine"]
    manifest_file_path   = "deployments/stg-subscriber-fe"
    build_image          = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace      = "StagingBuildNamespace"
    exported_variables   = ["IMAGE_TAG", "REPOS_URL"]
    enable_security_scan = true
    build_args = {
      VITE_API_URL                = "https://staging-be.lawyered.in/api/v1"
      VITE_RAZORPAY_KEY           = "rzp_test_StsoJuLzSQ0KRb"
      VITE_DATADOG_APPLICATION_ID = "9d432da4-f593-4b7e-931a-1b0ee31c855c"
      VITE_DATADOG_CLIENT_TOKEN   = "pubea15557b6c45656c024f32591cb6c6c3"
      VITE_DATADOG_SITE           = "us5.datadoghq.com"
      VITE_DATADOG_SERVICE        = "subscriber-dashboard-lots247"
      VITE_DATADOG_ENV            = "development"
      VITE_AI_URL                 = "https://lava-ai-for-lots247.onrender.com"
      VITE_GTM_ID                 = "GTM-PNZZHFT6"
      VITE_METABASE_SITE_URL      = "https://analytics.lawyered.in"
      VITE_METABASE_DASHBOARD_ID  = "70"
      VITE_METABASE_SECRET_KEY    = "4a875a120d779fdc5f1a9b740a3b21fa28a0c21694371ad23de0fa4cbb59f502"
      VITE_METABASE_TOKEN_EXPIRY_SECONDS = "600"
    }

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
    repository_id        = "Lawyered-in/lawyered-be"
    branch_name          = "staging"
    ecr_key              = "lawyered-be"
    prefetch_images      = ["node:20-alpine"]
    manifest_file_path   = "deployments/stg-lawyered-be"
    build_image          = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace      = "StagingBuildNamespace"
    exported_variables   = ["IMAGE_TAG", "REPOS_URL"]
    enable_security_scan = true
    custom_post_build_commands = [
      "echo Build completed on `date`",
      "echo Pushing the Docker images...",
      "docker push $REPOS_URL:latest",
      "docker push $REPOS_URL:$IMAGE_TAG",
      "echo Writing image definitions file...",
      "printf '[{\"name\":\"container-name\",\"imageUri\":\"%s\"}]' $REPOS_URL:$IMAGE_TAG > imagedefinitions.json",
      "echo Setting up SSH key for manifest repo push...",
      "mkdir -p ~/.ssh",
      "aws secretsmanager get-secret-value --secret-id $GITHUB_TOKEN_SECRET_NAME --query SecretString --output text > ~/.ssh/id_rsa",
      "chmod 600 ~/.ssh/id_rsa",
      "ssh-keyscan github.com >> ~/.ssh/known_hosts",
      "echo Cloning k8s-manifest repo...",
      "git clone git@github.com:Lawyered-in/k8s-manifest.git /tmp/k8s-manifest",
      "cd /tmp/k8s-manifest && git checkout staging",
      "cd /tmp/k8s-manifest && sed -i \"s|image: .*$(basename $REPOS_URL):.*|image: $REPOS_URL:$IMAGE_TAG|g\" deployments/stg-lawyered-be/deployment.yaml",
      "cd /tmp/k8s-manifest && sed -i \"s|image: .*$(basename $REPOS_URL):.*|image: $REPOS_URL:$IMAGE_TAG|g\" deployments/stg-lawyered-be/migration-job.yaml",
      "cd /tmp/k8s-manifest && sed -i \"s|name: lawyered-be-migrate-.*|name: lawyered-be-migrate-$IMAGE_TAG|g\" deployments/stg-lawyered-be/migration-job.yaml",
      "cd /tmp/k8s-manifest && git config user.email 'ci@lawyered.in' && git config user.name 'CodeBuild CI'",
      "cd /tmp/k8s-manifest && git add deployments/stg-lawyered-be/deployment.yaml deployments/stg-lawyered-be/migration-job.yaml",
      "cd /tmp/k8s-manifest && (git diff --cached --quiet || git commit -m 'New Build id Update for Manifest via CI/CD')",
      "cd /tmp/k8s-manifest && git push origin staging"
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }

  # ------------------------------------------------------------------
  # laravel-api Pipeline
  # Manages CI/CD for laravel-api.
  # Source: Lawyered-in/laravel-api (staging branch)
  # Destination: ECR (laravel-api) & k8s-manifests (deployments/stg-laravel-api)
  # ------------------------------------------------------------------
  laravel-api = {
    repository_id        = "Lawyered-in/laravel-api"
    branch_name          = "staging"
    ecr_key              = "laravel-api"
    prefetch_images      = ["node:18-alpine", "php:8.1-cli-alpine"]
    manifest_file_path   = "deployments/stg-laravel-api"
    build_image          = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    build_namespace      = "StagingBuildNamespace"
    exported_variables   = ["IMAGE_TAG", "REPOS_URL"]
    enable_security_scan = true
    custom_post_build_commands = [
      "echo Build completed on `date`",
      "echo Pushing the Docker images...",
      "docker push $REPOS_URL:latest",
      "docker push $REPOS_URL:$IMAGE_TAG",
      "echo Writing image definitions file...",
      "printf '[{\"name\":\"container-name\",\"imageUri\":\"%s\"}]' $REPOS_URL:$IMAGE_TAG > imagedefinitions.json",
      "echo Setting up SSH key for manifest repo push...",
      "mkdir -p ~/.ssh",
      "aws secretsmanager get-secret-value --secret-id $GITHUB_TOKEN_SECRET_NAME --query SecretString --output text > ~/.ssh/id_rsa",
      "chmod 600 ~/.ssh/id_rsa",
      "ssh-keyscan github.com >> ~/.ssh/known_hosts",
      "echo Cloning k8s-manifest repo...",
      "git clone git@github.com:Lawyered-in/k8s-manifest.git /tmp/k8s-manifest",
      "cd /tmp/k8s-manifest && git checkout staging",
      "cd /tmp/k8s-manifest && sed -i \"s|image: .*$(basename $REPOS_URL):.*|image: $REPOS_URL:$IMAGE_TAG|g\" deployments/stg-laravel-api/deployment.yaml",
      "cd /tmp/k8s-manifest && sed -i \"s|image: .*$(basename $REPOS_URL):.*|image: $REPOS_URL:$IMAGE_TAG|g\" deployments/stg-laravel-api/migration-job.yaml",
      "cd /tmp/k8s-manifest && sed -i \"s|name: laravel-api-migrate-.*|name: laravel-api-migrate-$IMAGE_TAG|g\" deployments/stg-laravel-api/migration-job.yaml",
      "cd /tmp/k8s-manifest && git config user.email 'ci@lawyered.in' && git config user.name 'CodeBuild CI'",
      "cd /tmp/k8s-manifest && git add deployments/stg-laravel-api/deployment.yaml deployments/stg-laravel-api/migration-job.yaml",
      "cd /tmp/k8s-manifest && (git diff --cached --quiet || git commit -m 'New Build id Update for Manifest via CI/CD')",
      "cd /tmp/k8s-manifest && git push origin staging"
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }

  # ------------------------------------------------------------------
  # challanpay-react Pipeline
  # Manages CI/CD for challanpay-react (Vite React SPA served by Nginx).
  # Source: Lawyered-in/challanpay-react (staging branch)
  # Destination: ECR (challanpay-react) & k8s-manifests (deployments/stg-challanpay-react)
  # VITE_* vars are baked into the JS bundle at Docker build time.
  # ------------------------------------------------------------------
  challanpay-react = {
    repository_id        = "Lawyered-in/challanpay-react"
    branch_name          = "staging"
    ecr_key              = "challanpay-react"
    prefetch_images      = ["node:22-alpine", "nginx:1.27-alpine"]
    manifest_file_path   = "deployments/stg-challanpay-react"
    build_image          = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    build_namespace      = "StagingBuildNamespace"
    exported_variables   = ["IMAGE_TAG", "REPOS_URL"]
    enable_security_scan = true
    build_args = {
      VITE_API_BASE_URL           = "https://staging-be.lawyered.in/api/v1"
      BACKEND_BASE_URL            = "https://staging-be.lawyered.in/api/v1"
      VITE_RAZORPAY_KEY           = "rzp_test_StsoJuLzSQ0KRb"
      VITE_MOENGAGE_APP_ID        = "QXZHRWGDAYS9LWCRKWXTV52D"
      VITE_MOENGAGE_API_KEY       = "JzBkatmnc6da7Qbx9FOLHcBU"
      VITE_MOENGAGE_BASE_URL      = "https://api-03.moengage.com"
      VITE_MOENGAGE_CLUSTER       = "DC_3"
      VITE_SENTRY_DSN             = "https://8f3c2d7a91b84e6ab5d2f7c9e1a4b6d@o123456.ingest.sentry.io/9876543"
      VITE_DATADOG_APPLICATION_ID = "47b1cb89-6fb9-49d2-8418-74f278cee79c"
      VITE_DATADOG_CLIENT_TOKEN   = "puba2d4a609a74d1a803adca77ced5dd3d3"
      VITE_DATADOG_SITE           = "us5.datadoghq.com"
      VITE_DATADOG_ENV            = "staging"
      VITE_GA4_MEASUREMENT_ID     = "G-2YKF6J30Z1"
      VITE_META_PIXEL_ID          = "1131279109198514"
      VITE_CLARITY_PROJECT_ID     = "unaw091dft"
      LAWYERED_CHALLAN_TOKEN      = "jGyrVfzf2XSFvCA9jNg9sItzctEHjhjqNX3g98JwfYxqIQI7E3plnG9xIcX1QsKLbK2mjTYOeBzN83j9qbZepjWM35Ei4Eu9v6MX"
      RAZORPAY_ORDER_ORIGIN       = "https://staging.lawyered.in"
      VITE_PAYMENT_HISTORY_PATH   = "payment-history"
      VITE_GA4_RSP_MEASUREMENT_ID = "G-D6G4GWDGL9"
    }
    custom_build_commands = [
      "echo Build started on `date`",
      "echo Building the Docker image with VITE_* build args...",
      "docker build --build-arg VITE_API_BASE_URL=$${VITE_API_BASE_URL} --build-arg BACKEND_BASE_URL=$${BACKEND_BASE_URL} --build-arg VITE_RAZORPAY_KEY=$${VITE_RAZORPAY_KEY} --build-arg VITE_MOENGAGE_APP_ID=$${VITE_MOENGAGE_APP_ID} --build-arg VITE_MOENGAGE_API_KEY=$${VITE_MOENGAGE_API_KEY} --build-arg VITE_MOENGAGE_BASE_URL=$${VITE_MOENGAGE_BASE_URL} --build-arg VITE_MOENGAGE_CLUSTER=$${VITE_MOENGAGE_CLUSTER} --build-arg VITE_SENTRY_DSN=$${VITE_SENTRY_DSN} --build-arg VITE_DATADOG_APPLICATION_ID=$${VITE_DATADOG_APPLICATION_ID} --build-arg VITE_DATADOG_CLIENT_TOKEN=$${VITE_DATADOG_CLIENT_TOKEN} --build-arg VITE_DATADOG_SITE=$${VITE_DATADOG_SITE} --build-arg VITE_DATADOG_ENV=$${VITE_DATADOG_ENV} --build-arg VITE_GA4_MEASUREMENT_ID=$${VITE_GA4_MEASUREMENT_ID} --build-arg VITE_META_PIXEL_ID=$${VITE_META_PIXEL_ID} --build-arg VITE_CLARITY_PROJECT_ID=$${VITE_CLARITY_PROJECT_ID} --build-arg LAWYERED_CHALLAN_TOKEN=$${LAWYERED_CHALLAN_TOKEN} --build-arg RAZORPAY_ORDER_ORIGIN=$${RAZORPAY_ORDER_ORIGIN} --build-arg VITE_PAYMENT_HISTORY_PATH=$${VITE_PAYMENT_HISTORY_PATH} --build-arg VITE_GA4_RSP_MEASUREMENT_ID=$${VITE_GA4_RSP_MEASUREMENT_ID} -t $REPOS_URL:latest .",
      "docker tag $REPOS_URL:latest $REPOS_URL:$IMAGE_TAG"
    ]
    tags = {
      Environment = "stage"
      Project     = "lawyered"
      Service     = "pipeline"
    }
  }
}

# -------------------------------------------------------------------
# AWS Bedrock Service Configuration
# -------------------------------------------------------------------
bedrock_model_id        = "minimax.minimax-m2.5"
create_bedrock_iam_user = true

