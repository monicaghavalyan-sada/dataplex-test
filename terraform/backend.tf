terraform {
  backend "gcs" {
      bucket = "tf-state-bucket11"
      prefix = "dataplex-quality-scans"
  }
}