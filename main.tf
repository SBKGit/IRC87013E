resource "aws_instance" "base"{
  ami                    = var.ami_version
  instance_type          = var.instance_type
  count                  = var.no-of-instances
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.terraform-sbk-elb.id]
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

## Security Group for ELB
resource "aws_security_group" "elb" {
  name = "terraform-sbk-elb"
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
### Creating ELB
  
resource "aws_elb" "sbk" {
  name = "terraform-asg-sbk"
  security_groups = ["${aws_security_group.elb.id}"]
  subnets = data.aws_subnet_ids.subnet.ids
  #availability_zones = ["${data.aws_availability_zones.all.names}"]
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
  availability_zone = "us-east-1a"
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
