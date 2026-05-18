# -------------------------------------------------------------------
# S3 Bucket for Pipeline Artifacts
# -------------------------------------------------------------------
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.pipeline_name}-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -------------------------------------------------------------------
# IAM Roles - Pipeline
# -------------------------------------------------------------------
resource "aws_iam_role" "pipeline" {
  name = "${var.pipeline_name}-pipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "pipeline" {
  name = "${var.pipeline_name}-pipeline-policy"
  role = aws_iam_role.pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:GetBucketVersioning", "s3:PutObjectAcl", "s3:PutObject"]
        Effect   = "Allow"
        Resource = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"]
      },
      {
        Action = [
          "codestar-connections:UseConnection",
          "codestar-connections:GetConnection"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = ["iam:PassRole"]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "codebuild.amazonaws.com"
          }
        }
      },
      {
        Action   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# -------------------------------------------------------------------
# IAM Roles - CodeBuild
# ----------------------------------------------------------------  ---
resource "aws_iam_role" "build" {
  name = "${var.pipeline_name}-build-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "build" {
  name = "${var.pipeline_name}-build-policy"
  role = aws_iam_role.build.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:GetBucketVersioning", "s3:PutObject"]
        Effect   = "Allow"
        Resource = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"]
      },
      {
        Action   = ["ecr:GetAuthorizationToken"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:PutImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = ["secretsmanager:GetSecretValue"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# -------------------------------------------------------------------
# CodeBuild Project
# -------------------------------------------------------------------
data "aws_region" "current" {}

resource "aws_codebuild_project" "this" {
  name         = "${var.pipeline_name}-build"
  description  = "Docker build project for ${var.pipeline_name}"
  service_role = aws_iam_role.build.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = var.build_image
    type            = "LINUX_CONTAINER"
    privileged_mode = true # Required for Docker builds

    environment_variable {
      name  = "ECR_REPOSITORY_URL"
      value = var.ecr_repository_url
    }

    environment_variable {
      name  = "GITHUB_TOKEN_SECRET_NAME"
      value = var.github_token_secret_name
    }

    environment_variable {
      name  = "FORCE_UPDATE"
      value = "20260430-V2"
    }

    dynamic "environment_variable" {
      for_each = var.build_args
      content {
        name  = environment_variable.key
        value = environment_variable.value
      }
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = yamlencode(merge(
      {
        version = 0.2
        phases = {
          pre_build = {
            commands = var.custom_pre_build_commands != null ? var.custom_pre_build_commands : [
              "echo Logging in to Amazon ECR...",
              "aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${var.ecr_repository_url}",
              "echo Pre-fetching images from ECR Public to avoid Docker Hub rate limits...",
              "for image in ${join(" ", var.prefetch_images)}; do echo Pulling $${image}...; docker pull public.ecr.aws/docker/library/$${image}; docker tag public.ecr.aws/docker/library/$${image} $${image}; done",
              "REPOS_URL=${var.ecr_repository_url}",
              "COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)",
              "IMAGE_TAG=$${COMMIT_HASH:=latest}"
            ]
          }
          build = {
            commands = var.custom_build_commands != null ? var.custom_build_commands : [
              "echo Build started on `date`",
              "echo Building the Docker image...",
              "docker build ${join(" ", [for k, v in var.build_args : "--build-arg ${k}=$${${k}}"])} -t $REPOS_URL:latest .",
              "docker tag $REPOS_URL:latest $REPOS_URL:$IMAGE_TAG"
            ]
          }
          post_build = {
            commands = var.custom_post_build_commands != null ? var.custom_post_build_commands : [
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
              "cd /tmp/k8s-manifest && git checkout ${var.manifest_branch}",
              "cd /tmp/k8s-manifest && sed -i \"s|image: .*$(basename $REPOS_URL):.*|image: $REPOS_URL:$IMAGE_TAG|g\" ${var.manifest_file_path}/deployment.yaml",
              "cd /tmp/k8s-manifest && git config user.email 'ci@lawyered.in' && git config user.name 'CodeBuild CI'",
              "cd /tmp/k8s-manifest && git add ${var.manifest_file_path}/deployment.yaml",
              "cd /tmp/k8s-manifest && (git diff --cached --quiet || git commit -m '[Devops Team Auto Updated] $(basename $REPOS_URL) image to $IMAGE_TAG [skip ci]')",
              "cd /tmp/k8s-manifest && git push origin ${var.manifest_branch}"
            ]
          }
        }
        artifacts = {
          files = ["imagedefinitions.json"]
        }
      },
      length(var.exported_variables) > 0 ? {
        env = {
          "exported-variables" = var.exported_variables
        }
      } : {}
    ))
  }

  tags = var.tags
}

# -------------------------------------------------------------------
# CodePipeline
# -------------------------------------------------------------------
resource "aws_codepipeline" "this" {
  name     = var.pipeline_name
  role_arn = aws_iam_role.pipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = var.github_connection_arn
        FullRepositoryId = var.repository_id
        BranchName       = var.branch_name
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      namespace        = var.build_namespace

      configuration = {
        ProjectName = aws_codebuild_project.this.name
      }
    }
  }

  dynamic "stage" {
    for_each = var.extra_stages
    content {
      name = stage.value.name
      dynamic "action" {
        for_each = stage.value.action
        content {
          name             = action.value.name
          category         = action.value.category
          owner            = action.value.owner
          provider         = action.value.provider
          version          = action.value.version
          input_artifacts  = action.value.input_artifacts
          output_artifacts = action.value.output_artifacts
          configuration    = action.value.configuration
          role_arn         = action.value.role_arn
          namespace        = action.value.namespace
        }
      }
    }
  }

  tags = var.tags
}

# -------------------------------------------------------------------
# Data Source
# -------------------------------------------------------------------
data "aws_caller_identity" "current" {}
