# Jira Epic Template: Route Optimization Engine - Phase 1

## Epic

**Title:** Route Optimization Engine - Phase 1: Core Platform
**Key:** ROE-1
**Priority:** High
**Labels:** `route-optimization`, `phase-1`, `field-service`, `q1-2026`
**Fix Version:** 1.0.0
**Team:** Field Service Engineering
**Epic Description:**

Build the core Route Optimization Engine platform for Polaris Real Estate field
service operations. Phase 1 delivers the foundational data pipeline, optimization
algorithms, backend API, frontend dashboard, integration layer, and monitoring
infrastructure. The goal is to reduce average route distance by 15-20% and improve
technician utilization from 65% to 85%.

**Business Value:**
- Reduce fleet fuel and vehicle maintenance costs by ~$180K/year
- Improve technician utilization leading to 15% more work orders completed per day
- Reduce average customer wait times by 25%
- Provide dispatchers with data-driven routing decisions

**Success Metrics:**
- Average route distance reduced by 15%+ vs. manual routing
- Technician utilization reaches 80%+ daily average
- 95% of optimized routes accepted by dispatchers without modification
- System processes optimization requests in < 30 seconds for up to 200 work orders

---

## Stories

---

### Story 1: Data Pipeline Setup

**Title:** Set up data ingestion pipeline from Salesforce and internal systems
**Key:** ROE-2
**Type:** Story
**Priority:** High
**Story Points:** 13
**Labels:** `data-pipeline`, `backend`, `integration`
**Sprint:** Sprint 1

**Description:**
As a data engineer, I need to build the ETL/sync pipeline that ingests work orders
from Salesforce, technician data from the HR system, and property data from the
property management API so that the optimization engine has current, clean data to
work with.

**Acceptance Criteria:**
- [ ] Salesforce work order sync runs incrementally every 15 minutes using the
      `simple-salesforce` library with retry logic and exponential backoff
- [ ] Full sync mode is available for initial data load and recovery scenarios
- [ ] Work order records are mapped from Salesforce schema to internal schema with
      proper field transformations (status mapping, priority mapping, duration
      conversion)
- [ ] Technician profiles are synced from MongoDB with skills, availability, and
      zone assignments
- [ ] Property records are loaded with geographic coordinates (lat/lng) for distance
      calculations
- [ ] All sync operations are idempotent (upsert on unique IDs)
- [ ] Sync metadata (last sync timestamp, record counts, error counts) is persisted
      for observability
- [ ] Error records are logged to a dedicated collection without blocking the pipeline
- [ ] Data quality rules reject records with missing required fields or out-of-range
      values
- [ ] Pipeline handles Salesforce API rate limits gracefully (429 responses)
- [ ] Unit tests cover field mapping, error handling, and retry logic (>80% coverage)
- [ ] Integration test confirms end-to-end flow from Salesforce sandbox to MongoDB

**Technical Notes:**
- Reference implementation: `integrations/salesforce/sync_work_orders.py`
- Informatica pipeline design documented in `integrations/informatica/pipeline_config.md`
- Snowflake target tables defined in the Looker view files under `looker/views/`

**Dependencies:** None (foundational)

---

### Story 2: Core Optimization Engine

**Title:** Implement route optimization algorithms with OR-Tools and genetic algorithm
**Key:** ROE-3
**Type:** Story
**Priority:** High
**Story Points:** 21
**Labels:** `optimization`, `algorithm`, `python`, `core`
**Sprint:** Sprint 1-2

**Description:**
As an optimization engineer, I need to implement the core route optimization
algorithms that take a set of work orders, technician availability, and constraints
as input and produce optimized route assignments as output, so that dispatchers
receive efficient route suggestions daily.

**Acceptance Criteria:**
- [ ] OR-Tools VRP solver is implemented as the primary optimization algorithm with
      support for time windows, capacity constraints, and skill matching
- [ ] Genetic algorithm is implemented as an alternative solver for comparison and
      fallback scenarios
