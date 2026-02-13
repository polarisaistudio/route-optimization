# Informatica ETL Pipeline Configuration
## Route Optimization Engine - Data Integration

### Overview

This document describes the Informatica Intelligent Cloud Services (IICS) ETL pipeline
design for the Route Optimization Engine. The pipeline extracts operational data from
source systems (Salesforce, MongoDB, internal APIs), transforms it into the analytics
schema, and loads it into the Snowflake data warehouse for Looker consumption.

---

### Pipeline Architecture

```
Source Systems              Informatica IICS              Target
+----------------+     +----------------------+     +------------------+
| Salesforce     |---->|                      |---->| Snowflake        |
| (WorkOrders)   |     |  Mapping Task:       |     | FIELD_SERVICE_OPS|
+----------------+     |  m_work_orders       |     |   .ANALYTICS     |
                        |                      |     |   .FACT_WORK_    |
+----------------+     |  Mapping Task:       |     |    ORDER         |
| MongoDB        |---->|  m_routes            |---->|   .FACT_ROUTE    |
| (Routes, Stops)|     |                      |     |   .FACT_ROUTE_   |
+----------------+     |  Mapping Task:       |     |    STOP          |
                        |  m_technicians       |---->|   .DIM_TECHNICIAN|
+----------------+     |                      |     |   .DIM_PROPERTY  |
| Property API   |---->|  Mapping Task:       |     +------------------+
|                |     |  m_properties         |
+----------------+     +----------------------+
```

---

### Source-to-Target Mapping

#### Mapping Task: m_work_orders

**Source:** Salesforce WorkOrder + WorkOrderLineItem objects
**Target:** `FIELD_SERVICE_OPS.ANALYTICS.FACT_WORK_ORDER`

| Source Field (Salesforce)   | Transformation           | Target Column               | Data Type     | Notes                           |
|-----------------------------|--------------------------|------------------------------|---------------|----------------------------------|
| WorkOrder.Id                | Direct map               | SALESFORCE_ID                | VARCHAR(18)   | Salesforce record ID             |
| WorkOrder.WorkOrderNumber   | Direct map               | WORK_ORDER_NUMBER            | VARCHAR(20)   | Human-readable identifier        |
| Sequence generator          | Auto-increment           | WORK_ORDER_ID                | VARCHAR(36)   | Internal UUID primary key        |
| WorkOrder.Subject           | Direct map               | SUBJECT                      | VARCHAR(255)  |                                  |
| WorkOrder.Status            | Lookup: STATUS_MAP       | STATUS                       | VARCHAR(20)   | Map SF statuses to internal enum |
| WorkOrder.Priority          | Lookup: PRIORITY_MAP     | PRIORITY                     | VARCHAR(10)   | critical/high/medium/low         |
| WorkType.Name               | Lookup via WorkTypeId    | CATEGORY                     | VARCHAR(50)   | inspection/maintenance/repair    |
| WorkOrder.Duration          | Convert to minutes       | ESTIMATED_DURATION_MIN       | NUMBER(10,2)  | Apply DurationType conversion    |
| WorkOrder.StartDate         | Timezone conversion      | TIME_WINDOW_START            | TIMESTAMP_NTZ |                                  |
| WorkOrder.EndDate           | Timezone conversion      | TIME_WINDOW_END              | TIMESTAMP_NTZ |                                  |
| WorkOrder.CreatedDate       | Timezone conversion      | CREATED_AT                   | TIMESTAMP_NTZ |                                  |
| WorkOrder.Latitude          | Direct map               | LATITUDE                     | NUMBER(10,7)  |                                  |
| WorkOrder.Longitude         | Direct map               | LONGITUDE                    | NUMBER(11,7)  |                                  |
| Lookup from route assignment| FK lookup                | ROUTE_ID                     | VARCHAR(36)   | Joined from route assignments    |
| Lookup from route assignment| FK lookup                | TECHNICIAN_ID                | VARCHAR(36)   | Joined from route assignments    |
| Property matching           | Geo-match or address     | PROPERTY_ID                  | VARCHAR(36)   | Matched via address/coordinates  |
| WorkOrderLineItem.Skills    | Aggregate skills list    | REQUIRED_SKILLS              | VARCHAR(500)  | Comma-separated skill list       |

