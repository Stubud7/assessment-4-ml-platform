from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
import boto3, os, json
import random
from datetime import datetime

app = FastAPI(title="XGBoost Gold Price Predictor")

ENDPOINT_NAME = os.getenv("ENDPOINT_NAME", "xgboost-predictor-endpoint")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
MOCK_MODE = os.getenv("MOCK_MODE", "false").lower() == "true"
MODEL_VERSION = os.getenv("MODEL_VERSION", "v1.0")


def get_sagemaker_client():
    return boto3.client("sagemaker-runtime", region_name=AWS_REGION)


@app.get("/")
def root():
    return {
        "service": "xgboost-predictor",
        "model": "XGBoost",
        "version": MODEL_VERSION,
        "mode": "mock" if MOCK_MODE else "sagemaker"
    }


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "service": "xgboost-predictor",
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


@app.post("/predict")
def predict(payload: dict):
    """
    Predict tomorrow's gold price using XGBoost
    Expected payload: {"current_price": 2000.0, "features": {...}}
    """
    if MOCK_MODE:
        # Mock prediction: slightly different variation than neural net
        current_price = payload.get("current_price", 2000.0)
        predicted_price = current_price + random.uniform(-40, 60)
        return {
            "model": "xgboost",
            "prediction": round(predicted_price, 2),
            "confidence": round(random.uniform(0.75, 0.92), 3),
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
        return {"prediction": result, "mode": "sagemaker"}
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e))