- [ ] Greedy nearest-neighbor heuristic is available as a fast baseline algorithm
- [ ] Simulated annealing solver is available for fine-tuning solutions
- [ ] All algorithms respect constraints: technician max hours, time windows,
      required skills, zone preferences, and break requirements
- [ ] Distance/duration matrix is computed using the Haversine formula with an
      optional external routing API integration point
- [ ] Optimization request accepts up to 200 work orders and 30 technicians and
      returns results within 30 seconds
- [ ] Each optimization run produces a quality score (0-100) based on distance
      efficiency, utilization balance, and constraint satisfaction
- [ ] Results include per-route metrics: total distance, duration, stop count,
      utilization percentage, and ordered stop sequence
- [ ] Algorithm selection is configurable per request (dispatcher can choose or
      system auto-selects based on problem size)
- [ ] Optimization service exposes a health endpoint and structured logging
- [ ] Unit tests cover each algorithm with known-good test fixtures (>85% coverage)
- [ ] Performance benchmark test validates the 30-second SLA for 200-order scenarios

**Technical Notes:**
- Python 3.11 with OR-Tools, numpy, scipy
- Service exposed via FastAPI (uvicorn)
- Docker image: `infrastructure/docker/Dockerfile.optimization`

**Dependencies:** ROE-2 (Data Pipeline - for test data)

---

### Story 3: Backend API

**Title:** Build the Node.js REST API for route management and optimization triggers
**Key:** ROE-4
**Type:** Story
**Priority:** High
**Story Points:** 13
**Labels:** `backend`, `api`, `nodejs`
**Sprint:** Sprint 2

**Description:**
As a backend engineer, I need to build the REST API that serves route data to the
frontend, accepts optimization requests, manages work orders and technician
assignments, and integrates with the Python optimization service, so that the
frontend and external systems have a stable interface to interact with.

**Acceptance Criteria:**
- [ ] RESTful API endpoints implemented:
  - `GET /api/v1/routes` - List routes with filtering (date, status, zone, algorithm)
  - `GET /api/v1/routes/:id` - Get route detail with stops and work orders
  - `POST /api/v1/routes/optimize` - Trigger optimization job
  - `PUT /api/v1/routes/:id/approve` - Approve an optimized route
  - `GET /api/v1/work-orders` - List work orders with filtering
  - `PATCH /api/v1/work-orders/:id/status` - Update work order status
  - `GET /api/v1/technicians` - List technicians with availability
  - `GET /api/v1/dashboard/metrics` - Aggregated KPI metrics
- [ ] Request validation with JSON schema (express-validator or joi)
- [ ] Pagination support on all list endpoints (cursor-based preferred)
- [ ] Authentication middleware validates Okta JWT tokens (bypass in dev mode)
- [ ] Authorization middleware enforces role-based access control per the Okta
      role mapping (admin, dispatcher, supervisor, technician, analyst, viewer)
- [ ] Zone-based data filtering applied automatically based on user context
- [ ] API communicates with Python optimization service via internal HTTP
- [ ] Optimization jobs are queued to SQS for async processing with status polling
- [ ] Redis caching for frequently accessed data (dashboard metrics, technician list)
- [ ] Structured JSON logging with request IDs for traceability
- [ ] Health check endpoint returns service status, dependency checks, and version
- [ ] OpenAPI/Swagger documentation auto-generated from route definitions
- [ ] API rate limiting (100 req/min per user for standard endpoints)
- [ ] Jest test suite with >80% coverage; integration tests with MongoDB testcontainer

**Technical Notes:**
- Node.js 18 with Express
- Docker image: `infrastructure/docker/Dockerfile.api`
- Okta auth config: `integrations/okta/auth_config.md`

**Dependencies:** ROE-2, ROE-3

---

### Story 4: Frontend Dashboard

**Title:** Build the React-based dispatcher dashboard for route visualization
**Key:** ROE-5
**Type:** Story
**Priority:** Medium
**Story Points:** 13
**Labels:** `frontend`, `react`, `dashboard`, `ui`
**Sprint:** Sprint 2-3

