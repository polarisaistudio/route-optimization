/*==============================================================================
 * QUERY: Geographic Zone Analysis
 *
 * Purpose: Analyze service density, travel patterns, and efficiency by zone
 * Author: Route Optimization Team
 * Created: 2026-02-12
 *
 * Use Case: Territory planning, technician assignment optimization, zone coverage
 * Frequency: Run monthly for strategic planning
 *============================================================================*/

USE ROLE ANALYST_ROLE;
USE DATABASE FIELD_SERVICE_OPS;
USE SCHEMA ANALYTICS;
USE WAREHOUSE ANALYTICS_WH;

/*------------------------------------------------------------------------------
 * PARAMETERS: Set analysis period
 *----------------------------------------------------------------------------*/

SET start_date = DATEADD(day, -90, CURRENT_DATE);  -- Last 90 days
SET end_date = CURRENT_DATE;

SELECT
    '=== GEOGRAPHIC ZONE ANALYSIS ===' AS report_header,
    $start_date AS analysis_start_date,
    $end_date AS analysis_end_date;

/*------------------------------------------------------------------------------
 * SECTION 1: Zone Service Volume and Coverage
 *----------------------------------------------------------------------------*/

WITH zone_metrics AS (
    SELECT
        dp.zone_id,
        COUNT(DISTINCT frs.route_key) AS total_routes,
        COUNT(DISTINCT frs.property_key) AS unique_properties_served,
        COUNT(DISTINCT dt.technician_key) AS unique_technicians,
        COUNT(*) AS total_stops,
        SUM(CASE WHEN frs.is_completed THEN 1 ELSE 0 END) AS completed_stops,
        SUM(CASE WHEN frs.is_skipped THEN 1 ELSE 0 END) AS skipped_stops,
        ROUND(AVG(frs.travel_distance_miles), 2) AS avg_travel_distance_per_stop,
        ROUND(AVG(frs.travel_duration_minutes), 2) AS avg_travel_time_per_stop,
        ROUND(AVG(frs.actual_duration_minutes), 2) AS avg_service_time_per_stop,
        SUM(frs.travel_distance_miles) AS total_travel_distance,
        SUM(frs.travel_duration_minutes) AS total_travel_time,
        COUNT(DISTINCT dp.city) AS cities_in_zone,
        COUNT(DISTINCT DATE(frs.created_at)) AS days_active
    FROM ANALYTICS.FACT_ROUTE_STOP frs
    INNER JOIN ANALYTICS.DIM_PROPERTY dp
        ON frs.property_key = dp.property_key
    INNER JOIN ANALYTICS.DIM_DATE dd
        ON frs.route_date_key = dd.date_key
    LEFT JOIN ANALYTICS.DIM_TECHNICIAN dt
        ON frs.technician_key = dt.technician_key
    WHERE dd.date_value BETWEEN $start_date AND $end_date
      AND dp.zone_id IS NOT NULL
    GROUP BY dp.zone_id
)

SELECT
    '--- Zone Service Volume Overview ---' AS zone_overview_section,
    zone_id,
    total_routes AS routes_serving_zone,
    unique_properties_served AS properties_served,
    unique_technicians AS technicians_assigned,
    total_stops,
    completed_stops,
    skipped_stops,
    ROUND(completed_stops * 100.0 / NULLIF(total_stops, 0), 1) AS completion_rate_pct,
    cities_in_zone,
    days_active AS days_with_activity,
    ROUND(total_stops / NULLIF(days_active, 0), 1) AS avg_stops_per_day
FROM zone_metrics
ORDER BY total_stops DESC;

/*------------------------------------------------------------------------------
 * SECTION 2: Zone Density Analysis
 *----------------------------------------------------------------------------*/

