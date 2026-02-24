from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
import boto3, os, json
import random
from datetime import datetime

app = FastAPI(title="Random Cut Forest Anomaly Detector")

ENDPOINT_NAME = os.getenv("ENDPOINT_NAME", "anomaly-detector-endpoint")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
MOCK_MODE = os.getenv("MOCK_MODE", "false").lower() == "true"
MODEL_VERSION = os.getenv("MODEL_VERSION", "v1.0")


def get_sagemaker_client():
    return boto3.client("sagemaker-runtime", region_name=AWS_REGION)


@app.get("/")
def root():
    return {
        "service": "anomaly-detector",
        "model": "Random Cut Forest",
        "version": MODEL_VERSION,
        "mode": "mock" if MOCK_MODE else "sagemaker"
    }


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "service": "anomaly-detector",
        "endpoint": ENDPOINT_NAME,
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/ready")
def ready():
    if MOCK_MODE:
        return {"status": "ready", "mode": "mock"}
    
    if not ENDPOINT_NAME:
        return JSONResponse(
            status_code=503,
            content={"status": "not ready", "error": "ENDPOINT_NAME not set"},
        )
    try:
        get_sagemaker_client()
        return {"status": "ready", "mode": "sagemaker"}
    except Exception as e:
        return JSONResponse(
            status_code=503,
            content={"status": "not ready", "error": str(e)},
        )


@app.post("/detect")
def detect(payload: dict):
    """
    Detect anomalies in gold price movements
    Expected payload: {"current_price": 2000.0, "historical_data": [...]}
    """
    if MOCK_MODE:
        # Mock anomaly detection
        current_price = payload.get("current_price", 2000.0)
        anomaly_score = random.uniform(0, 1)
        is_anomaly = anomaly_score > 0.7
        
        return {
            "model": "random-cut-forest",
            "anomaly_score": round(anomaly_score, 3),
            "is_anomaly": is_anomaly,
            "severity": "high" if anomaly_score > 0.9 else "medium" if anomaly_score > 0.7 else "low",
            "timestamp": datetime.utcnow().isoformat(),
            "mode": "mock"
        }
    
    # SageMaker mode
    if not ENDPOINT_NAME:
        raise HTTPException(status_code=503, detail="ENDPOINT_NAME not set")
    try:
        client = get_sagemaker_client()
        response = client.invoke_endpoint(
            EndpointName=ENDPOINT_NAME,
            ContentType="application/json",
            Body=json.dumps(payload),
        )
        result = json.loads(response["Body"].read().decode())
        return {"anomaly_detection": result, "mode": "sagemaker"}
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e))


# Also support /predict for consistency
@app.post("/predict")
def predict(payload: dict):
    return detect(payload)
