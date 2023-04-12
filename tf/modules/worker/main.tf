#####################################################
# Versions
#####################################################
terraform {
  required_version = ">= 1.1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}


#####################################################
# Data
#####################################################
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

#####################################################
# Vars
#####################################################
variable "app_deployment" {
  type = string
}

variable "container_insights" {
  type    = bool
  default = true
}

variable "env_local" {
  type = bool
  default = false
}

variable "hosted_zone" {
  type = string
  default = null
}

variable "hosted_zone_id" {
  type = string
  default = null
}

variable "lambda_node_arch" {
  description = "Architecture to use for running the lambda"
  default = ["amd64"]
  type = list(string)
}

variable "lambda_node_runtime" {
  description = "Node runtime to use for all lambdas in this project"
  default     = "nodejs18.x"
  type        = string
}

variable "vpc_service_discovery" {
  type = bool
  default = false
}

#####################################################
# Locals
#####################################################
locals {
  ecr_registry_id = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
}

#####################################################
# VPC (shared)
#####################################################
module "vpc" {
  source = "registry.terraform.io/terraform-aws-modules/vpc/aws"

  name = var.app_deployment
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true
}

resource "aws_service_discovery_private_dns_namespace" "local" {
  count = var.vpc_service_discovery ? 1 : 0

  name        = "local"
  description = "VPC-internal service discovery for data-collection VPC"
  vpc         = module.vpc.vpc_id
}
