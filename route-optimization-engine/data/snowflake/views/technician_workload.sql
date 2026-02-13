/*==============================================================================
 * ANALYTICS VIEW: Technician Workload Analysis
 *
 * Purpose: Technician workload balance and capacity utilization analysis
 * Author: Route Optimization Team
 * Created: 2026-02-12
 *
 * Features:
 *   - Daily and weekly workload metrics
 *   - Capacity utilization tracking
 *   - Work-life balance indicators
 *   - Performance benchmarking
 *   - Skill utilization analysis
 *
 * Grain: One row per technician per day
 *============================================================================*/

USE ROLE ADMIN_ROLE;
USE DATABASE FIELD_SERVICE_OPS;
USE SCHEMA ANALYTICS;
USE WAREHOUSE ANALYTICS_WH;

CREATE OR REPLACE VIEW ANALYTICS.VW_TECHNICIAN_WORKLOAD
COMMENT = 'Technician workload and capacity utilization analysis'
AS
WITH daily_metrics AS (
    /*--------------------------------------------------------------------------
     * Calculate daily metrics per technician
     *------------------------------------------------------------------------*/
    SELECT
        fr.technician_key,
        fr.route_date_key,
        COUNT(DISTINCT fr.route_id) AS routes_count,
        SUM(fr.num_stops) AS total_stops,
        SUM(fr.total_distance_miles) AS total_distance_miles,
        SUM(fr.total_duration_hours) AS total_hours_worked,
        SUM(fr.total_duration_minutes) AS total_minutes_worked,
        AVG(fr.utilization_percentage) AS avg_utilization_pct,
        SUM(CASE WHEN fr.is_completed THEN 1 ELSE 0 END) AS completed_routes,
        SUM(CASE WHEN fr.is_cancelled THEN 1 ELSE 0 END) AS cancelled_routes
    FROM ANALYTICS.FACT_ROUTE fr
    GROUP BY fr.technician_key, fr.route_date_key
),

weekly_metrics AS (
    /*--------------------------------------------------------------------------
     * Calculate weekly rollup metrics
     *------------------------------------------------------------------------*/
    SELECT
        dm.technician_key,
        dd.week_start_date,
        dd.week_of_year,
        dd.year_number,
        COUNT(DISTINCT dm.route_date_key) AS days_worked,
        SUM(dm.routes_count) AS weekly_routes,
        SUM(dm.total_stops) AS weekly_stops,
        SUM(dm.total_distance_miles) AS weekly_distance,
        SUM(dm.total_hours_worked) AS weekly_hours,
        AVG(dm.avg_utilization_pct) AS weekly_avg_utilization,
        SUM(dm.completed_routes) AS weekly_completed_routes,
        SUM(dm.cancelled_routes) AS weekly_cancelled_routes
    FROM daily_metrics dm
    INNER JOIN ANALYTICS.DIM_DATE dd
        ON dm.route_date_key = dd.date_key
    GROUP BY
        dm.technician_key,
        dd.week_start_date,
        dd.week_of_year,
        dd.year_number
),

work_order_details AS (
    /*--------------------------------------------------------------------------
     * Work order category breakdown per technician per day
     *------------------------------------------------------------------------*/
    SELECT
        dt.technician_key,
        dd.date_key,
        SUM(CASE WHEN fwo.category = 'HVAC' THEN 1 ELSE 0 END) AS hvac_jobs,
        SUM(CASE WHEN fwo.category = 'plumbing' THEN 1 ELSE 0 END) AS plumbing_jobs,
        SUM(CASE WHEN fwo.category = 'electrical' THEN 1 ELSE 0 END) AS electrical_jobs,
        SUM(CASE WHEN fwo.category = 'general' THEN 1 ELSE 0 END) AS general_jobs,
        SUM(CASE WHEN fwo.category = 'inspection' THEN 1 ELSE 0 END) AS inspection_jobs,
        SUM(CASE WHEN fwo.is_emergency THEN 1 ELSE 0 END) AS emergency_jobs,
        SUM(CASE WHEN fwo.is_completed THEN 1 ELSE 0 END) AS completed_jobs,
        SUM(CASE WHEN fwo.is_on_time THEN 1 ELSE 0 END) AS on_time_jobs,
        COUNT(*) AS total_jobs
    FROM ANALYTICS.FACT_WORK_ORDER fwo
    INNER JOIN ANALYTICS.DIM_TECHNICIAN dt
        ON fwo.technician_key = dt.technician_key
    LEFT JOIN ANALYTICS.DIM_DATE dd
        ON fwo.scheduled_date_key = dd.date_key
    WHERE fwo.status != 'cancelled'
    GROUP BY dt.technician_key, dd.date_key
)

