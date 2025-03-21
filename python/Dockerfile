# Use official Python image
FROM python:3.12

# Set working directory
WORKDIR /app

# Copy application files
COPY . .

# Upgrade pip and install dependencies with python3
RUN python3 -m pip install --upgrade pip && python3 -m pip install --no-cache-dir -r requirements.txt

# Force reinstall Flask in case it's missing
RUN python3 -m pip install --no-cache-dir --force-reinstall flask

# Ensure Spacy model is downloaded inside the container
RUN python3 -m spacy download en_core_web_sm

# Expose port 8080 for Cloud Run
EXPOSE 8080

CMD ["uvicorn", "indexer:app", "--host", "0.0.0.0", "--port", "8080"]

