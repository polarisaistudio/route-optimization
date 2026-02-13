/**
 * Global Error Handling Middleware
 * Provides consistent error response format and handles common error types.
 */

const logger = require('winston');
const config = require('../config');

/**
 * Map of Mongoose error names/codes to HTTP status codes and user-facing messages.
 */
const MONGOOSE_ERROR_MAP = {
  ValidationError: {
    status: 400,
    code: 'VALIDATION_ERROR',
  },
  CastError: {
    status: 400,
    code: 'INVALID_ID',
  },
  11000: {
    status: 409,
    code: 'DUPLICATE_KEY',
  },
};

/**
 * Format Mongoose validation errors into a details array.
 * @param {object} errors - Mongoose validation errors object
 * @returns {Array} Formatted error details
 */
function formatValidationErrors(errors) {
  return Object.keys(errors).map((field) => ({
    field,
    message: errors[field].message,
    value: errors[field].value,
  }));
}

/**
 * Extract duplicate key information from MongoDB duplicate key error.
 * @param {Error} err - MongoDB error
 * @returns {object} Extracted key info
 */
function extractDuplicateKeyInfo(err) {
  const match = err.message.match(/dup key: \{ (.+?) \}/);
  if (match) {
    return { duplicateKey: match[1] };
  }
  // Try to extract from keyPattern
  if (err.keyPattern) {
    return { duplicateFields: Object.keys(err.keyPattern) };
  }
  return {};
}

/**
 * Global error handler middleware.
 * Must be registered after all routes with four parameters (err, req, res, next).
 */
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  // Default error values
  let status = err.status || err.statusCode || 500;
  let code = 'INTERNAL_ERROR';
  let message = 'An unexpected error occurred';
  let details = [];

  // Handle Mongoose Validation Error
  if (err.name === 'ValidationError' && err.errors) {
    const mapped = MONGOOSE_ERROR_MAP.ValidationError;
    status = mapped.status;
    code = mapped.code;
    message = 'Request validation failed';
    details = formatValidationErrors(err.errors);
  }
  // Handle Mongoose CastError (invalid ObjectId, etc.)
  else if (err.name === 'CastError') {
    const mapped = MONGOOSE_ERROR_MAP.CastError;
    status = mapped.status;
    code = mapped.code;
    message = `Invalid value for ${err.path}: ${err.value}`;
    details = [{ field: err.path, value: err.value, kind: err.kind }];
  }
  // Handle MongoDB Duplicate Key Error
  else if (err.code === 11000 || err.code === 11001) {
    const mapped = MONGOOSE_ERROR_MAP[11000];
    status = mapped.status;
    code = mapped.code;
    message = 'A record with the given unique field(s) already exists';
    details = [extractDuplicateKeyInfo(err)];
  }
  // Handle SyntaxError (malformed JSON body)
  else if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    status = 400;
    code = 'MALFORMED_JSON';
    message = 'Request body contains invalid JSON';
    details = [];
  }
  // Handle custom application errors with status codes
  else if (err.status && err.status < 500) {
    status = err.status;
    code = err.code || 'CLIENT_ERROR';
    message = err.message;
    details = err.details || [];
  }
  // Handle all other errors
  else {
    // For 5xx errors, only expose message in non-production
    if (!config.server.isProduction) {
      message = err.message;
    }
  }

  // Log the error
  const logData = {
    code,
    status,
    method: req.method,
    path: req.originalUrl,
    ip: req.ip,
    userId: req.user ? req.user.id : 'anonymous',
  };

  if (status >= 500) {
    // Log full error for server errors
    logger.error('Server error', {
      ...logData,
      message: err.message,
      stack: err.stack,
    });
  } else {
    // Log reduced info for client errors
    logger.warn('Client error', {
      ...logData,
      message,
    });
  }

  // Build response - never leak stack traces in production
  const errorResponse = {
    error: {
      code,
      message,
      details,
    },
  };

  if (!config.server.isProduction && err.stack) {
    errorResponse.error.stack = err.stack;
  }

  res.status(status).json(errorResponse);
}

/**
 * 404 Not Found handler.
 * Must be registered after all routes but before the error handler.
 */
function notFoundHandler(req, res) {
  res.status(404).json({
    error: {
      code: 'NOT_FOUND',
      message: `Route ${req.method} ${req.originalUrl} not found`,
      details: [],
    },
  });
}

module.exports = {
  errorHandler,
  notFoundHandler,
};
