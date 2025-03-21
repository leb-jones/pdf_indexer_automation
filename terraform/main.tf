# 🚀 Define Terraform Required Providers
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.0"
    }
    kestra = {
      source  = "kestra-io/kestra"
      version = "~> 0.11.0"
    }
  }
}

# 🚀 Terraform Variables
variable "GOOGLE_CREDENTIALS_BUCKET" {}
variable "GOOGLE_CREDENTIALS_PATH" {}
variable "KESTRA_REPO_PATH" {}
variable "DIR" {}
variable "PYTHON_SCRIPT_PATH" {}

# 🚀 Google Cloud Provider Configuration
provider "google" {
  credentials = file(var.GOOGLE_CREDENTIALS_BUCKET)
  project     = "books-450100"
  region      = "us-central1"
}

# 🚀 Check for Existing Bucket with Prefix "indexing-pdf-storage"
data "google_storage_buckets" "existing_buckets" {
  project = "books-450100"
}

# 🚀 Find an Existing Bucket Matching the Prefix
locals {
  existing_pdf_bucket = length([
    for bucket in data.google_storage_buckets.existing_buckets.buckets :
    bucket.name if startswith(bucket.name, "indexing-pdf-storage")
  ]) > 0 ? [
    for bucket in data.google_storage_buckets.existing_buckets.buckets :
    bucket.name if startswith(bucket.name, "indexing-pdf-storage")
  ][0] : null
}

# 🚀 Only Create a New Bucket If No Existing One Is Found
resource "random_id" "bucket_suffix" {
  count       = local.existing_pdf_bucket == null ? 1 : 0
  byte_length = 4
}

resource "google_storage_bucket" "pdf_bucket" {
  count                          = local.existing_pdf_bucket == null ? 1 : 0
  name                           = "indexing-pdf-storage-${random_id.bucket_suffix[0].hex}"
  location                       = "US"
  storage_class                  = "STANDARD"
  uniform_bucket_level_access    = true
  force_destroy                  = false  # ✅ Prevents Terraform from deleting a bucket with objects
}

# 🚀 Output: Use Either the Existing or Newly Created Bucket
output "pdf_bucket_name" {
  value = local.existing_pdf_bucket != null ? local.existing_pdf_bucket : google_storage_bucket.pdf_bucket[0].name
}

# 🚀 Create BigQuery Dataset (Only If It Doesn't Exist)
resource "google_bigquery_dataset" "indexing_dataset" {
  dataset_id    = "indexing_dataset"
  project       = "books-450100"
  location      = "US"
  description   = "Dataset for storing indexed words, books, and references from PDFs."
}

# 🚀 Create BigQuery Tables (Allow Deletion)
resource "google_bigquery_table" "dim_word" {
  dataset_id          = google_bigquery_dataset.indexing_dataset.dataset_id
  table_id            = "dim_word"
  deletion_protection = false
  schema              = <<EOF
[
  {"name": "WordID", "type": "INT64", "mode": "REQUIRED"},
  {"name": "Word", "type": "STRING", "mode": "REQUIRED"}
]
EOF
}

resource "google_bigquery_table" "dim_book" {
  dataset_id          = google_bigquery_dataset.indexing_dataset.dataset_id
  table_id            = "dim_book"
  deletion_protection = false
  schema              = <<EOF
[
  {"name": "BookID", "type": "INT64", "mode": "REQUIRED"},
  {"name": "FileName", "type": "STRING", "mode": "REQUIRED"},
  {"name": "ISBN10", "type": "STRING", "mode": "NULLABLE"},
  {"name": "ISBN13", "type": "STRING", "mode": "NULLABLE"},
  {"name": "Title", "type": "STRING", "mode": "NULLABLE"},
  {"name": "Author", "type": "STRING", "mode": "NULLABLE"},
  {"name": "Editors", "type": "STRING", "mode": "NULLABLE"},
  {"name": "Publisher", "type": "STRING", "mode": "NULLABLE"},
  {"name": "PlaceOfPublication", "type": "STRING", "mode": "NULLABLE"},
  {"name": "PublicationYear", "type": "STRING", "mode": "NULLABLE"}
]
EOF
}

resource "google_bigquery_table" "index_fact" {
  dataset_id          = google_bigquery_dataset.indexing_dataset.dataset_id
  table_id            = "index_fact"
  deletion_protection = false
  schema              = <<EOF
[
  {"name": "WordID", "type": "INT64", "mode": "REQUIRED"},
  {"name": "BookID", "type": "INT64", "mode": "REQUIRED"},
  {"name": "PageNumber", "type": "INT64", "mode": "REQUIRED"}
]
EOF
}
