variable "region" {
  default = "ap-south-1"
}

variable "access" {
  default = "Change me"
}

variable "secret" {
  default = "Change me"
}

variable "vpc_cidr" {
  type = map(string)
}

variable "instance_count" {
  type = map(number)
}

variable "subnet_count" {
  type = map(number)
}

variable "instance_size" {
  type = map(string)
}

variable "env_tag" {
  default = "dev"
}

locals {
  env_name = lower(terraform.workspace)

  common_tag = {
    Enviornment = local.env_name
  }
}

data "aws_availability_zones" "azs" {}
