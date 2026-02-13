# API Reference

## Base Configuration

- **Base URL**: `http://localhost:3001/api/v1`
- **Content-Type**: `application/json`
- **Authentication**: Bearer JWT token in `Authorization` header
- **Swagger UI**: `http://localhost:3001/api-docs`

## Authentication

All endpoints except `/health` require a valid JWT token:

```
Authorization: Bearer <token>
```

Tokens are issued by Okta OIDC or the local JWT signing endpoint (development only).

---

## Health

### GET /health

Liveness check. Returns basic service status.

**Response** `200 OK`
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "uptime": 3600
}
```

### GET /health/ready

Readiness check. Verifies database connectivity.

**Response** `200 OK`
```json
{
  "status": "ready",
  "database": "connected",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

---

## Properties

### GET /properties

List all properties with pagination and filtering.

**Query Parameters**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `page` | integer | 1 | Page number |
| `limit` | integer | 20 | Items per page (max 100) |
| `type` | string | - | Filter by property type |
| `zone` | string | - | Filter by zone |
| `status` | string | - | Filter by status |

**Response** `200 OK`
```json
{
  "data": [
    {
      "_id": "65a1b2c3d4e5f6a7b8c9d0e1",
      "name": "Sunset Ridge Apartments",
      "address": "1234 Main St, Denver, CO 80202",
      "location": {
        "type": "Point",
        "coordinates": [-104.9903, 39.7392]
      },
      "type": "residential",
      "zone": "central",
      "accessRequirements": ["key_lockbox", "gate_code"],
      "status": "active"
    }
  ],
  "pagination": {
    "total": 50,
    "page": 1,
    "limit": 20,
    "pages": 3
  }
}
```

### POST /properties

Create a new property.

**Request Body**
```json
{
  "name": "Mountain View Office Park",
  "address": "5678 Business Blvd, Denver, CO 80210",
  "location": {
    "type": "Point",
    "coordinates": [-104.9500, 39.6800]
  },
  "type": "commercial",
  "zone": "south",
  "accessRequirements": ["badge_access"],
  "contactName": "Jane Smith",
  "contactPhone": "303-555-0100"
}
```

**Response** `201 Created`

### GET /properties/:id

Get a property by ID.

**Response** `200 OK`

### PUT /properties/:id

Update a property.

### DELETE /properties/:id

Delete a property.

### GET /properties/nearby

Find properties near a geographic point.

**Query Parameters**

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `lng` | number | yes | Longitude |
| `lat` | number | yes | Latitude |
| `maxDistance` | number | no | Max distance in meters (default: 5000) |

**Response** `200 OK`
```json
{
  "data": [
    {
      "_id": "65a1b2c3d4e5f6a7b8c9d0e1",
      "name": "Sunset Ridge Apartments",
      "distance": 1234.5
    }
  ]
}
```

---

## Technicians

### GET /technicians

List all technicians with optional filters.

**Query Parameters**

| Param | Type | Description |
|-------|------|-------------|
| `status` | string | Filter: `active`, `inactive`, `on_leave` |
| `skill` | string | Filter by skill |
| `zone` | string | Filter by assigned zone |

### POST /technicians

Create a new technician.

**Request Body**
```json
{
  "name": "John Rodriguez",
  "employeeId": "TECH-001",
  "skills": ["hvac", "electrical", "plumbing"],
  "certifications": ["EPA_608", "OSHA_30"],
  "homeBase": {
    "type": "Point",
    "coordinates": [-104.9903, 39.7392]
  },
  "zone": "central",
  "maxDailyHours": 8,
  "vehicleType": "van"
}
```

### GET /technicians/:id

Get a technician by ID.

### PUT /technicians/:id

Update a technician.

### PATCH /technicians/:id/status

Update a technician's status.

**Request Body**
```json
{
  "status": "active"
}
```

---

## Work Orders

### GET /work-orders

List work orders with filtering and pagination.

**Query Parameters**

| Param | Type | Description |
|-------|------|-------------|
| `page` | integer | Page number |
| `limit` | integer | Items per page |
| `status` | string | `pending`, `assigned`, `in_progress`, `completed`, `cancelled` |
| `priority` | string | `emergency`, `high`, `medium`, `low` |
| `propertyId` | string | Filter by property |
| `technicianId` | string | Filter by assigned technician |

### POST /work-orders

Create a new work order.

**Request Body**
```json
{
  "property": "65a1b2c3d4e5f6a7b8c9d0e1",
  "title": "HVAC System Repair",
  "description": "Compressor not functioning, tenant reports no cooling",
  "category": "hvac",
  "priority": "high",
  "requiredSkills": ["hvac"],
  "estimatedDuration": 120,
  "timeWindow": {
    "start": "2024-01-15T08:00:00.000Z",
    "end": "2024-01-15T12:00:00.000Z"
  },
  "slaDeadline": "2024-01-15T17:00:00.000Z"
}
```

### GET /work-orders/:id

Get a work order by ID.

### PUT /work-orders/:id

Update a work order.

### DELETE /work-orders/:id

Delete a work order.

### GET /work-orders/summary

Get aggregated work order statistics.

**Response** `200 OK`
```json
{
  "total": 100,
  "byStatus": {
    "pending": 25,
    "assigned": 30,
    "in_progress": 20,
    "completed": 20,
    "cancelled": 5
  },
  "byPriority": {
    "emergency": 5,
    "high": 20,
    "medium": 50,
    "low": 25
  },
  "avgDuration": 95.5
}
```

---

## Routes

### GET /routes

List all routes with pagination.

### GET /routes/:id

Get a route by ID with populated stops.

### GET /routes/date/:date

Get all routes for a specific date.

**Parameters**

| Param | Type | Format | Description |
|-------|------|--------|-------------|
| `date` | string | `YYYY-MM-DD` | Route date |

**Response** `200 OK`
```json
{
  "data": [
    {
      "_id": "65a1b2c3d4e5f6a7b8c9d0e1",
      "technician": {
        "name": "John Rodriguez",
        "employeeId": "TECH-001"
      },
      "date": "2024-01-15",
      "status": "optimized",
      "stops": [
        {
          "sequence": 1,
          "property": { "name": "Sunset Ridge Apartments" },
          "workOrder": { "title": "HVAC System Repair" },
          "arrivalTime": "2024-01-15T08:30:00.000Z",
          "departureTime": "2024-01-15T10:30:00.000Z",
          "travelTimeFromPrevious": 15,
          "distanceFromPrevious": 8.5
        }
      ],
      "summary": {
        "totalStops": 6,
        "totalDistance": 45.2,
        "totalDuration": 420,
        "totalTravelTime": 95,
        "totalServiceTime": 325,
        "utilizationRate": 0.82
      }
    }
  ]
}
```

### DELETE /routes/:id

Delete a route.

---

## Optimization

### POST /optimization/run

Trigger a new optimization run.

**Request Body**
```json
{
  "date": "2024-01-15",
  "algorithm": "vrp",
  "config": {
    "maxDailyHours": 8,
    "maxStopsPerRoute": 15,
    "timeoutSeconds": 300,
    "priorityWeights": {
      "emergency": 10000,
      "high": 5000,
      "medium": 1000,
      "low": 100
    }
  },
  "technicianIds": ["65a1...", "65a2..."],
  "workOrderIds": ["65b1...", "65b2..."]
}
```

**Response** `202 Accepted`
```json
{
  "runId": "65c1b2c3d4e5f6a7b8c9d0e1",
  "status": "running",
  "algorithm": "vrp",
  "message": "Optimization started"
}
```

### GET /optimization/:id/status

Check the status of an optimization run.

**Response** `200 OK`
```json
{
  "runId": "65c1b2c3d4e5f6a7b8c9d0e1",
  "status": "completed",
  "algorithm": "vrp",
  "startTime": "2024-01-15T10:30:00.000Z",
  "endTime": "2024-01-15T10:30:45.000Z",
  "duration": 45000,
  "results": {
    "totalRoutes": 5,
    "totalStops": 42,
    "totalDistance": 187.3,
    "unassignedWorkOrders": 3,
    "averageUtilization": 0.85
  }
}
```

### GET /optimization/history

Get optimization run history.

**Query Parameters**

| Param | Type | Description |
|-------|------|-------------|
| `page` | integer | Page number |
| `limit` | integer | Items per page |
| `algorithm` | string | Filter by algorithm |
| `status` | string | Filter by status |

### POST /optimization/compare

Compare results across algorithms for the same dataset.

**Request Body**
```json
{
  "date": "2024-01-15",
  "algorithms": ["vrp", "greedy", "genetic"]
}
```

**Response** `200 OK`
```json
{
  "date": "2024-01-15",
  "comparison": [
    {
      "algorithm": "vrp",
      "totalDistance": 187.3,
      "totalDuration": 2100,
      "avgUtilization": 0.85,
      "unassigned": 3,
      "runtime": 45000
    },
    {
      "algorithm": "greedy",
      "totalDistance": 215.8,
      "totalDuration": 2350,
      "avgUtilization": 0.78,
      "unassigned": 5,
      "runtime": 1200
    },
    {
      "algorithm": "genetic",
      "totalDistance": 195.1,
      "totalDuration": 2180,
      "avgUtilization": 0.83,
      "unassigned": 4,
      "runtime": 120000
    }
  ]
}
```

---

## Error Responses

All errors follow a consistent format:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input",
    "details": [
      {
        "field": "priority",
        "message": "Must be one of: emergency, high, medium, low"
      }
    ]
  }
}
```

### Status Codes

| Code | Description |
|------|-------------|
| `200` | Success |
| `201` | Created |
| `202` | Accepted (async operation started) |
| `400` | Bad Request (validation error) |
| `401` | Unauthorized (missing/invalid token) |
| `403` | Forbidden (insufficient permissions) |
| `404` | Not Found |
| `409` | Conflict (duplicate resource) |
| `429` | Too Many Requests (rate limited) |
| `500` | Internal Server Error |

## Rate Limiting

- **Window**: 15 minutes
- **Max Requests**: 100 per window per IP
- **Headers**: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`
