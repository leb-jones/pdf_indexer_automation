import fitz  # PyMuPDF
import os
import string
import pandas as pd
import nltk
from google.cloud import bigquery, storage
from nltk.corpus import stopwords
from nltk.stem import WordNetLemmatizer

# Google Cloud configurations
BQ_CREDENTIALS_PATH = "/home/lebjones/PDFIndexer/keys/bigquery.json"
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = BQ_CREDENTIALS_PATH

BQ_PROJECT_ID = "your-gcp-project-id"
BQ_DATASET = "indexing_dataset"
BQ_TABLE_DIM_WORD = "dim_word"
BQ_TABLE_DIM_BOOK = "dim_book"
BQ_TABLE_FACT_INDEX = "index_fact"
GCS_BUCKET = "indexing-pdf-storage"

storage_client = storage.Client()
bq_client = bigquery.Client(project=BQ_PROJECT_ID)

nltk.download("stopwords")
nltk.download("wordnet")

STOPWORDS = set(stopwords.words("english"))
STOPWORDS.update({"page", "document", "pdf", "figure", "table"})

lemmatizer = WordNetLemmatizer()

def normalize_word(word):
    word = word.strip(string.punctuation).lower()
    hyphen_variants = {word, word.replace("-", ""), word.replace("-", " ")}
    cleaned_words = {lemmatizer.lemmatize(w) for w in hyphen_variants if w and w.isalpha() and w not in STOPWORDS}
    return cleaned_words if cleaned_words else None

def extract_text_from_gcs(bucket_name):
    word_set = set()
    book_set = set()
    fact_data = []

    bucket = storage_client.bucket(bucket_name)
    blobs = bucket.list_blobs(prefix="pdfs/")

    for blob in blobs:
        if blob.name.endswith(".pdf"):
            book_set.add(blob.name)
            pdf_data = blob.download_as_bytes()
            doc = fitz.open(stream=pdf_data, filetype="pdf")

            for page_num in range(len(doc)):
                text = doc[page_num].get_text("text")
                words = set()
                for word in text.split():
                    normalized_words = normalize_word(word)
                    if normalized_words:
                        words.update(normalized_words)
                
                for word in words:
                    word_set.add(word)
                    fact_data.append((word, blob.name, page_num + 1))

    return word_set, book_set, fact_data

def build_star_schema(word_set, book_set, fact_data):
    dim_word = pd.DataFrame({"Word": sorted(word_set)})
    dim_word["WordID"] = range(1, len(dim_word) + 1)

    dim_book = pd.DataFrame({"Book": sorted(book_set)})
    dim_book["BookID"] = range(1, len(dim_book) + 1)

    word_dict = dict(zip(dim_word["Word"], dim_word["WordID"]))
    book_dict = dict(zip(dim_book["Book"], dim_book["BookID"]))

    fact_table = pd.DataFrame(fact_data, columns=["Word", "Book", "PageNumber"])
    fact_table["WordID"] = fact_table["Word"].map(word_dict)
    fact_table["BookID"] = fact_table["Book"].map(book_dict)
    fact_table = fact_table[["WordID", "BookID", "PageNumber"]]

    insert_into_bigquery(dim_word, BQ_TABLE_DIM_WORD)
    insert_into_bigquery(dim_book, BQ_TABLE_DIM_BOOK)
    insert_into_bigquery(fact_table, BQ_TABLE_FACT_INDEX)

def insert_into_bigquery(df, table_name):
    table_id = f"{BQ_PROJECT_ID}.{BQ_DATASET}.{table_name}"
    job_config = bigquery.LoadJobConfig(write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE)
    job = bq_client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()

if __name__ == "__main__":
    word_set, book_set, fact_data = extract_text_from_gcs(GCS_BUCKET)
    build_star_schema(word_set, book_set, fact_data)
