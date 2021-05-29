
# VPC
resource "aws_vpc" "terra_vpc" {
  cidr_block       = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  tags =  {
    Name = "Terraform_VPC"
  }
}

 resource "aws_subnet" "subnet1" {
   count = "${length(var.subnets_cidr2)}"
   vpc_id     = "${aws_vpc.terra_vpc.id}"
   cidr_block = "${element(var.subnets_cidr2,count.index)}"
   availability_zone = var.availability_zone1[0]


  tags  =  {
    Name = "app-subnet-1"
    }
 }

# Internet Gateway
resource "aws_internet_gateway" "terra_igw" {
  vpc_id = "${aws_vpc.terra_vpc.id}"
  tags =  {
    Name = "main"
  }
}

# Subnets : public
resource "aws_subnet" "public" {
  count = "${length(var.subnets_cidr)}"
  vpc_id = "${aws_vpc.terra_vpc.id}"
  cidr_block = "${element(var.subnets_cidr,count.index)}"
  availability_zone = "${element(var.azs,count.index)}"
  map_public_ip_on_launch = true
  tags =  {
    Name = "Subnet-${count.index+1}"
  }
}

# Route table: attach Internet Gateway 
resource "aws_route_table" "public_rt" {
  vpc_id = "${aws_vpc.terra_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.terra_igw.id}"
  }
  tags =  {
    Name = "publicRouteTable"
  }
}

# Route table association with public subnets
resource "aws_route_table_association" "a" {
  count = "${length(var.subnets_cidr)}"
  subnet_id      = "${element(aws_subnet.public.*.id,count.index)}"
  route_table_id = "${aws_route_table.public_rt.id}"
}
resource "aws_route_table_association" "public-assoc-1" {
  count = "${length(var.subnets_cidr)}"
  subnet_id      = "${aws_subnet.subnet1[count.index].id}"
  route_table_id = "${aws_route_table.public_rt.id}"
}

resource "aws_security_group" "webservers" {
  name        = "allow_http"
  description = "Allow http inbound traffic"
  vpc_id      = "${aws_vpc.terra_vpc.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    description = "ssh from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "base"{
  ami                    = var.ami_version
  instance_type          = var.instance_type
  count                  = var.no-of-instances
  key_name               = var.key_name
  # security_groups        = ["${aws_security_group.webservers.id}"]
  vpc_security_group_ids = ["${aws_security_group.webservers.id}"]
  subnet_id              = aws_subnet.subnet1[count.index].id
  user_data              = "${file("install_httpd.sh")}"
  tags ={
    Name = "sbktest${count.index}"
  }
}