import os
from google.cloud import storage, bigquery
import fitz  # PyMuPDF for PDF processing
import spacy

# Load NLP Model
nlp = spacy.load("en_core_web_sm")

# Set up Google Cloud clients
storage_client = storage.Client()
bigquery_client = bigquery.Client()

# Get bucket name from environment variable
BUCKET_NAME = os.getenv("PDF_BUCKET_NAME", "your-default-bucket")

# BigQuery Dataset & Table Names
BQ_DATASET = "indexing_dataset"
DIM_BOOK_TABLE = f"{BQ_DATASET}.dim_book"
DIM_WORD_TABLE = f"{BQ_DATASET}.dim_word"
FACT_INDEX_TABLE = f"{BQ_DATASET}.fact_index"

def list_pdfs():
    """List all PDF files in the bucket."""
    bucket = storage_client.bucket(BUCKET_NAME)
    return [blob.name for blob in bucket.list_blobs() if blob.name.endswith(".pdf")]

def download_pdf(file_name):
    """Download a PDF from the GCS bucket to Cloud Run's /tmp directory."""
    bucket = storage_client.bucket(BUCKET_NAME)
    blob = bucket.blob(file_name)

    local_path = f"/tmp/{os.path.basename(file_name)}"  # Ensure filename-only path
    blob.download_to_filename(local_path)
    
    print(f"Downloaded {file_name} to {local_path}")
    return local_path

def extract_text(pdf_path):
    """Extract text from a PDF file."""
    text_data = {}
    with fitz.open(pdf_path) as doc:
        for page_num, page in enumerate(doc):
            text_data[page_num + 1] = page.get_text()
    return text_data

def process_text(text_data):
    """Extract keywords from text using Spacy NLP."""
    keywords = {}
    for page, text in text_data.items():
        doc = nlp(text)
        words = {token.text.lower() for token in doc if token.is_alpha and not token.is_stop}
        keywords[page] = words
    return keywords

def insert_into_bigquery(file_name, keywords):
    """Insert book and word data into BigQuery."""
    book_id = insert_book_record(file_name)
    for page, words in keywords.items():
        for word in words:
            word_id = insert_word_record(word)
            insert_fact_index(book_id, word_id, page)

from google.cloud import bigquery

def insert_book_record(book_name):
    print(f"Inserting book record for: {book_name}")
    bigquery_client = bigquery.Client()

    # Escape single quotes to prevent SQL injection issues
    escaped_book_name = book_name.replace("'", "''")

    # Generate a new BookID by finding MAX(BookID) + 1
    get_max_id_query = f"""
    SELECT COALESCE(MAX(BookID), 0) + 1 AS new_id FROM `{DIM_BOOK_TABLE}`
    """

    try:
        # Execute query to get the next available BookID
        result = bigquery_client.query(get_max_id_query).result()
        new_book_id = None
        for row in result:
            new_book_id = row.new_id
        if new_book_id is None:
            print("Error: Failed to generate new BookID")
            return None

        # Insert new book with the generated BookID
        insert_query = f"""
        INSERT INTO `{DIM_BOOK_TABLE}` (BookID, BookName)
        VALUES (@book_id, @book_name)
        """

        query_params = [
            bigquery.ScalarQueryParameter("book_id", "INT64", new_book_id),
            bigquery.ScalarQueryParameter("book_name", "STRING", escaped_book_name)
        ]

        job_config = bigquery.QueryJobConfig(query_parameters=query_params)
        bigquery_client.query(insert_query, job_config=job_config).result()

        print(f"Inserted BookID {new_book_id} for '{book_name}'")
        return new_book_id

    except Exception as e:
        print(f"Error inserting book: {e}")
        return None

def insert_word_record(word):
    print(f"Inserting word record for: {word}")
    bigquery_client = bigquery.Client()

    # Escape single quotes to prevent SQL injection issues
    escaped_word = word.replace("'", "''")

    # Generate a new WordID by finding MAX(WordID) + 1
    get_max_id_query = f"""
    SELECT COALESCE(MAX(WordID), 0) + 1 AS new_id FROM `{DIM_WORD_TABLE}`
    """

    try:
        # Execute query to get the next available WordID
        result = bigquery_client.query(get_max_id_query).result()
        new_word_id = None
        for row in result:
            new_word_id = row.new_id
        if new_word_id is None:
            print("Error: Failed to generate new WordID")
            return None

        # Insert new word with the generated WordID
        insert_query = f"""
        INSERT INTO `{DIM_WORD_TABLE}` (WordID, Word)
        VALUES (@word_id, @word)
        """

        query_params = [
            bigquery.ScalarQueryParameter("word_id", "INT64", new_word_id),
            bigquery.ScalarQueryParameter("word", "STRING", escaped_word)
        ]

        job_config = bigquery.QueryJobConfig(query_parameters=query_params)
        bigquery_client.query(insert_query, job_config=job_config).result()

        print(f"Inserted WordID {new_word_id} for '{word}'")
        return new_word_id

    except Exception as e:
        print(f"Error inserting word: {e}")
        return None

def insert_fact_index(book_id, word_id, page):
    """Insert data into the fact_index table."""
    query = f"""
        INSERT INTO `{FACT_INDEX_TABLE}` (WordID, BookID, PageNumber)
        VALUES (@word_id, @book_id, @page);
    """
    bigquery_client.query(query, job_config=bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("word_id", "INT64", word_id),
            bigquery.ScalarQueryParameter("book_id", "INT64", book_id),
            bigquery.ScalarQueryParameter("page", "INT64", page),
        ]
    ))

# Flask or FastAPI Endpoint to Trigger Processing
from fastapi import FastAPI

app = FastAPI()

@app.get("/process_pdfs")
def process_pdfs():
    """Trigger the process to index all PDFs from GCS."""
    pdf_files = list_pdfs()
    for pdf in pdf_files:
        local_path = download_pdf(pdf)
        text_data = extract_text(local_path)
        keywords = process_text(text_data)
        insert_into_bigquery(pdf, keywords)
    return {"message": f"Processed {len(pdf_files)} PDFs successfully."}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
