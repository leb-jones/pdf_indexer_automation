#!/bin/bash

# Define GCP Project ID
PROJECT_ID="books-450100"

# Ensure the correct project is set for gcloud commands
gcloud config set project $PROJECT_ID

# Define the directory where the keys are stored
KEYS_DIR="/home/lebjones/PDFIndexer/keys"
TF_DIR="/home/lebjones/PDFIndexer/terraform"

# Set environment variables for Terraform credentials
export TF_VAR_google_credentials_bucket="$KEYS_DIR/bucket.json"
export TF_VAR_google_credentials_dataproc="$KEYS_DIR/dataproc.json"
export TF_VAR_google_credentials_bigquery="$KEYS_DIR/bigquery.json"
export TF_VAR_kestra_repo_path="/home/lebjones/PDFIndexer"
export TF_VAR_google_credentials_path="/app/repo/keys/bigquery.json"

# Print variables for verification
echo "GCP Project: $PROJECT_ID"
echo "GOOGLE_APPLICATION_CREDENTIALS_BUCKET=$TF_VAR_google_credentials_bucket"
echo "GOOGLE_APPLICATION_CREDENTIALS_DATAPROC=$TF_VAR_google_credentials_dataproc"
echo "GOOGLE_APPLICATION_CREDENTIALS_BIGQUERY=$TF_VAR_google_credentials_bigquery"

# Change to Terraform directory
cd $TF_DIR

# Initialize Terraform
terraform init

# Apply Terraform configuration (automated, no prompts)
terraform apply -auto-approve

# Wait for Kestra to start (since Terraform is running it)
sleep 10

# Check Kestra logs
docker logs -f kestra_server
