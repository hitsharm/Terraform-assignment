provider "aws" {
  region     = var.region
  access_key = var.access
  secret_key = var.secret
}

resource "aws_instance" "web" {
  count = var.instance_count[terraform.workspace]
  ami                    = "ami-03b5297d565ef30a6"
  instance_type          = var.instance_size[terraform.workspace]
  key_name               = "my_aws"
  vpc_security_group_ids = ["${aws_security_group.terraformsecuritygroup.id}"]
  subnet_id              = module.vpc.public_subnets[count.index % var.subnet_count[terraform.workspace]]
  user_data              = file("httpd.sh")

  tags = {
    Name = "${var.env_tag}-subnet${count.index+1}"
  }

}


resource "aws_key_pair" "deployer" {
  key_name   = "my_aws"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCqa7NhG4HhAaLcPzbYd3M0RZfZC8Ih6BmzWBeO2ZRr4yyaFoK+CRlrT82sbt4dH4yUTcfQGS+sOHG+hX+rjB4WBODEIrsq9bDsipVe3ajsqdl30eymnfiL1fY+rfT3VezdAQA845j8fmpNXYuy/LL+1BCF0KPePOZ8zSy28gIF/IV7yEoCKQm0wpHmMBvEvO0wSrQNbREIIfToUTcX/55H2bfaQuc4XBF6fP5CyycjqUJT9Ta5FAGvJV/7FNiHGt6xB53zTB3zJ0MEk0C89/X/jOw9b7g6DxFSBb9WMhlTMDiXezGrCwGDiMGPnu4SXBWPJ7jWQMO4o52bz3QopW0hRhGFQNkPc53HgF4TWqXqqx9VomxyhbjNAhKCkHGxrTqtmJy17pp/rOoZS1fZsJdgtZ0hg3OM9U674YdFB02VElp1tlgFZI0uUaUFfE5YRXk02qY8+H04NUqgpxWy0gGTq3iXv229SHftoIvQniIw+pFdGLAEjjSiJHdZ0WaVT8Kwmo4KV+/4nW1n0SO5kasSKpr5F8dVt/5gDN8pms3plX6da85esU55ZTABbUC1WbzTtou0c+ZNP6MyDBVf+ivtuZMNchu35vZfUUowFZcRoyfpgnR2BN/OtfZSQtE6rwrKsh/5wFBODwHrEgP5pdXKv3veSZzb3q8Ln5DrYKC+tQ== root@jenkins.elk.com"
}

# Networking #

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  name = "${local.env_name}-vpc"
  version = "2.33.0"

  cidr              = var.vpc_cidr[terraform.workspace]
  map_public_ip_on_launch = "true"
  azs       = slice(data.aws_availability_zones.azs.names, 0, var.subnet_count[terraform.workspace])
  public_subnets = data.template_file.public_cidrsubnet[*].rendered
  private_subnets = []
  
  tags = local.common_tag
}

data "template_file" "public_cidrsubnet" {
  count = var.subnet_count[terraform.workspace]

  template = "$${cidrsubnet(vpc_cidr,8,current_count)}"

  vars = {
    vpc_cidr = var.vpc_cidr[terraform.workspace]
    current_count = count.index
  }
}

resource "aws_security_group" "terraformsecuritygroup" {
  vpc_id      = module.vpc.vpc_id
  description = "Allow 80 and 22 port traffic"
  ingress {
    description = "allow 80 port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr[terraform.workspace]]
  }

  ingress {
    description = "Allow 22 port"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 tags = {
    Name = "allow_80 and 22 port"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
 }
}

resource "aws_security_group" "elbsecuritygroup" {
  vpc_id      = module.vpc.vpc_id
  description = "Allow 80 and 22 port traffic"
  ingress {
    description = "allow 80 port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_80 and 22 port"
  }
}

# Create a new load balancer
resource "aws_elb" "my-elb" {
  name               = "terraform-elb"
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.elbsecuritygroup.id]
  instances          = aws_instance.web[*].id

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  tags = {
    Name = "${var.env_tag}-elb"
  }
}

output "aws_instance_public_dns" {
  value = aws_instance.web[*].public_dns
}


output "aws_instance_public_ip" {
  value = aws_instance.web[*].public_ip
}

output "aws_elb_public_dns" {
  value = aws_elb.my-elb.dns_name
