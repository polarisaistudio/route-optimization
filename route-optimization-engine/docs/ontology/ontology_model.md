# Palantir Foundry Ontology Model - Route Optimization Engine

## Overview

The Route Optimization Engine leverages Palantir Foundry's Ontology framework to create a semantic layer that models field service operations in the real estate domain. The Ontology provides a business-friendly abstraction over raw data stored in Snowflake, enabling business users and analysts to interact with operational data through intuitive objects, relationships, and actions.

By modeling field service entities as Ontology objects, the system achieves:

- **Semantic Consistency**: A unified business vocabulary across all applications and reports
- **Data Lineage**: Clear traceability from source systems through transformations to analytical outputs
- **Action-Oriented Workflows**: Business processes encoded as executable Ontology Actions
- **Real-Time Integration**: Bidirectional sync between operational databases and the analytical platform
- **Type Safety**: Strongly-typed object schemas that enforce data quality at the platform level

The Ontology serves as the single source of truth for route optimization operations, integrating data from multiple source systems (Salesforce, IoT devices, work order management systems) and making it available for optimization algorithms, dashboards, and business intelligence tools.

## Object Types

### Property

Represents a physical real estate property that requires field service maintenance and visits.

**Primary Key**: `propertyId` (String)

**Properties**:

| Property Name | Data Type | Required | Description | Example |
|--------------|-----------|----------|-------------|---------|
| propertyId | String | Yes | Unique identifier for the property | "PROP-2024-0001234" |
| address | String | Yes | Street address of the property | "123 Main Street" |
| city | String | Yes | City name | "San Francisco" |
| state | String | Yes | State abbreviation | "CA" |
| zipCode | String | Yes | ZIP or postal code | "94105" |
| latitude | Double | Yes | Geographic latitude coordinate | 37.7749 |
| longitude | Double | Yes | Geographic longitude coordinate | -122.4194 |
| propertyType | String (Enum) | Yes | Classification of property | "RESIDENTIAL", "COMMERCIAL", "INDUSTRIAL", "MIXED_USE" |
| zoneId | String | No | Service zone identifier for routing | "ZONE-SF-NORTH" |
| squareFootage | Integer | No | Total square footage of the property | 2500 |
| accessNotes | String | No | Special access instructions for technicians | "Gate code: 1234, Ring bell at rear entrance" |
| createdAt | Timestamp | Yes | Record creation timestamp | 2024-01-15T08:30:00Z |
| updatedAt | Timestamp | Yes | Last modification timestamp | 2024-02-10T14:22:00Z |

**Datasource**: Snowflake `ANALYTICS.DIM_PROPERTY`

**Sync Configuration**:
- Full sync: Daily at 4:00 AM UTC
- Incremental sync: Every 2 hours
- Primary key field: `PROPERTY_ID`

---

### Technician

Represents a field service technician who performs work orders and is assigned to routes.

**Primary Key**: `technicianId` (String)

**Properties**:

| Property Name | Data Type | Required | Description | Example |
|--------------|-----------|----------|-------------|---------|
| technicianId | String | Yes | Unique identifier for the technician | "TECH-001234" |
| name | String | Yes | Full name of the technician | "John Smith" |
| email | String | Yes | Email address | "john.smith@company.com" |
| phone | String | Yes | Contact phone number | "+1-415-555-0123" |
| homeLatitude | Double | Yes | Home base latitude for route start/end | 37.8044 |
| homeLongitude | Double | Yes | Home base longitude for route start/end | -122.2711 |
| skills | StringSet | Yes | Set of technical skills/certifications | ["HVAC", "PLUMBING", "ELECTRICAL_L2"] |
| maxDailyHours | Double | Yes | Maximum working hours per day | 8.0 |
| maxDailyDistanceMiles | Double | Yes | Maximum travel distance per day | 150.0 |
| hourlyRate | Double | Yes | Labor cost per hour for optimization | 45.50 |
| availabilityStatus | String (Enum) | Yes | Current availability status | "ACTIVE", "ON_LEAVE", "INACTIVE" |
| zonePreference | StringSet | No | Preferred service zones | ["ZONE-SF-NORTH", "ZONE-SF-CENTRAL"] |
| employeeType | String (Enum) | Yes | Employment classification | "FULL_TIME", "PART_TIME", "CONTRACT" |
| certifications | StringSet | No | Professional certifications | ["EPA_608", "OSHA_30"] |
| createdAt | Timestamp | Yes | Record creation timestamp | 2023-06-01T00:00:00Z |
| updatedAt | Timestamp | Yes | Last modification timestamp | 2024-02-11T09:15:00Z |

