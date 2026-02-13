/**
 * Route Management Endpoints
 * CRUD operations for optimized routes assigned to technicians.
 */

const express = require('express');
const Route = require('../models/Route');
const { validatePagination, validateObjectId, validateDateParam } = require('../middleware/validators');

const router = express.Router();

/**
 * @swagger
 * /api/routes:
 *   get:
 *     summary: List routes
 *     description: Retrieve a paginated list of routes with optional filtering by date, technician, and algorithm.
 *     tags: [Routes]
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
 *         name: technicianId
 *         schema:
 *           type: string
 *         description: Filter by technician MongoDB ObjectId
 *       - in: query
 *         name: algorithmUsed
 *         schema:
 *           type: string
 *           enum: [vrp, greedy, genetic]
 *         description: Filter by optimization algorithm
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [planned, active, completed]
 *         description: Filter by route status
 *       - in: query
 *         name: date
 *         schema:
 *           type: string
 *           format: date
 *         description: Filter by route date (ISO 8601)
 *     responses:
 *       200:
 *         description: Paginated list of routes
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Route'
 *                 meta:
 *                   $ref: '#/components/schemas/PaginationMeta'
 */
router.get('/', validatePagination, async (req, res, next) => {
  try {
    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 20;
    const skip = (page - 1) * limit;

    // Build filter
    const filter = {};
    if (req.query.technicianId) filter.technicianId = req.query.technicianId;
    if (req.query.algorithmUsed) filter.algorithmUsed = req.query.algorithmUsed;
    if (req.query.status) filter.status = req.query.status;

    // Date filter
    if (req.query.date) {
      const startOfDay = new Date(req.query.date);
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date(req.query.date);
      endOfDay.setHours(23, 59, 59, 999);
      filter.routeDate = { $gte: startOfDay, $lte: endOfDay };
    }

    const [routes, total] = await Promise.all([
      Route.find(filter)
        .populate('technicianId', 'technicianId name skills availabilityStatus')
        .sort({ routeDate: -1, createdAt: -1 })
        .skip(skip)
        .limit(limit),
      Route.countDocuments(filter),
    ]);

    res.json({
      data: routes,
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
 * /api/routes/date/{date}:
 *   get:
 *     summary: Get routes by date
 *     description: Retrieve all routes for a specific date with full stop details.
 *     tags: [Routes]
 *     parameters:
 *       - in: path
 *         name: date
 *         required: true
 *         schema:
 *           type: string
 *           format: date
 *         description: Date in ISO 8601 format (YYYY-MM-DD)
 *     responses:
 *       200:
 *         description: List of routes for the specified date
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Route'
 *                 meta:
 *                   type: object
 *                   properties:
 *                     date:
 *                       type: string
 *                       format: date
 *                     count:
 *                       type: integer
 *                     totalStops:
 *                       type: integer
 *                     totalDistanceMiles:
 *                       type: number
 */
router.get('/date/:date', validateDateParam, async (req, res, next) => {
  try {
    const routes = await Route.findByDate(req.params.date)
      .populate('technicianId', 'technicianId name skills homeBase')
      .populate('stops.workOrderId', 'workOrderId title category priority')
      .populate('stops.propertyId', 'propertyId address city state zipCode');

    const totalStops = routes.reduce((sum, r) => sum + (r.stops ? r.stops.length : 0), 0);
    const totalDistanceMiles = routes.reduce(
      (sum, r) => sum + (r.summary ? r.summary.totalDistanceMiles : 0),
      0
    );

    res.json({
      data: routes,
      meta: {
        date: req.params.date,
        count: routes.length,
        totalStops,
        totalDistanceMiles: Math.round(totalDistanceMiles * 100) / 100,
      },
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @swagger
 * /api/routes/{id}:
 *   get:
 *     summary: Get route by ID
 *     description: Retrieve a single route with fully populated stop details.
 *     tags: [Routes]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: MongoDB ObjectId
 *     responses:
 *       200:
 *         description: Route details with populated stops
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/Route'
 *       404:
 *         description: Route not found
 */
router.get('/:id', validateObjectId, async (req, res, next) => {
  try {
    const route = await Route.findById(req.params.id)
      .populate('technicianId')
      .populate('optimizationRunId', 'runId algorithm status')
      .populate('stops.workOrderId')
      .populate('stops.propertyId');

    if (!route) {
      return res.status(404).json({
        error: {
          code: 'NOT_FOUND',
          message: 'Route not found',
          details: [],
        },
      });
    }

    res.json({ data: route });
  } catch (err) {
    next(err);
  }
});

/**
 * @swagger
 * /api/routes/{id}/directions:
 *   get:
 *     summary: Get route directions
 *     description: Get route geometry (LineString) and ordered stop coordinates for map display.
 *     tags: [Routes]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: MongoDB ObjectId
 *     responses:
 *       200:
 *         description: Route geometry and waypoints
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: object
 *                   properties:
 *                     routeId:
 *                       type: string
 *                     routeGeometry:
 *                       type: object
 *                       description: GeoJSON LineString
 *                     waypoints:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           sequence:
 *                             type: integer
 *                           coordinates:
 *                             type: array
 *                             items:
 *                               type: number
 *                           workOrderTitle:
 *                             type: string
 *                           arrivalTime:
 *                             type: string
 *                             format: date-time
 *       404:
 *         description: Route not found
 */
router.get('/:id/directions', async (req, res, next) => {
  try {
    const route = await Route.findById(req.params.id)
      .select('routeId routeGeometry stops technicianName summary');

    if (!route) {
      return res.status(404).json({
        error: {
          code: 'NOT_FOUND',
          message: 'Route not found',
          details: [],
        },
      });
    }

    // Build waypoints from stops
    const waypoints = (route.stops || []).map((stop) => ({
      sequence: stop.sequence,
      coordinates: stop.location.coordinates,
      workOrderTitle: stop.workOrder.title,
      category: stop.workOrder.category,
      priority: stop.workOrder.priority,
      arrivalTime: stop.arrivalTime,
      departureTime: stop.departureTime,
      travelDistanceMiles: stop.travelDistanceMiles,
      travelDurationMinutes: stop.travelDurationMinutes,
      estimatedDurationMinutes: stop.workOrder.estimatedDurationMinutes,
    }));

    res.json({
      data: {
        routeId: route.routeId,
        technicianName: route.technicianName,
        summary: route.summary,
        routeGeometry: route.routeGeometry || null,
        waypoints,
      },
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @swagger
 * /api/routes/{id}:
 *   delete:
 *     summary: Delete a route
 *     description: >
 *       Delete a route and reset the assigned work orders back to pending status.
 *       Only planned routes can be deleted.
 *     tags: [Routes]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: MongoDB ObjectId
 *     responses:
 *       200:
 *         description: Route deleted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 data:
 *                   type: object
 *                   properties:
 *                     routeId:
 *                       type: string
 *                     workOrdersReset:
 *                       type: integer
 *       400:
 *         description: Cannot delete active or completed routes
 *       404:
 *         description: Route not found
 */
router.delete('/:id', validateObjectId, async (req, res, next) => {
  try {
    const route = await Route.findById(req.params.id);

    if (!route) {
      return res.status(404).json({
        error: {
          code: 'NOT_FOUND',
          message: 'Route not found',
          details: [],
        },
      });
    }

    if (route.status !== 'planned') {
      return res.status(400).json({
        error: {
          code: 'INVALID_OPERATION',
          message: `Cannot delete a route with status '${route.status}'. Only planned routes can be deleted.`,
          details: [],
        },
      });
    }

    // Reset associated work orders back to pending
    const workOrderIds = (route.stops || [])
      .map((stop) => stop.workOrderId)
      .filter(Boolean);

    let workOrdersReset = 0;
    if (workOrderIds.length > 0) {
      const WorkOrder = require('../models/WorkOrder');
      const result = await WorkOrder.updateMany(
        { _id: { $in: workOrderIds }, assignedRouteId: route._id },
        {
          $set: { status: 'pending' },
          $unset: { assignedTechnicianId: '', assignedRouteId: '' },
        }
      );
      workOrdersReset = result.modifiedCount;
    }

    await Route.findByIdAndDelete(req.params.id);

    res.json({
      message: 'Route deleted successfully',
      data: {
        routeId: route.routeId,
        workOrdersReset,
      },
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
