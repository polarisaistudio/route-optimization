/**
 * Server Entry Point
 * Connects to MongoDB, starts the Express HTTP server, and handles graceful shutdown.
 */

const mongoose = require('mongoose');
const winston = require('winston');
const config = require('./config');
const app = require('./app');

// ---------------------------------------------------------------------------
// Winston Logger Setup
// ---------------------------------------------------------------------------
const logger = winston.createLogger({
  level: config.logging.level,
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'route-optimization-api' },
  transports: [
    // Console transport - always enabled
    new winston.transports.Console({
      format: config.server.isProduction
        ? winston.format.json()
        : winston.format.combine(
            winston.format.colorize(),
            winston.format.printf(({ timestamp, level, message, ...meta }) => {
              const metaStr = Object.keys(meta).length > 1
                ? ` ${JSON.stringify(meta)}`
                : '';
              return `${timestamp} [${level}]: ${message}${metaStr}`;
            })
          ),
    }),
  ],
});

// Add file transports in non-test environments
if (!config.server.isTest) {
  logger.add(
    new winston.transports.File({
      filename: config.logging.errorFile,
      level: 'error',
      maxsize: 20 * 1024 * 1024, // 20MB
      maxFiles: 5,
    })
  );
  logger.add(
    new winston.transports.File({
      filename: config.logging.file,
      maxsize: 20 * 1024 * 1024, // 20MB
      maxFiles: 5,
    })
  );
}

// Make logger available globally via winston default container
winston.add(logger.transports[0]);
if (logger.transports.length > 1) {
  for (let i = 1; i < logger.transports.length; i++) {
    winston.add(logger.transports[i]);
  }
}

// ---------------------------------------------------------------------------
// MongoDB Connection
// ---------------------------------------------------------------------------
const mongoUri = `${config.mongodb.uri}/${config.mongodb.dbName}`;

async function connectToDatabase() {
  try {
    await mongoose.connect(mongoUri, config.mongodb.options);
    logger.info('Connected to MongoDB', {
      uri: config.mongodb.uri.replace(/\/\/.*@/, '//<credentials>@'),
      database: config.mongodb.dbName,
    });
  } catch (err) {
    logger.error('Failed to connect to MongoDB', {
      error: err.message,
      uri: config.mongodb.uri.replace(/\/\/.*@/, '//<credentials>@'),
    });
    process.exit(1);
  }
}

// Handle MongoDB connection events
mongoose.connection.on('disconnected', () => {
  logger.warn('MongoDB disconnected');
});

mongoose.connection.on('reconnected', () => {
  logger.info('MongoDB reconnected');
});

mongoose.connection.on('error', (err) => {
  logger.error('MongoDB connection error', { error: err.message });
});

// ---------------------------------------------------------------------------
// Start Server
// ---------------------------------------------------------------------------
let server;

async function startServer() {
  await connectToDatabase();

  server = app.listen(config.server.port, () => {
    logger.info('Route Optimization API server started', {
      port: config.server.port,
      environment: config.server.env,
      nodeVersion: process.version,
      pid: process.pid,
    });
    logger.info(`API Documentation available at http://localhost:${config.server.port}/api-docs`);
  });

  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      logger.error(`Port ${config.server.port} is already in use`);
    } else {
      logger.error('Server error', { error: err.message });
    }
    process.exit(1);
  });
}

// ---------------------------------------------------------------------------
// Graceful Shutdown
// ---------------------------------------------------------------------------
async function gracefulShutdown(signal) {
  logger.info(`${signal} received. Starting graceful shutdown...`);

  // Stop accepting new connections
  if (server) {
    server.close((err) => {
      if (err) {
        logger.error('Error closing HTTP server', { error: err.message });
      } else {
        logger.info('HTTP server closed');
      }
    });
  }

  // Close MongoDB connection
  try {
    await mongoose.connection.close();
    logger.info('MongoDB connection closed');
  } catch (err) {
    logger.error('Error closing MongoDB connection', { error: err.message });
  }

  // Allow a maximum of 10 seconds for shutdown
  const shutdownTimeout = setTimeout(() => {
    logger.error('Graceful shutdown timed out, forcing exit');
    process.exit(1);
  }, 10000);

  shutdownTimeout.unref();

  logger.info('Graceful shutdown complete');
  process.exit(0);
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Handle unhandled rejections and uncaught exceptions
process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Promise Rejection', {
    reason: reason instanceof Error ? reason.message : reason,
    stack: reason instanceof Error ? reason.stack : undefined,
  });
});

process.on('uncaughtException', (err) => {
  logger.error('Uncaught Exception', {
    error: err.message,
    stack: err.stack,
  });
  // Exit after logging - the process manager should restart
  process.exit(1);
});

// Start the server
startServer();

module.exports = { app, startServer };
