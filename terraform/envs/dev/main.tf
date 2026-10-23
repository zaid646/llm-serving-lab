terraform {
  backend "s3" {
    bucket                      = "llm-tf-state-dev"
    key                         = "llm-serving-lab/dev/terraform.tfstate"
    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_region_validation      = true
    dynamodb_table              = "tf-locks"
    encrypt                     = false
  }

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
  endpoints {
    s3  = "http://localhost:4566"
    iam = "http://localhost:4566"
    ec2 = "http://localhost:4566"
    eks = "http://localhost:4566"
    rds = "http://localhost:4566"
  }
}

module "vpc" {
  source             = "../../modules/vpc"
  name_prefix        = var.name_prefix
  create_nat_gateway = var.create_nat_gateway
  tags               = var.tags
}

module "s3" {
  source      = "../../modules/s3"
  bucket_name = var.model_artifacts_bucket
  tags        = var.tags
}

module "iam" {
  source                 = "../../modules/iam"
  name_prefix            = var.name_prefix
  model_artifacts_bucket = module.s3.bucket_name
  create_iam_role        = var.create_iam_resources
  create_oidc_provider   = var.create_oidc_provider
  oidc_issuer_url        = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED00000000000000000000001"
  tags                   = var.tags
}

module "eks" {
  source                    = "../../modules/eks"
  name_prefix               = var.name_prefix
  create_cluster            = var.create_eks_cluster
  cluster_version           = var.eks_cluster_version
  subnet_ids                = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  cluster_security_group_id = module.vpc.eks_control_plane_security_group_id
  tags                      = var.tags
}

module "rds" {
  source          = "../../modules/rds"
  name_prefix     = var.name_prefix
  create_instance = var.create_rds_instance
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  vpc_cidr        = module.vpc.vpc_cidr
  # checkov:skip=CKV_SECRET_6:DB password is a placeholder value for dev environment
  db_password = "changeme-in-tfvars"
  tags        = var.tags
}
