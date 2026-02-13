/**
 * Optimization Service
 * Orchestrates route optimization runs by coordinating between MongoDB data,
 * the Python optimization engine, and result persistence.
 */

const { spawn } = require('child_process');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const logger = require('winston');

const config = require('../config');
const OptimizationRun = require('../models/OptimizationRun');
const WorkOrder = require('../models/WorkOrder');
const Technician = require('../models/Technician');
const Route = require('../models/Route');

/**
 * Run the Python optimization engine as a child process.
 * Sends input data via stdin as JSON and receives results via stdout.
 *
 * @param {object} inputData - Data to send to the Python script
 * @param {string} algorithm - Algorithm to use (vrp, greedy, genetic)
 * @param {number} maxTimeSeconds - Maximum computation time
 * @returns {Promise<object>} Parsed optimization results
 */
function executePythonOptimizer(inputData, algorithm, maxTimeSeconds) {
  return new Promise((resolve, reject) => {
    const scriptPath = path.resolve(config.optimization.scriptPath);
    const args = [
      scriptPath,
      '--algorithm', algorithm,
      '--max-time', String(maxTimeSeconds),
    ];

    logger.info('Spawning Python optimization engine', {
      script: scriptPath,
      algorithm,
      maxTimeSeconds,
    });

    const pythonProcess = spawn(config.optimization.pythonPath, args, {
      cwd: path.resolve('.'),
      env: { ...process.env },
    });

    let stdout = '';
    let stderr = '';

    pythonProcess.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    pythonProcess.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    pythonProcess.on('close', (code) => {
      if (code !== 0) {
        logger.error('Python optimization engine failed', {
          exitCode: code,
          stderr: stderr.substring(0, 2000),
        });
        return reject(
          new Error(`Optimization engine exited with code ${code}: ${stderr.substring(0, 500)}`)
        );
      }

      try {
        const results = JSON.parse(stdout);
        resolve(results);
      } catch (parseErr) {
        logger.error('Failed to parse optimization results', {
          error: parseErr.message,
          stdout: stdout.substring(0, 500),
        });
        reject(new Error('Failed to parse optimization engine output'));
      }
    });

    pythonProcess.on('error', (err) => {
      logger.error('Failed to spawn Python process', { error: err.message });
      reject(new Error(`Failed to start optimization engine: ${err.message}`));
    });

    // Send input data to the Python process via stdin
    const inputJson = JSON.stringify(inputData);
    pythonProcess.stdin.write(inputJson);
    pythonProcess.stdin.end();

    // Set a timeout to kill the process if it runs too long
    const timeout = setTimeout(() => {
      pythonProcess.kill('SIGTERM');
      reject(new Error(`Optimization engine timed out after ${maxTimeSeconds} seconds`));
    }, (maxTimeSeconds + 30) * 1000); // Add 30s buffer

    pythonProcess.on('close', () => {
      clearTimeout(timeout);
    });
  });
}

/**
 * Create Route records in MongoDB from optimization results.
 *
 * @param {object} optimizationResult - Results from the Python engine
 * @param {string} optimizationRunId - The OptimizationRun document ID
 * @param {Date} routeDate - Date for the routes
 * @param {string} algorithm - Algorithm that produced the results
 * @returns {Promise<Array>} Created Route documents
 */
async function createRoutesFromResults(optimizationResult, optimizationRunId, routeDate, algorithm) {
  const routes = [];

  if (!optimizationResult.routes || !Array.isArray(optimizationResult.routes)) {
    logger.warn('No routes in optimization result');
    return routes;
  }

  for (const routeData of optimizationResult.routes) {
    try {
      const route = new Route({
        routeId: `ROUTE-${uuidv4().substring(0, 8).toUpperCase()}`,
        optimizationRunId,
        technicianId: routeData.technicianId,
        technicianName: routeData.technicianName || 'Unknown',
        routeDate,
        algorithmUsed: algorithm,
        status: 'planned',
        stops: routeData.stops || [],
        summary: routeData.summary || {
          totalDistanceMiles: 0,
          totalDurationMinutes: 0,
          totalWorkMinutes: 0,
          totalTravelMinutes: 0,
          numStops: 0,
          utilizationPercent: 0,
        },
        routeGeometry: routeData.routeGeometry || null,
      });

      const savedRoute = await route.save();
      routes.push(savedRoute);

      // Update work orders as assigned
      if (routeData.stops && Array.isArray(routeData.stops)) {
        const workOrderIds = routeData.stops.map((stop) => stop.workOrderId).filter(Boolean);
        if (workOrderIds.length > 0) {
          await WorkOrder.updateMany(
            { _id: { $in: workOrderIds } },
            {
              $set: {
                status: 'assigned',
                assignedTechnicianId: routeData.technicianId,
                assignedRouteId: savedRoute._id,
              },
            }
          );
        }
      }
    } catch (routeErr) {
      logger.error('Failed to create route from optimization result', {
        error: routeErr.message,
        technicianId: routeData.technicianId,
      });
    }
  }

  return routes;
}

