resource "google_bigquery_dataset" "dataplex_scans" {
  dataset_id  = var.results_dataset
  location    = var.region
  description = "Dataset for storing Dataplex scan results"

  labels = {
    purpose = "data-quality"
    managed = "terraform"
  }

  depends_on = [google_project_service.bigquery]
}
