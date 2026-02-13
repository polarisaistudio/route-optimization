/**
 * Optimization Routes
 * Endpoints for triggering optimization runs, checking status, and comparing algorithms.
 */

const express = require('express');
const OptimizationRun = require('../models/OptimizationRun');
const optimizationService = require('../services/optimizationService');
const {
  validateOptimizationRequest,
  validatePagination,
} = require('../middleware/validators');

const router = express.Router();

/**
 * @swagger
 * /api/optimization/run:
 *   post:
 *     summary: Trigger optimization run
 *     description: >
 *       Start a new route optimization run. The run executes asynchronously.
 *       Use the status endpoint to monitor progress.
 *     tags: [Optimization]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - date
 *             properties:
 *               date:
 *                 type: string
 *                 format: date
 *                 description: Target date for optimization
 *                 example: '2026-02-15'
 *               algorithm:
 *                 type: string
 *                 enum: [vrp, greedy, genetic, all]
 *                 default: vrp
 *                 description: Optimization algorithm to use
 *               config:
 *                 type: object
 *                 properties:
 *                   maxTimeSeconds:
 *                     type: integer
 *                     description: Max computation time
 *                     example: 300
 *                   maxDistanceMiles:
 *                     type: number
 *                     description: Max route distance per technician
 *                   maxStopsPerRoute:
 *                     type: integer
 *                     description: Max stops per route
 *                   balanceWorkload:
 *                     type: boolean
 *                     description: Whether to balance workload across technicians
 *     responses:
 *       202:
 *         description: Optimization run started
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 data:
 *                   $ref: '#/components/schemas/OptimizationRun'
 *       400:
 *         description: Validation error
 *       500:
 *         description: Failed to start optimization
 */
router.post('/run', validateOptimizationRequest, async (req, res, next) => {
  try {
    const { date, algorithm, config: runConfig } = req.body;
    const triggeredBy = req.user ? req.user.id : 'api';

    // Start the optimization run asynchronously
    const run = await optimizationService.runOptimization({
      date,
      algorithm,
      config: runConfig,
      triggeredBy,
    });

    // Return immediately with the run info (status may still be 'running')
    res.status(202).json({
      message: 'Optimization run initiated',
      data: run,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @swagger
 * /api/optimization/status/{runId}:
 *   get:
 *     summary: Check optimization run status
 *     description: Get the current status and results of an optimization run.
 *     tags: [Optimization]
 *     parameters:
 *       - in: path
 *         name: runId
 *         required: true
 *         schema:
 *           type: string
 *         description: The optimization run ID (e.g., RUN-A1B2C3D4)
 *     responses:
 *       200:
 *         description: Optimization run status
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/OptimizationRun'
 *       404:
 *         description: Optimization run not found
 */
router.get('/status/:runId', async (req, res, next) => {
  try {
    const run = await optimizationService.getOptimizationStatus(req.params.runId);

    if (!run) {
      return res.status(404).json({
        error: {
          code: 'NOT_FOUND',
          message: 'Optimization run not found',
          details: [],
        },
      });
    }

    res.json({ data: run });
  } catch (err) {
    next(err);
  }
});

/**
 * @swagger
 * /api/optimization/history:
 *   get:
 *     summary: List optimization run history
 *     description: Retrieve a paginated list of past optimization runs, ordered by most recent first.
 *     tags: [Optimization]
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *         description: Page number
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 20
 *         description: Items per page
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [pending, running, completed, failed]
 *         description: Filter by run status
 *       - in: query
 *         name: algorithm
 *         schema:
 *           type: string
 *           enum: [vrp, greedy, genetic, all]
 *         description: Filter by algorithm
 *     responses:
 *       200:
 *         description: Paginated list of optimization runs
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/OptimizationRun'
 *                 meta:
 *                   $ref: '#/components/schemas/PaginationMeta'
 */
router.get('/history', validatePagination, async (req, res, next) => {
  try {
    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 20;
    const skip = (page - 1) * limit;

    // Build filter
    const filter = {};
    if (req.query.status) filter.status = req.query.status;
    if (req.query.algorithm) filter.algorithm = req.query.algorithm;

    const [runs, total] = await Promise.all([
      OptimizationRun.find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit),
      OptimizationRun.countDocuments(filter),
    ]);

    res.json({
      data: runs,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @swagger
 * /api/optimization/compare:
 *   post:
 *     summary: Compare optimization algorithms
 *     description: >
 *       Run all available algorithms (vrp, greedy, genetic) on the same dataset
 *       and return a comparative analysis of the results.
 *     tags: [Optimization]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - date
 *             properties:
 *               date:
 *                 type: string
 *                 format: date
 *                 description: Target date for optimization
 *                 example: '2026-02-15'
 *               config:
 *                 type: object
 *                 properties:
 *                   maxTimeSeconds:
 *                     type: integer
 *                   maxDistanceMiles:
 *                     type: number
 *                   maxStopsPerRoute:
 *                     type: integer
 *     responses:
 *       200:
 *         description: Algorithm comparison results
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: object
 *                   properties:
 *                     date:
 *                       type: string
 *                     algorithms:
 *                       type: object
 *                     summary:
 *                       type: object
 *                       properties:
 *                         bestByAssignment:
 *                           type: string
 *                         bestBySpeed:
 *                           type: string
 *                         bestByDistance:
 *                           type: string
 *       400:
 *         description: Validation error
 */
router.post('/compare', async (req, res, next) => {
  try {
    const { date, config: runConfig } = req.body;

    if (!date) {
      return res.status(400).json({
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Date is required for algorithm comparison',
          details: [],
        },
      });
    }

    const comparison = await optimizationService.compareAlgorithms(date, runConfig);

    res.json({ data: comparison });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
