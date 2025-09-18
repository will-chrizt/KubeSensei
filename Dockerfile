# ---- Stage 1: Builder ----
FROM python:3.12-slim AS builder

# Environment
ENV PYTHONUNBUFFERED=1 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    STREAMLIT_PORT=8501

# Install system deps and kubectl
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

# Set working directory
WORKDIR /app

# Install Python deps in builder
COPY requirements.txt .
RUN pip install --prefix=/install --no-cache-dir --upgrade pip && \
    pip install --prefix=/install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# ---- Stage 2: Final lightweight image ----
FROM python:3.12-slim

# Env
ENV PYTHONUNBUFFERED=1 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    STREAMLIT_PORT=8501 \
    PATH="/install/bin:$PATH"

# Copy kubectl from builder
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl

# Copy installed Python packages
COPY --from=builder /install /install
ENV PATH="/install/bin:$PATH" \
    PYTHONPATH="/install/lib/python3.12/site-packages:$PYTHONPATH"

# Set working directory
WORKDIR /app
COPY --from=builder /app /app

# Expose port
EXPOSE ${STREAMLIT_PORT}

# Entrypoint
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0", "--server.enableCORS=false"]
