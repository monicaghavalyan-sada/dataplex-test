# Service Account for Dataplex Operations

resource "google_service_account" "dataplex_sa" {
  account_id   = "dataplex-sa"
  display_name = "Dataplex Service Account"
}

resource "google_project_iam_member" "dataplex_sa_bigquery_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.dataplex_sa.email}"
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

# Service Account for GitHub Actions CI/CD

resource "google_service_account" "github_actions_sa" {
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions CI/CD Service Account"
  description  = "Service account for GitHub Actions workflows to update Dataplex quality rules"
}

resource "google_project_iam_member" "github_actions_sa_storage_object_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

resource "google_project_iam_member" "github_actions_sa_dataplex_editor" {
  project = var.project_id
  role    = "roles/dataplex.editor"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}


