#!/bin/bash

set -e
set -o pipefail

# Paths
WORKFLOW_FILE="./PDFIndexer/pdf_ingest_workflow.yaml"
DOCKER_COMPOSE_FILE="./docker-compose.yml"
KESTRA_HOST="http://localhost:8080"
KESTRA_CONTAINER_NAME="kestra"
WORKFLOW_PATH_IN_CONTAINER="/app/pdfindexer/pdf_ingest_workflow.yaml"
WORKFLOW_ID="pdf.indexer.pdf_ingest_workflow"

echo "🛠️ Starting Kestra with Docker Compose..."
docker-compose -f "$DOCKER_COMPOSE_FILE" up -d

echo "⏳ Waiting for Kestra to be ready..."
until curl --silent --fail $KESTRA_HOST > /dev/null; do
  printf '.'
  sleep 2
done
echo -e "\n✅ Kestra is ready."

echo "📥 Registering workflow..."
docker exec -i kestra \
  curl -X POST http://localhost:8080/api/v1/flows/import \
    -H "Content-Type: application/x-yaml" \
    --data-binary @/app/pdfindexer/pdf_ingest_workflow.yaml

echo "🚀 Executing workflow: $WORKFLOW_ID..."
docker exec kestra \
  curl -X POST http://localhost:8080/api/v1/executions/pdf.indexer/pdf_ingest_workflow \
    -F ""

echo "🎉 Workflow execution complete!"
