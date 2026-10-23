terraform {

  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  endpoints {
    s3  = "http://localhost:4566"
    iam = "http://localhost:4566"
    ec2 = "http://localhost:4566"
  }
}

module "vpc" {
  source             = "./vpc"
  name_prefix        = var.name_prefix
  create_nat_gateway = var.create_nat_gateway
  tags               = var.tags
}

module "s3" {
  source      = "./s3"
  bucket_name = var.model_artifacts_bucket
  tags        = var.tags
}

module "iam" {
  source                 = "./iam"
  name_prefix            = var.name_prefix
  model_artifacts_bucket = module.s3.bucket_name
  create_iam_role        = var.create_iam_resources
  create_oidc_provider   = var.create_oidc_provider
  oidc_issuer_url        = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED00000000000000000000001"
  tags                   = var.tags
}

variable "name_prefix" {
  description = "Prefix for all resource names."
  type        = string
  default     = "llm"
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default = {
    project = "llm-serving-lab"
    env     = "dev-localstack"
  }
}

variable "model_artifacts_bucket" {
  description = "S3 bucket name for model artifacts."
  type        = string
  default     = "llm-model-artifacts-dev-localstack"
}

variable "create_nat_gateway" {
  description = "Create NAT gateway (LocalStack Community cannot; off for plan)."
  type        = bool
  default     = false
}

variable "create_iam_resources" {
  description = "Create IAM role + OIDC provider."
  type        = bool
  default     = true
}

variable "create_oidc_provider" {
  description = "Create OIDC provider (IRSA trust for K8s SA)."
  type        = bool
  default     = true
}