SELECT
    /*--------------------------------------------------------------------------
     * Technician Identification
     *------------------------------------------------------------------------*/
    dt.technician_id,
    dt.name AS technician_name,
    dt.email AS technician_email,

    /*--------------------------------------------------------------------------
     * Date Information
     *------------------------------------------------------------------------*/
    dd.date_value AS work_date,
    dd.day_of_week_name,
    dd.is_weekday,
    dd.is_weekend,
    dd.week_of_year,
    dd.week_start_date,
    dd.month_name,
    dd.quarter_name,
    dd.year_number,

    /*--------------------------------------------------------------------------
     * Technician Profile
     *------------------------------------------------------------------------*/
    dt.skill_count,
    dt.has_hvac_skill,
    dt.has_electrical_skill,
    dt.has_plumbing_skill,
    dt.capacity_level,
    dt.max_daily_hours,
    dt.max_daily_distance_miles,
    dt.hourly_rate,
    dt.hourly_rate_bucket,
    dt.zone_preference,
    dt.availability_status,

    /*--------------------------------------------------------------------------
     * Daily Workload Metrics
     *------------------------------------------------------------------------*/
    COALESCE(dm.routes_count, 0) AS daily_routes,
    COALESCE(dm.total_stops, 0) AS daily_stops,
    COALESCE(dm.total_distance_miles, 0) AS daily_distance_miles,
    COALESCE(dm.total_hours_worked, 0) AS daily_hours_worked,
    COALESCE(dm.total_minutes_worked, 0) AS daily_minutes_worked,

    /*--------------------------------------------------------------------------
     * Daily Utilization
     *------------------------------------------------------------------------*/
    COALESCE(dm.avg_utilization_pct, 0) AS daily_utilization_pct,
    ROUND(COALESCE(dm.total_distance_miles, 0) * 100.0 / NULLIF(dt.max_daily_distance_miles, 0), 2) AS distance_utilization_pct,
    ROUND(COALESCE(dm.total_hours_worked, 0) * 100.0 / NULLIF(dt.max_daily_hours, 0), 2) AS time_utilization_pct,

    -- Remaining capacity
    dt.max_daily_hours - COALESCE(dm.total_hours_worked, 0) AS remaining_hours_capacity,
    dt.max_daily_distance_miles - COALESCE(dm.total_distance_miles, 0) AS remaining_distance_capacity,

    -- Utilization rating
    CASE
        WHEN COALESCE(dm.avg_utilization_pct, 0) >= 90 THEN 'Overutilized'
        WHEN COALESCE(dm.avg_utilization_pct, 0) >= 75 THEN 'Well-Utilized'
        WHEN COALESCE(dm.avg_utilization_pct, 0) >= 50 THEN 'Underutilized'
        ELSE 'Significantly Underutilized'
    END AS utilization_status,

    /*--------------------------------------------------------------------------
     * Weekly Workload Metrics
     *------------------------------------------------------------------------*/
    COALESCE(wm.days_worked, 0) AS weekly_days_worked,
    COALESCE(wm.weekly_routes, 0) AS weekly_routes,
    COALESCE(wm.weekly_stops, 0) AS weekly_stops,
    COALESCE(wm.weekly_distance, 0) AS weekly_distance_miles,
    COALESCE(wm.weekly_hours, 0) AS weekly_hours_worked,
    COALESCE(wm.weekly_avg_utilization, 0) AS weekly_avg_utilization_pct,

    -- Weekly capacity calculations
    ROUND(COALESCE(wm.weekly_hours, 0) * 100.0 / NULLIF(dt.max_daily_hours * 5, 0), 2) AS weekly_capacity_pct,
    dt.max_daily_hours * 5 - COALESCE(wm.weekly_hours, 0) AS weekly_remaining_hours,

    /*--------------------------------------------------------------------------
     * Work Order Details
     *------------------------------------------------------------------------*/
    COALESCE(wod.total_jobs, 0) AS daily_total_jobs,
    COALESCE(wod.completed_jobs, 0) AS daily_completed_jobs,
    COALESCE(wod.hvac_jobs, 0) AS daily_hvac_jobs,
    COALESCE(wod.plumbing_jobs, 0) AS daily_plumbing_jobs,
    COALESCE(wod.electrical_jobs, 0) AS daily_electrical_jobs,
    COALESCE(wod.general_jobs, 0) AS daily_general_jobs,
    COALESCE(wod.inspection_jobs, 0) AS daily_inspection_jobs,
    COALESCE(wod.emergency_jobs, 0) AS daily_emergency_jobs,

    /*--------------------------------------------------------------------------
     * Performance Metrics
     *------------------------------------------------------------------------*/
    ROUND(COALESCE(wod.completed_jobs, 0) * 100.0 / NULLIF(wod.total_jobs, 0), 2) AS completion_rate_pct,
    ROUND(COALESCE(wod.on_time_jobs, 0) * 100.0 / NULLIF(wod.total_jobs, 0), 2) AS on_time_rate_pct,
    COALESCE(dm.completed_routes, 0) AS daily_completed_routes,
    COALESCE(dm.cancelled_routes, 0) AS daily_cancelled_routes,

    /*--------------------------------------------------------------------------
     * Efficiency Metrics
     *------------------------------------------------------------------------*/
    ROUND(COALESCE(dm.total_stops, 0) / NULLIF(dm.total_hours_worked, 0), 2) AS stops_per_hour,
    ROUND(COALESCE(dm.total_distance_miles, 0) / NULLIF(dm.total_stops, 0), 2) AS avg_distance_per_stop,
    ROUND(COALESCE(dm.total_hours_worked, 0) * 60 / NULLIF(dm.total_stops, 0), 2) AS avg_minutes_per_stop,

    /*--------------------------------------------------------------------------
     * Revenue Metrics
     *------------------------------------------------------------------------*/
    ROUND(COALESCE(dm.total_hours_worked, 0) * dt.hourly_rate, 2) AS daily_labor_revenue,
    ROUND(COALESCE(dm.total_distance_miles, 0) * 0.58, 2) AS daily_vehicle_cost,
    ROUND((COALESCE(dm.total_hours_worked, 0) * dt.hourly_rate) - (COALESCE(dm.total_distance_miles, 0) * 0.58), 2) AS daily_net_revenue,

    -- Weekly revenue
    ROUND(COALESCE(wm.weekly_hours, 0) * dt.hourly_rate, 2) AS weekly_labor_revenue,
    ROUND(COALESCE(wm.weekly_distance, 0) * 0.58, 2) AS weekly_vehicle_cost,
    ROUND((COALESCE(wm.weekly_hours, 0) * dt.hourly_rate) - (COALESCE(wm.weekly_distance, 0) * 0.58), 2) AS weekly_net_revenue,

    /*--------------------------------------------------------------------------
     * Workload Balance Indicators
     *------------------------------------------------------------------------*/
    CASE
        WHEN COALESCE(dm.total_hours_worked, 0) > dt.max_daily_hours * 1.1 THEN 'Overloaded'
        WHEN COALESCE(dm.total_hours_worked, 0) > dt.max_daily_hours THEN 'At Maximum'
        WHEN COALESCE(dm.total_hours_worked, 0) >= dt.max_daily_hours * 0.75 THEN 'Balanced'
        WHEN COALESCE(dm.total_hours_worked, 0) >= dt.max_daily_hours * 0.5 THEN 'Light'
        ELSE 'Very Light'
    END AS workload_balance,

    CASE
        WHEN COALESCE(dm.total_hours_worked, 0) > dt.max_daily_hours THEN TRUE
        ELSE FALSE
    END AS is_overtime,

    CASE
        WHEN COALESCE(wm.weekly_hours, 0) > 40 THEN TRUE
        ELSE FALSE
    END AS is_weekly_overtime,

    /*--------------------------------------------------------------------------
     * Skill Utilization
     *------------------------------------------------------------------------*/
    CASE
        WHEN dt.has_hvac_skill AND COALESCE(wod.hvac_jobs, 0) > 0 THEN TRUE
        ELSE FALSE
    END AS hvac_skill_utilized,

    CASE
        WHEN dt.has_electrical_skill AND COALESCE(wod.electrical_jobs, 0) > 0 THEN TRUE
        ELSE FALSE
    END AS electrical_skill_utilized,

    CASE
        WHEN dt.has_plumbing_skill AND COALESCE(wod.plumbing_jobs, 0) > 0 THEN TRUE
        ELSE FALSE
    END AS plumbing_skill_utilized,

    /*--------------------------------------------------------------------------
     * Flags and Status
     *------------------------------------------------------------------------*/
    CASE WHEN dm.route_date_key IS NOT NULL THEN TRUE ELSE FALSE END AS was_scheduled,
    CASE WHEN COALESCE(dm.total_stops, 0) > 0 THEN TRUE ELSE FALSE END AS has_activity