**Datasource**: Snowflake `ANALYTICS.DIM_TECHNICIAN`

**Sync Configuration**:
- Full sync: Daily at 4:00 AM UTC
- Incremental sync: Every 1 hour
- Primary key field: `TECHNICIAN_ID`

---

### WorkOrder

Represents a service request or maintenance task to be performed at a property.

**Primary Key**: `workOrderId` (String)

**Properties**:

| Property Name | Data Type | Required | Description | Example |
|--------------|-----------|----------|-------------|---------|
| workOrderId | String | Yes | Unique identifier for the work order | "WO-2024-0056789" |
| title | String | Yes | Brief description of the work | "HVAC System Maintenance" |
| description | String | No | Detailed work order description | "Annual preventive maintenance on rooftop HVAC unit 3" |
| category | String (Enum) | Yes | Work order category | "HVAC", "PLUMBING", "ELECTRICAL", "GENERAL_MAINTENANCE", "EMERGENCY" |
| priority | String (Enum) | Yes | Urgency level | "LOW", "MEDIUM", "HIGH", "CRITICAL" |
| requiredSkills | StringSet | Yes | Skills needed to complete work | ["HVAC", "ELECTRICAL_L1"] |
| estimatedDurationMinutes | Integer | Yes | Expected time to complete work | 120 |
| timeWindowStart | Timestamp | No | Earliest acceptable start time | 2024-02-15T08:00:00Z |
| timeWindowEnd | Timestamp | No | Latest acceptable completion time | 2024-02-15T17:00:00Z |
| status | String (Enum) | Yes | Current work order status | "PENDING", "ASSIGNED", "IN_PROGRESS", "COMPLETED", "CANCELLED" |
| sourceSystem | String | Yes | Originating system | "SALESFORCE", "FIELD_SERVICE_APP", "CUSTOMER_PORTAL" |
| propertyId | String (FK) | Yes | Foreign key to Property | "PROP-2024-0001234" |
| requestedBy | String | No | Name of requester | "Property Manager - District 5" |
| estimatedCost | Double | No | Projected cost of work | 350.00 |
| actualCost | Double | No | Actual cost after completion | 375.50 |
| createdAt | Timestamp | Yes | Work order creation timestamp | 2024-02-10T10:30:00Z |
| updatedAt | Timestamp | Yes | Last modification timestamp | 2024-02-12T11:45:00Z |
| completedAt | Timestamp | No | Actual completion timestamp | null |

**Datasource**: Snowflake `ANALYTICS.FACT_WORK_ORDER`

**Sync Configuration**:
- Full sync: Daily at 4:00 AM UTC
- Incremental sync: Every 30 minutes (high-frequency for operational responsiveness)
- Primary key field: `WORK_ORDER_ID`
- Filter: Only sync work orders from last 90 days for performance

---

### Route

Represents an optimized daily route assigned to a technician, containing multiple stops.

**Primary Key**: `routeId` (String)

**Properties**:

| Property Name | Data Type | Required | Description | Example |
|--------------|-----------|----------|-------------|---------|
| routeId | String | Yes | Unique identifier for the route | "ROUTE-2024-02-15-TECH001234" |
| optimizationRunId | String | Yes | Reference to the optimization execution | "OPT-RUN-2024-02-14-2030" |
| technicianId | String (FK) | Yes | Foreign key to assigned Technician | "TECH-001234" |
| routeDate | Date | Yes | Date the route is scheduled for | 2024-02-15 |
| totalDistanceMiles | Double | Yes | Total driving distance for the route | 87.3 |
| totalDurationMinutes | Double | Yes | Total time including work and travel | 465 |
| numStops | Integer | Yes | Number of work order stops | 6 |
| algorithmUsed | String (Enum) | Yes | Optimization algorithm applied | "ORTOOLS_VRP", "GENETIC_ALGORITHM", "GREEDY_NEAREST" |
| algorithmVersion | String | Yes | Version of optimization engine | "v2.3.1" |
| status | String (Enum) | Yes | Route execution status | "DRAFT", "PUBLISHED", "IN_PROGRESS", "COMPLETED", "CANCELLED" |
| totalWorkMinutes | Double | Yes | Sum of actual work time (excluding travel) | 380 |
| totalTravelMinutes | Double | Yes | Sum of travel time between stops | 85 |
| startTime | Timestamp | No | Planned route start time | 2024-02-15T08:00:00Z |
| endTime | Timestamp | No | Planned route end time | 2024-02-15T15:45:00Z |
| optimizationScore | Double | No | Quality metric from optimizer | 0.92 |
| createdAt | Timestamp | Yes | Route creation timestamp | 2024-02-14T20:30:00Z |
| updatedAt | Timestamp | Yes | Last modification timestamp | 2024-02-15T07:30:00Z |