WITH property_density AS (
    SELECT
        zone_id,
        COUNT(*) AS total_properties,
        COUNT(CASE WHEN property_type = 'residential' THEN 1 END) AS residential_count,
        COUNT(CASE WHEN property_type = 'commercial' THEN 1 END) AS commercial_count,
        COUNT(CASE WHEN property_type = 'industrial' THEN 1 END) AS industrial_count,
        ROUND(AVG(square_footage), 0) AS avg_square_footage,
        COUNT(DISTINCT city) AS cities_in_zone
    FROM ANALYTICS.DIM_PROPERTY
    WHERE is_current = TRUE
      AND zone_id IS NOT NULL
    GROUP BY zone_id
),
work_order_demand AS (
    SELECT
        dp.zone_id,
        COUNT(*) AS total_work_orders,
        COUNT(CASE WHEN fwo.is_emergency THEN 1 END) AS emergency_work_orders,
        ROUND(AVG(fwo.estimated_duration_minutes), 1) AS avg_job_duration,
        COUNT(CASE WHEN fwo.category = 'HVAC' THEN 1 END) AS hvac_jobs,
        COUNT(CASE WHEN fwo.category = 'plumbing' THEN 1 END) AS plumbing_jobs,
        COUNT(CASE WHEN fwo.category = 'electrical' THEN 1 END) AS electrical_jobs
    FROM ANALYTICS.FACT_WORK_ORDER fwo
    INNER JOIN ANALYTICS.DIM_PROPERTY dp
        ON fwo.property_key = dp.property_key
    INNER JOIN ANALYTICS.DIM_DATE dd
        ON fwo.created_date_key = dd.date_key
    WHERE dd.date_value BETWEEN $start_date AND $end_date
      AND dp.zone_id IS NOT NULL
    GROUP BY dp.zone_id
)

SELECT
    '--- Zone Density & Demand Analysis ---' AS density_section,
    pd.zone_id,
    pd.total_properties,
    pd.residential_count,
    pd.commercial_count,
    pd.industrial_count,
    pd.avg_square_footage,
    pd.cities_in_zone,
    COALESCE(wod.total_work_orders, 0) AS work_orders_created,
    COALESCE(wod.emergency_work_orders, 0) AS emergency_jobs,
    ROUND(COALESCE(wod.total_work_orders, 0) * 1.0 / NULLIF(pd.total_properties, 0), 2) AS work_orders_per_property,
    ROUND(COALESCE(wod.avg_job_duration, 0), 1) AS avg_job_duration_min,

    -- Service demand intensity
    CASE
        WHEN COALESCE(wod.total_work_orders, 0) * 1.0 / NULLIF(pd.total_properties, 0) >= 0.5 THEN 'High Demand'
        WHEN COALESCE(wod.total_work_orders, 0) * 1.0 / NULLIF(pd.total_properties, 0) >= 0.25 THEN 'Moderate Demand'
        ELSE 'Low Demand'
    END AS demand_intensity

FROM property_density pd
LEFT JOIN work_order_demand wod
    ON pd.zone_id = wod.zone_id
ORDER BY work_orders_per_property DESC;

/*------------------------------------------------------------------------------
 * SECTION 3: Travel Efficiency by Zone
 *----------------------------------------------------------------------------*/

WITH zone_travel AS (
    SELECT
        dp.zone_id,
        COUNT(*) AS total_stops,
        ROUND(AVG(frs.travel_distance_miles), 3) AS avg_travel_distance_miles,
        ROUND(AVG(frs.travel_duration_minutes), 2) AS avg_travel_time_minutes,
        ROUND(MIN(frs.travel_distance_miles), 3) AS min_travel_distance,
        ROUND(MAX(frs.travel_distance_miles), 3) AS max_travel_distance,
        ROUND(STDDEV(frs.travel_distance_miles), 3) AS stddev_travel_distance,

        -- Calculate average speed
        ROUND(AVG(
            CASE
                WHEN frs.travel_duration_minutes > 0
                THEN (frs.travel_distance_miles / (frs.travel_duration_minutes / 60.0))
                ELSE NULL
            END
        ), 2) AS avg_travel_speed_mph,

        -- Service time
        ROUND(AVG(frs.actual_duration_minutes), 2) AS avg_service_time_minutes,

        -- Calculate travel vs service time ratio
        ROUND(AVG(frs.travel_duration_minutes) * 100.0 /
              NULLIF(AVG(frs.travel_duration_minutes) + AVG(frs.actual_duration_minutes), 0), 1) AS travel_time_pct
    FROM ANALYTICS.FACT_ROUTE_STOP frs
    INNER JOIN ANALYTICS.DIM_PROPERTY dp
        ON frs.property_key = dp.property_key
    INNER JOIN ANALYTICS.DIM_DATE dd
        ON frs.route_date_key = dd.date_key
    WHERE dd.date_value BETWEEN $start_date AND $end_date
      AND dp.zone_id IS NOT NULL
      AND frs.travel_distance_miles > 0  -- Exclude first stops
    GROUP BY dp.zone_id
)

