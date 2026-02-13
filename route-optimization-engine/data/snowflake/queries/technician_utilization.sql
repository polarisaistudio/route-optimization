/*==============================================================================
 * QUERY: Technician Utilization Analysis
 *
 * Purpose: Analyze technician capacity utilization and workload balance
 * Author: Route Optimization Team
 * Created: 2026-02-12
 *
 * Use Case: Resource planning, workload balancing, capacity management
 * Frequency: Run weekly for workforce optimization
 *============================================================================*/

USE ROLE ANALYST_ROLE;
USE DATABASE FIELD_SERVICE_OPS;
USE SCHEMA ANALYTICS;
USE WAREHOUSE ANALYTICS_WH;

/*------------------------------------------------------------------------------
 * PARAMETERS: Set analysis period
 *----------------------------------------------------------------------------*/

SET start_date = DATEADD(day, -30, CURRENT_DATE);  -- Last 30 days
SET end_date = CURRENT_DATE;

SELECT
    '=== TECHNICIAN UTILIZATION ANALYSIS ===' AS report_header,
    $start_date AS analysis_start_date,
    $end_date AS analysis_end_date;

/*------------------------------------------------------------------------------
 * SECTION 1: Overall Technician Utilization Summary
 *----------------------------------------------------------------------------*/

WITH utilization_summary AS (
    SELECT
        COUNT(DISTINCT technician_id) AS total_technicians,
        SUM(CASE WHEN was_scheduled THEN 1 ELSE 0 END) AS total_scheduled_days,
        ROUND(AVG(daily_utilization_pct), 1) AS avg_utilization_pct,
        ROUND(AVG(daily_hours_worked), 1) AS avg_hours_per_day,
        ROUND(AVG(daily_stops), 1) AS avg_stops_per_day,
        ROUND(AVG(daily_distance_miles), 1) AS avg_miles_per_day,
        SUM(daily_total_jobs) AS total_jobs_completed,
        ROUND(AVG(completion_rate_pct), 1) AS avg_completion_rate,
        ROUND(AVG(on_time_rate_pct), 1) AS avg_on_time_rate,
        SUM(daily_labor_revenue) AS total_labor_revenue,
        SUM(daily_vehicle_cost) AS total_vehicle_cost,
        SUM(daily_net_revenue) AS total_net_revenue
    FROM ANALYTICS.VW_TECHNICIAN_WORKLOAD
    WHERE work_date BETWEEN $start_date AND $end_date
      AND was_scheduled = TRUE
)

SELECT
    '--- Overall Summary ---' AS summary_section,
    total_technicians AS "Active Technicians",
    total_scheduled_days AS "Total Scheduled Days",
    avg_utilization_pct AS "Avg Utilization %",
    avg_hours_per_day AS "Avg Hours/Day",
    avg_stops_per_day AS "Avg Stops/Day",
    avg_miles_per_day AS "Avg Miles/Day",
    total_jobs_completed AS "Total Jobs Completed",
    avg_completion_rate AS "Avg Completion Rate %",
    avg_on_time_rate AS "Avg On-Time Rate %",
    CONCAT('$', ROUND(total_labor_revenue, 2)) AS "Total Labor Revenue",
    CONCAT('$', ROUND(total_vehicle_cost, 2)) AS "Total Vehicle Cost",
    CONCAT('$', ROUND(total_net_revenue, 2)) AS "Total Net Revenue"
FROM utilization_summary;

/*------------------------------------------------------------------------------
 * SECTION 2: Technician Ranking by Utilization
 *----------------------------------------------------------------------------*/

SELECT
    '--- Technician Utilization Ranking ---' AS ranking_section,
    technician_name,
    COUNT(DISTINCT work_date) AS days_worked,
    SUM(daily_stops) AS total_stops,
    ROUND(AVG(daily_hours_worked), 1) AS avg_daily_hours,
    ROUND(AVG(daily_utilization_pct), 1) AS avg_utilization_pct,
    utilization_status,
    ROUND(AVG(completion_rate_pct), 1) AS avg_completion_rate,
    ROUND(SUM(daily_labor_revenue), 2) AS total_revenue,
    skill_count,
    capacity_level
FROM ANALYTICS.VW_TECHNICIAN_WORKLOAD
WHERE work_date BETWEEN $start_date AND $end_date
  AND was_scheduled = TRUE
GROUP BY
    technician_name,
    utilization_status,
    skill_count,
    capacity_level
ORDER BY avg_utilization_pct DESC;

/*------------------------------------------------------------------------------
 * SECTION 3: Utilization Distribution
 *----------------------------------------------------------------------------*/

