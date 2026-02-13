# ============================================================================
# View: Routes (Fact Table)
# ============================================================================
# Source:      FIELD_SERVICE_OPS.ANALYTICS.FACT_ROUTE
# Description: Fact table containing optimized route records for field service
#              technicians. Each row represents a single planned or completed
#              route for a given date.
# Grain:       One row per route_id
# ============================================================================

view: routes {
  sql_table_name: FIELD_SERVICE_OPS.ANALYTICS.FACT_ROUTE ;;
  drill_fields: [route_id, technician_id, route_date, algorithm_used, status]

  # --------------------------------------------------------------------------
  # Primary Key
  # --------------------------------------------------------------------------
  dimension: route_id {
    primary_key: yes
    type: string
    sql: ${TABLE}.ROUTE_ID ;;
    label: "Route ID"
    description: "Unique identifier for the optimized route"
  }

  # --------------------------------------------------------------------------
  # Foreign Keys
  # --------------------------------------------------------------------------
  dimension: technician_id {
    type: string
    sql: ${TABLE}.TECHNICIAN_ID ;;
    label: "Technician ID"
    description: "Identifier for the assigned technician"
    hidden: yes
  }

  dimension: zone_id {
    type: string
    sql: ${TABLE}.ZONE_ID ;;
    label: "Zone ID"
    description: "Geographic zone the route primarily operates within"
  }

  # --------------------------------------------------------------------------
  # Date Dimensions
  # --------------------------------------------------------------------------
  dimension_group: route {
    type: time
    timeframes: [
      raw,
      date,
      day_of_week,
      week,
      month,
      quarter,
      year
    ]
    convert_tz: no
    datatype: date
    sql: ${TABLE}.ROUTE_DATE ;;
    label: "Route"
    description: "Date the route is planned or was executed"
  }

  dimension: route_date {
    type: date
    sql: ${TABLE}.ROUTE_DATE ;;
    label: "Route Date"
    description: "Date the route is planned or was executed (simple date)"
  }

  # --------------------------------------------------------------------------
  # Categorical Dimensions
  # --------------------------------------------------------------------------
  dimension: algorithm_used {
    type: string
    sql: ${TABLE}.ALGORITHM_USED ;;
    label: "Algorithm Used"
    description: "Optimization algorithm applied to generate this route (e.g., genetic_algorithm, or_tools_vrp, greedy_nearest, simulated_annealing)"
  }

  dimension: status {
    type: string
    sql: ${TABLE}.STATUS ;;
    label: "Status"
    description: "Current status of the route: planned, in_progress, completed, cancelled"
    html:
      {% if value == "completed" %}
        <span style="color: #00875a;">{{ value }}</span>
      {% elsif value == "in_progress" %}
        <span style="color: #0065ff;">{{ value }}</span>
      {% elsif value == "cancelled" %}
        <span style="color: #de350b;">{{ value }}</span>
      {% else %}
        {{ value }}
      {% endif %} ;;
  }

  # --------------------------------------------------------------------------
  # Numeric Dimensions
  # --------------------------------------------------------------------------
  dimension: total_distance_km {
    type: number
    sql: ${TABLE}.TOTAL_DISTANCE_KM ;;
    label: "Total Distance (km)"
    description: "Total planned driving distance for the route in kilometers"
    value_format_name: decimal_1
  }

  dimension: total_duration_min {
    type: number
    sql: ${TABLE}.TOTAL_DURATION_MIN ;;
    label: "Total Duration (min)"
    description: "Total planned duration including driving and service time in minutes"
    value_format_name: decimal_0
  }

  dimension: num_stops {
    type: number
    sql: ${TABLE}.NUM_STOPS ;;
    label: "Number of Stops"
    description: "Total number of service stops on the route"
  }

  dimension: utilization_pct {
    type: number
    sql: ${TABLE}.UTILIZATION_PCT ;;
    label: "Utilization %"
    description: "Percentage of the technician's available hours utilized by the route"
    value_format_name: percent_1
  }

  dimension: optimization_score {
    type: number
    sql: ${TABLE}.OPTIMIZATION_SCORE ;;
    label: "Optimization Score"
    description: "Composite score (0-100) reflecting the overall quality of the route optimization"
    value_format_name: decimal_1
  }

  dimension: distance_tier {
    type: tier
    tiers: [0, 25, 50, 100, 150, 200]
    style: integer
    sql: ${total_distance_km} ;;
    label: "Distance Tier (km)"
    description: "Bucketed distance ranges for route analysis"
  }

  # --------------------------------------------------------------------------
  # Measures
  # --------------------------------------------------------------------------
  measure: count {
    type: count
    label: "Total Routes"
    description: "Count of all routes"
    drill_fields: [route_id, technician_id, route_date, algorithm_used, status, total_distance_km, total_duration_min, num_stops]
  }

  measure: total_distance {
    type: sum
    sql: ${total_distance_km} ;;
    label: "Total Distance (km)"
    description: "Sum of all route distances in kilometers"
    value_format_name: decimal_1
    drill_fields: [route_id, route_date, algorithm_used, total_distance_km]
  }

  measure: avg_distance {
    type: average
    sql: ${total_distance_km} ;;
    label: "Avg Distance (km)"
    description: "Average route distance in kilometers"
    value_format_name: decimal_1
    drill_fields: [route_id, route_date, algorithm_used, total_distance_km]
  }

  measure: total_duration {
    type: sum
    sql: ${total_duration_min} ;;
    label: "Total Duration (min)"
    description: "Sum of all route durations in minutes"
    value_format_name: decimal_0
    drill_fields: [route_id, route_date, total_duration_min]
  }

  measure: avg_duration {
    type: average
    sql: ${total_duration_min} ;;
    label: "Avg Duration (min)"
    description: "Average route duration in minutes"
    value_format_name: decimal_1
    drill_fields: [route_id, route_date, total_duration_min]
  }

  measure: avg_stops {
    type: average
    sql: ${num_stops} ;;
    label: "Avg Stops per Route"
    description: "Average number of stops per route"
    value_format_name: decimal_1
    drill_fields: [route_id, route_date, num_stops, algorithm_used]
  }

  measure: avg_utilization {
    type: average
    sql: ${utilization_pct} ;;
    label: "Avg Utilization %"
    description: "Average technician utilization across routes"
    value_format_name: percent_1
  }

  measure: avg_optimization_score {
    type: average
    sql: ${optimization_score} ;;
    label: "Avg Optimization Score"
    description: "Average route optimization quality score"
    value_format_name: decimal_1
  }

  measure: completed_routes {
    type: count
    filters: [status: "completed"]
    label: "Completed Routes"
    description: "Count of routes with completed status"
  }

  measure: completion_rate {
    type: number
    sql: 1.0 * ${completed_routes} / NULLIF(${count}, 0) ;;
    label: "Route Completion Rate"
    description: "Percentage of planned routes that were completed"
    value_format_name: percent_1
  }
}

