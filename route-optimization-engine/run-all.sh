#!/usr/bin/env bash
# ============================================================================
# Route Optimization Engine - Run Everything
# ============================================================================
# Sets up the environment, starts services, generates data, runs optimization,
# and executes all test suites.
#
# Usage:
#   chmod +x run-all.sh
#   ./run-all.sh              # Run everything
#   ./run-all.sh --no-docker  # Skip Docker, assume MongoDB/Redis running locally
#   ./run-all.sh --tests-only # Only run tests (skip setup, data, optimization)
#   ./run-all.sh --no-tests   # Skip tests
# ============================================================================

set -euo pipefail

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
DOCKER_DIR="${PROJECT_ROOT}/infrastructure/docker"

USE_DOCKER=true
RUN_TESTS=true
TESTS_ONLY=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# --------------------------------------------------------------------------
# Parse arguments
# --------------------------------------------------------------------------
for arg in "$@"; do
    case $arg in
        --no-docker)  USE_DOCKER=false ;;
        --no-tests)   RUN_TESTS=false ;;
        --tests-only) TESTS_ONLY=true ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --no-docker   Skip Docker; assume MongoDB and Redis are running locally"
            echo "  --no-tests    Skip running test suites"
            echo "  --tests-only  Only run tests (skip setup, data generation, optimization)"
            echo "  -h, --help    Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument: $arg${NC}"
            echo "Run $0 --help for usage."
            exit 1
            ;;
    esac
done

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
step=0
step() {
    step=$((step + 1))
    echo ""
    echo -e "${BOLD}[$step] $1${NC}"
    echo "------------------------------------------------------------"
}

ok()   { echo -e "  ${GREEN}OK${NC}    $1"; }
warn() { echo -e "  ${YELLOW}WARN${NC}  $1"; }
fail() { echo -e "  ${RED}FAIL${NC}  $1"; }
info() { echo -e "  ${BLUE}...${NC}   $1"; }

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

record_pass() { PASS_COUNT=$((PASS_COUNT + 1)); }
record_fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); }
record_skip() { SKIP_COUNT=$((SKIP_COUNT + 1)); }

# --------------------------------------------------------------------------
# Header
# --------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Route Optimization Engine - Run All"
echo "============================================================"
echo " Project root: ${PROJECT_ROOT}"
echo " Docker:       ${USE_DOCKER}"
echo " Tests:        ${RUN_TESTS}"
echo " Tests only:   ${TESTS_ONLY}"
echo "============================================================"

if [ "$TESTS_ONLY" = true ]; then
    RUN_TESTS=true
fi

# ==========================================================================
# PHASE 1: Prerequisites
# ==========================================================================
step "Checking prerequisites"

PREREQS_OK=true

for cmd in python3 node npm; do
    if command -v "$cmd" &> /dev/null; then
        ok "$cmd: $("$cmd" --version 2>&1 | head -1)"
    else
        fail "$cmd is not installed"
        PREREQS_OK=false
    fi
done

if [ "$USE_DOCKER" = true ]; then
    if command -v docker &> /dev/null; then
        ok "docker: $(docker --version 2>&1 | head -1)"
        if docker compose version &> /dev/null; then
            ok "docker compose: $(docker compose version --short 2>&1)"
        elif command -v docker-compose &> /dev/null; then
            ok "docker-compose: $(docker-compose --version 2>&1 | head -1)"
        else
            fail "docker compose plugin not found"
            PREREQS_OK=false
        fi
    else
        fail "docker is not installed"
        PREREQS_OK=false
    fi
fi

if [ "$PREREQS_OK" = false ]; then
    fail "Missing prerequisites. Install the required tools and try again."
    exit 1
fi

ok "All prerequisites satisfied"

# ==========================================================================
# PHASE 2: Install dependencies
# ==========================================================================
step "Installing dependencies"

# Python
info "Installing Python dependencies..."
cd "${PROJECT_ROOT}"
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
    ok "Created virtual environment at .venv"
fi
source .venv/bin/activate
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet 2>&1 | tail -1 || true
ok "Python dependencies installed"

# Backend Node.js
if [ -f "${PROJECT_ROOT}/backend/package.json" ]; then
    info "Installing backend Node.js dependencies..."
    cd "${PROJECT_ROOT}/backend"
    npm install --no-audit --no-fund --silent 2>&1 | tail -3 || true
    ok "Backend dependencies installed"
    cd "${PROJECT_ROOT}"
else
    warn "backend/package.json not found, skipping"
fi

# Frontend Node.js
if [ -f "${PROJECT_ROOT}/frontend/package.json" ]; then
    info "Installing frontend Node.js dependencies..."
    cd "${PROJECT_ROOT}/frontend"
    npm install --no-audit --no-fund --silent 2>&1 | tail -3 || true
    ok "Frontend dependencies installed"
    cd "${PROJECT_ROOT}"
else
    warn "frontend/package.json not found, skipping"
fi

if [ "$TESTS_ONLY" = true ]; then
    # Jump straight to tests
    step "Skipping Docker, data, and optimization (--tests-only)"
    ok "Skipped"
else

