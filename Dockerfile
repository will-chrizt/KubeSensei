# ---- Stage 2: Final lightweight image ----
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    STREAMLIT_PORT=8501 \
    PYTHONPATH=/install \
    PATH=/install/bin:$PATH    # <-- Add this line

# Copy kubectl from builder
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl

# Copy Python packages and app
COPY --from=builder /install /install
COPY --from=builder /app /app

WORKDIR /app

EXPOSE ${STREAMLIT_PORT}

CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0", "--server.enableCORS=false"]
