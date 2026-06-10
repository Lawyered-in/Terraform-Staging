variable "identifier" {
  type        = string
  description = "Unique identifier / name for the RDS instance"
}

variable "engine" {
  type        = string
  description = "Database engine (e.g. mysql, postgres)"
  default     = "mysql"
}

variable "engine_version" {
  type        = string
  description = "Engine version (e.g. '8.0' for MySQL, '15.4' for PostgreSQL)"
  default     = "8.0"
}

variable "instance_class" {
  type        = string
  description = "RDS instance class (e.g. db.t3.micro)"
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  type        = number
  description = "Storage allocated in GB"
  default     = 20
}

variable "max_allocated_storage" {
  type        = number
  description = "Maximum storage limit for auto-scaling in GB"
  default     = 0
}

variable "storage_type" {
  type        = string
  description = "Storage type (gp2, gp3, io1)"
  default     = "gp3"
}

variable "storage_encrypted" {
  type        = bool
  description = "Enable storage encryption"
  default     = true
}

variable "db_name" {
  type        = string
  description = "Name of the initial database to create"
}

variable "username" {
  type        = string
  description = "Master username for the RDS instance"
}

variable "password" {
  type        = string
  description = "Master password for the RDS instance"
  sensitive   = true
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for the DB subnet group"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the RDS security group will be created"
}

variable "vpc_security_group_ids" {
  type        = list(string)
  description = "List of VPC security group IDs to attach to the RDS instance"
  default     = []
}

variable "multi_az" {
  type        = bool
  description = "Enable Multi-AZ deployment"
  default     = false
}

variable "backup_retention_period" {
  type        = number
  description = "Number of days to retain automated backups (0 disables backups)"
  default     = 7
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection"
  default     = false
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Skip final snapshot on destroy"
  default     = true
}

variable "apply_immediately" {
  type        = bool
  description = "Apply changes immediately (may cause downtime)"
  default     = false
}

variable "parameter_group_name" {
  type        = string
  description = "Name of the DB parameter group to associate"
  default     = null
}

variable "allow_major_version_upgrade" {
  type        = bool
  description = "Allow major version upgrades"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the RDS instance"
  default     = {}
}

variable "publicly_accessible" {
  type        = bool
  description = "Whether the DB should be publicly accessible"
  default     = false
}

variable "db_subnet_group_name" {
  type        = string
  description = "Optional override for DB subnet group name"
  default     = null
}
