terraform {
  required_version = ">= 1.10.5"

  required_providers {
    # Example providers - uncomment and configure as needed
    # aws = {
    #   source  = "hashicorp/aws"
    #   version = "~> 5.0"
    # }
  }

  # Uncomment and configure your backend
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "test/terraform.tfstate"
  #   region = "us-east-1"
  # }
}