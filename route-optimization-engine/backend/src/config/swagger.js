/**
 * Swagger/OpenAPI 3.0 Configuration
 * Generates API documentation from JSDoc annotations on route handlers.
 */

const swaggerJsdoc = require('swagger-jsdoc');

const swaggerDefinition = {
  openapi: '3.0.0',
  info: {
    title: 'Route Optimization Engine API',
    version: '1.0.0',
    description:
      'REST API for the Route Optimization Engine for Field Service Operations. ' +
      'Provides endpoints for managing properties, technicians, work orders, routes, ' +
      'and triggering optimization runs.',
    contact: {
      name: 'Polaris Engineering',
      email: 'engineering@polaris.com',
    },
    license: {
      name: 'Proprietary',
    },
  },
  servers: [
    {
      url: 'http://localhost:3001',
      description: 'Development server',
    },
    {
      url: 'https://api.polaris.com',
      description: 'Production server',
    },
  ],
  components: {
    securitySchemes: {
      BearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        description: 'Enter your JWT token in the format: Bearer <token>',
      },
    },
    schemas: {
      Error: {
        type: 'object',
        properties: {
          error: {
            type: 'object',
            properties: {
              code: { type: 'string' },
              message: { type: 'string' },
              details: { type: 'array', items: { type: 'object' } },
            },
          },
        },
      },
      PaginationMeta: {
        type: 'object',
        properties: {
          page: { type: 'integer' },
          limit: { type: 'integer' },
          total: { type: 'integer' },
          totalPages: { type: 'integer' },
        },
      },
      Property: {
        type: 'object',
        required: ['propertyId', 'address', 'city', 'state', 'zipCode', 'location', 'propertyType'],
        properties: {
          propertyId: { type: 'string', example: 'PROP-001' },
          address: { type: 'string', example: '123 Main St' },
          city: { type: 'string', example: 'Austin' },
          state: { type: 'string', example: 'TX', maxLength: 2 },
          zipCode: { type: 'string', example: '78701' },
          location: {
            type: 'object',
            properties: {
              type: { type: 'string', enum: ['Point'] },
              coordinates: {
                type: 'array',
                items: { type: 'number' },
                example: [-97.7431, 30.2672],
              },
            },
          },
          propertyType: {
            type: 'string',
            enum: ['residential', 'commercial', 'industrial'],
          },
          zoneId: { type: 'string', example: 'ZONE-A' },
          squareFootage: { type: 'number', example: 2500 },
          accessNotes: { type: 'string' },
        },
      },
      Technician: {
        type: 'object',
        required: ['technicianId', 'name', 'email', 'phone', 'homeBase', 'skills'],
        properties: {
          technicianId: { type: 'string', example: 'TECH-001' },
          name: { type: 'string', example: 'John Smith' },
          email: { type: 'string', example: 'john.smith@polaris.com' },
          phone: { type: 'string', example: '512-555-0123' },
          homeBase: {
            type: 'object',
            properties: {
              type: { type: 'string', enum: ['Point'] },
              coordinates: {
                type: 'array',
                items: { type: 'number' },
                example: [-97.7431, 30.2672],
              },
            },
          },
          skills: {
            type: 'array',
            items: {
              type: 'string',
              enum: ['hvac', 'plumbing', 'electrical', 'general', 'inspection'],
            },
          },
          maxDailyHours: { type: 'number', example: 8 },
          maxDailyDistanceMiles: { type: 'number', example: 150 },
          hourlyRate: { type: 'number', example: 45.0 },
          availabilityStatus: {
            type: 'string',
            enum: ['available', 'on_route', 'off_duty', 'on_leave'],
          },
        },
      },
      WorkOrder: {
        type: 'object',
        required: ['workOrderId', 'propertyId', 'title', 'category', 'priority', 'estimatedDurationMinutes'],
        properties: {
          workOrderId: { type: 'string', example: 'WO-001' },
          propertyId: { type: 'string', description: 'MongoDB ObjectId of the property' },
          title: { type: 'string', example: 'HVAC Maintenance' },
          description: { type: 'string' },
          category: {
            type: 'string',
            enum: ['hvac', 'plumbing', 'electrical', 'general', 'inspection'],
          },
          priority: {
            type: 'string',
            enum: ['emergency', 'high', 'medium', 'low'],
          },
          estimatedDurationMinutes: { type: 'number', example: 60 },
          status: {
            type: 'string',
            enum: ['pending', 'assigned', 'in_progress', 'completed', 'cancelled'],
          },
        },
      },
      Route: {
        type: 'object',
        properties: {
          routeId: { type: 'string', example: 'ROUTE-001' },
          technicianId: { type: 'string' },
          technicianName: { type: 'string' },
          routeDate: { type: 'string', format: 'date' },
          algorithmUsed: { type: 'string', enum: ['vrp', 'greedy', 'genetic'] },
          status: { type: 'string', enum: ['planned', 'active', 'completed'] },
          stops: { type: 'array', items: { type: 'object' } },
          summary: { $ref: '#/components/schemas/RouteSummary' },
        },
      },
      RouteSummary: {
        type: 'object',
        properties: {
          totalDistanceMiles: { type: 'number' },
          totalDurationMinutes: { type: 'number' },
          totalWorkMinutes: { type: 'number' },
          totalTravelMinutes: { type: 'number' },
          numStops: { type: 'integer' },
          utilizationPercent: { type: 'number' },
        },
      },
      OptimizationRun: {
        type: 'object',
        properties: {
          runId: { type: 'string' },
          status: { type: 'string', enum: ['pending', 'running', 'completed', 'failed'] },
          algorithm: { type: 'string', enum: ['vrp', 'greedy', 'genetic', 'all'] },
          optimizationDate: { type: 'string', format: 'date' },
          routesCreated: { type: 'integer' },
          workOrdersAssigned: { type: 'integer' },
          durationMs: { type: 'number' },
        },
      },
    },
  },
  security: [
    {
      BearerAuth: [],
    },
  ],
  tags: [
    { name: 'Health', description: 'Health check endpoints' },
    { name: 'Properties', description: 'Property management endpoints' },
    { name: 'Technicians', description: 'Technician management endpoints' },
    { name: 'Work Orders', description: 'Work order management endpoints' },
    { name: 'Routes', description: 'Route management endpoints' },
    { name: 'Optimization', description: 'Optimization engine endpoints' },
  ],
};

const options = {
  swaggerDefinition,
  apis: ['./src/routes/*.js'],
};

const swaggerSpec = swaggerJsdoc(options);

module.exports = swaggerSpec;
