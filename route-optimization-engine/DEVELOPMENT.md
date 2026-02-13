# Development Guide

Detailed instructions for setting up, running, and testing the Route Optimization Engine locally.

## Quick Start: Run Everything

```bash
cd route-optimization-engine

# Run setup, data generation, optimization, and all tests
./run-all.sh

# Or with options:
./run-all.sh --no-docker    # Skip Docker, use local MongoDB/Redis
./run-all.sh --tests-only   # Only run test suites
./run-all.sh --no-tests     # Skip tests
./run-all.sh --help         # Show all options
```

## Prerequisites

- **Python 3.9+** with pip
- **Node.js 18+** with npm
- **Docker** and Docker Compose (for the Docker workflow)
- **MongoDB 6+** (for the manual workflow, or use Docker)
- **Redis** (for the manual workflow, or use Docker)

## Option 1: Docker (Recommended)

This starts all five services (MongoDB, Redis, LocalStack, API, Optimization Engine) with a single command.

```bash
cd route-optimization-engine

# 1. Set up environment variables
cp .env.example .env

# 2. Start all services
cd infrastructure/docker
docker-compose up -d

# 3. Verify services are running
docker-compose ps

# 4. Install Python dependencies (for data scripts)
cd ../..
pip install -r requirements.txt

# 5. Generate synthetic data and load into MongoDB
python3 scripts/generate_data.py
python3 scripts/load_mongodb.py

# 6. Run optimization
python3 scripts/run_optimization.py
```

### Services & Ports

| Service        | URL                              | Description                  |
|----------------|----------------------------------|------------------------------|
| API (Swagger)  | http://localhost:3001/api-docs   | REST API with interactive docs |
| Frontend       | http://localhost:3000            | React/Next.js dashboard       |
| Optimization   | http://localhost:8000            | Python optimization service    |
| MongoDB        | localhost:27017                  | Operational database           |
| Redis          | localhost:6379                   | Cache and job queue            |
| LocalStack     | localhost:4566                   | AWS service emulation (S3, SQS, SNS, Lambda) |

### Stopping Services

```bash
cd infrastructure/docker
docker-compose down          # stop containers
docker-compose down -v       # stop and remove volumes (deletes data)
```

## Option 2: Manual Setup (No Docker)

Use this if you want to run each service individually. You'll need MongoDB and Redis running locally.

### 1. Python Optimization Engine

```bash
cd route-optimization-engine

# Install dependencies
pip install -r requirements.txt

# Generate synthetic data (50 properties, 10 technicians, 100 work orders)
python3 scripts/generate_data.py

# Load data into MongoDB (requires MongoDB running on localhost:27017)
python3 scripts/load_mongodb.py

# Run optimization with all three algorithms
python3 scripts/run_optimization.py
```

### 2. Backend API (Node.js)

```bash
cd route-optimization-engine/backend

# Install dependencies
npm install

# Set up environment (edit MONGODB_URI if your MongoDB is not on localhost:27017)
cp ../.env.example .env

# Start in development mode (auto-reloads on changes)
npm run dev
```

The API starts on http://localhost:3001 with Swagger docs at http://localhost:3001/api-docs.

### 3. Frontend Dashboard (Next.js)

```bash
cd route-optimization-engine/frontend

# Install dependencies
npm install

# Start dev server
npm run dev
```

The dashboard opens at http://localhost:3000.

## Running Tests

### Python Tests (Optimization Engine)

54 unit tests covering all three solvers, constraint validation, and distance calculations.

```bash
cd route-optimization-engine/optimization

# Run all tests with verbose output
python3 -m pytest tests/ -v

# Expected: 50 passed, 4 skipped
# The 4 skipped tests are VRP solver tests that require the ortools package

# Run with coverage report
python3 -m pytest tests/ -v --cov=. --cov-report=term-missing
```

### Python Tests (Scripts)

Tests for data generation, optimization runner, and evaluation scripts.

```bash
cd route-optimization-engine/scripts

python3 -m pytest tests/ -v
```

### Backend API Tests (Jest + Supertest)

Uses `mongodb-memory-server` so no external MongoDB is needed.

```bash
cd route-optimization-engine/backend

# Run tests
npm test

# Run with watch mode (re-runs on file changes)
npm run test:watch

# Run with coverage
npm run test:coverage
```

### Frontend Tests

```bash
cd route-optimization-engine/frontend

npm test
```

### Run All Tests

From the project root:

```bash
cd route-optimization-engine

# Python tests
python3 -m pytest optimization/tests/ scripts/tests/ -v

# Node.js tests
cd backend && npm test && cd ..
cd frontend && npm test && cd ..
```

## Benchmarking & Evaluation

### Algorithm Comparison

Run all three algorithms side-by-side and compare results:

```bash
cd route-optimization-engine

python3 scripts/run_optimization.py
```

### Evaluate Against Baseline

Compare optimized routes against naive (unoptimized) routes:

```bash
python3 scripts/evaluate.py
```

This calculates:
- Distance reduction (% improvement)
- Time savings per technician per day
- Workload balance (standard deviation across technicians)
- Constraint satisfaction rates

## Troubleshooting

### `ortools` installation fails

The VRP solver depends on Google OR-Tools. If `pip install ortools` fails:

- Ensure you're on Python 3.9-3.12 (not 3.13+; check with `python3 --version`)
- On Apple Silicon, try: `pip install --no-cache-dir ortools`
- The greedy and genetic algorithm solvers work without `ortools`

### MongoDB connection refused

- **Docker workflow**: make sure `docker-compose ps` shows mongodb as "healthy"
- **Manual workflow**: ensure MongoDB is running on `localhost:27017`
- Check your `.env` file has the correct `MONGODB_URI`

### Port already in use

If port 3001 or 3000 is taken:

```bash
# Find what's using the port
lsof -i :3001

# Change the port in .env
PORT=3002
```

### Docker build fails

```bash
# Clean rebuild
cd infrastructure/docker
docker-compose build --no-cache
docker-compose up -d
```

## Snowflake Setup (Optional)

Only needed if you want the analytics data warehouse.

```bash
# Create database and tables
snowsql -f data/snowflake/schemas/01_create_database.sql
snowsql -f data/snowflake/schemas/02_raw_tables.sql
snowsql -f data/snowflake/schemas/03_staging_tables.sql
snowsql -f data/snowflake/schemas/04_analytics_tables.sql

# Load sample data
snowsql -f data/snowflake/seed/sample_data.sql

# Create analytics views
snowsql -f data/snowflake/views/route_performance.sql
snowsql -f data/snowflake/views/technician_workload.sql
snowsql -f data/snowflake/views/optimization_comparison.sql
```

## Useful Commands

| Command | Description |
|---------|-------------|
| `python3 scripts/generate_data.py` | Generate synthetic Denver metro data |
| `python3 scripts/load_mongodb.py` | Load generated data into MongoDB |
| `python3 scripts/run_optimization.py` | Run all three optimization algorithms |
| `python3 scripts/evaluate.py` | Benchmark and compare results |
| `python3 scripts/load_snowflake.py` | Generate Snowflake INSERT statements |
| `npm run dev` (backend/) | Start API with hot reload |
| `npm run dev` (frontend/) | Start dashboard with hot reload |
| `npm run lint` (backend/) | Run ESLint |
| `npm run lint:fix` (backend/) | Auto-fix lint issues |
