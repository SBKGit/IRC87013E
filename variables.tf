variable "aws_region" {
  description = "AWS Region"
  default     = "us-east-1
}  

variable "key_name" {
  description = "Key name for SSHing into EC2"
  default = "sbktest"
}

variable "vpc_cidr" {
	default = "10.20.0.0/16"
}

variable "subnets_cidr" {
	type = "list"
	default = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "subnets_cidr2" {
	type = "list"
	default = ["10.20.3.0/24", "10.20.4.0/24"]
}

variable "azs" {
	type = "list"
	default = ["us-east-1a", "us-east-1b"]
}

variable "instance_type" {
  default = "t2.micro"
}

variable "no-of-instances" {
  default = "2"
}

variable "ami_version" {
  description = "Version of the AMI to deploy"
  type        = string
  default     = "ami-0b2d4c8a29d3cff80"
}

variable "availability_zone1" {
  default = ["us-east-1a", "us-east-1b"]
}

variable "min_size" {
  default = "1"
}

variable "max_size" {
  default = "3"
}
