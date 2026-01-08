resource "google_dataplex_asset" "sentiment_analysis" {
  name          = "sentiment-analysis-asset"
  location      = var.region
  lake          = google_dataplex_lake.main.name
  dataplex_zone = google_dataplex_zone.curated.name
  description   = "Sentiment analysis dataset asset"
  display_name  = "Sentiment Analysis Dataset"

  resource_spec {
    name = "projects/${var.project_id}/datasets/${var.source_dataset}"
    type = "BIGQUERY_DATASET"
  }

  discovery_spec {
    enabled  = true
    schedule = var.discovery_schedule
  }

  labels = {
    asset-type = "bigquery"
    managed    = "terraform"
  }

  depends_on = [
    google_dataplex_zone.curated
  ]
}
