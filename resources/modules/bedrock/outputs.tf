output "bedrock_access_policy_arn" {
  value       = aws_iam_policy.bedrock_access.arn
  description = "The ARN of the IAM Policy allowing invocation of the MiniMax M2.5 model"
}

output "bedrock_user_arn" {
  value       = try(aws_iam_user.bedrock_user[0].arn, null)
  description = "The ARN of the created Bedrock developer IAM User"
}

output "bedrock_secretsmanager_secret_arn" {
  value       = try(aws_secretsmanager_secret.bedrock_credentials[0].arn, null)
  description = "The ARN of the AWS Secrets Manager Secret containing the Access Key credentials"
}

output "bedrock_secretsmanager_secret_name" {
  value       = try(aws_secretsmanager_secret.bedrock_credentials[0].name, null)
  description = "The friendly name of the AWS Secrets Manager Secret containing the credentials"
}
