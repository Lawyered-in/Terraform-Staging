variable "vpc_name" {
  type        = string
  description = "Name of the VPC"
}

variable "cidr_block" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "public_subnets" {
  description = "Map of public subnet configurations"
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
}

variable "private_subnets" {
  description = "Map of private subnet configurations"
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
}

variable "database_subnets" {
  description = "Map of database subnet configurations"
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
  default = {}
}

variable "nat_subnet_key" {
  type        = string
  description = "Key of the public subnet in which to place the NAT Gateway (e.g. 'pub-1')"
}

variable "tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}