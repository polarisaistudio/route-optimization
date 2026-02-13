/*==============================================================================
 * FIELD SERVICE OPERATIONS - ANALYTICS LAYER TABLES
 *
 * Purpose: Create analytics-ready dimensional model (star schema)
 * Author: Route Optimization Team
 * Created: 2026-02-12
 *
 * Components:
 *   - Dimension Tables: DIM_PROPERTY, DIM_TECHNICIAN, DIM_DATE
 *   - Fact Tables: FACT_ROUTE, FACT_ROUTE_STOP, FACT_WORK_ORDER
 *
 * Features:
 *   - Surrogate keys for dimensional modeling
 *   - SCD Type 2 for slowly changing dimensions
 *   - Pre-aggregated metrics for performance
 *   - Optimized for analytical queries
 *============================================================================*/

USE ROLE ADMIN_ROLE;
USE DATABASE FIELD_SERVICE_OPS;
USE SCHEMA ANALYTICS;
USE WAREHOUSE COMPUTE_WH;

/*==============================================================================
 * DIMENSION TABLES
 *============================================================================*/

/*------------------------------------------------------------------------------
 * TABLE: ANALYTICS.DIM_DATE
 * Description: Date dimension for time-based analysis
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE TABLE ANALYTICS.DIM_DATE (
    -- Surrogate Key
    date_key NUMBER(8,0) NOT NULL,  -- YYYYMMDD format

    -- Natural Key
    date_value DATE NOT NULL,

    -- Date Attributes
    day_of_week NUMBER(1,0),  -- 1-7 (1=Sunday)
    day_of_week_name VARCHAR(10),  -- Sunday, Monday, etc.
    day_of_month NUMBER(2,0),
    day_of_year NUMBER(3,0),

    -- Week Attributes
    week_of_year NUMBER(2,0),
    week_start_date DATE,
    week_end_date DATE,

    -- Month Attributes
    month_number NUMBER(2,0),
    month_name VARCHAR(10),
    month_abbr VARCHAR(3),
    first_day_of_month DATE,
    last_day_of_month DATE,

    -- Quarter Attributes
    quarter_number NUMBER(1,0),
    quarter_name VARCHAR(10),  -- Q1, Q2, Q3, Q4
    first_day_of_quarter DATE,
    last_day_of_quarter DATE,

    -- Year Attributes
    year_number NUMBER(4,0),
    first_day_of_year DATE,
    last_day_of_year DATE,

    -- Business Attributes
    is_weekday BOOLEAN,
    is_weekend BOOLEAN,
    is_holiday BOOLEAN,
    holiday_name VARCHAR(100),

    -- Fiscal Period (if different from calendar)
    fiscal_year NUMBER(4,0),
    fiscal_quarter NUMBER(1,0),
    fiscal_period NUMBER(2,0),

    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Constraints
    CONSTRAINT pk_dim_date PRIMARY KEY (date_key),
    CONSTRAINT uk_dim_date UNIQUE (date_value)
)
COMMENT = 'Date dimension for temporal analysis';

/*------------------------------------------------------------------------------
 * TABLE: ANALYTICS.DIM_PROPERTY
 * Description: Property dimension with SCD Type 2
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE TABLE ANALYTICS.DIM_PROPERTY (
    -- Surrogate Key
    property_key NUMBER(18,0) AUTOINCREMENT NOT NULL,

    -- Natural Key
    property_id VARCHAR(50) NOT NULL,

    -- Property Attributes
    address VARCHAR(500) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(2) NOT NULL,
    zip_code VARCHAR(10) NOT NULL,
    full_address VARCHAR(1000),

    -- Geographic Coordinates
    lat FLOAT NOT NULL,
    lng FLOAT NOT NULL,

    -- Property Characteristics
    property_type VARCHAR(50) NOT NULL,
    property_type_category VARCHAR(20),  -- Rolled up: Residential, Commercial
    zone_id VARCHAR(50),
    zone_name VARCHAR(100),
    square_footage NUMBER(10,2),
    square_footage_bucket VARCHAR(50),  -- Small (<2000), Medium (2000-5000), Large (>5000)

    -- Service Information
    access_notes VARCHAR(2000),
    has_access_restrictions BOOLEAN,

    -- SCD Type 2 Columns
    effective_date DATE NOT NULL,
    expiration_date DATE DEFAULT TO_DATE('9999-12-31'),
    is_current BOOLEAN DEFAULT TRUE,

    -- Metadata
    source_system VARCHAR(100),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Constraints
    CONSTRAINT pk_dim_property PRIMARY KEY (property_key),
    CONSTRAINT chk_dim_property_dates CHECK (expiration_date >= effective_date)
)
COMMENT = 'Property dimension with SCD Type 2 for historical tracking';

-- Create index on natural key for lookups
CREATE INDEX idx_dim_property_id ON ANALYTICS.DIM_PROPERTY(property_id, is_current);

/*------------------------------------------------------------------------------
 * TABLE: ANALYTICS.DIM_TECHNICIAN
 * Description: Technician dimension with SCD Type 2
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE TABLE ANALYTICS.DIM_TECHNICIAN (
    -- Surrogate Key
    technician_key NUMBER(18,0) AUTOINCREMENT NOT NULL,

    -- Natural Key
    technician_id VARCHAR(50) NOT NULL,

    -- Personal Information
    name VARCHAR(200) NOT NULL,
    email VARCHAR(200),
    phone VARCHAR(20),

    -- Home Location
    home_lat FLOAT NOT NULL,
    home_lng FLOAT NOT NULL,
    home_city VARCHAR(100),
    home_state VARCHAR(2),
    home_zone_id VARCHAR(50),

    -- Skills
    skills VARIANT,
    skill_count NUMBER(3,0),
    skill_summary VARCHAR(500),  -- Comma-separated list
    has_hvac_skill BOOLEAN,
    has_electrical_skill BOOLEAN,
    has_plumbing_skill BOOLEAN,

    -- Capacity and Constraints
    max_daily_hours NUMBER(5,2),
    max_daily_distance_miles NUMBER(6,2),
    capacity_level VARCHAR(20),  -- Low, Medium, High

    -- Financial
    hourly_rate NUMBER(8,2),
    hourly_rate_bucket VARCHAR(50),  -- <$30, $30-$50, $50+

    -- Status
    availability_status VARCHAR(50),
    zone_preference VARCHAR(50),

    -- SCD Type 2 Columns
    effective_date DATE NOT NULL,
    expiration_date DATE DEFAULT TO_DATE('9999-12-31'),
    is_current BOOLEAN DEFAULT TRUE,

    -- Metadata
    source_system VARCHAR(100),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Constraints
    CONSTRAINT pk_dim_technician PRIMARY KEY (technician_key),
    CONSTRAINT chk_dim_tech_dates CHECK (expiration_date >= effective_date)
)
COMMENT = 'Technician dimension with SCD Type 2 for historical tracking';

-- Create index on natural key for lookups
CREATE INDEX idx_dim_technician_id ON ANALYTICS.DIM_TECHNICIAN(technician_id, is_current);

/*==============================================================================
 * FACT TABLES
 *============================================================================*/