**Datasource**: Snowflake `ANALYTICS.FACT_ROUTE`

**Sync Configuration**:
- Full sync: Daily at 4:00 AM UTC
- Incremental sync: Every 15 minutes
- Primary key field: `ROUTE_ID`
- Retention: Routes older than 1 year archived

---

### RouteStop

Represents a single stop on a route, linking a work order to a specific position in the route sequence.

**Primary Key**: `stopId` (String)

**Properties**:

| Property Name | Data Type | Required | Description | Example |
|--------------|-----------|----------|-------------|---------|
| stopId | String | Yes | Unique identifier for the route stop | "STOP-2024-02-15-001" |
| routeId | String (FK) | Yes | Foreign key to parent Route | "ROUTE-2024-02-15-TECH001234" |
| workOrderId | String (FK) | Yes | Foreign key to WorkOrder being serviced | "WO-2024-0056789" |
| sequenceNumber | Integer | Yes | Order of stop in the route (1-based) | 3 |
| arrivalTime | Timestamp | Yes | Planned arrival time at stop | 2024-02-15T10:15:00Z |
| departureTime | Timestamp | Yes | Planned departure time from stop | 2024-02-15T12:15:00Z |
| travelDistanceMiles | Double | Yes | Distance from previous stop | 12.4 |
| travelDurationMinutes | Double | Yes | Travel time from previous stop | 18 |
| actualArrivalTime | Timestamp | No | Actual arrival time (real-time tracking) | 2024-02-15T10:22:00Z |
| actualDepartureTime | Timestamp | No | Actual departure time (real-time tracking) | 2024-02-15T12:18:00Z |
| stopStatus | String (Enum) | Yes | Stop completion status | "PENDING", "ARRIVED", "IN_PROGRESS", "COMPLETED", "SKIPPED" |
| waitTimeMinutes | Double | No | Time waiting before service can start | 5 |
| createdAt | Timestamp | Yes | Stop record creation timestamp | 2024-02-14T20:30:00Z |
| updatedAt | Timestamp | Yes | Last modification timestamp | 2024-02-15T12:20:00Z |

**Datasource**: Snowflake `ANALYTICS.FACT_ROUTE_STOP`

**Sync Configuration**:
- Full sync: Daily at 4:00 AM UTC
- Incremental sync: Every 15 minutes
- Primary key field: `STOP_ID`
- Retention: Stops older than 1 year archived

---

## Link Types

Link types define the relationships between objects in the Ontology, enabling graph traversal and relational queries.

### Property ↔ WorkOrder Links

**propertyHasWorkOrders** (One-to-Many)
- **From**: Property
- **To**: WorkOrder
- **Cardinality**: One Property → Many WorkOrders
- **Description**: Links a property to all work orders scheduled or completed at that location
- **Use Case**: View all maintenance history for a property
- **Implementation**: Foreign key `propertyId` in WorkOrder object

**workOrderAtProperty** (Many-to-One)
- **From**: WorkOrder
- **To**: Property
- **Cardinality**: Many WorkOrders → One Property
- **Description**: Links a work order to its service location
- **Use Case**: Navigate from work order details to property information
- **Implementation**: Reverse link of `propertyHasWorkOrders`

---

### Technician ↔ Route Links

**technicianAssignedRoutes** (One-to-Many)
- **From**: Technician
- **To**: Route
- **Cardinality**: One Technician → Many Routes
- **Description**: Links a technician to all routes assigned to them (historical and future)
- **Use Case**: View technician's route history and workload
- **Implementation**: Foreign key `technicianId` in Route object

**routeAssignedToTechnician** (Many-to-One)
- **From**: Route
- **To**: Technician
- **Cardinality**: Many Routes → One Technician
- **Description**: Links a route to its assigned technician
- **Use Case**: Identify who is executing a specific route
- **Implementation**: Reverse link of `technicianAssignedRoutes`

---

### Route ↔ RouteStop Links

**routeContainsStops** (One-to-Many)
- **From**: Route
- **To**: RouteStop
- **Cardinality**: One Route → Many RouteStops
- **Description**: Links a route to all stops in sequence
- **Use Case**: Display full route itinerary
- **Implementation**: Foreign key `routeId` in RouteStop object
- **Ordering**: Results ordered by `sequenceNumber` property

