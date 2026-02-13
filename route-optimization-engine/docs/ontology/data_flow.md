# Data Flow Architecture - Route Optimization Engine

## End-to-End Data Flow

The Route Optimization Engine orchestrates data movement across multiple systems, from source systems through transformation layers to analytical and operational endpoints.

### High-Level Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              SOURCE SYSTEMS                                              │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐         │
│  │  Salesforce  │    │  CSV Files   │    │ IoT Sensors  │    │  Mobile App  │         │
│  │  (CRM/FSM)   │    │  (Property   │    │ (Telemetry)  │    │ (Technician  │         │
│  │              │    │   Data)      │    │              │    │  Check-ins)  │         │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘    └──────┬───────┘         │
│         │                   │                   │                   │                  │
└─────────┼───────────────────┼───────────────────┼───────────────────┼──────────────────┘
          │                   │                   │                   │
          │                   └───────────┬───────┘                   │
          │                               │                           │
          ▼                               ▼                           ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                           INFORMATICA ETL PIPELINE                                       │
│  ┌────────────────────────────────────────────────────────────────────────────────┐    │
│  │ - Data Extraction (API/SFTP/Streaming)                                          │    │
│  │ - Data Quality Validation                                                       │    │
│  │ - Deduplication & Enrichment                                                    │    │
│  │ - Business Rule Application                                                     │    │
│  └────────────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────┬───────────────────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              SNOWFLAKE DATA WAREHOUSE                                    │
│  ┌───────────────┐      ┌────────────────┐      ┌──────────────────┐                   │
│  │   RAW LAYER   │  →   │ STAGING LAYER  │  →   │ ANALYTICS LAYER  │                   │
│  │ (Bronze/L1)   │      │  (Silver/L2)   │      │   (Gold/L3)      │                   │
│  ├───────────────┤      ├────────────────┤      ├──────────────────┤                   │
│  │ - Raw ingests │      │ - Cleansed     │      │ - DIM_PROPERTY   │                   │
│  │ - No transf.  │      │ - Validated    │      │ - DIM_TECHNICIAN │                   │
│  │ - Timestamped │      │ - Standardized │      │ - FACT_WORK_ORDER│                   │
│  │ - Immutable   │      │ - SCD Type 2   │      │ - FACT_ROUTE     │                   │
│  └───────────────┘      └────────────────┘      │ - FACT_ROUTE_STOP│                   │
│                                                  └──────────────────┘                   │
└─────────────────────────────────────────┬───────────────────────────────────────────────┘
                                          │
                    ┌─────────────────────┴─────────────────────┐
                    │                                           │
                    ▼                                           ▼
    ┌───────────────────────────────────────┐     ┌────────────────────────────┐
    │   PALANTIR FOUNDRY ONTOLOGY           │     │      LOOKER (BI)           │
    │  ┌─────────────────────────────────┐  │     │  ┌──────────────────────┐  │
    │  │ - Property Objects              │  │     │  │ - Executive Dashboard │  │
    │  │ - Technician Objects            │  │     │  │ - Operational Reports │  │
    │  │ - WorkOrder Objects             │  │     │  │ - KPI Monitoring      │  │
    │  │ - Route Objects                 │  │     │  │ - Trend Analysis      │  │
    │  │ - RouteStop Objects             │  │     │  └──────────────────────┘  │
    │  └─────────────────────────────────┘  │     └────────────────────────────┘
    │  ┌─────────────────────────────────┐  │
    │  │ - Ontology Actions (OSDK)       │  │
    │  │ - Real-time Queries             │  │
    │  │ - Graph Traversal               │  │
    │  └─────────────────────────────────┘  │
    └───────────────┬───────────────────────┘
                    │
                    ▼
    ┌───────────────────────────────────────┐
    │   ROUTE OPTIMIZATION ENGINE (API)     │
    │  ┌─────────────────────────────────┐  │
    │  │ - Fetch pending work orders     │  │
    │  │ - Load technician constraints   │  │
    │  │ - Execute OR-Tools VRP solver   │  │
    │  │ - Generate optimized routes     │  │
    │  └─────────────────────────────────┘  │
    └───────────────┬───────────────────────┘
                    │
                    ▼
    ┌───────────────────────────────────────┐
    │         MONGODB (Results)             │
    │  ┌─────────────────────────────────┐  │
    │  │ - Optimization run metadata     │  │
    │  │ - Generated routes (versioned)  │  │
    │  │ - Algorithm performance metrics │  │
    │  │ - Real-time route execution logs│  │
    │  └─────────────────────────────────┘  │
    └───────────────┬───────────────────────┘
                    │
                    │ (Write-back to Snowflake nightly)
                    │
                    ▼
    ┌───────────────────────────────────────┐
    │      REACT DASHBOARD (Frontend)       │
    │  ┌─────────────────────────────────┐  │
    │  │ - Route visualization (maps)    │  │
    │  │ - Technician workload view      │  │
    │  │ - Work order management         │  │
    │  │ - Real-time route tracking      │  │
    │  │ - Manual re-optimization UI     │  │
    │  └─────────────────────────────────┘  │
    └───────────────────────────────────────┘
