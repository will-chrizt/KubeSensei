# ---- Base Image ----
FROM python:3.12-slim

# ---- Set environment variables ----
ENV PYTHONUNBUFFERED=1 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    STREAMLIT_PORT=8501

# ---- Install system dependencies ----
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    unzip \
    git \
    bash \
    && rm -rf /var/lib/apt/lists/*

# ---- Install kubectl ----
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# ---- Set working directory ----
WORKDIR /app

# ---- Copy requirements and install ----
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# ---- Copy application code ----
COPY . .

# ---- Expose Streamlit port ----
EXPOSE ${STREAMLIT_PORT}

# ---- Streamlit entrypoint ----
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0", "--server.enableCORS=false"]
