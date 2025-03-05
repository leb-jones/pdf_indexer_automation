provider "google" {
  credentials = file("/home/lebjones/PDFIndexer/keys/bucket.json")
  project     = "your-gcp-project-id"
  region      = "us-central1"
}

#Create a Google Cloud Storage (GCS) Bucket for PDFs
resource "google_storage_bucket" "pdf_bucket" {
  name          = "indexing-pdf-storage"
  location      = "US"
  storage_class = "STANDARD"

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 30  # Delete PDFs after 30 days (optional)
    }
    action {
      type = "Delete"
    }
  }
}

# 🔹 2️⃣ Create a Google Cloud Dataproc Cluster
resource "google_dataproc_cluster" "pdf_indexing_cluster" {
  name   = "pdf-indexing-cluster"
  region = "us-central1"

  cluster_config {
    master_config {
      num_instances = 1
      machine_type  = "n1-standard-4"
      disk_config {
        boot_disk_size_gb = 50
      }
    }

    worker_config {
      num_instances = 2
      machine_type  = "n1-standard-2"
      disk_config {
        boot_disk_size_gb = 50
      }
    }

    software_config {
      image_version = "2.0-debian10"
      optional_components = ["JUPYTER", "ANACONDA"]
      properties = {
        "dataproc:dataproc.logging.stackdriver.enable" = "true"
        "dataproc:dataproc.monitoring.stackdriver.enable" = "true"
      }
    }

    gce_cluster_config {
      service_account = "your-service-account@your-gcp-project-id.iam.gserviceaccount.com"
      service_account_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }
  }
}

#Upload the Indexer Script to GCS (so Dataproc can access it)
resource "google_storage_bucket_object" "indexer_script" {
  name   = "scripts/indexer.py"
  bucket = google_storage_bucket.pdf_bucket.name
  source = "/home/lebjones/PDFIndexer/python/indexer.py"
}

#onfigure Terraform Provider for BigQuery (Uses BigQuery Key)
provider "google" {
  credentials = file("/home/lebjones/PDFIndexer/keys/bigquery.json")
  project     = "your-gcp-project-id"
  region      = "US"
  alias       = "bigquery"
}

#Create a Google BigQuery Dataset (if not exists)
resource "google_bigquery_dataset" "indexing_dataset" {
  dataset_id = "indexing_dataset"
  project    = "your-gcp-project-id"
  location   = "US"
  description = "Dataset for storing indexed words, books, and references from PDFs."
}

#Create BigQuery Tables
resource "google_bigquery_table" "dim_word" {
  dataset_id = google_bigquery_dataset.indexing_dataset.dataset_id
  table_id   = "dim_word"
  schema     = <<EOF
[
  {"name": "WordID", "type": "INT64", "mode": "REQUIRED"},
  {"name": "Word", "type": "STRING", "mode": "REQUIRED"}
]
EOF
}

resource "google_bigquery_table" "dim_book" {
  dataset_id = google_bigquery_dataset.indexing_dataset.dataset_id
  table_id   = "dim_book"
  schema     = <<EOF
[
  {"name": "BookID", "type": "INT64", "mode": "REQUIRED"},
  {"name": "Book", "type": "STRING", "mode": "REQUIRED"}
]
EOF
}

resource "google_bigquery_table" "index_fact" {
  dataset_id = google_bigquery_dataset.indexing_dataset.dataset_id
  table_id   = "index_fact"
  schema     = <<EOF
[
  {"name": "WordID", "type": "INT64", "mode": "REQUIRED"},
  {"name": "BookID", "type": "INT64", "mode": "REQUIRED"},
  {"name": "PageNumber", "type": "INT64", "mode": "REQUIRED"}
]
EOF
}

output "gcs_bucket_name" {
  value = google_storage_bucket.pdf_bucket.name
}

output "dataproc_cluster_name" {
  value = google_dataproc_cluster.pdf_indexing_cluster.name
}
