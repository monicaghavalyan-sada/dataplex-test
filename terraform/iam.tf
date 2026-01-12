resource "google_service_account" "dataplex_sa" {
  account_id   = "dataplex-sa"
  display_name = "Dataplex Service Account"
  description  = "Service account for Dataplex operations"
  project      = var.project_id
}

resource "google_project_iam_member" "dataplex_sa_dataplex_editor" {
  project = var.project_id
  role    = "roles/dataplex.editor"
  member  = "serviceAccount:${google_service_account.dataplex_sa.email}"
}

resource "google_project_iam_member" "dataplex_sa_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.dataplex_sa.email}"
}

resource "google_project_iam_member" "dataplex_sa_bigquery_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.dataplex_sa.email}"
}

resource "google_service_account" "github_actions_sa" {
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions CI/CD Service Account"
  description  = "Service account for GitHub Actions workflows"
  project      = var.project_id
}

resource "google_storage_bucket_iam_member" "github_actions_storage_admin" {
  bucket = google_storage_bucket.dataplex_sources.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

resource "google_project_iam_member" "github_actions_dataplex_editor" {
  project = var.project_id
  role    = "roles/dataplex.editor"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

resource "google_project_iam_member" "github_actions_bigquery_viewer" {
  project = var.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

resource "google_project_iam_member" "github_actions_bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}