**Status Mapping Lookup (STATUS_MAP):**

| Salesforce Status | Internal Status |
|-------------------|-----------------|
| New               | pending         |
| In Progress       | in_progress     |
| On Hold           | deferred        |
| Completed         | completed       |
| Closed            | completed       |
| Canceled          | cancelled       |
| Cannot Complete   | cancelled       |

**Priority Mapping Lookup (PRIORITY_MAP):**

| Salesforce Priority | Internal Priority |
|---------------------|-------------------|
| Critical            | critical          |
| High                | high              |
| Medium              | medium            |
| Low                 | low               |
| (null)              | medium            |

---

#### Mapping Task: m_routes

**Source:** MongoDB `routes` collection
**Target:** `FIELD_SERVICE_OPS.ANALYTICS.FACT_ROUTE`

| Source Field (MongoDB)       | Transformation          | Target Column           | Data Type     | Notes                          |
|------------------------------|-------------------------|--------------------------|---------------|--------------------------------|
| _id                          | ObjectId to string      | ROUTE_ID                 | VARCHAR(36)   | Primary key                    |
| technician_id                | FK lookup               | TECHNICIAN_ID            | VARCHAR(36)   |                                |
| route_date                   | Date parse              | ROUTE_DATE               | DATE          |                                |
| algorithm                    | Direct map              | ALGORITHM_USED           | VARCHAR(30)   |                                |
| status                       | Direct map              | STATUS                   | VARCHAR(20)   |                                |
| total_distance_km            | Round to 1 decimal      | TOTAL_DISTANCE_KM        | NUMBER(10,1)  |                                |
| total_duration_min           | Round to integer        | TOTAL_DURATION_MIN       | NUMBER(10,0)  |                                |
| stops.length                 | Array count             | NUM_STOPS                | NUMBER(5,0)   |                                |
| utilization                  | Multiply by 100         | UTILIZATION_PCT          | NUMBER(5,2)   | Stored as 0.0-1.0 in source   |
| optimization_score           | Direct map              | OPTIMIZATION_SCORE       | NUMBER(5,1)   |                                |
| zone_id                      | Direct map              | ZONE_ID                  | VARCHAR(20)   |                                |
| updated_at                   | Timezone conversion     | UPDATED_AT               | TIMESTAMP_NTZ |                                |

---

#### Mapping Task: m_technicians

**Source:** MongoDB `technicians` collection
**Target:** `FIELD_SERVICE_OPS.ANALYTICS.DIM_TECHNICIAN`

| Source Field (MongoDB)    | Transformation         | Target Column            | Data Type     |
|---------------------------|------------------------|---------------------------|---------------|
| _id                       | ObjectId to string     | TECHNICIAN_ID             | VARCHAR(36)   |
| name                      | Direct map             | TECHNICIAN_NAME           | VARCHAR(100)  |
| email                     | Direct map             | EMAIL                     | VARCHAR(255)  |
| phone                     | Direct map             | PHONE                     | VARCHAR(20)   |
| skills                    | Array join with comma  | SKILLS                    | VARCHAR(500)  |
| max_daily_hours           | Direct map             | MAX_DAILY_HOURS           | NUMBER(4,1)   |
| hourly_rate               | Direct map             | HOURLY_RATE               | NUMBER(8,2)   |
| availability_status       | Direct map             | AVAILABILITY_STATUS       | VARCHAR(20)   |
| home_zone_id              | Direct map             | HOME_ZONE_ID              | VARCHAR(20)   |
| hire_date                 | Date parse             | HIRE_DATE                 | DATE          |

---

#### Mapping Task: m_properties

**Source:** Property Management API (REST)
**Target:** `FIELD_SERVICE_OPS.ANALYTICS.DIM_PROPERTY`

