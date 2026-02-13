# Architecture Diagrams - Route Optimization Engine

This document provides visual representations of the Route Optimization Engine's ontology structure, data flows, and system architecture using Mermaid diagram syntax.

## Table of Contents

1. [Entity Relationship Diagram](#entity-relationship-diagram)
2. [Ontology Object Hierarchy](#ontology-object-hierarchy)
3. [Data Flow Architecture](#data-flow-architecture)
4. [ETL Pipeline Flow](#etl-pipeline-flow)
5. [Route Optimization Workflow](#route-optimization-workflow)
6. [Real-Time Update Flow](#real-time-update-flow)
7. [System Integration Architecture](#system-integration-architecture)
8. [Snowflake Layer Architecture](#snowflake-layer-architecture)

---

## Entity Relationship Diagram

Complete entity relationship diagram showing all Ontology Object Types and their Link Types.

```mermaid
erDiagram
    PROPERTY ||--o{ WORK_ORDER : "has"
    WORK_ORDER }o--|| PROPERTY : "at"
    
    TECHNICIAN ||--o{ ROUTE : "assigned"
    ROUTE }o--|| TECHNICIAN : "assigned to"
    
    ROUTE ||--o{ ROUTE_STOP : "contains"
    ROUTE_STOP }o--|| ROUTE : "belongs to"
    
    WORK_ORDER ||--o{ ROUTE_STOP : "scheduled as"
    ROUTE_STOP }o--|| WORK_ORDER : "services"
    
    PROPERTY {
        string propertyId PK
        string address
        string city
        string state
        string zipCode
        double latitude
        double longitude
        string propertyType
        string zoneId
        integer squareFootage
        string accessNotes
        timestamp createdAt
        timestamp updatedAt
    }
    
    WORK_ORDER {
        string workOrderId PK
        string propertyId FK
        string title
        string description
        string category
        string priority
        stringset requiredSkills
        integer estimatedDurationMinutes
        timestamp timeWindowStart
        timestamp timeWindowEnd
        string status
        string sourceSystem
        double estimatedCost
        double actualCost
        timestamp createdAt
        timestamp updatedAt
        timestamp completedAt
    }
    
    TECHNICIAN {
        string technicianId PK
        string name
        string email
        string phone
        double homeLatitude
        double homeLongitude
        stringset skills
        double maxDailyHours
        double maxDailyDistanceMiles
        double hourlyRate
        string availabilityStatus
        stringset zonePreference
        string employeeType
        stringset certifications
        timestamp createdAt
        timestamp updatedAt
    }
    
    ROUTE {
        string routeId PK
        string optimizationRunId
        string technicianId FK
        date routeDate
        double totalDistanceMiles
        double totalDurationMinutes
        integer numStops
        string algorithmUsed
        string algorithmVersion
        string status
        double totalWorkMinutes
        double totalTravelMinutes
        timestamp startTime
        timestamp endTime
        double optimizationScore
        timestamp createdAt
        timestamp updatedAt
    }
    
    ROUTE_STOP {
        string stopId PK
        string routeId FK
        string workOrderId FK
        integer sequenceNumber
        timestamp arrivalTime
        timestamp departureTime
        double travelDistanceMiles
        double travelDurationMinutes
        timestamp actualArrivalTime
        timestamp actualDepartureTime
        string stopStatus
        double waitTimeMinutes
        timestamp createdAt
        timestamp updatedAt
    }
```

---

## Ontology Object Hierarchy

Hierarchical view of how objects relate in the Ontology, showing the primary navigation paths.

```mermaid
graph TD
    A[Ontology Root] --> B[Property Objects]
    A --> C[Technician Objects]
    A --> D[WorkOrder Objects]
    A --> E[Route Objects]
    
    B --> B1[Property<br/>propertyId: PROP-001]
    B1 --> B2[propertyHasWorkOrders]
    B2 --> D1[WorkOrder<br/>workOrderId: WO-001]
    B2 --> D2[WorkOrder<br/>workOrderId: WO-002]
    
    C --> C1[Technician<br/>technicianId: TECH-001]
    C1 --> C2[technicianAssignedRoutes]
    C2 --> E1[Route<br/>routeId: ROUTE-2024-02-15-001]
    
    D1 --> D3[workOrderScheduledStops]
    D3 --> F1[RouteStop<br/>stopId: STOP-001]
    
    E1 --> E2[routeContainsStops]
    E2 --> F1
    E2 --> F2[RouteStop<br/>stopId: STOP-002]
    E2 --> F3[RouteStop<br/>stopId: STOP-003]
    
    F1 --> F4[stopForWorkOrder]
    F4 --> D1
    
    F1 --> F5[stopBelongsToRoute]
    F5 --> E1
    
    E1 --> E3[routeAssignedToTechnician]
    E3 --> C1
    
    style A fill:#e1f5ff
    style B fill:#fff3cd
    style C fill:#d4edda
    style D fill:#f8d7da
    style E fill:#d1ecf1
    style B1 fill:#fff3cd
    style C1 fill:#d4edda
    style D1 fill:#f8d7da
    style D2 fill:#f8d7da
    style E1 fill:#d1ecf1
    style F1 fill:#e2e3e5
    style F2 fill:#e2e3e5
    style F3 fill:#e2e3e5
```

---

## Data Flow Architecture

End-to-end data flow from source systems through to consumption layers.

```mermaid
graph TB
    subgraph "Source Systems"
        A1[Salesforce<br/>CRM/FSM]
        A2[CSV Files<br/>Property Data]
        A3[IoT Sensors<br/>Telemetry]
        A4[Mobile App<br/>Check-ins]
    end
    
    subgraph "Event Layer"
        B1[AWS EventBridge]
        B2[SFTP Server]
        B3[Kafka Topics]
        B4[REST API]
    end
    
    subgraph "Informatica ETL"
        C1[Extraction Jobs]
        C2[Data Quality<br/>Validation]
        C3[Enrichment<br/>Geocoding]
        C4[Business Rules]
    end
    
    subgraph "Snowflake Data Warehouse"
        D1[RAW Layer<br/>Bronze/L1]
        D2[STAGING Layer<br/>Silver/L2]
        D3[ANALYTICS Layer<br/>Gold/L3]
    end
    
    subgraph "Consumption Layer"
        E1[Palantir Foundry<br/>Ontology]
        E2[Looker BI<br/>Dashboards]
    end
    
    subgraph "Optimization Layer"
        F1[Route Optimization<br/>Engine]
        F2[MongoDB<br/>Operational DB]
        F3[React Dashboard<br/>Frontend]
    end
    
    A1 --> B1
    A2 --> B2
    A3 --> B3
    A4 --> B4
    
    B1 --> C1
    B2 --> C1
    B3 --> C1
    B4 --> C1
    
    C1 --> C2
    C2 --> C3
    C3 --> C4
    C4 --> D1
    
    D1 -->|Incremental<br/>Every 30 min| D2
    D2 -->|Incremental<br/>Every 30 min| D3
    
    D3 -->|Sync<br/>Every 15-30 min| E1
    D3 -->|Query<br/>Real-time| E2
    
    E1 -->|OSDK API<br/>Read Objects| F1
    F1 -->|Write Routes| F2
    F2 -->|Query Routes| F3
    
    F2 -.->|Write-back<br/>Nightly| D3
    D3 -.->|Re-sync<br/>Next day| E1
    
    style A1 fill:#e3f2fd
    style A2 fill:#e3f2fd
    style A3 fill:#e3f2fd
    style A4 fill:#e3f2fd
    style C1 fill:#fff3e0
    style C2 fill:#fff3e0
    style C3 fill:#fff3e0
    style C4 fill:#fff3e0
    style D1 fill:#f3e5f5
    style D2 fill:#e1bee7
    style D3 fill:#ce93d8
    style E1 fill:#c8e6c9
    style E2 fill:#c8e6c9
    style F1 fill:#ffccbc
    style F2 fill:#ffccbc
    style F3 fill:#ffccbc
```

---

## ETL Pipeline Flow

Detailed view of the Informatica ETL pipeline stages.

```mermaid
flowchart LR
    subgraph "Stage 1: Extraction"
        A1[Salesforce<br/>Bulk API]
        A2[SFTP<br/>File Monitor]
        A3[Kafka<br/>Consumer]
        A4[REST API<br/>Poller]
    end
    
    subgraph "Stage 2: Data Quality"
        B1{Null Check}
        B2{Type<br/>Validation}
        B3{Range<br/>Validation}
        B4{Enum<br/>Validation}
        BQ[DQ Error<br/>Quarantine]
    end
    
    subgraph "Stage 3: Transformation"
        C1[Deduplication<br/>MD5 Hash]
        C2[Geocoding<br/>Google API]
        C3[Zone<br/>Assignment]
        C4[Skill<br/>Mapping]
    end
    
    subgraph "Stage 4: Enrichment"
        D1[Priority<br/>Scoring]
        D2[Cost<br/>Estimation]
        D3[Availability<br/>Cross-ref]
        D4[SCD Type 2<br/>History]
    end
    
    subgraph "Stage 5: Load"
        E1[Snowflake<br/>RAW Tables]
        E2[STAGING<br/>Tables]
        E3[ANALYTICS<br/>Tables]
    end
    
    A1 --> B1
    A2 --> B1
    A3 --> B1
    A4 --> B1
    
    B1 -->|Pass| B2
    B1 -->|Fail| BQ
    B2 -->|Pass| B3
    B2 -->|Fail| BQ
    B3 -->|Pass| B4
    B3 -->|Fail| BQ
    B4 -->|Pass| C1
    B4 -->|Fail| BQ
    
    C1 --> C2
    C2 --> C3
    C3 --> C4
    
    C4 --> D1
    D1 --> D2
    D2 --> D3
    D3 --> D4
    
    D4 --> E1
    E1 -->|Stream| E2
    E2 -->|Stream| E3
    
    BQ -.->|Alert| Alert[Data Engineering<br/>PagerDuty]
    
    style BQ fill:#ffcdd2
    style Alert fill:#ff8a80
    style E1 fill:#bbdefb
    style E2 fill:#90caf9
    style E3 fill:#64b5f6
```

---

## Route Optimization Workflow

Sequence diagram showing the route optimization process from trigger to dashboard update.

```mermaid
sequenceDiagram
    autonumber
    
    actor User
    participant Dashboard as React Dashboard
    participant API as Backend API
    participant OSDK as Foundry OSDK
    participant Ontology as Foundry Ontology
    participant Optimizer as Optimization Engine
    participant MongoDB as MongoDB
    participant Snowflake as Snowflake
    
    User->>Dashboard: Trigger "Create<br/>Optimization Run"
    Dashboard->>API: POST /api/optimize
    API->>OSDK: Execute Action:<br/>CreateOptimizationRun
    
    OSDK->>Ontology: Validate parameters
    Ontology-->>OSDK: Parameters valid
    
    OSDK->>Ontology: Query pending<br/>WorkOrders
    Ontology-->>OSDK: WorkOrder objects
    
    OSDK->>Ontology: Query available<br/>Technicians
    Ontology-->>OSDK: Technician objects
    
    OSDK->>Optimizer: Submit optimization job<br/>(work orders + techs)
    
    activate Optimizer
    Note over Optimizer: OR-Tools VRP Solver<br/>Execution: 30s - 5min
    Optimizer->>Optimizer: Apply constraints:<br/>- Skills matching<br/>- Time windows<br/>- Max hours/distance
    Optimizer->>Optimizer: Generate routes<br/>with stops
    deactivate Optimizer
    
    Optimizer->>MongoDB: Write Route objects
    Optimizer->>MongoDB: Write RouteStop objects
    Optimizer-->>OSDK: Optimization complete<br/>(optimizationRunId)
    
    OSDK-->>API: Action result:<br/>status, runId
    API-->>Dashboard: Optimization complete
    Dashboard->>Dashboard: Poll for route updates
    
    Dashboard->>API: GET /api/routes/:date
    API->>MongoDB: Query routes for date
    MongoDB-->>API: Route documents
    API-->>Dashboard: Route data (JSON)
    
    Dashboard->>User: Display optimized routes<br/>on map
    
    Note over MongoDB,Snowflake: Nightly write-back
    MongoDB->>Snowflake: Batch insert routes<br/>to ANALYTICS layer
    Snowflake->>Ontology: Next incremental sync<br/>(next morning)
```

---

## Real-Time Update Flow

Change Data Capture (CDC) flow showing how work order updates propagate through the system.

```mermaid
graph TB
    subgraph "Source Event"
        A[Technician completes<br/>work order in mobile app]
    end
    
    subgraph "CDC Pipeline"
        B1[Mobile App<br/>REST API]
        B2[AWS Lambda<br/>Event Handler]
        B3[Kafka Topic<br/>work-order-updates]
    end
    
    subgraph "Processing Paths"
        C1[Path 1: Fast Path<br/>Operational]
        C2[Path 2: Batch Path<br/>Analytical]
    end
    
    subgraph "Fast Path - Real-Time"
        D1[Backend API<br/>Status Update]
        D2[MongoDB<br/>Update RouteStop]
        D3[Change Stream<br/>Event]
        D4[WebSocket Push]
        D5[Dashboard<br/>Real-time Update]
    end
    
    subgraph "Batch Path - Analytical"
        E1[Informatica<br/>Kafka Consumer]
        E2[Snowflake RAW<br/>Insert Event]
        E3[Snowflake Stream<br/>Detects Change]
        E4[Scheduled Task<br/>Every 5 min]
        E5[STAGING → ANALYTICS<br/>Propagation]
        E6[Foundry Incremental<br/>Sync - 30 min]
        E7[Ontology Object<br/>Updated]
    end
    
    A --> B1
    B1 --> B2
    B2 --> B3
    
    B3 --> C1
    B3 --> C2
    
    C1 --> D1
    D1 --> D2
    D2 --> D3
    D3 --> D4
    D4 --> D5
    
    C2 --> E1
    E1 --> E2
    E2 --> E3
    E3 --> E4
    E4 --> E5
    E5 --> E6
    E6 --> E7
    
    style A fill:#e3f2fd
    style D1 fill:#c8e6c9
    style D2 fill:#c8e6c9
    style D3 fill:#c8e6c9
    style D4 fill:#c8e6c9
    style D5 fill:#a5d6a7
    style E1 fill:#fff9c4
    style E2 fill:#fff59d
    style E3 fill:#fff176
    style E4 fill:#ffee58
    style E5 fill:#ffeb3b
    style E6 fill:#fdd835
    style E7 fill:#fbc02d
    
    D5 -.->|Latency:<br/>< 10 seconds| Latency1[Fast]
    E7 -.->|Latency:<br/>~40 minutes| Latency2[Batch]
    
    style Latency1 fill:#4caf50,color:#fff
    style Latency2 fill:#ff9800,color:#fff
```

---

## System Integration Architecture

High-level system architecture showing all major components and their interactions.

```mermaid
graph TB
    subgraph "External Systems"
        EXT1[Salesforce]
        EXT2[Google Maps API]
        EXT3[Third-party<br/>Property DBs]
    end
    
    subgraph "Data Ingestion"
        ING1[Informatica<br/>PowerCenter]
        ING2[AWS EventBridge]
        ING3[Kafka Cluster]
    end
    
    subgraph "Data Platform"
        DP1[Snowflake<br/>Data Warehouse]
        DP2[Palantir Foundry<br/>Ontology Platform]
        DP3[MongoDB Atlas<br/>Operational DB]
    end
    
    subgraph "Application Layer"
        APP1[Route Optimization<br/>Engine API]
        APP2[Backend REST API]
        APP3[OSDK Integration<br/>Service]
    end
    
    subgraph "Analytics & BI"
        BI1[Looker<br/>BI Platform]
        BI2[Tableau<br/>Ad-hoc Analysis]
    end
    
    subgraph "User Interface"
        UI1[React Dashboard<br/>Route Management]
        UI2[Mobile App<br/>Technician]
        UI3[Admin Portal<br/>Configuration]
    end
    
    subgraph "Infrastructure"
        INF1[AWS ECS<br/>Container Runtime]
        INF2[AWS Lambda<br/>Serverless]
        INF3[AWS S3<br/>File Storage]
    end
    
    subgraph "Monitoring & Observability"
        MON1[DataDog<br/>APM & Metrics]
        MON2[PagerDuty<br/>Alerting]
        MON3[Slack<br/>Notifications]
    end
    
    EXT1 -->|API| ING1
    EXT1 -->|CDC| ING2
    EXT2 -->|Geocoding| ING1
    EXT3 -->|SFTP| ING1
    
    ING1 --> DP1
    ING2 --> ING3
    ING3 --> DP1
    
    DP1 -->|Sync| DP2
    DP1 -->|Query| BI1
    DP1 -->|Query| BI2
    
    DP2 -->|OSDK| APP3
    APP3 --> APP1
    APP1 --> DP3
    
    APP2 --> DP3
    APP2 --> DP2
    
    UI1 --> APP2
    UI2 --> APP2
    UI3 --> APP2
    
    BI1 --> UI1
    
    APP1 --> INF1
    APP2 --> INF1
    ING2 --> INF2
    ING1 --> INF3
    
    INF1 --> MON1
    APP1 --> MON1
    APP2 --> MON1
    
    MON1 -->|Alerts| MON2
    MON2 --> MON3
    
    style DP1 fill:#4a90e2
    style DP2 fill:#50c878
    style DP3 fill:#f39c12
    style APP1 fill:#e74c3c
    style APP2 fill:#e74c3c
    style APP3 fill:#e74c3c
    style UI1 fill:#9b59b6
    style UI2 fill:#9b59b6
    style UI3 fill:#9b59b6
```

---

## Snowflake Layer Architecture

Detailed view of the Snowflake data warehouse layers and transformations.

```mermaid
graph LR
    subgraph "RAW Layer - Bronze/L1"
        R1[RAW.SALESFORCE_<br/>WORK_ORDERS]
        R2[RAW.SALESFORCE_<br/>PROPERTIES]
        R3[RAW.SALESFORCE_<br/>TECHNICIANS]
        R4[RAW.PROPERTY_<br/>UPLOADS]
        R5[RAW.IOT_<br/>TELEMETRY]
        R6[RAW.MOBILE_<br/>STATUS_UPDATES]
    end
    
    subgraph "STAGING Layer - Silver/L2"
        S1[STAGING.WORK_ORDERS<br/>SCD Type 2]
        S2[STAGING.PROPERTIES<br/>SCD Type 2]
        S3[STAGING.TECHNICIANS<br/>SCD Type 2]
        S4[STAGING.TELEMETRY_<br/>EVENTS]
        S5[STAGING.STATUS_<br/>UPDATES]
    end
    
    subgraph "ANALYTICS Layer - Gold/L3"
        direction TB
        subgraph "Dimensions"
            A1[DIM_PROPERTY]
            A2[DIM_TECHNICIAN]
            A3[DIM_DATE]
            A4[DIM_ZONE]
        end
        subgraph "Facts"
            A5[FACT_WORK_ORDER]
            A6[FACT_ROUTE]
            A7[FACT_ROUTE_STOP]
            A8[FACT_TECHNICIAN_<br/>AVAILABILITY]
        end
        subgraph "Aggregates"
            A9[AGG_DAILY_<br/>SUMMARY]
            A10[AGG_ROUTE_<br/>EFFICIENCY]
        end
    end
    
    subgraph "Transformation Logic"
        T1[Data Quality<br/>Validation]
        T2[Deduplication<br/>Hash-based]
        T3[SCD Type 2<br/>History Tracking]
        T4[Business Rules<br/>Application]
        T5[Star Schema<br/>Modeling]
    end
    
    R1 -->|Stream| T1
    R2 -->|Stream| T1
    R3 -->|Stream| T1
    R4 -->|Stream| T1
    R5 -->|Stream| T1
    R6 -->|Stream| T1
    
    T1 --> T2
    T2 --> T3
    T3 --> S1
    T3 --> S2
    T3 --> S3
    T3 --> S4
    T3 --> S5
    
    S1 --> T4
    S2 --> T4
    S3 --> T4
    
    T4 --> T5
    
    T5 --> A1
    T5 --> A2
    T5 --> A5
    T5 --> A6
    T5 --> A7
    
    A5 --> A9
    A6 --> A9
    A7 --> A10
    
    style R1 fill:#ffebee
    style R2 fill:#ffebee
    style R3 fill:#ffebee
    style R4 fill:#ffebee
    style R5 fill:#ffebee
    style R6 fill:#ffebee
    style S1 fill:#fff3e0
    style S2 fill:#fff3e0
    style S3 fill:#fff3e0
    style S4 fill:#fff3e0
    style S5 fill:#fff3e0
    style A1 fill:#e8f5e9
    style A2 fill:#e8f5e9
    style A3 fill:#e8f5e9
    style A4 fill:#e8f5e9
    style A5 fill:#e3f2fd
    style A6 fill:#e3f2fd
    style A7 fill:#e3f2fd
    style A8 fill:#e3f2fd
    style A9 fill:#f3e5f5
    style A10 fill:#f3e5f5
```

---

## Ontology Action Flow

Detailed flow of executing an Ontology Action through OSDK.

```mermaid
sequenceDiagram
    autonumber
    
    actor User as User
    participant UI as React Dashboard
    participant BE as Backend API
    participant OSDK as OSDK Client
    participant Ontology as Foundry Ontology
    participant Validation as Action Validator
    participant Execute as Action Executor
    participant Audit as Audit Logger
    
    User->>UI: Click "Assign Work Order<br/>to Technician"
    UI->>UI: Collect parameters:<br/>- workOrderId<br/>- technicianId<br/>- scheduledDate
    
    UI->>BE: POST /api/actions/assign-work-order
    BE->>OSDK: client.actions.AssignWorkOrder.execute(params)
    
    OSDK->>Ontology: Fetch WorkOrder object
    Ontology-->>OSDK: WorkOrder details
    
    OSDK->>Ontology: Fetch Technician object
    Ontology-->>OSDK: Technician details
    
    OSDK->>Validation: Validate action parameters
    
    Validation->>Validation: Check work order status = PENDING
    Validation->>Validation: Check technician has<br/>required skills
    Validation->>Validation: Check technician availability<br/>on scheduled date
    Validation->>Validation: Check time window constraints
    
    alt Validation Fails
        Validation-->>OSDK: Validation error
        OSDK-->>BE: Error response
        BE-->>UI: Display error message
        UI-->>User: "Cannot assign:<br/>Technician lacks skills"
    else Validation Passes
        Validation-->>OSDK: Validation passed
        
        OSDK->>Execute: Execute action logic
        
        Execute->>Ontology: Update WorkOrder.status<br/>= "ASSIGNED"
        Execute->>Ontology: Create or update<br/>Route object
        Execute->>Ontology: Create RouteStop object
        
        Ontology-->>Execute: Objects updated
        
        Execute->>Audit: Log action execution
        Audit-->>Execute: Logged
        
        Execute-->>OSDK: Execution result:<br/>assignmentId, success=true
        OSDK-->>BE: Action result
        BE-->>UI: Assignment successful
        UI-->>User: "Work order assigned<br/>to John Smith"
        
        UI->>UI: Refresh work order list
        UI->>UI: Trigger notification<br/>to technician
    end
```

---

## Foundry to MongoDB Sync Flow

Visualization of how optimization results flow from Foundry Ontology to MongoDB and back.

```mermaid
flowchart TD
    subgraph "Palantir Foundry"
        F1[Ontology Objects:<br/>WorkOrders, Technicians]
        F2[OSDK Query API]
    end
    
    subgraph "Optimization Engine"
        O1[Fetch Input Data<br/>via OSDK]
        O2[OR-Tools VRP Solver<br/>Constraint Satisfaction]
        O3[Route Generation<br/>Algorithm]
        O4[Result Validation<br/>& Quality Check]
    end
    
    subgraph "MongoDB Operational DB"
        M1[Collection:<br/>optimization_runs]
        M2[Collection:<br/>routes]
        M3[Collection:<br/>route_stops]
        M4[Change Streams<br/>Real-time Events]
    end
    
    subgraph "Write-back Pipeline"
        W1[Scheduled Job<br/>Nightly at 11 PM]
        W2[MongoDB<br/>Aggregation Query]
        W3[Transform to<br/>Snowflake Schema]
        W4[Snowflake COPY INTO<br/>MERGE Statement]
    end
    
    subgraph "Snowflake Analytics"
        S1[ANALYTICS.FACT_ROUTE]
        S2[ANALYTICS.FACT_ROUTE_STOP]
        S3[Foundry Incremental<br/>Sync - Next Day]
    end
    
    F1 --> F2
    F2 --> O1
    
    O1 --> O2
    O2 --> O3
    O3 --> O4
    
    O4 -->|Write| M1
    O4 -->|Write| M2
    O4 -->|Write| M3
    
    M2 --> M4
    M3 --> M4
    
    M4 -.->|Real-time Push| Dashboard[React Dashboard<br/>WebSocket]
    
    W1 --> W2
    M2 --> W2
    M3 --> W2
    
    W2 --> W3
    W3 --> W4
    
    W4 --> S1
    W4 --> S2
    
    S1 --> S3
    S2 --> S3
    S3 --> F1
    
    style F1 fill:#c8e6c9
    style F2 fill:#c8e6c9
    style O1 fill:#ffccbc
    style O2 fill:#ffccbc
    style O3 fill:#ffccbc
    style O4 fill:#ffccbc
    style M1 fill:#fff9c4
    style M2 fill:#fff9c4
    style M3 fill:#fff9c4
    style M4 fill:#fff59d
    style S1 fill:#bbdefb
    style S2 fill:#bbdefb
    style S3 fill:#90caf9
    style Dashboard fill:#e1bee7
```

---

## Network Architecture

Deployment and network architecture showing security zones and data flows.

```mermaid
graph TB
    subgraph "Public Internet"
        PUB1[Users<br/>Web Browser]
        PUB2[Mobile App<br/>Technicians]
        PUB3[External APIs<br/>Google Maps]
    end
    
    subgraph "DMZ - Public Subnet"
        DMZ1[Application Load<br/>Balancer]
        DMZ2[CloudFront CDN<br/>Static Assets]
        DMZ3[API Gateway]
    end
    
    subgraph "Application Tier - Private Subnet"
        APP1[React Dashboard<br/>ECS Service]
        APP2[Backend REST API<br/>ECS Service]
        APP3[Optimization Engine<br/>ECS Service]
        APP4[OSDK Integration<br/>ECS Service]
    end
    
    subgraph "Data Tier - Private Subnet"
        DATA1[MongoDB Atlas<br/>VPC Peering]
        DATA2[Redis Cache<br/>ElastiCache]
        DATA3[S3 Buckets<br/>File Storage]
    end
    
    subgraph "External SaaS Platforms"
        SAAS1[Snowflake<br/>Data Warehouse<br/>PrivateLink]
        SAAS2[Palantir Foundry<br/>Ontology Platform<br/>HTTPS]
        SAAS3[Informatica<br/>ETL Platform<br/>Secure Agent]
    end
    
    subgraph "Monitoring & Security"
        SEC1[AWS WAF<br/>Web Firewall]
        SEC2[VPC Flow Logs]
        SEC3[CloudWatch Logs]
        SEC4[Secrets Manager]
    end
    
    PUB1 -->|HTTPS| SEC1
    PUB2 -->|HTTPS| SEC1
    PUB3 -.->|API Calls| APP2
    
    SEC1 --> DMZ1
    DMZ1 --> DMZ2
    DMZ1 --> DMZ3
    
    DMZ2 --> APP1
    DMZ3 --> APP2
    
    APP1 --> APP2
    APP2 --> APP3
    APP2 --> APP4
    APP3 --> APP4
    
    APP2 --> DATA1
    APP2 --> DATA2
    APP3 --> DATA1
    APP2 --> DATA3
    
    APP4 -->|TLS 1.2+| SAAS2
    APP2 -->|PrivateLink| SAAS1
    SAAS3 -->|Secure Agent| SAAS1
    
    APP2 --> SEC4
    APP3 --> SEC4
    APP4 --> SEC4
    
    DMZ1 --> SEC2
    APP1 --> SEC3
    APP2 --> SEC3
    APP3 --> SEC3
    
    style SEC1 fill:#ef5350
    style SEC2 fill:#ef5350
    style SEC3 fill:#ef5350
    style SEC4 fill:#ef5350
    style DMZ1 fill:#ffa726
    style DMZ2 fill:#ffa726
    style DMZ3 fill:#ffa726
    style APP1 fill:#66bb6a
    style APP2 fill:#66bb6a
    style APP3 fill:#66bb6a
    style APP4 fill:#66bb6a
    style DATA1 fill:#42a5f5
    style DATA2 fill:#42a5f5
    style DATA3 fill:#42a5f5
    style SAAS1 fill:#ab47bc
    style SAAS2 fill:#ab47bc
    style SAAS3 fill:#ab47bc
```

---

## Optimization Algorithm Flow

Internal flow of the route optimization algorithm.

```mermaid
flowchart TD
    START[Start Optimization] --> INPUT[Load Input Data]
    
    INPUT --> PARSE[Parse Work Orders<br/>& Technicians]
    
    PARSE --> MATRIX[Build Distance Matrix<br/>All locations ↔ All locations]
    
    MATRIX --> CONSTRAINTS[Define Constraints]
    
    CONSTRAINTS --> C1[Time Window<br/>Constraints]
    CONSTRAINTS --> C2[Skill Matching<br/>Constraints]
    CONSTRAINTS --> C3[Capacity Constraints<br/>Max hours/distance]
    CONSTRAINTS --> C4[Start/End Location<br/>Technician home]
    
    C1 --> MODEL
    C2 --> MODEL
    C3 --> MODEL
    C4 --> MODEL
    
    MODEL[Create OR-Tools<br/>VRP Model]
    
    MODEL --> OBJECTIVE[Define Objective<br/>Function]
    
    OBJECTIVE --> OBJ1[Minimize total<br/>travel distance]
    OBJECTIVE --> OBJ2[Weighted priority<br/>score]
    OBJECTIVE --> OBJ3[Balance workload<br/>across technicians]
    
    OBJ1 --> SOLVE
    OBJ2 --> SOLVE
    OBJ3 --> SOLVE
    
    SOLVE[Run Solver<br/>Time limit: 5 min]
    
    SOLVE --> CHECK{Solution<br/>Found?}
    
    CHECK -->|No feasible<br/>solution| RELAX[Relax Constraints<br/>Progressively]
    
    RELAX --> RELAX1[Remove low-priority<br/>work orders]
    RELAX1 --> RELAX2[Increase max<br/>hours limit]
    RELAX2 --> RELAX3[Loosen time<br/>windows]
    RELAX3 --> SOLVE
    
    CHECK -->|Yes| VALIDATE[Validate Solution]
    
    VALIDATE --> V1{All constraints<br/>satisfied?}
    
    V1 -->|No| REJECT[Flag violations<br/>Log errors]
    REJECT --> MANUAL[Return partial<br/>solution for manual<br/>review]
    
    V1 -->|Yes| QUALITY[Calculate Quality<br/>Metrics]
    
    QUALITY --> Q1[Total distance]
    QUALITY --> Q2[Total duration]
    QUALITY --> Q3[Workload balance]
    QUALITY --> Q4[Work order coverage]
    
    Q1 --> OUTPUT
    Q2 --> OUTPUT
    Q3 --> OUTPUT
    Q4 --> OUTPUT
    
    OUTPUT[Generate Output]
    
    OUTPUT --> OUT1[Create Route objects]
    OUTPUT --> OUT2[Create RouteStop objects<br/>with sequence]
    OUTPUT --> OUT3[Calculate metrics<br/>& statistics]
    
    OUT1 --> WRITE
    OUT2 --> WRITE
    OUT3 --> WRITE
    
    WRITE[Write to MongoDB]
    
    WRITE --> NOTIFY[Send Notifications]
    
    NOTIFY --> END[End Optimization]
    
    MANUAL --> END
    
    style START fill:#4caf50,color:#fff
    style END fill:#f44336,color:#fff
    style SOLVE fill:#ff9800
    style CHECK fill:#2196f3,color:#fff
    style V1 fill:#2196f3,color:#fff
    style REJECT fill:#f44336,color:#fff
    style WRITE fill:#9c27b0,color:#fff
```

---

## Data Lineage Diagram

Tracking data lineage from source to consumption.

```mermaid
graph LR
    subgraph "Source"
        S1[Salesforce<br/>Work Order Created<br/>2024-02-12 10:00 AM]
    end
    
    subgraph "Ingestion - L1"
        I1[EventBridge Event<br/>event-12345<br/>2024-02-12 10:01 AM]
        I2[Lambda Function<br/>ETL-handler<br/>2024-02-12 10:01 AM]
        I3[RAW.SALESFORCE_<br/>WORK_ORDERS<br/>RAW_ID: abc-123<br/>2024-02-12 10:03 AM]
    end
    
    subgraph "Transformation - L2"
        T1[Snowflake Stream<br/>Detected Change<br/>2024-02-12 10:05 AM]
        T2[Scheduled Task<br/>PROCESS_WORK_ORDERS<br/>2024-02-12 10:05 AM]
        T3[STAGING.WORK_ORDERS<br/>WORK_ORDER_SK: 456<br/>2024-02-12 10:08 AM]
    end
    
    subgraph "Analytics - L3"
        A1[ETL Logic<br/>Star Schema Mapping<br/>2024-02-12 10:10 AM]
        A2[ANALYTICS.FACT_<br/>WORK_ORDER<br/>WORK_ORDER_ID: WO-789<br/>2024-02-12 10:12 AM]
    end
    
    subgraph "Consumption"
        C1[Foundry Sync<br/>Incremental Pull<br/>2024-02-12 10:30 AM]
        C2[Ontology Object<br/>WorkOrder: WO-789<br/>2024-02-12 10:32 AM]
        C3[OSDK Query<br/>Optimization Engine<br/>2024-02-12 08:00 PM]
        C4[Route Generated<br/>ROUTE-2024-02-13-001<br/>2024-02-12 08:02 PM]
    end
    
    S1 -->|CDC Event| I1
    I1 --> I2
    I2 -->|ETL_BATCH_ID:<br/>batch-2024-02-12-1001| I3
    
    I3 -->|Stream| T1
    T1 --> T2
    T2 -->|Transform<br/>+ SCD Type 2| T3
    
    T3 -->|Business Rules<br/>+ Joins| A1
    A1 --> A2
    
    A2 -->|Dataset Sync| C1
    C1 --> C2
    C2 -->|OSDK API| C3
    C3 -->|Optimization<br/>Algorithm| C4
    
    style S1 fill:#e3f2fd
    style I3 fill:#ffebee
    style T3 fill:#fff3e0
    style A2 fill:#e8f5e9
    style C2 fill:#f3e5f5
    style C4 fill:#fff9c4
    
    A2 -.->|Audit Trail<br/>Query Lineage| AUDIT[Data Lineage<br/>Report]
    style AUDIT fill:#ffccbc
```

---

## Error Handling and Retry Flow

Comprehensive error handling across the system.

```mermaid
flowchart TD
    START[Operation Start] --> EXECUTE[Execute Operation]
    
    EXECUTE --> CHECK{Success?}
    
    CHECK -->|Yes| SUCCESS[Log Success<br/>Return Result]
    SUCCESS --> END_SUCCESS[End: Success]
    
    CHECK -->|No| ERROR_TYPE{Error Type?}
    
    ERROR_TYPE -->|Network/Timeout| RETRY{Retry Count<br/>< Max?}
    ERROR_TYPE -->|Validation Error| LOG_VAL[Log Validation<br/>Error Details]
    ERROR_TYPE -->|Data Quality| QUARANTINE[Move to<br/>Quarantine Table]
    ERROR_TYPE -->|System Error| CRITICAL[Critical Error<br/>Handler]
    
    RETRY -->|Yes| BACKOFF[Exponential<br/>Backoff Delay]
    BACKOFF --> WAIT[Wait: 2^n seconds]
    WAIT --> INCREMENT[Increment<br/>Retry Count]
    INCREMENT --> EXECUTE
    
    RETRY -->|No, Max<br/>Reached| EXHAUST[Max Retries<br/>Exhausted]
    
    LOG_VAL --> DLQ[Dead Letter<br/>Queue]
    QUARANTINE --> DLQ
    EXHAUST --> DLQ
    
    DLQ --> ALERT{Error Rate<br/>> Threshold?}
    
    ALERT -->|Yes| PAGE[PagerDuty<br/>Alert: P2]
    ALERT -->|No| SLACK[Slack<br/>Notification]
    
    PAGE --> ONCALL[On-call Engineer<br/>Investigates]
    SLACK --> LOG_SYSTEM[Log to<br/>Monitoring System]
    
    ONCALL --> LOG_SYSTEM
    
    CRITICAL --> PAGE_P1[PagerDuty<br/>Alert: P1]
    PAGE_P1 --> ONCALL
    
    LOG_SYSTEM --> REVIEW[Manual Review<br/>Required]
    
    REVIEW --> REPLAY{Can<br/>Replay?}
    
    REPLAY -->|Yes| REPROCESS[Reprocess from<br/>Quarantine]
    REPROCESS --> EXECUTE
    
    REPLAY -->|No| MANUAL_FIX[Manual Data<br/>Correction]
    MANUAL_FIX --> END_MANUAL[End: Manual Fix]
    
    style START fill:#4caf50,color:#fff
    style END_SUCCESS fill:#4caf50,color:#fff
    style SUCCESS fill:#81c784
    style ERROR_TYPE fill:#ff9800,color:#fff
    style CRITICAL fill:#f44336,color:#fff
    style PAGE fill:#f44336,color:#fff
    style PAGE_P1 fill:#d32f2f,color:#fff
    style DLQ fill:#ffcc80
    style QUARANTINE fill:#ffcc80
    style REVIEW fill:#64b5f6
    style END_MANUAL fill:#9e9e9e
```

---

## Appendix: Diagram Legend

### Node Colors and Meanings

- **Blue tones**: Data storage and persistence layers
- **Green tones**: Palantir Foundry and Ontology components
- **Orange tones**: ETL and transformation processes
- **Red tones**: Optimization and algorithmic components
- **Purple tones**: User interface and frontend
- **Yellow tones**: MongoDB and operational databases
- **Gray tones**: Infrastructure and monitoring

### Relationship Types

- **Solid lines**: Direct data flow or API calls
- **Dashed lines**: Async/scheduled processes or write-backs
- **Arrows**: Direction of data flow
- **Double arrows**: Bidirectional sync or communication

### Diagram Tools

All diagrams in this document use Mermaid syntax and can be:
- Rendered in GitHub, GitLab, Bitbucket
- Embedded in Confluence or Notion
- Exported to PNG/SVG using Mermaid CLI
- Edited using Mermaid Live Editor (https://mermaid.live)

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2024-02-12 | Data Architecture Team | Initial creation of all diagrams |

---

## Related Documentation

- [Ontology Model Documentation](./ontology_model.md)
- [Data Flow Documentation](./data_flow.md)
- Backend API Technical Design
- Frontend Architecture Guide
- Optimization Algorithm Specification