SELECT
    '--- Travel Efficiency by Zone ---' AS travel_section,
    zone_id,
    total_stops,
    avg_travel_distance_miles,
    avg_travel_time_minutes,
    min_travel_distance,
    max_travel_distance,
    stddev_travel_distance,
    avg_travel_speed_mph,
    avg_service_time_minutes,
    travel_time_pct,

    -- Efficiency rating based on travel time percentage
    CASE
        WHEN travel_time_pct <= 25 THEN 'Excellent (<=25% travel)'
        WHEN travel_time_pct <= 35 THEN 'Good (25-35% travel)'
        WHEN travel_time_pct <= 45 THEN 'Fair (35-45% travel)'
        ELSE 'Poor (>45% travel)'
    END AS efficiency_rating,

    -- Compactness indicator (lower stddev = more compact)
    CASE
        WHEN stddev_travel_distance <= 2 THEN 'High (Compact)'
        WHEN stddev_travel_distance <= 4 THEN 'Medium'
        ELSE 'Low (Dispersed)'
    END AS zone_compactness

FROM zone_travel
ORDER BY travel_time_pct ASC;

/*------------------------------------------------------------------------------
 * SECTION 4: Zone-to-Zone Travel Patterns
 *----------------------------------------------------------------------------*/

WITH zone_transitions AS (
    SELECT
        dp1.zone_id AS from_zone,
        dp2.zone_id AS to_zone,
        COUNT(*) AS transition_count,
        ROUND(AVG(frs2.travel_distance_miles), 2) AS avg_cross_zone_distance,
        ROUND(AVG(frs2.travel_duration_minutes), 2) AS avg_cross_zone_time
    FROM ANALYTICS.FACT_ROUTE_STOP frs1
    INNER JOIN ANALYTICS.FACT_ROUTE_STOP frs2
        ON frs1.route_key = frs2.route_key
        AND frs2.sequence_number = frs1.sequence_number + 1
    INNER JOIN ANALYTICS.DIM_PROPERTY dp1
        ON frs1.property_key = dp1.property_key
    INNER JOIN ANALYTICS.DIM_PROPERTY dp2
        ON frs2.property_key = dp2.property_key
    INNER JOIN ANALYTICS.DIM_DATE dd
        ON frs1.route_date_key = dd.date_key
    WHERE dd.date_value BETWEEN $start_date AND $end_date
      AND dp1.zone_id IS NOT NULL
      AND dp2.zone_id IS NOT NULL
      AND dp1.zone_id != dp2.zone_id  -- Cross-zone transitions only
    GROUP BY dp1.zone_id, dp2.zone_id
)

SELECT
    '--- Cross-Zone Travel Patterns ---' AS cross_zone_section,
    from_zone,
    to_zone,
    transition_count AS times_traveled,
    avg_cross_zone_distance AS avg_distance_miles,
    avg_cross_zone_time AS avg_time_minutes,
    ROUND(avg_cross_zone_distance * 0.58, 2) AS avg_vehicle_cost
FROM zone_transitions
WHERE transition_count >= 5  -- Only show significant patterns
ORDER BY transition_count DESC
LIMIT 20;

/*------------------------------------------------------------------------------
 * SECTION 5: Technician Zone Affinity
 *----------------------------------------------------------------------------*/