| Source Field (API)    | Transformation         | Target Column          | Data Type     |
|-----------------------|------------------------|-------------------------|---------------|
| id                    | Direct map             | PROPERTY_ID             | VARCHAR(36)   |
| address.street        | Direct map             | ADDRESS                 | VARCHAR(255)  |
| address.city          | Direct map             | CITY                    | VARCHAR(100)  |
| address.state         | Direct map             | STATE                   | VARCHAR(50)   |
| address.zip           | Direct map             | ZIP_CODE                | VARCHAR(10)   |
| type                  | Direct map             | PROPERTY_TYPE           | VARCHAR(30)   |
| subtype               | Direct map             | PROPERTY_SUBTYPE        | VARCHAR(50)   |
| zone_id               | Direct map             | ZONE_ID                 | VARCHAR(20)   |
| coordinates.lat       | Direct map             | LATITUDE                | NUMBER(10,7)  |
| coordinates.lng       | Direct map             | LONGITUDE               | NUMBER(11,7)  |
| square_footage        | Direct map             | SQUARE_FOOTAGE          | NUMBER(10,0)  |
| year_built            | Direct map             | YEAR_BUILT              | NUMBER(4,0)   |
| access.gate_code      | Direct map             | GATE_CODE               | VARCHAR(20)   |
| access.instructions   | Direct map             | ACCESS_INSTRUCTIONS     | VARCHAR(500)  |

---

### Transformation Rules

#### Global Transformations

1. **Timestamp normalization**: All timestamps are converted to UTC (TIMESTAMP_NTZ in Snowflake). Source timezone offsets are stripped after conversion.

2. **Null handling**: NULL values in required fields trigger a reject to the error table. NULL values in optional fields are passed through as-is.

3. **String trimming**: All VARCHAR fields are trimmed of leading and trailing whitespace.

4. **Deduplication**: Records with duplicate primary keys within the same batch are deduplicated, keeping the record with the latest modification timestamp.

5. **Surrogate key generation**: Internal IDs (WORK_ORDER_ID, ROUTE_ID, etc.) are generated as UUIDs when inserting new records. Existing records retain their assigned keys during updates.

#### Specific Transformation Rules

- **Duration conversion**: Salesforce Duration field is converted based on DurationType:
  - If DurationType = 'Hours', multiply by 60 to get minutes
  - If DurationType = 'Minutes', use as-is
  - If DurationType is NULL, assume minutes

- **Skills aggregation**: Individual skill records are aggregated into a comma-separated string and deduplicated (e.g., "plumbing,electrical,HVAC")

- **Utilization calculation**: Stored as a decimal (0.0-1.0) in MongoDB but loaded as a percentage (0-100) into Snowflake

- **Address standardization**: Street addresses are standardized using USPS address normalization rules (city name casing, state abbreviation, ZIP+4)

---

### Schedule Configuration

| Pipeline             | Schedule              | Trigger                        | Estimated Duration |
|----------------------|-----------------------|--------------------------------|--------------------|
| m_work_orders        | Every 15 minutes      | Cron: */15 * * * *             | 2-5 minutes        |
| m_routes             | Every 30 minutes      | Cron: */30 * * * *             | 3-8 minutes        |
| m_technicians        | Daily at 05:00 UTC    | Cron: 0 5 * * *                | 1-2 minutes        |
| m_properties         | Daily at 05:30 UTC    | Cron: 30 5 * * *               | 2-4 minutes        |
| Full refresh (all)   | Weekly Sunday 02:00   | Cron: 0 2 * * 0                | 30-60 minutes      |

**Dependency Chain:**
- `m_technicians` and `m_properties` must complete before `m_routes` (dimension tables loaded first)
- `m_routes` must complete before `m_work_orders` (route IDs needed for FK lookup)

**Incremental Logic:**
- All incremental pipelines use a high-watermark strategy based on `LastModifiedDate` (Salesforce) or `updated_at` (MongoDB)
- The watermark is stored in the Informatica persistent cache and Snowflake control table `FIELD_SERVICE_OPS.ETL.PIPELINE_WATERMARKS`

---

### Error Handling and Data Quality Rules

#### Error Classification

| Error Type          | Handling                                           | Retry Policy              |
|---------------------|----------------------------------------------------|---------------------------|
| Source unavailable   | Retry with exponential backoff, alert after 3 fails | 3 retries, 5-min backoff  |
| Authentication fail  | Alert immediately, halt pipeline                    | No auto-retry             |
| Schema mismatch      | Log to error table, skip record, alert              | No auto-retry             |
| Data type violation  | Log to error table, skip record                     | No auto-retry             |
| Duplicate key        | Upsert (update existing record)                     | N/A                       |
| Network timeout      | Retry with backoff                                  | 5 retries, 2-min backoff  |
| Target load failure  | Retry entire batch                                  | 3 retries, 1-min backoff  |

