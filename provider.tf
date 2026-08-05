# Terraform provider info
terraform {
  required_version = ">= 1.14.6"    
    backend "s3" {
      bucket         = "ens-cicd-files"
      key            = var.state_file
      region         = "us-east-1"
      use_lockfile   = true # set to false to debug
      encrypt        = true
    }  
  
    required_providers {
/*      azurerm = {
        source = "hashicorp/azurerm"
        version = ">= 4.62.0"
      }
*/
    }
}
