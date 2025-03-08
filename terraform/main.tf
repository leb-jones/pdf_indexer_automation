provider "google" {
  credentials = file("/home/lebjones/PDFIndexer/keys/dataproc.json")
  project     = "your-gcp-project-id"
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
      service_account = "your-dataproc-service-account@your-gcp-project-id.iam.gserviceaccount.com"
      service_account_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }
  }
}

# 🔹 Create BigQuery Dataset (Only If It Doesn't Exist)
resource "google_bigquery_dataset" "indexing_dataset" {
  dataset_id = "indexing_dataset"
  project    = "your-gcp-project-id"
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

# 🔹 Create Compute Engine VM for Kestra
resource "google_compute_instance" "kestra_vm" {
  name         = "kestra-server"
  machine_type = "e2-standard-2"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker

    # Pull and Run Kestra Container
    docker run -d -p 8080:8080 --name kestra_server \
      -e GOOGLE_APPLICATION_CREDENTIALS=/app/keys/bigquery.json \
      -v /home/lebjones/PDFIndexer/keys:/app/keys \
      -v /home/lebjones/PDFIndexer/kestra_workflows:/app/kestra_workflows \
      kestra/kestra:latest

    # Wait for Kestra to start
    sleep 30

    # Run Kestra workflow to start indexing
    docker exec kestra_server kestra workflow run indexing.index-pdfs-pipeline
  EOT
}

# 🔹 Output the VM's external IP
output "kestra_vm_ip" {
  value = google_compute_instance.kestra_vm.network_interface.0.access_config.0.nat_ip
}
