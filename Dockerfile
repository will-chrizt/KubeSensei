# Use official Python image
FROM python:3.12-slim

# Set working directory
WORKDIR /app

# Copy requirements (create a requirements.txt with needed packages)
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . .

# Set environment variable to avoid Python buffering
ENV PYTHONUNBUFFERED=1

# Run the app
CMD ["python", "app.py"]
