/*==============================================================================
 * QUERY: Route Optimization ROI Analysis
 *
 * Purpose: Calculate return on investment for route optimization implementation
 * Author: Route Optimization Team
 * Created: 2026-02-12
 *
 * Use Case: Executive reporting, optimization value demonstration, budget justification
 * Frequency: Run quarterly for business review
 *
 * Methodology:
 *   - Compare optimized routes vs baseline (nearest neighbor/manual routing)
 *   - Calculate savings in distance, time, and costs
 *   - Factor in computation costs and implementation overhead
 *============================================================================*/

USE ROLE ANALYST_ROLE;
USE DATABASE FIELD_SERVICE_OPS;
USE SCHEMA ANALYTICS;
USE WAREHOUSE ANALYTICS_WH;

/*------------------------------------------------------------------------------
 * PARAMETERS: Set analysis period
 *----------------------------------------------------------------------------*/

SET start_date = DATEADD(month, -6, CURRENT_DATE);  -- Last 6 months
SET end_date = CURRENT_DATE;

SELECT
    '=== ROUTE OPTIMIZATION ROI ANALYSIS ===' AS report_header,
    $start_date AS analysis_start_date,
    $end_date AS analysis_end_date,
    DATEDIFF(day, $start_date, $end_date) AS analysis_period_days;

/*------------------------------------------------------------------------------
 * SECTION 1: Executive Summary - Overall ROI
 *----------------------------------------------------------------------------*/

WITH baseline_performance AS (
    -- Baseline: nearest_neighbor or earliest routes (simple algorithm)
    SELECT
        COUNT(DISTINCT route_id) AS total_routes,
        SUM(num_stops) AS total_stops,
        SUM(total_distance_miles) AS total_distance,
        SUM(total_duration_hours) AS total_duration,
        AVG(avg_distance_per_stop) AS avg_distance_per_stop,
        AVG(utilization_percentage) AS avg_utilization,
        SUM(total_route_cost) AS total_cost,
        AVG(completion_rate_pct) AS avg_completion_rate
    FROM ANALYTICS.VW_ROUTE_PERFORMANCE
    WHERE route_date BETWEEN $start_date AND $end_date
      AND algorithm_used = 'nearest_neighbor'
),
optimized_performance AS (
    -- Optimized: advanced algorithms (genetic, or-tools, etc.)
    SELECT
        COUNT(DISTINCT route_id) AS total_routes,
        SUM(num_stops) AS total_stops,
        SUM(total_distance_miles) AS total_distance,
        SUM(total_duration_hours) AS total_duration,
        AVG(avg_distance_per_stop) AS avg_distance_per_stop,
        AVG(utilization_percentage) AS avg_utilization,
        SUM(total_route_cost) AS total_cost,
        AVG(completion_rate_pct) AS avg_completion_rate,
        AVG(optimization_score) AS avg_optimization_score
    FROM ANALYTICS.VW_ROUTE_PERFORMANCE
    WHERE route_date BETWEEN $start_date AND $end_date
      AND algorithm_used IN ('genetic_algorithm', 'or-tools', 'simulated_annealing')
),
computation_costs AS (
    SELECT
        SUM(computation_time_seconds) / 3600.0 AS total_compute_hours,
        -- Assuming $0.50/hour for compute resources (adjust as needed)
        ROUND(SUM(computation_time_seconds) / 3600.0 * 0.50, 2) AS total_compute_cost
    FROM ANALYTICS.VW_ROUTE_PERFORMANCE
    WHERE route_date BETWEEN $start_date AND $end_date
      AND algorithm_used IN ('genetic_algorithm', 'or-tools', 'simulated_annealing')
)

