/*==============================================================================
 * FIELD SERVICE OPERATIONS - ROUTE OPTIMIZATION ENGINE
 * Database, Warehouse, Schema, and Role Setup
 *
 * Purpose: Initial setup script for Snowflake environment
 * Author: Route Optimization Team
 * Created: 2026-02-12
 *
 * Components:
 *   - Database: FIELD_SERVICE_OPS
 *   - Warehouses: INGEST_WH, COMPUTE_WH, ANALYTICS_WH
 *   - Schemas: RAW, STAGING, ANALYTICS
 *   - Roles: INGEST_ROLE, ANALYST_ROLE, ADMIN_ROLE
 *
 * Prerequisites: SYSADMIN or ACCOUNTADMIN privileges
 *============================================================================*/

-- Set context to SYSADMIN role for object creation
USE ROLE SYSADMIN;

/*------------------------------------------------------------------------------
 * DATABASE CREATION
 *----------------------------------------------------------------------------*/

-- Create main database for field service operations
CREATE DATABASE IF NOT EXISTS FIELD_SERVICE_OPS
    COMMENT = 'Field Service Route Optimization Engine - Production Database';

-- Set database context
USE DATABASE FIELD_SERVICE_OPS;

/*------------------------------------------------------------------------------
 * WAREHOUSE CREATION
 *----------------------------------------------------------------------------*/

-- Warehouse for data ingestion workloads (lightweight)
CREATE WAREHOUSE IF NOT EXISTS INGEST_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    WAREHOUSE_TYPE = 'STANDARD'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 2
    SCALING_POLICY = 'STANDARD'
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for raw data ingestion and ETL processes';

-- Warehouse for transformation and computation workloads
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
    WAREHOUSE_SIZE = 'SMALL'
    WAREHOUSE_TYPE = 'STANDARD'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 3
    SCALING_POLICY = 'STANDARD'
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for data transformation and route optimization computations';

-- Warehouse for analytics and reporting workloads
CREATE WAREHOUSE IF NOT EXISTS ANALYTICS_WH
    WAREHOUSE_SIZE = 'MEDIUM'
    WAREHOUSE_TYPE = 'STANDARD'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 4
    SCALING_POLICY = 'ECONOMY'
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for analytics, BI queries, and route performance reporting';

/*------------------------------------------------------------------------------
 * SCHEMA CREATION
 *----------------------------------------------------------------------------*/

-- RAW schema: landing zone for ingested data (minimal transformation)
CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Raw data landing zone - ingested data with minimal transformation';

-- STAGING schema: cleansed and validated data
CREATE SCHEMA IF NOT EXISTS STAGING
    COMMENT = 'Staging layer - cleansed, validated, and deduplicated data';

-- ANALYTICS schema: analytics-ready dimensional model
CREATE SCHEMA IF NOT EXISTS ANALYTICS
    COMMENT = 'Analytics layer - dimensional model for reporting and analysis';

/*------------------------------------------------------------------------------
 * ROLE CREATION
 *----------------------------------------------------------------------------*/

-- Switch to ACCOUNTADMIN for role creation
USE ROLE ACCOUNTADMIN;

-- Role for data ingestion processes
CREATE ROLE IF NOT EXISTS INGEST_ROLE
    COMMENT = 'Role for data ingestion and ETL processes';

-- Role for data analysts and BI users
CREATE ROLE IF NOT EXISTS ANALYST_ROLE
    COMMENT = 'Role for analysts and business intelligence users';

-- Role for database administrators
CREATE ROLE IF NOT EXISTS ADMIN_ROLE
    COMMENT = 'Role for database administrators';

/*------------------------------------------------------------------------------
 * ROLE HIERARCHY
 *----------------------------------------------------------------------------*/

-- Establish role hierarchy (ADMIN_ROLE > ANALYST_ROLE > INGEST_ROLE)
GRANT ROLE INGEST_ROLE TO ROLE ANALYST_ROLE;
GRANT ROLE ANALYST_ROLE TO ROLE ADMIN_ROLE;
GRANT ROLE ADMIN_ROLE TO ROLE SYSADMIN;

/*------------------------------------------------------------------------------
 * DATABASE GRANTS
 *----------------------------------------------------------------------------*/

-- Grant database usage to all roles
GRANT USAGE ON DATABASE FIELD_SERVICE_OPS TO ROLE INGEST_ROLE;
GRANT USAGE ON DATABASE FIELD_SERVICE_OPS TO ROLE ANALYST_ROLE;
GRANT USAGE ON DATABASE FIELD_SERVICE_OPS TO ROLE ADMIN_ROLE;

-- Grant all privileges to ADMIN_ROLE
GRANT ALL PRIVILEGES ON DATABASE FIELD_SERVICE_OPS TO ROLE ADMIN_ROLE;

/*------------------------------------------------------------------------------
 * SCHEMA GRANTS
 *----------------------------------------------------------------------------*/

-- RAW schema grants
GRANT USAGE ON SCHEMA RAW TO ROLE INGEST_ROLE;
GRANT USAGE ON SCHEMA RAW TO ROLE ANALYST_ROLE;
GRANT USAGE ON SCHEMA RAW TO ROLE ADMIN_ROLE;

GRANT CREATE TABLE ON SCHEMA RAW TO ROLE INGEST_ROLE;
GRANT CREATE TABLE ON SCHEMA RAW TO ROLE ADMIN_ROLE;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA RAW TO ROLE INGEST_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA RAW TO ROLE INGEST_ROLE;

GRANT SELECT ON ALL TABLES IN SCHEMA RAW TO ROLE ANALYST_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA RAW TO ROLE ANALYST_ROLE;

