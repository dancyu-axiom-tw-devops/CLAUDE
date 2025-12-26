FROM python:3.11-slim

WORKDIR /app

# Install kubectl
RUN apt-get update && \
    apt-get install -y curl && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/ && \
    apt-get remove -y curl && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Copy health check script
COPY scripts/health-check.py /app/health-check.py
RUN chmod +x /app/health-check.py

# Create reports directory
RUN mkdir -p /reports

# Set entrypoint
ENTRYPOINT ["python3", "/app/health-check.py"]
