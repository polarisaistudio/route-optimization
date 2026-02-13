/*==============================================================================
 * ANALYTICS VIEW: Route Performance Analysis
 *
 * Purpose: Comprehensive route performance metrics for optimization analysis
 * Author: Route Optimization Team
 * Created: 2026-02-12
 *
 * Features:
 *   - Route-level KPIs and metrics
 *   - Technician performance indicators
 *   - Stop efficiency analysis
 *   - Time and distance utilization
 *   - Optimization algorithm comparison
 *
 * Grain: One row per route
 *============================================================================*/

USE ROLE ADMIN_ROLE;
USE DATABASE FIELD_SERVICE_OPS;
USE SCHEMA ANALYTICS;
USE WAREHOUSE ANALYTICS_WH;

CREATE OR REPLACE VIEW ANALYTICS.VW_ROUTE_PERFORMANCE
COMMENT = 'Route performance analysis with comprehensive KPIs'
AS
SELECT
    /*--------------------------------------------------------------------------
     * Route Identification
     *------------------------------------------------------------------------*/
    fr.route_id,
    fr.optimization_run_id,
    fr.algorithm_used,
    fr.route_status,

    /*--------------------------------------------------------------------------
     * Date Information
     *------------------------------------------------------------------------*/
    dd.date_value AS route_date,
    dd.day_of_week_name,
    dd.is_weekday,
    dd.is_weekend,
    dd.week_of_year,
    dd.month_name,
    dd.quarter_name,
    dd.year_number,

    /*--------------------------------------------------------------------------
     * Technician Information
     *------------------------------------------------------------------------*/
    dt.technician_id,
    dt.name AS technician_name,
    dt.skill_count AS technician_skill_count,
    dt.has_hvac_skill,
    dt.has_electrical_skill,
    dt.has_plumbing_skill,
    dt.max_daily_hours AS technician_max_hours,
    dt.max_daily_distance_miles AS technician_max_distance,
    dt.hourly_rate,
    dt.capacity_level,
    dt.zone_preference,

    /*--------------------------------------------------------------------------
     * Route Metrics
     *------------------------------------------------------------------------*/
    fr.num_stops,
    fr.total_distance_miles,
    fr.total_duration_minutes,
    fr.total_duration_hours,

    /*--------------------------------------------------------------------------
     * Average Metrics per Stop
     *------------------------------------------------------------------------*/
    fr.avg_distance_per_stop,
    fr.avg_duration_per_stop,
    ROUND(fr.total_distance_miles / NULLIF(fr.total_duration_hours, 0), 2) AS avg_speed_mph,

    /*--------------------------------------------------------------------------
     * Utilization Metrics
     *------------------------------------------------------------------------*/
    fr.utilization_percentage AS time_utilization_pct,
    fr.distance_constraint_utilization_pct,
    fr.time_constraint_utilization_pct,

    -- Efficiency ratings
    CASE
        WHEN fr.utilization_percentage >= 90 THEN 'Excellent'
        WHEN fr.utilization_percentage >= 75 THEN 'Good'
        WHEN fr.utilization_percentage >= 60 THEN 'Fair'
        ELSE 'Poor'
    END AS utilization_rating,

    /*--------------------------------------------------------------------------
     * Constraint Compliance
     *------------------------------------------------------------------------*/
    fr.is_within_distance_constraint,
    fr.is_within_time_constraint,
    CASE
        WHEN fr.is_within_distance_constraint AND fr.is_within_time_constraint THEN 'Compliant'
        WHEN NOT fr.is_within_distance_constraint THEN 'Distance Exceeded'
        WHEN NOT fr.is_within_time_constraint THEN 'Time Exceeded'
        ELSE 'Non-Compliant'
    END AS constraint_status,

    -- Remaining capacity
    dt.max_daily_distance_miles - fr.total_distance_miles AS remaining_distance_capacity,
    dt.max_daily_hours - fr.total_duration_hours AS remaining_time_capacity,

    /*--------------------------------------------------------------------------
     * Cost Metrics
     *------------------------------------------------------------------------*/
    ROUND(fr.total_duration_hours * dt.hourly_rate, 2) AS total_labor_cost,
    ROUND((fr.total_duration_hours * dt.hourly_rate) / NULLIF(fr.num_stops, 0), 2) AS labor_cost_per_stop,

    -- Assuming $0.58/mile for vehicle costs (IRS standard mileage rate)
    ROUND(fr.total_distance_miles * 0.58, 2) AS total_vehicle_cost,
    ROUND((fr.total_distance_miles * 0.58) / NULLIF(fr.num_stops, 0), 2) AS vehicle_cost_per_stop,

    -- Total cost
    ROUND((fr.total_duration_hours * dt.hourly_rate) + (fr.total_distance_miles * 0.58), 2) AS total_route_cost,
    ROUND(((fr.total_duration_hours * dt.hourly_rate) + (fr.total_distance_miles * 0.58)) / NULLIF(fr.num_stops, 0), 2) AS cost_per_stop,

    /*--------------------------------------------------------------------------
     * Stop Details (Aggregated)
     *------------------------------------------------------------------------*/
    COUNT(DISTINCT frs.stop_id) AS actual_stop_count,
    SUM(CASE WHEN frs.is_completed THEN 1 ELSE 0 END) AS completed_stops,
    SUM(CASE WHEN frs.is_skipped THEN 1 ELSE 0 END) AS skipped_stops,
    ROUND(SUM(CASE WHEN frs.is_completed THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(DISTINCT frs.stop_id), 0), 2) AS completion_rate_pct,

    /*--------------------------------------------------------------------------
     * Work Order Categories
     *------------------------------------------------------------------------*/
    SUM(CASE WHEN fwo.category = 'HVAC' THEN 1 ELSE 0 END) AS hvac_stops,
    SUM(CASE WHEN fwo.category = 'plumbing' THEN 1 ELSE 0 END) AS plumbing_stops,
    SUM(CASE WHEN fwo.category = 'electrical' THEN 1 ELSE 0 END) AS electrical_stops,
    SUM(CASE WHEN fwo.category = 'general' THEN 1 ELSE 0 END) AS general_stops,
    SUM(CASE WHEN fwo.category = 'inspection' THEN 1 ELSE 0 END) AS inspection_stops,

    /*--------------------------------------------------------------------------
     * Work Order Priorities
     *------------------------------------------------------------------------*/
    SUM(CASE WHEN fwo.is_emergency THEN 1 ELSE 0 END) AS emergency_stops,
    SUM(CASE WHEN fwo.priority = 'high' THEN 1 ELSE 0 END) AS high_priority_stops,
    SUM(CASE WHEN fwo.priority = 'medium' THEN 1 ELSE 0 END) AS medium_priority_stops,
    SUM(CASE WHEN fwo.priority = 'low' THEN 1 ELSE 0 END) AS low_priority_stops,

    /*--------------------------------------------------------------------------
     * Time Window Compliance
     *------------------------------------------------------------------------*/
    SUM(CASE WHEN fwo.is_time_constrained THEN 1 ELSE 0 END) AS time_constrained_stops,
    SUM(CASE WHEN fwo.is_on_time THEN 1 ELSE 0 END) AS on_time_stops,
    ROUND(SUM(CASE WHEN fwo.is_on_time THEN 1 ELSE 0 END) * 100.0 /
          NULLIF(SUM(CASE WHEN fwo.is_time_constrained THEN 1 ELSE 0 END), 0), 2) AS on_time_delivery_pct,

    /*--------------------------------------------------------------------------
     * Duration Analysis
     *------------------------------------------------------------------------*/
    AVG(frs.actual_duration_minutes) AS avg_stop_duration_minutes,
    AVG(frs.estimated_duration_minutes) AS avg_estimated_duration_minutes,
    AVG(frs.duration_variance_minutes) AS avg_duration_variance_minutes,
    ROUND(AVG(frs.duration_variance_minutes) * 100.0 / NULLIF(AVG(frs.estimated_duration_minutes), 0), 2) AS avg_duration_variance_pct,

    /*--------------------------------------------------------------------------
     * Travel Analysis
     *------------------------------------------------------------------------*/
    SUM(frs.travel_distance_miles) AS total_travel_distance,
    SUM(frs.travel_duration_minutes) AS total_travel_time_minutes,
    AVG(frs.travel_distance_miles) AS avg_travel_distance_per_stop,
    AVG(frs.travel_duration_minutes) AS avg_travel_time_per_stop,
    ROUND(SUM(frs.travel_duration_minutes) * 100.0 / NULLIF(fr.total_duration_minutes, 0), 2) AS travel_time_percentage,
    ROUND(SUM(frs.actual_duration_minutes) * 100.0 / NULLIF(fr.total_duration_minutes, 0), 2) AS service_time_percentage,

    /*--------------------------------------------------------------------------
     * Geographic Distribution
     *------------------------------------------------------------------------*/
    COUNT(DISTINCT dp.zone_id) AS zones_covered,
    COUNT(DISTINCT dp.city) AS cities_covered,
    MODE(dp.zone_id) AS primary_zone,

    /*--------------------------------------------------------------------------
     * Optimization Metrics
     *------------------------------------------------------------------------*/
    fr.optimization_score,
    fr.computation_time_seconds,

    -- Score categories
    CASE
        WHEN fr.optimization_score >= 0.9 THEN 'Excellent (0.9+)'
        WHEN fr.optimization_score >= 0.75 THEN 'Good (0.75-0.9)'
        WHEN fr.optimization_score >= 0.6 THEN 'Fair (0.6-0.75)'
        ELSE 'Poor (<0.6)'
    END AS optimization_quality,

    /*--------------------------------------------------------------------------
     * Status Flags
     *------------------------------------------------------------------------*/
    fr.is_completed,
    fr.is_cancelled,

    /*--------------------------------------------------------------------------
     * Audit Information
     *------------------------------------------------------------------------*/
    fr.created_at AS route_created_at,
    fr.updated_at AS route_updated_at,
    fr.load_timestamp AS route_loaded_at

