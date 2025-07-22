# Example Terraform configuration for testing
# This is a minimal example to demonstrate the direnv integration

# Example local values
locals {
  project_name = "terraform-direnv-test"
  environment  = "development"
}

# Example null resource to test Terraform functionality
resource "null_resource" "example" {
  triggers = {
    project     = local.project_name
    environment = local.environment
    timestamp   = timestamp()
  }

  provisioner "local-exec" {
    command = "echo 'Terraform is working! Project: ${local.project_name}, Env: ${local.environment}'"
  }
}

# Output example
output "project_info" {
  description = "Project information"
  value = {
    name        = local.project_name
    environment = local.environment
    timestamp   = resource.null_resource.example.triggers.timestamp
  }
}