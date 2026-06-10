variable "instance_name" {
  type        = string
  description = "Name of the EC2 instance"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for the EC2 instance"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID to launch the instance in"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the EC2 security group will be created"
}

variable "key_name" {
  type        = string
  description = "Name of the key pair to use for the instance"
  default     = null
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of security group IDs to attach to the instance"
  default     = []
}

variable "associate_public_ip" {
  type        = bool
  description = "Whether to associate a public IP address"
  default     = false
}

variable "root_volume_size" {
  type        = number
  description = "Root EBS volume size in GB"
  default     = 20
}

variable "root_volume_type" {
  type        = string
  description = "Root EBS volume type"
  default     = "gp3"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the EC2 instance"
  default     = {}
}

variable "iam_instance_profile" {
  type        = string
  description = "Name of the IAM instance profile to attach to the EC2 instance"
  default     = null
}
