#!/usr/bin/env bash
# ============================================================================
# Route Optimization Engine - Local Development Setup Script
# ============================================================================
# This script bootstraps the local development environment by verifying
# prerequisites, installing dependencies, configuring services, and loading
# sample data.
#
# Usage:
#   chmod +x infrastructure/scripts/setup-local.sh
#   ./infrastructure/scripts/setup-local.sh
#
# Options:
#   --skip-docker    Skip Docker service startup
#   --skip-data      Skip sample data generation and loading
#   --reset          Reset all data and start fresh
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${PROJECT_ROOT}/infrastructure/docker"

SKIP_DOCKER=false
SKIP_DATA=false
RESET=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --------------------------------------------------------------------------
# Parse arguments
# --------------------------------------------------------------------------
for arg in "$@"; do
    case $arg in
        --skip-docker) SKIP_DOCKER=true ;;
        --skip-data)   SKIP_DATA=true ;;
        --reset)       RESET=true ;;
        --help|-h)
            echo "Usage: $0 [--skip-docker] [--skip-data] [--reset]"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument: $arg${NC}"
            exit 1
            ;;
    esac
done

# --------------------------------------------------------------------------
# Helper functions
# --------------------------------------------------------------------------
log_info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

check_command() {
    if command -v "$1" &> /dev/null; then
        local version
        version=$("$1" --version 2>&1 | head -1)
        log_success "$1 found: $version"
        return 0
    else
        log_error "$1 is not installed. Please install it before continuing."
        return 1
    fi
}

# --------------------------------------------------------------------------
# Step 1: Check prerequisites
# --------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Route Optimization Engine - Local Setup"
echo "============================================================"
echo ""

log_info "Checking prerequisites..."

PREREQS_OK=true

check_command "node" || PREREQS_OK=false
check_command "npm" || PREREQS_OK=false
check_command "python3" || PREREQS_OK=false
check_command "pip3" || PREREQS_OK=false
check_command "docker" || PREREQS_OK=false
check_command "docker" && {
    if docker compose version &> /dev/null; then
        log_success "docker compose found: $(docker compose version --short 2>&1)"
    elif command -v docker-compose &> /dev/null; then
        log_success "docker-compose found: $(docker-compose --version 2>&1 | head -1)"
    else
        log_error "docker compose plugin not found"
        PREREQS_OK=false
    fi
}

if [ "$PREREQS_OK" = false ]; then
    log_error "Missing prerequisites. Please install the required tools and try again."
    exit 1
fi

log_success "All prerequisites satisfied."
echo ""

# --------------------------------------------------------------------------
# Step 2: Install backend (Node.js) dependencies
# --------------------------------------------------------------------------
log_info "Installing backend Node.js dependencies..."

if [ -f "${PROJECT_ROOT}/backend/package.json" ]; then
    cd "${PROJECT_ROOT}/backend"
    npm install --no-audit --no-fund
    log_success "Backend dependencies installed."
else
    log_warn "backend/package.json not found. Skipping npm install."
fi

echo ""

# --------------------------------------------------------------------------
# Step 3: Install Python dependencies
# --------------------------------------------------------------------------
log_info "Installing Python optimization dependencies..."

if [ -f "${PROJECT_ROOT}/optimization/requirements.txt" ]; then
    cd "${PROJECT_ROOT}"

    # Create virtual environment if it does not exist
    if [ ! -d "${PROJECT_ROOT}/.venv" ]; then
        log_info "Creating Python virtual environment..."
        python3 -m venv "${PROJECT_ROOT}/.venv"
    fi

    # Activate virtual environment
    source "${PROJECT_ROOT}/.venv/bin/activate"

    pip install --upgrade pip --quiet
    pip install -r "${PROJECT_ROOT}/optimization/requirements.txt" --quiet
    log_success "Python dependencies installed in .venv"
else
    log_warn "optimization/requirements.txt not found. Skipping pip install."
fi

echo ""

# --------------------------------------------------------------------------
# Step 4: Configure environment variables
# --------------------------------------------------------------------------
log_info "Configuring environment variables..."

cd "${PROJECT_ROOT}"

if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    cp .env.example .env
    log_success "Copied .env.example to .env"
    log_warn "Review .env and update any secrets before proceeding."
elif [ -f ".env" ]; then
    log_success ".env file already exists. Skipping copy."
else
    log_warn ".env.example not found. Creating minimal .env file..."
    cat > .env << 'EOF'
# Route Optimization Engine - Local Development Environment
NODE_ENV=development
PORT=3001
LOG_LEVEL=debug

# MongoDB
MONGO_USERNAME=routeadmin
MONGO_PASSWORD=routepass123
MONGODB_URI=mongodb://routeadmin:routepass123@localhost:27017/route_optimization?authSource=admin

# Redis
REDIS_PASSWORD=redispass123
REDIS_URL=redis://:redispass123@localhost:6379

