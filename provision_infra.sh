#!/bin/bash

set -e

TERRAFORM_DIR="./terraform"

echo "📦 Provisioning infrastructure with Terraform..."
cd "$TERRAFORM_DIR"

terraform init
terraform apply -auto-approve

cd -
echo "✅ Infrastructure is up-to-date."