**stopBelongsToRoute** (Many-to-One)
- **From**: RouteStop
- **To**: Route
- **Cardinality**: Many RouteStops → One Route
- **Description**: Links a stop back to its parent route
- **Use Case**: Navigate from stop details to full route context
- **Implementation**: Reverse link of `routeContainsStops`

---

### RouteStop ↔ WorkOrder Links

**stopForWorkOrder** (Many-to-One)
- **From**: RouteStop
- **To**: WorkOrder
- **Cardinality**: Many RouteStops → One WorkOrder
- **Description**: Links a route stop to the work order being serviced
- **Use Case**: Access work order details from route execution
- **Implementation**: Foreign key `workOrderId` in RouteStop object

**workOrderScheduledStops** (One-to-Many)
- **From**: WorkOrder
- **To**: RouteStop
- **Cardinality**: One WorkOrder → Many RouteStops (typically 0 or 1)
- **Description**: Links a work order to route stops (historical scheduling)
- **Use Case**: Track if work order has been scheduled and when
- **Implementation**: Reverse link of `stopForWorkOrder`

---

### Composite Link Paths

The Ontology enables multi-hop graph traversal for complex queries:

**Property → WorkOrder → RouteStop → Route → Technician**
- Use Case: "Which technicians have serviced this property in the last 6 months?"

**Technician → Route → RouteStop → WorkOrder → Property**
- Use Case: "What properties has this technician visited this month?"

**Route → RouteStop → WorkOrder → Property**
- Use Case: "Show all property locations on this route on a map"

---

## Actions

Ontology Actions encapsulate business logic and allow users to trigger operations directly from the Foundry interface or via OSDK API calls.

### CreateOptimizationRun

**Description**: Initiates a route optimization execution for a specified date range and technician pool.

**Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| optimizationDate | Date | Yes | Target date for route optimization |
| technicianIds | StringSet | No | Specific technicians to include (empty = all available) |
| zoneIds | StringSet | No | Limit to specific zones (empty = all zones) |
| algorithmType | String (Enum) | Yes | Algorithm to use: "ORTOOLS_VRP", "GENETIC_ALGORITHM", "GREEDY_NEAREST" |
| maxRouteDurationMinutes | Integer | No | Override default max route duration (default: 480) |
| prioritizeByDueDate | Boolean | No | Prioritize work orders by due date vs efficiency (default: false) |

**Returns**: 
- `optimizationRunId` (String): Identifier for the optimization execution
- `status` (String): "QUEUED", "RUNNING", "COMPLETED", "FAILED"

**Validation Rules**:
- optimizationDate must be today or future date
- technicianIds must reference existing, active technicians
- At least one work order must be in PENDING status for the date

**Execution**:
1. Validates input parameters
2. Queries pending work orders for target date
3. Fetches technician availability and constraints
4. Submits optimization job to backend API
5. Creates Route and RouteStop objects upon completion

**Audit**: All executions logged with timestamp, user, parameters, and results

---

### AssignWorkOrder

**Description**: Manually assigns a work order to a specific technician, bypassing optimization.

**Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| workOrderId | String | Yes | Work order to assign |
| technicianId | String | Yes | Target technician |
| scheduledDate | Date | Yes | Date to schedule work |
| scheduledTimeStart | Timestamp | No | Specific start time window |

**Returns**:
- `assignmentId` (String): Unique assignment identifier
- `success` (Boolean): Assignment success status

**Validation Rules**:
- Work order status must be PENDING
- Technician must have required skills
- Technician must be available on scheduled date
- Scheduled time must respect work order time windows

**Execution**:
1. Validates work order and technician
2. Checks skill matching
3. Updates work order status to ASSIGNED
4. Creates or updates route for technician on that date
5. Adds RouteStop to the route
6. Triggers notification to technician

**Rollback**: If assignment fails, work order returns to PENDING status

---

### UpdateWorkOrderStatus

**Description**: Updates the status of a work order with optional completion details.

**Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| workOrderId | String | Yes | Work order to update |
| newStatus | String (Enum) | Yes | Target status: "PENDING", "ASSIGNED", "IN_PROGRESS", "COMPLETED", "CANCELLED" |
| completionNotes | String | No | Notes or comments on status change |
| actualDurationMinutes | Integer | No | Actual time spent (for COMPLETED status) |
| actualCost | Double | No | Final cost (for COMPLETED status) |