SELECT
    '--- EXECUTIVE SUMMARY ---' AS summary_section,

    -- Baseline metrics
    bp.total_routes AS baseline_routes,
    bp.total_stops AS baseline_stops,
    ROUND(bp.total_distance, 1) AS baseline_total_miles,
    ROUND(bp.total_cost, 2) AS baseline_total_cost,

    -- Optimized metrics
    op.total_routes AS optimized_routes,
    op.total_stops AS optimized_stops,
    ROUND(op.total_distance, 1) AS optimized_total_miles,
    ROUND(op.total_cost, 2) AS optimized_total_cost,

    -- Absolute savings
    ROUND(bp.total_distance - op.total_distance, 1) AS miles_saved,
    ROUND(bp.total_duration - op.total_duration, 1) AS hours_saved,
    ROUND(bp.total_cost - op.total_cost, 2) AS cost_saved,

    -- Percentage improvements
    ROUND((bp.total_distance - op.total_distance) * 100.0 / NULLIF(bp.total_distance, 0), 2) AS distance_reduction_pct,
    ROUND((bp.total_duration - op.total_duration) * 100.0 / NULLIF(bp.total_duration, 0), 2) AS time_reduction_pct,
    ROUND((bp.total_cost - op.total_cost) * 100.0 / NULLIF(bp.total_cost, 0), 2) AS cost_reduction_pct,

    -- Quality improvements
    ROUND(op.avg_utilization - bp.avg_utilization, 2) AS utilization_improvement_pct,
    ROUND(op.avg_completion_rate - bp.avg_completion_rate, 2) AS completion_rate_improvement_pct,
    ROUND(op.avg_optimization_score, 3) AS avg_optimization_quality,

    -- ROI calculation
    ROUND(cc.total_compute_cost, 2) AS computation_investment,
    ROUND((bp.total_cost - op.total_cost) - cc.total_compute_cost, 2) AS net_savings,
    ROUND(((bp.total_cost - op.total_cost) - cc.total_compute_cost) * 100.0 / NULLIF(cc.total_compute_cost, 0), 1) AS roi_percentage,

    -- Payback period (days)
    CASE
        WHEN (bp.total_cost - op.total_cost) > 0
        THEN ROUND(cc.total_compute_cost / ((bp.total_cost - op.total_cost) / DATEDIFF(day, $start_date, $end_date)), 1)
        ELSE NULL
    END AS payback_period_days

FROM baseline_performance bp
CROSS JOIN optimized_performance op
CROSS JOIN computation_costs cc;

/*------------------------------------------------------------------------------
 * SECTION 2: Monthly ROI Trend
 *----------------------------------------------------------------------------*/

WITH monthly_baseline AS (
    SELECT
        DATE_TRUNC('month', route_date) AS month,
        COUNT(DISTINCT route_id) AS routes,
        SUM(total_distance_miles) AS total_distance,
        SUM(total_duration_hours) AS total_duration,
        SUM(total_route_cost) AS total_cost,
        AVG(utilization_percentage) AS avg_utilization
    FROM ANALYTICS.VW_ROUTE_PERFORMANCE
    WHERE route_date BETWEEN $start_date AND $end_date
      AND algorithm_used = 'nearest_neighbor'
    GROUP BY DATE_TRUNC('month', route_date)
),
monthly_optimized AS (
    SELECT
        DATE_TRUNC('month', route_date) AS month,
        COUNT(DISTINCT route_id) AS routes,
        SUM(total_distance_miles) AS total_distance,
        SUM(total_duration_hours) AS total_duration,
        SUM(total_route_cost) AS total_cost,
        AVG(utilization_percentage) AS avg_utilization,
        AVG(optimization_score) AS avg_score
    FROM ANALYTICS.VW_ROUTE_PERFORMANCE
    WHERE route_date BETWEEN $start_date AND $end_date
      AND algorithm_used IN ('genetic_algorithm', 'or-tools', 'simulated_annealing')
    GROUP BY DATE_TRUNC('month', route_date)
)

SELECT
    '--- MONTHLY ROI TREND ---' AS monthly_section,
    TO_CHAR(COALESCE(mb.month, mo.month), 'YYYY-MM') AS month,
    COALESCE(mb.routes, 0) AS baseline_routes,
    COALESCE(mo.routes, 0) AS optimized_routes,
    ROUND(COALESCE(mb.total_distance, 0), 1) AS baseline_miles,
    ROUND(COALESCE(mo.total_distance, 0), 1) AS optimized_miles,
    ROUND(COALESCE(mb.total_distance, 0) - COALESCE(mo.total_distance, 0), 1) AS miles_saved,
    ROUND(COALESCE(mb.total_cost, 0), 2) AS baseline_cost,
    ROUND(COALESCE(mo.total_cost, 0), 2) AS optimized_cost,
    ROUND(COALESCE(mb.total_cost, 0) - COALESCE(mo.total_cost, 0), 2) AS cost_saved,
    ROUND((COALESCE(mb.total_cost, 0) - COALESCE(mo.total_cost, 0)) * 100.0 / NULLIF(mb.total_cost, 0), 2) AS savings_pct,
    ROUND(COALESCE(mo.avg_utilization, 0) - COALESCE(mb.avg_utilization, 0), 2) AS utilization_gain
