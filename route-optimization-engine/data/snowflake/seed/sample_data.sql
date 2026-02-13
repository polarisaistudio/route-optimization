/*==============================================================================
 * SAMPLE DATA: Route Optimization Engine
 *
 * Purpose: Seed data for testing and demonstration
 * Author: Route Optimization Team
 * Created: 2026-02-12
 *
 * Location: Denver, CO Metro Area
 * Coordinates: Approximately 39.7392° N, 104.9903° W
 *
 * Contents:
 *   - 10 sample properties (Denver metro)
 *   - 5 sample technicians
 *   - 20 sample work orders
 *   - 3 sample routes with stops
 *============================================================================*/

USE ROLE ADMIN_ROLE;
USE DATABASE FIELD_SERVICE_OPS;
USE SCHEMA RAW;
USE WAREHOUSE INGEST_WH;

/*==============================================================================
 * SAMPLE PROPERTIES - Denver Metro Area
 *============================================================================*/

INSERT INTO RAW.PROPERTIES (
    property_id,
    address,
    city,
    state,
    zip_code,
    lat,
    lng,
    property_type,
    zone_id,
    square_footage,
    access_notes,
    created_at,
    updated_at,
    source_system
) VALUES
    -- Downtown Denver
    ('PROP-001', '1600 Broadway', 'Denver', 'CO', '80202',
     39.7436, -104.9878, 'commercial', 'ZONE-DOWNTOWN', 15000.00,
     'High-rise building. Use service elevator. Security check-in required.',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'CRM_SYSTEM'),

    -- Capitol Hill
    ('PROP-002', '234 E Colfax Ave', 'Denver', 'CO', '80203',
     39.7392, -104.9823, 'residential', 'ZONE-CENTRAL', 2200.00,
     'Single family home. Gate code: 1234. Park on street.',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'CRM_SYSTEM'),

    -- Highlands
    ('PROP-003', '3456 W 32nd Ave', 'Denver', 'CO', '80211',
     39.7635, -105.0295, 'residential', 'ZONE-NORTH', 1800.00,
     'Duplex - Unit A. Key lockbox at front door.',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'CRM_SYSTEM'),

    -- Cherry Creek
    ('PROP-004', '250 Fillmore St', 'Denver', 'CO', '80206',
     39.7224, -104.9531, 'commercial', 'ZONE-EAST', 8500.00,
     'Office building. Contact property manager before arrival.',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'CRM_SYSTEM'),

    -- Washington Park
    ('PROP-005', '789 S Downing St', 'Denver', 'CO', '80209',
     39.7017, -104.9733, 'residential', 'ZONE-SOUTH', 3200.00,
     'Large single family. Dog on property - call first.',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'CRM_SYSTEM'),

    -- Lakewood (West Denver)
    ('PROP-006', '5600 W Colfax Ave', 'Lakewood', 'CO', '80214',
     39.7404, -105.0593, 'commercial', 'ZONE-WEST', 22000.00,
     'Shopping center. Use loading dock entrance.',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'CRM_SYSTEM'),

    -- Aurora (East Denver)
    ('PROP-007', '14500 E Colfax Ave', 'Aurora', 'CO', '80011',
     39.7402, -104.8175, 'industrial', 'ZONE-EAST', 35000.00,
     'Warehouse facility. Report to main office first.',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'CRM_SYSTEM'),

    -- Littleton (South Denver)
    ('PROP-008', '2500 W Main St', 'Littleton', 'CO', '80120',
     39.6139, -105.0067, 'residential', 'ZONE-SOUTH', 2800.00,
     'Townhome community. Visitor parking in front.',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'CRM_SYSTEM'),

    -- Arvada (Northwest)
    ('PROP-009', '7500 Ralston Rd', 'Arvada', 'CO', '80002',
     39.8028, -105.0875, 'commercial', 'ZONE-NORTH', 12000.00,
     'Medical office building. Sign in at reception.',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'CRM_SYSTEM'),

    -- Centennial (Southeast)
    ('PROP-010', '13456 E Arapahoe Rd', 'Centennial', 'CO', '80112',
     39.5926, -104.8458, 'residential', 'ZONE-SOUTH', 4500.00,
     'Luxury home with gate. Code will be provided day-of.',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'CRM_SYSTEM');

/*==============================================================================
 * SAMPLE TECHNICIANS
 *============================================================================*/

