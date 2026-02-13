/*==============================================================================
 * QUERY: Daily Route Summary with KPIs
 *
 * Purpose: Executive dashboard showing daily route optimization performance
 * Author: Route Optimization Team
 * Created: 2026-02-12
 *
 * Use Case: Daily operations review, management reporting
 * Frequency: Run daily for previous day's performance
 *============================================================================*/

USE ROLE ANALYST_ROLE;
USE DATABASE FIELD_SERVICE_OPS;
USE SCHEMA ANALYTICS;
USE WAREHOUSE ANALYTICS_WH;

/*------------------------------------------------------------------------------
 * SECTION 1: Overall Daily Summary
 *----------------------------------------------------------------------------*/

-- Set the target date (default to yesterday)
SET target_date = DATEADD(day, -1, CURRENT_DATE);

SELECT
    '=== DAILY ROUTE SUMMARY ===' AS section_header,
    $target_date AS report_date,
    DAYNAME($target_date) AS day_of_week;

/*------------------------------------------------------------------------------
 * SECTION 2: Key Performance Indicators (KPIs)
 *----------------------------------------------------------------------------*/

WITH daily_kpis AS (
    SELECT
        COUNT(DISTINCT route_id) AS total_routes,
        COUNT(DISTINCT technician_id) AS active_technicians,
        SUM(num_stops) AS total_stops,
        SUM(total_distance_miles) AS total_miles_driven,
        SUM(total_duration_hours) AS total_hours_worked,
        ROUND(AVG(num_stops), 1) AS avg_stops_per_route,
        ROUND(AVG(total_distance_miles), 1) AS avg_miles_per_route,
        ROUND(AVG(total_duration_hours), 1) AS avg_hours_per_route,
        ROUND(AVG(time_utilization_pct), 1) AS avg_utilization_pct,
        SUM(total_route_cost) AS total_operational_cost,
        SUM(completed_stops) AS completed_stops,
        SUM(skipped_stops) AS skipped_stops,
        ROUND(AVG(completion_rate_pct), 1) AS avg_completion_rate,
        ROUND(AVG(on_time_delivery_pct), 1) AS avg_on_time_rate,
        SUM(emergency_stops) AS emergency_jobs_handled,
        COUNT(CASE WHEN constraint_status != 'Compliant' THEN 1 END) AS constraint_violations
    FROM ANALYTICS.VW_ROUTE_PERFORMANCE
    WHERE route_date = $target_date
)

SELECT
    '--- Key Performance Indicators ---' AS kpi_section,

    -- Volume Metrics
    total_routes AS "Total Routes Executed",
    active_technicians AS "Technicians Deployed",
    total_stops AS "Total Service Stops",
    completed_stops AS "Stops Completed",
    skipped_stops AS "Stops Skipped",

    -- Efficiency Metrics
    avg_stops_per_route AS "Avg Stops per Route",
    avg_miles_per_route AS "Avg Miles per Route",
    avg_hours_per_route AS "Avg Hours per Route",
    avg_utilization_pct AS "Avg Utilization %",

    -- Quality Metrics
    avg_completion_rate AS "Completion Rate %",
    avg_on_time_rate AS "On-Time Delivery %",

    -- Operational Metrics
    CONCAT('$', ROUND(total_operational_cost, 2)) AS "Total Operational Cost",
    CONCAT('$', ROUND(total_operational_cost / total_routes, 2)) AS "Cost per Route",
    CONCAT('$', ROUND(total_operational_cost / total_stops, 2)) AS "Cost per Stop",

    -- Issues
    emergency_jobs_handled AS "Emergency Jobs",
    constraint_violations AS "Constraint Violations"

FROM daily_kpis;

/*------------------------------------------------------------------------------
 * SECTION 3: Routes by Status
 *----------------------------------------------------------------------------*/

SELECT
    '--- Routes by Status ---' AS status_section,
    route_status,
    COUNT(*) AS route_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS percentage,
    SUM(num_stops) AS total_stops,
    ROUND(AVG(time_utilization_pct), 1) AS avg_utilization
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE route_date = $target_date
GROUP BY route_status
ORDER BY route_count DESC;

/*------------------------------------------------------------------------------
 * SECTION 4: Top Performing Technicians
 *----------------------------------------------------------------------------*/

SELECT
    '--- Top 10 Performing Technicians ---' AS top_performers_section,
    technician_name,
    num_stops AS stops_completed,
    ROUND(total_distance_miles, 1) AS miles_driven,
    ROUND(total_duration_hours, 1) AS hours_worked,
    ROUND(time_utilization_pct, 1) AS utilization_pct,
    ROUND(completion_rate_pct, 1) AS completion_rate,
    CONCAT('$', ROUND(total_route_cost, 2)) AS total_cost
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE route_date = $target_date
  AND route_status = 'completed'
ORDER BY time_utilization_pct DESC, num_stops DESC
LIMIT 10;

