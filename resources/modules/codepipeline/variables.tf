variable "pipeline_name" {
  type        = string
  description = "Name of the pipeline"
}

variable "github_connection_arn" {
  type        = string
  description = "ARN of the AWS CodeStar connection to GitHub"
}

variable "repository_id" {
  type        = string
  description = "GitHub repository ID (e.g., Organization/repository)"
}

variable "branch_name" {
  type        = string
  description = "Branch name to trigger the pipeline"
  default     = "staging"
}

variable "ecr_repository_url" {
  type        = string
  description = "URL of the ECR repository to push the image to"
}

variable "region" {
  type        = string
  description = "AWS region"
  default     = "ap-south-1"
}

variable "prefetch_images" {
  type        = list(string)
  description = "List of images to pre-fetch from ECR Public to avoid Docker Hub rate limits"
  default     = []
}

variable "build_args" {
  type        = map(string)
  description = "Map of build arguments to pass to the docker build command"
  default     = {}
}

variable "manifest_file_path" {
  type        = string
  description = "Path inside k8s-manifest repo to update (e.g. deployments/stg-lawyered-in-website)"
  default     = ""
}

variable "manifest_branch" {
  description = "The branch of the manifest repository to update"
  type        = string
  default     = "staging"
}

variable "github_token_secret_name" {
  type        = string
  description = "AWS Secrets Manager secret name containing the GitHub PAT for manifest repo push"
  default     = "github-connection-key"
}

variable "tags" {
  type        = map(string)
  description = "Common tags"
  default     = {}
}

variable "build_image" {
  type        = string
  description = "CodeBuild image to use"
  default     = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
}

variable "extra_stages" {
  type = list(object({
    name = string
    action = list(object({
      name             = string
      category         = string
      owner            = string
      provider         = string
      version          = string
      input_artifacts  = optional(list(string), [])
      output_artifacts = optional(list(string), [])
      configuration    = optional(map(string), {})
      role_arn         = optional(string)
      namespace        = optional(string)
    }))
  }))
  description = "List of extra stages to add to the pipeline"
  default     = []
}

variable "build_namespace" {
  type        = string
  description = "Namespace for the build stage"
  default     = null
}

variable "exported_variables" {
  type        = list(string)
  description = "List of variables to export from the build stage"
  default     = []
}

variable "custom_pre_build_commands" {
  type        = list(string)
  description = "Optional list of commands to run in pre_build phase. If provided, replaces defaults."
  default     = null
}

variable "custom_build_commands" {
  type        = list(string)
  description = "Optional list of commands to run in build phase. If provided, replaces defaults."
  default     = null
}

variable "custom_post_build_commands" {
  type        = list(string)
  description = "Optional list of commands to run in post_build phase. If provided, replaces defaults."
  default     = null
}

variable "enable_gated_deploy" {
  type        = bool
  description = "When true (and enable_security_scan is true), the k8s-manifest push is moved out of the Build stage into a separate Deploy stage that only runs after the SecurityScan stage passes. When false (default), Build pushes the manifest directly, same as before -- required for a pipeline whose custom_post_build_commands/manifest_file_path have not yet been migrated to the split layout."
  default     = false
}

variable "custom_deploy_commands" {
  type        = list(string)
  description = "Optional list of commands to run in the Deploy stage (only used when enable_gated_deploy is true). If not provided, defaults to cloning k8s-manifest, patching manifest_file_path/deployment.yaml with the built image, and pushing to manifest_branch."
  default     = null
}

variable "enable_security_scan" {
  type        = bool
  description = "Enable vulnerability and security scanning stage"
  default     = false
}

variable "security_scan_role_arn" {
  type        = string
  description = "IAM role ARN to use for the CodeBuild security scan project"
  default     = null
}

variable "security_reports_bucket_name" {
  type        = string
  description = "Name of the central S3 bucket for storing DevSecOps security reports"
  default     = null
}

variable "build_compute_type" {
  type        = string
  description = "Compute type for the standard build project (e.g. BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM)"
  default     = "BUILD_GENERAL1_SMALL"
}

variable "security_scan_compute_type" {
  type        = string
  description = "Compute type for the security scan project (e.g. BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM)"
  default     = "BUILD_GENERAL1_SMALL"
}

variable "critical_threshold" {
  type        = number
  description = "Max allowed Critical+High severity findings (combined Semgrep+Grype) before the security gate blocks deployment"
  default     = 3
}

variable "medium_threshold" {
  type        = number
  description = "Max allowed Medium severity findings before the security gate blocks deployment"
  default     = 5
}

variable "low_threshold" {
  type        = number
  description = "Max allowed Low severity findings before the security gate blocks deployment"
  default     = 10
}