# AWS (LocalStack)
AWS_ENDPOINT_URL=http://localhost:4566
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
S3_BUCKET_NAME=route-optimization-data
SQS_QUEUE_URL=http://localhost:4566/000000000000/optimization-jobs
SNS_TOPIC_ARN=arn:aws:sns:us-east-1:000000000000:route-notifications

# Auth (disabled for local development)
AUTH_ENABLED=false
JWT_SECRET=local-dev-secret-key-do-not-use-in-production
EOF
    log_success "Created minimal .env file."
fi

echo ""

# --------------------------------------------------------------------------
# Step 5: Start Docker services
# --------------------------------------------------------------------------
if [ "$SKIP_DOCKER" = false ]; then
    log_info "Starting Docker services..."

    cd "${DOCKER_DIR}"

    if [ "$RESET" = true ]; then
        log_warn "Resetting all Docker volumes and containers..."
        docker compose down -v --remove-orphans 2>/dev/null || true
    fi

    docker compose up -d --build

    log_info "Waiting for services to become healthy..."
    sleep 5

    # Wait for MongoDB
    RETRIES=30
    until docker compose exec -T mongodb mongosh --eval "db.adminCommand('ping')" --quiet > /dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
        log_info "Waiting for MongoDB... ($RETRIES attempts remaining)"
        RETRIES=$((RETRIES - 1))
        sleep 2
    done

    if [ $RETRIES -eq 0 ]; then
        log_error "MongoDB did not become healthy in time."
        exit 1
    fi
    log_success "MongoDB is ready."

    # Wait for Redis
    RETRIES=15
    until docker compose exec -T redis redis-cli -a redispass123 ping 2>/dev/null | grep -q PONG || [ $RETRIES -eq 0 ]; do
        log_info "Waiting for Redis... ($RETRIES attempts remaining)"
        RETRIES=$((RETRIES - 1))
        sleep 2
    done
    log_success "Redis is ready."

    log_success "All Docker services are running."
else
    log_warn "Skipping Docker service startup (--skip-docker)."
fi

echo ""

# --------------------------------------------------------------------------
# Step 6: Generate and load sample data
# --------------------------------------------------------------------------
if [ "$SKIP_DATA" = false ] && [ "$SKIP_DOCKER" = false ]; then
    log_info "Generating sample data..."

    cd "${PROJECT_ROOT}"

    if [ -f "scripts/generate_sample_data.py" ]; then
        if [ -d ".venv" ]; then
            source .venv/bin/activate
        fi
        python3 scripts/generate_sample_data.py --output tmp/sample_data.json
        log_success "Sample data generated at tmp/sample_data.json"
    else
        log_warn "scripts/generate_sample_data.py not found. Skipping data generation."
    fi

    log_info "Loading sample data into MongoDB..."

    if [ -f "scripts/load_sample_data.py" ]; then
        python3 scripts/load_sample_data.py --input tmp/sample_data.json
        log_success "Sample data loaded into MongoDB."
    elif [ -f "tmp/sample_data.json" ]; then
        # Fallback: use mongoimport directly
        log_info "Using mongoimport as fallback..."
        docker compose -f "${DOCKER_DIR}/docker-compose.yml" exec -T mongodb \
            mongoimport \
                --uri "mongodb://routeadmin:routepass123@localhost:27017/route_optimization?authSource=admin" \
                --collection sample_routes \
                --jsonArray \
                --file /dev/stdin < tmp/sample_data.json 2>/dev/null || \
            log_warn "mongoimport fallback did not complete. Load data manually."
    else
        log_warn "No sample data or load script found. Skipping data loading."
    fi
else
    log_warn "Skipping data generation and loading."
fi

echo ""

# --------------------------------------------------------------------------
# Step 7: Print success message
# --------------------------------------------------------------------------
echo "============================================================"
echo ""
log_success "Local development environment is ready!"
echo ""
echo "  Services:"
echo "  ---------------------------------------------------------"
echo "  API Backend:          http://localhost:3001"
echo "  API Health Check:     http://localhost:3001/health"
echo "  Optimization Service: http://localhost:8000"
echo "  MongoDB:              mongodb://localhost:27017"
echo "  Redis:                redis://localhost:6379"
echo "  LocalStack (AWS):     http://localhost:4566"
echo ""
echo "  Useful commands:"
echo "  ---------------------------------------------------------"
echo "  Start services:       cd infrastructure/docker && docker compose up -d"
echo "  Stop services:        cd infrastructure/docker && docker compose down"
echo "  View logs:            cd infrastructure/docker && docker compose logs -f"
echo "  Reset everything:     ./infrastructure/scripts/setup-local.sh --reset"
echo "  Run API tests:        cd backend && npm test"
echo "  Run Python tests:     cd optimization && pytest"
echo ""
echo "============================================================"
