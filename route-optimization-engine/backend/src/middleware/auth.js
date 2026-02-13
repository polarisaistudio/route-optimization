/**
 * Authentication & Authorization Middleware
 * Supports both local JWT verification and Okta JWKS-based verification.
 */

const jwt = require('jsonwebtoken');
const jwksRsa = require('jwks-rsa');
const config = require('../config');
const logger = require('winston');

/**
 * JWKS client for Okta token verification.
 * Initialized lazily only when Okta issuer is configured.
 */
let jwksClient = null;

function getJwksClient() {
  if (!jwksClient && config.okta.issuer) {
    jwksClient = jwksRsa({
      cache: true,
      cacheMaxEntries: 5,
      cacheMaxAge: 600000, // 10 minutes
      rateLimit: true,
      jwksRequestsPerMinute: 10,
      jwksUri: `${config.okta.issuer}/v1/keys`,
    });
  }
  return jwksClient;
}

/**
 * Retrieve the signing key from JWKS endpoint.
 * @param {string} kid - Key ID from JWT header
 * @returns {Promise<string>} Public signing key
 */
function getSigningKey(kid) {
  return new Promise((resolve, reject) => {
    const client = getJwksClient();
    if (!client) {
      return reject(new Error('JWKS client not configured'));
    }
    // TODO: In production, implement proper key matching with kid rotation handling.
    // Consider caching keys and implementing a fallback strategy for key rotation.
    client.getSigningKey(kid, (err, key) => {
      if (err) {
        logger.error('Failed to retrieve signing key from JWKS', { error: err.message, kid });
        return reject(err);
      }
      const signingKey = key.getPublicKey();
      resolve(signingKey);
    });
  });
}

/**
 * Verify a JWT token using local secret.
 * @param {string} token - JWT token string
 * @returns {object} Decoded token payload
 */
function verifyLocalToken(token) {
  return jwt.verify(token, config.jwt.secret, {
    issuer: config.jwt.issuer,
    algorithms: ['HS256'],
  });
}

/**
 * Verify a JWT token using Okta JWKS.
 * @param {string} token - JWT token string
 * @returns {Promise<object>} Decoded token payload
 */
async function verifyOktaToken(token) {
  const decoded = jwt.decode(token, { complete: true });
  if (!decoded || !decoded.header || !decoded.header.kid) {
    throw new Error('Invalid token: missing header or kid');
  }

  const signingKey = await getSigningKey(decoded.header.kid);

  return jwt.verify(token, signingKey, {
    issuer: config.okta.issuer,
    audience: config.okta.audience,
    algorithms: ['RS256'],
  });
}

/**
 * Authentication middleware.
 * Extracts and verifies JWT from the Authorization header.
 * Attaches decoded user information to req.user.
 *
 * Tries Okta JWKS verification first (if configured), then falls back to local JWT.
 */
async function authenticate(req, res, next) {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader) {
      return res.status(401).json({
        error: {
          code: 'UNAUTHORIZED',
          message: 'Authorization header is required',
          details: [],
        },
      });
    }

    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer') {
      return res.status(401).json({
        error: {
          code: 'UNAUTHORIZED',
          message: 'Authorization header must use Bearer scheme',
          details: [],
        },
      });
    }

    const token = parts[1];
    let payload;

    // Try Okta verification first if configured, then fall back to local
    if (config.okta.issuer) {
      try {
        payload = await verifyOktaToken(token);
      } catch (oktaError) {
        logger.debug('Okta verification failed, trying local JWT', {
          error: oktaError.message,
        });
        payload = verifyLocalToken(token);
      }
    } else {
      payload = verifyLocalToken(token);
    }

    // Attach user info extracted from the token to the request
    req.user = {
      id: payload.sub || payload.userId || payload.id,
      email: payload.email || '',
      name: payload.name || '',
      roles: payload.roles || payload.groups || ['user'],
    };

    next();
  } catch (err) {
    logger.warn('Authentication failed', {
      error: err.message,
      ip: req.ip,
      path: req.path,
    });

    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({
        error: {
          code: 'TOKEN_EXPIRED',
          message: 'Authentication token has expired',
          details: [],
        },
      });
    }

    if (err.name === 'JsonWebTokenError') {
      return res.status(401).json({
        error: {
          code: 'INVALID_TOKEN',
          message: 'Authentication token is invalid',
          details: [],
        },
      });
    }

    return res.status(401).json({
      error: {
        code: 'UNAUTHORIZED',
        message: 'Authentication failed',
        details: [],
      },
    });
  }
}

/**
 * Authorization middleware factory.
 * Checks that the authenticated user has at least one of the required roles.
 *
 * @param {string[]} roles - Array of allowed roles
 * @returns {Function} Express middleware
 */
function authorize(roles = []) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        error: {
          code: 'UNAUTHORIZED',
          message: 'Authentication is required before authorization',
          details: [],
        },
      });
    }

    if (roles.length === 0) {
      return next();
    }

    const userRoles = req.user.roles || [];
    const hasRole = roles.some((role) => userRoles.includes(role));

    if (!hasRole) {
      logger.warn('Authorization denied', {
        userId: req.user.id,
        requiredRoles: roles,
        userRoles,
        path: req.path,
      });

      return res.status(403).json({
        error: {
          code: 'FORBIDDEN',
          message: 'Insufficient permissions to access this resource',
          details: [
            {
              required: roles,
              current: userRoles,
            },
          ],
        },
      });
    }

    next();
  };
}

module.exports = {
  authenticate,
  authorize,
};
