@#!/bin/bash

set -e
set -o pipefail

# Paths
WORKFLOW_FILE="/home/lebjones/PDFIndexer/pdf_ingest_workflow.yml"
DOCKER_COMPOSE_FILE="./docker-compose.yml"
KESTRA_HOST="http://localhost:8080"
KESTRA_CONTAINER_NAME="kestra"
WORKFLOW_PATH_IN_CONTAINER="/app/pdfindexer/pdf_ingest_workflow.yml"
WORKFLOW_ID="pdfindexer.pdf_ingest_workflow"

echo "🛠️ Starting Kestra with Docker Compose..."
docker-compose -f "$DOCKER_COMPOSE_FILE" up -d

echo "⏳ Waiting for Kestra to be ready..."
until curl --silent --fail $KESTRA_HOST > /dev/null; do
  printf '.'
  sleep 2
done
echo -e "\n✅ Kestra is ready."

curl -X POST http://localhost:8080/api/v1/namespaces \
  -H "Content-Type: application/json" \
  -d '{"name": "pdf.indexer"}'

curl -X POST http://localhost:8080/api/v1/flows/import \
  -H "Content-Type: application/x-yaml" \
  --data-binary @${WORKFLOW_FILE}

echo "🚀 Executing workflow: $WORKFLOW_ID..."
docker exec kestra \
  curl -X POST http://localhost:8080/api/v1/executions/pdfindexer/pdf_ingest_workflow \

echo "🎉 Workflow execution complete!"