SELECT
    '--- Utilization Distribution ---' AS distribution_section,
    utilization_status,
    COUNT(DISTINCT technician_id) AS technician_count,
    ROUND(COUNT(DISTINCT technician_id) * 100.0 /
          SUM(COUNT(DISTINCT technician_id)) OVER(), 1) AS percentage_of_technicians,
    ROUND(AVG(daily_utilization_pct), 1) AS avg_utilization,
    ROUND(AVG(daily_hours_worked), 1) AS avg_hours,
    ROUND(AVG(daily_stops), 1) AS avg_stops,
    SUM(daily_total_jobs) AS total_jobs
FROM ANALYTICS.VW_TECHNICIAN_WORKLOAD
WHERE work_date BETWEEN $start_date AND $end_date
  AND was_scheduled = TRUE
GROUP BY utilization_status
ORDER BY
    CASE utilization_status
        WHEN 'Overutilized' THEN 1
        WHEN 'Well-Utilized' THEN 2
        WHEN 'Underutilized' THEN 3
        WHEN 'Significantly Underutilized' THEN 4
    END;

/*------------------------------------------------------------------------------
 * SECTION 4: Overutilized Technicians (Need Workload Reduction)
 *----------------------------------------------------------------------------*/

SELECT
    '--- Overutilized Technicians (>=90% Utilization) ---' AS overutilized_section,
    technician_name,
    COUNT(DISTINCT work_date) AS days_worked,
    ROUND(AVG(daily_utilization_pct), 1) AS avg_utilization_pct,
    ROUND(AVG(daily_hours_worked), 1) AS avg_hours_worked,
    ROUND(AVG(max_daily_hours), 1) AS max_hours_allowed,
    ROUND(AVG(remaining_hours_capacity), 1) AS avg_remaining_capacity,
    SUM(CASE WHEN is_overtime THEN 1 ELSE 0 END) AS overtime_days,
    ROUND(SUM(daily_labor_revenue), 2) AS total_revenue
FROM ANALYTICS.VW_TECHNICIAN_WORKLOAD
WHERE work_date BETWEEN $start_date AND $end_date
  AND was_scheduled = TRUE
GROUP BY technician_name
HAVING AVG(daily_utilization_pct) >= 90
ORDER BY avg_utilization_pct DESC;

/*------------------------------------------------------------------------------
 * SECTION 5: Underutilized Technicians (Capacity Available)
 *----------------------------------------------------------------------------*/

SELECT
    '--- Underutilized Technicians (<50% Utilization) ---' AS underutilized_section,
    technician_name,
    COUNT(DISTINCT work_date) AS days_worked,
    ROUND(AVG(daily_utilization_pct), 1) AS avg_utilization_pct,
    ROUND(AVG(daily_hours_worked), 1) AS avg_hours_worked,
    ROUND(AVG(max_daily_hours), 1) AS max_hours_allowed,
    ROUND(AVG(remaining_hours_capacity), 1) AS avg_available_hours,
    ROUND(AVG(daily_stops), 1) AS avg_stops,
    skill_count,
    availability_status,
    zone_preference
FROM ANALYTICS.VW_TECHNICIAN_WORKLOAD
WHERE work_date BETWEEN $start_date AND $end_date
  AND was_scheduled = TRUE
GROUP BY
    technician_name,
    skill_count,
    availability_status,
    zone_preference
HAVING AVG(daily_utilization_pct) < 50
ORDER BY avg_utilization_pct ASC;

/*------------------------------------------------------------------------------
 * SECTION 6: Weekly Workload Trends
 *----------------------------------------------------------------------------*/

SELECT
    '--- Weekly Workload Trends ---' AS weekly_trends_section,
    technician_name,
    week_start_date,
    weekly_days_worked,
    weekly_stops,
    ROUND(weekly_hours_worked, 1) AS weekly_hours,
    ROUND(weekly_avg_utilization_pct, 1) AS avg_utilization,
    ROUND(weekly_capacity_pct, 1) AS weekly_capacity_pct,
    workload_balance,
    CASE WHEN is_weekly_overtime THEN 'Yes' ELSE 'No' END AS overtime
FROM ANALYTICS.VW_TECHNICIAN_WORKLOAD
WHERE work_date BETWEEN $start_date AND $end_date
  AND was_scheduled = TRUE
GROUP BY
    technician_name,
    week_start_date,
    weekly_days_worked,
    weekly_stops,
    weekly_hours_worked,
    weekly_avg_utilization_pct,
    weekly_capacity_pct,
    workload_balance,
    is_weekly_overtime
