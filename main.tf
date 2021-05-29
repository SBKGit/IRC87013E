resource "aws_instance" "base"{
  ami                    = var.ami_version
  instance_type          = var.instance_type
  count                  = var.no-of-instances
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.allow_ports.id]
  user_data              = "${file("install_httpd.sh")}"

  tags ={
    Name = "sbktest${count.index}"
  }
}

resource "aws_eip" "myeip"{
  count =length(aws_instance.base)
  vpc = true
  instance = "${element(aws_instance.base.*.id,count.index)}"

  tags = {
    Name ="eip-sbk${count.index + 1}" 
  }
}


## Create VPC ##
resource "aws_vpc" "terraform-vpc" {
  cidr_block       = "172.16.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "terraform-demo-vpc"
  }
}

resource "aws_subnet" "terraform-subnet_1" {
  vpc_id     = "${aws_vpc.terraform-vpc.id}"
  cidr_block = "172.16.10.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "terraform-subnet_1"
  }
}

resource "aws_security_group" "allow_ports" {
  name          = "alb"
  description   = "Allow inbound traffic"
  vpc_id        = "${aws_vpc.terraform-vpc.id}"
  
  ingress {
    description = "http from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks =["0.0.0.0/0"]
  }

  ingress {
    description = "tomcat port from VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    ="tcp"
    cidr_blocks =["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks =["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks =["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ports"
  }
}


resource "aws_lb_target_group" "my-target-group" {
  health_check {
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
  }

  name        = "my-test-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = "${aws_vpc.terraform-vpc.id}"
}

resource "aws_lb" "my-aws-alb" {
  name      = "test-alb"
  internal  = false
  security_groups = [
    "${aws_security_group.allow_ports.id}",
  ]

  subnets = data.aws_subnet_ids.subnet.ids
  tags = {
    Name = "test-alb"
  }

  ip_address_type     = "ipv4"
  load_balancer_type  = "application"
}

resource "aws_lb_listener" "test-alb-listener" {
  load_balancer_arn = aws_lb.my-aws-alb.arn
       port     = 80
       protocol = "HTTP"
       default_action {
         target_group_arn = "${aws_lb_target_group.my-target-group.arn}"
         type             = "forward"
       }  
}

resource "aws_alb_target_group_attachment" "ec2_attach" {
  count = length(aws_instance.base)
  target_group_arn = aws_lb_target_group.my-target-group.arn
  target_id = aws_instance.base[count.index].id
}
  
# Internet Gateway
resource "aws_internet_gateway" "terra_igw" {
  vpc_id = "${aws_vpc.terraform-vpc.id}"
  tags =  {
    Name = "main"
  }
}

# # Subnets : public
resource "aws_subnet" "public" {
  count   = "${length(var.subnets_cidr)}"
  vpc_id  = "${aws_vpc.terraform-vpc.id}"
  cidr_block = "${element(var.subnets_cidr,count.index)}"
  availability_zone = var.azs
  tags =  {
    Name = "Subnet-${count.index+1}"
  }
}

# # Route table: attach Internet Gateway 
resource "aws_route_table" "public_rt" {
  vpc_id = "${aws_vpc.terraform-vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.terra_igw.id}"
  }
  tags =  {
    Name = "publicRouteTable"
  }
}

# # Route table association with public subnets
resource "aws_route_table_association" "a" {
  count = "${length(var.subnets_cidr)}"
  subnet_id      = "${element(aws_subnet.public.*.id,count.index)}"
  route_table_id = "${aws_route_table.public_rt.id}"
}