WITH technician_zone_work AS (
    SELECT
        dt.technician_id,
        dt.name AS technician_name,
        dt.zone_preference,
        dp.zone_id AS service_zone,
        COUNT(*) AS stops_in_zone,
        ROUND(AVG(frs.travel_distance_miles), 2) AS avg_travel_distance,
        ROUND(AVG(frs.actual_duration_minutes), 2) AS avg_service_time,
        SUM(CASE WHEN frs.is_completed THEN 1 ELSE 0 END) AS completed_stops,
        ROUND(SUM(CASE WHEN frs.is_completed THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS completion_rate_pct
    FROM ANALYTICS.FACT_ROUTE_STOP frs
    INNER JOIN ANALYTICS.DIM_TECHNICIAN dt
        ON frs.technician_key = dt.technician_key
    INNER JOIN ANALYTICS.DIM_PROPERTY dp
        ON frs.property_key = dp.property_key
    INNER JOIN ANALYTICS.DIM_DATE dd
        ON frs.route_date_key = dd.date_key
    WHERE dd.date_value BETWEEN $start_date AND $end_date
      AND dp.zone_id IS NOT NULL
      AND dt.is_current = TRUE
    GROUP BY
        dt.technician_id,
        dt.name,
        dt.zone_preference,
        dp.zone_id
)

SELECT
    '--- Technician Zone Performance ---' AS tech_zone_section,
    technician_name,
    zone_preference AS preferred_zone,
    service_zone AS actual_service_zone,
    CASE
        WHEN zone_preference = service_zone THEN 'Match'
        ELSE 'Different'
    END AS preference_match,
    stops_in_zone,
    avg_travel_distance,
    avg_service_time,
    completed_stops,
    completion_rate_pct,

    -- Performance indicator
    CASE
        WHEN completion_rate_pct >= 95 AND avg_travel_distance <= 5 THEN 'High Performer'
        WHEN completion_rate_pct >= 85 THEN 'Good Performer'
        ELSE 'Needs Review'
    END AS performance_indicator

FROM technician_zone_work
WHERE stops_in_zone >= 10  -- Minimum sample size
ORDER BY
    technician_name,
    stops_in_zone DESC;

/*------------------------------------------------------------------------------
 * SECTION 6: Zone Service Time Analysis
 *----------------------------------------------------------------------------*/

WITH zone_timing AS (
    SELECT
        dp.zone_id,
        COUNT(*) AS total_stops,
        ROUND(AVG(frs.actual_duration_minutes), 2) AS avg_service_duration,
        ROUND(MIN(frs.actual_duration_minutes), 2) AS min_service_duration,
        ROUND(MAX(frs.actual_duration_minutes), 2) AS max_service_duration,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY frs.actual_duration_minutes), 2) AS median_service_duration,
        ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY frs.actual_duration_minutes), 2) AS p75_service_duration,
        ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY frs.actual_duration_minutes), 2) AS p90_service_duration,

        -- Time window compliance
        COUNT(CASE WHEN fwo.is_time_constrained THEN 1 END) AS time_constrained_jobs,
        COUNT(CASE WHEN fwo.is_on_time THEN 1 END) AS on_time_jobs,
        ROUND(COUNT(CASE WHEN fwo.is_on_time THEN 1 END) * 100.0 /
              NULLIF(COUNT(CASE WHEN fwo.is_time_constrained THEN 1 END), 0), 1) AS on_time_pct
    FROM ANALYTICS.FACT_ROUTE_STOP frs
    INNER JOIN ANALYTICS.DIM_PROPERTY dp
        ON frs.property_key = dp.property_key
    LEFT JOIN ANALYTICS.FACT_WORK_ORDER fwo
        ON frs.work_order_key = fwo.work_order_key
    INNER JOIN ANALYTICS.DIM_DATE dd
        ON frs.route_date_key = dd.date_key
    WHERE dd.date_value BETWEEN $start_date AND $end_date
      AND dp.zone_id IS NOT NULL
      AND frs.actual_duration_minutes IS NOT NULL
    GROUP BY dp.zone_id
)

SELECT
    '--- Zone Service Time Analysis ---' AS timing_section,
    zone_id,
    total_stops,
    avg_service_duration AS avg_minutes,
    min_service_duration AS min_minutes,
    max_service_duration AS max_minutes,
    median_service_duration AS median_minutes,
    p75_service_duration AS p75_minutes,
    p90_service_duration AS p90_minutes,
    time_constrained_jobs,
    on_time_jobs,
    on_time_pct,

    -- Service time category
    CASE
        WHEN avg_service_duration <= 30 THEN 'Quick (<30 min)'
        WHEN avg_service_duration <= 60 THEN 'Standard (30-60 min)'
        WHEN avg_service_duration <= 120 THEN 'Extended (60-120 min)'
        ELSE 'Complex (>120 min)'
    END AS service_time_category

FROM zone_timing
ORDER BY avg_service_duration DESC;

/*------------------------------------------------------------------------------
 * SECTION 7: Zone Cost Analysis
 *----------------------------------------------------------------------------*/

WITH zone_costs AS (
    SELECT
        dp.zone_id,
        COUNT(DISTINCT fr.route_key) AS total_routes,
        COUNT(*) AS total_stops,
        SUM(frs.travel_distance_miles) AS total_travel_miles,
        SUM(frs.travel_duration_minutes) AS total_travel_minutes,
        SUM(frs.actual_duration_minutes) AS total_service_minutes,

        -- Cost calculations
        ROUND(SUM(frs.travel_distance_miles * 0.58), 2) AS total_vehicle_cost,
        ROUND(SUM((frs.travel_duration_minutes + frs.actual_duration_minutes) / 60.0 * dt.hourly_rate), 2) AS total_labor_cost,
        ROUND(AVG(dt.hourly_rate), 2) AS avg_hourly_rate
    FROM ANALYTICS.FACT_ROUTE_STOP frs
    INNER JOIN ANALYTICS.DIM_PROPERTY dp
        ON frs.property_key = dp.property_key
    INNER JOIN ANALYTICS.FACT_ROUTE fr
        ON frs.route_key = fr.route_key
    INNER JOIN ANALYTICS.DIM_TECHNICIAN dt
        ON fr.technician_key = dt.technician_key
    INNER JOIN ANALYTICS.DIM_DATE dd
        ON frs.route_date_key = dd.date_key
    WHERE dd.date_value BETWEEN $start_date AND $end_date
      AND dp.zone_id IS NOT NULL
    GROUP BY dp.zone_id
)

