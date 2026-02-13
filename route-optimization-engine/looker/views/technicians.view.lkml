# ============================================================================
# View: Technicians (Dimension Table)
# ============================================================================
# Source:      FIELD_SERVICE_OPS.ANALYTICS.DIM_TECHNICIAN
# Description: Dimension table containing field service technician profiles
#              including skills, availability, and compensation data. Used to
#              analyze technician workload, skill coverage, and capacity
#              planning.
# Grain:       One row per technician_id
# ============================================================================

view: technicians {
  sql_table_name: FIELD_SERVICE_OPS.ANALYTICS.DIM_TECHNICIAN ;;
  drill_fields: [technician_id, name, skills, availability_status]

  # --------------------------------------------------------------------------
  # Primary Key
  # --------------------------------------------------------------------------
  dimension: technician_id {
    primary_key: yes
    type: string
    sql: ${TABLE}.TECHNICIAN_ID ;;
    label: "Technician ID"
    description: "Unique identifier for the field service technician"
  }

  # --------------------------------------------------------------------------
  # Descriptive Dimensions
  # --------------------------------------------------------------------------
  dimension: name {
    type: string
    sql: ${TABLE}.TECHNICIAN_NAME ;;
    label: "Technician Name"
    description: "Full name of the technician"
  }

  dimension: email {
    type: string
    sql: ${TABLE}.EMAIL ;;
    label: "Email"
    description: "Technician email address"
  }

  dimension: phone {
    type: string
    sql: ${TABLE}.PHONE ;;
    label: "Phone"
    description: "Technician phone number"
  }

  dimension: skills {
    type: string
    sql: ${TABLE}.SKILLS ;;
    label: "Skills"
    description: "Comma-separated list of certified skills (e.g., plumbing, electrical, HVAC, general_maintenance)"
  }

  dimension: skill_count {
    type: number
    sql: ARRAY_SIZE(SPLIT(${TABLE}.SKILLS, ',')) ;;
    label: "Number of Skills"
    description: "Count of distinct skills the technician is certified in"
  }

  dimension: home_zone_id {
    type: string
    sql: ${TABLE}.HOME_ZONE_ID ;;
    label: "Home Zone"
    description: "Primary geographic zone assigned to the technician"
  }

  # --------------------------------------------------------------------------
  # Capacity Dimensions
  # --------------------------------------------------------------------------
  dimension: max_daily_hours {
    type: number
    sql: ${TABLE}.MAX_DAILY_HOURS ;;
    label: "Max Daily Hours"
    description: "Maximum number of hours the technician can work per day"
    value_format_name: decimal_1
  }

  dimension: max_daily_hours_tier {
    type: tier
    tiers: [4, 6, 8, 10, 12]
    style: integer
    sql: ${max_daily_hours} ;;
    label: "Max Daily Hours Tier"
    description: "Bucketed daily hour capacity"
  }

  # --------------------------------------------------------------------------
  # Compensation Dimensions
  # --------------------------------------------------------------------------
  dimension: hourly_rate {
    type: number
    sql: ${TABLE}.HOURLY_RATE ;;
    label: "Hourly Rate ($)"
    description: "Technician's hourly compensation rate in USD"
    value_format_name: usd
  }

  dimension: hourly_rate_tier {
    type: tier
    tiers: [20, 30, 40, 50, 60, 80]
    style: integer
    sql: ${hourly_rate} ;;
    label: "Hourly Rate Tier"
    description: "Bucketed hourly rate ranges for compensation analysis"
  }

  # --------------------------------------------------------------------------
  # Status Dimensions
  # --------------------------------------------------------------------------
  dimension: availability_status {
    type: string
    sql: ${TABLE}.AVAILABILITY_STATUS ;;
    label: "Availability Status"
    description: "Current availability: available, on_leave, sick, training, inactive"
    html:
      {% if value == "available" %}
        <span style="color: #00875a; font-weight: bold;">{{ value }}</span>
      {% elsif value == "on_leave" or value == "training" %}
        <span style="color: #ff8b00;">{{ value }}</span>
      {% elsif value == "sick" %}
        <span style="color: #de350b;">{{ value }}</span>
      {% elsif value == "inactive" %}
        <span style="color: #97a0af;">{{ value }}</span>
      {% else %}
        {{ value }}
      {% endif %} ;;
  }

  dimension: is_active {
    type: yesno
    sql: ${TABLE}.AVAILABILITY_STATUS != 'inactive' ;;
    label: "Is Active"
    description: "Whether the technician is an active member of the workforce"
  }

  dimension: is_available {
    type: yesno
    sql: ${TABLE}.AVAILABILITY_STATUS = 'available' ;;
    label: "Is Available Today"
    description: "Whether the technician is currently available for scheduling"
  }

  # --------------------------------------------------------------------------
  # Date Dimensions
  # --------------------------------------------------------------------------
  dimension_group: hire {
    type: time
    timeframes: [date, month, year]
    sql: ${TABLE}.HIRE_DATE ;;
    label: "Hire"
    description: "Date the technician was hired"
  }

  dimension: tenure_years {
    type: number
    sql: DATEDIFF('year', ${TABLE}.HIRE_DATE, CURRENT_DATE()) ;;
    label: "Tenure (years)"
    description: "Number of years since the technician was hired"
    value_format_name: decimal_0
  }

  # --------------------------------------------------------------------------
  # Measures
  # --------------------------------------------------------------------------
  measure: count {
    type: count
    label: "Total Technicians"
    description: "Count of all technicians"
    drill_fields: [technician_id, name, skills, availability_status, max_daily_hours, hourly_rate]
  }

  measure: active_count {
    type: count
    filters: [is_active: "Yes"]
    label: "Active Technicians"
    description: "Count of active (non-inactive) technicians"
  }

  measure: available_count {
    type: count
    filters: [is_available: "Yes"]
    label: "Available Technicians"
    description: "Count of technicians currently available for scheduling"
  }

  measure: avg_hourly_rate {
    type: average
    sql: ${hourly_rate} ;;
    label: "Avg Hourly Rate ($)"
    description: "Average hourly compensation rate across technicians"
    value_format_name: usd
    drill_fields: [technician_id, name, hourly_rate, skills]
  }

  measure: total_daily_capacity_hours {
    type: sum
    sql: ${max_daily_hours} ;;
    label: "Total Daily Capacity (hours)"
    description: "Sum of all technician max daily hours representing total fleet capacity"
    value_format_name: decimal_0
    filters: [is_available: "Yes"]
  }

  measure: avg_skill_count {
    type: average
    sql: ${skill_count} ;;
    label: "Avg Skills per Technician"
    description: "Average number of certified skills per technician"
    value_format_name: decimal_1
  }

  measure: avg_tenure {
    type: average
    sql: ${tenure_years} ;;
    label: "Avg Tenure (years)"
    description: "Average tenure in years across the technician workforce"
    value_format_name: decimal_1
  }
}