FROM monthly_baseline mb
FULL OUTER JOIN monthly_optimized mo
    ON mb.month = mo.month
ORDER BY COALESCE(mb.month, mo.month) DESC;

/*------------------------------------------------------------------------------
 * SECTION 3: Cost Savings Breakdown
 *----------------------------------------------------------------------------*/

WITH savings_detail AS (
    SELECT
        -- Baseline
        SUM(CASE WHEN algorithm_used = 'nearest_neighbor' THEN total_distance_miles ELSE 0 END) AS baseline_miles,
        SUM(CASE WHEN algorithm_used = 'nearest_neighbor' THEN total_duration_hours ELSE 0 END) AS baseline_hours,
        SUM(CASE WHEN algorithm_used = 'nearest_neighbor' THEN total_labor_cost ELSE 0 END) AS baseline_labor_cost,
        SUM(CASE WHEN algorithm_used = 'nearest_neighbor' THEN total_vehicle_cost ELSE 0 END) AS baseline_vehicle_cost,

        -- Optimized
        SUM(CASE WHEN algorithm_used IN ('genetic_algorithm', 'or-tools', 'simulated_annealing')
            THEN total_distance_miles ELSE 0 END) AS optimized_miles,
        SUM(CASE WHEN algorithm_used IN ('genetic_algorithm', 'or-tools', 'simulated_annealing')
            THEN total_duration_hours ELSE 0 END) AS optimized_hours,
        SUM(CASE WHEN algorithm_used IN ('genetic_algorithm', 'or-tools', 'simulated_annealing')
            THEN total_labor_cost ELSE 0 END) AS optimized_labor_cost,
        SUM(CASE WHEN algorithm_used IN ('genetic_algorithm', 'or-tools', 'simulated_annealing')
            THEN total_vehicle_cost ELSE 0 END) AS optimized_vehicle_cost
    FROM ANALYTICS.VW_ROUTE_PERFORMANCE
    WHERE route_date BETWEEN $start_date AND $end_date
)

SELECT
    '--- COST SAVINGS BREAKDOWN ---' AS breakdown_section,

    -- Labor cost savings
    CONCAT('$', ROUND(baseline_labor_cost - optimized_labor_cost, 2)) AS labor_cost_saved,
    ROUND((baseline_labor_cost - optimized_labor_cost) * 100.0 / NULLIF(baseline_labor_cost, 0), 2) AS labor_savings_pct,
    ROUND(baseline_hours - optimized_hours, 1) AS labor_hours_saved,

    -- Vehicle cost savings
    CONCAT('$', ROUND(baseline_vehicle_cost - optimized_vehicle_cost, 2)) AS vehicle_cost_saved,
    ROUND((baseline_vehicle_cost - optimized_vehicle_cost) * 100.0 / NULLIF(baseline_vehicle_cost, 0), 2) AS vehicle_savings_pct,
    ROUND(baseline_miles - optimized_miles, 1) AS miles_saved,

    -- Total savings
    CONCAT('$', ROUND((baseline_labor_cost + baseline_vehicle_cost) -
                      (optimized_labor_cost + optimized_vehicle_cost), 2)) AS total_savings,
    ROUND(((baseline_labor_cost + baseline_vehicle_cost) -
           (optimized_labor_cost + optimized_vehicle_cost)) * 100.0 /
          NULLIF(baseline_labor_cost + baseline_vehicle_cost, 0), 2) AS total_savings_pct,

    -- Breakdown of savings
    ROUND((baseline_labor_cost - optimized_labor_cost) * 100.0 /
          NULLIF((baseline_labor_cost + baseline_vehicle_cost) -
                 (optimized_labor_cost + optimized_vehicle_cost), 0), 1) AS labor_pct_of_total_savings,
    ROUND((baseline_vehicle_cost - optimized_vehicle_cost) * 100.0 /
          NULLIF((baseline_labor_cost + baseline_vehicle_cost) -
                 (optimized_labor_cost + optimized_vehicle_cost), 0), 1) AS vehicle_pct_of_total_savings

