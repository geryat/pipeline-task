# ---- Stage 1: build dependencies ----
FROM python:3.12-slim AS builder
 
WORKDIR /app
 
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt
 
# ---- Stage 2: final lightweight image ----
FROM python:3.12-slim
 
# Create a non-root user to run the app
RUN useradd --create-home appuser
WORKDIR /app
 
# Copy only the installed packages from the builder stage
COPY --from=builder /root/.local /home/appuser/.local
COPY app.py .
 
# Make sure pip-installed binaries (gunicorn) are on PATH
ENV PATH=/home/appuser/.local/bin:$PATH
 
USER appuser
 
EXPOSE 5000
 
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
