/*==============================================================================
 * ANALYTICS VIEW: Optimization Algorithm Comparison
 *
 * Purpose: Compare performance of different route optimization algorithms
 * Author: Route Optimization Team
 * Created: 2026-02-12
 *
 * Features:
 *   - Algorithm performance benchmarking
 *   - Cost and efficiency comparisons
 *   - Improvement metrics vs baseline
 *   - Computation time analysis
 *   - Statistical aggregations
 *
 * Grain: One row per algorithm (or algorithm + time period combination)
 *============================================================================*/

USE ROLE ADMIN_ROLE;
USE DATABASE FIELD_SERVICE_OPS;
USE SCHEMA ANALYTICS;
USE WAREHOUSE ANALYTICS_WH;

CREATE OR REPLACE VIEW ANALYTICS.VW_OPTIMIZATION_COMPARISON
COMMENT = 'Optimization algorithm performance comparison and benchmarking'
AS
WITH algorithm_metrics AS (
    /*--------------------------------------------------------------------------
     * Calculate detailed metrics per algorithm
     *------------------------------------------------------------------------*/
    SELECT
        fr.algorithm_used,
        dd.year_number,
        dd.month_name,
        dd.month_number,
        dd.quarter_name,

        -- Route counts
        COUNT(DISTINCT fr.route_id) AS total_routes,
        COUNT(DISTINCT fr.technician_key) AS unique_technicians,
        COUNT(DISTINCT fr.optimization_run_id) AS optimization_runs,

        -- Completion metrics
        SUM(CASE WHEN fr.is_completed THEN 1 ELSE 0 END) AS completed_routes,
        SUM(CASE WHEN fr.is_cancelled THEN 1 ELSE 0 END) AS cancelled_routes,
        ROUND(SUM(CASE WHEN fr.is_completed THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS completion_rate_pct,

        -- Stop metrics
        SUM(fr.num_stops) AS total_stops,
        ROUND(AVG(fr.num_stops), 2) AS avg_stops_per_route,
        MIN(fr.num_stops) AS min_stops_per_route,
        MAX(fr.num_stops) AS max_stops_per_route,
        STDDEV(fr.num_stops) AS stddev_stops,

        -- Distance metrics
        SUM(fr.total_distance_miles) AS total_distance_miles,
        ROUND(AVG(fr.total_distance_miles), 2) AS avg_distance_per_route,
        MIN(fr.total_distance_miles) AS min_distance_per_route,
        MAX(fr.total_distance_miles) AS max_distance_per_route,
        ROUND(STDDEV(fr.total_distance_miles), 2) AS stddev_distance,
        ROUND(AVG(fr.avg_distance_per_stop), 2) AS avg_distance_per_stop,

        -- Time metrics
        SUM(fr.total_duration_hours) AS total_duration_hours,
        ROUND(AVG(fr.total_duration_hours), 2) AS avg_duration_per_route,
        MIN(fr.total_duration_hours) AS min_duration_per_route,
        MAX(fr.total_duration_hours) AS max_duration_per_route,
        ROUND(STDDEV(fr.total_duration_hours), 2) AS stddev_duration,
        ROUND(AVG(fr.avg_duration_per_stop), 2) AS avg_duration_per_stop,

        -- Utilization metrics
        ROUND(AVG(fr.utilization_percentage), 2) AS avg_utilization_pct,
        MIN(fr.utilization_percentage) AS min_utilization_pct,
        MAX(fr.utilization_percentage) AS max_utilization_pct,
        ROUND(STDDEV(fr.utilization_percentage), 2) AS stddev_utilization,

        -- Constraint compliance
        SUM(CASE WHEN fr.is_within_distance_constraint THEN 1 ELSE 0 END) AS routes_within_distance,
        SUM(CASE WHEN fr.is_within_time_constraint THEN 1 ELSE 0 END) AS routes_within_time,
        ROUND(SUM(CASE WHEN fr.is_within_distance_constraint AND fr.is_within_time_constraint THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS constraint_compliance_pct,

        -- Optimization quality
        ROUND(AVG(fr.optimization_score), 4) AS avg_optimization_score,
        MIN(fr.optimization_score) AS min_optimization_score,
        MAX(fr.optimization_score) AS max_optimization_score,
        ROUND(STDDEV(fr.optimization_score), 4) AS stddev_optimization_score,

        -- Computation time
        ROUND(AVG(fr.computation_time_seconds), 2) AS avg_computation_time_sec,
        MIN(fr.computation_time_seconds) AS min_computation_time_sec,
        MAX(fr.computation_time_seconds) AS max_computation_time_sec,
        ROUND(SUM(fr.computation_time_seconds), 2) AS total_computation_time_sec,

        -- Cost metrics (using hourly rate from technician dimension)
        ROUND(SUM(fr.total_duration_hours * dt.hourly_rate), 2) AS total_labor_cost,
        ROUND(AVG(fr.total_duration_hours * dt.hourly_rate), 2) AS avg_labor_cost_per_route,
        ROUND(SUM(fr.total_distance_miles * 0.58), 2) AS total_vehicle_cost,
        ROUND(AVG(fr.total_distance_miles * 0.58), 2) AS avg_vehicle_cost_per_route,
        ROUND(SUM((fr.total_duration_hours * dt.hourly_rate) + (fr.total_distance_miles * 0.58)), 2) AS total_route_cost,
        ROUND(AVG((fr.total_duration_hours * dt.hourly_rate) + (fr.total_distance_miles * 0.58)), 2) AS avg_total_cost_per_route,

        -- Work order metrics
        COUNT(DISTINCT frs.work_order_key) AS total_work_orders,
        SUM(CASE WHEN frs.is_completed THEN 1 ELSE 0 END) AS completed_work_orders,
        ROUND(SUM(CASE WHEN frs.is_completed THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(DISTINCT frs.work_order_key), 0), 2) AS work_order_completion_pct

    FROM ANALYTICS.FACT_ROUTE fr
    INNER JOIN ANALYTICS.DIM_DATE dd
        ON fr.route_date_key = dd.date_key
    LEFT JOIN ANALYTICS.DIM_TECHNICIAN dt
        ON fr.technician_key = dt.technician_key
    LEFT JOIN ANALYTICS.FACT_ROUTE_STOP frs
        ON fr.route_key = frs.route_key

    WHERE fr.algorithm_used IS NOT NULL

    GROUP BY
        fr.algorithm_used,
        dd.year_number,
        dd.month_name,
        dd.month_number,
        dd.quarter_name
),

baseline_metrics AS (
    /*--------------------------------------------------------------------------
     * Identify baseline algorithm for comparison
     * Using "nearest_neighbor" as baseline (simplest algorithm)
     *------------------------------------------------------------------------*/
    SELECT
        year_number,
        month_number,
        avg_distance_per_route AS baseline_avg_distance,
        avg_duration_per_route AS baseline_avg_duration,
        avg_stops_per_route AS baseline_avg_stops,
        avg_total_cost_per_route AS baseline_avg_cost,
        avg_utilization_pct AS baseline_utilization,
        avg_computation_time_sec AS baseline_computation_time
    FROM algorithm_metrics
    WHERE algorithm_used = 'nearest_neighbor'
)

SELECT
    /*--------------------------------------------------------------------------
     * Algorithm Identification
     *------------------------------------------------------------------------*/
    am.algorithm_used,

    -- Categorization
    CASE
        WHEN am.algorithm_used LIKE '%genetic%' THEN 'Metaheuristic'
        WHEN am.algorithm_used LIKE '%simulated%annealing%' THEN 'Metaheuristic'
        WHEN am.algorithm_used LIKE '%tabu%' THEN 'Metaheuristic'
        WHEN am.algorithm_used LIKE '%nearest%neighbor%' THEN 'Greedy'
        WHEN am.algorithm_used LIKE '%2-opt%' OR am.algorithm_used LIKE '%3-opt%' THEN 'Local Search'
        WHEN am.algorithm_used LIKE '%or-tools%' OR am.algorithm_used LIKE '%vrp%' THEN 'Exact/MIP'
        ELSE 'Other'
    END AS algorithm_category,

    /*--------------------------------------------------------------------------
     * Time Period
     *------------------------------------------------------------------------*/
    am.year_number,
    am.quarter_name,
    am.month_name,

    /*--------------------------------------------------------------------------
     * Volume Metrics
     *------------------------------------------------------------------------*/
    am.total_routes,
    am.unique_technicians,
    am.optimization_runs,
    am.completed_routes,
    am.cancelled_routes,
    am.completion_rate_pct,

    /*--------------------------------------------------------------------------
     * Stop Metrics
     *------------------------------------------------------------------------*/
    am.total_stops,
    am.avg_stops_per_route,
    am.min_stops_per_route,
    am.max_stops_per_route,
    am.stddev_stops,

    /*--------------------------------------------------------------------------
     * Distance Metrics
     *------------------------------------------------------------------------*/
    am.total_distance_miles,
    am.avg_distance_per_route,
    am.min_distance_per_route,
    am.max_distance_per_route,
    am.stddev_distance,
    am.avg_distance_per_stop,

    /*--------------------------------------------------------------------------
     * Time Metrics
     *------------------------------------------------------------------------*/
    am.total_duration_hours,
    am.avg_duration_per_route,
    am.min_duration_per_route,
    am.max_duration_per_route,
    am.stddev_duration,
    am.avg_duration_per_stop,

    /*--------------------------------------------------------------------------
     * Utilization Metrics
     *------------------------------------------------------------------------*/
    am.avg_utilization_pct,
    am.min_utilization_pct,
    am.max_utilization_pct,
    am.stddev_utilization,

    -- Utilization rating
    CASE
        WHEN am.avg_utilization_pct >= 85 THEN 'Excellent'
        WHEN am.avg_utilization_pct >= 70 THEN 'Good'
        WHEN am.avg_utilization_pct >= 55 THEN 'Fair'
        ELSE 'Poor'
    END AS utilization_rating,

    /*--------------------------------------------------------------------------
     * Constraint Compliance
     *------------------------------------------------------------------------*/
    am.routes_within_distance,
    am.routes_within_time,
    am.constraint_compliance_pct,

    /*--------------------------------------------------------------------------
     * Optimization Quality
     *------------------------------------------------------------------------*/
    am.avg_optimization_score,
    am.min_optimization_score,
    am.max_optimization_score,
    am.stddev_optimization_score,

    CASE
        WHEN am.avg_optimization_score >= 0.9 THEN 'Excellent'
        WHEN am.avg_optimization_score >= 0.75 THEN 'Good'
        WHEN am.avg_optimization_score >= 0.6 THEN 'Fair'
        ELSE 'Poor'
    END AS optimization_quality_rating,

    /*--------------------------------------------------------------------------
     * Computation Performance
     *------------------------------------------------------------------------*/
    am.avg_computation_time_sec,
    am.min_computation_time_sec,
    am.max_computation_time_sec,
    am.total_computation_time_sec,

    CASE
        WHEN am.avg_computation_time_sec < 1 THEN 'Very Fast (<1s)'
        WHEN am.avg_computation_time_sec < 5 THEN 'Fast (1-5s)'
        WHEN am.avg_computation_time_sec < 30 THEN 'Moderate (5-30s)'
        WHEN am.avg_computation_time_sec < 120 THEN 'Slow (30-120s)'
        ELSE 'Very Slow (>120s)'
    END AS computation_speed_rating,

    /*--------------------------------------------------------------------------
     * Cost Metrics
     *------------------------------------------------------------------------*/
    am.total_labor_cost,
    am.avg_labor_cost_per_route,
    am.total_vehicle_cost,
    am.avg_vehicle_cost_per_route,
    am.total_route_cost,
    am.avg_total_cost_per_route,

    -- Cost per stop
    ROUND(am.avg_total_cost_per_route / NULLIF(am.avg_stops_per_route, 0), 2) AS avg_cost_per_stop,

    -- Cost per mile
    ROUND(am.total_route_cost / NULLIF(am.total_distance_miles, 0), 2) AS cost_per_mile,

    /*--------------------------------------------------------------------------
     * Work Order Metrics
     *------------------------------------------------------------------------*/
    am.total_work_orders,
    am.completed_work_orders,
    am.work_order_completion_pct,

    /*--------------------------------------------------------------------------
     * Comparison vs Baseline (Nearest Neighbor)
     *------------------------------------------------------------------------*/
    ROUND(((bm.baseline_avg_distance - am.avg_distance_per_route) / NULLIF(bm.baseline_avg_distance, 0)) * 100, 2) AS distance_improvement_vs_baseline_pct,
    ROUND(((bm.baseline_avg_duration - am.avg_duration_per_route) / NULLIF(bm.baseline_avg_duration, 0)) * 100, 2) AS time_improvement_vs_baseline_pct,
    ROUND(((bm.baseline_avg_cost - am.avg_total_cost_per_route) / NULLIF(bm.baseline_avg_cost, 0)) * 100, 2) AS cost_improvement_vs_baseline_pct,
    ROUND(am.avg_utilization_pct - bm.baseline_utilization, 2) AS utilization_diff_vs_baseline,
    ROUND(((am.avg_computation_time_sec - bm.baseline_computation_time) / NULLIF(bm.baseline_computation_time, 0)) * 100, 2) AS computation_time_increase_vs_baseline_pct,

    /*--------------------------------------------------------------------------
     * Overall Performance Score (Weighted)
     *------------------------------------------------------------------------*/
    ROUND(
        (am.avg_optimization_score * 0.3) +  -- 30% weight on optimization score
        ((100 - ABS(am.avg_utilization_pct - 80)) / 100 * 0.3) +  -- 30% weight on utilization (target 80%)
        (am.constraint_compliance_pct / 100 * 0.2) +  -- 20% weight on constraint compliance
        (am.work_order_completion_pct / 100 * 0.2),  -- 20% weight on completion rate
        4
    ) AS overall_performance_score,

    /*--------------------------------------------------------------------------
     * Efficiency Ratio
     *------------------------------------------------------------------------*/
    ROUND(am.total_stops / NULLIF(am.total_distance_miles, 0), 4) AS stops_per_mile,
    ROUND(am.total_stops / NULLIF(am.total_duration_hours, 0), 2) AS stops_per_hour,

    /*--------------------------------------------------------------------------
     * Recommendation Flag
     *------------------------------------------------------------------------*/
    CASE
        WHEN am.avg_optimization_score >= 0.85
         AND am.constraint_compliance_pct >= 95
         AND am.avg_utilization_pct >= 70
         AND am.avg_computation_time_sec < 60
        THEN 'Recommended'
        WHEN am.avg_optimization_score >= 0.75
         AND am.constraint_compliance_pct >= 90
        THEN 'Acceptable'
        ELSE 'Needs Improvement'
    END AS recommendation_status

FROM algorithm_metrics am
LEFT JOIN baseline_metrics bm
    ON am.year_number = bm.year_number
    AND am.month_number = bm.month_number

ORDER BY
    am.year_number DESC,
    am.month_number DESC,
    am.avg_optimization_score DESC
;

/*------------------------------------------------------------------------------
 * GRANT ACCESS
 *----------------------------------------------------------------------------*/

GRANT SELECT ON ANALYTICS.VW_OPTIMIZATION_COMPARISON TO ROLE ANALYST_ROLE;

/*------------------------------------------------------------------------------
 * SAMPLE QUERIES
 *----------------------------------------------------------------------------*/

/*
-- Overall algorithm performance comparison
SELECT
    algorithm_used,
    algorithm_category,
    total_routes,
    avg_stops_per_route,
    avg_distance_per_route,
    avg_utilization_pct,
    avg_optimization_score,
    avg_computation_time_sec,
    avg_total_cost_per_route,
    distance_improvement_vs_baseline_pct,
    cost_improvement_vs_baseline_pct,
    overall_performance_score,
    recommendation_status
FROM ANALYTICS.VW_OPTIMIZATION_COMPARISON
WHERE year_number = YEAR(CURRENT_DATE)
  AND total_routes >= 10  -- Only algorithms with sufficient sample size
ORDER BY overall_performance_score DESC;

-- Best algorithm by cost efficiency
SELECT
    algorithm_used,
    total_routes,
    avg_total_cost_per_route,
    avg_cost_per_stop,
    cost_improvement_vs_baseline_pct,
    avg_utilization_pct,
    constraint_compliance_pct
FROM ANALYTICS.VW_OPTIMIZATION_COMPARISON
WHERE year_number = YEAR(CURRENT_DATE)
ORDER BY avg_total_cost_per_route ASC
LIMIT 5;

-- Algorithm performance trend over time
SELECT
    algorithm_used,
    year_number,
    month_name,
    avg_distance_per_route,
    avg_utilization_pct,
    avg_optimization_score,
    distance_improvement_vs_baseline_pct
FROM ANALYTICS.VW_OPTIMIZATION_COMPARISON
WHERE algorithm_used IN ('genetic_algorithm', 'or-tools', 'nearest_neighbor')
ORDER BY year_number DESC, month_number DESC, algorithm_used;
*/

/*==============================================================================
 * END OF SCRIPT
 *============================================================================*/
