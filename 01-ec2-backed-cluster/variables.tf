variable "aws_region" {
  type        = string
  default     = "ap-south-1"
  description = "AWS Deployment Region"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block for the custom VPC"
}

variable "public_subnet_a_cidr" {
  type        = string
  default     = "10.0.1.0/24"
  description = "CIDR block for Public Subnet A"
}

variable "public_subnet_b_cidr" {
  type        = string
  default     = "10.0.2.0/24"
  description = "CIDR block for Public Subnet B (Required for ALB Multi-AZ)"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro" # Updated default to t3.micro for modern nitro-based EC2 performance
  description = "EC2 host instance size for the Auto Scaling Group"
}