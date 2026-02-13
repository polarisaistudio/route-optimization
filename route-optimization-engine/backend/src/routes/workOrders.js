/**
 * Work Order Routes
 * CRUD operations, status management, and summary aggregation for work orders.
 */

const express = require('express');
const WorkOrder = require('../models/WorkOrder');
const {
  validateWorkOrder,
  validatePagination,
  validateObjectId,
} = require('../middleware/validators');

const router = express.Router();

/**
 * @swagger
 * /api/work-orders:
 *   get:
 *     summary: List work orders
 *     description: Retrieve a paginated list of work orders with optional filtering.
 *     tags: [Work Orders]
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
 *           enum: [pending, assigned, in_progress, completed, cancelled]
 *         description: Filter by status
 *       - in: query
 *         name: priority
 *         schema:
 *           type: string
 *           enum: [emergency, high, medium, low]
 *         description: Filter by priority
 *       - in: query
 *         name: category
 *         schema:
 *           type: string
 *           enum: [hvac, plumbing, electrical, general, inspection]
 *         description: Filter by category
 *       - in: query
 *         name: startDate
 *         schema:
 *           type: string
 *           format: date
 *         description: Filter by creation date start (ISO 8601)
 *       - in: query
 *         name: endDate
 *         schema:
 *           type: string
 *           format: date
 *         description: Filter by creation date end (ISO 8601)
 *       - in: query
 *         name: technicianId
 *         schema:
 *           type: string
 *         description: Filter by assigned technician ID
 *     responses:
 *       200:
 *         description: Paginated list of work orders
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/WorkOrder'
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
    if (req.query.status) filter.status = req.query.status;
    if (req.query.priority) filter.priority = req.query.priority;
    if (req.query.category) filter.category = req.query.category;
    if (req.query.technicianId) filter.assignedTechnicianId = req.query.technicianId;

    // Date range filter
    if (req.query.startDate || req.query.endDate) {
      filter.createdAt = {};
      if (req.query.startDate) filter.createdAt.$gte = new Date(req.query.startDate);
      if (req.query.endDate) filter.createdAt.$lte = new Date(req.query.endDate);
    }

    const [workOrders, total] = await Promise.all([
      WorkOrder.find(filter)
        .populate('propertyId', 'propertyId address city state zipCode')
        .populate('assignedTechnicianId', 'technicianId name')
        .sort({ priority: -1, createdAt: -1 })
        .skip(skip)
        .limit(limit),
      WorkOrder.countDocuments(filter),
    ]);

    res.json({
      data: workOrders,
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
 * /api/work-orders/summary:
 *   get:
 *     summary: Work order summary
 *     description: Get aggregated counts of work orders grouped by status and priority.
 *     tags: [Work Orders]
 *     responses:
 *       200:
 *         description: Work order summary
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: object
 *                   properties:
 *                     byStatus:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           _id:
 *                             type: string
 *                           count:
 *                             type: integer
 *                     byPriority:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           _id:
 *                             type: string
 *                           count:
 *                             type: integer
 *                     total:
 *                       type: integer
 */
