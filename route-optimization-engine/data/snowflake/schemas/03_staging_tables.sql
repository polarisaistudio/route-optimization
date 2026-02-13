/*==============================================================================
 * FIELD SERVICE OPERATIONS - STAGING LAYER TABLES
 *
 * Purpose: Create staging tables with data quality, deduplication, and CDC
 * Author: Route Optimization Team
 * Created: 2026-02-12
 *
 * Features:
 *   - Data quality validations
 *   - Deduplication logic
 *   - Type casting and standardization
 *   - Stream-based CDC from RAW to STAGING
 *   - Data lineage tracking
 *
 * Processing Pattern:
 *   RAW (landing) -> STREAMS (CDC) -> STAGING (cleansed) -> ANALYTICS (dimensional)
 *============================================================================*/

USE ROLE ADMIN_ROLE;
USE DATABASE FIELD_SERVICE_OPS;
USE SCHEMA STAGING;
USE WAREHOUSE COMPUTE_WH;

/*------------------------------------------------------------------------------
 * TABLE: STAGING.PROPERTIES
 * Description: Cleansed and validated property data
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE TABLE STAGING.PROPERTIES (
    -- Primary Key
    property_id VARCHAR(50) NOT NULL,

    -- Address Information (standardized)
    address VARCHAR(500) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(2) NOT NULL,
    zip_code VARCHAR(10) NOT NULL,
    full_address VARCHAR(1000),  -- Computed: concatenated address

    -- Geographic Coordinates (validated)
    lat FLOAT NOT NULL,
    lng FLOAT NOT NULL,

    -- Property Characteristics (standardized)
    property_type VARCHAR(50) NOT NULL,
    zone_id VARCHAR(50),
    square_footage NUMBER(10,2),

    -- Service Access Information
    access_notes VARCHAR(2000),

    -- Data Quality Flags
    is_valid_coordinates BOOLEAN,
    is_complete BOOLEAN,
    data_quality_score NUMBER(3,0),  -- 0-100 score

    -- Audit Fields
    created_at TIMESTAMP_NTZ NOT NULL,
    updated_at TIMESTAMP_NTZ NOT NULL,
    valid_from TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    valid_to TIMESTAMP_NTZ DEFAULT TO_TIMESTAMP_NTZ('9999-12-31 23:59:59'),
    is_current BOOLEAN DEFAULT TRUE,

    -- Metadata
    source_system VARCHAR(100),
    raw_ingestion_timestamp TIMESTAMP_NTZ,
    staging_load_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    record_hash VARCHAR(64),  -- MD5 hash for change detection

    -- Constraints
    CONSTRAINT pk_staging_properties PRIMARY KEY (property_id),
    CONSTRAINT chk_stg_property_type CHECK (property_type IN ('residential', 'commercial', 'industrial')),
    CONSTRAINT chk_stg_state CHECK (LENGTH(state) = 2)
)
COMMENT = 'Staging properties with data quality validations and cleansing';

/*------------------------------------------------------------------------------
 * TABLE: STAGING.TECHNICIANS
 * Description: Cleansed and validated technician data
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE TABLE STAGING.TECHNICIANS (
    -- Primary Key
    technician_id VARCHAR(50) NOT NULL,

    -- Personal Information (standardized)
    name VARCHAR(200) NOT NULL,
    email VARCHAR(200),
    phone VARCHAR(20),

    -- Home Location (validated)
    home_lat FLOAT NOT NULL,
    home_lng FLOAT NOT NULL,

    -- Skills (parsed and validated)
    skills VARIANT,
    skills_array ARRAY,  -- Parsed array for easier querying
    skill_count NUMBER(3,0),

    -- Daily Constraints
    max_daily_hours NUMBER(5,2) DEFAULT 8.0,
    max_daily_distance_miles NUMBER(6,2) DEFAULT 150.0,

    -- Financial
    hourly_rate NUMBER(8,2),

    -- Status and Preferences
    availability_status VARCHAR(50) DEFAULT 'active',
    zone_preference VARCHAR(50),

    -- Data Quality Flags
    is_valid_coordinates BOOLEAN,
    is_valid_email BOOLEAN,
    is_complete BOOLEAN,
    data_quality_score NUMBER(3,0),

    -- Audit Fields
    created_at TIMESTAMP_NTZ NOT NULL,
    updated_at TIMESTAMP_NTZ NOT NULL,
    valid_from TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    valid_to TIMESTAMP_NTZ DEFAULT TO_TIMESTAMP_NTZ('9999-12-31 23:59:59'),
    is_current BOOLEAN DEFAULT TRUE,

    -- Metadata
    source_system VARCHAR(100),
    raw_ingestion_timestamp TIMESTAMP_NTZ,
    staging_load_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    record_hash VARCHAR(64),

    -- Constraints
    CONSTRAINT pk_staging_technicians PRIMARY KEY (technician_id),
    CONSTRAINT chk_stg_availability CHECK (availability_status IN ('active', 'on_leave', 'inactive'))
)
COMMENT = 'Staging technicians with skills parsing and data quality validations';

/*------------------------------------------------------------------------------
 * TABLE: STAGING.WORK_ORDERS
 * Description: Cleansed and validated work order data
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE TABLE STAGING.WORK_ORDERS (
    -- Primary Key
    work_order_id VARCHAR(50) NOT NULL,

    -- Related Property
    property_id VARCHAR(50) NOT NULL,

    -- Work Order Details
    title VARCHAR(500) NOT NULL,
    description VARCHAR(4000),

    -- Classification (standardized)
    category VARCHAR(50) NOT NULL,
    priority VARCHAR(20) NOT NULL,
    priority_rank NUMBER(1,0),  -- 1=emergency, 2=high, 3=medium, 4=low

    -- Requirements
    required_skills VARIANT,
    required_skills_array ARRAY,
    estimated_duration_minutes NUMBER(5,0) NOT NULL,
    estimated_duration_hours NUMBER(5,2),  -- Computed

    -- Scheduling Constraints (validated)
    time_window_start TIMESTAMP_NTZ,
    time_window_end TIMESTAMP_NTZ,
    time_window_hours NUMBER(5,2),  -- Duration of time window
    is_time_constrained BOOLEAN,

    -- Status
    status VARCHAR(50) NOT NULL DEFAULT 'pending',

    -- Completion Information
    assigned_technician_id VARCHAR(50),
    scheduled_date DATE,
    completed_at TIMESTAMP_NTZ,

    -- Data Quality Flags
    is_valid_time_window BOOLEAN,
    has_property_match BOOLEAN,
    has_technician_match BOOLEAN,
    is_complete BOOLEAN,
    data_quality_score NUMBER(3,0),

    -- Audit Fields
    created_at TIMESTAMP_NTZ NOT NULL,
    updated_at TIMESTAMP_NTZ NOT NULL,

    -- Metadata
    source_system VARCHAR(100),
    raw_ingestion_timestamp TIMESTAMP_NTZ,
    staging_load_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    record_hash VARCHAR(64),

    -- Constraints
    CONSTRAINT pk_staging_work_orders PRIMARY KEY (work_order_id),
    CONSTRAINT chk_stg_category CHECK (category IN ('HVAC', 'plumbing', 'electrical', 'general', 'inspection')),
    CONSTRAINT chk_stg_priority CHECK (priority IN ('emergency', 'high', 'medium', 'low')),
    CONSTRAINT chk_stg_status CHECK (status IN ('pending', 'scheduled', 'in_progress', 'completed', 'cancelled'))
)
COMMENT = 'Staging work orders with enhanced validations and computed fields';

/*------------------------------------------------------------------------------
 * TABLE: STAGING.ROUTES
 * Description: Cleansed and validated route data
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE TABLE STAGING.ROUTES (
    -- Primary Key
    route_id VARCHAR(50) NOT NULL,

    -- Optimization Context
    optimization_run_id VARCHAR(50) NOT NULL,

    -- Assignment
    technician_id VARCHAR(50) NOT NULL,
    route_date DATE NOT NULL,

    -- Route Metrics
    total_distance_miles NUMBER(8,2),
    total_duration_minutes NUMBER(6,0),
    total_duration_hours NUMBER(6,2),
    num_stops NUMBER(3,0) DEFAULT 0,

    -- Computed Metrics
    avg_distance_per_stop NUMBER(8,2),
    avg_duration_per_stop NUMBER(6,2),
    utilization_percentage NUMBER(5,2),  -- Percentage of max_daily_hours used

    -- Optimization Metadata
    algorithm_used VARCHAR(100),
    optimization_score NUMBER(10,4),
    computation_time_seconds NUMBER(8,2),

    -- Status
    route_status VARCHAR(50) DEFAULT 'planned',

    -- Data Quality Flags
    has_technician_match BOOLEAN,
    is_within_constraints BOOLEAN,  -- Respects technician max hours/distance
    is_complete BOOLEAN,
    data_quality_score NUMBER(3,0),

    -- Audit Fields
    created_at TIMESTAMP_NTZ NOT NULL,
    updated_at TIMESTAMP_NTZ,

    -- Metadata
    source_system VARCHAR(100),
    raw_ingestion_timestamp TIMESTAMP_NTZ,
    staging_load_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    record_hash VARCHAR(64),

    -- Constraints
    CONSTRAINT pk_staging_routes PRIMARY KEY (route_id),
    CONSTRAINT chk_stg_route_status CHECK (route_status IN ('planned', 'in_progress', 'completed', 'cancelled'))
)
COMMENT = 'Staging routes with computed metrics and constraint validations';

/*------------------------------------------------------------------------------
 * TABLE: STAGING.ROUTE_STOPS
 * Description: Cleansed and validated route stop data
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE TABLE STAGING.ROUTE_STOPS (
    -- Primary Key
    stop_id VARCHAR(50) NOT NULL,

    -- Foreign Keys
    route_id VARCHAR(50) NOT NULL,
    work_order_id VARCHAR(50) NOT NULL,

    -- Sequence Information
    sequence_number NUMBER(3,0) NOT NULL,
    is_first_stop BOOLEAN,
    is_last_stop BOOLEAN,

    -- Timing
    arrival_time TIMESTAMP_NTZ,
    departure_time TIMESTAMP_NTZ,
    actual_duration_minutes NUMBER(5,0),

    -- Travel from previous stop
    travel_distance_miles NUMBER(8,2),
    travel_duration_minutes NUMBER(5,0),

    -- Status
    stop_status VARCHAR(50) DEFAULT 'planned',

    -- Notes
    notes VARCHAR(2000),

    -- Data Quality Flags
    has_route_match BOOLEAN,
    has_work_order_match BOOLEAN,
    is_valid_timing BOOLEAN,
    is_complete BOOLEAN,
    data_quality_score NUMBER(3,0),

    -- Audit Fields
    created_at TIMESTAMP_NTZ NOT NULL,
    updated_at TIMESTAMP_NTZ,

    -- Metadata
    source_system VARCHAR(100),
    raw_ingestion_timestamp TIMESTAMP_NTZ,
    staging_load_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    record_hash VARCHAR(64),

    -- Constraints
    CONSTRAINT pk_staging_route_stops PRIMARY KEY (stop_id),
    CONSTRAINT chk_stg_stop_status CHECK (stop_status IN ('planned', 'arrived', 'in_service', 'completed', 'skipped'))
)
COMMENT = 'Staging route stops with sequence flags and relationship validations';

/*==============================================================================
 * STREAMS FOR CHANGE DATA CAPTURE (CDC)
 *
 * Purpose: Track changes in RAW tables to incrementally load STAGING tables
 *============================================================================*/

