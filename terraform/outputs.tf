output "bucket_name" {
  description = "Name of the Dataplex sources bucket"
  value       = google_storage_bucket.dataplex_sources.name
}

output "bucket_url" {
  description = "URL of the Dataplex sources bucket"
  value       = google_storage_bucket.dataplex_sources.url
}

output "dataplex_scans_dataset_id" {
  description = "ID of the dataplex scans dataset"
  value       = google_bigquery_dataset.dataplex_scans.dataset_id
}


output "lake_name" {
  description = "Name of the Dataplex lake"
  value       = google_dataplex_lake.main.name
}

output "lake_id" {
  description = "Full ID of the Dataplex lake"
  value       = google_dataplex_lake.main.id
}

output "zone_name" {
  description = "Name of the Dataplex zone"
  value       = google_dataplex_zone.curated.name
}

output "zone_id" {
  description = "Full ID of the Dataplex zone"
  value       = google_dataplex_zone.curated.id
}

output "asset_name" {
  description = "Name of the Dataplex asset"
  value       = google_dataplex_asset.sentiment_analysis.name
}

output "asset_id" {
  description = "Full ID of the Dataplex asset"
  value       = google_dataplex_asset.sentiment_analysis.id
}

output "service_account_email" {
  description = "Email of the Dataplex service account"
  value       = google_service_account.dataplex_sa.email
}

output "service_account_id" {
  description = "ID of the Dataplex service account"
  value       = google_service_account.dataplex_sa.id
}