**Description:**
As a dispatcher, I need a web dashboard that displays optimized routes on a map,
shows KPI metrics, allows me to review and approve route suggestions, and manage
daily work order assignments, so that I can make informed routing decisions quickly.

**Acceptance Criteria:**
- [ ] Dashboard displays daily route overview with KPI tiles (total routes, avg
      distance, avg utilization, improvement vs. baseline)
- [ ] Interactive map visualization (Mapbox GL or Leaflet) showing routes with
      color-coded paths per technician and stop markers
- [ ] Route list view with sortable/filterable table (date, technician, algorithm,
      status, distance, duration, stops)
- [ ] Route detail panel shows ordered stop sequence, time windows, estimated
      arrival times, and work order details
- [ ] "Run Optimization" button triggers async optimization and displays progress
- [ ] Route approval workflow: dispatcher can approve, modify, or reject suggested
      routes
- [ ] Technician workload view showing daily utilization per technician
- [ ] Work order management view with drag-and-drop manual assignment capability
- [ ] Responsive layout supporting desktop (1280px+) and tablet (768px+) viewports
- [ ] Dark mode support using CSS variables
- [ ] Okta SSO login integration with automatic token refresh
- [ ] Loading states, error boundaries, and empty states for all views
- [ ] Accessibility: WCAG 2.1 Level AA compliance for core workflows

**Technical Notes:**
- React 18 with TypeScript
- State management: React Query (TanStack Query) for server state
- Map: Mapbox GL JS or react-leaflet
- UI framework: Tailwind CSS or Ant Design

**Dependencies:** ROE-4 (Backend API)

---

### Story 5: Integration Layer

**Title:** Set up Salesforce sync, Informatica ETL, and Okta SSO integrations
**Key:** ROE-6
**Type:** Story
**Priority:** Medium
**Story Points:** 8
**Labels:** `integration`, `salesforce`, `okta`, `informatica`
**Sprint:** Sprint 3

**Description:**
As a platform engineer, I need to connect the Route Optimization Engine with
enterprise systems (Salesforce, Informatica, Okta) so that data flows
bidirectionally, user authentication is centralized, and analytics data is
available in Snowflake for Looker dashboards.

**Acceptance Criteria:**
- [ ] Salesforce integration syncs work orders bidirectionally:
  - Inbound: work orders from Salesforce to MongoDB (existing sync script)
  - Outbound: route assignments and completion status pushed back to Salesforce
    custom fields
- [ ] Informatica ETL pipeline configured per the design document to load
      analytics data into Snowflake on the defined schedule
- [ ] Snowflake tables match the schema defined in Looker view files
- [ ] Okta OIDC integration configured for staging and production environments
- [ ] SCIM 2.0 user provisioning endpoint receives user create/update/deactivate
      events from Okta
- [ ] Role mapping from Okta groups to application roles is implemented and tested
- [ ] Zone-based access control filters data based on user attributes
- [ ] Integration health checks are exposed via the API health endpoint
- [ ] Runbook documents troubleshooting steps for each integration point

**Technical Notes:**
- Salesforce sync: `integrations/salesforce/sync_work_orders.py`
- Informatica config: `integrations/informatica/pipeline_config.md`
- Okta config: `integrations/okta/auth_config.md`
- Looker model: `looker/models/route_optimization.model.lkml`

**Dependencies:** ROE-2, ROE-4

---

### Story 6: Monitoring & Observability

**Title:** Implement monitoring, logging, alerting, and operational dashboards
**Key:** ROE-7
**Type:** Story
**Priority:** Medium
**Story Points:** 8
**Labels:** `monitoring`, `observability`, `devops`, `looker`
**Sprint:** Sprint 3-4

**Description:**
As an SRE/DevOps engineer, I need comprehensive monitoring and observability for the
Route Optimization Engine so that I can detect issues early, troubleshoot efficiently,
and ensure the system meets its SLA targets.

