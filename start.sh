#!/bin/bash
set -e

# 1. Set script directory context
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 2. Determine target team (from CLI arg, environment variable, or interactive prompt)
TEAM="${1:-$TEAM_NAME}"

if [ -z "$TEAM" ]; then
    echo "=========================================="
    echo " Select Lab Team Environment"
    echo "=========================================="
    echo "1) Fraud Detection (team-fraud-detection)"
    echo "2) Recommendations (team-recommendations)"
    echo "3) Forecasting (team-forecasting)"
    read -rp "Enter choice [1-3] or type team name directly: " CHOICE

    case "$CHOICE" in
        1) TEAM="team-fraud-detection" ;;
        2) TEAM="team-recommendations" ;;
        3) TEAM="team-forecasting" ;;
        *) TEAM="$CHOICE" ;;
    esac
fi

echo ""
echo "--> Configured for Team: $TEAM"

# 3. Query AWS SageMaker Endpoint for the selected lab team
echo "Fetching active SageMaker endpoint for $TEAM..."
ENDPOINT_NAME=$(aws sagemaker list-endpoints \
  --name-contains "ml-platform-$TEAM" \
  --query "Endpoints[0].EndpointName" \
  --output text 2>/dev/null || true)

# Fallback: prompt if endpoint was not found automatically
if [ "$ENDPOINT_NAME" = "None" ] || [ -z "$ENDPOINT_NAME" ]; then
    echo "Warning: No SageMaker endpoint matching 'ml-platform-$TEAM' was found in AWS."
    read -rp "Enter custom Endpoint Name manually (or press Enter to skip): " ENDPOINT_NAME
    ENDPOINT_NAME="${ENDPOINT_NAME:-your-sagemaker-endpoint}"
else
    echo "Found active endpoint: $ENDPOINT_NAME"
fi

# 4. Port availability helper functions
check_port_in_use() {
    local port="$1"
    if command -v lsof >/dev/null 2>&1; then
        lsof -i :"$port" >/dev/null 2>&1
    elif command -v netstat >/dev/null 2>&1; then
        netstat -an 2>/dev/null | grep -q ":$port.*LISTEN"
    else
        timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/$port" 2>/dev/null
    fi
}

find_available_port() {
    local port="$1"
    local attempts=0
    while [ $attempts -lt 100 ]; do
        if ! check_port_in_use "$port"; then
            echo "$port"
            return 0
        fi
        port=$((port + 1))
        attempts=$((attempts + 1))
    done
    echo "$1"
    return 1
}

echo "Checking local ports..."
BACKEND_PORT=$(find_available_port 8000)
DASHBOARD_PORT=$(find_available_port 3000)

[ "$BACKEND_PORT" != "8000" ] && echo "Port 8000 in use, assigning $BACKEND_PORT"
[ "$DASHBOARD_PORT" != "3000" ] && echo "Port 3000 in use, assigning $DASHBOARD_PORT"

# 5. Generate fresh .env file for the target lab team
cat > .env << EOF
AWS_REGION=us-east-1
TEAM_NAME=$TEAM
ENDPOINT_NAME=$ENDPOINT_NAME
BACKEND_PORT=$BACKEND_PORT
DASHBOARD_PORT=$DASHBOARD_PORT
TF_VAR_project_name=ml-platform
TF_VAR_environment=dev
TF_VAR_aws_region=us-east-1
EOF

echo "Updated .env file for $TEAM"

# 6. Initialize secrets file if missing
if [ ! -f .env.secrets ]; then
    cat > .env.secrets << EOF
# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=
EOF
    echo "Created .env.secrets"
fi

# 7. Export variables to shell environment
set -a && source .env && set +a

echo ""
echo "=========================================="
echo " Environment Ready"
echo "=========================================="
echo "  Team:           $TEAM"
echo "  Endpoint:       $ENDPOINT_NAME"
echo "  Backend Port:   $BACKEND_PORT"
echo "  Dashboard Port: $DASHBOARD_PORT"
echo "  AWS Region:     $AWS_REGION"
echo "=========================================="

# Extract short name: handles 'team-fraud-detection' or 'fraud'
SERVICE_DIR=$(echo "$TEAM" | sed -E 's/^(team-)?([a-z]+).*/\2/')

if [ -d "services/$SERVICE_DIR" ]; then
    echo ""
    echo "=========================================="
    echo " Starting $SERVICE_DIR Service Locally"
    echo "=========================================="
    echo "  URL: http://localhost:$BACKEND_PORT"
    echo "  SageMaker Target: $ENDPOINT_NAME"
    echo "=========================================="
    echo ""
    
    cd "services/$SERVICE_DIR"
    uvicorn app:app --host 0.0.0.0 --port "$BACKEND_PORT" --reload
else
    echo ""
    echo "Warning: Directory 'services/$SERVICE_DIR' not found."
    echo "Available services:"
    ls -d services/*/ | xargs -n 1 basename
fi