# ==========================================================================
# PHASE 3: Start Docker services
# ==========================================================================
if [ "$USE_DOCKER" = true ]; then
    step "Starting Docker services"

    cd "${DOCKER_DIR}"

    # Copy .env if needed
    if [ -f "${PROJECT_ROOT}/.env.example" ] && [ ! -f "${PROJECT_ROOT}/.env" ]; then
        cp "${PROJECT_ROOT}/.env.example" "${PROJECT_ROOT}/.env"
        ok "Copied .env.example to .env"
    fi

    info "Starting containers (mongodb, redis, localstack)..."
    docker compose up -d mongodb redis localstack 2>&1 | tail -5

    info "Waiting for MongoDB to be healthy..."
    RETRIES=30
    until docker compose exec -T mongodb mongosh --eval "db.adminCommand('ping')" --quiet > /dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
        RETRIES=$((RETRIES - 1))
        sleep 2
    done
    if [ $RETRIES -eq 0 ]; then
        fail "MongoDB did not become healthy in time"
        exit 1
    fi
    ok "MongoDB is ready"

    info "Waiting for Redis to be healthy..."
    RETRIES=15
    until docker compose exec -T redis redis-cli -a redispass123 ping 2>/dev/null | grep -q PONG || [ $RETRIES -eq 0 ]; do
        RETRIES=$((RETRIES - 1))
        sleep 2
    done
    ok "Redis is ready"

    cd "${PROJECT_ROOT}"
else
    step "Skipping Docker (--no-docker)"
    warn "Make sure MongoDB and Redis are running locally"
fi

# ==========================================================================
# PHASE 4: Generate and load data
# ==========================================================================
step "Generating and loading sample data"

cd "${PROJECT_ROOT}"
source .venv/bin/activate

if [ -f "scripts/generate_data.py" ]; then
    info "Generating synthetic data (Denver metro)..."
    python3 scripts/generate_data.py
    ok "Data generated"
else
    warn "scripts/generate_data.py not found, skipping"
fi

if [ -f "scripts/load_mongodb.py" ]; then
    info "Loading data into MongoDB..."
    python3 scripts/load_mongodb.py
    ok "Data loaded into MongoDB"
else
    warn "scripts/load_mongodb.py not found, skipping"
fi

# ==========================================================================
# PHASE 5: Run optimization
# ==========================================================================
step "Running optimization (all algorithms)"

cd "${PROJECT_ROOT}"
source .venv/bin/activate

if [ -f "scripts/run_optimization.py" ]; then
    info "Running VRP, Greedy, and Genetic Algorithm solvers..."
    python3 scripts/run_optimization.py
    ok "Optimization complete"
else
    warn "scripts/run_optimization.py not found, skipping"
fi

# ==========================================================================
# PHASE 6: Evaluate results
# ==========================================================================
step "Evaluating and benchmarking results"

if [ -f "scripts/evaluate.py" ]; then
    info "Running evaluation..."
    python3 scripts/evaluate.py
    ok "Evaluation complete"
else
    warn "scripts/evaluate.py not found, skipping"
fi

fi  # end of TESTS_ONLY skip block

# ==========================================================================
# PHASE 7: Run tests
# ==========================================================================
if [ "$RUN_TESTS" = true ]; then
    step "Running test suites"

    cd "${PROJECT_ROOT}"
    source .venv/bin/activate

    # -- Python optimization tests --
    echo ""
    info "Python optimization tests (pytest)..."
    if [ -d "optimization/tests" ]; then
        if python3 -m pytest optimization/tests/ -v --tb=short 2>&1; then
            ok "Optimization tests passed"
            record_pass
        else
            fail "Optimization tests had failures"
            record_fail
        fi
    else
        warn "optimization/tests/ not found, skipping"
        record_skip
    fi

    # -- Python script tests --
    echo ""
    info "Python script tests (pytest)..."
    if [ -d "scripts/tests" ]; then
        if python3 -m pytest scripts/tests/ -v --tb=short 2>&1; then
            ok "Script tests passed"
            record_pass
        else
            fail "Script tests had failures"
            record_fail
        fi
    else
        warn "scripts/tests/ not found, skipping"
        record_skip
    fi

    # -- Backend API tests (Jest) --
    echo ""
    info "Backend API tests (Jest)..."
    if [ -f "backend/package.json" ]; then
        cd "${PROJECT_ROOT}/backend"
        if npm test 2>&1; then
            ok "Backend tests passed"
            record_pass
        else
            fail "Backend tests had failures"
            record_fail
        fi
        cd "${PROJECT_ROOT}"
    else
        warn "backend/package.json not found, skipping"
        record_skip
    fi

    # -- Frontend tests --
    echo ""
    info "Frontend tests..."
    if [ -f "frontend/package.json" ]; then
        cd "${PROJECT_ROOT}/frontend"
        if npm test 2>&1; then
            ok "Frontend tests passed"
            record_pass
        else
            fail "Frontend tests had failures"
            record_fail
        fi
        cd "${PROJECT_ROOT}"
    else
        warn "frontend/package.json not found, skipping"
        record_skip
    fi
else
    step "Skipping tests (--no-tests)"
    ok "Skipped"
fi

# ==========================================================================
# Summary
# ==========================================================================
echo ""
echo "============================================================"
echo -e " ${BOLD}Summary${NC}"
echo "============================================================"

if [ "$RUN_TESTS" = true ]; then
    echo -e "  Test suites passed:  ${GREEN}${PASS_COUNT}${NC}"
    echo -e "  Test suites failed:  ${RED}${FAIL_COUNT}${NC}"
    echo -e "  Test suites skipped: ${YELLOW}${SKIP_COUNT}${NC}"
    echo ""
fi

if [ "$USE_DOCKER" = true ] && [ "$TESTS_ONLY" = false ]; then
    echo "  Services running:"
    echo "    API (Swagger):      http://localhost:3001/api-docs"
    echo "    Optimization:       http://localhost:8000"
    echo "    MongoDB:            localhost:27017"
    echo "    Redis:              localhost:6379"
    echo ""
    echo "  Stop services:  cd infrastructure/docker && docker compose down"
fi

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo -e "  ${RED}Some tests failed. Check output above for details.${NC}"
    echo "============================================================"
    exit 1
else
    echo -e "  ${GREEN}All done!${NC}"
    echo "============================================================"
    exit 0
fi
