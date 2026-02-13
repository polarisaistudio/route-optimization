/**
 * Request Validation Middleware
 * Uses express-validator to validate incoming request data.
 */

const { body, query, param, validationResult } = require('express-validator');

/**
 * Generic validation result checker.
 * If validation errors exist, returns a 400 response with error details.
 * Must be placed after validation chain middleware in the route handler array.
 */
function validate() {
  return (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      const formattedErrors = errors.array().map((err) => ({
        field: err.path || err.param,
        message: err.msg,
        value: err.value,
        location: err.location,
      }));

      return res.status(400).json({
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Request validation failed',
          details: formattedErrors,
        },
      });
    }
    next();
  };
}

/**
 * Validation rules for creating/updating a work order.
 */
const validateWorkOrder = [
  body('workOrderId')
    .trim()
    .notEmpty()
    .withMessage('Work order ID is required')
    .isLength({ max: 50 })
    .withMessage('Work order ID cannot exceed 50 characters'),

  body('propertyId')
    .notEmpty()
    .withMessage('Property ID is required')
    .isMongoId()
    .withMessage('Property ID must be a valid MongoDB ObjectId'),

  body('title')
    .trim()
    .notEmpty()
    .withMessage('Title is required')
    .isLength({ max: 200 })
    .withMessage('Title cannot exceed 200 characters'),

  body('description')
    .optional()
    .trim()
    .isLength({ max: 2000 })
    .withMessage('Description cannot exceed 2000 characters'),

  body('category')
    .notEmpty()
    .withMessage('Category is required')
    .isIn(['hvac', 'plumbing', 'electrical', 'general', 'inspection'])
    .withMessage('Category must be one of: hvac, plumbing, electrical, general, inspection'),

  body('priority')
    .optional()
    .isIn(['emergency', 'high', 'medium', 'low'])
    .withMessage('Priority must be one of: emergency, high, medium, low'),

  body('estimatedDurationMinutes')
    .notEmpty()
    .withMessage('Estimated duration is required')
    .isInt({ min: 1, max: 960 })
    .withMessage('Estimated duration must be between 1 and 960 minutes'),

  body('requiredSkills')
    .optional()
    .isArray()
    .withMessage('Required skills must be an array'),

  body('requiredSkills.*')
    .optional()
    .isIn(['hvac', 'plumbing', 'electrical', 'general', 'inspection'])
    .withMessage('Each skill must be one of: hvac, plumbing, electrical, general, inspection'),

  body('timeWindowStart')
    .optional()
    .isISO8601()
    .withMessage('Time window start must be a valid ISO 8601 date'),

  body('timeWindowEnd')
    .optional()
    .isISO8601()
    .withMessage('Time window end must be a valid ISO 8601 date'),

  body('property')
    .optional()
    .isObject()
    .withMessage('Property snapshot must be an object'),

  body('property.location.coordinates')
    .optional()
    .isArray({ min: 2, max: 2 })
    .withMessage('Coordinates must be an array of [longitude, latitude]'),

  body('property.address')
    .optional()
    .trim()
    .notEmpty()
    .withMessage('Property address cannot be empty if provided'),

  body('sourceSystem')
    .optional()
    .isIn(['salesforce', 'manual', 'iot'])
    .withMessage('Source system must be one of: salesforce, manual, iot'),

  validate(),
];

/**
 * Validation rules for triggering an optimization run.
 */
const validateOptimizationRequest = [
  body('date')
    .notEmpty()
    .withMessage('Optimization date is required')
    .isISO8601()
    .withMessage('Date must be a valid ISO 8601 date string'),

  body('algorithm')
    .optional()
    .isIn(['vrp', 'greedy', 'genetic', 'all'])
    .withMessage('Algorithm must be one of: vrp, greedy, genetic, all'),

  body('config')
    .optional()
    .isObject()
    .withMessage('Configuration must be an object'),

  body('config.maxTimeSeconds')
    .optional()
    .isInt({ min: 1, max: 3600 })
    .withMessage('Max time must be between 1 and 3600 seconds'),

  body('config.maxDistanceMiles')
    .optional()
    .isFloat({ min: 1 })
    .withMessage('Max distance must be at least 1 mile'),

  body('config.maxStopsPerRoute')
    .optional()
    .isInt({ min: 1, max: 50 })
    .withMessage('Max stops per route must be between 1 and 50'),

  body('config.balanceWorkload')
    .optional()
    .isBoolean()
    .withMessage('Balance workload must be a boolean'),

  validate(),
];

/**
 * Validation rules for pagination query parameters.
 */
const validatePagination = [
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Page must be a positive integer')
    .toInt(),

  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit must be between 1 and 100')
    .toInt(),

  validate(),
];

/**
 * Validation rules for MongoDB ObjectId path parameters.
 */
const validateObjectId = [
  param('id')
    .isMongoId()
    .withMessage('Invalid ID format'),

  validate(),
];

/**
 * Validation rules for date path parameters.
 */
const validateDateParam = [
  param('date')
    .isISO8601()
    .withMessage('Date must be a valid ISO 8601 date string'),

  validate(),
];

module.exports = {
  validate,
  validateWorkOrder,
  validateOptimizationRequest,
  validatePagination,
  validateObjectId,
  validateDateParam,
};