-- Stream for RAW.PROPERTIES changes
CREATE OR REPLACE STREAM RAW.PROPERTIES_STREAM
ON TABLE RAW.PROPERTIES
COMMENT = 'CDC stream for properties table';

-- Stream for RAW.TECHNICIANS changes
CREATE OR REPLACE STREAM RAW.TECHNICIANS_STREAM
ON TABLE RAW.TECHNICIANS
COMMENT = 'CDC stream for technicians table';

-- Stream for RAW.WORK_ORDERS changes
CREATE OR REPLACE STREAM RAW.WORK_ORDERS_STREAM
ON TABLE RAW.WORK_ORDERS
COMMENT = 'CDC stream for work orders table';

-- Stream for RAW.ROUTES changes
CREATE OR REPLACE STREAM RAW.ROUTES_STREAM
ON TABLE RAW.ROUTES
COMMENT = 'CDC stream for routes table';

-- Stream for RAW.ROUTE_STOPS changes
CREATE OR REPLACE STREAM RAW.ROUTE_STOPS_STREAM
ON TABLE RAW.ROUTE_STOPS
COMMENT = 'CDC stream for route stops table';

/*==============================================================================
 * MERGE PROCEDURES: RAW TO STAGING
 *
 * Purpose: Load and transform data from RAW to STAGING with quality checks
 *============================================================================*/

