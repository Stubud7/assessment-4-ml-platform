FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV FRAUD_SERVICE_URL="http://fraud-service:8000"
ENV RECOMMENDATIONS_SERVICE_URL="http://recommendations-service:8000"
ENV FORECASTING_SERVICE_URL="http://forecasting-service:8000"

EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