FROM ANALYTICS.FACT_ROUTE fr
INNER JOIN ANALYTICS.DIM_DATE dd
    ON fr.route_date_key = dd.date_key
INNER JOIN ANALYTICS.DIM_TECHNICIAN dt
    ON fr.technician_key = dt.technician_key
LEFT JOIN ANALYTICS.FACT_ROUTE_STOP frs
    ON fr.route_key = frs.route_key
LEFT JOIN ANALYTICS.FACT_WORK_ORDER fwo
    ON frs.work_order_key = fwo.work_order_key
LEFT JOIN ANALYTICS.DIM_PROPERTY dp
    ON frs.property_key = dp.property_key

GROUP BY
    fr.route_id,
    fr.optimization_run_id,
    fr.algorithm_used,
    fr.route_status,
    dd.date_value,
    dd.day_of_week_name,
    dd.is_weekday,
    dd.is_weekend,
    dd.week_of_year,
    dd.month_name,
    dd.quarter_name,
    dd.year_number,
    dt.technician_id,
    dt.name,
    dt.skill_count,
    dt.has_hvac_skill,
    dt.has_electrical_skill,
    dt.has_plumbing_skill,
    dt.max_daily_hours,
    dt.max_daily_distance_miles,
    dt.hourly_rate,
    dt.capacity_level,
    dt.zone_preference,
    fr.num_stops,
    fr.total_distance_miles,
    fr.total_duration_minutes,
    fr.total_duration_hours,
    fr.avg_distance_per_stop,
    fr.avg_duration_per_stop,
    fr.utilization_percentage,
    fr.distance_constraint_utilization_pct,
    fr.time_constraint_utilization_pct,
    fr.is_within_distance_constraint,
    fr.is_within_time_constraint,
    fr.optimization_score,
    fr.computation_time_seconds,
    fr.is_completed,
    fr.is_cancelled,
    fr.created_at,
    fr.updated_at,
    fr.load_timestamp
