resource "google_storage_bucket" "dataplex_sources" {
  name          = "${var.project_id}-dataplex-sources"
  location      = var.region

  force_destroy = true
  uniform_bucket_level_access = true

  labels = {
    purpose = "dataplex-rules"
    managed = "terraform"
  }
}