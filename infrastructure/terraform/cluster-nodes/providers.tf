terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.96.0"
    }
  }

  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "homelab-tfstate-164850291083"
    key          = "homelab/cluster-nodes/terraform.tfstate"
    region       = "eu-central-1"
    profile      = "homelab-tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "proxmox" {
  insecure = false
}
