terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  
  backend "s3" {
    bucket = "dataops-hub-terraform-state"
    key    = "terraform.tfstate"
    region = "eu-central-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "dataops-hub"
      ManagedBy   = "terraform"
    }
  }
} 