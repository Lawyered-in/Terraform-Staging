# -------------------------------------------------------------------
# VPC
# -------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge({ Name = var.vpc_name }, var.tags)
}

# -------------------------------------------------------------------
# Subnets — Public (for_each over public_subnets map)
# -------------------------------------------------------------------
resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = true

  tags = merge(
    {
      Name = each.key
      Tier = "public"
      "kubernetes.io/role/elb" = "1"
    },
    var.tags
  )
}

# -------------------------------------------------------------------
# Subnets — Private (for_each over private_subnets map)
# -------------------------------------------------------------------
resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = merge(
    {
      Name = each.key
      Tier = "private"
      "kubernetes.io/role/internal-elb" = "1"
    },
    var.tags
  )
}

# -------------------------------------------------------------------
# Internet Gateway
# -------------------------------------------------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge({ Name = "igw" }, var.tags)
}

# -------------------------------------------------------------------
# Elastic IP for NAT Gateway (regional — one per VPC)
# -------------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge({ Name = "nat-eip" }, var.tags)

  depends_on = [aws_internet_gateway.this]
}

# -------------------------------------------------------------------
# NAT Gateway — placed in the first public subnet (regional, one per VPC)
# -------------------------------------------------------------------
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[var.nat_subnet_key].id

  tags = merge({ Name = "nat-gw" }, var.tags)

  depends_on = [aws_internet_gateway.this]
}

# -------------------------------------------------------------------
# Route Table — Public (one shared RT for all public subnets)
# -------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge({ Name = "pub-rt" }, var.tags)
}

# Route Table Associations — Public Subnets
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# -------------------------------------------------------------------
# Route Table — Private (one shared RT for all private subnets)
# -------------------------------------------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = merge({ Name = "pri-rt" }, var.tags)
}

# Route Table Associations — Private Subnets
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# -------------------------------------------------------------------
# Subnets — Database (for_each over database_subnets map)
# -------------------------------------------------------------------
resource "aws_subnet" "database" {
  for_each = var.database_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = merge(
    {
      Name = each.key
      Tier = "database"
    },
    var.tags
  )
}

# -------------------------------------------------------------------
# Route Table — Database (one shared RT for all database subnets, NO EXTERNAL ROUTE)
# -------------------------------------------------------------------
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.this.id

  tags = merge({ Name = "db-rt" }, var.tags)
}

# Route Table Associations — Database Subnets
resource "aws_route_table_association" "database" {
  for_each = aws_subnet.database

  subnet_id      = each.value.id
  route_table_id = aws_route_table.database.id
}