# ============================================================================
# View: Route Stops (Fact Table)
# ============================================================================
# Intermediate fact table linking routes to individual work order stops.
# ============================================================================

view: route_stops {
  sql_table_name: FIELD_SERVICE_OPS.ANALYTICS.FACT_ROUTE_STOP ;;

  dimension: route_stop_id {
    primary_key: yes
    type: string
    sql: ${TABLE}.ROUTE_STOP_ID ;;
    label: "Route Stop ID"
  }

  dimension: route_id {
    type: string
    sql: ${TABLE}.ROUTE_ID ;;
    hidden: yes
  }

  dimension: work_order_id {
    type: string
    sql: ${TABLE}.WORK_ORDER_ID ;;
    hidden: yes
  }

  dimension: stop_sequence {
    type: number
    sql: ${TABLE}.STOP_SEQUENCE ;;
    label: "Stop Sequence"
    description: "Order of the stop within the route"
  }

  dimension: arrival_time {
    type: string
    sql: ${TABLE}.ARRIVAL_TIME ;;
    label: "Arrival Time"
    description: "Planned arrival time at the stop"
  }

  dimension: departure_time {
    type: string
    sql: ${TABLE}.DEPARTURE_TIME ;;
    label: "Departure Time"
    description: "Planned departure time from the stop"
  }

  dimension: travel_distance_km {
    type: number
    sql: ${TABLE}.TRAVEL_DISTANCE_KM ;;
    label: "Travel Distance to Stop (km)"
    value_format_name: decimal_1
  }

  dimension: travel_time_min {
    type: number
    sql: ${TABLE}.TRAVEL_TIME_MIN ;;
    label: "Travel Time to Stop (min)"
    value_format_name: decimal_0
  }

  measure: count {
    type: count
    label: "Total Stops"
  }

  measure: avg_travel_distance {
    type: average
    sql: ${travel_distance_km} ;;
    label: "Avg Travel Distance Between Stops (km)"
    value_format_name: decimal_2
  }

  measure: avg_travel_time {
    type: average
    sql: ${travel_time_min} ;;
    label: "Avg Travel Time Between Stops (min)"
    value_format_name: decimal_1
  }
}