GRANT ALL PRIVILEGES ON SCHEMA RAW TO ROLE ADMIN_ROLE;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA RAW TO ROLE ADMIN_ROLE;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA RAW TO ROLE ADMIN_ROLE;

-- STAGING schema grants
GRANT USAGE ON SCHEMA STAGING TO ROLE INGEST_ROLE;
GRANT USAGE ON SCHEMA STAGING TO ROLE ANALYST_ROLE;
GRANT USAGE ON SCHEMA STAGING TO ROLE ADMIN_ROLE;

GRANT CREATE TABLE ON SCHEMA STAGING TO ROLE INGEST_ROLE;
GRANT CREATE TABLE ON SCHEMA STAGING TO ROLE ADMIN_ROLE;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA STAGING TO ROLE INGEST_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA STAGING TO ROLE INGEST_ROLE;

GRANT SELECT ON ALL TABLES IN SCHEMA STAGING TO ROLE ANALYST_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA STAGING TO ROLE ANALYST_ROLE;

GRANT ALL PRIVILEGES ON SCHEMA STAGING TO ROLE ADMIN_ROLE;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA STAGING TO ROLE ADMIN_ROLE;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA STAGING TO ROLE ADMIN_ROLE;

-- ANALYTICS schema grants
GRANT USAGE ON SCHEMA ANALYTICS TO ROLE ANALYST_ROLE;
GRANT USAGE ON SCHEMA ANALYTICS TO ROLE ADMIN_ROLE;

GRANT CREATE TABLE ON SCHEMA ANALYTICS TO ROLE ADMIN_ROLE;
GRANT CREATE VIEW ON SCHEMA ANALYTICS TO ROLE ADMIN_ROLE;

GRANT SELECT ON ALL TABLES IN SCHEMA ANALYTICS TO ROLE ANALYST_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA ANALYTICS TO ROLE ANALYST_ROLE;
GRANT SELECT ON ALL VIEWS IN SCHEMA ANALYTICS TO ROLE ANALYST_ROLE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA ANALYTICS TO ROLE ANALYST_ROLE;

GRANT ALL PRIVILEGES ON SCHEMA ANALYTICS TO ROLE ADMIN_ROLE;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA ANALYTICS TO ROLE ADMIN_ROLE;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA ANALYTICS TO ROLE ADMIN_ROLE;
GRANT ALL PRIVILEGES ON ALL VIEWS IN SCHEMA ANALYTICS TO ROLE ADMIN_ROLE;
GRANT ALL PRIVILEGES ON FUTURE VIEWS IN SCHEMA ANALYTICS TO ROLE ADMIN_ROLE;

/*------------------------------------------------------------------------------
 * WAREHOUSE GRANTS
 *----------------------------------------------------------------------------*/

-- INGEST_WH grants
GRANT USAGE ON WAREHOUSE INGEST_WH TO ROLE INGEST_ROLE;
GRANT USAGE ON WAREHOUSE INGEST_WH TO ROLE ADMIN_ROLE;
GRANT OPERATE ON WAREHOUSE INGEST_WH TO ROLE ADMIN_ROLE;
GRANT MODIFY ON WAREHOUSE INGEST_WH TO ROLE ADMIN_ROLE;

-- COMPUTE_WH grants
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE INGEST_ROLE;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE ANALYST_ROLE;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE ADMIN_ROLE;
GRANT OPERATE ON WAREHOUSE COMPUTE_WH TO ROLE ADMIN_ROLE;
GRANT MODIFY ON WAREHOUSE COMPUTE_WH TO ROLE ADMIN_ROLE;

-- ANALYTICS_WH grants
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE ANALYST_ROLE;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE ADMIN_ROLE;
GRANT OPERATE ON WAREHOUSE ANALYTICS_WH TO ROLE ADMIN_ROLE;
GRANT MODIFY ON WAREHOUSE ANALYTICS_WH TO ROLE ADMIN_ROLE;

/*------------------------------------------------------------------------------
 * RESOURCE MONITORS (Optional - uncomment and adjust as needed)
 *----------------------------------------------------------------------------*/

/*
-- Create resource monitor for cost control
USE ROLE ACCOUNTADMIN;

CREATE RESOURCE MONITOR IF NOT EXISTS FIELD_SERVICE_MONITOR
    CREDIT_QUOTA = 1000
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO SUSPEND
        ON 100 PERCENT DO SUSPEND_IMMEDIATE;

-- Assign monitor to warehouses
ALTER WAREHOUSE INGEST_WH SET RESOURCE_MONITOR = FIELD_SERVICE_MONITOR;
ALTER WAREHOUSE COMPUTE_WH SET RESOURCE_MONITOR = FIELD_SERVICE_MONITOR;
ALTER WAREHOUSE ANALYTICS_WH SET RESOURCE_MONITOR = FIELD_SERVICE_MONITOR;
*/

/*------------------------------------------------------------------------------
 * VERIFICATION QUERIES
 *----------------------------------------------------------------------------*/

-- Verify database creation
SHOW DATABASES LIKE 'FIELD_SERVICE_OPS';

-- Verify warehouse creation
SHOW WAREHOUSES LIKE '%WH';

-- Verify schema creation
USE DATABASE FIELD_SERVICE_OPS;
SHOW SCHEMAS;

-- Verify role creation
SHOW ROLES LIKE '%ROLE';

-- Display role hierarchy
SHOW GRANTS TO ROLE ADMIN_ROLE;
SHOW GRANTS TO ROLE ANALYST_ROLE;
SHOW GRANTS TO ROLE INGEST_ROLE;

/*==============================================================================
 * END OF SCRIPT
 *============================================================================*/