/**
 * Run a full optimization cycle.
 *
 * Steps:
 * 1. Create an OptimizationRun record with status 'running'
 * 2. Fetch pending work orders and available technicians from MongoDB
 * 3. Call the Python optimization engine via child_process.spawn
 * 4. Parse results and create Route records in MongoDB
 * 5. Update the OptimizationRun with results summary
 * 6. Handle errors and update status to 'failed' if needed
 *
 * @param {object} optimizationConfig - Configuration for the optimization run
 * @param {string} optimizationConfig.date - Target date for optimization (ISO string)
 * @param {string} [optimizationConfig.algorithm] - Algorithm to use
 * @param {object} [optimizationConfig.config] - Additional config parameters
 * @param {string} [optimizationConfig.triggeredBy] - Who triggered the run
 * @returns {Promise<object>} The completed OptimizationRun document
 */
async function runOptimization(optimizationConfig) {
  const {
    date,
    algorithm = config.optimization.defaultAlgorithm,
    config: runConfig = {},
    triggeredBy = 'system',
  } = optimizationConfig;

  const optimizationDate = new Date(date);
  const maxTimeSeconds = runConfig.maxTimeSeconds || config.optimization.maxTimeSeconds;

  // Step 1: Create OptimizationRun record
  const run = new OptimizationRun({
    runId: `RUN-${uuidv4().substring(0, 8).toUpperCase()}`,
    status: 'running',
    algorithm,
    optimizationDate,
    config: {
      maxTimeSeconds,
      maxDistanceMiles: runConfig.maxDistanceMiles,
      maxStopsPerRoute: runConfig.maxStopsPerRoute,
      balanceWorkload: runConfig.balanceWorkload !== undefined ? runConfig.balanceWorkload : true,
    },
    startedAt: new Date(),
    triggeredBy,
  });

  await run.save();

  logger.info('Optimization run started', {
    runId: run.runId,
    algorithm,
    date: optimizationDate.toISOString(),
  });

  try {
    // Step 2: Fetch work orders and technicians
    const workOrders = await WorkOrder.find({
      status: 'pending',
      $or: [
        { timeWindowStart: { $lte: new Date(optimizationDate.getTime() + 24 * 60 * 60 * 1000) } },
        { timeWindowStart: null },
      ],
    }).populate('propertyId');

    const technicians = await Technician.find({
      availabilityStatus: 'available',
    });

    logger.info('Fetched optimization input data', {
      runId: run.runId,
      workOrderCount: workOrders.length,
      technicianCount: technicians.length,
    });

    // Update input counts
    run.input = {
      workOrderCount: workOrders.length,
      technicianCount: technicians.length,
    };
    await run.save();

    if (workOrders.length === 0) {
      await run.markCompleted({
        routesCreated: 0,
        workOrdersAssigned: 0,
        workOrdersUnassigned: 0,
        results: [],
      });
      logger.info('No pending work orders found, optimization skipped', { runId: run.runId });
      return run;
    }

    if (technicians.length === 0) {
      await run.markFailed(new Error('No available technicians found'));
      return run;
    }

    // Step 3: Prepare input and call Python engine
    const inputData = {
      workOrders: workOrders.map((wo) => ({
        id: wo._id.toString(),
        workOrderId: wo.workOrderId,
        title: wo.title,
        category: wo.category,
        priority: wo.priority,
        priorityWeight: wo.priorityWeight,
        estimatedDurationMinutes: wo.estimatedDurationMinutes,
        requiredSkills: wo.requiredSkills,
        coordinates: wo.property.location.coordinates,
        address: wo.property.address,
        timeWindowStart: wo.timeWindowStart ? wo.timeWindowStart.toISOString() : null,
        timeWindowEnd: wo.timeWindowEnd ? wo.timeWindowEnd.toISOString() : null,
      })),
      technicians: technicians.map((tech) => ({
        id: tech._id.toString(),
        technicianId: tech.technicianId,
        name: tech.name,
        skills: tech.skills,
        homeBaseCoordinates: tech.homeBase.coordinates,
        maxDailyHours: tech.maxDailyHours,
        maxDailyDistanceMiles: tech.maxDailyDistanceMiles,
        hourlyRate: tech.hourlyRate,
        zonePreference: tech.zonePreference,
      })),
      config: {
        algorithm,
        maxTimeSeconds,
        maxDistanceMiles: runConfig.maxDistanceMiles,
        maxStopsPerRoute: runConfig.maxStopsPerRoute,
        balanceWorkload: runConfig.balanceWorkload,
        optimizationDate: optimizationDate.toISOString(),
      },
    };

    const optimizationResult = await executePythonOptimizer(inputData, algorithm, maxTimeSeconds);

    // Step 4: Create Route records from results
    const createdRoutes = await createRoutesFromResults(
      optimizationResult,
      run._id,
      optimizationDate,
      algorithm
    );

    // Step 5: Update OptimizationRun with results
    const assignedCount = createdRoutes.reduce(
      (sum, route) => sum + (route.stops ? route.stops.length : 0),
      0
    );
    const unassignedCount = workOrders.length - assignedCount;

    const resultSummary = {
      algorithm,
      totalDistanceMiles: createdRoutes.reduce(
        (sum, r) => sum + (r.summary ? r.summary.totalDistanceMiles : 0),
        0
      ),
      totalDurationMinutes: createdRoutes.reduce(
        (sum, r) => sum + (r.summary ? r.summary.totalDurationMinutes : 0),
        0
      ),
      totalRoutes: createdRoutes.length,
      unassignedWorkOrders: unassignedCount,
      avgUtilizationPercent:
        createdRoutes.length > 0
          ? createdRoutes.reduce(
              (sum, r) => sum + (r.summary ? r.summary.utilizationPercent : 0),
              0
            ) / createdRoutes.length
          : 0,
      computeTimeMs: optimizationResult.computeTimeMs || 0,
    };

    await run.markCompleted({
      routesCreated: createdRoutes.length,
      workOrdersAssigned: assignedCount,
      workOrdersUnassigned: unassignedCount,
      results: [resultSummary],
    });

    logger.info('Optimization run completed', {
      runId: run.runId,
      routesCreated: createdRoutes.length,
      workOrdersAssigned: assignedCount,
      workOrdersUnassigned: unassignedCount,
    });

    return run;
  } catch (err) {
    logger.error('Optimization run failed', {
      runId: run.runId,
      error: err.message,
      stack: err.stack,
    });
    await run.markFailed(err);
    return run;
  }
}