/*------------------------------------------------------------------------------
 * TABLE: ANALYTICS.FACT_WORK_ORDER
 * Description: Work order fact table
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE TABLE ANALYTICS.FACT_WORK_ORDER (
    -- Surrogate Key
    work_order_key NUMBER(18,0) AUTOINCREMENT NOT NULL,

    -- Natural Key
    work_order_id VARCHAR(50) NOT NULL,

    -- Foreign Keys to Dimensions
    property_key NUMBER(18,0),
    technician_key NUMBER(18,0),
    created_date_key NUMBER(8,0),
    scheduled_date_key NUMBER(8,0),
    completed_date_key NUMBER(8,0),

    -- Degenerate Dimensions (facts without dimensions)
    category VARCHAR(50) NOT NULL,
    priority VARCHAR(20) NOT NULL,
    priority_rank NUMBER(1,0),
    status VARCHAR(50) NOT NULL,

    -- Work Order Details
    title VARCHAR(500),
    description VARCHAR(4000),
    required_skills VARIANT,

    -- Time Window
    time_window_start TIMESTAMP_NTZ,
    time_window_end TIMESTAMP_NTZ,
    time_window_hours NUMBER(5,2),
    is_time_constrained BOOLEAN,

    -- Metrics (Additive)
    estimated_duration_minutes NUMBER(5,0),
    actual_duration_minutes NUMBER(5,0),
    duration_variance_minutes NUMBER(6,0),  -- actual - estimated
    duration_variance_pct NUMBER(6,2),

    -- Derived Metrics
    days_from_created_to_scheduled NUMBER(5,0),
    days_from_scheduled_to_completed NUMBER(5,0),
    days_from_created_to_completed NUMBER(5,0),

    -- Status Flags (Semi-additive)
    is_completed BOOLEAN,
    is_cancelled BOOLEAN,
    is_emergency BOOLEAN,
    is_on_time BOOLEAN,  -- Completed within time window

    -- Metadata
    source_system VARCHAR(100),
    created_at TIMESTAMP_NTZ NOT NULL,
    updated_at TIMESTAMP_NTZ,
    load_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Constraints
    CONSTRAINT pk_fact_work_order PRIMARY KEY (work_order_key),
    CONSTRAINT uk_fact_work_order UNIQUE (work_order_id)
)
COMMENT = 'Work order fact table for service request analysis';

-- Cluster by date for query performance
ALTER TABLE ANALYTICS.FACT_WORK_ORDER CLUSTER BY (created_date_key, scheduled_date_key);

/*------------------------------------------------------------------------------
 * TABLE: ANALYTICS.FACT_ROUTE
 * Description: Route fact table
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE TABLE ANALYTICS.FACT_ROUTE (
    -- Surrogate Key
    route_key NUMBER(18,0) AUTOINCREMENT NOT NULL,

    -- Natural Key
    route_id VARCHAR(50) NOT NULL,

    -- Foreign Keys to Dimensions
    technician_key NUMBER(18,0),
    route_date_key NUMBER(8,0),

    -- Degenerate Dimensions
    optimization_run_id VARCHAR(50),
    algorithm_used VARCHAR(100),
    route_status VARCHAR(50),

    -- Route Metrics (Additive)
    total_distance_miles NUMBER(8,2),
    total_duration_minutes NUMBER(6,0),
    total_duration_hours NUMBER(6,2),
    num_stops NUMBER(3,0),

    -- Computed Metrics
    avg_distance_per_stop NUMBER(8,2),
    avg_duration_per_stop NUMBER(6,2),
    utilization_percentage NUMBER(5,2),

    -- Optimization Metrics
    optimization_score NUMBER(10,4),
    computation_time_seconds NUMBER(8,2),

    -- Efficiency Metrics
    distance_efficiency NUMBER(8,4),  -- total_distance / straight_line_distance
    time_efficiency NUMBER(8,4),      -- actual_time / estimated_time

    -- Constraint Compliance
    is_within_distance_constraint BOOLEAN,
    is_within_time_constraint BOOLEAN,
    distance_constraint_utilization_pct NUMBER(5,2),
    time_constraint_utilization_pct NUMBER(5,2),

    -- Status Flags
    is_completed BOOLEAN,
    is_cancelled BOOLEAN,

    -- Metadata
    source_system VARCHAR(100),
    created_at TIMESTAMP_NTZ NOT NULL,
    updated_at TIMESTAMP_NTZ,
    load_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Constraints
    CONSTRAINT pk_fact_route PRIMARY KEY (route_key),
    CONSTRAINT uk_fact_route UNIQUE (route_id)
)
COMMENT = 'Route fact table for route performance analysis';

-- Cluster by date and technician for query performance
ALTER TABLE ANALYTICS.FACT_ROUTE CLUSTER BY (route_date_key, technician_key);

/*------------------------------------------------------------------------------
 * TABLE: ANALYTICS.FACT_ROUTE_STOP
 * Description: Route stop fact table (grain: one stop per route)
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE TABLE ANALYTICS.FACT_ROUTE_STOP (
    -- Surrogate Key
    route_stop_key NUMBER(18,0) AUTOINCREMENT NOT NULL,

    -- Natural Key
    stop_id VARCHAR(50) NOT NULL,

    -- Foreign Keys to Facts (snowflake schema)
    route_key NUMBER(18,0),
    work_order_key NUMBER(18,0),

    -- Foreign Keys to Dimensions
    property_key NUMBER(18,0),
    technician_key NUMBER(18,0),
    route_date_key NUMBER(8,0),
    arrival_date_key NUMBER(8,0),

    -- Degenerate Dimensions
    route_id VARCHAR(50),
    work_order_id VARCHAR(50),
    stop_status VARCHAR(50),

    -- Sequence Information
    sequence_number NUMBER(3,0),
    is_first_stop BOOLEAN,
    is_last_stop BOOLEAN,

    -- Timing Metrics
    arrival_time TIMESTAMP_NTZ,
    departure_time TIMESTAMP_NTZ,
    actual_duration_minutes NUMBER(5,0),
    estimated_duration_minutes NUMBER(5,0),
    duration_variance_minutes NUMBER(6,0),

    -- Travel Metrics (from previous stop)
    travel_distance_miles NUMBER(8,2),
    travel_duration_minutes NUMBER(5,0),

    -- Efficiency Metrics
    is_on_time_arrival BOOLEAN,
    arrival_variance_minutes NUMBER(6,0),  -- vs. planned arrival

    -- Status Flags
    is_completed BOOLEAN,
    is_skipped BOOLEAN,

    -- Metadata
    notes VARCHAR(2000),
    source_system VARCHAR(100),
    created_at TIMESTAMP_NTZ NOT NULL,
    updated_at TIMESTAMP_NTZ,
    load_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Constraints
    CONSTRAINT pk_fact_route_stop PRIMARY KEY (route_stop_key),
    CONSTRAINT uk_fact_route_stop UNIQUE (stop_id)
)
COMMENT = 'Route stop fact table for granular stop-level analysis';

-- Cluster by route and date for query performance
ALTER TABLE ANALYTICS.FACT_ROUTE_STOP CLUSTER BY (route_date_key, route_key);

/*==============================================================================
 * STORED PROCEDURES: Load Analytics Tables from Staging
 *============================================================================*/

