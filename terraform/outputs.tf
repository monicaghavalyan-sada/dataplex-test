# Project
output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

# Storage
output "bucket_name" {
  value = google_storage_bucket.dataplex_sources.name
}

# BigQuery
output "dataplex_scans_dataset_id" {
  value = google_bigquery_dataset.dataplex_scans.dataset_id
}

# Dataplex
output "lake_name" {
  value = google_dataplex_lake.main.name
}

output "zone_name" {
  value = google_dataplex_zone.curated.name
}

output "asset_name" {
  value = google_dataplex_asset.sentiment_analysis.name
}

# Service Accounts
output "dataplex_service_account_email" {
  value = google_service_account.dataplex_sa.email
}

output "github_actions_service_account_email" {
  value = google_service_account.github_actions_sa.email
}

# Workload Identity
output "workload_identity_provider_name" {
  value = google_iam_workload_identity_pool_provider.github_provider.name
}

# GitHub Actions config
output "github_actions_config" {
  value = {
    workload_identity_provider = google_iam_workload_identity_pool_provider.github_provider.name
    service_account            = google_service_account.github_actions_sa.email
    bucket_name                = google_storage_bucket.dataplex_sources.name
  }
}
