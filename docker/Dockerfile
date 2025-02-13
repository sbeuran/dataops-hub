FROM apache/spark-py:3.4.0

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3-pip \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt /app/requirements.txt

# Install Python dependencies
RUN pip3 install --no-cache-dir -r /app/requirements.txt

# Copy source code
COPY src/ /app/src/

# Set working directory
WORKDIR /app

# Command to run the ETL job
CMD ["spark-submit", "--master", "local[*]", "src/etl/transaction_etl.py"] 