/*==============================================================================
 * FIELD SERVICE OPERATIONS - RAW LAYER TABLES
 *
 * Purpose: Create raw ingestion tables for field service route optimization
 * Author: Route Optimization Team
 * Created: 2026-02-12
 *
 * Tables:
 *   - RAW.PROPERTIES: Property master data
 *   - RAW.TECHNICIANS: Technician master data
 *   - RAW.WORK_ORDERS: Work order transactions
 *   - RAW.ROUTES: Optimized route plans
 *   - RAW.ROUTE_STOPS: Individual stops within routes
 *
 * Notes:
 *   - Minimal transformation applied at this layer
 *   - VARIANT columns for semi-structured data
 *   - All timestamps in UTC
 *   - Source system tracking for data lineage
 *============================================================================*/

USE ROLE ADMIN_ROLE;
USE DATABASE FIELD_SERVICE_OPS;
USE SCHEMA RAW;
USE WAREHOUSE INGEST_WH;

/*------------------------------------------------------------------------------
 * TABLE: RAW.PROPERTIES
 * Description: Property master data including location and characteristics
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE TABLE RAW.PROPERTIES (
    -- Primary Key
    property_id VARCHAR(50) NOT NULL,

    -- Address Information
    address VARCHAR(500) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(2) NOT NULL,
    zip_code VARCHAR(10) NOT NULL,

    -- Geographic Coordinates (WGS84)
    lat FLOAT NOT NULL,
    lng FLOAT NOT NULL,

    -- Property Characteristics
    property_type VARCHAR(50) NOT NULL,  -- residential, commercial, industrial
    zone_id VARCHAR(50),
    square_footage NUMBER(10,2),

    -- Service Access Information
    access_notes VARCHAR(2000),

    -- Audit Fields
    created_at TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),

    -- Metadata
    source_system VARCHAR(100),
    ingestion_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Constraints
    CONSTRAINT pk_properties PRIMARY KEY (property_id),
    CONSTRAINT chk_property_type CHECK (property_type IN ('residential', 'commercial', 'industrial')),
    CONSTRAINT chk_state CHECK (LENGTH(state) = 2),
    CONSTRAINT chk_lat CHECK (lat BETWEEN -90 AND 90),
    CONSTRAINT chk_lng CHECK (lng BETWEEN -180 AND 180)
)
COMMENT = 'Raw property master data with location and characteristics';

-- Add clustering for performance optimization
ALTER TABLE RAW.PROPERTIES CLUSTER BY (zone_id, city);

/*------------------------------------------------------------------------------
 * TABLE: RAW.TECHNICIANS
 * Description: Technician master data including skills and availability
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE TABLE RAW.TECHNICIANS (
    -- Primary Key
    technician_id VARCHAR(50) NOT NULL,

    -- Personal Information
    name VARCHAR(200) NOT NULL,
    email VARCHAR(200),
    phone VARCHAR(20),

    -- Home Location (starting point for routes)
    home_lat FLOAT NOT NULL,
    home_lng FLOAT NOT NULL,

    -- Skills and Capabilities (JSON array)
    skills VARIANT,  -- e.g., ["HVAC", "electrical", "plumbing"]

    -- Daily Constraints
    max_daily_hours NUMBER(5,2) DEFAULT 8.0,
    max_daily_distance_miles NUMBER(6,2) DEFAULT 150.0,

    -- Financial
    hourly_rate NUMBER(8,2),

    -- Status and Preferences
    availability_status VARCHAR(50) DEFAULT 'active',  -- active, on_leave, inactive
    zone_preference VARCHAR(50),  -- Preferred zone for assignments

    -- Audit Fields
    created_at TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),

    -- Metadata
    source_system VARCHAR(100),
    ingestion_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Constraints
    CONSTRAINT pk_technicians PRIMARY KEY (technician_id),
    CONSTRAINT chk_tech_lat CHECK (home_lat BETWEEN -90 AND 90),
    CONSTRAINT chk_tech_lng CHECK (home_lng BETWEEN -180 AND 180),
    CONSTRAINT chk_availability CHECK (availability_status IN ('active', 'on_leave', 'inactive')),
    CONSTRAINT chk_max_hours CHECK (max_daily_hours > 0 AND max_daily_hours <= 24),
    CONSTRAINT chk_max_distance CHECK (max_daily_distance_miles > 0)
)
COMMENT = 'Raw technician master data with skills, availability, and constraints';

/*------------------------------------------------------------------------------
 * TABLE: RAW.WORK_ORDERS
 * Description: Work order transactions requiring service visits
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE TABLE RAW.WORK_ORDERS (
    -- Primary Key
    work_order_id VARCHAR(50) NOT NULL,

    -- Related Property
    property_id VARCHAR(50) NOT NULL,

    -- Work Order Details
    title VARCHAR(500) NOT NULL,
    description VARCHAR(4000),

    -- Classification
    category VARCHAR(50) NOT NULL,  -- HVAC, plumbing, electrical, general, inspection
    priority VARCHAR(20) NOT NULL,  -- emergency, high, medium, low

    -- Requirements
    required_skills VARIANT,  -- JSON array of required skills
    estimated_duration_minutes NUMBER(5,0) NOT NULL,

    -- Scheduling Constraints
    time_window_start TIMESTAMP_NTZ,  -- Earliest acceptable start time
    time_window_end TIMESTAMP_NTZ,    -- Latest acceptable start time

    -- Status
    status VARCHAR(50) NOT NULL DEFAULT 'pending',  -- pending, scheduled, in_progress, completed, cancelled

    -- Completion Information
    assigned_technician_id VARCHAR(50),
    scheduled_date DATE,
    completed_at TIMESTAMP_NTZ,

    -- Audit Fields
    created_at TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),

    -- Metadata
    source_system VARCHAR(100),
    ingestion_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Constraints
    CONSTRAINT pk_work_orders PRIMARY KEY (work_order_id),
    CONSTRAINT chk_category CHECK (category IN ('HVAC', 'plumbing', 'electrical', 'general', 'inspection')),
    CONSTRAINT chk_priority CHECK (priority IN ('emergency', 'high', 'medium', 'low')),
    CONSTRAINT chk_status CHECK (status IN ('pending', 'scheduled', 'in_progress', 'completed', 'cancelled')),
    CONSTRAINT chk_time_window CHECK (time_window_end IS NULL OR time_window_start IS NULL OR time_window_end > time_window_start),
    CONSTRAINT chk_duration CHECK (estimated_duration_minutes > 0)
)
COMMENT = 'Raw work order transactions with service requirements and constraints';

-- Add clustering for query performance
ALTER TABLE RAW.WORK_ORDERS CLUSTER BY (status, scheduled_date, priority);

/*------------------------------------------------------------------------------
 * TABLE: RAW.ROUTES
 * Description: Optimized route plans for technicians
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE TABLE RAW.ROUTES (
    -- Primary Key
    route_id VARCHAR(50) NOT NULL,

    -- Optimization Context
    optimization_run_id VARCHAR(50) NOT NULL,  -- Links routes from same optimization run

    -- Assignment
    technician_id VARCHAR(50) NOT NULL,
    route_date DATE NOT NULL,

    -- Route Metrics
    total_distance_miles NUMBER(8,2),
    total_duration_minutes NUMBER(6,0),
    num_stops NUMBER(3,0) DEFAULT 0,

    -- Optimization Metadata
    algorithm_used VARCHAR(100),  -- nearest_neighbor, genetic_algorithm, or_tools, etc.
    optimization_score NUMBER(10,4),  -- Algorithm-specific quality score
    computation_time_seconds NUMBER(8,2),

    -- Status
    route_status VARCHAR(50) DEFAULT 'planned',  -- planned, in_progress, completed, cancelled

    -- Audit Fields
    created_at TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Metadata
    source_system VARCHAR(100),
    ingestion_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Constraints
    CONSTRAINT pk_routes PRIMARY KEY (route_id),
    CONSTRAINT chk_route_status CHECK (route_status IN ('planned', 'in_progress', 'completed', 'cancelled')),
    CONSTRAINT chk_num_stops CHECK (num_stops >= 0),
    CONSTRAINT chk_total_distance CHECK (total_distance_miles IS NULL OR total_distance_miles >= 0),
    CONSTRAINT chk_total_duration CHECK (total_duration_minutes IS NULL OR total_duration_minutes >= 0)
)
COMMENT = 'Raw optimized route plans with metrics and algorithm metadata';

-- Add clustering for query performance
ALTER TABLE RAW.ROUTES CLUSTER BY (route_date, technician_id);

/*------------------------------------------------------------------------------
 * TABLE: RAW.ROUTE_STOPS
 * Description: Individual stops within routes (work order visits)
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE TABLE RAW.ROUTE_STOPS (
    -- Primary Key
    stop_id VARCHAR(50) NOT NULL,

    -- Foreign Keys
    route_id VARCHAR(50) NOT NULL,
    work_order_id VARCHAR(50) NOT NULL,

    -- Sequence Information
    sequence_number NUMBER(3,0) NOT NULL,  -- Order of visit in route (1, 2, 3, ...)

    -- Timing
    arrival_time TIMESTAMP_NTZ,
    departure_time TIMESTAMP_NTZ,
    actual_duration_minutes NUMBER(5,0),

    -- Travel from previous stop
    travel_distance_miles NUMBER(8,2),
    travel_duration_minutes NUMBER(5,0),

    -- Status
    stop_status VARCHAR(50) DEFAULT 'planned',  -- planned, arrived, in_service, completed, skipped

    -- Notes
    notes VARCHAR(2000),

    -- Audit Fields
    created_at TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Metadata
    source_system VARCHAR(100),
    ingestion_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Constraints
    CONSTRAINT pk_route_stops PRIMARY KEY (stop_id),
    CONSTRAINT chk_stop_status CHECK (stop_status IN ('planned', 'arrived', 'in_service', 'completed', 'skipped')),
    CONSTRAINT chk_sequence CHECK (sequence_number > 0),
    CONSTRAINT chk_timing CHECK (departure_time IS NULL OR arrival_time IS NULL OR departure_time >= arrival_time),
    CONSTRAINT chk_travel_distance CHECK (travel_distance_miles IS NULL OR travel_distance_miles >= 0),
    CONSTRAINT chk_travel_duration CHECK (travel_duration_minutes IS NULL OR travel_duration_minutes >= 0)
)
COMMENT = 'Raw route stops with sequencing, timing, and travel metrics';

-- Add clustering for query performance
ALTER TABLE RAW.ROUTE_STOPS CLUSTER BY (route_id, sequence_number);

/*------------------------------------------------------------------------------
 * INDEXES FOR FOREIGN KEY RELATIONSHIPS
 * Note: Snowflake uses micro-partitions; these are logical for documentation
 *----------------------------------------------------------------------------*/

