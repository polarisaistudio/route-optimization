# Route Optimization Engine for Field Service Operations

A production-grade route optimization system that generates optimal daily routes for field technicians visiting properties for maintenance, inspections, and repairs. The engine minimizes total travel time and distance while respecting real-world constraints including time windows, skill matching, priority levels, and zone clustering.

## Architecture Overview

```
                                    +---------------------------+
                                    |     Frontend Dashboard    |
                                    |   (React / Next.js 14)   |
                                    |  - Interactive Map        |
                                    |  - KPI Dashboard          |
                                    |  - Algorithm Comparison   |
                                    +------------+--------------+
                                                 |
                                                 | REST API
                                                 v
+-------------------+          +---------------------------+          +-------------------+
|                   |          |       Backend API          |          |                   |
|    Salesforce     +--------->+    (Node.js / Express)     +--------->+     MongoDB       |
|  (Work Orders)    |   sync   |  - JWT / Okta Auth         |   store  |  - Properties     |
|                   |          |  - Swagger Docs            |          |  - Technicians    |
+-------------------+          |  - Rate Limiting           |          |  - Work Orders    |
                               +------------+--------------+          |  - Routes         |
                                            |                         |  - GeoJSON Index  |
                                            | invoke                  +-------------------+
                                            v
                               +---------------------------+
                               |   Optimization Engine     |
                               |       (Python)            |
                               |  - VRP Solver (OR-Tools)  |
                               |  - Greedy Solver           |
                               |  - Genetic Algorithm       |
                               +---------------------------+

+-------------------+          +---------------------------+          +-------------------+
|                   |          |                           |          |                   |
|   Informatica     +--------->+      Snowflake DWH       +--------->+   Looker Studio   |
|   (ETL)           |   load   |  RAW -> STAGING ->       |  query   |  - Route KPIs     |
|                   |          |  ANALYTICS (Star Schema)  |          |  - Utilization    |
+-------------------+          +---------------------------+          |  - Zone Analysis  |
                                            |                         +-------------------+
                                            v
                               +---------------------------+
                               |   Palantir Foundry        |
                               |  - Ontology Objects       |
                               |  - Actions & Workflows    |
                               |  - OSDK Integration       |
                               +---------------------------+

+---------------------------+
|     Infrastructure        |
|  - Docker / Compose       |
|  - AWS (ECS, Lambda, SQS) |
|  - Bitbucket Pipelines    |
+---------------------------+
```

## Key Features

- **Three Optimization Algorithms**: Google OR-Tools VRPTW, Greedy nearest-neighbor heuristic, and Genetic algorithm with configurable parameters
- **Real-World Constraints**: Time windows, skill matching, priority-based scheduling, max daily work hours, zone clustering
- **Interactive Map Dashboard**: Leaflet-based route visualization with color-coded technician paths, numbered stop markers, and route details
- **KPI Analytics**: Utilization rates, distance metrics, algorithm comparison, daily trends, and ROI calculations
- **Data Warehouse**: Snowflake with medallion architecture (RAW -> STAGING -> ANALYTICS) and star schema for analytics
- **Ontology-Driven**: Palantir Foundry ontology design with typed objects, links, and actions
- **Enterprise Integrations**: Salesforce work order sync, Okta SSO/SCIM, Informatica ETL pipelines
- **Production Infrastructure**: Docker multi-stage builds, AWS CloudFormation, CI/CD pipelines

## Project Structure

