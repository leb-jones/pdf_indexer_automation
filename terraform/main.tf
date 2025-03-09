variable "google_credentials_bucket" {}
variable "google_credentials_dataproc" {}
variable "google_credentials_bigquery" {}

provider "google" {
  credentials = file(var.google_credentials_bucket)
  project     = "books-450100"
  region      = "us-central1"
}

# 🔹 Create Google Cloud Storage (GCS) Bucket for PDFs
resource "google_storage_bucket" "pdf_bucket" {
  name          = "indexing-pdf-storage"
  location      = "US"
  storage_class = "STANDARD"
  uniform_bucket_level_access = true
}

# 🔹 Create Google Cloud Dataproc Cluster
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

    gce_cluster_config {
      service_account = "indexer-bucket@books-450100.iam.gserviceaccount.com"
      service_account_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }
  }
}

# 🔹 Create BigQuery Dataset (Only If It Doesn't Exist)
resource "google_bigquery_dataset" "indexing_dataset" {
  dataset_id = "indexing_dataset"
  project    = "books-450100"
  location   = "US"
  description = "Dataset for storing indexed words, books, and references from PDFs."
}

# 🔹 Create BigQuery Tables (Only If They Do Not Exist)
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

# 🔹 Start Kestra in Docker Locally
resource "null_resource" "start_kestra" {
  provisioner "local-exec" {
    command = <<EOT
      docker run -d --name kestra_server \
        -p 8080:8080 \
        -e GOOGLE_APPLICATION_CREDENTIALS=${var.google_credentials_path} \
        -v ${var.kestra_repo_path}:/app/repo \
        kestra/kestra:latest
    EOT
  }
}

# 🔹 Wait for Kestra to Start
resource "null_resource" "wait_for_kestra" {
  provisioner "local-exec" {
    command = "sleep 10"
  }

  depends_on = [null_resource.start_kestra]
}

# 🔹 Kick Off the Kestra Workflow
resource "null_resource" "run_kestra_workflow" {
  provisioner "local-exec" {
    command = <<EOT
      curl -X POST "http://localhost:8080/api/v1/executions/${var.kestra_workflow_namespace}/${var.kestra_workflow_id}" \
        -H "Content-Type: application/json"
    EOT
  }

  depends_on = [null_resource.wait_for_kestra]
}

output "kestra_url" {
  value = "http://localhost:8080/"
}
