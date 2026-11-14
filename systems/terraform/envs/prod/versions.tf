terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.87.0"
    }
  }

  backend "s3" {
    bucket       = "infra-tfstate-prod-190837341922"
    key          = "osmond/engineering/terraform.tfstate"
    region       = "eu-west-2"
    profile      = "infra-prod-state"
    encrypt      = true
    use_lockfile = true
  }
}