SELECT
    '--- Zone Cost Analysis ---' AS cost_section,
    zone_id,
    total_routes,
    total_stops,
    ROUND(total_travel_miles, 1) AS total_miles,
    ROUND(total_travel_minutes / 60.0, 1) AS total_travel_hours,
    ROUND(total_service_minutes / 60.0, 1) AS total_service_hours,
    CONCAT('$', total_vehicle_cost) AS vehicle_cost,
    CONCAT('$', total_labor_cost) AS labor_cost,
    CONCAT('$', total_vehicle_cost + total_labor_cost) AS total_operational_cost,
    CONCAT('$', ROUND((total_vehicle_cost + total_labor_cost) / total_stops, 2)) AS cost_per_stop,
    CONCAT('$', ROUND((total_vehicle_cost + total_labor_cost) / total_routes, 2)) AS cost_per_route,

    -- Cost efficiency rating
    CASE
        WHEN (total_vehicle_cost + total_labor_cost) / total_stops <= 50 THEN 'Low Cost'
        WHEN (total_vehicle_cost + total_labor_cost) / total_stops <= 75 THEN 'Moderate Cost'
        ELSE 'High Cost'
    END AS cost_efficiency

FROM zone_costs
ORDER BY (total_vehicle_cost + total_labor_cost) / total_stops ASC;

/*------------------------------------------------------------------------------
 * SECTION 8: Zone Coverage Gaps and Recommendations
 *----------------------------------------------------------------------------*/

WITH zone_summary AS (
    SELECT
        dp.zone_id,
        COUNT(DISTINCT dp.property_key) AS total_properties,
        COUNT(DISTINCT frs.property_key) AS properties_serviced,
        COUNT(DISTINCT frs.route_key) AS routes_in_zone,
        COUNT(*) AS total_stops,
        ROUND(AVG(frs.travel_distance_miles), 2) AS avg_travel_distance,
        ROUND(AVG(frs.travel_duration_minutes), 2) AS avg_travel_time,
        COUNT(DISTINCT dt.technician_key) AS unique_technicians
    FROM ANALYTICS.DIM_PROPERTY dp
    LEFT JOIN ANALYTICS.FACT_ROUTE_STOP frs
        ON dp.property_key = frs.property_key
    LEFT JOIN ANALYTICS.DIM_DATE dd
        ON frs.route_date_key = dd.date_key
        AND dd.date_value BETWEEN $start_date AND $end_date
    LEFT JOIN ANALYTICS.DIM_TECHNICIAN dt
        ON frs.technician_key = dt.technician_key
    WHERE dp.is_current = TRUE
      AND dp.zone_id IS NOT NULL
    GROUP BY dp.zone_id
)

SELECT
    '--- Zone Coverage & Recommendations ---' AS recommendations_section,
    zone_id,
    total_properties,
    properties_serviced,
    ROUND(properties_serviced * 100.0 / NULLIF(total_properties, 0), 1) AS coverage_pct,
    routes_in_zone,
    total_stops,
    unique_technicians,
    ROUND(total_stops / NULLIF(unique_technicians, 0), 1) AS stops_per_technician,
    avg_travel_distance,
    avg_travel_time,

    -- Coverage status
    CASE
        WHEN properties_serviced * 100.0 / NULLIF(total_properties, 0) >= 75 THEN 'Good Coverage'
        WHEN properties_serviced * 100.0 / NULLIF(total_properties, 0) >= 50 THEN 'Moderate Coverage'
        WHEN properties_serviced * 100.0 / NULLIF(total_properties, 0) >= 25 THEN 'Low Coverage'
        ELSE 'Very Low Coverage'
    END AS coverage_status,

    -- Recommendations
    CASE
        WHEN properties_serviced * 100.0 / NULLIF(total_properties, 0) < 50
            THEN 'Consider assigning dedicated technician'
        WHEN avg_travel_time > 20
            THEN 'High travel time - consider route optimization'
        WHEN unique_technicians < 2
            THEN 'Limited technician diversity - add backup coverage'
        WHEN total_stops / NULLIF(unique_technicians, 0) > 100
            THEN 'High workload - consider additional resources'
        ELSE 'No immediate action needed'
    END AS recommendation

FROM zone_summary
ORDER BY coverage_pct ASC, total_properties DESC;

/*==============================================================================
 * END OF QUERY
 *============================================================================*/
