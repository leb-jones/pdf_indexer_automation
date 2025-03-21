#!/bin/bash

# Exit script on any error
set -e

# Define base directory
BASE_DIR="/home/lebjones/PDFIndexer"
SHARED_DIR="$BASE_DIR/shared"
KESTRA_READY_FILE="$SHARED_DIR/kestra_ready.log"
KESTRA_URL="http://localhost:8080"
FLOW_NAMESPACE="indexing"
FLOW_ID="index-pdfspipeline"

# Define environment variables for Terraform
export TF_VAR_DIR="$BASE_DIR"
export TF_VAR_GOOGLE_CREDENTIALS_BUCKET="$BASE_DIR/keys/storage.json"
export TF_VAR_GOOGLE_CREDENTIALS_PATH="$BASE_DIR/keys/storage.json"
export TF_VAR_KESTRA_REPO_PATH="$BASE_DIR/kestra_workflows"
export TF_VAR_TERRAFORM="$BASE_DIR/terraform"
export TF_VAR_PYTHON_SCRIPT_PATH="$BASE_DIR/python"
export GOOGLE_APPLICATION_CREDENTIALS=$TF_VAR_GOOGLE_CREDENTIALS_PATH

# Ensure Terraform directory exists
if [ ! -d "$TF_VAR_TERRAFORM" ]; then
  echo "ERROR: Terraform directory not found: $TF_VAR_TERRAFORM"
  exit 1
fi

# Change to Terraform directory
cd "$TF_VAR_TERRAFORM"

## Initialize and apply Terraform
#echo "Initializing Terraform..."
#terraform init
#terraform apply -auto-approve

# Extract the GCS bucket name dynamically
BUCKET_NAME=$(terraform output -raw pdf_bucket_name)

# Check if bucket name was retrieved
if [ "$BUCKET_NAME" = "ERROR" ] || [ -z "$BUCKET_NAME" ]; then
  echo "ERROR: Failed to get bucket name from Terraform!"
  exit 1
fi

echo $BUCKET_NAME

export PDF_BUCKET_NAME=$BUCKET_NAME

source /home/lebjones/PDFIndexer/.venv/bin/activate

cd /home/lebjones/PDFIndexer/python

pip install -r requirements.txt

python -m spacy download en_core_web_sm

python load_pdfs.py

python indexer.py

deactivate
