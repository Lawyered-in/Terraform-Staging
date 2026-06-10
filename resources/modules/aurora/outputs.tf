output "cluster_endpoint" {
  description = "The cluster endpoint"
  value       = aws_rds_cluster.this.endpoint
}

output "cluster_reader_endpoint" {
  description = "The cluster reader endpoint"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "cluster_identifier" {
  description = "The cluster identifier"
  value       = aws_rds_cluster.this.cluster_identifier
}

output "security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.this.id
}

output "master_user_secret_arn" {
  description = "The ARN of the AWS Secrets Manager secret containing the generated master user password"
  value       = try(aws_rds_cluster.this.master_user_secret[0].secret_arn, null)
}
