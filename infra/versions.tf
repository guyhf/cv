terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Default provider: region where the S3 origin buckets live.
provider "aws" {
  region = var.aws_region
}

# CloudFront requires its ACM certificate to live in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
