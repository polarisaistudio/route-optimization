# ============================================================================
# View: Properties (Dimension Table)
# ============================================================================
# Source:      FIELD_SERVICE_OPS.ANALYTICS.DIM_PROPERTY
# Description: Dimension table containing property records for service
#              locations. Properties represent the physical locations where
#              field service work orders are fulfilled. Includes geographic
#              coordinates for distance calculations and map visualizations.
# Grain:       One row per property_id
# ============================================================================

view: properties {
  sql_table_name: FIELD_SERVICE_OPS.ANALYTICS.DIM_PROPERTY ;;
  drill_fields: [property_id, address, city, property_type, zone_id]

  # --------------------------------------------------------------------------
  # Primary Key
  # --------------------------------------------------------------------------
  dimension: property_id {
    primary_key: yes
    type: string
    sql: ${TABLE}.PROPERTY_ID ;;
    label: "Property ID"
    description: "Unique identifier for the property"
  }

  # --------------------------------------------------------------------------
  # Address Dimensions
  # --------------------------------------------------------------------------
  dimension: address {
    type: string
    sql: ${TABLE}.ADDRESS ;;
    label: "Street Address"
    description: "Full street address of the property"
  }

  dimension: city {
    type: string
    sql: ${TABLE}.CITY ;;
    label: "City"
    description: "City where the property is located"
  }

  dimension: state {
    type: string
    sql: ${TABLE}.STATE ;;
    label: "State"
    description: "State or province where the property is located"
    map_layer_name: us_states
  }

  dimension: zip_code {
    type: zipcode
    sql: ${TABLE}.ZIP_CODE ;;
    label: "ZIP Code"
    description: "Postal code for the property"
  }

  dimension: full_address {
    type: string
    sql: CONCAT(${TABLE}.ADDRESS, ', ', ${TABLE}.CITY, ', ', ${TABLE}.STATE, ' ', ${TABLE}.ZIP_CODE) ;;
    label: "Full Address"
    description: "Complete formatted address"
  }

  # --------------------------------------------------------------------------
  # Property Type Dimensions
  # --------------------------------------------------------------------------
  dimension: property_type {
    type: string
    sql: ${TABLE}.PROPERTY_TYPE ;;
    label: "Property Type"
    description: "Classification of the property (e.g., residential, commercial, industrial, mixed_use)"
  }

  dimension: property_subtype {
    type: string
    sql: ${TABLE}.PROPERTY_SUBTYPE ;;
    label: "Property Subtype"
    description: "Detailed property classification (e.g., single_family, apartment, office, warehouse)"
  }

  # --------------------------------------------------------------------------
  # Geographic Dimensions
  # --------------------------------------------------------------------------
  dimension: zone_id {
    type: string
    sql: ${TABLE}.ZONE_ID ;;
    label: "Zone ID"
    description: "Geographic service zone the property belongs to"
  }

  dimension: latitude {
    type: number
    sql: ${TABLE}.LATITUDE ;;
    label: "Latitude"
    description: "Geographic latitude coordinate"
    hidden: yes
  }

  dimension: longitude {
    type: number
    sql: ${TABLE}.LONGITUDE ;;
    label: "Longitude"
    description: "Geographic longitude coordinate"
    hidden: yes
  }

  dimension: location {
    type: location
    sql_latitude: ${latitude} ;;
    sql_longitude: ${longitude} ;;
    label: "Location"
    description: "Geographic location (latitude/longitude) for map visualizations"
  }

  # --------------------------------------------------------------------------
  # Property Attributes
  # --------------------------------------------------------------------------
  dimension: square_footage {
    type: number
    sql: ${TABLE}.SQUARE_FOOTAGE ;;
    label: "Square Footage"
    description: "Total square footage of the property"
    value_format_name: decimal_0
  }

  dimension: square_footage_tier {
    type: tier
    tiers: [500, 1000, 2000, 5000, 10000, 50000]
    style: integer
    sql: ${square_footage} ;;
    label: "Square Footage Tier"
    description: "Bucketed square footage ranges"
  }

  dimension: year_built {
    type: number
    sql: ${TABLE}.YEAR_BUILT ;;
    label: "Year Built"
    description: "Year the property was originally constructed"
    value_format_name: id
  }

  dimension: property_age {
    type: number
    sql: YEAR(CURRENT_DATE()) - ${TABLE}.YEAR_BUILT ;;
    label: "Property Age (years)"
    description: "Number of years since construction"
  }

  dimension: has_gate_code {
    type: yesno
    sql: ${TABLE}.GATE_CODE IS NOT NULL ;;
    label: "Has Gate Code"
    description: "Whether the property requires a gate code for access"
  }

  dimension: access_instructions {
    type: string
    sql: ${TABLE}.ACCESS_INSTRUCTIONS ;;
    label: "Access Instructions"
    description: "Special instructions for accessing the property"
  }

  # --------------------------------------------------------------------------
  # Measures
  # --------------------------------------------------------------------------
  measure: count {
    type: count
    label: "Total Properties"
    description: "Count of all properties"
    drill_fields: [property_id, address, city, property_type, zone_id]
  }

  measure: count_residential {
    type: count
    filters: [property_type: "residential"]
    label: "Residential Properties"
    description: "Count of residential properties"
  }

  measure: count_commercial {
    type: count
    filters: [property_type: "commercial"]
    label: "Commercial Properties"
    description: "Count of commercial properties"
  }

  measure: avg_square_footage {
    type: average
    sql: ${square_footage} ;;
    label: "Avg Square Footage"
    description: "Average property square footage"
    value_format_name: decimal_0
  }

  measure: avg_property_age {
    type: average
    sql: ${property_age} ;;
    label: "Avg Property Age (years)"
    description: "Average age of properties in years"
    value_format_name: decimal_0
  }
}
