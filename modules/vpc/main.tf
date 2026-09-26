locals {
  az_count = length(var.azs)                          #Calculates the number of Availability Zones specified in your var.azs list by evaluating its length.
  name     = "${var.project_name}-${var.environment}" #creates a standardized naming string prefix by interpolating your project name and environment variables.
}

# VPC

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${local.name}-vpc"
  })
}

# Subnets

resource "aws_subnet" "public" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${local.name}-public-${var.azs[count.index]}"
  })
}

resource "aws_subnet" "private" {
  count             = local.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, {
    Name = "${local.name}-private-${var.azs[count.index]}"
  })
}

# Internet Gateway + Public Routing

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${local.name}-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${local.name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = local.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT Gateways + Private Routing - 1 NAT Gateway per AZ


# 1. Elastic IPs for NAT Gateways

resource "aws_eip" "nat" {
  # Creates 1 EIP per AZ if NAT is enabled, or 0 if disabled
  count  = var.enable_nat_gateway ? local.az_count : 0
  domain = "vpc"

  tags = merge(var.tags, {
    # Dynamically names each EIP with its matching AZ (e.g., nat-eip-ap-southeast-1a)
    Name = "${local.name}-nat-eip-${var.azs[count.index]}"
  })
}


# 2. Multi-AZ NAT Gateways

resource "aws_nat_gateway" "this" {
  # Matches EIP count: 1 NAT Gateway per AZ
  count = var.enable_nat_gateway ? local.az_count : 0

  # Pairs EIP [0] with NAT [0], EIP [1] with NAT [1], etc.
  allocation_id = aws_eip.nat[count.index].id

  # Places NAT Gateway [0] in Public Subnet [0], NAT [1] in Public Subnet [1]
  subnet_id = aws_subnet.public[count.index].id

  # Ensures the Internet Gateway exists before trying to provision NAT Gateways
  depends_on = [aws_internet_gateway.this]

  tags = merge(var.tags, {
    Name = "${local.name}-nat-${var.azs[count.index]}"
  })
}

# 3. Dedicated Private Route Tables (1 per AZ)

resource "aws_route_table" "private" {
  # Creates a separate route table for EACH private subnet/AZ
  count  = local.az_count
  vpc_id = aws_vpc.this.id

  # Conditionally injects an outbound internet route (0.0.0.0/0)
  dynamic "route" {
    # If NAT is true, creates 1 route block [1]. If false, creates 0 route blocks []
    for_each = var.enable_nat_gateway ? [1] : []

    content {
      cidr_block = "0.0.0.0/0"
      # Routes traffic to the NAT Gateway residing in THIS specific AZ
      nat_gateway_id = aws_nat_gateway.this[count.index].id
    }
  }

  tags = merge(var.tags, {
    Name = "${local.name}-private-rt-${var.azs[count.index]}"
  })
}


# 4. Route Table Associations

resource "aws_route_table_association" "private" {
  count = local.az_count
  # Binds Private Subnet [0] to Route Table [0], Subnet [1] to Route Table [1]
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}