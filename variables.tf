variable "region" {
  description = "AWS Region"
  default     = "us-east-1"
}  

variable "instance_type" {
  description = "The type of EC2 Instances to run"
  type        = string
  default     = "t2.micro"
}

variable "ami_version" {
  description = "Version of the AMI to deploy"
  type        = string
  default     = "ami-0b2d4c8a29d3cff80"
}

variable "vpc_cidr" {
	default = "10.20.0.0/16"
}

variable "subnets_cidr" {
	type = "list"
	default = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "azs" {
	type = "list"
	default = ["us-east-1a", "us-east-1b"]
}