;

/*------------------------------------------------------------------------------
 * GRANT ACCESS
 *----------------------------------------------------------------------------*/

GRANT SELECT ON ANALYTICS.VW_ROUTE_PERFORMANCE TO ROLE ANALYST_ROLE;

/*------------------------------------------------------------------------------
 * SAMPLE QUERIES
 *----------------------------------------------------------------------------*/

/*
-- Top 10 most efficient routes
SELECT
    route_id,
    route_date,
    technician_name,
    num_stops,
    total_distance_miles,
    time_utilization_pct,
    utilization_rating,
    total_route_cost,
    cost_per_stop
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE route_status = 'completed'
ORDER BY time_utilization_pct DESC
LIMIT 10;

-- Routes exceeding constraints
SELECT
    route_id,
    route_date,
    technician_name,
    constraint_status,
    total_distance_miles,
    technician_max_distance,
    total_duration_hours,
    technician_max_hours
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE constraint_status != 'Compliant'
ORDER BY route_date DESC;

-- Average metrics by day of week
SELECT
    day_of_week_name,
    COUNT(*) AS route_count,
    ROUND(AVG(num_stops), 1) AS avg_stops,
    ROUND(AVG(total_distance_miles), 1) AS avg_distance,
    ROUND(AVG(time_utilization_pct), 1) AS avg_utilization,
    ROUND(AVG(completion_rate_pct), 1) AS avg_completion_rate
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE route_status = 'completed'
GROUP BY day_of_week_name
ORDER BY
    CASE day_of_week_name
        WHEN 'Monday' THEN 1
        WHEN 'Tuesday' THEN 2
        WHEN 'Wednesday' THEN 3
        WHEN 'Thursday' THEN 4
        WHEN 'Friday' THEN 5
        WHEN 'Saturday' THEN 6
        WHEN 'Sunday' THEN 7
    END;
*/

/*==============================================================================
 * END OF SCRIPT
 *============================================================================*/