**Returns**:
- `success` (Boolean): Update success status
- `previousStatus` (String): Status before update

**Validation Rules**:
- Status transitions must follow valid state machine:
  - PENDING → ASSIGNED → IN_PROGRESS → COMPLETED
  - Any status → CANCELLED (except COMPLETED)
- COMPLETED status requires actualDurationMinutes

**Execution**:
1. Validates status transition
2. Updates work order object properties
3. Updates timestamp fields
4. If COMPLETED, updates associated RouteStop status
5. Sends notification to relevant stakeholders

**Audit**: Status changes logged with user, timestamp, and reason

---

### ReoptimizeRoute

**Description**: Re-runs optimization for a single route, useful when work orders are added/removed or technician availability changes.

**Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| routeId | String | Yes | Route to re-optimize |
| keepAssignedWorkOrders | Boolean | No | Preserve existing work orders (default: true) |
| addWorkOrderIds | StringSet | No | Additional work orders to include |
| removeStopIds | StringSet | No | Stops to remove from route |

**Returns**:
- `newRouteId` (String): Identifier for the new optimized route
- `improvementPercent` (Double): Efficiency improvement vs old route

**Validation Rules**:
- Route status must be DRAFT or PUBLISHED (not IN_PROGRESS or COMPLETED)
- Added work orders must match technician skills
- Route date must be today or future

**Execution**:
1. Fetches current route and stops
2. Applies add/remove operations
3. Runs optimization algorithm on modified work order set
4. Creates new Route object
5. Marks old route as SUPERSEDED
6. Notifies technician of route change

**Performance**: Optimizes single route in <30 seconds for typical route size (5-10 stops)

---

## Ontology Sync Configuration

The Ontology is synchronized from Snowflake data warehouse using Foundry's Data Connection and Ontology sync pipelines.

### Data Connection

**Connection Name**: `snowflake_analytics_prod`

**Configuration**:
- **Host**: `company.snowflakecomputing.com`
- **Database**: `ANALYTICS`
- **Schema**: Multiple schemas (DIM, FACT)
- **Warehouse**: `ANALYTICS_WH`
- **Authentication**: Service account with read-only access
- **SSL**: Enabled
- **Query Timeout**: 300 seconds

**Network**:
- Connection via Foundry's secure connector
- IP whitelisting on Snowflake side
- Encrypted in transit (TLS 1.2+)

---

### Object Type Sync Schedules

#### Property Object

**Source**: `ANALYTICS.DIM_PROPERTY`

**Sync Type**: Incremental (based on `UPDATED_AT` column)

**Schedule**:
- **Full Sync**: Daily at 4:00 AM UTC
- **Incremental Sync**: Every 2 hours (6:00, 8:00, 10:00, etc.)

**Mapping**:
```sql
SELECT 
  PROPERTY_ID as propertyId,
  ADDRESS as address,
  CITY as city,
  STATE as state,
  ZIP_CODE as zipCode,
  LATITUDE as latitude,
  LONGITUDE as longitude,
  PROPERTY_TYPE as propertyType,
  ZONE_ID as zoneId,
  SQUARE_FOOTAGE as squareFootage,
  ACCESS_NOTES as accessNotes,
  CREATED_AT as createdAt,
  UPDATED_AT as updatedAt
FROM ANALYTICS.DIM_PROPERTY
WHERE UPDATED_AT > :lastSyncTime
```

**Primary Key**: `propertyId`

**Error Handling**: Failed syncs retry 3 times with exponential backoff; alerts sent to data engineering team

---

#### Technician Object

**Source**: `ANALYTICS.DIM_TECHNICIAN`

**Sync Type**: Incremental

**Schedule**:
- **Full Sync**: Daily at 4:00 AM UTC
- **Incremental Sync**: Every 1 hour

**Mapping**:
```sql
SELECT 
  TECHNICIAN_ID as technicianId,
  NAME as name,
  EMAIL as email,
  PHONE as phone,
  HOME_LATITUDE as homeLatitude,
  HOME_LONGITUDE as homeLongitude,
  SKILLS as skills,  -- JSON array converted to StringSet
  MAX_DAILY_HOURS as maxDailyHours,
  MAX_DAILY_DISTANCE_MILES as maxDailyDistanceMiles,
  HOURLY_RATE as hourlyRate,
  AVAILABILITY_STATUS as availabilityStatus,
  ZONE_PREFERENCE as zonePreference,  -- JSON array converted to StringSet
  EMPLOYEE_TYPE as employeeType,
  CERTIFICATIONS as certifications,  -- JSON array converted to StringSet
  CREATED_AT as createdAt,
  UPDATED_AT as updatedAt
FROM ANALYTICS.DIM_TECHNICIAN
WHERE UPDATED_AT > :lastSyncTime
```