FROM ANALYTICS.DIM_TECHNICIAN dt
CROSS JOIN ANALYTICS.DIM_DATE dd
LEFT JOIN daily_metrics dm
    ON dt.technician_key = dm.technician_key
    AND dd.date_key = dm.route_date_key
LEFT JOIN weekly_metrics wm
    ON dt.technician_key = wm.technician_key
    AND dd.week_start_date = wm.week_start_date
LEFT JOIN work_order_details wod
    ON dt.technician_key = wod.technician_key
    AND dd.date_key = wod.date_key

WHERE dt.is_current = TRUE
  AND dd.date_value >= DATEADD(day, -90, CURRENT_DATE)  -- Last 90 days
  AND dd.date_value <= CURRENT_DATE
  AND dd.is_weekday = TRUE  -- Only show weekdays
;

/*------------------------------------------------------------------------------
 * GRANT ACCESS
 *----------------------------------------------------------------------------*/

GRANT SELECT ON ANALYTICS.VW_TECHNICIAN_WORKLOAD TO ROLE ANALYST_ROLE;

/*------------------------------------------------------------------------------
 * SAMPLE QUERIES
 *----------------------------------------------------------------------------*/

/*
-- Technician utilization summary for current week
SELECT
    technician_name,
    weekly_days_worked,
    weekly_stops,
    weekly_hours_worked,
    weekly_avg_utilization_pct,
    weekly_capacity_pct,
    utilization_status,
    weekly_labor_revenue,
    weekly_net_revenue
FROM ANALYTICS.VW_TECHNICIAN_WORKLOAD
WHERE week_start_date = DATE_TRUNC('week', CURRENT_DATE)
  AND was_scheduled = TRUE
GROUP BY
    technician_name,
    weekly_days_worked,
    weekly_stops,
    weekly_hours_worked,
    weekly_avg_utilization_pct,
    weekly_capacity_pct,
    utilization_status,
    weekly_labor_revenue,
    weekly_net_revenue
ORDER BY weekly_avg_utilization_pct DESC;

-- Overutilized technicians needing workload rebalancing
SELECT
    technician_name,
    work_date,
    daily_hours_worked,
    max_daily_hours,
    daily_stops,
    workload_balance,
    is_overtime,
    daily_labor_revenue
FROM ANALYTICS.VW_TECHNICIAN_WORKLOAD
WHERE workload_balance IN ('Overloaded', 'At Maximum')
  AND work_date >= DATEADD(day, -7, CURRENT_DATE)
ORDER BY daily_hours_worked DESC;

-- Skill utilization analysis
SELECT
    technician_name,
    skill_count,
    SUM(daily_hvac_jobs) AS total_hvac_jobs,
    SUM(daily_plumbing_jobs) AS total_plumbing_jobs,
    SUM(daily_electrical_jobs) AS total_electrical_jobs,
    SUM(daily_general_jobs) AS total_general_jobs,
    ROUND(AVG(daily_utilization_pct), 1) AS avg_utilization,
    COUNT(CASE WHEN hvac_skill_utilized THEN 1 END) AS days_hvac_used,
    COUNT(CASE WHEN electrical_skill_utilized THEN 1 END) AS days_electrical_used,
    COUNT(CASE WHEN plumbing_skill_utilized THEN 1 END) AS days_plumbing_used
FROM ANALYTICS.VW_TECHNICIAN_WORKLOAD
WHERE work_date >= DATEADD(day, -30, CURRENT_DATE)
  AND was_scheduled = TRUE
GROUP BY technician_name, skill_count
ORDER BY avg_utilization DESC;
*/

/*==============================================================================
 * END OF SCRIPT
 *============================================================================*/
