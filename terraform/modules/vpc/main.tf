resource "aws_vpc" "main" {
  # checkov:skip=CKV2_AWS_11:VPC flow logging not enabled for dev environment
  # checkov:skip=CKV2_AWS_12:Default security group is AWS-managed; not modified by this module
  cidr_block                           = var.vpc_cidr
  enable_dns_hostnames                 = true
  enable_dns_support                   = true
  enable_network_address_usage_metrics = false
  tags                                 = merge(var.tags, { Name = "${var.name_prefix}-vpc" })
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}


resource "aws_subnet" "public" {
  # checkov:skip=CKV_AWS_130:Public subnets intentionally assign public IPs for dev ingress
  count             = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-public-${count.index}" })
}

data "aws_availability_zones" "available" {
  # checkov:skip=CKV_AWS_394:Availability zone selection is dev-environment agnostic
  state = "available"
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-private-${count.index}" })
}

resource "aws_route_table" "private" {
  count  = var.create_nat_gateway ? length(var.private_subnet_cidrs) : 0
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-private-${count.index}-rt" })
}

resource "aws_eip" "nat" {
  count  = var.create_nat_gateway ? 1 : 0
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-nat-eip" })
}

resource "aws_nat_gateway" "main" {
  count         = var.create_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  tags          = merge(var.tags, { Name = "${var.name_prefix}-nat" })
}

resource "aws_route" "private_nat" {
  count                  = var.create_nat_gateway ? length(var.private_subnet_cidrs) : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = var.create_nat_gateway ? length(var.private_subnet_cidrs) : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "private_implicit" {
  count          = var.create_nat_gateway ? 0 : length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_vpc.main.default_route_table_id
}

resource "aws_security_group" "eks_control_plane" {
  # checkov:skip=CKV_AWS_382:Egress to 0.0.0.0/0 required for dev outbound internet
  # checkov:skip=CKV2_AWS_5:Security group is referenced by the EKS module at env level
  name        = "${var.name_prefix}-eks-control-plane-sg"
  description = "EKS control plane endpoint"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS to EKS API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound traffic (dev)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound traffic (dev)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-eks-control-plane-sg" })
}

resource "aws_security_group" "vllm" {
  name        = "${var.name_prefix}-vllm-sg"
  # checkov:skip=CKV_AWS_382:Egress to 0.0.0.0/0 required for dev outbound internet
  # checkov:skip=CKV2_AWS_5:Security group is referenced by the vLLM Service at env level
  description = "vLLM serving endpoint"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "vLLM HTTP API"
    from_port   = var.vllm_port
    to_port     = var.vllm_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic (dev)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-eks-control-plane-sg" })
}

