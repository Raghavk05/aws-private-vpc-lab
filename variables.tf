variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix applied to every resource."
  type        = string
  default     = "private-vpc-lab"
}

variable "environment" {
  description = "Environment tag value (dev, test, prod)."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet that hosts the NAT gateway."
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet that hosts the workload instance."
  type        = string
  default     = "10.0.2.0/24"
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro and t2.micro are free-tier eligible in most regions."
  type        = string
  default     = "t3.micro"
}

variable "enable_nat_gateway" {
  description = <<-EOT
    Create a managed NAT gateway for private subnet egress.
    WARNING: a NAT gateway has no free tier. It bills from the first hour
    (~$0.045/hr plus $0.045/GB processed in us-east-1). Set to false to
    deploy the network without egress and avoid the charge.
  EOT
  type        = bool
  default     = true
}
