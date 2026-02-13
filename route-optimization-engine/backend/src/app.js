/**
 * Express Application Setup
 * Configures middleware, mounts route handlers, and sets up error handling.
 * This file exports the Express app without starting the server,
 * making it testable with supertest.
 */

const config = require('./config');

// Conditionally require New Relic before anything else
if (config.newrelic.enabled) {
  try {
    require('newrelic');
  } catch (err) {
    console.warn('New Relic could not be loaded:', err.message);
  }
}

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const swaggerUi = require('swagger-ui-express');
const swaggerSpec = require('./config/swagger');
const { errorHandler, notFoundHandler } = require('./middleware/errorHandler');

// Route handlers
const healthRoutes = require('./routes/health');
const propertyRoutes = require('./routes/properties');
const technicianRoutes = require('./routes/technicians');
const workOrderRoutes = require('./routes/workOrders');
const routeRoutes = require('./routes/routes');
const optimizationRoutes = require('./routes/optimization');

const app = express();

// ---------------------------------------------------------------------------
// Security middleware
// ---------------------------------------------------------------------------
app.use(helmet({
  contentSecurityPolicy: config.server.isProduction ? undefined : false,
}));

// ---------------------------------------------------------------------------
// CORS
// ---------------------------------------------------------------------------
app.use(cors({
  origin: config.cors.origin,
  credentials: config.cors.credentials,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-ID'],
}));

// ---------------------------------------------------------------------------
// Compression
// ---------------------------------------------------------------------------
app.use(compression());

// ---------------------------------------------------------------------------
// Request parsing
// ---------------------------------------------------------------------------
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ---------------------------------------------------------------------------
// Request logging
// ---------------------------------------------------------------------------
if (!config.server.isTest) {
  app.use(morgan(config.server.isProduction ? 'combined' : 'dev'));
}

// ---------------------------------------------------------------------------
// Rate limiting
// ---------------------------------------------------------------------------
if (config.server.isProduction) {
  const limiter = rateLimit({
    windowMs: config.rateLimit.windowMs,
    max: config.rateLimit.max,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
      error: {
        code: 'RATE_LIMIT_EXCEEDED',
        message: 'Too many requests, please try again later',
        details: [],
      },
    },
  });
  app.use('/api/', limiter);
}

// ---------------------------------------------------------------------------
// Swagger UI - API documentation
// ---------------------------------------------------------------------------
app.use(
  '/api-docs',
  swaggerUi.serve,
  swaggerUi.setup(swaggerSpec, {
    explorer: true,
    customSiteTitle: 'Route Optimization API Docs',
    swaggerOptions: {
      persistAuthorization: true,
    },
  })
);

// Expose raw OpenAPI spec as JSON
app.get('/api-docs.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(swaggerSpec);
});

// ---------------------------------------------------------------------------
// Mount routes
// ---------------------------------------------------------------------------
app.use('/health', healthRoutes);
app.use('/api/properties', propertyRoutes);
app.use('/api/technicians', technicianRoutes);
app.use('/api/work-orders', workOrderRoutes);
app.use('/api/routes', routeRoutes);
app.use('/api/optimization', optimizationRoutes);

// ---------------------------------------------------------------------------
// 404 handler - must be after all routes
// ---------------------------------------------------------------------------
app.use(notFoundHandler);

// ---------------------------------------------------------------------------
// Global error handler - must be last middleware
// ---------------------------------------------------------------------------
app.use(errorHandler);

module.exports = app;