/*------------------------------------------------------------------------------
 * SECTION 5: Utilization Distribution
 *----------------------------------------------------------------------------*/

SELECT
    '--- Technician Utilization Distribution ---' AS utilization_section,
    utilization_rating,
    COUNT(*) AS technician_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS percentage,
    ROUND(AVG(num_stops), 1) AS avg_stops,
    ROUND(AVG(total_distance_miles), 1) AS avg_miles
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE route_date = $target_date
GROUP BY utilization_rating
ORDER BY
    CASE utilization_rating
        WHEN 'Excellent' THEN 1
        WHEN 'Good' THEN 2
        WHEN 'Fair' THEN 3
        WHEN 'Poor' THEN 4
    END;

/*------------------------------------------------------------------------------
 * SECTION 6: Work Order Category Breakdown
 *----------------------------------------------------------------------------*/

SELECT
    '--- Work Orders by Category ---' AS category_section,
    'HVAC' AS category,
    SUM(hvac_stops) AS job_count,
    ROUND(SUM(hvac_stops) * 100.0 / NULLIF(SUM(num_stops), 0), 1) AS percentage_of_total
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE route_date = $target_date

UNION ALL

SELECT
    '',
    'Plumbing',
    SUM(plumbing_stops),
    ROUND(SUM(plumbing_stops) * 100.0 / NULLIF(SUM(num_stops), 0), 1)
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE route_date = $target_date

UNION ALL

SELECT
    '',
    'Electrical',
    SUM(electrical_stops),
    ROUND(SUM(electrical_stops) * 100.0 / NULLIF(SUM(num_stops), 0), 1)
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE route_date = $target_date

UNION ALL

SELECT
    '',
    'General',
    SUM(general_stops),
    ROUND(SUM(general_stops) * 100.0 / NULLIF(SUM(num_stops), 0), 1)
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE route_date = $target_date

UNION ALL

SELECT
    '',
    'Inspection',
    SUM(inspection_stops),
    ROUND(SUM(inspection_stops) * 100.0 / NULLIF(SUM(num_stops), 0), 1)
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE route_date = $target_date

ORDER BY job_count DESC;

/*------------------------------------------------------------------------------
 * SECTION 7: Priority Distribution
 *----------------------------------------------------------------------------*/

SELECT
    '--- Work Orders by Priority ---' AS priority_section,
    'Emergency' AS priority_level,
    SUM(emergency_stops) AS job_count,
    ROUND(SUM(emergency_stops) * 100.0 / NULLIF(SUM(num_stops), 0), 1) AS percentage_of_total
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE route_date = $target_date

UNION ALL

SELECT
    '',
    'High',
    SUM(high_priority_stops),
    ROUND(SUM(high_priority_stops) * 100.0 / NULLIF(SUM(num_stops), 0), 1)
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE route_date = $target_date

UNION ALL

SELECT
    '',
    'Medium',
    SUM(medium_priority_stops),
    ROUND(SUM(medium_priority_stops) * 100.0 / NULLIF(SUM(num_stops), 0), 1)
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE route_date = $target_date

UNION ALL

SELECT
    '',
    'Low',
    SUM(low_priority_stops),
    ROUND(SUM(low_priority_stops) * 100.0 / NULLIF(SUM(num_stops), 0), 1)
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE route_date = $target_date

ORDER BY job_count DESC;

/*------------------------------------------------------------------------------
 * SECTION 8: Algorithm Performance
 *----------------------------------------------------------------------------*/

SELECT
    '--- Optimization Algorithm Performance ---' AS algorithm_section,
    algorithm_used,
    COUNT(*) AS routes_using_algorithm,
    ROUND(AVG(num_stops), 1) AS avg_stops,
    ROUND(AVG(total_distance_miles), 1) AS avg_distance,
    ROUND(AVG(time_utilization_pct), 1) AS avg_utilization,
    ROUND(AVG(optimization_score), 3) AS avg_optimization_score,
    optimization_quality
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE route_date = $target_date
GROUP BY algorithm_used, optimization_quality
ORDER BY avg_optimization_score DESC;

/*------------------------------------------------------------------------------
 * SECTION 9: Geographic Coverage
 *----------------------------------------------------------------------------*/

SELECT
    '--- Geographic Coverage ---' AS geographic_section,
    primary_zone,
    COUNT(*) AS routes_in_zone,
    SUM(num_stops) AS total_stops,
    ROUND(AVG(total_distance_miles), 1) AS avg_distance,
    ROUND(AVG(total_duration_hours), 1) AS avg_duration,
    COUNT(DISTINCT technician_id) AS technicians_assigned
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE route_date = $target_date
  AND primary_zone IS NOT NULL
GROUP BY primary_zone
ORDER BY routes_in_zone DESC;