/*------------------------------------------------------------------------------
 * PROCEDURE: Load STAGING.PROPERTIES from RAW.PROPERTIES
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE STAGING.LOAD_PROPERTIES()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    -- Merge from stream to staging with transformations and quality checks
    MERGE INTO STAGING.PROPERTIES AS target
    USING (
        SELECT
            property_id,
            UPPER(TRIM(address)) AS address,
            UPPER(TRIM(city)) AS city,
            UPPER(TRIM(state)) AS state,
            TRIM(zip_code) AS zip_code,
            CONCAT(UPPER(TRIM(address)), ', ', UPPER(TRIM(city)), ', ',
                   UPPER(TRIM(state)), ' ', TRIM(zip_code)) AS full_address,
            lat,
            lng,
            LOWER(TRIM(property_type)) AS property_type,
            zone_id,
            square_footage,
            access_notes,
            -- Data quality checks
            (lat BETWEEN -90 AND 90 AND lng BETWEEN -180 AND 180) AS is_valid_coordinates,
            (address IS NOT NULL AND city IS NOT NULL AND state IS NOT NULL
             AND lat IS NOT NULL AND lng IS NOT NULL) AS is_complete,
            CASE
                WHEN address IS NULL OR city IS NULL OR state IS NULL THEN 0
                WHEN lat NOT BETWEEN -90 AND 90 OR lng NOT BETWEEN -180 AND 180 THEN 30
                WHEN zone_id IS NULL THEN 70
                ELSE 100
            END AS data_quality_score,
            created_at,
            updated_at,
            source_system,
            ingestion_timestamp AS raw_ingestion_timestamp,
            MD5(CONCAT(property_id, address, city, lat, lng, property_type)) AS record_hash
        FROM RAW.PROPERTIES_STREAM
        WHERE METADATA$ACTION = 'INSERT' OR METADATA$ACTION = 'UPDATE'
    ) AS source
    ON target.property_id = source.property_id
    WHEN MATCHED AND target.record_hash != source.record_hash THEN
        UPDATE SET
            address = source.address,
            city = source.city,
            state = source.state,
            zip_code = source.zip_code,
            full_address = source.full_address,
            lat = source.lat,
            lng = source.lng,
            property_type = source.property_type,
            zone_id = source.zone_id,
            square_footage = source.square_footage,
            access_notes = source.access_notes,
            is_valid_coordinates = source.is_valid_coordinates,
            is_complete = source.is_complete,
            data_quality_score = source.data_quality_score,
            updated_at = source.updated_at,
            source_system = source.source_system,
            raw_ingestion_timestamp = source.raw_ingestion_timestamp,
            staging_load_timestamp = CURRENT_TIMESTAMP(),
            record_hash = source.record_hash,
            valid_to = CURRENT_TIMESTAMP(),
            is_current = FALSE
    WHEN NOT MATCHED THEN
        INSERT (
            property_id, address, city, state, zip_code, full_address,
            lat, lng, property_type, zone_id, square_footage, access_notes,
            is_valid_coordinates, is_complete, data_quality_score,
            created_at, updated_at, source_system, raw_ingestion_timestamp, record_hash
        )
        VALUES (
            source.property_id, source.address, source.city, source.state,
            source.zip_code, source.full_address, source.lat, source.lng,
            source.property_type, source.zone_id, source.square_footage,
            source.access_notes, source.is_valid_coordinates, source.is_complete,
            source.data_quality_score, source.created_at, source.updated_at,
            source.source_system, source.raw_ingestion_timestamp, source.record_hash
        );

    RETURN 'Properties loaded successfully';
END;
$$;

/*------------------------------------------------------------------------------
 * PROCEDURE: Load STAGING.TECHNICIANS from RAW.TECHNICIANS
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE STAGING.LOAD_TECHNICIANS()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    MERGE INTO STAGING.TECHNICIANS AS target
    USING (
        SELECT
            technician_id,
            TRIM(name) AS name,
            LOWER(TRIM(email)) AS email,
            TRIM(phone) AS phone,
            home_lat,
            home_lng,
            skills,
            TRY_PARSE_JSON(skills) AS skills_array,
            ARRAY_SIZE(TRY_PARSE_JSON(skills)) AS skill_count,
            max_daily_hours,
            max_daily_distance_miles,
            hourly_rate,
            LOWER(TRIM(availability_status)) AS availability_status,
            zone_preference,
            -- Data quality checks
            (home_lat BETWEEN -90 AND 90 AND home_lng BETWEEN -180 AND 180) AS is_valid_coordinates,
            (email LIKE '%@%.%') AS is_valid_email,
            (name IS NOT NULL AND home_lat IS NOT NULL AND home_lng IS NOT NULL) AS is_complete,
            CASE
                WHEN name IS NULL THEN 0
                WHEN home_lat NOT BETWEEN -90 AND 90 OR home_lng NOT BETWEEN -180 AND 180 THEN 30
                WHEN email IS NULL OR email NOT LIKE '%@%.%' THEN 60
                WHEN skills IS NULL THEN 70
                ELSE 100
            END AS data_quality_score,
            created_at,
            updated_at,
            source_system,
            ingestion_timestamp AS raw_ingestion_timestamp,
            MD5(CONCAT(technician_id, name, email, home_lat, home_lng)) AS record_hash
        FROM RAW.TECHNICIANS_STREAM
        WHERE METADATA$ACTION = 'INSERT' OR METADATA$ACTION = 'UPDATE'
    ) AS source
    ON target.technician_id = source.technician_id
    WHEN MATCHED AND target.record_hash != source.record_hash THEN
        UPDATE SET
            name = source.name,
            email = source.email,
            phone = source.phone,
            home_lat = source.home_lat,
            home_lng = source.home_lng,
            skills = source.skills,
            skills_array = source.skills_array,
            skill_count = source.skill_count,
            max_daily_hours = source.max_daily_hours,
            max_daily_distance_miles = source.max_daily_distance_miles,
            hourly_rate = source.hourly_rate,
            availability_status = source.availability_status,
            zone_preference = source.zone_preference,
            is_valid_coordinates = source.is_valid_coordinates,
            is_valid_email = source.is_valid_email,
            is_complete = source.is_complete,
            data_quality_score = source.data_quality_score,
            updated_at = source.updated_at,
            staging_load_timestamp = CURRENT_TIMESTAMP(),
            record_hash = source.record_hash
    WHEN NOT MATCHED THEN
        INSERT (
            technician_id, name, email, phone, home_lat, home_lng,
            skills, skills_array, skill_count, max_daily_hours,
            max_daily_distance_miles, hourly_rate, availability_status,
            zone_preference, is_valid_coordinates, is_valid_email,
            is_complete, data_quality_score, created_at, updated_at,
            source_system, raw_ingestion_timestamp, record_hash
        )
        VALUES (
            source.technician_id, source.name, source.email, source.phone,
            source.home_lat, source.home_lng, source.skills, source.skills_array,
            source.skill_count, source.max_daily_hours, source.max_daily_distance_miles,
            source.hourly_rate, source.availability_status, source.zone_preference,
            source.is_valid_coordinates, source.is_valid_email, source.is_complete,
            source.data_quality_score, source.created_at, source.updated_at,
            source.source_system, source.raw_ingestion_timestamp, source.record_hash
        );

    RETURN 'Technicians loaded successfully';
END;
$$;

/*------------------------------------------------------------------------------
 * PROCEDURE: Load STAGING.WORK_ORDERS from RAW.WORK_ORDERS
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE STAGING.LOAD_WORK_ORDERS()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    MERGE INTO STAGING.WORK_ORDERS AS target
    USING (
        SELECT
            work_order_id,
            property_id,
            TRIM(title) AS title,
            description,
            UPPER(TRIM(category)) AS category,
            LOWER(TRIM(priority)) AS priority,
            CASE LOWER(TRIM(priority))
                WHEN 'emergency' THEN 1
                WHEN 'high' THEN 2
                WHEN 'medium' THEN 3
                WHEN 'low' THEN 4
                ELSE 5
            END AS priority_rank,
            required_skills,
            TRY_PARSE_JSON(required_skills) AS required_skills_array,
            estimated_duration_minutes,
            ROUND(estimated_duration_minutes / 60.0, 2) AS estimated_duration_hours,
            time_window_start,
            time_window_end,
            CASE
                WHEN time_window_start IS NOT NULL AND time_window_end IS NOT NULL
                THEN DATEDIFF('hour', time_window_start, time_window_end)
                ELSE NULL
            END AS time_window_hours,
            (time_window_start IS NOT NULL OR time_window_end IS NOT NULL) AS is_time_constrained,
            LOWER(TRIM(status)) AS status,
            assigned_technician_id,
            scheduled_date,
            completed_at,
            -- Data quality checks
            (time_window_end IS NULL OR time_window_start IS NULL OR time_window_end > time_window_start) AS is_valid_time_window,
            EXISTS (SELECT 1 FROM RAW.PROPERTIES p WHERE p.property_id = r.property_id) AS has_property_match,
            (assigned_technician_id IS NULL OR
             EXISTS (SELECT 1 FROM RAW.TECHNICIANS t WHERE t.technician_id = r.assigned_technician_id)) AS has_technician_match,
            (property_id IS NOT NULL AND title IS NOT NULL AND estimated_duration_minutes > 0) AS is_complete,
            CASE
                WHEN property_id IS NULL OR title IS NULL THEN 0
                WHEN estimated_duration_minutes <= 0 THEN 30
                WHEN category IS NULL OR priority IS NULL THEN 60
                ELSE 100
            END AS data_quality_score,
            created_at,
            updated_at,
            source_system,
            ingestion_timestamp AS raw_ingestion_timestamp,
            MD5(CONCAT(work_order_id, property_id, title, status)) AS record_hash
        FROM RAW.WORK_ORDERS_STREAM r
        WHERE METADATA$ACTION = 'INSERT' OR METADATA$ACTION = 'UPDATE'
    ) AS source
    ON target.work_order_id = source.work_order_id
    WHEN MATCHED AND target.record_hash != source.record_hash THEN
        UPDATE SET
            property_id = source.property_id,
            title = source.title,
            description = source.description,
            category = source.category,
            priority = source.priority,
            priority_rank = source.priority_rank,
            required_skills = source.required_skills,
            required_skills_array = source.required_skills_array,
            estimated_duration_minutes = source.estimated_duration_minutes,
            estimated_duration_hours = source.estimated_duration_hours,
            time_window_start = source.time_window_start,
            time_window_end = source.time_window_end,
            time_window_hours = source.time_window_hours,
            is_time_constrained = source.is_time_constrained,
            status = source.status,
            assigned_technician_id = source.assigned_technician_id,
            scheduled_date = source.scheduled_date,
            completed_at = source.completed_at,
            is_valid_time_window = source.is_valid_time_window,
            has_property_match = source.has_property_match,
            has_technician_match = source.has_technician_match,
            is_complete = source.is_complete,
            data_quality_score = source.data_quality_score,
            updated_at = source.updated_at,
            staging_load_timestamp = CURRENT_TIMESTAMP(),
            record_hash = source.record_hash
    WHEN NOT MATCHED THEN
        INSERT (
            work_order_id, property_id, title, description, category, priority,
            priority_rank, required_skills, required_skills_array,
            estimated_duration_minutes, estimated_duration_hours,
            time_window_start, time_window_end, time_window_hours,
            is_time_constrained, status, assigned_technician_id, scheduled_date,
            completed_at, is_valid_time_window, has_property_match,
            has_technician_match, is_complete, data_quality_score,
            created_at, updated_at, source_system, raw_ingestion_timestamp, record_hash
        )
        VALUES (
            source.work_order_id, source.property_id, source.title, source.description,
            source.category, source.priority, source.priority_rank, source.required_skills,
            source.required_skills_array, source.estimated_duration_minutes,
            source.estimated_duration_hours, source.time_window_start, source.time_window_end,
            source.time_window_hours, source.is_time_constrained, source.status,
            source.assigned_technician_id, source.scheduled_date, source.completed_at,
            source.is_valid_time_window, source.has_property_match, source.has_technician_match,
            source.is_complete, source.data_quality_score, source.created_at, source.updated_at,
            source.source_system, source.raw_ingestion_timestamp, source.record_hash
        );

    RETURN 'Work orders loaded successfully';
END;
$$;

/*------------------------------------------------------------------------------
 * PROCEDURE: Load STAGING.ROUTES from RAW.ROUTES
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE STAGING.LOAD_ROUTES()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    MERGE INTO STAGING.ROUTES AS target
    USING (
        SELECT
            r.route_id,
            r.optimization_run_id,
            r.technician_id,
            r.route_date,
            r.total_distance_miles,
            r.total_duration_minutes,
            ROUND(r.total_duration_minutes / 60.0, 2) AS total_duration_hours,
            r.num_stops,
            CASE WHEN r.num_stops > 0 THEN ROUND(r.total_distance_miles / r.num_stops, 2) ELSE 0 END AS avg_distance_per_stop,
            CASE WHEN r.num_stops > 0 THEN ROUND(r.total_duration_minutes / r.num_stops, 2) ELSE 0 END AS avg_duration_per_stop,
            CASE
                WHEN t.max_daily_hours > 0 THEN ROUND((r.total_duration_minutes / 60.0) / t.max_daily_hours * 100, 2)
                ELSE NULL
            END AS utilization_percentage,
            r.algorithm_used,
            r.optimization_score,
            r.computation_time_seconds,
            LOWER(TRIM(r.route_status)) AS route_status,
            EXISTS (SELECT 1 FROM RAW.TECHNICIANS t WHERE t.technician_id = r.technician_id) AS has_technician_match,
            (r.total_distance_miles <= t.max_daily_distance_miles AND
             r.total_duration_minutes / 60.0 <= t.max_daily_hours) AS is_within_constraints,
            (r.technician_id IS NOT NULL AND r.route_date IS NOT NULL) AS is_complete,
            CASE
                WHEN r.technician_id IS NULL OR r.route_date IS NULL THEN 0
                WHEN r.total_distance_miles IS NULL OR r.total_duration_minutes IS NULL THEN 50
                ELSE 100
            END AS data_quality_score,
            r.created_at,
            r.updated_at,
            r.source_system,
            r.ingestion_timestamp AS raw_ingestion_timestamp,
            MD5(CONCAT(r.route_id, r.technician_id, r.route_date)) AS record_hash
        FROM RAW.ROUTES_STREAM r
        LEFT JOIN RAW.TECHNICIANS t ON r.technician_id = t.technician_id
        WHERE METADATA$ACTION = 'INSERT' OR METADATA$ACTION = 'UPDATE'
    ) AS source
    ON target.route_id = source.route_id
    WHEN MATCHED AND target.record_hash != source.record_hash THEN
        UPDATE SET
            optimization_run_id = source.optimization_run_id,
            technician_id = source.technician_id,
            route_date = source.route_date,
            total_distance_miles = source.total_distance_miles,
            total_duration_minutes = source.total_duration_minutes,
            total_duration_hours = source.total_duration_hours,
            num_stops = source.num_stops,
            avg_distance_per_stop = source.avg_distance_per_stop,
            avg_duration_per_stop = source.avg_duration_per_stop,
            utilization_percentage = source.utilization_percentage,
            algorithm_used = source.algorithm_used,
            optimization_score = source.optimization_score,
            computation_time_seconds = source.computation_time_seconds,
            route_status = source.route_status,
            has_technician_match = source.has_technician_match,
            is_within_constraints = source.is_within_constraints,
            is_complete = source.is_complete,
            data_quality_score = source.data_quality_score,
            updated_at = source.updated_at,
            staging_load_timestamp = CURRENT_TIMESTAMP(),
            record_hash = source.record_hash
    WHEN NOT MATCHED THEN
        INSERT (
            route_id, optimization_run_id, technician_id, route_date,
            total_distance_miles, total_duration_minutes, total_duration_hours,
            num_stops, avg_distance_per_stop, avg_duration_per_stop,
            utilization_percentage, algorithm_used, optimization_score,
            computation_time_seconds, route_status, has_technician_match,
            is_within_constraints, is_complete, data_quality_score,
            created_at, updated_at, source_system, raw_ingestion_timestamp, record_hash
        )
        VALUES (
            source.route_id, source.optimization_run_id, source.technician_id,
            source.route_date, source.total_distance_miles, source.total_duration_minutes,
            source.total_duration_hours, source.num_stops, source.avg_distance_per_stop,
            source.avg_duration_per_stop, source.utilization_percentage,
            source.algorithm_used, source.optimization_score, source.computation_time_seconds,
            source.route_status, source.has_technician_match, source.is_within_constraints,
            source.is_complete, source.data_quality_score, source.created_at,
            source.updated_at, source.source_system, source.raw_ingestion_timestamp,
            source.record_hash
        );

    RETURN 'Routes loaded successfully';
END;
$$;

/*------------------------------------------------------------------------------
 * PROCEDURE: Load STAGING.ROUTE_STOPS from RAW.ROUTE_STOPS
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE STAGING.LOAD_ROUTE_STOPS()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    MERGE INTO STAGING.ROUTE_STOPS AS target
    USING (
        SELECT
            rs.stop_id,
            rs.route_id,
            rs.work_order_id,
            rs.sequence_number,
            (rs.sequence_number = 1) AS is_first_stop,
            (rs.sequence_number = (SELECT MAX(sequence_number) FROM RAW.ROUTE_STOPS WHERE route_id = rs.route_id)) AS is_last_stop,
            rs.arrival_time,
            rs.departure_time,
            rs.actual_duration_minutes,
            rs.travel_distance_miles,
            rs.travel_duration_minutes,
            LOWER(TRIM(rs.stop_status)) AS stop_status,
            rs.notes,
            EXISTS (SELECT 1 FROM RAW.ROUTES r WHERE r.route_id = rs.route_id) AS has_route_match,
            EXISTS (SELECT 1 FROM RAW.WORK_ORDERS w WHERE w.work_order_id = rs.work_order_id) AS has_work_order_match,
            (rs.departure_time IS NULL OR rs.arrival_time IS NULL OR rs.departure_time >= rs.arrival_time) AS is_valid_timing,
            (rs.route_id IS NOT NULL AND rs.work_order_id IS NOT NULL AND rs.sequence_number > 0) AS is_complete,
            CASE
                WHEN rs.route_id IS NULL OR rs.work_order_id IS NULL THEN 0
                WHEN rs.sequence_number <= 0 THEN 30
                WHEN rs.arrival_time IS NULL AND rs.departure_time IS NULL THEN 70
                ELSE 100
            END AS data_quality_score,
            rs.created_at,
            rs.updated_at,
            rs.source_system,
            rs.ingestion_timestamp AS raw_ingestion_timestamp,
            MD5(CONCAT(rs.stop_id, rs.route_id, rs.work_order_id, rs.sequence_number)) AS record_hash
        FROM RAW.ROUTE_STOPS_STREAM rs
        WHERE METADATA$ACTION = 'INSERT' OR METADATA$ACTION = 'UPDATE'
    ) AS source
    ON target.stop_id = source.stop_id
    WHEN MATCHED AND target.record_hash != source.record_hash THEN
        UPDATE SET
            route_id = source.route_id,
            work_order_id = source.work_order_id,
            sequence_number = source.sequence_number,
            is_first_stop = source.is_first_stop,
            is_last_stop = source.is_last_stop,
            arrival_time = source.arrival_time,
            departure_time = source.departure_time,
            actual_duration_minutes = source.actual_duration_minutes,
            travel_distance_miles = source.travel_distance_miles,
            travel_duration_minutes = source.travel_duration_minutes,
            stop_status = source.stop_status,
            notes = source.notes,
            has_route_match = source.has_route_match,
            has_work_order_match = source.has_work_order_match,
            is_valid_timing = source.is_valid_timing,
            is_complete = source.is_complete,
            data_quality_score = source.data_quality_score,
            updated_at = source.updated_at,
            staging_load_timestamp = CURRENT_TIMESTAMP(),
            record_hash = source.record_hash
    WHEN NOT MATCHED THEN
        INSERT (
            stop_id, route_id, work_order_id, sequence_number,
            is_first_stop, is_last_stop, arrival_time, departure_time,
            actual_duration_minutes, travel_distance_miles, travel_duration_minutes,
            stop_status, notes, has_route_match, has_work_order_match,
            is_valid_timing, is_complete, data_quality_score,
            created_at, updated_at, source_system, raw_ingestion_timestamp, record_hash
        )
        VALUES (
            source.stop_id, source.route_id, source.work_order_id, source.sequence_number,
            source.is_first_stop, source.is_last_stop, source.arrival_time, source.departure_time,
            source.actual_duration_minutes, source.travel_distance_miles, source.travel_duration_minutes,
            source.stop_status, source.notes, source.has_route_match, source.has_work_order_match,
            source.is_valid_timing, source.is_complete, source.data_quality_score,
            source.created_at, source.updated_at, source.source_system,
            source.raw_ingestion_timestamp, source.record_hash
        );

    RETURN 'Route stops loaded successfully';
END;
$$;

/*------------------------------------------------------------------------------
 * TASK: Automated ETL from RAW to STAGING
 * Note: Uncomment to enable scheduled execution
 *----------------------------------------------------------------------------*/

/*
CREATE OR REPLACE TASK STAGING.LOAD_STAGING_DATA
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '5 MINUTE'
WHEN
    SYSTEM$STREAM_HAS_DATA('RAW.PROPERTIES_STREAM') OR
    SYSTEM$STREAM_HAS_DATA('RAW.TECHNICIANS_STREAM') OR
    SYSTEM$STREAM_HAS_DATA('RAW.WORK_ORDERS_STREAM') OR
    SYSTEM$STREAM_HAS_DATA('RAW.ROUTES_STREAM') OR
    SYSTEM$STREAM_HAS_DATA('RAW.ROUTE_STOPS_STREAM')
AS
BEGIN
    CALL STAGING.LOAD_PROPERTIES();
    CALL STAGING.LOAD_TECHNICIANS();
    CALL STAGING.LOAD_WORK_ORDERS();
    CALL STAGING.LOAD_ROUTES();
    CALL STAGING.LOAD_ROUTE_STOPS();
END;

-- Enable the task
ALTER TASK STAGING.LOAD_STAGING_DATA RESUME;
*/

/*==============================================================================
 * END OF SCRIPT
 *============================================================================*/
