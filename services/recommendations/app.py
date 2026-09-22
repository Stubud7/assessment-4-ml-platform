#assessment-4 app.py file
 
import json
import os
import boto3
from botocore.exceptions import BotoCoreError, ClientError
from fastapi import FastAPI, Header, HTTPException
from fastapi.responses import JSONResponse
from typing import Optional

app = FastAPI()

ENDPOINT_NAME = os.getenv("ENDPOINT_NAME", "")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")


def get_sagemaker_client():
    return boto3.client("sagemaker-runtime", region_name=AWS_REGION)


@app.get("/health")
def health():
    return {"status": "healthy", "endpoint": ENDPOINT_NAME}


@app.get("/ready")
def ready():
    if not ENDPOINT_NAME:
        return JSONResponse(
            status_code=503,
            content={"status": "not ready", "error": "ENDPOINT_NAME not set"},
        )

    try:
        # Check AWS SageMaker control plane to confirm the endpoint is InService
        sm_control = boto3.client("sagemaker", region_name=AWS_REGION)
        description = sm_control.describe_endpoint(EndpointName=ENDPOINT_NAME)
        endpoint_status = description.get("EndpointStatus")

        if endpoint_status != "InService":
            return JSONResponse(
                status_code=503,
                content={
                    "status": "not ready",
                    "error": f"Endpoint status is '{endpoint_status}'",
                },
            )

        return {"status": "ready"}
    except Exception as e:
        return JSONResponse(
            status_code=503,
            content={"status": "not ready", "error": str(e)},
        )


@app.post("/predict")
def predict(payload: dict, x_target_variant: Optional[str] = Header(default=None)):
    if not ENDPOINT_NAME:
        raise HTTPException(status_code=503, detail="ENDPOINT_NAME not set")

    try:
        client = get_sagemaker_client()

        # Build kwargs dynamically to support optional A/B variant routing header
        invoke_args = {
            "EndpointName": ENDPOINT_NAME,
            "ContentType": "application/json",
            "Body": json.dumps(payload),
        }
        if x_target_variant:
            invoke_args["TargetVariant"] = x_target_variant

        response = client.invoke_endpoint(**invoke_args)

        result = json.loads(response["Body"].read().decode())
        return {"prediction": result}

    # Specific Failure Paths & Granular Error Handling
    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code", "")
        error_msg = e.response.get("Error", {}).get("Message", str(e))

        if error_code == "ModelError":
            # SageMaker model container crashed or returned an error
            raise HTTPException(
                status_code=502,
                detail=f"SageMaker Model Container Error: {error_msg}",
            )
        elif error_code == "ValidationError":
            # Mismatched input shape/format or non-existent TargetVariant
            raise HTTPException(
                status_code=400,
                detail=f"Invalid Request Payload/Variant: {error_msg}",
            )
        else:
            raise HTTPException(
                status_code=500,
                detail=f"AWS SageMaker Error ({error_code}): {error_msg}",
            )

    except BotoCoreError as e:
        # Connection timeouts / Network issues
        raise HTTPException(
            status_code=504,
            detail=f"Gateway Timeout / AWS Communication Failure: {str(e)}",
        )

    except Exception as e:
        # Catch-all for JSON parsing issues or unexpected runtime errors
        raise HTTPException(status_code=502, detail=str(e))