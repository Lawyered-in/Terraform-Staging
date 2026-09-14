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
      },
      {
        # Lets the build-stage finally block ask CodeBuild for the exact
        # failure reason of a failed phase, instead of scraping log output.
        Action   = ["codebuild:BatchGetBuilds"]
        Effect   = "Allow"
        Resource = aws_codebuild_project.this.arn
      }
    ]
  })
}

# -------------------------------------------------------------------
# CodeBuild Project
# -------------------------------------------------------------------
data "aws_region" "current" {}

# -------------------------------------------------------------------
# Build-stage Slack notifications
# Runs from post_build's `finally` section, which CodeBuild guarantees
# to execute even when pre_build/build failed and their own commands
# were skipped -- so this fires exactly once per build no matter which
# phase broke. On success it tells devs the pipeline is moving on; on
# failure it asks CodeBuild itself (via BatchGetBuilds) for the failed
# phase's recorded reason instead of scraping raw log output.
# -------------------------------------------------------------------
locals {
  build_status_next_step = var.enable_security_scan ? "Security Scan" : "Deploy"

  build_notify_finally_commands = [
    "BUILD_SLACK_WEBHOOK_URL=$(aws secretsmanager get-secret-value --secret-id devsecops/build-status-slack-webhook --query SecretString --output text || echo \"\")",
    "APP_NAME=$(echo $PIPELINE_NAME | sed 's/-pipeline$//')",
    "if [ -z \"$IMAGE_TAG\" ]; then IMAGE_TAG=pending; fi",
    <<-EOT
    if [ ! -z "$BUILD_SLACK_WEBHOOK_URL" ] && [ "$BUILD_SLACK_WEBHOOK_URL" != "https://hooks.slack.com/services/PLACEHOLDER" ]; then
      if [ "$CODEBUILD_BUILD_SUCCEEDING" = "1" ]; then
        curl -X POST -H 'Content-type: application/json' --data "{
          \"text\": \"✅ *Build Succeeded:* \`$APP_NAME\` (\`$IMAGE_TAG\`)\\nPipeline is now running ${local.build_status_next_step}.\"
        }" "$BUILD_SLACK_WEBHOOK_URL"
      else
        FAILED_PHASE=$(aws codebuild batch-get-builds --ids $CODEBUILD_BUILD_ID --query "builds[0].phases[?phaseStatus=='FAILED'].phaseType | [0]" --output text 2>/dev/null)
        FAILED_REASON=$(aws codebuild batch-get-builds --ids $CODEBUILD_BUILD_ID --query "builds[0].phases[?phaseStatus=='FAILED'].contexts[0].message | [0]" --output text 2>/dev/null)
        if [ -z "$FAILED_PHASE" ] || [ "$FAILED_PHASE" = "None" ]; then FAILED_PHASE=UNKNOWN; fi
        if [ -z "$FAILED_REASON" ] || [ "$FAILED_REASON" = "None" ]; then FAILED_REASON="No failure detail reported by CodeBuild."; fi
        BUILD_ID_ENCODED=$(echo "$CODEBUILD_BUILD_ID" | sed 's/:/%3A/g')
        LOG_URL="https://${data.aws_region.current.id}.console.aws.amazon.com/codesuite/codebuild/projects/$PIPELINE_NAME-build/build/$BUILD_ID_ENCODED/log?region=${data.aws_region.current.id}"
        SLACK_TEXT="❌ *Build Failed:* \`$APP_NAME\` (\`$IMAGE_TAG\`)\nFailed at *$FAILED_PHASE* phase.\n*Reason:* $FAILED_REASON\n🔗 <$LOG_URL|View Build Logs>"
        jq -n --arg text "$SLACK_TEXT" '{text:$text}' | curl -X POST -H 'Content-type: application/json' --data @- "$BUILD_SLACK_WEBHOOK_URL"
      fi
    else
      echo "Build Status Slack Webhook URL is empty or placeholder, skipping notification."
    fi
    EOT
  ]
}

