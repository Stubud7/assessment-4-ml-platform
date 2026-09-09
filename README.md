# Resources

Starter files for Assessment IV.  Copy into your repo and build from here.

## Structure

- `services/example/` — FastAPI service with `/health`, `/ready`, `/predict`
- `dashboard/` — React + Vite shell with a health-check table
- `terraform/main.tf` — Provider and variable skeleton
- `k8s/example/` — Namespace, ConfigMap, Deployment, Service manifests
- `.github/workflows/deploy.yml` — CI/CD workflow template
- `start.sh` — Creates `.env` and `.env.secrets` with defaults

## Quick Start

```bash
./start.sh
cd services/example
pip install -r requirements.txt
ENDPOINT_NAME=<your-endpoint> uvicorn app:app --port 8000
```

Rename `example` to your team/client names, duplicate per team, and swap in the right values.
