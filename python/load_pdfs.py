import os
import sys
from google.cloud import storage

# 🚀 Configuration
LOCAL_PDF_DIRECTORY = "/home/lebjones/Media/Books"  # Local directory containing PDFs
GCS_DESTINATION_PREFIX = "pdfs/"  # Folder inside the bucket (optional)

# 🚀 Ensure Google Cloud credentials are set
GCS_CREDENTIALS = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
if not GCS_CREDENTIALS:
    print("❌ ERROR: GOOGLE_APPLICATION_CREDENTIALS environment variable is not set!", file=sys.stderr)
    sys.exit(1)

GCS_BUCKET_NAME = os.getenv("PDF_BUCKET_NAME")
if not GCS_BUCKET_NAME:
    print("❌ ERROR: PDF_BUCKET_NAME environment variable is not set!", file=sys.stderr)
    sys.exit(1)

# 🚀 Initialize Google Cloud Storage Client
try:
    storage_client = storage.Client()
    bucket = storage_client.bucket(GCS_BUCKET_NAME)
except Exception as e:
    print(f"❌ ERROR: Failed to initialize Google Cloud Storage client: {e}", file=sys.stderr)
    sys.exit(1)

def get_existing_files():
    """Fetch existing PDF filenames from the GCS bucket to prevent duplicate uploads."""
    try:
        blobs = bucket.list_blobs(prefix=GCS_DESTINATION_PREFIX)
        existing_files = {blob.name.split("/")[-1] for blob in blobs}  # Extract filenames only
        print(f"📂 Found {len(existing_files)} existing PDFs in the bucket.")
        return existing_files
    except Exception as e:
        print(f"❌ ERROR: Failed to retrieve existing files from GCS: {e}", file=sys.stderr)
        sys.exit(1)

def upload_pdf_to_gcs(local_file_path, destination_blob_name):
    """Uploads a single PDF file to a GCS bucket."""
    blob = bucket.blob(destination_blob_name)

    try:
        blob.upload_from_filename(local_file_path)
        print(f"✅ Uploaded: {local_file_path} → gs://{GCS_BUCKET_NAME}/{destination_blob_name}")
    except Exception as e:
        print(f"❌ Failed to upload {local_file_path}: {e}")

def upload_pdfs_from_directory(local_directory):
    """Uploads only new PDFs from a local directory to GCS."""
    if not os.path.exists(local_directory):
        print(f"❌ ERROR: Directory not found: {local_directory}")
        return

    print(f"🚀 Starting upload from: {local_directory} → GCS Bucket: {GCS_BUCKET_NAME}")

    # Fetch existing PDFs in the bucket
    existing_files = get_existing_files()

    for root, _, files in os.walk(local_directory):
        for file in files:
            if file.lower().endswith(".pdf"):
                if file in existing_files:
                    print(f"⏭️ Skipping {file}, already exists in GCS.")
                    continue  # Skip existing PDFs

                local_path = os.path.join(root, file)
                gcs_path = os.path.join(GCS_DESTINATION_PREFIX, file).replace("\\", "/")
                upload_pdf_to_gcs(local_path, gcs_path)

    print("✅ Upload process completed.")

if __name__ == "__main__":
    upload_pdfs_from_directory(LOCAL_PDF_DIRECTORY)
