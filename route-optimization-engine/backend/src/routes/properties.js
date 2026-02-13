/**
 * Property Routes
 * CRUD operations and geo-spatial queries for real estate properties.
 */

const express = require("express");
const Property = require("../models/Property");
const {
  validatePagination,
  validateObjectId,
} = require("../middleware/validators");

const router = express.Router();

/**
 * @swagger
 * /api/properties:
 *   get:
 *     summary: List properties
 *     description: Retrieve a paginated list of properties with optional filtering by zone and type.
 *     tags: [Properties]
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
 *         name: zoneId
 *         schema:
 *           type: string
 *         description: Filter by zone ID
 *       - in: query
 *         name: propertyType
 *         schema:
 *           type: string
 *           enum: [residential, commercial, industrial]
 *         description: Filter by property type
 *       - in: query
 *         name: city
 *         schema:
 *           type: string
 *         description: Filter by city
 *       - in: query
 *         name: state
 *         schema:
 *           type: string
 *         description: Filter by state (2-letter code)
 *     responses:
 *       200:
 *         description: Paginated list of properties
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Property'
 *                 meta:
 *                   $ref: '#/components/schemas/PaginationMeta'
 */
router.get("/", validatePagination, async (req, res, next) => {
  try {
    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 20;
    const skip = (page - 1) * limit;

    // Build filter
    const filter = {};
    if (req.query.zoneId) filter.zoneId = req.query.zoneId;
    if (req.query.propertyType) filter.propertyType = req.query.propertyType;
    if (req.query.city) filter.city = new RegExp(req.query.city, "i");
    if (req.query.state) filter.state = req.query.state.toUpperCase();

    const [properties, total] = await Promise.all([
      Property.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit),
      Property.countDocuments(filter),
    ]);

    res.json({
      data: properties,
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
 * /api/properties/nearby:
 *   get:
 *     summary: Find nearby properties
 *     description: Find properties within a specified radius of a given point using geo-spatial query.
 *     tags: [Properties]
 *     parameters:
 *       - in: query
 *         name: longitude
 *         required: true
 *         schema:
 *           type: number
 *         description: Longitude of the center point
 *       - in: query
 *         name: latitude
 *         required: true
 *         schema:
 *           type: number
 *         description: Latitude of the center point
 *       - in: query
 *         name: radius
 *         schema:
 *           type: number
 *           default: 10
 *         description: Search radius in miles
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 50
 *         description: Maximum number of results
 *     responses:
 *       200:
 *         description: List of nearby properties
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Property'
 *                 meta:
 *                   type: object
 *                   properties:
 *                     center:
 *                       type: object
 *                     radiusMiles:
 *                       type: number
 *                     count:
 *                       type: integer
 *       400:
 *         description: Missing or invalid coordinates
 */
router.get("/nearby", async (req, res, next) => {
  try {
    const { longitude, latitude, radius = 10, limit = 50 } = req.query;

    if (!longitude || !latitude) {
      return res.status(400).json({
        error: {
          code: "VALIDATION_ERROR",
          message: "Longitude and latitude are required query parameters",
          details: [],
        },
      });
    }

    const lng = parseFloat(longitude);
    const lat = parseFloat(latitude);
    const maxDistance = parseFloat(radius);
    const maxResults = parseInt(limit, 10);

    if (
      isNaN(lng) ||
      isNaN(lat) ||
      lng < -180 ||
      lng > 180 ||
      lat < -90 ||
      lat > 90
    ) {
      return res.status(400).json({
        error: {
          code: "VALIDATION_ERROR",
          message:
            "Invalid coordinates. Longitude: -180 to 180, Latitude: -90 to 90",
          details: [],
        },
      });
    }

    const properties = await Property.findNearby(lng, lat, maxDistance).limit(
      maxResults,
    );

    res.json({
      data: properties,
      meta: {
        center: { longitude: lng, latitude: lat },
        radiusMiles: maxDistance,
        count: properties.length,
      },
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @swagger
 * /api/properties/{id}:
 *   get:
 *     summary: Get property by ID
 *     description: Retrieve a single property by its MongoDB ObjectId.
 *     tags: [Properties]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: MongoDB ObjectId
 *     responses:
 *       200:
 *         description: Property details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/Property'
 *       404:
 *         description: Property not found
 */
router.get("/:id", validateObjectId, async (req, res, next) => {
  try {
    const property = await Property.findById(req.params.id);

    if (!property) {
      return res.status(404).json({
        error: {
          code: "NOT_FOUND",
          message: "Property not found",
          details: [],
        },
      });
    }

    res.json({ data: property });
  } catch (err) {
    next(err);
  }
});

/**
 * @swagger
 * /api/properties:
 *   post:
 *     summary: Create a property
 *     description: Create a new property record.
 *     tags: [Properties]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Property'
 *     responses:
 *       201:
 *         description: Property created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/Property'
 *       400:
 *         description: Validation error
 *       409:
 *         description: Duplicate property ID
 */
router.post("/", async (req, res, next) => {
  try {
    const property = new Property(req.body);
    const saved = await property.save();

    res.status(201).json({ data: saved });
  } catch (err) {
    next(err);
  }
});

/**
 * @swagger
 * /api/properties/{id}:
 *   put:
 *     summary: Update a property
 *     description: Update an existing property by its MongoDB ObjectId.
 *     tags: [Properties]
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
 *             $ref: '#/components/schemas/Property'
 *     responses:
 *       200:
 *         description: Property updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/Property'
 *       404:
 *         description: Property not found
 */
router.put("/:id", validateObjectId, async (req, res, next) => {
  try {
    const property = await Property.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    });

    if (!property) {
      return res.status(404).json({
        error: {
          code: "NOT_FOUND",
          message: "Property not found",
          details: [],
        },
      });
    }

    res.json({ data: property });
  } catch (err) {
    next(err);
  }
});

/**
 * @swagger
 * /api/properties/{id}:
 *   delete:
 *     summary: Delete a property
 *     description: Delete a property by its MongoDB ObjectId.
 *     tags: [Properties]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: MongoDB ObjectId
 *     responses:
 *       200:
 *         description: Property deleted successfully
 *       404:
 *         description: Property not found
 */
router.delete("/:id", validateObjectId, async (req, res, next) => {
  try {
    const property = await Property.findByIdAndDelete(req.params.id);

    if (!property) {
      return res.status(404).json({
        error: {
          code: "NOT_FOUND",
          message: "Property not found",
          details: [],
        },
      });
    }

    res.json({
      data: { message: "Property deleted successfully", id: req.params.id },
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