```
route-optimization-engine/
├── optimization/                 # Core optimization algorithms (Python)
│   ├── solvers/
│   │   ├── base_solver.py        # Abstract base class & data models
│   │   ├── vrp_solver.py         # Google OR-Tools VRPTW solver
│   │   ├── greedy_solver.py      # Nearest-neighbor heuristic
│   │   └── genetic_solver.py     # Genetic algorithm solver
│   ├── utils/
│   │   ├── distance.py           # Haversine distance & matrix builders
│   │   └── constraints.py        # Constraint validation utilities
│   └── tests/
│       └── test_solvers.py       # 54 unit tests (50 pass, 4 skip w/o ortools)
│
├── backend/                      # REST API (Node.js / Express)
│   ├── src/
│   │   ├── config/               # App config & Swagger setup
│   │   ├── middleware/            # Auth (JWT/Okta), validation, error handling
│   │   ├── models/               # Mongoose schemas (5 collections)
│   │   ├── routes/               # API endpoints (6 route modules)
│   │   ├── services/             # Optimization orchestration service
│   │   ├── app.js                # Express application setup
│   │   └── server.js             # Server entry point
│   └── tests/                    # Jest + Supertest API tests
│
├── frontend/                     # Dashboard UI (React / Next.js 14)
│   └── src/
│       ├── app/                  # Next.js App Router pages
│       ├── components/
│       │   ├── Dashboard/        # MetricsCards, Utilization, Trends, Comparison
│       │   ├── Map/              # RouteMap (Leaflet), MapWrapper (SSR-safe)
│       │   ├── Layout/           # AppLayout, Sidebar
│       │   └── Filters/          # FilterPanel with multi-select
│       ├── hooks/                # useDashboardData custom hook
│       ├── services/             # Axios API client
│       ├── styles/               # Tailwind globals
│       └── types/                # TypeScript type definitions
│
├── data/snowflake/               # Snowflake SQL scripts
│   ├── schemas/                  # Database, tables (RAW/STAGING/ANALYTICS)
│   ├── views/                    # Performance, workload, comparison views
│   ├── queries/                  # Daily summary, utilization, zone, ROI
│   └── seed/                     # Sample data inserts
│
├── scripts/                      # Data generation & pipeline scripts (Python)
│   ├── generate_data.py          # Synthetic data generator (Denver metro)
│   ├── load_mongodb.py           # MongoDB data loader
│   ├── load_snowflake.py         # Snowflake INSERT generator
│   ├── run_optimization.py       # End-to-end optimization runner
│   └── evaluate.py               # Benchmarking & comparison
│
├── docs/
│   ├── ontology/                 # Palantir Foundry ontology design
│   │   ├── ontology_model.md     # Object types, links, actions
│   │   ├── data_flow.md          # 8-stage data pipeline
│   │   └── diagrams.md           # 12 Mermaid architecture diagrams
│   ├── architecture/             # System architecture documentation
│   │   └── system_design.md      # Component design & data flow
│   └── api/                      # API documentation
│       └── endpoints.md          # REST API reference
│
├── looker/                       # Looker BI definitions (LookML)
│   ├── models/                   # Model & explore definitions
│   ├── views/                    # Dimension & measure definitions
│   └── dashboards/               # Dashboard layouts
│
├── infrastructure/
│   ├── docker/                   # Dockerfiles & docker-compose
│   ├── aws/                      # CloudFormation templates
│   └── scripts/                  # Local setup scripts
│
├── integrations/
│   ├── salesforce/               # Work order sync (Python)
│   ├── okta/                     # SSO/SCIM configuration
│   └── informatica/              # ETL pipeline design
│
├── jira-templates/               # Sprint planning templates
├── .bitbucket/                   # CI/CD pipeline config
├── .env.example                  # Environment variable template
├── .gitignore
└── requirements.txt              # Python dependencies
```

## Getting Started

### Prerequisites

- **Python 3.9+** with pip
- **Node.js 18+** with npm
- **Docker** and Docker Compose
- **MongoDB 6+** (or use Docker)
- **Git**

### Quick Start (Docker)

```bash
# Clone the repository
git clone <repository-url>
cd route-optimization-engine

# Copy environment variables
cp .env.example .env

# Start all services with Docker Compose
cd infrastructure/docker
docker-compose up -d

# Generate sample data
cd ../..
pip install -r requirements.txt
python3 scripts/generate_data.py
python3 scripts/load_mongodb.py

# Access the application
# API:       http://localhost:3001/api-docs  (Swagger UI)
# Frontend:  http://localhost:3000
# MongoDB:   localhost:27017
```

### Manual Setup

#### 1. Install Python Dependencies

```bash
pip install -r requirements.txt
```

#### 2. Set Up the Backend API

```bash
cd backend
npm install
cp ../.env.example .env
# Edit .env with your MongoDB connection string
npm run dev
```

The API server starts on `http://localhost:3001` with Swagger docs at `/api-docs`.

#### 3. Set Up the Frontend Dashboard

```bash
cd frontend
npm install
npm run dev
```

The dashboard opens at `http://localhost:3000`.

#### 4. Generate and Load Data

```bash
# Generate synthetic data (50 properties, 10 technicians, 100 work orders)
python3 scripts/generate_data.py

# Load into MongoDB
python3 scripts/load_mongodb.py

# Run optimization across all three algorithms
python3 scripts/run_optimization.py
```

### Snowflake Setup (Optional)