resource "aws_codebuild_project" "this" {
  name         = "${var.pipeline_name}-build"
  description  = "Docker build project for ${var.pipeline_name}"
  service_role = aws_iam_role.build.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = var.build_compute_type
    image           = var.build_image
    type            = "LINUX_CONTAINER"
    privileged_mode = true # Required for Docker builds

    environment_variable {
      name  = "PIPELINE_NAME"
      value = var.pipeline_name
    }

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
              "aws ecr get-login-password --region ${data.aws_region.current.id} | docker login --username AWS --password-stdin ${var.ecr_repository_url}",
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
            commands = var.custom_post_build_commands != null ? var.custom_post_build_commands : (
              var.enable_gated_deploy ? [
                "echo Build completed on `date`",
                "echo Pushing the Docker images...",
                "docker push $REPOS_URL:latest",
                "docker push $REPOS_URL:$IMAGE_TAG",
                "echo Writing image definitions file...",
                "printf '[{\"name\":\"container-name\",\"imageUri\":\"%s\"}]' $REPOS_URL:$IMAGE_TAG > imagedefinitions.json"
                ] : [
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
                "cd /tmp/k8s-manifest && (git diff --cached --quiet || git commit -m 'New Build id Update for Manifest via CI/CD')",
                "cd /tmp/k8s-manifest && git push origin ${var.manifest_branch}"
              ]
            )
            finally = local.build_notify_finally_commands
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
# CodeBuild Security Scan Project
# -------------------------------------------------------------------
resource "aws_codebuild_project" "security_scan" {
  count        = var.enable_security_scan ? 1 : 0
  name         = "${var.pipeline_name}-security-scan"
  description  = "Security scan (Semgrep, Syft, Grype) for ${var.pipeline_name}"
  service_role = var.security_scan_role_arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = var.security_scan_compute_type
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "PIPELINE_NAME"
      value = var.pipeline_name
    }

    environment_variable {
      name  = "ARTIFACT_BUCKET"
      value = aws_s3_bucket.artifacts.bucket
    }

    environment_variable {
      name  = "SECURITY_REPORTS_BUCKET"
      value = var.security_reports_bucket_name
    }

    environment_variable {
      name  = "GITHUB_TOKEN_SECRET_NAME"
      value = var.github_token_secret_name
    }

    environment_variable {
      name  = "REPOSITORY_ID"
      value = var.repository_id
    }

    environment_variable {
      name  = "BRANCH_NAME"
      value = var.branch_name
    }

    environment_variable {
      name  = "CRITICAL_THRESHOLD"
      value = tostring(var.critical_threshold)
    }

    environment_variable {
      name  = "MEDIUM_THRESHOLD"
      value = tostring(var.medium_threshold)
    }

    environment_variable {
      name  = "LOW_THRESHOLD"
      value = tostring(var.low_threshold)
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/buildspec_security_tests.yaml")
  }

  tags = var.tags
}

# -------------------------------------------------------------------
# CodeBuild Deploy Project
# Pushes the k8s-manifest update (which ArgoCD auto-syncs) *after* the
# SecurityScan stage has passed, instead of from inside the Build stage.
# Only created when enable_gated_deploy is true.
# -------------------------------------------------------------------
locals {
  deploy_app_name = trimsuffix(var.pipeline_name, "-pipeline")

  # Built with jsonencode so Terraform (not hand-written escapes) handles all
  # JSON/backtick escaping correctly; __IMAGE_TAG__ is swapped in at runtime
  # via bash parameter expansion since the tag isn't known until the build runs.
  deploy_success_payload_template = jsonencode({
    text = "✅ *Deployment Successful:* `${local.deploy_app_name}` (`__IMAGE_TAG__`)\nPassed the security gate and is deploying. Changes should be live within ~2 minutes."
  })

  deploy_notify_commands = [
    "echo Fetching Deployment Status Slack Webhook URL from Secrets Manager...",
    "DEPLOY_SLACK_WEBHOOK_URL=$(aws secretsmanager get-secret-value --secret-id devsecops/deployment-status-slack-webhook --query SecretString --output text || echo \"\")",
    "if [ ! -z \"$DEPLOY_SLACK_WEBHOOK_URL\" ] && [ \"$DEPLOY_SLACK_WEBHOOK_URL\" != \"https://hooks.slack.com/services/PLACEHOLDER\" ]; then echo Sending deployment-succeeded alert to Slack...; PAYLOAD='${local.deploy_success_payload_template}'; PAYLOAD=$${PAYLOAD/__IMAGE_TAG__/$IMAGE_TAG}; curl -X POST -H 'Content-type: application/json' --data \"$PAYLOAD\" \"$DEPLOY_SLACK_WEBHOOK_URL\"; else echo \"Deployment Status Slack Webhook URL is empty or placeholder, skipping notification.\"; fi"
  ]
}