FROM savings_detail;

/*------------------------------------------------------------------------------
 * SECTION 4: Environmental Impact
 *----------------------------------------------------------------------------*/

WITH environmental_impact AS (
    SELECT
        SUM(CASE WHEN algorithm_used = 'nearest_neighbor' THEN total_distance_miles ELSE 0 END) AS baseline_miles,
        SUM(CASE WHEN algorithm_used IN ('genetic_algorithm', 'or-tools', 'simulated_annealing')
            THEN total_distance_miles ELSE 0 END) AS optimized_miles
    FROM ANALYTICS.VW_ROUTE_PERFORMANCE
    WHERE route_date BETWEEN $start_date AND $end_date
)

SELECT
    '--- ENVIRONMENTAL IMPACT ---' AS environmental_section,

    ROUND(baseline_miles - optimized_miles, 1) AS miles_reduced,

    -- CO2 emissions saved (assuming 0.89 lbs CO2 per mile for average vehicle)
    ROUND((baseline_miles - optimized_miles) * 0.89, 1) AS co2_pounds_saved,
    ROUND((baseline_miles - optimized_miles) * 0.89 / 2000, 2) AS co2_tons_saved,

    -- Fuel saved (assuming 20 MPG average)
    ROUND((baseline_miles - optimized_miles) / 20, 1) AS gallons_fuel_saved,

    -- Fuel cost saved (assuming $3.50/gallon)
    CONCAT('$', ROUND((baseline_miles - optimized_miles) / 20 * 3.50, 2)) AS fuel_cost_saved,

    -- Equivalent environmental metrics
    ROUND((baseline_miles - optimized_miles) * 0.89 / 21.77, 1) AS equivalent_trees_planted,  -- 21.77 lbs CO2/tree/year
    ROUND((baseline_miles - optimized_miles) / 24, 1) AS equivalent_days_of_emissions  -- Average 24 miles/day per vehicle

FROM environmental_impact;

/*------------------------------------------------------------------------------
 * SECTION 5: Service Quality Impact
 *----------------------------------------------------------------------------*/

WITH quality_comparison AS (
    SELECT
        algorithm_used,
        COUNT(DISTINCT route_id) AS total_routes,
        AVG(completion_rate_pct) AS avg_completion_rate,
        AVG(on_time_delivery_pct) AS avg_on_time_rate,
        AVG(num_stops) AS avg_stops_per_route,
        AVG(utilization_percentage) AS avg_utilization,
        SUM(emergency_stops) AS emergency_jobs_completed,
        AVG(optimization_score) AS avg_optimization_score
    FROM ANALYTICS.VW_ROUTE_PERFORMANCE
    WHERE route_date BETWEEN $start_date AND $end_date
      AND algorithm_used IN ('nearest_neighbor', 'genetic_algorithm', 'or-tools', 'simulated_annealing')
    GROUP BY algorithm_used
)

SELECT
    '--- SERVICE QUALITY COMPARISON ---' AS quality_section,
    algorithm_used,
    total_routes,
    ROUND(avg_completion_rate, 1) AS completion_rate_pct,
    ROUND(avg_on_time_rate, 1) AS on_time_delivery_pct,
    ROUND(avg_stops_per_route, 1) AS avg_stops,
    ROUND(avg_utilization, 1) AS utilization_pct,
    emergency_jobs_completed,
    ROUND(avg_optimization_score, 3) AS optimization_score,

    -- Quality rating
    CASE
        WHEN avg_completion_rate >= 95 AND avg_on_time_rate >= 90 THEN 'Excellent'
        WHEN avg_completion_rate >= 85 AND avg_on_time_rate >= 80 THEN 'Good'
        WHEN avg_completion_rate >= 75 THEN 'Fair'
        ELSE 'Poor'
    END AS quality_rating

FROM quality_comparison
ORDER BY avg_optimization_score DESC NULLS LAST;

/*------------------------------------------------------------------------------
 * SECTION 6: Capacity Gained
 *----------------------------------------------------------------------------*/

