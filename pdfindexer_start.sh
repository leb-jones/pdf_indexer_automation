#!/bin/bash

# Define the directory where the keys are stored
KEYS_DIR="/home/lebjones/PDFIndexer/keys"
TF_DIR="/home/lebjones/PDFIndexer/terraform"

# Set environment variables
export TF_VAR_google_credentials_bucket="/home/lebjones/PDFIndexer/keys/bucket.json"
export TF_VAR_google_credentials_dataproc="/home/lebjones/PDFIndexer/keys/dataproc.json"
export TF_VAR_google_credentials_bigquery="/home/lebjones/PDFIndexer/keys/bigquery.json"

# Change to Terraform directory
cd $TF_DIR

# Initialize Terraform
terraform init

# Apply Terraform configuration (automated, no prompts)
terraform apply -auto-approve

# Get Kestra VM IP (extracts the value from Terraform output)
KESTRA_VM_IP=$(terraform output -raw kestra_vm_ip)
echo "Kestra is running at: http://$KESTRA_VM_IP:8080"

# SSH into Kestra VM and check logs
echo "Checking Kestra logs..."
gcloud compute ssh kestra-server --zone=us-central1-a --command "docker logs -f kestra_server"
