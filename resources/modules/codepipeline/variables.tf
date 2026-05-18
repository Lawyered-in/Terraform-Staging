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
