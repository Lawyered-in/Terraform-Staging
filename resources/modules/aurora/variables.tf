variable "cluster_identifier" {
  description = "The cluster identifier"
  type        = string
}

variable "engine" {
  description = "The name of the database engine to be used for this DB cluster"
  type        = string
  default     = "aurora-mysql"
}

variable "engine_version" {
  description = "The database engine version"
  type        = string
  default     = "8.0.mysql_aurora.3.12.0"
}

variable "database_name" {
  description = "The name for the database"
  type        = string
}

variable "master_username" {
  description = "Username for the master DB user"
  type        = string
}

variable "master_password" {
  description = "Password for the master DB user (omit to use native AWS Secrets Manager)"
  type        = string
  sensitive   = true
  default     = null
}

variable "instance_class" {
  description = "The instance class to use"
  type        = string
  default     = "db.t4g.large"
}

variable "instance_count" {
  description = "Number of cluster instances"
  type        = number
  default     = 1
}

variable "vpc_id" {
  description = "The VPC ID where Aurora will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "A list of VPC subnet IDs"
  type        = list(string)
}

variable "preferred_az" {
  description = "The preferred Availability Zone for the instance"
  type        = string
  default     = "ap-south-1a"
}

variable "backup_retention_period" {
  description = "The days to retain backups for"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "The daily time range during which automated backups are created"
  type        = string
  default     = "02:00-03:00"
}

variable "storage_encrypted" {
  description = "Specifies whether the DB cluster is encrypted"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Determines whether a final DB snapshot is created before the DB cluster is deleted"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "If the DB instance should have deletion protection enabled"
  type        = bool
  default     = false
}

variable "tags" {
  description = "A mapping of tags to assign to the resource"
  type        = map(string)
  default     = {}
}

variable "db_subnet_group_name" {
  type        = string
  description = "Optional override for DB subnet group name"
  default     = null
}
