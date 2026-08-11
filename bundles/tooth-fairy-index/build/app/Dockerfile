FROM python:3.12-slim
WORKDIR /app

# Install dependencies first so this layer stays cached across app-code-only changes.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .
COPY templates/ templates/

ENV PORT=8080
EXPOSE 8080

# Shell form so $PORT expands. Cloud Run sends one request at a time per
# thread; a single worker with several threads is enough for this app and
# keeps memory use predictable at the "small" size tier.
CMD gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 0 main:app
