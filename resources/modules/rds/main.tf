# -------------------------------------------------------------------
# Security Group for RDS Instance
# -------------------------------------------------------------------
resource "aws_security_group" "this" {
  name        = "${var.identifier}-SG"
  description = "Security group for RDS instance ${var.identifier}"
  vpc_id      = var.vpc_id

  # Outbound rule - Allow all traffic to all destinations
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge({ Name = "rds-sg" }, var.tags)
}

# -------------------------------------------------------------------
# DB Subnet Group — uses private subnet IDs passed from VPC module
# -------------------------------------------------------------------
resource "aws_db_subnet_group" "this" {
  name        = var.db_subnet_group_name != null ? var.db_subnet_group_name : "${var.identifier}-subnet-group"
  subnet_ids  = var.subnet_ids
  description = "DB subnet group for ${var.identifier}"

  tags = merge({ Name = "db-sub-grp" }, var.tags)
}

# -------------------------------------------------------------------
# RDS Instance
# -------------------------------------------------------------------
resource "aws_db_instance" "this" {
  identifier        = var.identifier
  engine            = var.engine
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage > 0 ? var.max_allocated_storage : null
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted

  db_name  = var.db_name
  username = var.username
  password = var.password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = concat([aws_security_group.this.id], var.vpc_security_group_ids)

  multi_az                = var.multi_az
  publicly_accessible     = var.publicly_accessible
  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final-snapshot"

  apply_immediately           = var.apply_immediately
  allow_major_version_upgrade = var.allow_major_version_upgrade
  parameter_group_name        = var.parameter_group_name

  tags = merge({ Name = var.identifier }, var.tags)
}