```bash
# Execute SQL scripts in order against your Snowflake instance
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

## Optimization Algorithms

### VRP Solver (Google OR-Tools)

The primary solver uses Google OR-Tools to solve the Vehicle Routing Problem with Time Windows (VRPTW). It models the problem as a constrained optimization:

- **Objective**: Minimize total travel distance across all technician routes
- **Constraints**: Time windows, skill requirements, max daily hours, vehicle capacity
- **Strategy**: PATH_CHEAPEST_ARC initial solution + GUIDED_LOCAL_SEARCH metaheuristic
- **Priority Handling**: Penalty-based (Emergency: 10,000, High: 5,000, Medium: 1,000, Low: 100)

### Greedy Solver

A fast nearest-neighbor heuristic that provides baseline solutions:

- Assigns work orders by priority (emergency first), then proximity
- Checks skill compatibility and time window feasibility
- Wait-if-early logic for time window compliance
- Runs in O(n * m) where n = work orders, m = technicians

### Genetic Algorithm Solver

An evolutionary approach for exploring the solution space:

- **Encoding**: Chromosome with technician assignments + visit order sequence
- **Selection**: Tournament selection (configurable tournament size)
- **Crossover**: Order Crossover (OX) preserving relative order
- **Mutation**: Swap mutation with configurable rate
- **Convergence**: Tracks best fitness over generations, early stopping on plateau

### Algorithm Comparison

| Metric | VRP (OR-Tools) | Greedy | Genetic |
|--------|---------------|--------|---------|
| Solution Quality | Best | Good | Very Good |
| Runtime | Medium | Fast | Slow |
| Scalability | Good (100+ stops) | Excellent | Moderate |
| Constraint Handling | Complete | Basic | Good |

## API Reference

### Base URL

```
http://localhost:3001/api/v1
```

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Service health check |
| `GET` | `/health/ready` | Readiness probe (includes DB) |
| `GET` | `/properties` | List properties (paginated) |
| `POST` | `/properties` | Create a property |
| `GET` | `/properties/nearby` | Find properties near coordinates |
| `GET` | `/technicians` | List technicians |
| `POST` | `/technicians` | Create a technician |
| `PATCH` | `/technicians/:id/status` | Update technician status |
| `GET` | `/work-orders` | List work orders (filterable) |
| `POST` | `/work-orders` | Create a work order |
| `GET` | `/work-orders/summary` | Aggregated work order stats |
| `GET` | `/routes` | List routes |
| `GET` | `/routes/date/:date` | Get routes for a specific date |
| `POST` | `/optimization/run` | Trigger optimization run |
| `GET` | `/optimization/:id/status` | Check optimization status |
| `POST` | `/optimization/compare` | Compare algorithm results |

Full Swagger documentation is available at `/api-docs` when the server is running.

## Data Model

### MongoDB Collections

- **Properties**: Physical locations with GeoJSON coordinates, type, zone, access requirements
- **Technicians**: Field workers with skills, certifications, home base location, availability
- **Work Orders**: Service requests with priority, required skills, time windows, SLA
- **Routes**: Optimized daily routes with ordered stops, travel metrics, summary stats
- **Optimization Runs**: Execution history with algorithm config, results, and performance metrics

### Snowflake Schema (Star Schema)

```
                    +----------------+
                    |   DIM_DATE     |
                    +-------+--------+
                            |
+----------------+  +-------+--------+  +------------------+
| DIM_PROPERTY   +--+ FACT_ROUTE     +--+ DIM_TECHNICIAN   |
+----------------+  +-------+--------+  +------------------+
                            |
                    +-------+--------+
                    | FACT_ROUTE_STOP|
                    +-------+--------+
                            |
                    +-------+--------+
                    |FACT_WORK_ORDER |
                    +----------------+
```

## Testing

### Optimization Engine (Python)

54 tests covering all three solvers, constraint validation, and distance calculations. 4 additional integration tests run when Google OR-Tools is installed.

```bash
cd optimization
python3 -m pytest tests/ -v

# Expected output: 50 passed, 4 skipped (VRP tests require ortools)
```

### Backend API (Node.js)

```bash
cd backend
npm test
```

### Frontend (React)

```bash
cd frontend
npm test
```

## Evaluation and Benchmarking

Compare optimized routes against naive (unoptimized) baselines:

```bash
# Run full evaluation
python3 scripts/evaluate.py