ORDER BY
    week_start_date DESC,
    weekly_avg_utilization_pct DESC;

/*------------------------------------------------------------------------------
 * SECTION 7: Skill Utilization Analysis
 *----------------------------------------------------------------------------*/

SELECT
    '--- Skill Utilization Analysis ---' AS skill_section,
    technician_name,
    skill_count AS total_skills,
    CASE WHEN has_hvac_skill THEN 'Yes' ELSE 'No' END AS has_hvac,
    CASE WHEN has_electrical_skill THEN 'Yes' ELSE 'No' END AS has_electrical,
    CASE WHEN has_plumbing_skill THEN 'Yes' ELSE 'No' END AS has_plumbing,
    SUM(daily_hvac_jobs) AS hvac_jobs,
    SUM(daily_electrical_jobs) AS electrical_jobs,
    SUM(daily_plumbing_jobs) AS plumbing_jobs,
    SUM(daily_general_jobs) AS general_jobs,
    COUNT(CASE WHEN hvac_skill_utilized THEN 1 END) AS days_hvac_used,
    COUNT(CASE WHEN electrical_skill_utilized THEN 1 END) AS days_electrical_used,
    COUNT(CASE WHEN plumbing_skill_utilized THEN 1 END) AS days_plumbing_used,
    ROUND(AVG(daily_utilization_pct), 1) AS avg_utilization
FROM ANALYTICS.VW_TECHNICIAN_WORKLOAD
WHERE work_date BETWEEN $start_date AND $end_date
  AND was_scheduled = TRUE
GROUP BY
    technician_name,
    skill_count,
    has_hvac_skill,
    has_electrical_skill,
    has_plumbing_skill
ORDER BY skill_count DESC, avg_utilization DESC;

/*------------------------------------------------------------------------------
 * SECTION 8: Performance Quality Metrics
 *----------------------------------------------------------------------------*/

SELECT
    '--- Technician Performance Quality ---' AS quality_section,
    technician_name,
    COUNT(DISTINCT work_date) AS days_worked,
    SUM(daily_total_jobs) AS total_jobs,
    SUM(daily_completed_jobs) AS completed_jobs,
    ROUND(AVG(completion_rate_pct), 1) AS avg_completion_rate,
    ROUND(AVG(on_time_rate_pct), 1) AS avg_on_time_rate,
    SUM(daily_emergency_jobs) AS emergency_jobs_handled,
    ROUND(AVG(stops_per_hour), 2) AS avg_stops_per_hour,
    ROUND(AVG(daily_utilization_pct), 1) AS avg_utilization,

    -- Performance rating
    CASE
        WHEN AVG(completion_rate_pct) >= 95 AND AVG(on_time_rate_pct) >= 90 THEN 'Excellent'
        WHEN AVG(completion_rate_pct) >= 85 AND AVG(on_time_rate_pct) >= 80 THEN 'Good'
        WHEN AVG(completion_rate_pct) >= 75 THEN 'Fair'
        ELSE 'Needs Improvement'
    END AS performance_rating

FROM ANALYTICS.VW_TECHNICIAN_WORKLOAD
WHERE work_date BETWEEN $start_date AND $end_date
  AND was_scheduled = TRUE
GROUP BY technician_name
ORDER BY avg_completion_rate DESC, avg_on_time_rate DESC;

/*------------------------------------------------------------------------------
 * SECTION 9: Daily Capacity Planning
 *----------------------------------------------------------------------------*/

SELECT
    '--- Capacity Available by Day ---' AS capacity_section,
    work_date,
    day_of_week_name,
    COUNT(DISTINCT technician_id) AS technicians_scheduled,
    SUM(daily_stops) AS total_stops,
    ROUND(SUM(daily_hours_worked), 1) AS total_hours_used,
    ROUND(SUM(remaining_hours_capacity), 1) AS total_hours_available,
    ROUND(SUM(remaining_distance_capacity), 1) AS total_miles_available,
    ROUND(AVG(daily_utilization_pct), 1) AS avg_utilization,

    -- Capacity status
    CASE
        WHEN AVG(daily_utilization_pct) >= 90 THEN 'At Capacity'
        WHEN AVG(daily_utilization_pct) >= 75 THEN 'High Utilization'
        WHEN AVG(daily_utilization_pct) >= 50 THEN 'Moderate Utilization'
        ELSE 'Low Utilization'
    END AS capacity_status

FROM ANALYTICS.VW_TECHNICIAN_WORKLOAD
WHERE work_date BETWEEN $start_date AND $end_date
  AND was_scheduled = TRUE