/*------------------------------------------------------------------------------
 * PROCEDURE: Populate DIM_DATE
 * Description: Generate date dimension for a date range
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE ANALYTICS.POPULATE_DIM_DATE(
    start_date DATE,
    end_date DATE
)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    v_sql STRING;
BEGIN
    -- Generate date records using a generator
    v_sql := '
    INSERT INTO ANALYTICS.DIM_DATE (
        date_key,
        date_value,
        day_of_week,
        day_of_week_name,
        day_of_month,
        day_of_year,
        week_of_year,
        week_start_date,
        week_end_date,
        month_number,
        month_name,
        month_abbr,
        first_day_of_month,
        last_day_of_month,
        quarter_number,
        quarter_name,
        first_day_of_quarter,
        last_day_of_quarter,
        year_number,
        first_day_of_year,
        last_day_of_year,
        is_weekday,
        is_weekend,
        fiscal_year,
        fiscal_quarter,
        fiscal_period
    )
    SELECT
        TO_NUMBER(TO_CHAR(d.date_val, ''YYYYMMDD'')) AS date_key,
        d.date_val AS date_value,
        DAYOFWEEK(d.date_val) AS day_of_week,
        DAYNAME(d.date_val) AS day_of_week_name,
        DAYOFMONTH(d.date_val) AS day_of_month,
        DAYOFYEAR(d.date_val) AS day_of_year,
        WEEKOFYEAR(d.date_val) AS week_of_year,
        DATE_TRUNC(''WEEK'', d.date_val) AS week_start_date,
        DATEADD(''day'', 6, DATE_TRUNC(''WEEK'', d.date_val)) AS week_end_date,
        MONTH(d.date_val) AS month_number,
        MONTHNAME(d.date_val) AS month_name,
        LEFT(MONTHNAME(d.date_val), 3) AS month_abbr,
        DATE_TRUNC(''MONTH'', d.date_val) AS first_day_of_month,
        LAST_DAY(d.date_val) AS last_day_of_month,
        QUARTER(d.date_val) AS quarter_number,
        CONCAT(''Q'', QUARTER(d.date_val)) AS quarter_name,
        DATE_TRUNC(''QUARTER'', d.date_val) AS first_day_of_quarter,
        LAST_DAY(DATE_TRUNC(''QUARTER'', d.date_val), ''QUARTER'') AS last_day_of_quarter,
        YEAR(d.date_val) AS year_number,
        DATE_TRUNC(''YEAR'', d.date_val) AS first_day_of_year,
        DATEADD(''day'', -1, DATEADD(''year'', 1, DATE_TRUNC(''YEAR'', d.date_val))) AS last_day_of_year,
        CASE WHEN DAYOFWEEK(d.date_val) BETWEEN 2 AND 6 THEN TRUE ELSE FALSE END AS is_weekday,
        CASE WHEN DAYOFWEEK(d.date_val) IN (1, 7) THEN TRUE ELSE FALSE END AS is_weekend,
        YEAR(d.date_val) AS fiscal_year,
        QUARTER(d.date_val) AS fiscal_quarter,
        MONTH(d.date_val) AS fiscal_period
    FROM (
        SELECT DATEADD(day, SEQ4(), :1) AS date_val
        FROM TABLE(GENERATOR(ROWCOUNT => DATEDIFF(day, :1, :2) + 1))
    ) d
    WHERE NOT EXISTS (
        SELECT 1 FROM ANALYTICS.DIM_DATE WHERE date_value = d.date_val
    );
    ';

    EXECUTE IMMEDIATE v_sql USING (start_date, start_date, end_date);

    RETURN 'Date dimension populated successfully';
END;
$$;

/*------------------------------------------------------------------------------
 * PROCEDURE: Load DIM_PROPERTY from Staging (SCD Type 2)
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE ANALYTICS.LOAD_DIM_PROPERTY()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    -- Handle SCD Type 2 logic
    -- Step 1: Expire changed records
    UPDATE ANALYTICS.DIM_PROPERTY dim
    SET
        expiration_date = CURRENT_DATE - 1,
        is_current = FALSE,
        updated_at = CURRENT_TIMESTAMP()
    WHERE dim.is_current = TRUE
      AND EXISTS (
          SELECT 1
          FROM STAGING.PROPERTIES stg
          WHERE stg.property_id = dim.property_id
            AND stg.is_current = TRUE
            AND (
                stg.address != dim.address
                OR stg.lat != dim.lat
                OR stg.lng != dim.lng
                OR stg.property_type != dim.property_type
                OR COALESCE(stg.zone_id, '') != COALESCE(dim.zone_id, '')
            )
      );

    -- Step 2: Insert new/changed records
    INSERT INTO ANALYTICS.DIM_PROPERTY (
        property_id,
        address,
        city,
        state,
        zip_code,
        full_address,
        lat,
        lng,
        property_type,
        property_type_category,
        zone_id,
        square_footage,
        square_footage_bucket,
        access_notes,
        has_access_restrictions,
        effective_date,
        is_current,
        source_system
    )
    SELECT
        stg.property_id,
        stg.address,
        stg.city,
        stg.state,
        stg.zip_code,
        stg.full_address,
        stg.lat,
        stg.lng,
        stg.property_type,
        CASE
            WHEN stg.property_type = 'residential' THEN 'Residential'
            WHEN stg.property_type IN ('commercial', 'industrial') THEN 'Commercial'
            ELSE 'Other'
        END AS property_type_category,
        stg.zone_id,
        stg.square_footage,
        CASE
            WHEN stg.square_footage < 2000 THEN 'Small (<2000)'
            WHEN stg.square_footage BETWEEN 2000 AND 5000 THEN 'Medium (2000-5000)'
            WHEN stg.square_footage > 5000 THEN 'Large (>5000)'
            ELSE 'Unknown'
        END AS square_footage_bucket,
        stg.access_notes,
        (stg.access_notes IS NOT NULL AND LENGTH(stg.access_notes) > 0) AS has_access_restrictions,
        CURRENT_DATE AS effective_date,
        TRUE AS is_current,
        stg.source_system
    FROM STAGING.PROPERTIES stg
    WHERE stg.is_current = TRUE
      AND stg.data_quality_score >= 70  -- Only load quality data
      AND NOT EXISTS (
          SELECT 1
          FROM ANALYTICS.DIM_PROPERTY dim
          WHERE dim.property_id = stg.property_id
            AND dim.is_current = TRUE
      );

    RETURN 'Property dimension loaded successfully';
END;
$$;

/*------------------------------------------------------------------------------
 * PROCEDURE: Load DIM_TECHNICIAN from Staging (SCD Type 2)
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE ANALYTICS.LOAD_DIM_TECHNICIAN()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    -- Step 1: Expire changed records
    UPDATE ANALYTICS.DIM_TECHNICIAN dim
    SET
        expiration_date = CURRENT_DATE - 1,
        is_current = FALSE,
        updated_at = CURRENT_TIMESTAMP()
    WHERE dim.is_current = TRUE
      AND EXISTS (
          SELECT 1
          FROM STAGING.TECHNICIANS stg
          WHERE stg.technician_id = dim.technician_id
            AND stg.is_current = TRUE
            AND (
                stg.name != dim.name
                OR COALESCE(stg.email, '') != COALESCE(dim.email, '')
                OR stg.max_daily_hours != dim.max_daily_hours
                OR stg.availability_status != dim.availability_status
            )
      );

    -- Step 2: Insert new/changed records
    INSERT INTO ANALYTICS.DIM_TECHNICIAN (
        technician_id,
        name,
        email,
        phone,
        home_lat,
        home_lng,
        skills,
        skill_count,
        has_hvac_skill,
        has_electrical_skill,
        has_plumbing_skill,
        max_daily_hours,
        max_daily_distance_miles,
        capacity_level,
        hourly_rate,
        hourly_rate_bucket,
        availability_status,
        zone_preference,
        effective_date,
        is_current,
        source_system
    )
    SELECT
        stg.technician_id,
        stg.name,
        stg.email,
        stg.phone,
        stg.home_lat,
        stg.home_lng,
        stg.skills,
        stg.skill_count,
        ARRAY_CONTAINS('HVAC'::VARIANT, stg.skills_array) AS has_hvac_skill,
        ARRAY_CONTAINS('electrical'::VARIANT, stg.skills_array) AS has_electrical_skill,
        ARRAY_CONTAINS('plumbing'::VARIANT, stg.skills_array) AS has_plumbing_skill,
        stg.max_daily_hours,
        stg.max_daily_distance_miles,
        CASE
            WHEN stg.max_daily_hours >= 10 THEN 'High'
            WHEN stg.max_daily_hours >= 8 THEN 'Medium'
            ELSE 'Low'
        END AS capacity_level,
        stg.hourly_rate,
        CASE
            WHEN stg.hourly_rate < 30 THEN 'Entry (<$30)'
            WHEN stg.hourly_rate BETWEEN 30 AND 50 THEN 'Mid ($30-$50)'
            WHEN stg.hourly_rate > 50 THEN 'Senior ($50+)'
            ELSE 'Unknown'
        END AS hourly_rate_bucket,
        stg.availability_status,
        stg.zone_preference,
        CURRENT_DATE AS effective_date,
        TRUE AS is_current,
        stg.source_system
    FROM STAGING.TECHNICIANS stg
    WHERE stg.is_current = TRUE
      AND stg.data_quality_score >= 70
      AND NOT EXISTS (
          SELECT 1
          FROM ANALYTICS.DIM_TECHNICIAN dim
          WHERE dim.technician_id = stg.technician_id
            AND dim.is_current = TRUE
      );

    RETURN 'Technician dimension loaded successfully';
END;
$$;

/*------------------------------------------------------------------------------
 * PROCEDURE: Load FACT_WORK_ORDER from Staging
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE ANALYTICS.LOAD_FACT_WORK_ORDER()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    MERGE INTO ANALYTICS.FACT_WORK_ORDER AS target
    USING (
        SELECT
            wo.work_order_id,
            dp.property_key,
            dt.technician_key,
            dd1.date_key AS created_date_key,
            dd2.date_key AS scheduled_date_key,
            dd3.date_key AS completed_date_key,
            wo.category,
            wo.priority,
            wo.priority_rank,
            wo.status,
            wo.title,
            wo.description,
            wo.required_skills,
            wo.time_window_start,
            wo.time_window_end,
            wo.time_window_hours,
            wo.is_time_constrained,
            wo.estimated_duration_minutes,
            rs.actual_duration_minutes,
            rs.actual_duration_minutes - wo.estimated_duration_minutes AS duration_variance_minutes,
            CASE
                WHEN wo.estimated_duration_minutes > 0
                THEN ((rs.actual_duration_minutes - wo.estimated_duration_minutes) / wo.estimated_duration_minutes * 100)
                ELSE NULL
            END AS duration_variance_pct,
            DATEDIFF(day, wo.created_at, wo.scheduled_date) AS days_from_created_to_scheduled,
            DATEDIFF(day, wo.scheduled_date, wo.completed_at) AS days_from_scheduled_to_completed,
            DATEDIFF(day, wo.created_at, wo.completed_at) AS days_from_created_to_completed,
            (wo.status = 'completed') AS is_completed,
            (wo.status = 'cancelled') AS is_cancelled,
            (wo.priority = 'emergency') AS is_emergency,
            (wo.completed_at BETWEEN wo.time_window_start AND wo.time_window_end) AS is_on_time,
            wo.source_system,
            wo.created_at,
            wo.updated_at
        FROM STAGING.WORK_ORDERS wo
        LEFT JOIN ANALYTICS.DIM_PROPERTY dp
            ON wo.property_id = dp.property_id AND dp.is_current = TRUE
        LEFT JOIN ANALYTICS.DIM_TECHNICIAN dt
            ON wo.assigned_technician_id = dt.technician_id AND dt.is_current = TRUE
        LEFT JOIN ANALYTICS.DIM_DATE dd1
            ON TO_DATE(wo.created_at) = dd1.date_value
        LEFT JOIN ANALYTICS.DIM_DATE dd2
            ON wo.scheduled_date = dd2.date_value
        LEFT JOIN ANALYTICS.DIM_DATE dd3
            ON TO_DATE(wo.completed_at) = dd3.date_value
        LEFT JOIN STAGING.ROUTE_STOPS rs
            ON wo.work_order_id = rs.work_order_id
        WHERE wo.data_quality_score >= 70
    ) AS source
    ON target.work_order_id = source.work_order_id
    WHEN MATCHED THEN
        UPDATE SET
            property_key = source.property_key,
            technician_key = source.technician_key,
            scheduled_date_key = source.scheduled_date_key,
            completed_date_key = source.completed_date_key,
            status = source.status,
            actual_duration_minutes = source.actual_duration_minutes,
            duration_variance_minutes = source.duration_variance_minutes,
            duration_variance_pct = source.duration_variance_pct,
            days_from_scheduled_to_completed = source.days_from_scheduled_to_completed,
            days_from_created_to_completed = source.days_from_created_to_completed,
            is_completed = source.is_completed,
            is_on_time = source.is_on_time,
            updated_at = source.updated_at,
            load_timestamp = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN
        INSERT (
            work_order_id, property_key, technician_key, created_date_key,
            scheduled_date_key, completed_date_key, category, priority,
            priority_rank, status, title, description, required_skills,
            time_window_start, time_window_end, time_window_hours,
            is_time_constrained, estimated_duration_minutes, actual_duration_minutes,
            duration_variance_minutes, duration_variance_pct,
            days_from_created_to_scheduled, days_from_scheduled_to_completed,
            days_from_created_to_completed, is_completed, is_cancelled,
            is_emergency, is_on_time, source_system, created_at, updated_at
        )
        VALUES (
            source.work_order_id, source.property_key, source.technician_key,
            source.created_date_key, source.scheduled_date_key, source.completed_date_key,
            source.category, source.priority, source.priority_rank, source.status,
            source.title, source.description, source.required_skills,
            source.time_window_start, source.time_window_end, source.time_window_hours,
            source.is_time_constrained, source.estimated_duration_minutes,
            source.actual_duration_minutes, source.duration_variance_minutes,
            source.duration_variance_pct, source.days_from_created_to_scheduled,
            source.days_from_scheduled_to_completed, source.days_from_created_to_completed,
            source.is_completed, source.is_cancelled, source.is_emergency,
            source.is_on_time, source.source_system, source.created_at, source.updated_at
        );

    RETURN 'Work order facts loaded successfully';
END;
$$;

/*------------------------------------------------------------------------------
 * PROCEDURE: Load FACT_ROUTE from Staging
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE ANALYTICS.LOAD_FACT_ROUTE()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    MERGE INTO ANALYTICS.FACT_ROUTE AS target
    USING (
        SELECT
            r.route_id,
            dt.technician_key,
            dd.date_key AS route_date_key,
            r.optimization_run_id,
            r.algorithm_used,
            r.route_status,
            r.total_distance_miles,
            r.total_duration_minutes,
            r.total_duration_hours,
            r.num_stops,
            r.avg_distance_per_stop,
            r.avg_duration_per_stop,
            r.utilization_percentage,
            r.optimization_score,
            r.computation_time_seconds,
            (r.total_distance_miles / NULLIF(tech.max_daily_distance_miles, 0) * 100) AS distance_constraint_utilization_pct,
            (r.total_duration_hours / NULLIF(tech.max_daily_hours, 0) * 100) AS time_constraint_utilization_pct,
            (r.total_distance_miles <= tech.max_daily_distance_miles) AS is_within_distance_constraint,
            (r.total_duration_hours <= tech.max_daily_hours) AS is_within_time_constraint,
            (r.route_status = 'completed') AS is_completed,
            (r.route_status = 'cancelled') AS is_cancelled,
            r.source_system,
            r.created_at,
            r.updated_at
        FROM STAGING.ROUTES r
        INNER JOIN ANALYTICS.DIM_TECHNICIAN dt
            ON r.technician_id = dt.technician_id AND dt.is_current = TRUE
        INNER JOIN STAGING.TECHNICIANS tech
            ON r.technician_id = tech.technician_id AND tech.is_current = TRUE
        INNER JOIN ANALYTICS.DIM_DATE dd
            ON r.route_date = dd.date_value
        WHERE r.data_quality_score >= 70
    ) AS source
    ON target.route_id = source.route_id
    WHEN MATCHED THEN
        UPDATE SET
            route_status = source.route_status,
            is_completed = source.is_completed,
            updated_at = source.updated_at,
            load_timestamp = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN
        INSERT (
            route_id, technician_key, route_date_key, optimization_run_id,
            algorithm_used, route_status, total_distance_miles,
            total_duration_minutes, total_duration_hours, num_stops,
            avg_distance_per_stop, avg_duration_per_stop, utilization_percentage,
            optimization_score, computation_time_seconds,
            distance_constraint_utilization_pct, time_constraint_utilization_pct,
            is_within_distance_constraint, is_within_time_constraint,
            is_completed, is_cancelled, source_system, created_at, updated_at
        )
        VALUES (
            source.route_id, source.technician_key, source.route_date_key,
            source.optimization_run_id, source.algorithm_used, source.route_status,
            source.total_distance_miles, source.total_duration_minutes,
            source.total_duration_hours, source.num_stops, source.avg_distance_per_stop,
            source.avg_duration_per_stop, source.utilization_percentage,
            source.optimization_score, source.computation_time_seconds,
            source.distance_constraint_utilization_pct, source.time_constraint_utilization_pct,
            source.is_within_distance_constraint, source.is_within_time_constraint,
            source.is_completed, source.is_cancelled, source.source_system,
            source.created_at, source.updated_at
        );

    RETURN 'Route facts loaded successfully';
END;
$$;

/*------------------------------------------------------------------------------
 * PROCEDURE: Load FACT_ROUTE_STOP from Staging
 *----------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE ANALYTICS.LOAD_FACT_ROUTE_STOP()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    MERGE INTO ANALYTICS.FACT_ROUTE_STOP AS target
    USING (
        SELECT
            rs.stop_id,
            fr.route_key,
            fwo.work_order_key,
            dp.property_key,
            dt.technician_key,
            dd1.date_key AS route_date_key,
            dd2.date_key AS arrival_date_key,
            rs.route_id,
            rs.work_order_id,
            rs.stop_status,
            rs.sequence_number,
            rs.is_first_stop,
            rs.is_last_stop,
            rs.arrival_time,
            rs.departure_time,
            rs.actual_duration_minutes,
            wo.estimated_duration_minutes,
            rs.actual_duration_minutes - wo.estimated_duration_minutes AS duration_variance_minutes,
            rs.travel_distance_miles,
            rs.travel_duration_minutes,
            (rs.stop_status = 'completed') AS is_completed,
            (rs.stop_status = 'skipped') AS is_skipped,
            rs.notes,
            rs.source_system,
            rs.created_at,
            rs.updated_at
        FROM STAGING.ROUTE_STOPS rs
        LEFT JOIN ANALYTICS.FACT_ROUTE fr
            ON rs.route_id = fr.route_id
        LEFT JOIN ANALYTICS.FACT_WORK_ORDER fwo
            ON rs.work_order_id = fwo.work_order_id
        LEFT JOIN STAGING.WORK_ORDERS wo
            ON rs.work_order_id = wo.work_order_id
        LEFT JOIN ANALYTICS.DIM_PROPERTY dp
            ON wo.property_id = dp.property_id AND dp.is_current = TRUE
        LEFT JOIN ANALYTICS.DIM_TECHNICIAN dt
            ON fr.technician_key = dt.technician_key
        LEFT JOIN ANALYTICS.DIM_DATE dd1
            ON TO_DATE(rs.arrival_time) = dd1.date_value
        LEFT JOIN ANALYTICS.DIM_DATE dd2
            ON TO_DATE(rs.arrival_time) = dd2.date_value
        WHERE rs.data_quality_score >= 70
    ) AS source
    ON target.stop_id = source.stop_id
    WHEN MATCHED THEN
        UPDATE SET
            stop_status = source.stop_status,
            departure_time = source.departure_time,
            actual_duration_minutes = source.actual_duration_minutes,
            duration_variance_minutes = source.duration_variance_minutes,
            is_completed = source.is_completed,
            is_skipped = source.is_skipped,
            updated_at = source.updated_at,
            load_timestamp = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN
        INSERT (
            stop_id, route_key, work_order_key, property_key, technician_key,
            route_date_key, arrival_date_key, route_id, work_order_id,
            stop_status, sequence_number, is_first_stop, is_last_stop,
            arrival_time, departure_time, actual_duration_minutes,
            estimated_duration_minutes, duration_variance_minutes,
            travel_distance_miles, travel_duration_minutes,
            is_completed, is_skipped, notes, source_system,
            created_at, updated_at
        )
        VALUES (
            source.stop_id, source.route_key, source.work_order_key,
            source.property_key, source.technician_key, source.route_date_key,
            source.arrival_date_key, source.route_id, source.work_order_id,
            source.stop_status, source.sequence_number, source.is_first_stop,
            source.is_last_stop, source.arrival_time, source.departure_time,
            source.actual_duration_minutes, source.estimated_duration_minutes,
            source.duration_variance_minutes, source.travel_distance_miles,
            source.travel_duration_minutes, source.is_completed, source.is_skipped,
            source.notes, source.source_system, source.created_at, source.updated_at
        );

    RETURN 'Route stop facts loaded successfully';
END;
$$;

/*==============================================================================
 * END OF SCRIPT
 *============================================================================*/
