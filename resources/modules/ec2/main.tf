# -------------------------------------------------------------------
# Security Group for EC2 Instance
# -------------------------------------------------------------------
resource "aws_security_group" "this" {
  name        = "${var.instance_name}-sg1"
  description = "Security group for EC2 instance ${var.instance_name}"
  vpc_id      = var.vpc_id

  # Outbound rule - Allow all traffic to all destinations
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge({ Name = "ec2-sg" }, var.tags)
}

# -------------------------------------------------------------------
# EC2 Instance
# -------------------------------------------------------------------
resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = concat([aws_security_group.this.id], var.security_group_ids)
  associate_public_ip_address = var.associate_public_ip
  iam_instance_profile        = var.iam_instance_profile

  # Capacity reservation specification - set to none for GPU instances
  capacity_reservation_specification {
    capacity_reservation_preference = "none"
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(
    {
      Name = var.instance_name
    },
    var.tags
  )
}
