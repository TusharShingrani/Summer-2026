###############################################################################
# Networking: VPC, Internet Gateway, public subnet, route table
#
# This gives the EC2 instance real, routable internet access:
#   instance -> public subnet -> route table (0.0.0.0/0) -> Internet Gateway
# Combined with a public IP (Elastic IP in ec2.tf) the host can both reach the
# internet outbound and be reached inbound on the ports opened in security.tf.
###############################################################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name}-vpc"
  }
}

# Internet Gateway: the door between the VPC and the public internet.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name}-igw"
  }
}

# Public subnet: instances here can be given public IPs and reach the IGW.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = local.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name}-public-subnet"
    Tier = "public"
  }
}

# Route table sending all non-local traffic to the Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