-- Work orders to properties relationship
-- Query pattern: Find all work orders for a property
-- Already optimized via clustering

-- Route stops to routes relationship
-- Query pattern: Find all stops for a route
-- Already optimized via clustering

-- Routes to technicians relationship
-- Query pattern: Find all routes for a technician
-- Already optimized via clustering

/*------------------------------------------------------------------------------
 * TABLE COMMENTS AND DOCUMENTATION
 *----------------------------------------------------------------------------*/

-- Add column comments for better documentation
ALTER TABLE RAW.PROPERTIES MODIFY COLUMN property_id
    COMMENT 'Unique identifier for property';

ALTER TABLE RAW.PROPERTIES MODIFY COLUMN lat
    COMMENT 'Latitude in WGS84 decimal degrees (-90 to 90)';

ALTER TABLE RAW.PROPERTIES MODIFY COLUMN lng
    COMMENT 'Longitude in WGS84 decimal degrees (-180 to 180)';

ALTER TABLE RAW.TECHNICIANS MODIFY COLUMN skills
    COMMENT 'JSON array of technician skills, e.g., ["HVAC", "electrical"]';

ALTER TABLE RAW.WORK_ORDERS MODIFY COLUMN required_skills
    COMMENT 'JSON array of required skills for work order';

ALTER TABLE RAW.ROUTES MODIFY COLUMN optimization_run_id
    COMMENT 'Groups routes generated in same optimization batch';

ALTER TABLE RAW.ROUTE_STOPS MODIFY COLUMN sequence_number
    COMMENT 'Order of visit in route, starting at 1';

/*------------------------------------------------------------------------------
 * VERIFICATION QUERIES
 *----------------------------------------------------------------------------*/

-- Verify table creation
SHOW TABLES IN SCHEMA RAW;

-- Show table details
DESC TABLE RAW.PROPERTIES;
DESC TABLE RAW.TECHNICIANS;
DESC TABLE RAW.WORK_ORDERS;
DESC TABLE RAW.ROUTES;
DESC TABLE RAW.ROUTE_STOPS;

-- Verify clustering
SHOW TABLES LIKE '%' IN SCHEMA RAW;

/*==============================================================================
 * END OF SCRIPT
 *============================================================================*/