**Primary Key**: `technicianId`

---

#### WorkOrder Object

**Source**: `ANALYTICS.FACT_WORK_ORDER`

**Sync Type**: Incremental (high-frequency for operational responsiveness)

**Schedule**:
- **Full Sync**: Daily at 4:00 AM UTC
- **Incremental Sync**: Every 30 minutes

**Mapping**:
```sql
SELECT 
  WORK_ORDER_ID as workOrderId,
  TITLE as title,
  DESCRIPTION as description,
  CATEGORY as category,
  PRIORITY as priority,
  REQUIRED_SKILLS as requiredSkills,  -- JSON array converted to StringSet
  ESTIMATED_DURATION_MINUTES as estimatedDurationMinutes,
  TIME_WINDOW_START as timeWindowStart,
  TIME_WINDOW_END as timeWindowEnd,
  STATUS as status,
  SOURCE_SYSTEM as sourceSystem,
  PROPERTY_ID as propertyId,
  REQUESTED_BY as requestedBy,
  ESTIMATED_COST as estimatedCost,
  ACTUAL_COST as actualCost,
  CREATED_AT as createdAt,
  UPDATED_AT as updatedAt,
  COMPLETED_AT as completedAt
FROM ANALYTICS.FACT_WORK_ORDER
WHERE UPDATED_AT > :lastSyncTime
  AND CREATED_AT >= CURRENT_DATE - INTERVAL '90 DAYS'  -- Performance filter
```

**Primary Key**: `workOrderId`

**Performance Optimization**: Only syncs work orders from last 90 days to limit dataset size

---

#### Route Object

**Source**: `ANALYTICS.FACT_ROUTE`

**Sync Type**: Incremental

**Schedule**:
- **Full Sync**: Daily at 4:00 AM UTC
- **Incremental Sync**: Every 15 minutes

**Mapping**:
```sql
SELECT 
  ROUTE_ID as routeId,
  OPTIMIZATION_RUN_ID as optimizationRunId,
  TECHNICIAN_ID as technicianId,
  ROUTE_DATE as routeDate,
  TOTAL_DISTANCE_MILES as totalDistanceMiles,
  TOTAL_DURATION_MINUTES as totalDurationMinutes,
  NUM_STOPS as numStops,
  ALGORITHM_USED as algorithmUsed,
  ALGORITHM_VERSION as algorithmVersion,
  STATUS as status,
  TOTAL_WORK_MINUTES as totalWorkMinutes,
  TOTAL_TRAVEL_MINUTES as totalTravelMinutes,
  START_TIME as startTime,
  END_TIME as endTime,
  OPTIMIZATION_SCORE as optimizationScore,
  CREATED_AT as createdAt,
  UPDATED_AT as updatedAt
FROM ANALYTICS.FACT_ROUTE
WHERE UPDATED_AT > :lastSyncTime
```

**Primary Key**: `routeId`

---

#### RouteStop Object

**Source**: `ANALYTICS.FACT_ROUTE_STOP`

**Sync Type**: Incremental

**Schedule**:
- **Full Sync**: Daily at 4:00 AM UTC
- **Incremental Sync**: Every 15 minutes

**Mapping**:
```sql
SELECT 
  STOP_ID as stopId,
  ROUTE_ID as routeId,
  WORK_ORDER_ID as workOrderId,
  SEQUENCE_NUMBER as sequenceNumber,
  ARRIVAL_TIME as arrivalTime,
  DEPARTURE_TIME as departureTime,
  TRAVEL_DISTANCE_MILES as travelDistanceMiles,
  TRAVEL_DURATION_MINUTES as travelDurationMinutes,
  ACTUAL_ARRIVAL_TIME as actualArrivalTime,
  ACTUAL_DEPARTURE_TIME as actualDepartureTime,
  STOP_STATUS as stopStatus,
  WAIT_TIME_MINUTES as waitTimeMinutes,
  CREATED_AT as createdAt,
  UPDATED_AT as updatedAt
FROM ANALYTICS.FACT_ROUTE_STOP
WHERE UPDATED_AT > :lastSyncTime
```

**Primary Key**: `stopId`

---

### Link Type Sync

Links are derived automatically from foreign key relationships in the object properties:

- **propertyHasWorkOrders / workOrderAtProperty**: Derived from `WorkOrder.propertyId`
- **technicianAssignedRoutes / routeAssignedToTechnician**: Derived from `Route.technicianId`
- **routeContainsStops / stopBelongsToRoute**: Derived from `RouteStop.routeId`
- **stopForWorkOrder**: Derived from `RouteStop.workOrderId`

**Validation**: Foundry validates referential integrity during sync; orphaned objects (e.g., RouteStop referencing non-existent Route) are logged as errors

---

### Sync Monitoring and Alerting

**Metrics Tracked**:
- Sync duration and throughput (rows/minute)
- Success/failure rate
- Data quality issues (null values in required fields, invalid enums)
- Referential integrity violations

**Alerts**:
- Sync failure after 3 retries → PagerDuty alert to Data Engineering on-call
- Sync duration exceeds 15 minutes → Warning notification
- Data quality issues exceed 1% of records → Investigation required

**Dashboard**: Foundry monitoring dashboard tracks all sync pipelines with historical trends

---

## OSDK Integration

The backend Route Optimization API integrates with Palantir Foundry's Ontology using the **Ontology SDK (OSDK)**, enabling programmatic access to objects, links, and actions.

### OSDK Setup

**Library**: `@palantir/foundry-ontology-sdk` (TypeScript/Node.js)

**Authentication**: 
- Service account token with scoped permissions
- Permissions: Read (all objects), Write (Route, RouteStop), Execute (all actions)

**Configuration**:
```typescript
import { Client } from '@palantir/foundry-ontology-sdk';

const client = new Client({
  foundryUrl: 'https://foundry.company.com',
  authToken: process.env.FOUNDRY_SERVICE_TOKEN,
  ontology: 'route-optimization-v1'
});
```

---

### Querying Objects

**Example: Fetch Pending Work Orders for a Date**

```typescript
const workOrders = await client.objects.WorkOrder.query()
  .where({
    status: 'PENDING',
    timeWindowStart: {
      $gte: new Date('2024-02-15T00:00:00Z'),
      $lt: new Date('2024-02-16T00:00:00Z')
    }
  })
  .select(['workOrderId', 'title', 'propertyId', 'requiredSkills', 'estimatedDurationMinutes'])
  .limit(1000)
  .execute();

console.log(`Found ${workOrders.length} pending work orders`);
```

**Example: Fetch Technician with Skills**

```typescript
const technician = await client.objects.Technician.get('TECH-001234');

console.log(`Technician: ${technician.name}`);
console.log(`Skills: ${technician.skills.join(', ')}`);
console.log(`Max Daily Hours: ${technician.maxDailyHours}`);
```

---

### Traversing Links

**Example: Get All Work Orders for a Property**

```typescript
const property = await client.objects.Property.get('PROP-2024-0001234');

const workOrders = await property.links.propertyHasWorkOrders()
  .select(['workOrderId', 'title', 'status', 'createdAt'])
  .orderBy('createdAt', 'desc')
  .execute();

console.log(`Property has ${workOrders.length} work orders`);
```

**Example: Get Route Details with Stops**

```typescript
const route = await client.objects.Route.get('ROUTE-2024-02-15-TECH001234');

const stops = await route.links.routeContainsStops()
  .select(['stopId', 'sequenceNumber', 'arrivalTime', 'workOrderId'])
  .orderBy('sequenceNumber', 'asc')
  .execute();

for (const stop of stops) {
  const workOrder = await client.objects.WorkOrder.get(stop.workOrderId);
  console.log(`Stop ${stop.sequenceNumber}: ${workOrder.title} at ${stop.arrivalTime}`);
}
```

---

### Executing Actions

**Example: Trigger Optimization Run**

```typescript
const result = await client.actions.CreateOptimizationRun.execute({
  optimizationDate: new Date('2024-02-15'),
  technicianIds: ['TECH-001234', 'TECH-005678'],
  zoneIds: ['ZONE-SF-NORTH'],
  algorithmType: 'ORTOOLS_VRP',
  maxRouteDurationMinutes: 480,
  prioritizeByDueDate: false
});

console.log(`Optimization run created: ${result.optimizationRunId}`);
console.log(`Status: ${result.status}`);
```

**Example: Manually Assign Work Order**

