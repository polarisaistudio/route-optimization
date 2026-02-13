/**
 * Technician Routes
 * CRUD operations and availability management for field technicians.
 */

const express = require('express');
const Technician = require('../models/Technician');
const { validatePagination, validateObjectId } = require('../middleware/validators');

const router = express.Router();

/**
 * @swagger
 * /api/technicians:
 *   get:
 *     summary: List technicians
 *     description: Retrieve a paginated list of technicians with optional filtering.
 *     tags: [Technicians]
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
 *         name: skill
 *         schema:
 *           type: string
 *           enum: [hvac, plumbing, electrical, general, inspection]
 *         description: Filter by skill
 *       - in: query
 *         name: availabilityStatus
 *         schema:
 *           type: string
 *           enum: [available, on_route, off_duty, on_leave]
 *         description: Filter by availability status
 *       - in: query
 *         name: zone
 *         schema:
 *           type: string
 *         description: Filter by zone preference
 *     responses:
 *       200:
 *         description: Paginated list of technicians
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Technician'
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
    if (req.query.skill) filter.skills = req.query.skill;
    if (req.query.availabilityStatus) filter.availabilityStatus = req.query.availabilityStatus;
    if (req.query.zone) filter.zonePreference = req.query.zone;

    const [technicians, total] = await Promise.all([
      Technician.find(filter).sort({ name: 1 }).skip(skip).limit(limit),
      Technician.countDocuments(filter),
    ]);

    res.json({
      data: technicians,
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
 * /api/technicians/{id}:
 *   get:
 *     summary: Get technician by ID
 *     description: Retrieve a single technician by MongoDB ObjectId.
 *     tags: [Technicians]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: MongoDB ObjectId
 *     responses:
 *       200:
 *         description: Technician details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/Technician'
 *       404:
 *         description: Technician not found
 */
router.get('/:id', validateObjectId, async (req, res, next) => {
  try {
    const technician = await Technician.findById(req.params.id);

    if (!technician) {
      return res.status(404).json({
        error: {
          code: 'NOT_FOUND',
          message: 'Technician not found',
          details: [],
        },
      });
    }

    res.json({ data: technician });
  } catch (err) {
    next(err);
  }
});

/**
 * @swagger
 * /api/technicians:
 *   post:
 *     summary: Create a technician
 *     description: Register a new field technician.
 *     tags: [Technicians]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Technician'
 *     responses:
 *       201:
 *         description: Technician created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/Technician'
 *       400:
 *         description: Validation error
 *       409:
 *         description: Duplicate technician ID or email
 */
router.post('/', async (req, res, next) => {
  try {
    const technician = new Technician(req.body);
    const saved = await technician.save();

    res.status(201).json({ data: saved });
  } catch (err) {
    next(err);
  }
});

/**
 * @swagger
 * /api/technicians/{id}:
 *   put:
 *     summary: Update a technician
 *     description: Update an existing technician's information.
 *     tags: [Technicians]
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
 *             $ref: '#/components/schemas/Technician'
 *     responses:
 *       200:
 *         description: Technician updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/Technician'
 *       404:
 *         description: Technician not found
 */
router.put('/:id', validateObjectId, async (req, res, next) => {
  try {
    const technician = await Technician.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    );

    if (!technician) {
      return res.status(404).json({
        error: {
          code: 'NOT_FOUND',
          message: 'Technician not found',
          details: [],
        },
      });
    }

    res.json({ data: technician });
  } catch (err) {
    next(err);
  }
});

/**
 * @swagger
 * /api/technicians/{id}/status:
 *   patch:
 *     summary: Update technician availability status
 *     description: Update only the availability status of a technician.
 *     tags: [Technicians]
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
 *               - availabilityStatus
 *             properties:
 *               availabilityStatus:
 *                 type: string
 *                 enum: [available, on_route, off_duty, on_leave]
 *     responses:
 *       200:
 *         description: Status updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/Technician'
 *       400:
 *         description: Invalid status value
 *       404:
 *         description: Technician not found
 */
router.patch('/:id/status', validateObjectId, async (req, res, next) => {
  try {
    const { availabilityStatus } = req.body;
    const validStatuses = ['available', 'on_route', 'off_duty', 'on_leave'];

    if (!availabilityStatus || !validStatuses.includes(availabilityStatus)) {
      return res.status(400).json({
        error: {
          code: 'VALIDATION_ERROR',
          message: `availabilityStatus must be one of: ${validStatuses.join(', ')}`,
          details: [],
        },
      });
    }

    const technician = await Technician.findByIdAndUpdate(
      req.params.id,
      { availabilityStatus },
      { new: true, runValidators: true }
    );

    if (!technician) {
      return res.status(404).json({
        error: {
          code: 'NOT_FOUND',
          message: 'Technician not found',
          details: [],
        },
      });
    }

    res.json({ data: technician });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
