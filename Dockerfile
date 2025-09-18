# ---- Builder Stage ----
FROM python:3.12-slim AS builder

# ---- Set environment variables ----
ENV PYTHONUNBUFFERED=1 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    STREAMLIT_PORT=8501 \
    PYTHONPATH=/install \
    PATH=/install/bin:$PATH

# ---- Install system dependencies ----
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        git \
        bash \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# ---- Install kubectl ----
RUN KUBECTL_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt) && \
    curl -LO "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# ---- Set working directory ----
WORKDIR /app

# ---- Copy requirements and install ----
COPY requirements.txt .
RUN pip install --prefix=/install --no-cache-dir --upgrade pip && \
    pip install --prefix=/install --no-cache-dir -r requirements.txt

# ---- Copy application code ----
COPY . .

# ---- Final Stage ----
FROM python:3.12-slim

# ---- Set environment variables ----
ENV PYTHONUNBUFFERED=1 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    STREAMLIT_PORT=8501 \
    PYTHONPATH=/install \
    PATH=/install/bin:$PATH

# ---- Install kubectl runtime dependency ----
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        bash \
    && rm -rf /var/lib/apt/lists/*

# ---- Copy installed packages and app from builder ----
COPY --from=builder /install /install
COPY --from=builder /app /app

WORKDIR /app

# ---- Expose Streamlit port ----
EXPOSE ${STREAMLIT_PORT}

# ---- Entrypoint ----
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0", "--server.enableCORS=false"]