#### Data Quality Rules

| Rule ID | Rule Description                                   | Action on Violation    | Applies To              |
|---------|-----------------------------------------------------|------------------------|-------------------------|
| DQ-001  | WORK_ORDER_ID must not be null                       | Reject record          | FACT_WORK_ORDER         |
| DQ-002  | ROUTE_DATE must be within last 2 years               | Reject record          | FACT_ROUTE              |
| DQ-003  | LATITUDE must be between -90 and 90                  | Reject record          | DIM_PROPERTY            |
| DQ-004  | LONGITUDE must be between -180 and 180               | Reject record          | DIM_PROPERTY            |
| DQ-005  | ESTIMATED_DURATION_MIN must be > 0 and < 1440        | Set to NULL, flag      | FACT_WORK_ORDER         |
| DQ-006  | PRIORITY must be in (critical, high, medium, low)    | Default to 'medium'    | FACT_WORK_ORDER         |
| DQ-007  | HOURLY_RATE must be > 0 and < 500                    | Reject record          | DIM_TECHNICIAN          |
| DQ-008  | TOTAL_DISTANCE_KM must be >= 0                       | Set to 0, flag         | FACT_ROUTE              |
| DQ-009  | NUM_STOPS must be >= 0 and <= 50                     | Reject record          | FACT_ROUTE              |
| DQ-010  | Email format validation                              | Set to NULL, flag      | DIM_TECHNICIAN          |

**Error Tables:**
- `FIELD_SERVICE_OPS.ETL.ERROR_LOG` - Central error log for all pipeline runs
- `FIELD_SERVICE_OPS.ETL.REJECTED_RECORDS` - Records that failed data quality checks

---

### Monitoring and Alerting Setup

#### Monitoring Dashboards

The pipeline health is monitored through the Informatica Monitor console and a supplementary Snowflake-based monitoring view:

```sql
-- Pipeline execution summary view
CREATE OR REPLACE VIEW FIELD_SERVICE_OPS.ETL.V_PIPELINE_HEALTH AS
SELECT
    pipeline_name,
    execution_date,
    status,
    records_processed,
    records_rejected,
    duration_seconds,
    CASE
        WHEN records_rejected > records_processed * 0.05 THEN 'WARNING'
        WHEN status = 'FAILED' THEN 'CRITICAL'
        ELSE 'HEALTHY'
    END AS health_status
FROM FIELD_SERVICE_OPS.ETL.PIPELINE_EXECUTION_LOG
WHERE execution_date >= DATEADD('day', -7, CURRENT_DATE());
```

#### Alert Configuration

| Alert                              | Condition                                     | Channel          | Severity |
|------------------------------------|-----------------------------------------------|-------------------|----------|
| Pipeline failure                   | Any pipeline run status = FAILED               | PagerDuty + Slack | P2       |
| High reject rate                   | Rejected records > 5% of processed             | Slack #data-alerts | P3       |
| Pipeline SLA breach                | Duration exceeds 3x historical average          | Slack #data-alerts | P3       |
| Source connectivity failure        | 3 consecutive connection failures               | PagerDuty         | P2       |
| No data received                   | 0 records fetched for 2+ consecutive runs       | Slack #data-alerts | P3       |
| Schema drift detected              | New/missing columns in source                   | Slack #data-eng   | P3       |
| Full refresh overdue               | Weekly full refresh not completed in 7+ days    | Slack #data-alerts | P4       |

#### Notification Channels

- **PagerDuty**: `route-optimization-data-pipeline` service, on-call rotation
- **Slack**: `#route-opt-data-alerts` channel
- **Email**: `data-engineering@polaris.com` for weekly summary reports

#### SLA Targets

| Metric                            | Target            | Measurement Window |
|-----------------------------------|-------------------|--------------------|
| Pipeline availability             | 99.5%             | Monthly            |
| Data freshness (work orders)      | < 20 minutes      | Continuous         |
| Data freshness (routes)           | < 45 minutes      | Continuous         |
| Data freshness (dimensions)       | < 24 hours        | Daily              |
| Error rate                        | < 1% of records   | Per pipeline run   |
| End-to-end latency (source to DW) | < 30 minutes      | 95th percentile    |