**Acceptance Criteria:**
- [ ] Structured JSON logging implemented across all services (API, optimization,
      sync jobs) with correlation IDs
- [ ] CloudWatch metrics and alarms configured for:
  - API latency (p50, p95, p99) with alarm at p95 > 2 seconds
  - Optimization job duration with alarm at > 60 seconds
  - Error rate with alarm at > 5% over 5-minute window
  - SQS queue depth with alarm at > 50 messages
  - ECS task health (running count, CPU, memory utilization)
- [ ] CloudWatch dashboards created for operational monitoring
- [ ] Looker dashboard deployed for business-level route efficiency analytics
  - Dashboard definition: `looker/dashboards/route_efficiency.dashboard.lookml`
  - KPI tiles, algorithm comparison, distance trends, utilization by technician
- [ ] PagerDuty integration for critical alerts (P1/P2)
- [ ] Slack integration for informational alerts and deployment notifications
- [ ] API request/response logging with sensitive field masking
- [ ] Database query performance monitoring (slow query alerts > 5 seconds)
- [ ] ETL pipeline monitoring with SLA tracking per the Informatica config
- [ ] Weekly automated report summarizing optimization performance metrics
- [ ] Runbook with common alert response procedures

**Technical Notes:**
- Looker dashboards: `looker/dashboards/route_efficiency.dashboard.lookml`
- CloudFormation includes CloudWatch log groups: `infrastructure/aws/cloudformation.yml`
- Bitbucket pipeline sends Slack notifications on deploy

**Dependencies:** ROE-4, ROE-5, ROE-6

---

## Epic Summary

| Story | Title                        | Points | Priority | Sprint   | Status  |
|-------|------------------------------|--------|----------|----------|---------|
| ROE-2 | Data Pipeline Setup          | 13     | High     | Sprint 1 | To Do   |
| ROE-3 | Core Optimization Engine     | 21     | High     | Sprint 1-2 | To Do |
| ROE-4 | Backend API                  | 13     | High     | Sprint 2 | To Do   |
| ROE-5 | Frontend Dashboard           | 13     | Medium   | Sprint 2-3 | To Do |
| ROE-6 | Integration Layer            | 8      | Medium   | Sprint 3 | To Do   |
| ROE-7 | Monitoring & Observability   | 8      | Medium   | Sprint 3-4 | To Do |

**Total Story Points:** 76
**Estimated Duration:** 4 sprints (8 weeks, assuming 2-week sprints)
**Team Size:** 4-5 engineers (2 backend, 1 frontend, 1 data/ML, 1 DevOps)

---

## Definition of Done

A story is considered done when all of the following are satisfied:

1. All acceptance criteria are met and verified
2. Code is reviewed and approved by at least one peer
3. Unit test coverage meets minimum threshold (80% for backend, 85% for optimization)
4. Integration tests pass in the CI pipeline
5. No critical or high-severity bugs remain open
6. API documentation (OpenAPI spec) is updated for any endpoint changes
7. Deployment pipeline successfully deploys to staging environment
8. Product owner has reviewed and accepted the implementation
9. Monitoring and alerting is configured for new components
10. Technical documentation is updated (inline comments, README if applicable)

---

## Risks and Mitigations

| Risk                                          | Impact | Probability | Mitigation                                                  |
|-----------------------------------------------|--------|-------------|-------------------------------------------------------------|
| Salesforce API rate limits throttle sync       | Medium | Medium      | Implement backoff, use Bulk API for full syncs, cache data  |
| Optimization performance degrades at scale     | High   | Low         | Benchmark early, use Lambda scaling, algorithm time limits   |
| Okta configuration delays from IT             | Medium | Medium      | Start OIDC setup in Sprint 1, use mock auth for development |
| Snowflake schema changes from analytics team  | Medium | Low         | Version schema definitions, automated drift detection       |
| Team unfamiliar with OR-Tools                 | Low    | Medium      | Allocate spike time in Sprint 1, pair programming sessions  |
