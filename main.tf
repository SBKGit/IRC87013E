
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

#target group
resource "aws_lb_target_group" "my-target-group" {
  health_check {
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  name        = "my-test-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = "${aws_vpc.terra_vpc.id}"
}

resource "aws_elb" "my-aws-elb" {
  name     = "sbk-test-elb"
  internal = false
  security_groups = [
    "${aws_security_group.webservers.id}",
  ]

  subnets =  [
    for num in aws_subnet.public:
    num.id
  ]
  tags = {
    Name = "sbk-test-alb"
  }

  # ip_address_type    = "ipv4"
  # load_balancer_type = "application"
  health_check {
    healthy_threshold = 10
    unhealthy_threshold = 10
    timeout = 3
    interval = 30
    target = "HTTP:80/"
  }
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }
}

# resource "aws_lb_listener" "sbk-test-alb-listner" {
  
#  load_balancer_arn = aws_lb.my-aws-alb.arn
#       port                = 80
#       protocol            = "HTTP"
#       default_action {
#         target_group_arn = "${aws_lb_target_group.my-target-group.arn}"
#         type             = "forward"
#       }
# }

# resource "aws_alb_target_group_attachment" "ec2_attach" {
#   count = length(aws_instance.base)
#   target_group_arn = aws_lb_target_group.my-target-group.arn
#   target_id = aws_instance.base[count.index].id
# }

 resource "aws_default_subnet" "defaultsub" {
  availability_zone = "us-east-1b"

  tags = {
    Name = "Default subnet"
  }
}


## Creating Launch Configuration
resource "aws_launch_configuration" "example" {
  image_id               = var.ami_version
  instance_type          = var.instance_type
  security_groups        = ["${aws_security_group.webservers.id}"]
  key_name               = var.key_name
  user_data              = "${file("install_httpd.sh")}"
}

## Creating AutoScaling Group
resource "aws_autoscaling_group" "example" {
  launch_configuration = "${aws_launch_configuration.example.id}"
  availability_zones = var.availability_zone1
  min_size = 1
  max_size = 3
  load_balancers = ["${aws_elb.my-aws-elb.name}"]
  health_check_type = "EC2"
  tag {
    key = "Name"
    value = "terraform-asg-example"
    propagate_at_launch = true
  }
}
