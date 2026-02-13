/**
 * Health Check Routes
 * Provides liveness and readiness probes for monitoring and orchestration.
 */

const express = require('express');
const mongoose = require('mongoose');

const router = express.Router();

/**
 * @swagger
 * /health:
 *   get:
 *     summary: Basic health check
 *     description: Returns service status, uptime, and current timestamp. Used for liveness probes.
 *     tags: [Health]
 *     security: []
 *     responses:
 *       200:
 *         description: Service is running
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   example: ok
 *                 uptime:
 *                   type: number
 *                   description: Process uptime in seconds
 *                   example: 12345.678
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 *                 environment:
 *                   type: string
 *                   example: development
 *                 version:
 *                   type: string
 *                   example: 1.0.0
 */
router.get('/', (req, res) => {
  res.status(200).json({
    status: 'ok',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development',
    version: '1.0.0',
  });
});

/**
 * @swagger
 * /health/ready:
 *   get:
 *     summary: Readiness check
 *     description: >
 *       Verifies that the service is ready to accept traffic by checking
 *       connectivity to dependent services (MongoDB). Used for readiness probes.
 *     tags: [Health]
 *     security: []
 *     responses:
 *       200:
 *         description: Service is ready
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   example: ready
 *                 checks:
 *                   type: object
 *                   properties:
 *                     mongodb:
 *                       type: object
 *                       properties:
 *                         status:
 *                           type: string
 *                           example: connected
 *                         responseTimeMs:
 *                           type: number
 *       503:
 *         description: Service is not ready
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   example: not_ready
 *                 checks:
 *                   type: object
 */
router.get('/ready', async (req, res) => {
  const checks = {};
  let overallStatus = 'ready';

  // Check MongoDB connection
  try {
    const mongoStart = Date.now();
    const mongoState = mongoose.connection.readyState;
    // 0 = disconnected, 1 = connected, 2 = connecting, 3 = disconnecting
    const stateMap = {
      0: 'disconnected',
      1: 'connected',
      2: 'connecting',
      3: 'disconnecting',
    };

    if (mongoState === 1) {
      // Ping the database to verify actual connectivity
      await mongoose.connection.db.admin().ping();
      checks.mongodb = {
        status: 'connected',
        responseTimeMs: Date.now() - mongoStart,
      };
    } else {
      checks.mongodb = {
        status: stateMap[mongoState] || 'unknown',
        responseTimeMs: Date.now() - mongoStart,
      };
      overallStatus = 'not_ready';
    }
  } catch (err) {
    checks.mongodb = {
      status: 'error',
      error: err.message,
    };
    overallStatus = 'not_ready';
  }

  const statusCode = overallStatus === 'ready' ? 200 : 503;
  res.status(statusCode).json({
    status: overallStatus,
    timestamp: new Date().toISOString(),
    checks,
  });
});

module.exports = router;
