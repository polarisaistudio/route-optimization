# ============================================================================
# View: Work Orders (Fact Table)
# ============================================================================
# Source:      FIELD_SERVICE_OPS.ANALYTICS.FACT_WORK_ORDER
# Description: Fact table containing work order records representing service
#              jobs to be fulfilled by field technicians. Work orders originate
#              from Salesforce and are enriched with scheduling and routing
#              metadata during the optimization process.
# Grain:       One row per work_order_id
# ============================================================================

view: work_orders {
  sql_table_name: FIELD_SERVICE_OPS.ANALYTICS.FACT_WORK_ORDER ;;
  drill_fields: [work_order_id, category, priority, status, estimated_duration]

  # --------------------------------------------------------------------------
  # Primary Key
  # --------------------------------------------------------------------------
  dimension: work_order_id {
    primary_key: yes
    type: string
    sql: ${TABLE}.WORK_ORDER_ID ;;
    label: "Work Order ID"
    description: "Unique identifier for the work order"
  }

  # --------------------------------------------------------------------------
  # Foreign Keys
  # --------------------------------------------------------------------------
  dimension: property_id {
    type: string
    sql: ${TABLE}.PROPERTY_ID ;;
    label: "Property ID"
    description: "Identifier for the property where service is performed"
    hidden: yes
  }

  dimension: route_id {
    type: string
    sql: ${TABLE}.ROUTE_ID ;;
    label: "Route ID"
    description: "Identifier for the assigned route"
    hidden: yes
  }

  dimension: technician_id {
    type: string
    sql: ${TABLE}.TECHNICIAN_ID ;;
    label: "Technician ID"
    description: "Identifier for the assigned technician"
    hidden: yes
  }

  dimension: salesforce_id {
    type: string
    sql: ${TABLE}.SALESFORCE_ID ;;
    label: "Salesforce ID"
    description: "Original Salesforce record identifier for traceability"
  }

  # --------------------------------------------------------------------------
  # Categorical Dimensions
  # --------------------------------------------------------------------------
  dimension: category {
    type: string
    sql: ${TABLE}.CATEGORY ;;
    label: "Category"
    description: "Work order category (e.g., inspection, maintenance, repair, installation, emergency)"
  }

  dimension: priority {
    type: string
    sql: ${TABLE}.PRIORITY ;;
    label: "Priority"
    description: "Work order priority level: critical, high, medium, low"
    html:
      {% if value == "critical" %}
        <span style="color: #ffffff; background-color: #de350b; padding: 2px 8px; border-radius: 4px;">{{ value }}</span>
      {% elsif value == "high" %}
        <span style="color: #ffffff; background-color: #ff8b00; padding: 2px 8px; border-radius: 4px;">{{ value }}</span>
      {% elsif value == "medium" %}
        <span style="color: #172b4d; background-color: #ffc400; padding: 2px 8px; border-radius: 4px;">{{ value }}</span>
      {% else %}
        <span style="color: #172b4d; background-color: #dfe1e6; padding: 2px 8px; border-radius: 4px;">{{ value }}</span>
      {% endif %} ;;
  }

  dimension: priority_order {
    type: number
    sql: CASE
           WHEN ${TABLE}.PRIORITY = 'critical' THEN 1
           WHEN ${TABLE}.PRIORITY = 'high' THEN 2
           WHEN ${TABLE}.PRIORITY = 'medium' THEN 3
           WHEN ${TABLE}.PRIORITY = 'low' THEN 4
           ELSE 5
         END ;;
    label: "Priority Sort Order"
    description: "Numeric ordering for priority-based sorting"
    hidden: yes
  }

  dimension: status {
    type: string
    sql: ${TABLE}.STATUS ;;
    label: "Status"
    description: "Current work order status: pending, assigned, in_progress, completed, cancelled, deferred"
    html:
      {% if value == "completed" %}
        <span style="color: #00875a;">{{ value }}</span>
      {% elsif value == "in_progress" %}
        <span style="color: #0065ff;">{{ value }}</span>
      {% elsif value == "cancelled" %}
        <span style="color: #de350b;">{{ value }}</span>
      {% elsif value == "deferred" %}
        <span style="color: #ff8b00;">{{ value }}</span>
      {% else %}
        {{ value }}
      {% endif %} ;;
  }

  dimension: required_skills {
    type: string
    sql: ${TABLE}.REQUIRED_SKILLS ;;
    label: "Required Skills"
    description: "Comma-separated list of skills required to complete the work order"
  }

  dimension: is_emergency {
    type: yesno
    sql: ${TABLE}.PRIORITY = 'critical' ;;
    label: "Is Emergency"
    description: "Whether the work order is classified as a critical/emergency job"
  }

  # --------------------------------------------------------------------------
  # Numeric Dimensions
  # --------------------------------------------------------------------------
  dimension: estimated_duration {
    type: number
    sql: ${TABLE}.ESTIMATED_DURATION_MIN ;;
    label: "Estimated Duration (min)"
    description: "Estimated time in minutes to complete the work order"
    value_format_name: decimal_0
  }

  dimension: actual_duration {
    type: number
    sql: ${TABLE}.ACTUAL_DURATION_MIN ;;
    label: "Actual Duration (min)"
    description: "Actual time in minutes taken to complete the work order"
    value_format_name: decimal_0
  }

  dimension: duration_variance {
    type: number
    sql: ${TABLE}.ACTUAL_DURATION_MIN - ${TABLE}.ESTIMATED_DURATION_MIN ;;
    label: "Duration Variance (min)"
    description: "Difference between actual and estimated duration (positive = took longer)"
    value_format_name: decimal_0
  }

  dimension: estimated_duration_tier {
    type: tier
    tiers: [0, 30, 60, 120, 180, 240]
    style: integer
    sql: ${estimated_duration} ;;
    label: "Estimated Duration Tier (min)"
    description: "Bucketed estimated duration for distribution analysis"
  }

  # --------------------------------------------------------------------------
  # Time Dimension Groups
  # --------------------------------------------------------------------------
  dimension_group: time_window_start {
    type: time
    timeframes: [
      raw,
      time,
      hour_of_day,
      date,
      day_of_week,
      week,
      month,
      quarter,
      year
    ]
    sql: ${TABLE}.TIME_WINDOW_START ;;
    label: "Time Window Start"
    description: "Start of the customer-requested service time window"
  }

  dimension_group: time_window_end {
    type: time
    timeframes: [
      raw,
      time,
      hour_of_day,
      date
    ]
    sql: ${TABLE}.TIME_WINDOW_END ;;
    label: "Time Window End"
    description: "End of the customer-requested service time window"
  }

  dimension_group: created {
    type: time
    timeframes: [
      raw,
      time,
      date,
      day_of_week,
      week,
      month,
      quarter,
      year
    ]
    sql: ${TABLE}.CREATED_AT ;;
    label: "Created"
    description: "Timestamp when the work order was created"
  }

  dimension_group: completed {
    type: time
    timeframes: [
      raw,
      time,
      date,
      week,
      month
    ]
    sql: ${TABLE}.COMPLETED_AT ;;
    label: "Completed"
    description: "Timestamp when the work order was marked as completed"
  }

  dimension: time_window_duration_hours {
    type: number
    sql: DATEDIFF('hour', ${TABLE}.TIME_WINDOW_START, ${TABLE}.TIME_WINDOW_END) ;;
    label: "Time Window Duration (hours)"
    description: "Length of the customer service time window in hours"
    value_format_name: decimal_1
  }

  # --------------------------------------------------------------------------
  # Measures
  # --------------------------------------------------------------------------
  measure: count {
    type: count
    label: "Total Work Orders"
    description: "Count of all work orders"
    drill_fields: [work_order_id, category, priority, status, estimated_duration, time_window_start_time]
  }

  measure: total_estimated_duration {
    type: sum
    sql: ${estimated_duration} ;;
    label: "Total Estimated Duration (min)"
    description: "Sum of all estimated work order durations in minutes"
    value_format_name: decimal_0
    drill_fields: [work_order_id, category, estimated_duration]
  }

  measure: avg_duration {
    type: average
    sql: ${estimated_duration} ;;
    label: "Avg Estimated Duration (min)"
    description: "Average estimated duration across work orders in minutes"
    value_format_name: decimal_1
    drill_fields: [work_order_id, category, estimated_duration]
  }

  measure: avg_actual_duration {
    type: average
    sql: ${actual_duration} ;;
    label: "Avg Actual Duration (min)"
    description: "Average actual duration across completed work orders"
    value_format_name: decimal_1
  }

  measure: emergency_count {
    type: count
    filters: [priority: "critical"]
    label: "Emergency Work Orders"
    description: "Count of critical/emergency work orders"
    drill_fields: [work_order_id, category, status, time_window_start_time]
  }

  measure: completion_rate {
    type: number
    sql: 1.0 * COUNT(CASE WHEN ${TABLE}.STATUS = 'completed' THEN 1 END) / NULLIF(${count}, 0) ;;
    label: "Completion Rate"
    description: "Percentage of work orders that have been completed"
    value_format_name: percent_1
  }

  measure: on_time_rate {
    type: number
    sql: 1.0 * COUNT(CASE
           WHEN ${TABLE}.STATUS = 'completed'
             AND ${TABLE}.COMPLETED_AT <= ${TABLE}.TIME_WINDOW_END
           THEN 1
         END) / NULLIF(COUNT(CASE WHEN ${TABLE}.STATUS = 'completed' THEN 1 END), 0) ;;
    label: "On-Time Completion Rate"
    description: "Percentage of completed work orders finished within the time window"
    value_format_name: percent_1
  }

  measure: avg_duration_variance {
    type: average
    sql: ${duration_variance} ;;
    label: "Avg Duration Variance (min)"
    description: "Average difference between actual and estimated duration"
    value_format_name: decimal_1
  }
}