WITH capacity_analysis AS (
    SELECT
        -- Baseline capacity
        SUM(CASE WHEN algorithm_used = 'nearest_neighbor' THEN num_stops ELSE 0 END) AS baseline_stops,
        SUM(CASE WHEN algorithm_used = 'nearest_neighbor' THEN total_duration_hours ELSE 0 END) AS baseline_hours,
        COUNT(DISTINCT CASE WHEN algorithm_used = 'nearest_neighbor' THEN technician_id END) AS baseline_technicians,

        -- Optimized capacity
        SUM(CASE WHEN algorithm_used IN ('genetic_algorithm', 'or-tools', 'simulated_annealing')
            THEN num_stops ELSE 0 END) AS optimized_stops,
        SUM(CASE WHEN algorithm_used IN ('genetic_algorithm', 'or-tools', 'simulated_annealing')
            THEN total_duration_hours ELSE 0 END) AS optimized_hours,
        COUNT(DISTINCT CASE WHEN algorithm_used IN ('genetic_algorithm', 'or-tools', 'simulated_annealing')
            THEN technician_id END) AS optimized_technicians,

        -- Time saved
        SUM(CASE WHEN algorithm_used = 'nearest_neighbor' THEN total_duration_hours ELSE 0 END) -
        SUM(CASE WHEN algorithm_used IN ('genetic_algorithm', 'or-tools', 'simulated_annealing')
            THEN total_duration_hours ELSE 0 END) AS hours_saved
    FROM ANALYTICS.VW_ROUTE_PERFORMANCE
    WHERE route_date BETWEEN $start_date AND $end_date
)

SELECT
    '--- CAPACITY GAINED ---' AS capacity_section,

    baseline_stops,
    optimized_stops,
    optimized_stops - baseline_stops AS additional_stops_capacity,

    ROUND(baseline_hours, 1) AS baseline_hours,
    ROUND(optimized_hours, 1) AS optimized_hours,
    ROUND(hours_saved, 1) AS hours_freed_up,

    baseline_technicians,
    optimized_technicians,

    -- Calculate equivalent capacity gain
    ROUND(hours_saved / 8, 1) AS equivalent_workdays_gained,
    ROUND(hours_saved / (8 * 5), 1) AS equivalent_workweeks_gained,
    ROUND(hours_saved / (8 * 20), 1) AS equivalent_technician_months_gained,

    -- Additional jobs that could be served
    ROUND((optimized_stops * 1.0 / NULLIF(optimized_hours, 0)) * hours_saved, 0) AS potential_additional_jobs,

    -- Value of freed capacity (assuming $100 avg revenue per job)
    CONCAT('$', ROUND((optimized_stops * 1.0 / NULLIF(optimized_hours, 0)) * hours_saved * 100, 2)) AS potential_additional_revenue

FROM capacity_analysis;

/*------------------------------------------------------------------------------
 * SECTION 7: Algorithm Performance Ranking
 *----------------------------------------------------------------------------*/

SELECT
    '--- ALGORITHM PERFORMANCE RANKING ---' AS algorithm_ranking_section,
    algorithm_used,
    algorithm_category,
    total_routes,

    -- Efficiency metrics
    ROUND(avg_distance_per_route, 2) AS avg_distance_miles,
    ROUND(avg_utilization_pct, 1) AS avg_utilization,
    ROUND(avg_optimization_score, 3) AS optimization_score,

    -- Savings vs baseline
    distance_improvement_vs_baseline_pct AS distance_saved_pct,
    cost_improvement_vs_baseline_pct AS cost_saved_pct,

    -- Quality
    ROUND(avg_total_cost_per_route, 2) AS avg_cost_per_route,
    ROUND(constraint_compliance_pct, 1) AS constraint_compliance,

    -- Speed
    ROUND(avg_computation_time_sec, 2) AS avg_compute_time_sec,
    computation_speed_rating,

    -- Overall rating
    recommendation_status,
    ROUND(overall_performance_score, 3) AS performance_score

FROM ANALYTICS.VW_OPTIMIZATION_COMPARISON
WHERE year_number >= YEAR($start_date)
  AND total_routes >= 10
ORDER BY overall_performance_score DESC
LIMIT 10;

/*------------------------------------------------------------------------------
 * SECTION 8: ROI Projection (Annualized)
 *----------------------------------------------------------------------------*/