INSERT INTO RAW.TECHNICIANS (
    technician_id,
    name,
    email,
    phone,
    home_lat,
    home_lng,
    skills,
    max_daily_hours,
    max_daily_distance_miles,
    hourly_rate,
    availability_status,
    zone_preference,
    created_at,
    updated_at,
    source_system
) VALUES
    ('TECH-001', 'John Martinez', 'john.martinez@fieldservice.com', '720-555-0101',
     39.7294, -104.8319, -- Lives in Aurora
     PARSE_JSON('["HVAC", "electrical", "general"]'),
     8.0, 150.0, 45.00, 'active', 'ZONE-EAST',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'HR_SYSTEM'),

    ('TECH-002', 'Sarah Johnson', 'sarah.johnson@fieldservice.com', '303-555-0102',
     39.7686, -105.0372, -- Lives in Highlands
     PARSE_JSON('["plumbing", "HVAC", "general"]'),
     8.0, 140.0, 42.00, 'active', 'ZONE-NORTH',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'HR_SYSTEM'),

    ('TECH-003', 'Michael Chen', 'michael.chen@fieldservice.com', '720-555-0103',
     39.6503, -104.9878, -- Lives in Littleton
     PARSE_JSON('["electrical", "inspection"]'),
     10.0, 180.0, 52.00, 'active', 'ZONE-SOUTH',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'HR_SYSTEM'),

    ('TECH-004', 'Emily Rodriguez', 'emily.rodriguez@fieldservice.com', '303-555-0104',
     39.7392, -104.9903, -- Lives downtown
     PARSE_JSON('["HVAC", "plumbing", "electrical", "general"]'),
     8.0, 160.0, 48.00, 'active', 'ZONE-CENTRAL',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'HR_SYSTEM'),

    ('TECH-005', 'David Thompson', 'david.thompson@fieldservice.com', '720-555-0105',
     39.8042, -105.0875, -- Lives in Arvada
     PARSE_JSON('["inspection", "general"]'),
     8.0, 130.0, 38.00, 'active', 'ZONE-NORTH',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'HR_SYSTEM');

/*==============================================================================
 * SAMPLE WORK ORDERS
 *============================================================================*/