/**
 * Get the current status of an optimization run.
 *
 * @param {string} runId - The run ID (runId field, not MongoDB _id)
 * @returns {Promise<object|null>} The OptimizationRun document or null
 */
async function getOptimizationStatus(runId) {
  const run = await OptimizationRun.findOne({ runId });
  return run;
}

/**
 * Compare all algorithms by running each one and returning comparative results.
 * This creates separate optimization runs for each algorithm.
 *
 * @param {string} date - Target date for optimization (ISO string)
 * @param {object} [runConfig] - Additional configuration
 * @returns {Promise<object>} Comparison results for all algorithms
 */
async function compareAlgorithms(date, runConfig = {}) {
  const algorithms = ['vrp', 'greedy', 'genetic'];
  const comparisonResults = {
    date,
    startedAt: new Date().toISOString(),
    algorithms: {},
    summary: {},
  };

  logger.info('Starting algorithm comparison', { date, algorithms });

  const runPromises = algorithms.map(async (algorithm) => {
    try {
      const result = await runOptimization({
        date,
        algorithm,
        config: runConfig,
        triggeredBy: 'comparison',
      });
      return { algorithm, result, success: true };
    } catch (err) {
      logger.error(`Algorithm ${algorithm} comparison failed`, { error: err.message });
      return { algorithm, error: err.message, success: false };
    }
  });

  const results = await Promise.allSettled(runPromises);

  for (const settledResult of results) {
    const { algorithm, result, error, success } =
      settledResult.status === 'fulfilled' ? settledResult.value : settledResult.reason;

    if (success && result) {
      comparisonResults.algorithms[algorithm] = {
        status: result.status,
        routesCreated: result.routesCreated,
        workOrdersAssigned: result.workOrdersAssigned,
        workOrdersUnassigned: result.workOrdersUnassigned,
        durationMs: result.durationMs,
        results: result.results,
      };
    } else {
      comparisonResults.algorithms[algorithm] = {
        status: 'failed',
        error: error || 'Unknown error',
      };
    }
  }

  // Build summary: find best algorithm by different metrics
  const completedAlgorithms = Object.entries(comparisonResults.algorithms)
    .filter(([, data]) => data.status === 'completed')
    .map(([name, data]) => ({ name, ...data }));

  if (completedAlgorithms.length > 0) {
    comparisonResults.summary = {
      bestByAssignment: completedAlgorithms.reduce((best, curr) =>
        curr.workOrdersAssigned > best.workOrdersAssigned ? curr : best
      ).name,
      bestBySpeed: completedAlgorithms.reduce((best, curr) =>
        curr.durationMs < best.durationMs ? curr : best
      ).name,
      bestByDistance: completedAlgorithms.reduce((best, curr) => {
        const currDist =
          curr.results && curr.results[0] ? curr.results[0].totalDistanceMiles : Infinity;
        const bestDist =
          best.results && best.results[0] ? best.results[0].totalDistanceMiles : Infinity;
        return currDist < bestDist ? curr : best;
      }).name,
    };
  }

  comparisonResults.completedAt = new Date().toISOString();

  logger.info('Algorithm comparison completed', {
    algorithms: Object.keys(comparisonResults.algorithms),
    summary: comparisonResults.summary,
  });

  return comparisonResults;
}

module.exports = {
  runOptimization,
  getOptimizationStatus,
  compareAlgorithms,
};