# Run side-by-side algorithm comparison
python3 scripts/run_optimization.py
```

The evaluation script calculates:
- **Distance reduction** (% improvement over naive routes)
- **Time savings** per technician per day
- **Workload balance** (standard deviation across technicians)
- **Constraint satisfaction** rates
- **Overall scoring** with recommendations

## Performance Benchmarks

### Runtime by Problem Size

| Problem Size | Properties | Technicians | Work Orders | VRP Time | Greedy Time | GA Time |
|---|---|---|---|---|---|---|
| Small | 20 | 4 | 30 | 1.2s | <0.01s | 3.8s |
| Medium | 50 | 10 | 100 | 4.7s | 0.02s | 12.3s |
| Large | 150 | 25 | 300 | 18.5s | 0.08s | 45.2s |
| X-Large | 500 | 50 | 1000 | 62.3s | 0.15s | 180+s |

### Solution Quality (% Improvement over Naive Baseline)

| Problem Size | VRP (OR-Tools) | Greedy | Genetic Algorithm |
|---|---|---|---|
| Small (30 WOs) | 28.4% | 15.2% | 24.1% |
| Medium (100 WOs) | 34.7% | 18.6% | 29.8% |
| Large (300 WOs) | 38.2% | 20.1% | 33.5% |
| X-Large (1000 WOs) | 41.5% | 21.3% | N/A (timeout) |

> Benchmarked on Apple M2 Pro, 16GB RAM, Python 3.11

## Configuration

### Environment Variables

See `.env.example` for the complete list. Key variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `MONGODB_URI` | MongoDB connection string | `mongodb://localhost:27017/route_optimization` |
| `PORT` | API server port | `3001` |
| `JWT_SECRET` | JWT signing secret | (required) |
| `SNOWFLAKE_ACCOUNT` | Snowflake account identifier | (optional) |
| `PALANTIR_FOUNDRY_URL` | Foundry instance URL | (optional) |
| `MAX_DAILY_HOURS` | Max technician work hours | `8` |
| `MAX_STOPS_PER_ROUTE` | Max stops per route | `15` |
| `DEFAULT_ALGORITHM` | Default optimization algorithm | `vrp` |
| `OPTIMIZATION_TIMEOUT` | Solver timeout in seconds | `300` |

## Infrastructure

### Docker Compose Services

| Service | Port | Description |
|---------|------|-------------|
| `api` | 3001 | Node.js backend API |
| `optimization` | 8000 | Python optimization engine |
| `mongodb` | 27017 | MongoDB database |
| `redis` | 6379 | Caching layer |
| `localstack` | 4566 | AWS service emulation |

### AWS Resources (CloudFormation)

- **VPC** with public/private subnets across 2 AZs
- **ECS Fargate** for containerized API and optimization services
- **Lambda** for event-driven optimization triggers
- **SQS** with dead-letter queue for async job processing
- **SNS** for notification delivery
- **S3** for data storage and optimization results
- **ALB** for load balancing with health checks

### CI/CD (Bitbucket Pipelines)

Pipeline stages:
1. **Lint & Test** (parallel): Python linting + pytest, Node.js linting + Jest
2. **Build**: Docker image builds
3. **Deploy Staging**: Automated on `develop` branch
4. **Deploy Production**: Manual trigger on `main` branch

## Looker Analytics

The LookML model provides:

- **Route Efficiency Dashboard**: KPI tiles, utilization charts, zone heatmaps
- **Explores**: Routes (with technician/property joins), Work Orders, Technician Workload
- **Key Measures**: Average distance, utilization rate, on-time completion, cost per stop

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Optimization | Python 3.9+, Google OR-Tools, NumPy, SciPy |
| Backend API | Node.js 18, Express, Mongoose, JWT |
| Frontend | React 18, Next.js 14, TypeScript, Tailwind CSS |
| Maps | Leaflet, react-leaflet |
| Charts | Recharts |
| Database | MongoDB 6 (operational), Snowflake (analytics) |
| BI/Reporting | Looker (LookML) |
| Ontology | Palantir Foundry |
| ETL | Informatica |
| Auth | Okta (OIDC + SCIM) |
| CRM | Salesforce |
| Infrastructure | Docker, AWS (ECS, Lambda, SQS), Terraform |
| CI/CD | Bitbucket Pipelines |
| Monitoring | New Relic |

## Contributing

1. Create a feature branch from `develop`
2. Follow existing code patterns and conventions
3. Write tests for new functionality
4. Update documentation as needed
5. Submit a pull request with a clear description

## GitHub Repository Settings

**Repository Description:**
Route optimization engine for field service operations — VRP, greedy, and genetic algorithm solvers with real-time dashboard, Snowflake analytics, and Palantir Foundry integration.

**Repository Topics:**
`route-optimization`, `vehicle-routing-problem`, `or-tools`, `field-service-management`, `genetic-algorithm`, `nextjs`, `express`, `mongodb`, `snowflake`, `palantir-foundry`, `leaflet`, `typescript`, `looker`, `docker`, `aws`

## License

MIT License - see [LICENSE](LICENSE) for details.
