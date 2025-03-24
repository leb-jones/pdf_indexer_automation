FROM kestra/kestra:latest-full

# Switch to root to install curl
USER root

# Install curl
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Install Python
RUN apt-get update && \
    apt-get install -y python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Switch back to kestra user
USER kestra

# Download and extract the Docker plugin
RUN curl -L https://github.com/kestra-io/plugin-docker/archive/refs/tags/v0.21.2.tar.gz \
  | tar -xz -C /app/plugins/

# Install Python requirements
COPY python/requirements.txt /app/
RUN pip3 install --no-cache-dir -r /app/requirements.txt

# Copy Python scripts
COPY python/ /app/

# Default Kestra entrypoint stays intact (for server or CLI use)
