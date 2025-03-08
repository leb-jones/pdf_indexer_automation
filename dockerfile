#Use the official Kestra image
FROM kestra/kestra:latest

#Set the working directory inside the container
WORKDIR /app

#Copy Kestra workflows inside the container
COPY home/lebjones/PDFIndexer/kestra/ /app/kestra_workflows/

#Install Terraform (for infrastructure automation)
RUN apk add --no-cache terraform

#Install Google Cloud SDK (for Dataproc & BigQuery)
RUN apk add --no-cache google-cloud-sdk

#Copy Terraform scripts inside the container
COPY home/lebjones/PDFIndexer/terraform/ /app/terraform/

#Set environment variables for credentials
ENV GCS_KEY_PATH="/app/keys/bucket.json"
ENV BIGQUERY_KEY_PATH="/app/keys/bigquery.json"
ENV GOOGLE_APPLICATION_CREDENTIALS="/app/keys/bigquery.json"
ENV DATAPROC_KEY_PATH="/run/secrets/dataproc_key"

#Expose Kestra UI port (8080)
EXPOSE 8080

#Start Kestra server
CMD ["server"]
