# ---- Stage 1: Builder ----
FROM python:3.12-slim AS builder

ENV PYTHONUNBUFFERED=1 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    STREAMLIT_PORT=8501

# Install system deps for building packages and kubectl
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        unzip \
        git \
        bash \
        build-essential \
        && rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN KUBECTL_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt) && \
    curl -LO "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

WORKDIR /app

# Copy requirements and install Python deps into /install
COPY requirements.txt .
RUN pip install --target=/install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# ---- Stage 2: Final lightweight image ----
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    STREAMLIT_PORT=8501 \
    PYTHONPATH=/install

# Copy kubectl from builder
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl

# Copy Python packages and app
COPY --from=builder /install /install
COPY --from=builder /app /app

WORKDIR /app

EXPOSE ${STREAMLIT_PORT}

CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0", "--server.enableCORS=false"]
