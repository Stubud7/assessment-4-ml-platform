import os
import httpx
from fastapi import FastAPI, Header, HTTPException, Request, Response, status
from typing import Optional

app = FastAPI(title="Multi-Endpoint AI Gateway")

# Target cluster URLs for individual team microservices
SERVICES = {
    "fraud": os.getenv("FRAUD_SERVICE_URL", "http://fraud-service:8000"),
    "recommendations": os.getenv("RECOMMENDATIONS_SERVICE_URL", "http://recommendations-service:8000"),
    "forecasting": os.getenv("FORECASTING_SERVICE_URL", "http://forecasting-service:8000"),
}


@app.get("/health")
def health():
    return {"status": "healthy", "service": "gateway"}


@app.get("/ready")
async def ready():
    """Aggregated readiness check across all downstream team services."""
    readiness_status = {}
    all_ready = True

    async with httpx.AsyncClient() as client:
        for team, url in SERVICES.items():
            try:
                res = await client.get(f"{url}/ready", timeout=3.0)
                if res.status_code == 200:
                    readiness_status[team] = "ready"
                else:
                    readiness_status[team] = f"not ready ({res.status_code})"
                    all_ready = False
            except Exception as e:
                readiness_status[team] = f"unreachable ({str(e)})"
                all_ready = False

    if not all_ready:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"status": "not ready", "services": readiness_status},
        )

    return {"status": "ready", "services": readiness_status}


@app.post("/predict/{team}")
async def proxy_predict(
    team: str,
    payload: dict,
    x_target_variant: Optional[str] = Header(default=None),
):
    """
    Single entry-point proxy routing requests to team services based on URL path.
    Also forwards optional A/B testing headers.
    """
    if team not in SERVICES:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Unknown team route '{team}'. Valid endpoints: {list(SERVICES.keys())}",
        )

    target_url = f"{SERVICES[team]}/predict"
    headers = {}
    if x_target_variant:
        headers["X-Target-Variant"] = x_target_variant

    async with httpx.AsyncClient() as client:
        try:
            # Proxy request to downstream microservice
            response = await client.post(
                target_url,
                json=payload,
                headers=headers,
                timeout=10.0,
            )
            # Pass through the target service status code and JSON response
            return Response(
                content=response.content,
                status_code=response.status_code,
                media_type="application/json",
            )

        # Gateway Failure Path Handling
        except httpx.TimeoutException:
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail=f"Gateway timeout waiting for service '{team}'.",
            )
        except httpx.RequestError as e:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Failed to communicate with downstream service '{team}': {str(e)}",
            )