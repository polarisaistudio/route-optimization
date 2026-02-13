# ============================================================================
# Route Optimization Engine - LookML Model
# ============================================================================
# Model:       route_optimization
# Connection:  snowflake_field_service
# Description: Central model for route optimization analytics, connecting
#              route performance data with work orders, technicians, and
#              property dimensions.
# ============================================================================

connection: "snowflake_field_service"

# Include all view definitions
include: "/looker/views/*.view.lkml"

# Include dashboard definitions
include: "/looker/dashboards/*.dashboard.lookml"

# ============================================================================
# Data group for caching policy
# ============================================================================
datagroup: route_optimization_default_datagroup {
  sql_trigger: SELECT MAX(updated_at) FROM FIELD_SERVICE_OPS.ANALYTICS.FACT_ROUTE ;;
  max_cache_age: "4 hours"
  label: "Route Optimization Cache"
  description: "Invalidates when new route data is loaded or every 4 hours"
}

persist_with: route_optimization_default_datagroup

# ============================================================================
# Explore: Route Performance
# ============================================================================
# Primary explore for analyzing route efficiency, stop-level details,
# technician assignments, and property characteristics.
# ============================================================================
explore: route_performance {
  label: "Route Performance"
  description: "Analyze route efficiency metrics including distance, duration, stop counts, and technician utilization. Join with work orders, technicians, and properties for full operational visibility."
  group_label: "Field Service Operations"

  from: routes
  view_name: routes

  # Join route stops for stop-level analysis
  join: route_stops {
    type: left_outer
    relationship: one_to_many
    sql_on: ${routes.route_id} = ${route_stops.route_id} ;;
  }

  # Join work orders through route stops
  join: work_orders {
    type: left_outer
    relationship: one_to_one
    sql_on: ${route_stops.work_order_id} = ${work_orders.work_order_id} ;;
  }

  # Join technician dimension for technician attributes
  join: technicians {
    type: left_outer
    relationship: many_to_one
    sql_on: ${routes.technician_id} = ${technicians.technician_id} ;;
  }

  # Join property dimension through work orders
  join: properties {
    type: left_outer
    relationship: many_to_one
    sql_on: ${work_orders.property_id} = ${properties.property_id} ;;
  }

  # Default access filters for row-level security
  access_filter: {
    field: routes.zone_id
    user_attribute: allowed_zones
  }

  # Always filter to prevent full table scans
  always_filter: {
    filters: [routes.route_date: "30 days"]
  }
}

# ============================================================================
# Explore: Technician Workload
# ============================================================================
# Focused explore for analyzing technician capacity, utilization, and
# workload distribution across the fleet.
# ============================================================================
explore: technician_workload {
  label: "Technician Workload"
  description: "Analyze technician capacity utilization, skill coverage, and workload balance across the field service team."
  group_label: "Field Service Operations"

  from: technicians
  view_name: technicians

  join: routes {
    type: left_outer
    relationship: one_to_many
    sql_on: ${technicians.technician_id} = ${routes.technician_id} ;;
  }

  join: work_orders {
    type: left_outer
    relationship: one_to_many
    sql_on: ${routes.route_id} = ${work_orders.route_id} ;;
  }

  always_filter: {
    filters: [routes.route_date: "7 days"]
  }
}

# ============================================================================
# Explore: Optimization Comparison
# ============================================================================
# Explore for comparing algorithm performance, A/B test results, and
# before/after optimization metrics.
# ============================================================================
explore: optimization_comparison {
  label: "Optimization Comparison"
  description: "Compare route optimization algorithm performance across different strategies, time periods, and zones. Use this explore for A/B testing analysis and algorithm tuning."
  group_label: "Field Service Operations"

  from: routes
  view_name: routes

  join: technicians {
    type: left_outer
    relationship: many_to_one
    sql_on: ${routes.technician_id} = ${technicians.technician_id} ;;
  }

  join: work_orders {
    type: left_outer
    relationship: one_to_many
    sql_on: ${routes.route_id} = ${work_orders.route_id} ;;
  }

  always_filter: {
    filters: [routes.route_date: "90 days"]
  }
}
