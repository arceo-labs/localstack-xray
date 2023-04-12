terraform {
  required_version = ">= 1.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.52.00"
    }
  }
}

locals {
  app             = "worker"
  environment     = "local"
}

provider "aws" {
  access_key = "test"
  secret_key = "test"
  region     = "us-east-1"
  profile    = "localstack"

  # only required for non virtual hosted-style endpoint use case.
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs#s3_use_path_style
  s3_use_path_style           = false
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  default_tags {
    tags = {
      Environment = local.environment
      App         = local.app
      terraform   = "true"
    }
  }

  endpoints {
    acm              = "http://localhost:4566"
    apigateway       = "http://localhost:4566"
    apigatewayv2     = "http://localhost:4566"
    cloudformation   = "http://localhost:4566"
    cloudwatch       = "http://localhost:4566"
    docdb            = "http://localhost:4566"
    dynamodb         = "http://localhost:4566"
    ec2              = "http://localhost:4566"
    es               = "http://localhost:4566"
    elasticache      = "http://localhost:4566"
    events           = "http://localhost:4566"
    firehose         = "http://localhost:4566"
    iam              = "http://localhost:4566"
    kinesis          = "http://localhost:4566"
    lambda           = "http://localhost:4566"
    logs             = "http://localhost:4566"
    rds              = "http://localhost:4566"
    redshift         = "http://localhost:4566"
    route53          = "http://localhost:4566"
    s3               = "http://s3.localhost.localstack.cloud:4566"
    secretsmanager   = "http://localhost:4566"
    servicediscovery = "http://localhost:4566"
    ses              = "http://localhost:4566"
    sns              = "http://localhost:4566"
    sqs              = "http://localhost:4566"
    ssm              = "http://localhost:4566"
    stepfunctions    = "http://localhost:4566"
    sts              = "http://localhost:4566"
  }
}

# ------------- Pre-existing resources -----------------
# For the local stack, we provision a few things outside the module
# to simulate resources that the module assumes are created outside the
# scope of this project/deployment.
#
resource "aws_route53_zone" "primary" {
  name = "localhost.localstack.cloud:4566"
}

# ------------- Module: rdc -----------------
# Deploy rdc the same way we do in AWS
#
module "rdc" {
  source = "../modules/worker"

  app_deployment     = "${local.app}-${local.environment}"
  hosted_zone_id     = aws_route53_zone.primary.zone_id
  lambda_node_arch   = ["arm64"]

  # Running in Localstack
  env_local = true
}
