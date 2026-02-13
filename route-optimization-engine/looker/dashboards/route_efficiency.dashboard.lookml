# ============================================================================
# Dashboard: Route Optimization - Daily Efficiency
# ============================================================================
# Provides a comprehensive view of route optimization performance including
# KPI tiles, algorithm comparisons, distance trends, technician utilization,
# and work order priority distribution.
# ============================================================================

- dashboard: route_efficiency
  title: "Route Optimization - Daily Efficiency"
  layout: newspaper
  preferred_viewer: dashboards-next
  description: >
    Monitor daily route optimization performance across algorithms, zones,
    and technicians. Track distance reduction, utilization improvements,
    and work order fulfillment rates.
  filters_location_top: true
  refresh: 1 hour

  # ==========================================================================
  # Dashboard Filters
  # ==========================================================================
  filters:

    - name: date_filter
      title: "Date Range"
      type: field_filter
      default_value: "30 days"
      allow_multiple_values: true
      required: true
      ui_config:
        type: relative_timeframes
        display: inline
      explore: route_performance
      field: routes.route_date

    - name: algorithm_filter
      title: "Algorithm"
      type: field_filter
      default_value: ""
      allow_multiple_values: true
      required: false
      ui_config:
        type: checkboxes
        display: popover
      explore: route_performance
      field: routes.algorithm_used

    - name: zone_filter
      title: "Zone"
      type: field_filter
      default_value: ""
      allow_multiple_values: true
      required: false
      ui_config:
        type: checkboxes
        display: popover
      explore: route_performance
      field: routes.zone_id

  # ==========================================================================
  # KPI Tiles Row
  # ==========================================================================
  elements:

    # --- Tile: Total Routes ---
    - title: "Total Routes"
      name: total_routes
      explore: route_performance
      type: single_value
      fields: [routes.count]
      filters:
        routes.route_date: ""
      listen:
        date_filter: routes.route_date
        algorithm_filter: routes.algorithm_used
        zone_filter: routes.zone_id
      note_state: collapsed
      note_display: below
      note_text: "Total optimized routes in selected period"
      row: 0
      col: 0
      width: 6
      height: 4

    # --- Tile: Avg Distance ---
    - title: "Avg Distance (km)"
      name: avg_distance
      explore: route_performance
      type: single_value
      fields: [routes.avg_distance]
      filters:
        routes.route_date: ""
      listen:
        date_filter: routes.route_date
        algorithm_filter: routes.algorithm_used
        zone_filter: routes.zone_id
      note_state: collapsed
      note_display: below
      note_text: "Average distance per route"
      row: 0
      col: 6
      width: 6
      height: 4

    # --- Tile: Avg Utilization ---
    - title: "Avg Utilization"
      name: avg_utilization
      explore: route_performance
      type: single_value
      fields: [routes.avg_utilization]
      filters:
        routes.route_date: ""
      listen:
        date_filter: routes.route_date
        algorithm_filter: routes.algorithm_used
        zone_filter: routes.zone_id
      note_state: collapsed
      note_display: below
      note_text: "Average technician utilization across routes"
      row: 0
      col: 12
      width: 6
      height: 4

    # --- Tile: Improvement % ---
    - title: "Distance Improvement %"
      name: improvement_pct
      explore: optimization_comparison
      type: single_value
      fields: [routes.avg_optimization_score]
      filters:
        routes.route_date: ""
      listen:
        date_filter: routes.route_date
        algorithm_filter: routes.algorithm_used
        zone_filter: routes.zone_id
      note_state: collapsed
      note_display: below
      note_text: "Average optimization score (0-100)"
      row: 0
      col: 18
      width: 6
      height: 4

    # ========================================================================
    # Charts Row 1
    # ========================================================================

    # --- Chart: Routes by Algorithm (Bar) ---
    - title: "Routes by Algorithm"
      name: routes_by_algorithm
      explore: route_performance
      type: looker_bar
      fields: [routes.algorithm_used, routes.count, routes.avg_distance, routes.avg_duration]
      sorts: [routes.count desc]
      filters:
        routes.route_date: ""
      listen:
        date_filter: routes.route_date
        zone_filter: routes.zone_id
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_view_names: false
      show_y_axis_labels: true
      show_y_axis_ticks: true
      show_x_axis_label: true
      show_x_axis_ticks: true
      legend_position: center
      point_style: none
      series_colors:
        routes.count: "#0065ff"
        routes.avg_distance: "#00875a"
        routes.avg_duration: "#ff8b00"
      y_axes:
        - label: "Route Count"
          orientation: left
          series:
            - id: routes.count
              name: "Total Routes"
        - label: "Avg Distance (km)"
          orientation: right
          series:
            - id: routes.avg_distance
              name: "Avg Distance"
      row: 4
      col: 0
      width: 12
      height: 8

    # --- Chart: Distance Trend (Line) ---
    - title: "Distance Trend Over Time"
      name: distance_trend
      explore: route_performance
      type: looker_line
      fields: [routes.route_date, routes.avg_distance, routes.avg_duration]
      sorts: [routes.route_date asc]
      filters:
        routes.route_date: ""
      listen:
        date_filter: routes.route_date
        algorithm_filter: routes.algorithm_used
        zone_filter: routes.zone_id
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_view_names: false
      show_y_axis_labels: true
      show_y_axis_ticks: true
      show_x_axis_label: true
      show_x_axis_ticks: true
      legend_position: center
      point_style: circle
      line_width: 2
      series_colors:
        routes.avg_distance: "#0065ff"
        routes.avg_duration: "#ff8b00"
      y_axes:
        - label: "Avg Distance (km)"
          orientation: left
          series:
            - id: routes.avg_distance
              name: "Avg Distance"
        - label: "Avg Duration (min)"
          orientation: right
          series:
            - id: routes.avg_duration
              name: "Avg Duration"
      trend_lines:
        - color: "#de350b"
          label_position: right
          period: 7
          regression_type: linear
          series_index: 1
          show_label: true
      row: 4
      col: 12
      width: 12
      height: 8

    # ========================================================================
    # Charts Row 2
    # ========================================================================

    # --- Chart: Utilization by Technician (Bar) ---
    - title: "Utilization by Technician"
      name: utilization_by_technician
      explore: route_performance
      type: looker_bar
      fields: [technicians.name, routes.avg_utilization, routes.count]
      sorts: [routes.avg_utilization desc]
      limit: 20
      filters:
        routes.route_date: ""
      listen:
        date_filter: routes.route_date
        algorithm_filter: routes.algorithm_used
        zone_filter: routes.zone_id
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_view_names: false
      show_y_axis_labels: true
      show_y_axis_ticks: true
      show_x_axis_label: true
      show_x_axis_ticks: true
      legend_position: center
      series_colors:
        routes.avg_utilization: "#00875a"
        routes.count: "#0065ff"
      y_axes:
        - label: "Avg Utilization %"
          orientation: left
          series:
            - id: routes.avg_utilization
              name: "Utilization"
        - label: "Route Count"
          orientation: right
          series:
            - id: routes.count
              name: "Routes"
      reference_lines:
        - reference_type: line
          line_value: "0.85"
          range_start: max
          range_end: min
          margin_top: deviation
          margin_value: mean
          margin_bottom: deviation
          label_position: right
          color: "#de350b"
          label: "Target (85%)"
      row: 12
      col: 0
      width: 12
      height: 8

    # --- Chart: Jobs by Priority (Pie) ---
    - title: "Work Orders by Priority"
      name: jobs_by_priority
      explore: route_performance
      type: looker_pie
      fields: [work_orders.priority, work_orders.count]
      sorts: [work_orders.priority_order asc]
      filters:
        routes.route_date: ""
      listen:
        date_filter: routes.route_date
        algorithm_filter: routes.algorithm_used
        zone_filter: routes.zone_id
      value_labels: legend
      label_type: labPer
      show_view_names: false
      series_colors:
        critical: "#de350b"
        high: "#ff8b00"
        medium: "#ffc400"
        low: "#dfe1e6"
      inner_radius: 45
      row: 12
      col: 12
      width: 12
      height: 8

    # ========================================================================
    # Detail Table Row
    # ========================================================================

    # --- Table: Route Detail ---
    - title: "Route Detail Table"
      name: route_detail
      explore: route_performance
      type: looker_grid
      fields: [
        routes.route_date,
        routes.route_id,
        technicians.name,
        routes.algorithm_used,
        routes.num_stops,
        routes.total_distance_km,
        routes.total_duration_min,
        routes.utilization_pct,
        routes.optimization_score,
        routes.status
      ]
      sorts: [routes.route_date desc, routes.optimization_score desc]
      limit: 50
      filters:
        routes.route_date: ""
      listen:
        date_filter: routes.route_date
        algorithm_filter: routes.algorithm_used
        zone_filter: routes.zone_id
      show_view_names: false
      show_row_numbers: true
      truncate_column_names: false
      subtotals_at_bottom: false
      hide_totals: false
      hide_row_totals: false
      table_theme: white
      limit_displayed_rows: false
      enable_conditional_formatting: true
      conditional_formatting:
        - type: along a scale...
          value:
          background_color: "#00875a"
          font_color:
          color_application:
            collection_id: polaris-field-service
            palette_id: polaris-field-service-diverging-0
          bold: false
          italic: false
          strikethrough: false
          fields: [routes.optimization_score]
      row: 20
      col: 0
      width: 24
      height: 10
