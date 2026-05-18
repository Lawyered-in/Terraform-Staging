# -------------------------------------------------------------------
# Security Group for Aurora Cluster
# -------------------------------------------------------------------
resource "aws_security_group" "this" {
  name        = "lawyered-database-sg"
  description = "Security group for Aurora MySQL cluster ${var.cluster_identifier}"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge({ Name = "lawyered-database-sg" }, var.tags)
}

# -------------------------------------------------------------------
# DB Subnet Group
# -------------------------------------------------------------------
resource "aws_db_subnet_group" "this" {
  name        = var.db_subnet_group_name != null ? var.db_subnet_group_name : "${var.cluster_identifier}-subnet-group"
  subnet_ids  = var.subnet_ids
  description = "DB subnet group for ${var.cluster_identifier}"

  tags = merge({ Name = "${var.cluster_identifier}-sub-grp" }, var.tags)
}

# -------------------------------------------------------------------
# Aurora Cluster (Provisioned)
# -------------------------------------------------------------------
resource "aws_rds_cluster" "this" {
  cluster_identifier      = var.cluster_identifier
  engine                  = var.engine
  engine_version          = var.engine_version
  database_name           = var.database_name
  master_username             = var.master_username
  master_password             = var.master_password
  manage_master_user_password = var.master_password == null ? true : null
  backup_retention_period     = var.backup_retention_period
  preferred_backup_window     = var.preferred_backup_window
  db_subnet_group_name        = aws_db_subnet_group.this.name
  vpc_security_group_ids      = [aws_security_group.this.id]
  storage_encrypted               = var.storage_encrypted
  skip_final_snapshot             = var.skip_final_snapshot
  deletion_protection             = var.deletion_protection
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name
  enabled_cloudwatch_logs_exports = ["error", "slowquery"]

  tags = merge({ Name = var.cluster_identifier }, var.tags)
}

# -------------------------------------------------------------------
# Aurora Cluster Instance
# -------------------------------------------------------------------
resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count

  identifier         = "${var.cluster_identifier}-instance-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version
  availability_zone  = var.preferred_az

  # Best practice: enable performance insights
  performance_insights_enabled = true
  db_parameter_group_name      = aws_db_parameter_group.this.name

  tags = merge({ Name = "${var.cluster_identifier}-instance" }, var.tags)
}

# -------------------------------------------------------------------
# DB Parameter Groups
# -------------------------------------------------------------------
resource "aws_rds_cluster_parameter_group" "this" {
  name        = "lawyered-database-cluster-pg"
  family      = "aurora-mysql8.0"
  description = "lawyered-database"

  tags = var.tags
}

resource "aws_db_parameter_group" "this" {
  name        = "lawyered-database-mysql-pg"
  family      = "aurora-mysql8.0"
  description = "lawyered-database"

  tags = var.tags
}
