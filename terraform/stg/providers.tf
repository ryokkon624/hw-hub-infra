terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "hwhub-terraform-state-apne1"
    key            = "stg/ephemeral/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "hwhub-terraform-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-northeast-1"
}