INSERT INTO RAW.WORK_ORDERS (
    work_order_id,
    property_id,
    title,
    description,
    category,
    priority,
    required_skills,
    estimated_duration_minutes,
    time_window_start,
    time_window_end,
    status,
    assigned_technician_id,
    scheduled_date,
    created_at,
    updated_at,
    source_system
) VALUES
    -- Day 1 Work Orders (Today)
    ('WO-001', 'PROP-001', 'HVAC System Maintenance',
     'Quarterly maintenance on rooftop HVAC units', 'HVAC', 'medium',
     PARSE_JSON('["HVAC"]'), 90,
     DATEADD(hour, 8, CURRENT_DATE), DATEADD(hour, 12, CURRENT_DATE),
     'scheduled', 'TECH-001', CURRENT_DATE,
     DATEADD(day, -5, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    ('WO-002', 'PROP-003', 'Plumbing Leak Repair',
     'Fix leak under kitchen sink', 'plumbing', 'high',
     PARSE_JSON('["plumbing"]'), 60,
     DATEADD(hour, 9, CURRENT_DATE), DATEADD(hour, 14, CURRENT_DATE),
     'scheduled', 'TECH-002', CURRENT_DATE,
     DATEADD(day, -3, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    ('WO-003', 'PROP-005', 'Electrical Outlet Installation',
     'Install 3 new outlets in home office', 'electrical', 'low',
     PARSE_JSON('["electrical"]'), 120,
     DATEADD(hour, 10, CURRENT_DATE), DATEADD(hour, 16, CURRENT_DATE),
     'scheduled', 'TECH-001', CURRENT_DATE,
     DATEADD(day, -7, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    ('WO-004', 'PROP-007', 'Safety Inspection',
     'Annual safety and compliance inspection', 'inspection', 'medium',
     PARSE_JSON('["inspection"]'), 90,
     DATEADD(hour, 13, CURRENT_DATE), DATEADD(hour, 17, CURRENT_DATE),
     'scheduled', 'TECH-003', CURRENT_DATE,
     DATEADD(day, -10, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    ('WO-005', 'PROP-008', 'Furnace Repair',
     'Furnace not heating properly - emergency', 'HVAC', 'emergency',
     PARSE_JSON('["HVAC"]'), 75,
     DATEADD(hour, 8, CURRENT_DATE), DATEADD(hour, 11, CURRENT_DATE),
     'scheduled', 'TECH-004', CURRENT_DATE,
     DATEADD(day, -1, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    ('WO-006', 'PROP-009', 'General Maintenance',
     'Replace air filters and check systems', 'general', 'low',
     PARSE_JSON('["general"]'), 45,
     DATEADD(hour, 14, CURRENT_DATE), DATEADD(hour, 17, CURRENT_DATE),
     'scheduled', 'TECH-005', CURRENT_DATE,
     DATEADD(day, -4, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    ('WO-007', 'PROP-002', 'Water Heater Inspection',
     'Check water heater and flush tank', 'plumbing', 'medium',
     PARSE_JSON('["plumbing"]'), 60,
     DATEADD(hour, 11, CURRENT_DATE), DATEADD(hour, 15, CURRENT_DATE),
     'scheduled', 'TECH-002', CURRENT_DATE,
     DATEADD(day, -6, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    -- Day 2 Work Orders (Tomorrow)
    ('WO-008', 'PROP-004', 'Circuit Breaker Replacement',
     'Replace faulty circuit breaker', 'electrical', 'high',
     PARSE_JSON('["electrical"]'), 90,
     DATEADD(hour, 9, DATEADD(day, 1, CURRENT_DATE)), DATEADD(hour, 12, DATEADD(day, 1, CURRENT_DATE)),
     'scheduled', 'TECH-003', DATEADD(day, 1, CURRENT_DATE),
     DATEADD(day, -2, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    ('WO-009', 'PROP-006', 'HVAC Commercial Service',
     'Commercial HVAC system annual service', 'HVAC', 'medium',
     PARSE_JSON('["HVAC"]'), 120,
     DATEADD(hour, 8, DATEADD(day, 1, CURRENT_DATE)), DATEADD(hour, 12, DATEADD(day, 1, CURRENT_DATE)),
     'scheduled', 'TECH-004', DATEADD(day, 1, CURRENT_DATE),
     DATEADD(day, -8, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    ('WO-010', 'PROP-010', 'Plumbing System Inspection',
     'Pre-sale plumbing inspection', 'inspection', 'medium',
     PARSE_JSON('["plumbing", "inspection"]'), 90,
     DATEADD(hour, 10, DATEADD(day, 1, CURRENT_DATE)), DATEADD(hour, 14, DATEADD(day, 1, CURRENT_DATE)),
     'scheduled', 'TECH-002', DATEADD(day, 1, CURRENT_DATE),
     DATEADD(day, -5, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    -- Pending Work Orders (Future)
    ('WO-011', 'PROP-001', 'Electrical Panel Upgrade',
     'Upgrade electrical panel to 200A service', 'electrical', 'medium',
     PARSE_JSON('["electrical"]'), 240,
     NULL, NULL, 'pending', NULL, NULL,
     DATEADD(day, -3, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    ('WO-012', 'PROP-003', 'Drain Cleaning',
     'Clear main drain line', 'plumbing', 'high',
     PARSE_JSON('["plumbing"]'), 60,
     NULL, NULL, 'pending', NULL, NULL,
     DATEADD(day, -1, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    ('WO-013', 'PROP-005', 'AC Unit Repair',
     'AC not cooling - compressor issue suspected', 'HVAC', 'emergency',
     PARSE_JSON('["HVAC"]'), 120,
     NULL, NULL, 'pending', NULL, NULL,
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    ('WO-014', 'PROP-007', 'Lighting Retrofit',
     'Replace warehouse lighting with LED', 'electrical', 'low',
     PARSE_JSON('["electrical"]'), 180,
     NULL, NULL, 'pending', NULL, NULL,
     DATEADD(day, -12, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    ('WO-015', 'PROP-008', 'General Inspection',
     'Move-in inspection for new tenant', 'inspection', 'medium',
     PARSE_JSON('["inspection"]'), 60,
     NULL, NULL, 'pending', NULL, NULL,
     DATEADD(day, -2, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    ('WO-016', 'PROP-009', 'HVAC Filter Replacement',
     'Replace all HVAC filters in building', 'general', 'low',
     PARSE_JSON('["general", "HVAC"]'), 45,
     NULL, NULL, 'pending', NULL, NULL,
     DATEADD(day, -9, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    ('WO-017', 'PROP-010', 'Sprinkler System Repair',
     'Fix broken sprinkler heads', 'plumbing', 'medium',
     PARSE_JSON('["plumbing"]'), 90,
     NULL, NULL, 'pending', NULL, NULL,
     DATEADD(day, -4, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    ('WO-018', 'PROP-002', 'Smoke Detector Installation',
     'Install hardwired smoke detectors', 'electrical', 'high',
     PARSE_JSON('["electrical"]'), 120,
     NULL, NULL, 'pending', NULL, NULL,
     DATEADD(day, -6, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    ('WO-019', 'PROP-004', 'Thermostat Upgrade',
     'Install smart thermostats in all zones', 'HVAC', 'low',
     PARSE_JSON('["HVAC", "electrical"]'), 90,
     NULL, NULL, 'pending', NULL, NULL,
     DATEADD(day, -11, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM'),

    ('WO-020', 'PROP-006', 'Backflow Prevention Test',
     'Annual backflow preventer inspection', 'inspection', 'medium',
     PARSE_JSON('["plumbing", "inspection"]'), 45,
     NULL, NULL, 'pending', NULL, NULL,
     DATEADD(day, -7, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, 'SERVICE_SYSTEM');

/*==============================================================================
 * SAMPLE ROUTES
 *============================================================================*/

-- Route 1: TECH-001 (John Martinez) - East Zone Route
INSERT INTO RAW.ROUTES (
    route_id,
    optimization_run_id,
    technician_id,
    route_date,
    total_distance_miles,
    total_duration_minutes,
    num_stops,
    algorithm_used,
    optimization_score,
    computation_time_seconds,
    route_status,
    created_at,
    updated_at,
    source_system
) VALUES
    ('ROUTE-001', 'OPT-RUN-2026021201', 'TECH-001', CURRENT_DATE,
     28.5, 240, 2, 'or-tools', 0.92, 3.45, 'in_progress',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'OPTIMIZATION_ENGINE');

-- Route 2: TECH-002 (Sarah Johnson) - North Zone Route
INSERT INTO RAW.ROUTES (
    route_id,
    optimization_run_id,
    technician_id,
    route_date,
    total_distance_miles,
    total_duration_minutes,
    num_stops,
    algorithm_used,
    optimization_score,
    computation_time_seconds,
    route_status,
    created_at,
    updated_at,
    source_system
) VALUES
    ('ROUTE-002', 'OPT-RUN-2026021201', 'TECH-002', CURRENT_DATE,
     22.3, 180, 2, 'or-tools', 0.89, 2.87, 'in_progress',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'OPTIMIZATION_ENGINE');

-- Route 3: TECH-004 (Emily Rodriguez) - Central/South Route
INSERT INTO RAW.ROUTES (
    route_id,
    optimization_run_id,
    technician_id,
    route_date,
    total_distance_miles,
    total_duration_minutes,
    num_stops,
    algorithm_used,
    optimization_score,
    computation_time_seconds,
    route_status,
    created_at,
    updated_at,
    source_system
) VALUES
    ('ROUTE-003', 'OPT-RUN-2026021201', 'TECH-004', CURRENT_DATE,
     18.7, 165, 2, 'or-tools', 0.94, 3.12, 'in_progress',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'OPTIMIZATION_ENGINE');

/*==============================================================================
 * SAMPLE ROUTE STOPS
 *============================================================================*/

-- ROUTE-001 Stops (TECH-001: East Zone)
INSERT INTO RAW.ROUTE_STOPS (
    stop_id,
    route_id,
    work_order_id,
    sequence_number,
    arrival_time,
    departure_time,
    actual_duration_minutes,
    travel_distance_miles,
    travel_duration_minutes,
    stop_status,
    created_at,
    updated_at,
    source_system
) VALUES
    ('STOP-001', 'ROUTE-001', 'WO-001', 1,
     DATEADD(hour, 8, CURRENT_DATE), DATEADD(minute, 90, DATEADD(hour, 8, CURRENT_DATE)),
     90, 12.3, 25, 'completed',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'OPTIMIZATION_ENGINE'),

    ('STOP-002', 'ROUTE-001', 'WO-003', 2,
     DATEADD(hour, 10, CURRENT_DATE), DATEADD(minute, 120, DATEADD(hour, 10, CURRENT_DATE)),
     120, 16.2, 35, 'in_service',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'OPTIMIZATION_ENGINE');

-- ROUTE-002 Stops (TECH-002: North Zone)
INSERT INTO RAW.ROUTE_STOPS (
    stop_id,
    route_id,
    work_order_id,
    sequence_number,
    arrival_time,
    departure_time,
    actual_duration_minutes,
    travel_distance_miles,
    travel_duration_minutes,
    stop_status,
    created_at,
    updated_at,
    source_system
) VALUES
    ('STOP-003', 'ROUTE-002', 'WO-002', 1,
     DATEADD(hour, 9, CURRENT_DATE), DATEADD(minute, 60, DATEADD(hour, 9, CURRENT_DATE)),
     60, 8.5, 18, 'completed',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'OPTIMIZATION_ENGINE'),

    ('STOP-004', 'ROUTE-002', 'WO-007', 2,
     DATEADD(hour, 11, CURRENT_DATE), DATEADD(minute, 60, DATEADD(hour, 11, CURRENT_DATE)),
     60, 13.8, 32, 'arrived',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'OPTIMIZATION_ENGINE');

-- ROUTE-003 Stops (TECH-004: Central/South Zone)
INSERT INTO RAW.ROUTE_STOPS (
    stop_id,
    route_id,
    work_order_id,
    sequence_number,
    arrival_time,
    departure_time,
    actual_duration_minutes,
    travel_distance_miles,
    travel_duration_minutes,
    stop_status,
    created_at,
    updated_at,
    source_system
) VALUES
    ('STOP-005', 'ROUTE-003', 'WO-005', 1,
     DATEADD(hour, 8, CURRENT_DATE), DATEADD(minute, 75, DATEADD(hour, 8, CURRENT_DATE)),
     75, 6.2, 15, 'completed',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'OPTIMIZATION_ENGINE'),

    ('STOP-006', 'ROUTE-003', 'WO-006', 2,
     DATEADD(hour, 14, CURRENT_DATE), NULL,
     NULL, 12.5, 30, 'planned',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'OPTIMIZATION_ENGINE');

/*==============================================================================
 * VERIFICATION QUERIES
 *============================================================================*/

-- Verify data insertion
SELECT '=== DATA VERIFICATION ===' AS section;

SELECT 'Properties Inserted:' AS metric, COUNT(*) AS count FROM RAW.PROPERTIES
UNION ALL
SELECT 'Technicians Inserted:', COUNT(*) FROM RAW.TECHNICIANS
UNION ALL
SELECT 'Work Orders Inserted:', COUNT(*) FROM RAW.WORK_ORDERS
UNION ALL
SELECT 'Routes Inserted:', COUNT(*) FROM RAW.ROUTES
UNION ALL
SELECT 'Route Stops Inserted:', COUNT(*) FROM RAW.ROUTE_STOPS;

-- Display sample records
SELECT '--- Sample Properties ---' AS section;
SELECT property_id, address, city, property_type, zone_id
FROM RAW.PROPERTIES
ORDER BY property_id
LIMIT 5;

SELECT '--- Sample Technicians ---' AS section;
SELECT technician_id, name, skills, max_daily_hours, zone_preference
FROM RAW.TECHNICIANS
ORDER BY technician_id;

SELECT '--- Sample Work Orders ---' AS section;
SELECT work_order_id, property_id, title, category, priority, status
FROM RAW.WORK_ORDERS
ORDER BY work_order_id
LIMIT 10;

SELECT '--- Sample Routes ---' AS section;
SELECT route_id, technician_id, route_date, num_stops,
       total_distance_miles, algorithm_used, route_status
FROM RAW.ROUTES
ORDER BY route_id;

SELECT '--- Sample Route Stops ---' AS section;
SELECT stop_id, route_id, work_order_id, sequence_number,
       stop_status, travel_distance_miles
FROM RAW.ROUTE_STOPS
ORDER BY route_id, sequence_number;

/*------------------------------------------------------------------------------
 * NOTES FOR TESTING
 *----------------------------------------------------------------------------*/

/*
To test the complete data flow:

1. Run staging load procedures:
   CALL STAGING.LOAD_PROPERTIES();
   CALL STAGING.LOAD_TECHNICIANS();
   CALL STAGING.LOAD_WORK_ORDERS();
   CALL STAGING.LOAD_ROUTES();
   CALL STAGING.LOAD_ROUTE_STOPS();

2. Populate date dimension:
   CALL ANALYTICS.POPULATE_DIM_DATE('2026-01-01', '2026-12-31');

3. Load analytics tables:
   CALL ANALYTICS.LOAD_DIM_PROPERTY();
   CALL ANALYTICS.LOAD_DIM_TECHNICIAN();
   CALL ANALYTICS.LOAD_FACT_WORK_ORDER();
   CALL ANALYTICS.LOAD_FACT_ROUTE();
   CALL ANALYTICS.LOAD_FACT_ROUTE_STOP();

4. Query the views:
   SELECT * FROM ANALYTICS.VW_ROUTE_PERFORMANCE LIMIT 10;
   SELECT * FROM ANALYTICS.VW_TECHNICIAN_WORKLOAD LIMIT 10;
   SELECT * FROM ANALYTICS.VW_OPTIMIZATION_COMPARISON LIMIT 10;

5. Run sample queries from the queries folder
*/

/*==============================================================================
 * END OF SCRIPT
 *============================================================================*/
