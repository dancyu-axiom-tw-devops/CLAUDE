FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy scripts
COPY scripts/ /app/scripts/
COPY config/ /app/config/

# Set permissions
RUN chmod +x /app/scripts/*.py

# Set Python path
ENV PYTHONPATH=/app/scripts

# Run healthcheck
ENTRYPOINT ["python3", "/app/scripts/healthcheck.py"]
