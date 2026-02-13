/**
 * API Route Tests
 * Integration tests using Jest + Supertest with MongoMemoryServer.
 */

const request = require("supertest");
const mongoose = require("mongoose");
const { MongoMemoryServer } = require("mongodb-memory-server");

// Mock the auth middleware before loading the app so all routes are accessible
jest.mock("../src/middleware/auth", () => ({
  authenticate: (req, res, next) => {
    req.user = {
      id: "test-user-id",
      email: "test@example.com",
      name: "Test User",
      roles: ["admin"],
    };
    next();
  },
  authorize: () => (req, res, next) => next(),
}));

// Set test environment
process.env.NODE_ENV = "test";

const app = require("../src/app");
const Property = require("../src/models/Property");
const WorkOrder = require("../src/models/WorkOrder");
const Technician = require("../src/models/Technician");
const Route = require("../src/models/Route");
const OptimizationRun = require("../src/models/OptimizationRun");

// ---------------------------------------------------------------------------
// Test Data Fixtures
// ---------------------------------------------------------------------------
const testProperty = {
  propertyId: "TEST-PROP-001",
  address: "100 Test Street",
  city: "Austin",
  state: "TX",
  zipCode: "78701",
  location: {
    type: "Point",
    coordinates: [-97.7431, 30.2672],
  },
  propertyType: "commercial",
  zoneId: "ZONE-TEST",
};

const testTechnician = {
  technicianId: "TEST-TECH-001",
  name: "Test Technician",
  email: "test.tech@example.com",
  phone: "512-555-0100",
  homeBase: {
    type: "Point",
    coordinates: [-97.7431, 30.2672],
  },
  skills: ["hvac", "general"],
  maxDailyHours: 8,
  maxDailyDistanceMiles: 150,
  hourlyRate: 45,
  availabilityStatus: "available",
};

// ---------------------------------------------------------------------------
// Setup and Teardown
// ---------------------------------------------------------------------------
let mongoServer;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  const mongoUri = mongoServer.getUri();
  await mongoose.connect(mongoUri);
}, 30000);

afterAll(async () => {
  if (mongoose.connection.readyState === 1) {
    await mongoose.disconnect();
  }
  if (mongoServer) {
    await mongoServer.stop();
  }
}, 15000);

beforeEach(async () => {
  const collections = mongoose.connection.collections;
  for (const key in collections) {
    await collections[key].deleteMany({});
  }
});

// ---------------------------------------------------------------------------
// Health Check Tests
// ---------------------------------------------------------------------------
describe("Health Check Routes", () => {
  test("GET /health should return 200 with status ok", async () => {
    const res = await request(app).get("/health");

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty("status", "ok");
    expect(res.body).toHaveProperty("uptime");
    expect(res.body).toHaveProperty("timestamp");
    expect(res.body).toHaveProperty("version", "1.0.0");
  });

  test("GET /health/ready should return 200 when MongoDB is connected", async () => {
    const res = await request(app).get("/health/ready");

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty("status", "ready");
    expect(res.body.checks).toHaveProperty("mongodb");
    expect(res.body.checks.mongodb).toHaveProperty("status", "connected");
    expect(res.body.checks.mongodb).toHaveProperty("responseTimeMs");
  });
});