/*------------------------------------------------------------------------------
 * SECTION 10: Issues and Alerts
 *----------------------------------------------------------------------------*/

SELECT
    '--- Issues Requiring Attention ---' AS issues_section,
    route_id,
    technician_name,
    constraint_status,
    ROUND(total_distance_miles, 1) AS distance_miles,
    ROUND(technician_max_distance, 1) AS max_allowed_distance,
    ROUND(total_duration_hours, 1) AS hours_worked,
    ROUND(technician_max_hours, 1) AS max_allowed_hours,
    ROUND(completion_rate_pct, 1) AS completion_rate
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE route_date = $target_date
  AND (
      constraint_status != 'Compliant'
      OR completion_rate_pct < 85
      OR skipped_stops > 2
  )
ORDER BY
    CASE constraint_status
        WHEN 'Distance Exceeded' THEN 1
        WHEN 'Time Exceeded' THEN 2
        WHEN 'Non-Compliant' THEN 3
        ELSE 4
    END,
    completion_rate_pct ASC;

/*------------------------------------------------------------------------------
 * SECTION 11: Cost Summary
 *----------------------------------------------------------------------------*/

SELECT
    '--- Cost Summary ---' AS cost_section,
    SUM(total_labor_cost) AS total_labor_cost,
    SUM(total_vehicle_cost) AS total_vehicle_cost,
    SUM(total_route_cost) AS total_operational_cost,
    ROUND(AVG(labor_cost_per_stop), 2) AS avg_labor_cost_per_stop,
    ROUND(AVG(vehicle_cost_per_stop), 2) AS avg_vehicle_cost_per_stop,
    ROUND(AVG(cost_per_stop), 2) AS avg_total_cost_per_stop,
    ROUND(SUM(total_route_cost) / NULLIF(SUM(num_stops), 0), 2) AS blended_cost_per_stop,
    ROUND(SUM(total_route_cost) / NULLIF(COUNT(DISTINCT technician_id), 0), 2) AS cost_per_technician
FROM ANALYTICS.VW_ROUTE_PERFORMANCE
WHERE route_date = $target_date;

/*------------------------------------------------------------------------------
 * SECTION 12: Week-over-Week Comparison
 *----------------------------------------------------------------------------*/

WITH current_week AS (
    SELECT
        COUNT(DISTINCT route_id) AS routes,
        SUM(num_stops) AS stops,
        ROUND(AVG(total_distance_miles), 1) AS avg_distance,
        ROUND(AVG(time_utilization_pct), 1) AS avg_utilization,
        SUM(total_route_cost) AS total_cost
    FROM ANALYTICS.VW_ROUTE_PERFORMANCE
    WHERE route_date = $target_date
),
prior_week AS (
    SELECT
        COUNT(DISTINCT route_id) AS routes,
        SUM(num_stops) AS stops,
        ROUND(AVG(total_distance_miles), 1) AS avg_distance,
        ROUND(AVG(time_utilization_pct), 1) AS avg_utilization,
        SUM(total_route_cost) AS total_cost
    FROM ANALYTICS.VW_ROUTE_PERFORMANCE
    WHERE route_date = DATEADD(day, -7, $target_date)
)

SELECT
    '--- Week-over-Week Comparison ---' AS comparison_section,
    'Current Day' AS period,
    cw.routes,
    cw.stops,
    cw.avg_distance,
    cw.avg_utilization,
    CONCAT('$', ROUND(cw.total_cost, 2)) AS total_cost
FROM current_week cw

UNION ALL

SELECT
    '',
    'Prior Week Same Day',
    pw.routes,
    pw.stops,
    pw.avg_distance,
    pw.avg_utilization,
    CONCAT('$', ROUND(pw.total_cost, 2))
FROM prior_week pw

UNION ALL

SELECT
    '',
    'Change',
    cw.routes - pw.routes,
    cw.stops - pw.stops,
    cw.avg_distance - pw.avg_distance,
    cw.avg_utilization - pw.avg_utilization,
    CONCAT('$', ROUND(cw.total_cost - pw.total_cost, 2))
FROM current_week cw, prior_week pw

UNION ALL

SELECT
    '',
    'Change %',
    ROUND((cw.routes - pw.routes) * 100.0 / NULLIF(pw.routes, 0), 1),
    ROUND((cw.stops - pw.stops) * 100.0 / NULLIF(pw.stops, 0), 1),
    ROUND((cw.avg_distance - pw.avg_distance) * 100.0 / NULLIF(pw.avg_distance, 0), 1),
    ROUND((cw.avg_utilization - pw.avg_utilization) * 100.0 / NULLIF(pw.avg_utilization, 0), 1),
    CONCAT(ROUND((cw.total_cost - pw.total_cost) * 100.0 / NULLIF(pw.total_cost, 0), 1), '%')
FROM current_week cw, prior_week pw;

/*==============================================================================
 * END OF QUERY
 *============================================================================*/
