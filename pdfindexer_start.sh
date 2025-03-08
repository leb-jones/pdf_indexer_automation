#!/bin/bash

# Define the directory where the keys are stored
KEYS_DIR="/home/lebjones/PDFIndexer/keys"
TF_DIR="/home/lebjones/PDFIndexer/terraform"

# Set environment variables
export GOOGLE_APPLICATION_CREDENTIALS_BUCKET="$KEYS_DIR/bucket.json"
export GOOGLE_APPLICATION_CREDENTIALS_DATAPROC="$KEYS_DIR/dataproc.json"
export GOOGLE_APPLICATION_CREDENTIALS_BIGQUERY="$KEYS_DIR/bigquery.json"

# Print variables for verification
echo "GOOGLE_APPLICATION_CREDENTIALS_BUCKET=$GOOGLE_APPLICATION_CREDENTIALS_BUCKET"
echo "GOOGLE_APPLICATION_CREDENTIALS_DATAPROC=$GOOGLE_APPLICATION_CREDENTIALS_DATAPROC"
echo "GOOGLE_APPLICATION_CREDENTIALS_BIGQUERY=$GOOGLE_APPLICATION_CREDENTIALS_BIGQUERY"

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