// ---------------------------------------------------------------------------
// Property Route Tests
// ---------------------------------------------------------------------------
describe("Property Routes", () => {
  test("GET /api/properties should return an empty array initially", async () => {
    const res = await request(app).get("/api/properties");

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty("data");
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data).toHaveLength(0);
    expect(res.body).toHaveProperty("meta");
    expect(res.body.meta).toHaveProperty("total", 0);
  });

  test("POST /api/properties should create a new property", async () => {
    const res = await request(app).post("/api/properties").send(testProperty);

    expect(res.status).toBe(201);
    expect(res.body.data).toHaveProperty("propertyId", "TEST-PROP-001");
    expect(res.body.data).toHaveProperty("address", "100 Test Street");
    expect(res.body.data).toHaveProperty("city", "Austin");
    expect(res.body.data).toHaveProperty("propertyType", "commercial");
  });

  test("GET /api/properties should return properties after creation", async () => {
    await Property.create(testProperty);

    const res = await request(app).get("/api/properties");

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0]).toHaveProperty("propertyId", "TEST-PROP-001");
    expect(res.body.meta.total).toBe(1);
  });

  test("GET /api/properties/:id should return a single property", async () => {
    const property = await Property.create(testProperty);

    const res = await request(app).get(`/api/properties/${property._id}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveProperty("propertyId", "TEST-PROP-001");
  });

  test("GET /api/properties/:id should return 404 for non-existent property", async () => {
    const fakeId = new mongoose.Types.ObjectId();
    const res = await request(app).get(`/api/properties/${fakeId}`);

    expect(res.status).toBe(404);
    expect(res.body.error).toHaveProperty("code", "NOT_FOUND");
  });

  test("GET /api/properties should support filtering by zone", async () => {
    await Property.create(testProperty);
    await Property.create({
      ...testProperty,
      propertyId: "TEST-PROP-002",
      zoneId: "ZONE-OTHER",
    });

    const res = await request(app).get("/api/properties?zoneId=ZONE-TEST");

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0]).toHaveProperty("zoneId", "ZONE-TEST");
  });

  test("PUT /api/properties/:id should update a property", async () => {
    const property = await Property.create(testProperty);

    const res = await request(app)
      .put(`/api/properties/${property._id}`)
      .send({ address: "200 Updated Street" });

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveProperty("address", "200 Updated Street");
  });

  test("DELETE /api/properties/:id should delete a property", async () => {
    const property = await Property.create(testProperty);

    const res = await request(app).delete(`/api/properties/${property._id}`);
    expect(res.status).toBe(200);

    const check = await Property.findById(property._id);
    expect(check).toBeNull();
  });

  test("DELETE /api/properties/:id should return 404 for non-existent", async () => {
    const fakeId = new mongoose.Types.ObjectId();
    const res = await request(app).delete(`/api/properties/${fakeId}`);
    expect(res.status).toBe(404);
  });
});

// ---------------------------------------------------------------------------
// Technician Route Tests
// ---------------------------------------------------------------------------
describe("Technician Routes", () => {
  test("GET /api/technicians should return an array", async () => {
    const res = await request(app).get("/api/technicians");

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
  });

  test("POST /api/technicians should create a new technician", async () => {
    const res = await request(app)
      .post("/api/technicians")
      .send(testTechnician);

    expect(res.status).toBe(201);
    expect(res.body.data).toHaveProperty("technicianId", "TEST-TECH-001");
    expect(res.body.data).toHaveProperty("name", "Test Technician");
    expect(res.body.data.skills).toContain("hvac");
  });

  test("GET /api/technicians/:id should return a single technician", async () => {
    const tech = await Technician.create(testTechnician);

    const res = await request(app).get(`/api/technicians/${tech._id}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveProperty("technicianId", "TEST-TECH-001");
  });

  test("PATCH /api/technicians/:id/status should update availability", async () => {
    const tech = await Technician.create(testTechnician);

    const res = await request(app)
      .patch(`/api/technicians/${tech._id}/status`)
      .send({ availabilityStatus: "on_route" });

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveProperty("availabilityStatus", "on_route");
  });

  test("PATCH /api/technicians/:id/status should reject invalid status", async () => {
    const tech = await Technician.create(testTechnician);

    const res = await request(app)
      .patch(`/api/technicians/${tech._id}/status`)
      .send({ availabilityStatus: "invalid_status" });

    expect(res.status).toBe(400);
    expect(res.body.error).toHaveProperty("code", "VALIDATION_ERROR");
  });

  test("PUT /api/technicians/:id should update technician details", async () => {
    const tech = await Technician.create(testTechnician);

    const res = await request(app)
      .put(`/api/technicians/${tech._id}`)
      .send({ name: "Updated Name", maxDailyHours: 10 });

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveProperty("name", "Updated Name");
    expect(res.body.data).toHaveProperty("maxDailyHours", 10);
  });
});