```typescript
const assignment = await client.actions.AssignWorkOrder.execute({
  workOrderId: 'WO-2024-0056789',
  technicianId: 'TECH-001234',
  scheduledDate: new Date('2024-02-15'),
  scheduledTimeStart: new Date('2024-02-15T10:00:00Z')
});

if (assignment.success) {
  console.log(`Work order assigned successfully: ${assignment.assignmentId}`);
} else {
  console.error('Assignment failed');
}
```

---

### Subscribing to Object Changes

**Example: Real-Time Updates on Route Status**

```typescript
const subscription = client.objects.Route.subscribe({
  where: { routeDate: new Date('2024-02-15') },
  onChange: (changedRoute) => {
    console.log(`Route ${changedRoute.routeId} status changed to: ${changedRoute.status}`);
    
    if (changedRoute.status === 'COMPLETED') {
      notifyStakeholders(changedRoute);
    }
  }
});

// Subscription remains active, receiving real-time updates
// Unsubscribe when done:
// subscription.unsubscribe();
```

**Use Cases for Subscriptions**:
- Dashboard real-time updates when routes change
- Alerting when high-priority work orders are created
- Monitoring technician check-ins at route stops

---

### Error Handling

**OSDK Best Practices**:

```typescript
try {
  const workOrder = await client.objects.WorkOrder.get('WO-INVALID');
} catch (error) {
  if (error.code === 'OBJECT_NOT_FOUND') {
    console.error('Work order does not exist');
  } else if (error.code === 'PERMISSION_DENIED') {
    console.error('Insufficient permissions to access work order');
  } else {
    console.error('Unexpected error:', error.message);
  }
}
```

**Common Error Codes**:
- `OBJECT_NOT_FOUND`: Object with specified primary key doesn't exist
- `PERMISSION_DENIED`: Service account lacks required permissions
- `VALIDATION_ERROR`: Action parameters failed validation
- `NETWORK_ERROR`: Connection to Foundry failed

---

### Performance Optimization

**Batching Reads**:
```typescript
const workOrderIds = ['WO-001', 'WO-002', 'WO-003', /* ... */];

// Batch fetch instead of individual gets
const workOrders = await client.objects.WorkOrder.getBatch(workOrderIds);
```

**Selective Field Loading**:
```typescript
// Only load required fields to reduce payload size
const routes = await client.objects.Route.query()
  .where({ routeDate: targetDate })
  .select(['routeId', 'technicianId', 'totalDistanceMiles'])  // Don't load all fields
  .execute();
```

**Query Result Caching**:
- OSDK automatically caches query results for 60 seconds
- Use `{ cache: false }` option for real-time data requirements

---

## Ontology Versioning and Evolution

**Current Version**: `route-optimization-v1`

**Version Strategy**:
- Major version changes (v1 → v2) for breaking schema changes
- Minor updates handled via additive changes (new properties, optional fields)

**Migration Process**:
1. Create new ontology version in Foundry
2. Update OSDK client configuration to new version
3. Run dual-write period (write to both old and new ontology)
4. Migrate historical data via batch pipeline
5. Cutover applications to new version
6. Deprecate old version after 90-day grace period

**Schema Change Log**: Maintained in Git repository alongside this documentation

---

## Security and Access Control

**Object-Level Permissions**:
- Read access: All authenticated users
- Write access: Field service managers, system service accounts
- Delete access: Data administrators only

**Action Permissions**:
- `CreateOptimizationRun`: Route planners, system service accounts
- `AssignWorkOrder`: Field service managers, dispatchers
- `UpdateWorkOrderStatus`: Technicians (own work orders), managers (all)
- `ReoptimizeRoute`: Route planners, managers

**Data Masking**:
- Technician personal information (phone, email) masked for non-manager roles
- Property access notes visible only to assigned technicians

**Audit Logging**:
- All object reads/writes logged with user, timestamp, IP address
- Action executions logged with full parameter set
- Logs retained for 2 years for compliance

---

## Appendix: Data Quality Rules

**Property Object**:
- Latitude must be between -90 and 90
- Longitude must be between -180 and 180
- Property type must be valid enum value

**Technician Object**:
- maxDailyHours must be between 1 and 16
- hourlyRate must be positive
- Skills set must contain at least one skill

**WorkOrder Object**:
- estimatedDurationMinutes must be between 15 and 480
- timeWindowEnd must be after timeWindowStart
- Priority and Category must be valid enum values

**Route Object**:
- totalDistanceMiles must be non-negative
- totalDurationMinutes must equal totalWorkMinutes + totalTravelMinutes
- routeDate must not be more than 90 days in past

**Enforcement**: Data quality rules validated during Ontology sync; violations logged and quarantined for review