resource "aws_codebuild_project" "deploy" {
  count        = var.enable_gated_deploy && var.enable_security_scan ? 1 : 0
  name         = "${var.pipeline_name}-deploy"
  description  = "Updates k8s-manifest to trigger ArgoCD deployment for ${var.pipeline_name}"
  service_role = aws_iam_role.build.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = var.build_compute_type
    image           = var.build_image
    type            = "LINUX_CONTAINER"
    privileged_mode = false

    environment_variable {
      name  = "GITHUB_TOKEN_SECRET_NAME"
      value = var.github_token_secret_name
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = yamlencode({
      version = 0.2
      phases = {
        post_build = {
          commands = concat(
            var.custom_deploy_commands != null ? var.custom_deploy_commands : [
              "echo Deploying $REPOS_URL:$IMAGE_TAG for ${var.pipeline_name}...",
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
              "cd /tmp/k8s-manifest && (git diff --cached --quiet || git commit -m 'New Build id Update for Manifest via CI/CD')",
              "cd /tmp/k8s-manifest && git push origin ${var.manifest_branch}"
            ],
            local.deploy_notify_commands
          )
        }
      }
    })
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
        ConnectionArn        = var.github_connection_arn
        FullRepositoryId     = var.repository_id
        BranchName           = var.branch_name
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
    for_each = var.enable_security_scan ? [1] : []
    content {
      name = "SecurityScan"
      action {
        name             = "SecurityScan"
        category         = "Build"
        owner            = "AWS"
        provider         = "CodeBuild"
        version          = "1"
        input_artifacts  = ["source_output"]
        output_artifacts = ["security_scan_output"]

        configuration = {
          ProjectName   = aws_codebuild_project.security_scan[0].name
          PrimarySource = "source_output"
          EnvironmentVariables = jsonencode([
            {
              name  = "IMAGE_TAG"
              value = format("#{%s.IMAGE_TAG}", coalesce(var.build_namespace, "BuildVariables"))
              type  = "PLAINTEXT"
            },
            {
              name  = "REPOS_URL"
              value = format("#{%s.REPOS_URL}", coalesce(var.build_namespace, "BuildVariables"))
              type  = "PLAINTEXT"
            }
          ])
        }
      }
    }
  }

  dynamic "stage" {
    for_each = var.enable_gated_deploy && var.enable_security_scan ? [1] : []
    content {
      name = "Deploy"
      action {
        name             = "Deploy"
        category         = "Build"
        owner            = "AWS"
        provider         = "CodeBuild"
        version          = "1"
        input_artifacts  = ["source_output"]
        output_artifacts = ["deploy_output"]

        configuration = {
          ProjectName   = aws_codebuild_project.deploy[0].name
          PrimarySource = "source_output"
          EnvironmentVariables = jsonencode([
            {
              name  = "IMAGE_TAG"
              value = format("#{%s.IMAGE_TAG}", coalesce(var.build_namespace, "BuildVariables"))
              type  = "PLAINTEXT"
            },
            {
              name  = "REPOS_URL"
              value = format("#{%s.REPOS_URL}", coalesce(var.build_namespace, "BuildVariables"))
              type  = "PLAINTEXT"
            }
          ])
        }
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
