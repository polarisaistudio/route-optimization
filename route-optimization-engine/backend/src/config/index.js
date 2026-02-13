/**
 * Centralized Configuration
 * All configuration values loaded from environment variables with sensible defaults.
 */

require('dotenv').config();

const config = {
  server: {
    port: parseInt(process.env.PORT, 10) || 3001,
    env: process.env.NODE_ENV || 'development',
    isProduction: process.env.NODE_ENV === 'production',
    isTest: process.env.NODE_ENV === 'test',
  },

  mongodb: {
    uri: process.env.MONGODB_URI || 'mongodb://localhost:27017',
    dbName: process.env.MONGODB_DB_NAME || 'route_optimization',
    options: {
      maxPoolSize: parseInt(process.env.MONGODB_POOL_SIZE, 10) || 10,
      serverSelectionTimeoutMS: parseInt(process.env.MONGODB_TIMEOUT, 10) || 5000,
      heartbeatFrequencyMS: parseInt(process.env.MONGODB_HEARTBEAT, 10) || 10000,
    },
  },

  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT, 10) || 6379,
    password: process.env.REDIS_PASSWORD || '',
    db: parseInt(process.env.REDIS_DB, 10) || 0,
    keyPrefix: process.env.REDIS_KEY_PREFIX || 'route-opt:',
  },

  jwt: {
    secret: process.env.JWT_SECRET || 'dev-secret-change-in-production',
    expiry: process.env.JWT_EXPIRY || '24h',
    issuer: process.env.JWT_ISSUER || 'route-optimization-api',
  },

  okta: {
    issuer: process.env.OKTA_ISSUER || '',
    clientId: process.env.OKTA_CLIENT_ID || '',
    audience: process.env.OKTA_AUDIENCE || 'api://default',
  },

  newrelic: {
    enabled: process.env.NEW_RELIC_ENABLED === 'true',
    licenseKey: process.env.NEW_RELIC_LICENSE_KEY || '',
    appName: process.env.NEW_RELIC_APP_NAME || 'Route Optimization API',
  },

  optimization: {
    maxTimeSeconds: parseInt(process.env.OPTIMIZATION_MAX_TIME, 10) || 300,
    defaultAlgorithm: process.env.OPTIMIZATION_DEFAULT_ALGORITHM || 'vrp',
    pythonPath: process.env.PYTHON_PATH || 'python3',
    scriptPath: process.env.OPTIMIZATION_SCRIPT_PATH || 'scripts/run_optimization.py',
  },

  aws: {
    region: process.env.AWS_REGION || 'us-east-1',
    s3Bucket: process.env.AWS_S3_BUCKET || 'route-optimization-data',
    lambdaFunction: process.env.AWS_LAMBDA_FUNCTION || 'route-optimization-engine',
    accessKeyId: process.env.AWS_ACCESS_KEY_ID || '',
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || '',
  },

  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) || 15 * 60 * 1000, // 15 minutes
    max: parseInt(process.env.RATE_LIMIT_MAX, 10) || 100,
  },

  cors: {
    origin: process.env.CORS_ORIGIN || '*',
    credentials: process.env.CORS_CREDENTIALS === 'true',
  },

  logging: {
    level: process.env.LOG_LEVEL || 'info',
    file: process.env.LOG_FILE || 'logs/app.log',
    errorFile: process.env.LOG_ERROR_FILE || 'logs/error.log',
    maxSize: process.env.LOG_MAX_SIZE || '20m',
    maxFiles: process.env.LOG_MAX_FILES || '14d',
  },
};

module.exports = config;
