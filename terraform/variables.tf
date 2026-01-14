variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region for resources"
  type        = string
}

variable "lake_name" {
  description = "Dataplex Lake name"
  type        = string
  default     = "dataplex-lake"
}

variable "zone_name" {
  description = "Dataplex Zone name"
  type        = string
  default     = "dataplex-zone"
}

variable "discovery_schedule" {
  description = "Cron schedule for data discovery"
  type        = string
  default     = "0 * * * *"
}

variable "source_dataset" {
  description = "Source BigQuery dataset name"
  type        = string
}

variable "source_table" {
  description = "Source BigQuery table name"
  type        = string
}

variable "results_dataset" {
  description = "Dataset name for storing scan results"
  type        = string
  default     = "dataplex_scans"
}