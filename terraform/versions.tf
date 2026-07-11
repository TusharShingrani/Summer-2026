terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # ---------------------------------------------------------------------------
  # Remote state backend (recommended for CI/CD).
  #
  # A remote backend lets the pipeline share a single source of truth for the
  # infrastructure state instead of keeping it on the runner (which is
  # ephemeral). Bootstrap the bucket + lock table ONCE (see README section
  # "One-time backend bootstrap"), then uncomment and fill in the block below.
  #
  # backend "s3" {
  #   bucket         = "REPLACE-with-your-tfstate-bucket"
  #   key            = "nameserver-proxy/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "REPLACE-with-your-tf-lock-table"
  #   encrypt        = true
  # }
}