router.get('/summary', async (req, res, next) => {
  try {
    const [byStatus, byPriority, totalResult] = await Promise.all([
      WorkOrder.aggregate([
        { $group: { _id: '$status', count: { $sum: 1 } } },
        { $sort: { _id: 1 } },
      ]),
      WorkOrder.aggregate([
        { $group: { _id: '$priority', count: { $sum: 1 } } },
        { $sort: { _id: 1 } },
      ]),
      WorkOrder.countDocuments(),
    ]);

    // Also group by category
    const byCategory = await WorkOrder.aggregate([
      { $group: { _id: '$category', count: { $sum: 1 } } },
      { $sort: { _id: 1 } },
    ]);

    res.json({
      data: {
        byStatus,
        byPriority,
        byCategory,
        total: totalResult,
      },
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @swagger
 * /api/work-orders/{id}:
 *   get:
 *     summary: Get work order by ID
 *     description: Retrieve a single work order with populated property and technician references.
 *     tags: [Work Orders]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: MongoDB ObjectId
 *     responses:
 *       200:
 *         description: Work order details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/WorkOrder'
 *       404:
 *         description: Work order not found
 */
router.get('/:id', validateObjectId, async (req, res, next) => {
  try {
    const workOrder = await WorkOrder.findById(req.params.id)
      .populate('propertyId')
      .populate('assignedTechnicianId')
      .populate('assignedRouteId');

    if (!workOrder) {
      return res.status(404).json({
        error: {
          code: 'NOT_FOUND',
          message: 'Work order not found',
          details: [],
        },
      });
    }

    res.json({ data: workOrder });
  } catch (err) {
    next(err);
  }
});

/**
 * @swagger
 * /api/work-orders:
 *   post:
 *     summary: Create a work order
 *     description: Create a new work order. The property reference and coordinates are required.
 *     tags: [Work Orders]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/WorkOrder'
 *     responses:
 *       201:
 *         description: Work order created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/WorkOrder'
 *       400:
 *         description: Validation error
 *       409:
 *         description: Duplicate work order ID
 */
router.post('/', validateWorkOrder, async (req, res, next) => {
  try {
    const workOrder = new WorkOrder(req.body);
    const saved = await workOrder.save();

    res.status(201).json({ data: saved });
  } catch (err) {
    next(err);
  }
});

/**
 * @swagger
 * /api/work-orders/{id}:
 *   put:
 *     summary: Update a work order
 *     description: Update an existing work order by MongoDB ObjectId.
 *     tags: [Work Orders]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: MongoDB ObjectId
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/WorkOrder'
 *     responses:
 *       200:
 *         description: Work order updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/WorkOrder'
 *       404:
 *         description: Work order not found
 */
router.put('/:id', validateObjectId, async (req, res, next) => {
  try {
    const workOrder = await WorkOrder.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    );

    if (!workOrder) {
      return res.status(404).json({
        error: {
          code: 'NOT_FOUND',
          message: 'Work order not found',
          details: [],
        },
      });
    }

    res.json({ data: workOrder });
  } catch (err) {
    next(err);
  }
});

/**
 * @swagger
 * /api/work-orders/{id}/status:
 *   patch:
 *     summary: Update work order status
 *     description: Update only the status of a work order. Supports cancellation with a reason.
 *     tags: [Work Orders]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: MongoDB ObjectId
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - status
 *             properties:
 *               status:
 *                 type: string
 *                 enum: [pending, assigned, in_progress, completed, cancelled]
 *               cancellationReason:
 *                 type: string
 *                 description: Required when status is 'cancelled'
 *     responses:
 *       200:
 *         description: Status updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/WorkOrder'
 *       400:
 *         description: Invalid status value
 *       404:
 *         description: Work order not found
 */
router.patch('/:id/status', validateObjectId, async (req, res, next) => {
  try {
    const { status, cancellationReason } = req.body;
    const validStatuses = ['pending', 'assigned', 'in_progress', 'completed', 'cancelled'];

    if (!status || !validStatuses.includes(status)) {
      return res.status(400).json({
        error: {
          code: 'VALIDATION_ERROR',
          message: `Status must be one of: ${validStatuses.join(', ')}`,
          details: [],
        },
      });
    }

    const workOrder = await WorkOrder.findById(req.params.id);
    if (!workOrder) {
      return res.status(404).json({
        error: {
          code: 'NOT_FOUND',
          message: 'Work order not found',
          details: [],
        },
      });
    }

    // Handle status-specific logic
    if (status === 'completed') {
      await workOrder.complete();
    } else if (status === 'cancelled') {
      await workOrder.cancel(cancellationReason);
    } else {
      workOrder.status = status;
      await workOrder.save();
    }

    res.json({ data: workOrder });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
