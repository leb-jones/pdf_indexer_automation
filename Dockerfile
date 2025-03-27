FROM kestra/kestra:latest-full

# Switch to root to install curl and Python
USER root

# Install curl and Python
RUN apt-get update && \
    apt-get install -y curl python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Create plugin directory if it doesn't exist
RUN mkdir -p /app/plugins

# Download the Docker plugin JAR
RUN curl -L -o /app/plugins/kestra-io-plugin-docker.jar \
  https://github.com/kestra-io/plugin-docker/releases/download/v0.21.2/kestra-io-plugin-docker-0.21.2.jar

# Switch back to kestra user
USER kestra

# Install Python requirements
COPY python/requirements.txt /app/
RUN pip3 install --no-cache-dir -r /app/requirements.txt

# Copy your Python scripts into the image
COPY python/ /app/