```

---

## Data Flow Stages

### Stage 1: Source System Integration

**Input**: Raw operational data from multiple systems

**Source Systems**:

1. **Salesforce (CRM/Field Service Management)**
   - Work orders (service requests)
   - Customer property information
   - Technician profiles
   - Service appointments
   - API: Salesforce REST API v56.0
   - Extraction: Real-time webhooks + batch sync every 15 minutes

2. **CSV Files (Property Data)**
   - Building management system exports
   - Third-party property databases
   - Manual data uploads
   - Ingestion: SFTP server monitored every hour
   - Format: Standardized CSV schema with validation

3. **IoT Sensors (Telemetry)**
   - Building access logs (technician check-ins)
   - Equipment status (predictive maintenance triggers)
   - Environmental sensors (urgency indicators)
   - Protocol: MQTT streaming to Kafka topics
   - Volume: ~10K events/minute

4. **Mobile App (Technician Check-ins)**
   - GPS location updates
   - Work order status updates
   - Time tracking (arrival/departure)
   - Route deviation reports
   - API: REST API with JWT authentication
   - Frequency: Real-time event stream

**Data Volume**:
- Salesforce: ~50K work orders/month
- CSV: ~200K property records (monthly refresh)
- IoT: ~14M events/day
- Mobile: ~5K status updates/day

**Challenges**:
- Schema variations across sources
- Data quality issues (missing fields, invalid formats)
- Network latency for real-time feeds
- API rate limits (Salesforce: 100K calls/day)

**Error Handling**:
- Failed API calls retry with exponential backoff (max 5 attempts)
- Malformed records logged to error quarantine table
- Dead letter queue for unprocessable streaming events
- Alerts triggered if error rate exceeds 2%

---

### Stage 2: Informatica ETL Pipeline

**Input**: Raw data from source systems

**Transformation**: Cleansing, validation, enrichment, business rule application

**Output**: Validated data loaded into Snowflake RAW layer

#### ETL Components

**Extraction**:
- **Salesforce Connector**: Uses Bulk API 2.0 for large datasets
- **SFTP File Watcher**: Monitors `/incoming` directory for CSV files
- **Kafka Consumer**: Subscribes to IoT telemetry topics
- **REST API Poller**: Queries mobile app API for updates

**Transformation Logic**:

1. **Data Quality Validation**
   - Null checks on required fields
   - Data type validation (e.g., latitude/longitude ranges)
   - Enum value validation (e.g., work order status)
   - Cross-field validation (e.g., timeWindowEnd > timeWindowStart)
   - Invalid records flagged with error codes and quarantined

2. **Deduplication**
   - Primary key-based deduplication for batch loads
   - Timestamp-based merge for incremental updates
   - Algorithm: MD5 hash on composite key fields
   - Duplicates logged; latest record wins

3. **Data Enrichment**
   - Geocoding: Convert addresses to lat/long (Google Maps API)
   - Zone assignment: Spatial join with service zone polygons
   - Skill inference: Map work order category to required skills
   - Timezone normalization: Convert to UTC

4. **Business Rule Application**
   - Priority scoring: Calculate urgency based on SLA and customer tier
   - Technician availability: Cross-reference with HR system for PTO
   - Cost estimation: Apply labor rates and parts markup
   - Route constraints: Enforce max hours, distance limits

**Workflows**:

- **WF_SALESFORCE_WORK_ORDERS**: Extracts work orders, validates, enriches, loads to RAW.SALESFORCE_WORK_ORDERS
  - Schedule: Every 15 minutes
  - Duration: ~3 minutes (avg)
  - Parallelism: 4 concurrent threads

- **WF_PROPERTY_FILE_INGESTION**: Processes property CSV files, geocodes addresses, loads to RAW.PROPERTY_UPLOADS
  - Schedule: Hourly file scan
  - Duration: ~10 minutes for 200K records
  - Geocoding: Batch requests (100 addresses/call)

- **WF_IOT_TELEMETRY_STREAM**: Real-time processing of IoT events, aggregates to 5-minute windows
  - Schedule: Continuous streaming
  - Throughput: ~200 events/second
  - Latency: <30 seconds end-to-end

- **WF_MOBILE_APP_SYNC**: Polls mobile API for status updates, merges with existing work orders
  - Schedule: Every 5 minutes
  - Duration: <1 minute
  - Error handling: Retry failed status updates on next run

**Target Mappings**:

| Source | Target Snowflake Table | Mapping Type |
|--------|----------------------|--------------|
| Salesforce Work Orders | RAW.SALESFORCE_WORK_ORDERS | Direct load + timestamp |
| Salesforce Properties | RAW.SALESFORCE_PROPERTIES | Direct load + timestamp |
| Salesforce Technicians | RAW.SALESFORCE_TECHNICIANS | Direct load + timestamp |
| CSV Property Files | RAW.PROPERTY_UPLOADS | File metadata + records |
| IoT Events | RAW.IOT_TELEMETRY | Streaming insert (micro-batch) |
| Mobile App Events | RAW.MOBILE_STATUS_UPDATES | Incremental merge |

**Schedule and Monitoring**:

- **Monitoring**: Informatica Monitoring Dashboard
  - Success/failure rates per workflow
  - Record counts and data volumes
  - Processing duration trends
  - Data quality metrics (rejection rates)

- **Alerting**:
  - Workflow failure → PagerDuty to Data Engineering
  - Data quality issues (>2% rejection) → Slack alert
  - Processing time exceeds SLA → Email to team lead
  - Source system connectivity failures → Immediate notification

- **SLAs**:
  - Work order data: Available in Snowflake within 20 minutes of creation
  - Property data: Daily refresh complete by 6:00 AM
  - IoT telemetry: 5-minute latency from event to warehouse
  - Mobile app updates: 10-minute latency

**Performance Optimization**:
- Incremental loads based on `LAST_MODIFIED_DATE` from source
- Partitioned tables in Snowflake RAW layer by date
- Pushdown optimization: SQL transformations executed in Snowflake
- Parallel processing: Multiple workflows run concurrently

---

### Stage 3: Snowflake Data Warehouse

**Input**: Raw data from Informatica ETL

**Transformation**: Multi-layer data architecture (RAW → STAGING → ANALYTICS)

**Output**: Clean, modeled data ready for consumption

#### Layer 1: RAW (Bronze/L1)

**Purpose**: Immutable landing zone for source data

**Characteristics**:
- No transformations applied
- Exact copy of source data with metadata
- Includes ETL batch ID and timestamp
- Retention: 90 days (rolling window)

**Tables**:
- `RAW.SALESFORCE_WORK_ORDERS`
- `RAW.SALESFORCE_PROPERTIES`
- `RAW.SALESFORCE_TECHNICIANS`
- `RAW.PROPERTY_UPLOADS`
- `RAW.IOT_TELEMETRY`
- `RAW.MOBILE_STATUS_UPDATES`

**Sample RAW Table Structure**:
```sql
CREATE TABLE RAW.SALESFORCE_WORK_ORDERS (
  RAW_ID STRING PRIMARY KEY,
  ETL_BATCH_ID STRING NOT NULL,
  ETL_TIMESTAMP TIMESTAMP_NTZ NOT NULL,
  SOURCE_SYSTEM STRING DEFAULT 'SALESFORCE',
  RECORD_JSON VARIANT NOT NULL,  -- Full source record as JSON
  CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

**Data Arrival Frequency**:
- Salesforce tables: Every 15 minutes
- Property uploads: Hourly
- IoT telemetry: Continuous (micro-batches every 1 minute)
- Mobile updates: Every 5 minutes

**Error Handling**:
- Duplicate inserts prevented by unique constraint on RAW_ID
- Schema evolution handled via VARIANT column (JSON)
- Failed loads quarantined in separate error tables

---

#### Layer 2: STAGING (Silver/L2)

**Purpose**: Cleansed, validated, and standardized data

**Characteristics**:
- Data quality rules applied
- Slowly Changing Dimensions (SCD Type 2) for history tracking
- Standardized column names and data types
- Retention: 2 years

**Transformations**:
1. Parse JSON from RAW.RECORD_JSON
2. Cast to proper data types
3. Apply business logic (e.g., status normalization)
4. Implement SCD Type 2 for dimension changes
5. Join with reference data (e.g., skill mappings)

**Tables**:
- `STAGING.WORK_ORDERS`
- `STAGING.PROPERTIES`
- `STAGING.TECHNICIANS`
- `STAGING.TELEMETRY_EVENTS`
- `STAGING.STATUS_UPDATES`

**Sample STAGING Table Structure (SCD Type 2)**:
```sql
CREATE TABLE STAGING.TECHNICIANS (
  TECHNICIAN_SK NUMBER AUTOINCREMENT PRIMARY KEY,  -- Surrogate key
  TECHNICIAN_ID STRING NOT NULL,  -- Natural key
  NAME STRING,
  EMAIL STRING,
  SKILLS ARRAY,
  AVAILABILITY_STATUS STRING,
  EFFECTIVE_DATE TIMESTAMP_NTZ NOT NULL,
  END_DATE TIMESTAMP_NTZ,
  IS_CURRENT BOOLEAN DEFAULT TRUE,
  ETL_BATCH_ID STRING,
  ETL_TIMESTAMP TIMESTAMP_NTZ
);
```

**Processing Schedule**:
- Incremental: Every 30 minutes (micro-batch ELT)
- Full refresh: Weekly on Sunday at 2:00 AM
- SCD Type 2 updates: Detect changes via hash comparison

**Data Quality Checks**:
```sql
-- Example validation: Work orders must have valid property reference
INSERT INTO STAGING.WORK_ORDERS
SELECT ...
FROM RAW.SALESFORCE_WORK_ORDERS raw
WHERE EXISTS (
  SELECT 1 FROM STAGING.PROPERTIES p
  WHERE p.PROPERTY_ID = raw.RECORD_JSON:PropertyId::STRING
  AND p.IS_CURRENT = TRUE
);

-- Invalid records logged to quarantine
INSERT INTO STAGING.DATA_QUALITY_ERRORS
SELECT *, 'INVALID_PROPERTY_REFERENCE' AS ERROR_CODE
FROM RAW.SALESFORCE_WORK_ORDERS raw
WHERE NOT EXISTS (...);
```

---

#### Layer 3: ANALYTICS (Gold/L3)

**Purpose**: Business-ready dimensional model optimized for analytics and ML

**Characteristics**:
- Star schema design
- Dimension tables (DIM_*) and fact tables (FACT_*)
- Pre-aggregated metrics
- Optimized for query performance
- Retention: Indefinite (with archival strategy)

**Tables**:

**Dimension Tables**:
- `ANALYTICS.DIM_PROPERTY`: Property master data
- `ANALYTICS.DIM_TECHNICIAN`: Technician profiles
- `ANALYTICS.DIM_DATE`: Date dimension (calendar attributes)
- `ANALYTICS.DIM_ZONE`: Service zone reference data

**Fact Tables**:
- `ANALYTICS.FACT_WORK_ORDER`: Transactional work order data
- `ANALYTICS.FACT_ROUTE`: Optimized routes
- `ANALYTICS.FACT_ROUTE_STOP`: Individual stops on routes
- `ANALYTICS.FACT_TECHNICIAN_AVAILABILITY`: Daily availability snapshot

**Sample Star Schema**:
```sql
-- Dimension: Property
CREATE TABLE ANALYTICS.DIM_PROPERTY (
  PROPERTY_ID STRING PRIMARY KEY,
  ADDRESS STRING,
  CITY STRING,
  STATE STRING,
  ZIP_CODE STRING,
  LATITUDE FLOAT,
  LONGITUDE FLOAT,
  PROPERTY_TYPE STRING,
  ZONE_ID STRING,
  SQUARE_FOOTAGE NUMBER,
  ACCESS_NOTES STRING,
  CREATED_AT TIMESTAMP_NTZ,
  UPDATED_AT TIMESTAMP_NTZ
);

-- Fact: Work Order
CREATE TABLE ANALYTICS.FACT_WORK_ORDER (
  WORK_ORDER_ID STRING PRIMARY KEY,
  PROPERTY_ID STRING,  -- FK to DIM_PROPERTY
  TITLE STRING,
  CATEGORY STRING,
  PRIORITY STRING,
  REQUIRED_SKILLS ARRAY,
  ESTIMATED_DURATION_MINUTES NUMBER,
  TIME_WINDOW_START TIMESTAMP_NTZ,
  TIME_WINDOW_END TIMESTAMP_NTZ,
  STATUS STRING,
  CREATED_DATE_ID NUMBER,  -- FK to DIM_DATE
  CREATED_AT TIMESTAMP_NTZ,
  UPDATED_AT TIMESTAMP_NTZ,
  
  -- Foreign key constraints
  CONSTRAINT FK_PROPERTY FOREIGN KEY (PROPERTY_ID) 
    REFERENCES ANALYTICS.DIM_PROPERTY(PROPERTY_ID),
  CONSTRAINT FK_CREATED_DATE FOREIGN KEY (CREATED_DATE_ID)
    REFERENCES ANALYTICS.DIM_DATE(DATE_ID)
);
```

**Materialized Views**:
- `ANALYTICS.MV_DAILY_WORK_ORDER_SUMMARY`: Aggregated daily metrics
- `ANALYTICS.MV_TECHNICIAN_UTILIZATION`: Weekly utilization rates
- `ANALYTICS.MV_ROUTE_EFFICIENCY`: Route performance metrics

**Processing Schedule**:
- Incremental: Every 30 minutes (synced with STAGING updates)
- Full refresh: Monthly on 1st at 3:00 AM
- Materialized view refresh: Every 2 hours

**Optimization Techniques**:
- Clustered tables on frequently queried columns (e.g., CREATED_AT)
- Partitioning by date for large fact tables
- Automatic query result caching (24 hours)
- Search optimization service enabled for text columns

---

### Stage 4: Palantir Foundry Ontology Sync

**Input**: ANALYTICS layer tables from Snowflake

**Transformation**: Relational data → Ontology objects and links

**Output**: Foundry Ontology (Property, Technician, WorkOrder, Route, RouteStop objects)

**Sync Mechanism**:

1. **Foundry Data Connection**
   - Connects to Snowflake ANALYTICS schema
   - Uses service account with read-only permissions
   - Encrypted connection (TLS 1.2+)

2. **Dataset Sync**
   - Creates Foundry datasets from Snowflake views
   - Incremental sync based on `UPDATED_AT` timestamp
   - Full sync daily at 4:00 AM UTC

3. **Ontology Mapping**
   - Maps dataset columns to object type properties
   - Derives links from foreign key relationships
   - Validates referential integrity

**Sync Configuration** (detailed in `ontology_model.md`):

| Object Type | Source Table | Sync Frequency | Mode |
|------------|--------------|----------------|------|
| Property | ANALYTICS.DIM_PROPERTY | Every 2 hours | Incremental |
| Technician | ANALYTICS.DIM_TECHNICIAN | Every 1 hour | Incremental |
| WorkOrder | ANALYTICS.FACT_WORK_ORDER | Every 30 minutes | Incremental |
| Route | ANALYTICS.FACT_ROUTE | Every 15 minutes | Incremental |
| RouteStop | ANALYTICS.FACT_ROUTE_STOP | Every 15 minutes | Incremental |

**Data Freshness**:
- Work orders: 30-minute latency from source system to Ontology
- Routes: 15-minute latency after optimization execution
- Properties/Technicians: 1-2 hour latency (acceptable for master data)

**Error Handling**:
- Referential integrity violations logged and quarantined
- Sync failures retry 3 times with exponential backoff
- Alerts sent to Data Engineering on-call if sync fails
- Fallback: Read directly from Snowflake if Ontology unavailable

---

### Stage 5: Route Optimization Engine

**Input**: Pending work orders and technician data from Foundry Ontology (via OSDK)

**Processing**: Vehicle Routing Problem (VRP) solver execution

**Output**: Optimized routes written to MongoDB

**Workflow**:

1. **Trigger**: 
   - Scheduled: Daily at 8:00 PM for next day's routes
   - On-demand: User executes `CreateOptimizationRun` action from UI

2. **Data Fetch** (via OSDK):
   ```typescript
   // Fetch pending work orders for target date
   const workOrders = await foundryClient.objects.WorkOrder.query()
     .where({ 
       status: 'PENDING', 
       timeWindowStart: { $gte: startOfDay, $lt: endOfDay } 
     })
     .execute();
   
   // Fetch available technicians
   const technicians = await foundryClient.objects.Technician.query()
     .where({ availabilityStatus: 'ACTIVE' })
     .execute();
   ```

3. **Optimization Algorithm**:
   - **Solver**: Google OR-Tools (Vehicle Routing Problem with Time Windows)
   - **Objective**: Minimize total travel distance + weighted priority score
   - **Constraints**:
     - Technician max daily hours
     - Technician max daily distance
     - Work order time windows
     - Skill matching requirements
     - Start/end at technician home location
   - **Processing Time**: 30 seconds - 5 minutes (depending on problem size)

4. **Output Generation**:
   - Creates `Route` objects (one per technician)
   - Creates `RouteStop` objects (one per work order, sequenced)
   - Calculates route metrics (total distance, duration, efficiency score)

5. **Data Persistence**:
   - **Primary**: Write to MongoDB (immediate operational use)
   - **Secondary**: Write-back to Snowflake nightly (analytical record)
   - **Tertiary**: Sync to Foundry Ontology (enables action execution)

**MongoDB Collections**:

```javascript
// Collection: optimization_runs
{
  _id: "OPT-RUN-2024-02-14-2030",
  optimizationDate: ISODate("2024-02-15T00:00:00Z"),
  status: "COMPLETED",
  algorithmType: "ORTOOLS_VRP",
  executionTimeMs: 42350,
  numWorkOrders: 87,
  numRoutes: 12,
  totalDistanceMiles: 1024.3,
  createdAt: ISODate("2024-02-14T20:30:00Z"),
  completedAt: ISODate("2024-02-14T20:30:42Z")
}

// Collection: routes
{
  _id: "ROUTE-2024-02-15-TECH001234",
  optimizationRunId: "OPT-RUN-2024-02-14-2030",
  technicianId: "TECH-001234",
  routeDate: ISODate("2024-02-15T00:00:00Z"),
  stops: [
    {
      stopId: "STOP-2024-02-15-001",
      workOrderId: "WO-2024-0056789",
      sequenceNumber: 1,
      arrivalTime: ISODate("2024-02-15T08:15:00Z"),
      departureTime: ISODate("2024-02-15T10:15:00Z"),
      travelDistanceMiles: 12.4,
      travelDurationMinutes: 18
    },
    // ... more stops
  ],
  totalDistanceMiles: 87.3,
  totalDurationMinutes: 465,
  status: "PUBLISHED",
  createdAt: ISODate("2024-02-14T20:30:42Z")
}
```

**Error Handling**:
- Infeasible solutions: Flag problematic work orders, run partial optimization
- Solver timeout: Return best solution found within time limit
- Data fetch failures: Retry with exponential backoff, fallback to Snowflake direct query

---

### Stage 6: Write-Back to Snowflake

**Input**: Optimized routes from MongoDB

**Transformation**: MongoDB documents → Snowflake relational tables

**Output**: ANALYTICS.FACT_ROUTE and ANALYTICS.FACT_ROUTE_STOP populated

**Schedule**: Daily at 11:00 PM (after optimization runs complete)

**Process**:
1. MongoDB aggregation pipeline extracts routes and stops
2. Python script formats data for Snowflake COPY INTO
3. Writes to stage: `@ANALYTICS.STAGES.MONGO_ROUTES`
4. Executes COPY INTO with MERGE logic (upsert)
5. Updates route status in Foundry Ontology via OSDK

**Code Example**:
```python
import pymongo
from snowflake.connector import connect

# Extract from MongoDB
mongo_client = pymongo.MongoClient(mongo_uri)
routes = mongo_client.routes.find({'routeDate': target_date})

# Transform to Snowflake format
route_records = [
    (r['_id'], r['optimizationRunId'], r['technicianId'], 
     r['routeDate'], r['totalDistanceMiles'], r['status'])
    for r in routes
]

# Load to Snowflake
sf_conn = connect(user='ETL_USER', account='company.snowflake')
cursor = sf_conn.cursor()
cursor.executemany("""
  MERGE INTO ANALYTICS.FACT_ROUTE tgt
  USING (SELECT %s, %s, %s, %s, %s, %s) src
  ON tgt.ROUTE_ID = src.ROUTE_ID
  WHEN MATCHED THEN UPDATE SET ...
  WHEN NOT MATCHED THEN INSERT ...
""", route_records)
```

**Data Volume**: ~500 routes/day with ~3,000 stops

**Latency**: Routes available in Snowflake within 30 minutes of optimization completion

---

### Stage 7: Business Intelligence (Looker)

**Input**: ANALYTICS layer tables from Snowflake

**Transformation**: SQL queries → BI dashboards and reports

**Output**: Executive dashboards, operational reports, KPI monitoring

**Looker Models**:

- **Model: Route Optimization**
  - Explores: Work Orders, Routes, Technicians, Properties
  - Dimensions: Date, Zone, Technician, Work Order Category
  - Measures: Total Distance, Avg Route Duration, Work Order Completion Rate

**Key Dashboards**:

1. **Executive Overview**
   - KPIs: Daily routes completed, avg efficiency score, SLA adherence
   - Visualizations: Trend lines, heatmaps, gauge charts
   - Refresh: Every 1 hour

2. **Operational Dashboard**
   - Technician utilization by day
   - Route performance metrics (distance, duration, stops)
   - Work order aging report
   - Refresh: Every 30 minutes

3. **Geographic Analysis**
   - Map visualization of properties and routes
   - Zone-level aggregations
   - Drive time heatmaps
   - Refresh: Daily

**Data Refresh**:
- Scheduled cache refresh: Every 2 hours
- On-demand refresh available for users
- Real-time queries for small datasets (<10K rows)

**Performance**:
- Dashboard load time: <3 seconds (p95)
- Query execution: <10 seconds (p95)
- Optimized via Snowflake query result caching

---

### Stage 8: React Dashboard (Frontend)

**Input**: 
- Real-time routes from MongoDB (via Backend API)
- Ontology objects from Foundry (via OSDK)
- Work order updates from Backend API

**Transformation**: API responses → Interactive UI components

**Output**: User-facing web application for route management

**Features**:

1. **Route Visualization**
   - Google Maps integration showing route paths
   - Color-coded stops by status (pending, in-progress, completed)
   - Real-time technician location tracking
   - Data source: MongoDB via Backend API (WebSocket for real-time)

2. **Technician Workload View**
   - Calendar view of assigned routes
   - Daily schedule with work orders
   - Time/distance summaries
   - Data source: Foundry Ontology via OSDK

3. **Work Order Management**
   - List view with filters (status, priority, zone)
   - Drag-and-drop manual assignment
   - Bulk actions (assign, reassign, cancel)
   - Data source: Foundry Ontology via OSDK

4. **Manual Re-Optimization**
   - Trigger `ReoptimizeRoute` action
   - Preview optimized vs current route
   - Accept/reject optimization suggestions
   - Data source: Foundry Ontology actions via OSDK

**Data Flow**:
```
React Dashboard → Backend API → MongoDB (read routes)
                               ↓
                             OSDK → Foundry Ontology (read work orders, execute actions)
                               ↓
                           MongoDB ← Optimization Engine (write routes)
                               ↓
                           Snowflake ← Nightly write-back
```

**Performance**:
- Page load time: <2 seconds
- API response time: <500ms (p95)
- WebSocket latency: <1 second for real-time updates

**Caching Strategy**:
- Route data: 5-minute client-side cache
- Work order list: 2-minute cache with stale-while-revalidate
- Technician profiles: 1-hour cache (infrequent changes)

---

## Change Data Capture (CDC)

### CDC Architecture

**Purpose**: Propagate data changes in near real-time from source systems through the entire pipeline

**Implementation**:

1. **Salesforce CDC**
   - **Mechanism**: Salesforce Change Data Capture API
   - **Events**: Work order created/updated, technician profile changed
   - **Delivery**: Pub/Sub events to AWS EventBridge
   - **Latency**: <1 minute from source change to event delivery
   
   **Event Processing**:
   ```
   Salesforce Change → EventBridge → Lambda Function → Informatica REST Endpoint → RAW Layer
   ```

2. **Snowflake Streams**
   - **Mechanism**: Snowflake Streams on RAW and STAGING tables
   - **Purpose**: Track inserts/updates/deletes for incremental processing
   - **Consumption**: Scheduled tasks read stream and process changes
   
   **Example Stream**:
   ```sql
   CREATE STREAM STAGING.WORK_ORDER_STREAM 
   ON TABLE STAGING.WORK_ORDERS;
   
   -- Task to process stream
   CREATE TASK ANALYTICS.PROCESS_WORK_ORDER_CHANGES
   WAREHOUSE = ANALYTICS_WH
   SCHEDULE = '5 MINUTE'
   WHEN SYSTEM$STREAM_HAS_DATA('STAGING.WORK_ORDER_STREAM')
   AS
   MERGE INTO ANALYTICS.FACT_WORK_ORDER tgt
   USING STAGING.WORK_ORDER_STREAM src
   ON tgt.WORK_ORDER_ID = src.WORK_ORDER_ID
   WHEN MATCHED AND src.METADATA$ACTION = 'INSERT' OR src.METADATA$ACTION = 'UPDATE' THEN
     UPDATE SET ...
   WHEN NOT MATCHED AND src.METADATA$ACTION = 'INSERT' THEN
     INSERT ...;
   ```

3. **Foundry Incremental Sync**
   - **Mechanism**: Query-based incremental sync using `UPDATED_AT` filter
   - **Trigger**: Scheduled sync jobs every 15-30 minutes
   - **Optimization**: Only fetches changed records since last sync
   
   **Sync Query**:
   ```sql
   SELECT * FROM ANALYTICS.FACT_WORK_ORDER
   WHERE UPDATED_AT > :lastSyncTimestamp
   ORDER BY UPDATED_AT ASC;
   ```

4. **MongoDB Change Streams**
   - **Mechanism**: MongoDB Change Streams on `routes` collection
   - **Purpose**: Real-time notifications to React dashboard
   - **Delivery**: WebSocket push to connected clients
   
   **Change Stream Consumer**:
   ```javascript
   const changeStream = db.collection('routes').watch();
   changeStream.on('change', (change) => {
     if (change.operationType === 'update') {
       // Notify dashboard via WebSocket
       io.to(change.documentKey._id).emit('routeUpdated', change.fullDocument);
     }
   });
   ```

### CDC Data Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                   Change Data Capture Flow                        │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Work Order Created in Salesforce                                │
│         │                                                         │
│         ▼                                                         │
│  Salesforce CDC Event (< 1 min)                                  │
│         │                                                         │
│         ▼                                                         │
│  AWS EventBridge → Lambda → Informatica                          │
│         │                                                         │
│         ▼                                                         │
│  Snowflake RAW Layer (< 5 min)                                   │
│         │                                                         │
│         ▼                                                         │
│  Snowflake Stream Detects Change                                 │
│         │                                                         │
│         ▼                                                         │
│  Scheduled Task Processes Stream (every 5 min)                   │
│         │                                                         │
│         ▼                                                         │
│  Snowflake STAGING → ANALYTICS (< 10 min)                        │
│         │                                                         │
│         ├──────────────────┬─────────────────┐                   │
│         ▼                  ▼                 ▼                    │
│  Foundry Sync      Looker Cache      Backend API                 │
│  (every 30 min)    (every 2 hr)      (on-demand query)           │
│         │                  │                 │                    │
│         ▼                  ▼                 ▼                    │
│  Ontology Object   BI Dashboard     React Dashboard              │
│  (< 35 min)        (< 2.5 hr)       (< 15 min)                   │
│         │                                    │                    │
│         ▼                                    │                    │
│  OSDK Actions                                │                    │
│  (Optimization)                              │                    │
│         │                                    │                    │
│         ▼                                    │                    │
│  MongoDB (routes updated)                    │                    │
│         │                                    │                    │
│         ▼                                    │                    │
│  Change Stream Event ─────────────────────────┘                  │
│         │                                                         │
│         ▼                                                         │
│  WebSocket Push to Dashboard (< 1 sec)                           │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### End-to-End Latency

**Scenario: New Work Order Created in Salesforce**

| Stage | System | Latency | Cumulative |
|-------|--------|---------|-----------|
| 1. Work order created | Salesforce | 0 min | 0 min |
| 2. CDC event published | EventBridge | 1 min | 1 min |
| 3. Event processing | Lambda + Informatica | 2 min | 3 min |
| 4. RAW layer insert | Snowflake | 1 min | 4 min |
| 5. Stream processing | Snowflake Task | 5 min | 9 min |
| 6. ANALYTICS layer update | Snowflake | 1 min | 10 min |
| 7. Foundry incremental sync | Foundry | 30 min | 40 min |
| 8. Available in Ontology | Foundry | 0 min | 40 min |
| 9. Dashboard query | React via API | 1 min | 41 min |

**Total End-to-End Latency**: ~40 minutes from creation to dashboard visibility

**Real-Time Path** (for urgent updates):
- Mobile app status update → Backend API → MongoDB → WebSocket → Dashboard: <10 seconds

---

## Data Quality and Validation

### Data Quality Checks at Each Stage

**Stage 1: Source Systems**
- Schema validation on API responses
- Required field presence checks
- Data type validation

**Stage 2: Informatica ETL**
- Null checks on required fields
- Range validation (lat/long, dates, numeric constraints)
- Enum value validation
- Referential integrity checks
- Deduplication logic

**Stage 3: Snowflake RAW**
- Primary key uniqueness
- ETL batch tracking
- Data lineage metadata

**Stage 4: Snowflake STAGING**
- SCD Type 2 consistency
- Cross-field validation (e.g., end date > start date)
- Business rule validation

**Stage 5: Snowflake ANALYTICS**
- Dimensional model integrity (orphan fact checks)
- Aggregate reconciliation
- Historical consistency validation

**Stage 6: Foundry Ontology**
- Foreign key validation (Property ID exists for Work Order)
- Enum value validation
- Required property checks

**Stage 7: Optimization Engine**
- Input data completeness (all required fields present)
- Constraint feasibility (solvable problem)
- Output validation (routes don't violate constraints)

### Data Quality Metrics

**Tracked Metrics**:
- Null rate per column
- Duplicate rate
- Referential integrity violation rate
- Schema compliance rate
- Timeliness (data freshness)

**Monitoring Dashboard**: Snowflake + Tableau dashboard tracking DQ metrics

**Alerting Thresholds**:
- Null rate > 5% in required fields → Alert
- Duplicate rate > 1% → Alert
- Referential integrity violations > 0.1% → Alert
- Data staleness > 2 hours (for real-time sources) → Alert

---

## Disaster Recovery and Data Lineage

### Disaster Recovery

**Snowflake**:
- Daily snapshots (Time Travel enabled for 90 days)
- Failover to secondary region (us-west-2) with 15-minute RPO
- RTO: <1 hour for full failover

**MongoDB**:
- Replica set with 3 nodes across availability zones
- Point-in-time backups every 6 hours
- RTO: <30 minutes, RPO: <6 hours

**Foundry**:
- Foundry platform-level redundancy (managed by Palantir)
- Dataset versioning (rollback to previous builds)
- RTO: <15 minutes, RPO: <1 hour

### Data Lineage

**Lineage Tracking**:
- ETL batch IDs propagated through all layers
- Snowflake METADATA columns track source and transformation
- Foundry dataset build history
- MongoDB documents include `optimizationRunId` referencing upstream data

**Lineage Query Example**:
```sql
-- Trace work order from source to analytics
SELECT 
  raw.ETL_BATCH_ID,
  raw.ETL_TIMESTAMP,
  raw.SOURCE_SYSTEM,
  staging.EFFECTIVE_DATE,
  analytics.CREATED_AT,
  analytics.WORK_ORDER_ID
FROM RAW.SALESFORCE_WORK_ORDERS raw
JOIN STAGING.WORK_ORDERS staging 
  ON raw.RECORD_JSON:Id::STRING = staging.WORK_ORDER_ID
JOIN ANALYTICS.FACT_WORK_ORDER analytics
  ON staging.WORK_ORDER_ID = analytics.WORK_ORDER_ID
WHERE analytics.WORK_ORDER_ID = 'WO-2024-0056789';
```

---

## Performance Benchmarks

### Data Volume and Processing Times

| Pipeline Stage | Daily Volume | Processing Time | SLA |
|----------------|--------------|-----------------|-----|
| Informatica ETL (Salesforce) | 50K work orders | 15 min | 30 min |
| Informatica ETL (CSV) | 200K properties | 10 min | 1 hour |
| Informatica ETL (IoT) | 14M events | Continuous | 5 min latency |
| Snowflake RAW → STAGING | 300K records | 5 min | 15 min |
| Snowflake STAGING → ANALYTICS | 300K records | 5 min | 15 min |
| Foundry Ontology Sync | 50K objects | 10 min | 30 min |
| Route Optimization | 100 work orders | 2 min | 10 min |
| MongoDB Write-back to Snowflake | 500 routes | 5 min | 15 min |

### Query Performance

| Query Type | Dataset Size | Execution Time (p95) | Optimization |
|------------|--------------|---------------------|--------------|
| Single work order lookup | N/A | <100 ms | Primary key index |
| Work orders by date range | 10K rows | <2 seconds | Clustered on date |
| Technician route history | 100 routes | <1 second | FK index |
| Route efficiency report | 1M stops | <10 seconds | Materialized view |
| Geographic aggregation | 200K properties | <5 seconds | Spatial index |

---

## Future Enhancements

**Planned Improvements**:

1. **Real-Time Optimization**:
   - Move from batch (nightly) to event-driven optimization
   - Trigger re-optimization on work order creation/cancellation
   - Target latency: <5 minutes from work order to route assignment

2. **Enhanced CDC**:
   - Implement Debezium for MySQL/PostgreSQL sources
   - Real-time Kafka streaming for all source systems
   - Event-driven data quality validation

3. **Machine Learning Integration**:
   - Predictive work order duration (ML model in Snowflake)
   - Technician skill recommendation
   - Route efficiency scoring

4. **Data Catalog**:
   - Implement data catalog (Alation or Collibra)
   - Automated data lineage visualization
   - Business glossary for self-service analytics

5. **Multi-Region Support**:
   - Expand to EU and APAC regions
   - Region-specific Snowflake instances
   - Cross-region data replication for global reporting

---

## Appendix: Technology Stack

**Data Integration**:
- Informatica PowerCenter 10.5
- AWS EventBridge
- AWS Lambda (Python 3.11)

**Data Warehouse**:
- Snowflake Enterprise Edition
- Warehouse size: X-Large (analytics), Medium (ETL)

**Ontology Platform**:
- Palantir Foundry (SaaS)
- OSDK (TypeScript SDK v2.0)

**Optimization**:
- Google OR-Tools 9.5
- Python 3.11
- Docker containers (AWS ECS)

**Operational Database**:
- MongoDB 6.0 (Atlas managed)
- Replica set: 3 nodes

**Business Intelligence**:
- Looker (Google Cloud)
- Tableau (for ad-hoc analysis)

**Frontend**:
- React 18
- TypeScript 5.0
- WebSocket (Socket.io)
- Google Maps API

**Orchestration**:
- Snowflake Tasks
- AWS Step Functions
- Foundry Pipeline Builder

**Monitoring**:
- DataDog (infrastructure and APM)
- PagerDuty (alerting)
- Slack (notifications)
