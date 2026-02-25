#!/bin/bash
set -e

# Script to set GitHub secrets from .env file
# Usage: ./scripts/set-github-secrets.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting GitHub Secrets from .env${NC}"
echo "================================================"

# Check if .env exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
    exit 1
fi

# Check if gh CLI is installed and authenticated
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
    echo "Install from: https://cli.github.com/"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with GitHub CLI${NC}"
    echo "Run: gh auth login"
    exit 1
fi

# Source the .env file
source "$ENV_FILE"

# Set AWS credentials
echo -n "Setting AWS_ACCESS_KEY_ID... "
echo "$AWS_ACCESS_KEY" | gh secret set AWS_ACCESS_KEY_ID
echo -e "${GREEN}✓${NC}"

echo -n "Setting AWS_SECRET_ACCESS_KEY... "
echo "$AWS_SECRET_KEY" | gh secret set AWS_SECRET_ACCESS_KEY
echo -e "${GREEN}✓${NC}"

echo -n "Setting EKS_CLUSTER_NAME... "
echo "$AWS_EKS_CLUSTER_NAME" | gh secret set EKS_CLUSTER_NAME
echo -e "${GREEN}✓${NC}"

# Optional: Set GHCR token if not using GITHUB_TOKEN
# echo -n "Setting GHCR_TOKEN... "
# echo "$GHCR_TOKEN" | gh secret set GHCR_TOKEN
# echo -e "${GREEN}✓${NC}"

echo ""
echo -e "${GREEN}All secrets set successfully!${NC}"
echo ""
echo "Verify with:"
echo "  gh secret list"
