data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  project_name = var.project_name

  public_subnet_cidrs = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  private_subnet_cidrs = [
    "10.0.11.0/24",
    "10.0.12.0/24"
  ]
}

# Main VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${local.project_name}-vpc"
    Project = local.project_name
  }
}

# Internet gateway for public subnets
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${local.project_name}-igw"
    Project = local.project_name
  }
}

# Public subnets for the Application Load Balancer
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${local.project_name}-public-${count.index + 1}"
    Project = local.project_name
    Type    = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${local.project_name}-public-rt"
    Project = local.project_name
  }
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Elastic IP and NAT gateway for private subnet outbound access
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name    = "${local.project_name}-nat-eip"
    Project = local.project_name
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name    = "${local.project_name}-nat"
    Project = local.project_name
  }
}

# Private subnets for ECS tasks
resource "aws_subnet" "private" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.private_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name    = "${local.project_name}-private-${count.index + 1}"
    Project = local.project_name
    Type    = "private"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name    = "${local.project_name}-private-rt"
    Project = local.project_name
  }
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Public-facing load balancer security group
resource "aws_security_group" "alb" {
  name        = "${local.project_name}-alb-sg"
  description = "Allow public HTTP traffic to the load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${local.project_name}-alb-sg"
    Project = local.project_name
  }
}

# Application security group: only the ALB can reach port 8000
resource "aws_security_group" "app" {
  name        = "${local.project_name}-app-sg"
  description = "Allow application traffic only from the load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Flask API traffic from the load balancer"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${local.project_name}-app-sg"
    Project = local.project_name
  }
}