FROM python:3.9.25-alpine3.22

RUN apk update && apk upgrade --no-cache

WORKDIR /app

COPY . .

RUN pip install --no-cache-dir -r requirements.txt

CMD ["opentelemetry-instrument", "gunicorn", "--bind", "0.0.0.0:8003", "app:app"]