WITH current_savings AS (
    SELECT
        DATEDIFF(day, $start_date, $end_date) AS analysis_days,

        SUM(CASE WHEN algorithm_used = 'nearest_neighbor' THEN total_route_cost ELSE 0 END) AS baseline_cost,
        SUM(CASE WHEN algorithm_used IN ('genetic_algorithm', 'or-tools', 'simulated_annealing')
            THEN total_route_cost ELSE 0 END) AS optimized_cost,

        SUM(CASE WHEN algorithm_used = 'nearest_neighbor' THEN total_distance_miles ELSE 0 END) AS baseline_miles,
        SUM(CASE WHEN algorithm_used IN ('genetic_algorithm', 'or-tools', 'simulated_annealing')
            THEN total_distance_miles ELSE 0 END) AS optimized_miles

    FROM ANALYTICS.VW_ROUTE_PERFORMANCE
    WHERE route_date BETWEEN $start_date AND $end_date
)

SELECT
    '--- ANNUALIZED ROI PROJECTION ---' AS projection_section,

    -- Current period savings
    analysis_days AS days_analyzed,
    CONCAT('$', ROUND(baseline_cost - optimized_cost, 2)) AS total_savings_to_date,
    ROUND(baseline_miles - optimized_miles, 1) AS total_miles_saved,

    -- Daily averages
    CONCAT('$', ROUND((baseline_cost - optimized_cost) / analysis_days, 2)) AS avg_savings_per_day,
    ROUND((baseline_miles - optimized_miles) / analysis_days, 1) AS avg_miles_saved_per_day,

    -- Annualized projections (365 days)
    CONCAT('$', ROUND((baseline_cost - optimized_cost) / analysis_days * 365, 2)) AS projected_annual_savings,
    ROUND((baseline_miles - optimized_miles) / analysis_days * 365, 1) AS projected_annual_miles_saved,

    -- 3-year projection
    CONCAT('$', ROUND((baseline_cost - optimized_cost) / analysis_days * 365 * 3, 2)) AS projected_3year_savings,

    -- Assuming one-time implementation cost of $50,000
    CONCAT('$', '50,000') AS estimated_implementation_cost,
    ROUND(50000 / ((baseline_cost - optimized_cost) / analysis_days * 365) * 365, 0) AS payback_period_days_annualized,
    ROUND(((baseline_cost - optimized_cost) / analysis_days * 365 * 3 - 50000) / 50000 * 100, 1) AS three_year_roi_pct

FROM current_savings;

/*------------------------------------------------------------------------------
 * SECTION 9: Key Recommendations
 *----------------------------------------------------------------------------*/

SELECT
    '--- KEY RECOMMENDATIONS ---' AS recommendations_section,

    CASE
        WHEN EXISTS (
            SELECT 1 FROM ANALYTICS.VW_OPTIMIZATION_COMPARISON
            WHERE distance_improvement_vs_baseline_pct > 15
              AND year_number = YEAR(CURRENT_DATE)
        )
        THEN 'Continue using advanced optimization - showing strong ROI (>15% distance reduction)'
        ELSE 'Evaluate optimization effectiveness - savings below target'
    END AS recommendation_1,

    CASE
        WHEN (
            SELECT AVG(avg_utilization_pct)
            FROM ANALYTICS.VW_OPTIMIZATION_COMPARISON
            WHERE algorithm_used IN ('genetic_algorithm', 'or-tools')
              AND year_number = YEAR(CURRENT_DATE)
        ) >= 75
        THEN 'Excellent technician utilization - capacity well-managed'
        ELSE 'Opportunity to improve technician utilization through better optimization'
    END AS recommendation_2,

    CASE
        WHEN (
            SELECT AVG(avg_computation_time_sec)
            FROM ANALYTICS.VW_OPTIMIZATION_COMPARISON
            WHERE algorithm_used IN ('genetic_algorithm', 'or-tools')
              AND year_number = YEAR(CURRENT_DATE)
        ) > 60
        THEN 'Consider optimizing computation time or using faster algorithms for real-time planning'
        ELSE 'Computation time acceptable for current operations'
    END AS recommendation_3,

    'Monitor environmental impact savings and consider carbon credit opportunities' AS recommendation_4,
    'Leverage freed capacity for additional revenue generation through new customer acquisition' AS recommendation_5;

/*==============================================================================
 * END OF QUERY
 *============================================================================*/
