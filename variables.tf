variable "region" {
  description = "AWS Region"
  access_key  = "AKIAY5NLBQSSGZGXF7SA"
  secret_key  = "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"
  region      = "eu-east-1"
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
