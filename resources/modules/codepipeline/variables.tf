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