// ---------------------------------------------------------------------------
// Work Order Route Tests
// ---------------------------------------------------------------------------
describe("Work Order Routes", () => {
  let savedProperty;

  beforeEach(async () => {
    savedProperty = await Property.create(testProperty);
  });

  test("POST /api/work-orders should validate required fields", async () => {
    const res = await request(app).post("/api/work-orders").send({});

    expect(res.status).toBe(400);
    expect(res.body.error).toHaveProperty("code", "VALIDATION_ERROR");
    expect(res.body.error).toHaveProperty("details");
    expect(res.body.error.details.length).toBeGreaterThan(0);
  });

  test("POST /api/work-orders should reject invalid category", async () => {
    const res = await request(app)
      .post("/api/work-orders")
      .send({
        workOrderId: "WO-TEST-001",
        propertyId: savedProperty._id.toString(),
        title: "Test Work Order",
        category: "invalid_category",
        estimatedDurationMinutes: 60,
        property: {
          location: {
            type: "Point",
            coordinates: [-97.7431, 30.2672],
          },
        },
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toHaveProperty("code", "VALIDATION_ERROR");
  });

  test("POST /api/work-orders should create a valid work order", async () => {
    const res = await request(app)
      .post("/api/work-orders")
      .send({
        workOrderId: "WO-TEST-001",
        propertyId: savedProperty._id.toString(),
        title: "HVAC Maintenance",
        category: "hvac",
        priority: "medium",
        estimatedDurationMinutes: 60,
        property: {
          location: {
            type: "Point",
            coordinates: [-97.7431, 30.2672],
          },
          address: "100 Test Street",
          city: "Austin",
          state: "TX",
          zipCode: "78701",
        },
      });

    expect(res.status).toBe(201);
    expect(res.body.data).toHaveProperty("workOrderId", "WO-TEST-001");
    expect(res.body.data).toHaveProperty("category", "hvac");
    expect(res.body.data).toHaveProperty("status", "pending");
  });

  test("GET /api/work-orders should return work orders", async () => {
    await WorkOrder.create({
      workOrderId: "WO-LIST-001",
      propertyId: savedProperty._id,
      title: "Test WO",
      category: "hvac",
      priority: "high",
      estimatedDurationMinutes: 30,
      property: {
        location: { type: "Point", coordinates: [-97.7431, 30.2672] },
      },
    });

    const res = await request(app).get("/api/work-orders");
    expect(res.status).toBe(200);
    expect(res.body.data.length).toBe(1);
  });

  test("GET /api/work-orders should filter by status", async () => {
    await WorkOrder.create({
      workOrderId: "WO-S1",
      propertyId: savedProperty._id,
      title: "Pending",
      category: "hvac",
      priority: "medium",
      estimatedDurationMinutes: 30,
      status: "pending",
      property: {
        location: { type: "Point", coordinates: [-97.7431, 30.2672] },
      },
    });
    await WorkOrder.create({
      workOrderId: "WO-S2",
      propertyId: savedProperty._id,
      title: "Completed",
      category: "general",
      priority: "low",
      estimatedDurationMinutes: 30,
      status: "completed",
      property: {
        location: { type: "Point", coordinates: [-97.7431, 30.2672] },
      },
    });

    const res = await request(app).get("/api/work-orders?status=pending");
    expect(res.status).toBe(200);
    expect(res.body.data.length).toBe(1);
    expect(res.body.data[0]).toHaveProperty("status", "pending");
  });

  test("GET /api/work-orders/summary should return aggregated counts", async () => {
    await WorkOrder.create({
      workOrderId: "WO-SUM-001",
      propertyId: savedProperty._id,
      title: "Test Summary",
      category: "hvac",
      priority: "high",
      estimatedDurationMinutes: 30,
      property: {
        location: { type: "Point", coordinates: [-97.7431, 30.2672] },
      },
    });

    const res = await request(app).get("/api/work-orders/summary");

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveProperty("byStatus");
    expect(res.body.data).toHaveProperty("byPriority");
    expect(res.body.data).toHaveProperty("total");
    expect(res.body.data.total).toBe(1);
  });

  test("PATCH /api/work-orders/:id/status should update status", async () => {
    const wo = await WorkOrder.create({
      workOrderId: "WO-STATUS-001",
      propertyId: savedProperty._id,
      title: "Status Update Test",
      category: "general",
      priority: "low",
      estimatedDurationMinutes: 30,
      property: {
        location: { type: "Point", coordinates: [-97.7431, 30.2672] },
      },
    });

    const res = await request(app)
      .patch(`/api/work-orders/${wo._id}/status`)
      .send({ status: "completed" });

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveProperty("status", "completed");
    expect(res.body.data).toHaveProperty("completedAt");
  });
});

// ---------------------------------------------------------------------------
// Route Management Tests
// ---------------------------------------------------------------------------
describe("Route Routes", () => {
  test("GET /api/routes/date/:date should return routes for a date", async () => {
    const today = new Date().toISOString().split("T")[0];
    const res = await request(app).get(`/api/routes/date/${today}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty("data");
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body).toHaveProperty("meta");
    expect(res.body.meta).toHaveProperty("date", today);
    expect(res.body.meta).toHaveProperty("count", 0);
  });

  test("GET /api/routes should return an empty array initially", async () => {
    const res = await request(app).get("/api/routes");

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(0);
    expect(res.body.meta.total).toBe(0);
  });

  test("GET /api/routes/:id should return 404 for non-existent route", async () => {
    const fakeId = new mongoose.Types.ObjectId();
    const res = await request(app).get(`/api/routes/${fakeId}`);

    expect(res.status).toBe(404);
    expect(res.body.error).toHaveProperty("code", "NOT_FOUND");
  });

  test("DELETE /api/routes/:id should return 404 for non-existent route", async () => {
    const fakeId = new mongoose.Types.ObjectId();
    const res = await request(app).delete(`/api/routes/${fakeId}`);

    expect(res.status).toBe(404);
  });
});

// ---------------------------------------------------------------------------
// Optimization Route Tests
// ---------------------------------------------------------------------------
describe("Optimization Routes", () => {
  test("GET /api/optimization/history should return empty list initially", async () => {
    const res = await request(app).get("/api/optimization/history");

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(0);
    expect(res.body.meta.total).toBe(0);
  });

  test("GET /api/optimization/status/:runId should return 404 for non-existent run", async () => {
    const res = await request(app).get("/api/optimization/status/RUN-NONEXIST");

    expect(res.status).toBe(404);
    expect(res.body.error).toHaveProperty("code", "NOT_FOUND");
  });

  test("POST /api/optimization/run should require date field", async () => {
    const res = await request(app).post("/api/optimization/run").send({});

    expect(res.status).toBe(400);
    expect(res.body.error).toHaveProperty("code", "VALIDATION_ERROR");
  });

  test("POST /api/optimization/run should reject invalid algorithm", async () => {
    const res = await request(app).post("/api/optimization/run").send({
      date: "2026-03-15",
      algorithm: "invalid_algo",
    });

    expect(res.status).toBe(400);
    expect(res.body.error).toHaveProperty("code", "VALIDATION_ERROR");
  });
});

// ---------------------------------------------------------------------------
// 404 Handler Tests
// ---------------------------------------------------------------------------
describe("404 Handler", () => {
  test("Undefined routes should return 404", async () => {
    const res = await request(app).get("/api/nonexistent");

    expect(res.status).toBe(404);
    expect(res.body.error).toHaveProperty("code", "NOT_FOUND");
  });
});

// ---------------------------------------------------------------------------
// Pagination Tests
// ---------------------------------------------------------------------------
describe("Pagination", () => {
  test("Should reject invalid page parameter", async () => {
    const res = await request(app).get("/api/properties?page=-1");

    expect(res.status).toBe(400);
    expect(res.body.error).toHaveProperty("code", "VALIDATION_ERROR");
  });

  test("Should reject limit exceeding maximum", async () => {
    const res = await request(app).get("/api/properties?limit=500");

    expect(res.status).toBe(400);
    expect(res.body.error).toHaveProperty("code", "VALIDATION_ERROR");
  });

  test("Should accept valid pagination parameters", async () => {
    const res = await request(app).get("/api/properties?page=1&limit=10");

    expect(res.status).toBe(200);
    expect(res.body.meta).toHaveProperty("page", 1);
    expect(res.body.meta).toHaveProperty("limit", 10);
  });
});