GROUP BY work_date, day_of_week_name
ORDER BY work_date DESC;

/*------------------------------------------------------------------------------
 * SECTION 10: Revenue and Cost Analysis by Technician
 *----------------------------------------------------------------------------*/

SELECT
    '--- Revenue & Cost Analysis ---' AS revenue_section,
    technician_name,
    hourly_rate,
    hourly_rate_bucket,
    COUNT(DISTINCT work_date) AS days_worked,
    ROUND(SUM(daily_hours_worked), 1) AS total_hours,
    ROUND(SUM(daily_distance_miles), 1) AS total_miles,
    CONCAT('$', ROUND(SUM(daily_labor_revenue), 2)) AS total_labor_revenue,
    CONCAT('$', ROUND(SUM(daily_vehicle_cost), 2)) AS total_vehicle_cost,
    CONCAT('$', ROUND(SUM(daily_net_revenue), 2)) AS total_net_revenue,
    CONCAT('$', ROUND(AVG(daily_labor_revenue), 2)) AS avg_daily_revenue,
    ROUND(SUM(daily_net_revenue) / NULLIF(SUM(daily_total_jobs), 0), 2) AS revenue_per_job,
    ROUND(AVG(daily_utilization_pct), 1) AS avg_utilization
FROM ANALYTICS.VW_TECHNICIAN_WORKLOAD
WHERE work_date BETWEEN $start_date AND $end_date
  AND was_scheduled = TRUE
GROUP BY
    technician_name,
    hourly_rate,
    hourly_rate_bucket
ORDER BY SUM(daily_net_revenue) DESC;

/*------------------------------------------------------------------------------
 * SECTION 11: Workload Balance Recommendations
 *----------------------------------------------------------------------------*/

WITH technician_metrics AS (
    SELECT
        technician_name,
        ROUND(AVG(daily_utilization_pct), 1) AS avg_utilization,
        ROUND(AVG(remaining_hours_capacity), 1) AS avg_available_hours,
        skill_count,
        zone_preference,
        COUNT(DISTINCT work_date) AS days_worked,

        CASE
            WHEN AVG(daily_utilization_pct) >= 90 THEN 'Reduce Load'
            WHEN AVG(daily_utilization_pct) < 50 THEN 'Increase Load'
            ELSE 'Maintain'
        END AS recommendation

    FROM ANALYTICS.VW_TECHNICIAN_WORKLOAD
    WHERE work_date BETWEEN $start_date AND $end_date
      AND was_scheduled = TRUE
    GROUP BY
        technician_name,
        skill_count,
        zone_preference
)

SELECT
    '--- Workload Balance Recommendations ---' AS recommendations_section,
    technician_name,
    avg_utilization AS current_utilization_pct,
    avg_available_hours AS avg_hours_available,
    days_worked,
    skill_count,
    zone_preference,
    recommendation AS recommended_action,

    -- Suggested adjustment
    CASE recommendation
        WHEN 'Reduce Load' THEN CONCAT('Reduce by ~', ROUND((avg_utilization - 80) * avg_available_hours / 20, 1), ' hours/day')
        WHEN 'Increase Load' THEN CONCAT('Can add ~', ROUND(avg_available_hours, 1), ' hours/day')
        ELSE 'No change needed'
    END AS suggested_adjustment

FROM technician_metrics
WHERE recommendation != 'Maintain'
ORDER BY
    CASE recommendation
        WHEN 'Reduce Load' THEN 1
        WHEN 'Increase Load' THEN 2
    END,
    avg_utilization DESC;

/*------------------------------------------------------------------------------
 * SECTION 12: Day of Week Utilization Pattern
 *----------------------------------------------------------------------------*/

SELECT
    '--- Utilization by Day of Week ---' AS day_pattern_section,
    day_of_week_name,
    COUNT(DISTINCT technician_id || work_date) AS technician_days,
    ROUND(AVG(daily_utilization_pct), 1) AS avg_utilization,
    ROUND(AVG(daily_stops), 1) AS avg_stops,
    ROUND(AVG(daily_hours_worked), 1) AS avg_hours,
    ROUND(AVG(daily_distance_miles), 1) AS avg_miles,
    SUM(daily_total_jobs) AS total_jobs
FROM ANALYTICS.VW_TECHNICIAN_WORKLOAD
WHERE work_date BETWEEN $start_date AND $end_date
  AND was_scheduled = TRUE
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

/*==============================================================================
 * END OF QUERY
 *============================================================================*/
