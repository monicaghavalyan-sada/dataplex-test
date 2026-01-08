resource "google_dataplex_lake" "main" {
  name         = var.lake_name
  location     = var.region
  description  = "Main Dataplex lake for data management"
  display_name = "Main Data Lake"

  labels = {
    purpose = "data-management"
    managed = "terraform"
  }

  depends_on = [google_project_service.dataplex]
}

resource "google_dataplex_zone" "curated" {
  name         = var.zone_name
  location     = var.region
  lake         = google_dataplex_lake.main.name
  type         = "CURATED"
  description  = "Curated zone for processed data"
  display_name = "Curated Data Zone"

  resource_spec {
    location_type = "SINGLE_REGION"
  }

  discovery_spec {
    enabled  = true
    schedule = var.discovery_schedule
  }

  labels = {
    zone-type = "curated"
    managed   = "terraform"
  }
}
