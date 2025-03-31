Link to Public Dashboard: https://calebjones.metabaseapp.com/public/dashboard/9ec4fae3-935c-4684-9163-0924ecfdc0a3

# 📚 PDF Indexer Automation

This project automates the ingestion, processing, and indexing of PDF documents using Google Cloud services. It extracts keywords from PDFs using NLP and stores them in BigQuery for efficient querying and analysis.

---

## 🚀 Overview

The application:
- Uploads PDFs to a GCS bucket
- Uses Cloud Run to process each PDF
- Extracts keywords per page with spaCy
- Looks up metadata via `isbnlib`
- Stores:
  - Book metadata in `dim_book`
  - Unique words in `dim_word`
  - Indexed relationships in `index_fact`

---

## 🛠️ Technologies

- **Python 3.12**
- **FastAPI** for serving endpoints
- **Google Cloud Run**
- **BigQuery** for structured storage
- **Google Cloud Storage** for PDF storage
- **spaCy** for NLP
- **PyMuPDF** for PDF parsing
- **isbnlib** for metadata lookups
