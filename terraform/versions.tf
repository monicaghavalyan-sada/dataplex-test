terraform {
  required_version = "= 1.13.4"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "= 6.12.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  impersonate_service_account = "terraform-sa@sada-tirayr.iam.gserviceaccount.com"
}
