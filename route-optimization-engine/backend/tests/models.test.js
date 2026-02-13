/**
 * Model & Middleware Tests
 * Unit tests for Mongoose models, virtuals, methods, pre-save hooks,
 * authentication middleware, and error handler middleware.
 */

const mongoose = require("mongoose");
const { MongoMemoryServer } = require("mongodb-memory-server");
const jwt = require("jsonwebtoken");

// Set test environment before loading modules that read config
process.env.NODE_ENV = "test";

const Property = require("../src/models/Property");
const Technician = require("../src/models/Technician");
const WorkOrder = require("../src/models/WorkOrder");
const Route = require("../src/models/Route");
const OptimizationRun = require("../src/models/OptimizationRun");
const { authenticate, authorize } = require("../src/middleware/auth");
const {
  errorHandler,
  notFoundHandler,
} = require("../src/middleware/errorHandler");

// ---------------------------------------------------------------------------
// Setup / Teardown
// ---------------------------------------------------------------------------
let mongoServer;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  const mongoUri = mongoServer.getUri();
  await mongoose.connect(mongoUri);
}, 30000);

afterAll(async () => {
  if (mongoose.connection.readyState === 1) await mongoose.disconnect();
  if (mongoServer) await mongoServer.stop();
}, 15000);

beforeEach(async () => {
  const collections = mongoose.connection.collections;
  for (const key in collections) {
    await collections[key].deleteMany({});
  }
});

// ---------------------------------------------------------------------------
// Test Data Helpers
// ---------------------------------------------------------------------------
const validProperty = () => ({
  propertyId: "PROP-001",
  address: "123 Main St",
  city: "Austin",
  state: "TX",
  zipCode: "78701",
  location: { type: "Point", coordinates: [-97.7431, 30.2672] },
  propertyType: "residential",
});

const validTechnician = () => ({
  technicianId: "TECH-001",
  name: "Jane Doe",
  email: "jane@example.com",
  phone: "512-555-1234",
  homeBase: { type: "Point", coordinates: [-97.7431, 30.2672] },
  skills: ["hvac", "plumbing"],
  maxDailyHours: 8,
  maxDailyDistanceMiles: 150,
  hourlyRate: 50,
  availabilityStatus: "available",
});

const validWorkOrder = (propertyObjectId) => ({
  workOrderId: "WO-001",
  propertyId: propertyObjectId || new mongoose.Types.ObjectId(),
  property: {
    location: { type: "Point", coordinates: [-97.7431, 30.2672] },
    address: "123 Main St",
    city: "Austin",
    state: "TX",
    zipCode: "78701",
  },
  title: "Fix HVAC unit",
  category: "hvac",
  priority: "medium",
  estimatedDurationMinutes: 60,
});

const validOptimizationRun = () => ({
  runId: "RUN-001",
  status: "pending",
  algorithm: "vrp",
  optimizationDate: new Date("2026-03-15"),
});

const validRoute = (techId, runId) => ({
  routeId: "ROUTE-001",
  optimizationRunId: runId || new mongoose.Types.ObjectId(),
  technicianId: techId || new mongoose.Types.ObjectId(),
  technicianName: "Jane Doe",
  routeDate: new Date("2026-03-15"),
  stops: [],
  summary: {
    totalDistanceMiles: 0,
    totalDurationMinutes: 0,
    totalWorkMinutes: 0,
    totalTravelMinutes: 0,
    numStops: 0,
    utilizationPercent: 0,
  },
  algorithmUsed: "vrp",
  status: "planned",
});

// Helpers for middleware tests
const mockReq = (overrides = {}) => ({
  headers: {},
  ip: "127.0.0.1",
  path: "/test",
  method: "GET",
  originalUrl: "/test",
  ...overrides,
});

const mockRes = () => {
  const res = {
    status: jest.fn().mockReturnThis(),
    json: jest.fn().mockReturnThis(),
  };
  return res;
};

const JWT_SECRET = "dev-secret-change-in-production";
const JWT_ISSUER = "route-optimization-api";

const createToken = (payload = {}, options = {}) => {
  const defaults = {
    sub: "user-1",
    email: "test@example.com",
    name: "Test User",
    roles: ["admin"],
  };
  return jwt.sign({ ...defaults, ...payload }, JWT_SECRET, {
    issuer: JWT_ISSUER,
    algorithm: "HS256",
    expiresIn: "1h",
    ...options,
  });
};

// =========================================================================
// PROPERTY MODEL TESTS
// =========================================================================
describe("Property Model", () => {
  // -----------------------------------------------------------------------
  // Required field validation
  // -----------------------------------------------------------------------
  describe("required field validation", () => {
    test("should fail without propertyId", async () => {
      const data = validProperty();
      delete data.propertyId;
      const doc = new Property(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.propertyId).toBeDefined();
    });

    test("should fail without address", async () => {
      const data = validProperty();
      delete data.address;
      const doc = new Property(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.address).toBeDefined();
    });

    test("should fail without city", async () => {
      const data = validProperty();
      delete data.city;
      const doc = new Property(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.city).toBeDefined();
    });

    test("should fail without state", async () => {
      const data = validProperty();
      delete data.state;
      const doc = new Property(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.state).toBeDefined();
    });

    test("should fail without zipCode", async () => {
      const data = validProperty();
      delete data.zipCode;
      const doc = new Property(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.zipCode).toBeDefined();
    });

    test("should fail without location coordinates", async () => {
      const data = validProperty();
      delete data.location;
      const doc = new Property(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });

    test("should fail without propertyType", async () => {
      const data = validProperty();
      delete data.propertyType;
      const doc = new Property(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.propertyType).toBeDefined();
    });

    test("should save successfully with all required fields", async () => {
      const doc = await Property.create(validProperty());
      expect(doc._id).toBeDefined();
      expect(doc.propertyId).toBe("PROP-001");
    });
  });

  // -----------------------------------------------------------------------
  // Field format validation
  // -----------------------------------------------------------------------
  describe("field format validation", () => {
    test("should enforce state uppercase and maxlength 2", async () => {
      const data = validProperty();
      data.state = "tx";
      const doc = await Property.create(data);
      expect(doc.state).toBe("TX");

      const data2 = validProperty();
      data2.propertyId = "PROP-002";
      data2.state = "TXA";
      const doc2 = new Property(data2);
      const err = doc2.validateSync();
      expect(err).toBeDefined();
    });

    test("should reject invalid zipCode format", async () => {
      const data = validProperty();
      data.zipCode = "ABCDE";
      const doc = new Property(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.zipCode).toBeDefined();
    });

    test("should accept valid 5-digit zipCode", async () => {
      const data = validProperty();
      data.zipCode = "90210";
      const doc = new Property(data);
      const err = doc.validateSync();
      expect(err).toBeUndefined();
    });

    test("should accept valid 9-digit zipCode", async () => {
      const data = validProperty();
      data.zipCode = "78701-1234";
      const doc = new Property(data);
      const err = doc.validateSync();
      expect(err).toBeUndefined();
    });

    test("should reject invalid zipCode like 1234", async () => {
      const data = validProperty();
      data.zipCode = "1234";
      const doc = new Property(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.zipCode).toBeDefined();
    });
  });

  // -----------------------------------------------------------------------
  // Enum validation
  // -----------------------------------------------------------------------
  describe("enum validation", () => {
    test("should reject invalid propertyType", async () => {
      const data = validProperty();
      data.propertyType = "farm";
      const doc = new Property(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.propertyType).toBeDefined();
    });

    test.each(["residential", "commercial", "industrial"])(
      'should accept propertyType "%s"',
      async (type) => {
        const data = validProperty();
        data.propertyType = type;
        const doc = new Property(data);
        const err = doc.validateSync();
        expect(err).toBeUndefined();
      },
    );
  });

  // -----------------------------------------------------------------------
  // Optional fields
  // -----------------------------------------------------------------------
  describe("optional fields", () => {
    test("should accept zoneId", async () => {
      const data = { ...validProperty(), zoneId: "ZONE-A" };
      const doc = await Property.create(data);
      expect(doc.zoneId).toBe("ZONE-A");
    });

    test("should accept squareFootage >= 0", async () => {
      const data = { ...validProperty(), squareFootage: 1500 };
      const doc = await Property.create(data);
      expect(doc.squareFootage).toBe(1500);
    });

    test("should reject negative squareFootage", async () => {
      const data = { ...validProperty(), squareFootage: -1 };
      const doc = new Property(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });

    test("should accept accessNotes up to 1000 chars", async () => {
      const data = { ...validProperty(), accessNotes: "Gate code 1234" };
      const doc = await Property.create(data);
      expect(doc.accessNotes).toBe("Gate code 1234");
    });

    test("should reject accessNotes exceeding 1000 chars", async () => {
      const data = { ...validProperty(), accessNotes: "x".repeat(1001) };
      const doc = new Property(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });
  });

  // -----------------------------------------------------------------------
  // Unique constraint
  // -----------------------------------------------------------------------
  describe("unique constraint", () => {
    test("should reject duplicate propertyId", async () => {
      await Property.create(validProperty());
      await expect(Property.create(validProperty())).rejects.toThrow();
    });
  });

  // -----------------------------------------------------------------------
  // Coordinate validation
  // -----------------------------------------------------------------------
  describe("coordinate validation", () => {
    test("should reject longitude out of range", async () => {
      const data = validProperty();
      data.location.coordinates = [181, 30];
      const doc = new Property(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });

    test("should reject latitude out of range", async () => {
      const data = validProperty();
      data.location.coordinates = [-97, 91];
      const doc = new Property(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });

    test("should accept boundary coordinates [-180, -90]", async () => {
      const data = validProperty();
      data.location.coordinates = [-180, -90];
      const doc = new Property(data);
      const err = doc.validateSync();
      expect(err).toBeUndefined();
    });

    test("should accept boundary coordinates [180, 90]", async () => {
      const data = validProperty();
      data.location.coordinates = [180, 90];
      const doc = new Property(data);
      const err = doc.validateSync();
      expect(err).toBeUndefined();
    });
  });

  // -----------------------------------------------------------------------
  // Pre-save middleware
  // -----------------------------------------------------------------------
  describe("pre-save coordinate validation", () => {
    test("should reject out-of-range coordinates on save", async () => {
      const data = validProperty();
      data.location.coordinates = [-181, 30];
      const doc = new Property(data);
      await expect(doc.save()).rejects.toThrow();
    });
  });

  // -----------------------------------------------------------------------
  // Virtuals
  // -----------------------------------------------------------------------
  describe("virtuals", () => {
    test("fullAddress should return formatted address", async () => {
      const doc = await Property.create(validProperty());
      expect(doc.fullAddress).toBe("123 Main St, Austin, TX 78701");
    });

    test("longitude should return location.coordinates[0]", async () => {
      const doc = await Property.create(validProperty());
      expect(doc.longitude).toBe(-97.7431);
    });

    test("latitude should return location.coordinates[1]", async () => {
      const doc = await Property.create(validProperty());
      expect(doc.latitude).toBe(30.2672);
    });

    test("longitude should return null when location is missing", () => {
      const doc = new Property({});
      expect(doc.longitude).toBeNull();
    });

    test("latitude should return null when location is missing", () => {
      const doc = new Property({});
      expect(doc.latitude).toBeNull();
    });
  });

  // -----------------------------------------------------------------------
  // Instance methods
  // -----------------------------------------------------------------------
  describe("distanceTo()", () => {
    test("should return 0 for same location", async () => {
      const doc = await Property.create(validProperty());
      const dist = doc.distanceTo(-97.7431, 30.2672);
      expect(dist).toBeCloseTo(0, 1);
    });

    test("should return reasonable distance to another point", async () => {
      const doc = await Property.create(validProperty());
      // Dallas is roughly 195 miles from Austin
      const dist = doc.distanceTo(-96.797, 32.7767);
      expect(dist).toBeGreaterThan(150);
      expect(dist).toBeLessThan(250);
    });
  });

  // -----------------------------------------------------------------------
  // Static methods
  // -----------------------------------------------------------------------
  describe("findByZone()", () => {
    test("should return properties matching the zone", async () => {
      await Property.create({ ...validProperty(), zoneId: "ZONE-A" });
      await Property.create({
        ...validProperty(),
        propertyId: "PROP-002",
        zoneId: "ZONE-B",
      });

      const results = await Property.findByZone("ZONE-A");
      expect(results).toHaveLength(1);
      expect(results[0].zoneId).toBe("ZONE-A");
    });

    test("should return empty array when no properties match", async () => {
      const results = await Property.findByZone("ZONE-NONE");
      expect(results).toHaveLength(0);
    });
  });
});

// =========================================================================
// TECHNICIAN MODEL TESTS
// =========================================================================
describe("Technician Model", () => {
  // -----------------------------------------------------------------------
  // Required field validation
  // -----------------------------------------------------------------------
  describe("required field validation", () => {
    test("should fail without technicianId", async () => {
      const data = validTechnician();
      delete data.technicianId;
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.technicianId).toBeDefined();
    });

    test("should fail without name", async () => {
      const data = validTechnician();
      delete data.name;
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.name).toBeDefined();
    });

    test("should fail without email", async () => {
      const data = validTechnician();
      delete data.email;
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.email).toBeDefined();
    });

    test("should fail without phone", async () => {
      const data = validTechnician();
      delete data.phone;
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.phone).toBeDefined();
    });

    test("should fail without homeBase coordinates", async () => {
      const data = validTechnician();
      delete data.homeBase;
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });

    test("should fail without skills", async () => {
      const data = validTechnician();
      data.skills = [];
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.skills).toBeDefined();
    });

    test("should fail without hourlyRate", async () => {
      const data = validTechnician();
      delete data.hourlyRate;
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.hourlyRate).toBeDefined();
    });

    test("should save successfully with all required fields", async () => {
      const doc = await Technician.create(validTechnician());
      expect(doc._id).toBeDefined();
      expect(doc.technicianId).toBe("TECH-001");
    });
  });

  // -----------------------------------------------------------------------
  // Name length validation
  // -----------------------------------------------------------------------
  describe("name length validation", () => {
    test("should reject name shorter than 2 characters", async () => {
      const data = validTechnician();
      data.name = "A";
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.name).toBeDefined();
    });

    test("should reject name longer than 100 characters", async () => {
      const data = validTechnician();
      data.name = "A".repeat(101);
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.name).toBeDefined();
    });

    test("should accept name of 2 characters", async () => {
      const data = validTechnician();
      data.name = "Al";
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeUndefined();
    });
  });

  // -----------------------------------------------------------------------
  // Email validation
  // -----------------------------------------------------------------------
  describe("email validation", () => {
    test("should reject invalid email", async () => {
      const data = validTechnician();
      data.email = "not-an-email";
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.email).toBeDefined();
    });

    test("should lowercased email on save", async () => {
      const data = validTechnician();
      data.email = "JANE@EXAMPLE.COM";
      const doc = await Technician.create(data);
      expect(doc.email).toBe("jane@example.com");
    });

    test("should reject duplicate email", async () => {
      await Technician.create(validTechnician());
      const data2 = validTechnician();
      data2.technicianId = "TECH-002";
      await expect(Technician.create(data2)).rejects.toThrow();
    });
  });

  // -----------------------------------------------------------------------
  // Phone validation
  // -----------------------------------------------------------------------
  describe("phone validation", () => {
    test("should reject invalid phone format", async () => {
      const data = validTechnician();
      data.phone = "123";
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.phone).toBeDefined();
    });

    test("should accept valid phone formats", async () => {
      const data = validTechnician();
      data.phone = "5125551234";
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeUndefined();
    });
  });

  // -----------------------------------------------------------------------
  // Skills validation
  // -----------------------------------------------------------------------
  describe("skills validation", () => {
    test("should reject invalid skill values", async () => {
      const data = validTechnician();
      data.skills = ["carpentry"];
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.skills).toBeDefined();
    });

    test.each(["hvac", "plumbing", "electrical", "general", "inspection"])(
      'should accept valid skill "%s"',
      async (skill) => {
        const data = validTechnician();
        data.skills = [skill];
        const doc = new Technician(data);
        const err = doc.validateSync();
        expect(err).toBeUndefined();
      },
    );
  });

  // -----------------------------------------------------------------------
  // Numeric field ranges
  // -----------------------------------------------------------------------
  describe("numeric field ranges", () => {
    test("should reject maxDailyHours < 1", async () => {
      const data = validTechnician();
      data.maxDailyHours = 0;
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });

    test("should reject maxDailyHours > 24", async () => {
      const data = validTechnician();
      data.maxDailyHours = 25;
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });

    test("should reject maxDailyDistanceMiles < 1", async () => {
      const data = validTechnician();
      data.maxDailyDistanceMiles = 0;
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });

    test("should reject maxDailyDistanceMiles > 500", async () => {
      const data = validTechnician();
      data.maxDailyDistanceMiles = 501;
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });

    test("should reject negative hourlyRate", async () => {
      const data = validTechnician();
      data.hourlyRate = -1;
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });

    test("should apply default maxDailyHours of 8", async () => {
      const data = validTechnician();
      delete data.maxDailyHours;
      const doc = await Technician.create(data);
      expect(doc.maxDailyHours).toBe(8);
    });

    test("should apply default maxDailyDistanceMiles of 150", async () => {
      const data = validTechnician();
      delete data.maxDailyDistanceMiles;
      const doc = await Technician.create(data);
      expect(doc.maxDailyDistanceMiles).toBe(150);
    });

    test("should apply default availabilityStatus of available", async () => {
      const data = validTechnician();
      delete data.availabilityStatus;
      const doc = await Technician.create(data);
      expect(doc.availabilityStatus).toBe("available");
    });
  });

  // -----------------------------------------------------------------------
  // Enum validation
  // -----------------------------------------------------------------------
  describe("availabilityStatus enum", () => {
    test("should reject invalid status", async () => {
      const data = validTechnician();
      data.availabilityStatus = "sleeping";
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.availabilityStatus).toBeDefined();
    });

    test.each(["available", "on_route", "off_duty", "on_leave"])(
      'should accept status "%s"',
      async (status) => {
        const data = validTechnician();
        data.availabilityStatus = status;
        const doc = new Technician(data);
        const err = doc.validateSync();
        expect(err).toBeUndefined();
      },
    );
  });

  // -----------------------------------------------------------------------
  // Pre-save middleware (dedup)
  // -----------------------------------------------------------------------
  describe("pre-save deduplication", () => {
    test("should deduplicate skills array", async () => {
      const data = validTechnician();
      data.skills = ["hvac", "hvac", "plumbing", "plumbing"];
      const doc = await Technician.create(data);
      expect(doc.skills).toEqual(["hvac", "plumbing"]);
    });

    test("should deduplicate zonePreference array", async () => {
      const data = validTechnician();
      data.zonePreference = ["ZONE-A", "ZONE-A", "ZONE-B"];
      const doc = await Technician.create(data);
      expect(doc.zonePreference).toEqual(["ZONE-A", "ZONE-B"]);
    });
  });

  // -----------------------------------------------------------------------
  // Virtuals
  // -----------------------------------------------------------------------
  describe("virtuals", () => {
    test("homeBaseLongitude should return coordinates[0]", async () => {
      const doc = await Technician.create(validTechnician());
      expect(doc.homeBaseLongitude).toBe(-97.7431);
    });

    test("homeBaseLatitude should return coordinates[1]", async () => {
      const doc = await Technician.create(validTechnician());
      expect(doc.homeBaseLatitude).toBe(30.2672);
    });

    test("capacityInfo should return maxHours, maxDistance, hourlyRate", async () => {
      const doc = await Technician.create(validTechnician());
      expect(doc.capacityInfo).toEqual({
        maxHours: 8,
        maxDistance: 150,
        hourlyRate: 50,
      });
    });
  });

  // -----------------------------------------------------------------------
  // Instance methods
  // -----------------------------------------------------------------------
  describe("hasSkills()", () => {
    test("should return true when technician has all required skills", async () => {
      const doc = await Technician.create(validTechnician());
      expect(doc.hasSkills(["hvac"])).toBe(true);
      expect(doc.hasSkills(["hvac", "plumbing"])).toBe(true);
    });

    test("should return false when technician lacks a required skill", async () => {
      const doc = await Technician.create(validTechnician());
      expect(doc.hasSkills(["electrical"])).toBe(false);
      expect(doc.hasSkills(["hvac", "electrical"])).toBe(false);
    });

    test("should return true for empty or null requiredSkills", async () => {
      const doc = await Technician.create(validTechnician());
      expect(doc.hasSkills([])).toBe(true);
      expect(doc.hasSkills(null)).toBe(true);
      expect(doc.hasSkills(undefined)).toBe(true);
    });
  });

  describe("isAvailable()", () => {
    test("should return true when status is available", async () => {
      const doc = await Technician.create(validTechnician());
      expect(doc.isAvailable()).toBe(true);
    });

    test("should return false when status is not available", async () => {
      const data = validTechnician();
      data.availabilityStatus = "on_route";
      const doc = await Technician.create(data);
      expect(doc.isAvailable()).toBe(false);
    });
  });

  describe("distanceFromHome()", () => {
    test("should return 0 for same location", async () => {
      const doc = await Technician.create(validTechnician());
      const dist = doc.distanceFromHome(-97.7431, 30.2672);
      expect(dist).toBeCloseTo(0, 1);
    });

    test("should return reasonable distance to another point", async () => {
      const doc = await Technician.create(validTechnician());
      // Houston is roughly 165 miles from Austin
      const dist = doc.distanceFromHome(-95.3698, 29.7604);
      expect(dist).toBeGreaterThan(140);
      expect(dist).toBeLessThan(200);
    });
  });
});

// =========================================================================
// WORK ORDER MODEL TESTS
// =========================================================================
describe("WorkOrder Model", () => {
  let savedProperty;

  beforeEach(async () => {
    savedProperty = await Property.create(validProperty());
  });

  // -----------------------------------------------------------------------
  // Required field validation
  // -----------------------------------------------------------------------
  describe("required field validation", () => {
    test("should fail without workOrderId", async () => {
      const data = validWorkOrder(savedProperty._id);
      delete data.workOrderId;
      const doc = new WorkOrder(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.workOrderId).toBeDefined();
    });

    test("should fail without propertyId", async () => {
      const data = validWorkOrder(savedProperty._id);
      delete data.propertyId;
      const doc = new WorkOrder(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.propertyId).toBeDefined();
    });

    test("should fail without title", async () => {
      const data = validWorkOrder(savedProperty._id);
      delete data.title;
      const doc = new WorkOrder(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.title).toBeDefined();
    });

    test("should fail without category", async () => {
      const data = validWorkOrder(savedProperty._id);
      delete data.category;
      const doc = new WorkOrder(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.category).toBeDefined();
    });

    test("should fail without estimatedDurationMinutes", async () => {
      const data = validWorkOrder(savedProperty._id);
      delete data.estimatedDurationMinutes;
      const doc = new WorkOrder(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.estimatedDurationMinutes).toBeDefined();
    });

    test("should fail without property location coordinates", async () => {
      const data = validWorkOrder(savedProperty._id);
      delete data.property.location.coordinates;
      const doc = new WorkOrder(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });

    test("should save successfully with all required fields", async () => {
      const doc = await WorkOrder.create(validWorkOrder(savedProperty._id));
      expect(doc._id).toBeDefined();
      expect(doc.workOrderId).toBe("WO-001");
    });
  });

  // -----------------------------------------------------------------------
  // Enum validation
  // -----------------------------------------------------------------------
  describe("enum validation", () => {
    test("should reject invalid category", async () => {
      const data = validWorkOrder(savedProperty._id);
      data.category = "landscaping";
      const doc = new WorkOrder(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.category).toBeDefined();
    });

    test.each(["hvac", "plumbing", "electrical", "general", "inspection"])(
      'should accept category "%s"',
      async (cat) => {
        const data = validWorkOrder(savedProperty._id);
        data.category = cat;
        const doc = new WorkOrder(data);
        const err = doc.validateSync();
        expect(err).toBeUndefined();
      },
    );

    test("should reject invalid priority", async () => {
      const data = validWorkOrder(savedProperty._id);
      data.priority = "urgent";
      const doc = new WorkOrder(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.priority).toBeDefined();
    });

    test.each(["emergency", "high", "medium", "low"])(
      'should accept priority "%s"',
      async (p) => {
        const data = validWorkOrder(savedProperty._id);
        data.priority = p;
        const doc = new WorkOrder(data);
        const err = doc.validateSync();
        expect(err).toBeUndefined();
      },
    );

    test("should reject invalid status", async () => {
      const data = validWorkOrder(savedProperty._id);
      data.status = "unknown";
      const doc = new WorkOrder(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.status).toBeDefined();
    });

    test.each(["pending", "assigned", "in_progress", "completed", "cancelled"])(
      'should accept status "%s"',
      async (s) => {
        const data = validWorkOrder(savedProperty._id);
        data.status = s;
        const doc = new WorkOrder(data);
        const err = doc.validateSync();
        expect(err).toBeUndefined();
      },
    );
  });

  // -----------------------------------------------------------------------
  // Duration limits
  // -----------------------------------------------------------------------
  describe("estimatedDurationMinutes limits", () => {
    test("should reject duration < 1", async () => {
      const data = validWorkOrder(savedProperty._id);
      data.estimatedDurationMinutes = 0;
      const doc = new WorkOrder(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });

    test("should reject duration > 960", async () => {
      const data = validWorkOrder(savedProperty._id);
      data.estimatedDurationMinutes = 961;
      const doc = new WorkOrder(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });

    test("should accept duration at boundary 1", async () => {
      const data = validWorkOrder(savedProperty._id);
      data.estimatedDurationMinutes = 1;
      const doc = new WorkOrder(data);
      const err = doc.validateSync();
      expect(err).toBeUndefined();
    });

    test("should accept duration at boundary 960", async () => {
      const data = validWorkOrder(savedProperty._id);
      data.estimatedDurationMinutes = 960;
      const doc = new WorkOrder(data);
      const err = doc.validateSync();
      expect(err).toBeUndefined();
    });
  });

  // -----------------------------------------------------------------------
  // Title validation
  // -----------------------------------------------------------------------
  describe("title validation", () => {
    test("should reject title exceeding 200 characters", async () => {
      const data = validWorkOrder(savedProperty._id);
      data.title = "T".repeat(201);
      const doc = new WorkOrder(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.title).toBeDefined();
    });
  });

  // -----------------------------------------------------------------------
  // Default values
  // -----------------------------------------------------------------------
  describe("default values", () => {
    test("should default priority to medium", async () => {
      const data = validWorkOrder(savedProperty._id);
      delete data.priority;
      const doc = await WorkOrder.create(data);
      expect(doc.priority).toBe("medium");
    });

    test("should default status to pending", async () => {
      const data = validWorkOrder(savedProperty._id);
      const doc = await WorkOrder.create(data);
      expect(doc.status).toBe("pending");
    });
  });

  // -----------------------------------------------------------------------
  // Virtuals
  // -----------------------------------------------------------------------
  describe("virtuals", () => {
    test("priorityWeight should return correct weight for each priority", async () => {
      const weights = { emergency: 100, high: 75, medium: 50, low: 25 };

      for (const [priority, expected] of Object.entries(weights)) {
        const data = validWorkOrder(savedProperty._id);
        data.workOrderId = `WO-PW-${priority}`;
        data.priority = priority;
        const doc = await WorkOrder.create(data);
        expect(doc.priorityWeight).toBe(expected);
      }
    });

    test("estimatedDurationHours should convert minutes to hours", async () => {
      const data = validWorkOrder(savedProperty._id);
      data.estimatedDurationMinutes = 90;
      const doc = await WorkOrder.create(data);
      expect(doc.estimatedDurationHours).toBe(1.5);
    });

    test("hasTimeWindow should return true when both start and end are set", async () => {
      const data = validWorkOrder(savedProperty._id);
      data.timeWindowStart = new Date("2026-03-15T08:00:00Z");
      data.timeWindowEnd = new Date("2026-03-15T12:00:00Z");
      const doc = await WorkOrder.create(data);
      expect(doc.hasTimeWindow).toBe(true);
    });

    test("hasTimeWindow should return false when missing time fields", async () => {
      const doc = await WorkOrder.create(validWorkOrder(savedProperty._id));
      expect(doc.hasTimeWindow).toBe(false);
    });

    test("coordinates should return property location coordinates", async () => {
      const doc = await WorkOrder.create(validWorkOrder(savedProperty._id));
      expect(doc.coordinates).toEqual([-97.7431, 30.2672]);
    });
  });

  // -----------------------------------------------------------------------
  // Instance methods
  // -----------------------------------------------------------------------
  describe("isAssignable()", () => {
    test("should return true when status is pending", async () => {
      const doc = await WorkOrder.create(validWorkOrder(savedProperty._id));
      expect(doc.isAssignable()).toBe(true);
    });

    test("should return false when status is assigned", async () => {
      const data = validWorkOrder(savedProperty._id);
      data.status = "assigned";
      const doc = await WorkOrder.create(data);
      expect(doc.isAssignable()).toBe(false);
    });

    test("should return false when status is completed", async () => {
      const data = validWorkOrder(savedProperty._id);
      data.status = "completed";
      const doc = await WorkOrder.create(data);
      expect(doc.isAssignable()).toBe(false);
    });
  });

  describe("canBeHandledBy()", () => {
    test("should return true when technician has all required skills", async () => {
      const doc = await WorkOrder.create(validWorkOrder(savedProperty._id));
      // Pre-save assigns ['hvac'] since category is hvac
      const tech = { skills: ["hvac", "plumbing"] };
      expect(doc.canBeHandledBy(tech)).toBe(true);
    });

    test("should return false when technician lacks required skills", async () => {
      const doc = await WorkOrder.create(validWorkOrder(savedProperty._id));
      const tech = { skills: ["plumbing"] };
      expect(doc.canBeHandledBy(tech)).toBe(false);
    });

    test("should return true when requiredSkills is empty", async () => {
      const data = validWorkOrder(savedProperty._id);
      data.category = "general";
      data.requiredSkills = [];
      const doc = await WorkOrder.create(data);
      // For 'general' category with empty requiredSkills, pre-save does NOT auto-assign
      expect(doc.canBeHandledBy({ skills: [] })).toBe(true);
    });
  });

  describe("isWithinTimeWindow()", () => {
    test("should return true when no time window is set", async () => {
      const doc = await WorkOrder.create(validWorkOrder(savedProperty._id));
      const t = new Date("2026-03-15T10:00:00Z");
      expect(doc.isWithinTimeWindow(t)).toBe(true);
    });

    test("should return true when scheduled time is within window", async () => {
      const data = validWorkOrder(savedProperty._id);
      data.timeWindowStart = new Date("2026-03-15T08:00:00Z");
      data.timeWindowEnd = new Date("2026-03-15T12:00:00Z");
      const doc = await WorkOrder.create(data);
      expect(doc.isWithinTimeWindow(new Date("2026-03-15T10:00:00Z"))).toBe(
        true,
      );
    });

    test("should return false when scheduled time is outside window", async () => {
      const data = validWorkOrder(savedProperty._id);
      data.timeWindowStart = new Date("2026-03-15T08:00:00Z");
      data.timeWindowEnd = new Date("2026-03-15T12:00:00Z");
      const doc = await WorkOrder.create(data);
      expect(doc.isWithinTimeWindow(new Date("2026-03-15T13:00:00Z"))).toBe(
        false,
      );
    });

    test("should return true at exact start boundary", async () => {
      const data = validWorkOrder(savedProperty._id);
      data.timeWindowStart = new Date("2026-03-15T08:00:00Z");
      data.timeWindowEnd = new Date("2026-03-15T12:00:00Z");
      const doc = await WorkOrder.create(data);
      expect(doc.isWithinTimeWindow(new Date("2026-03-15T08:00:00Z"))).toBe(
        true,
      );
    });
  });

  describe("assignTo()", () => {
    test("should set technicianId, routeId, and status to assigned", async () => {
      const doc = await WorkOrder.create(validWorkOrder(savedProperty._id));
      const techId = new mongoose.Types.ObjectId();
      const routeId = new mongoose.Types.ObjectId();
      const saved = await doc.assignTo(techId, routeId);
      expect(saved.status).toBe("assigned");
      expect(saved.assignedTechnicianId.toString()).toBe(techId.toString());
      expect(saved.assignedRouteId.toString()).toBe(routeId.toString());
    });
  });

  describe("complete()", () => {
    test("should set status to completed and record completedAt", async () => {
      const doc = await WorkOrder.create(validWorkOrder(savedProperty._id));
      const saved = await doc.complete();
      expect(saved.status).toBe("completed");
      expect(saved.completedAt).toBeDefined();
      expect(saved.completedAt).toBeInstanceOf(Date);
    });
  });

  describe("cancel()", () => {
    test("should set status to cancelled and record reason", async () => {
      const doc = await WorkOrder.create(validWorkOrder(savedProperty._id));
      const saved = await doc.cancel("Customer request");
      expect(saved.status).toBe("cancelled");
      expect(saved.cancelledAt).toBeInstanceOf(Date);
      expect(saved.cancellationReason).toBe("Customer request");
    });

    test("should work without a reason", async () => {
      const doc = await WorkOrder.create(validWorkOrder(savedProperty._id));
      const saved = await doc.cancel();
      expect(saved.status).toBe("cancelled");
      expect(saved.cancelledAt).toBeInstanceOf(Date);
      expect(saved.cancellationReason).toBeUndefined();
    });
  });

  // -----------------------------------------------------------------------
  // Pre-save middleware
  // -----------------------------------------------------------------------
  describe("pre-save requiredSkills auto-assign", () => {
    test("should auto-assign requiredSkills from category when not provided", async () => {
      const data = validWorkOrder(savedProperty._id);
      delete data.requiredSkills;
      data.category = "plumbing";
      const doc = await WorkOrder.create(data);
      expect(doc.requiredSkills).toEqual(["plumbing"]);
    });

    test("should NOT auto-assign requiredSkills for general category", async () => {
      const data = validWorkOrder(savedProperty._id);
      data.category = "general";
      delete data.requiredSkills;
      const doc = await WorkOrder.create(data);
      expect(doc.requiredSkills).toEqual([]);
    });

    test("should not override explicitly provided requiredSkills", async () => {
      const data = validWorkOrder(savedProperty._id);
      data.requiredSkills = ["electrical", "plumbing"];
      const doc = await WorkOrder.create(data);
      expect(doc.requiredSkills).toEqual(["electrical", "plumbing"]);
    });
  });

  // -----------------------------------------------------------------------
  // Unique constraint
  // -----------------------------------------------------------------------
  describe("unique constraint", () => {
    test("should reject duplicate workOrderId", async () => {
      await WorkOrder.create(validWorkOrder(savedProperty._id));
      await expect(
        WorkOrder.create(validWorkOrder(savedProperty._id)),
      ).rejects.toThrow();
    });
  });
});

// =========================================================================
// ROUTE MODEL TESTS
// =========================================================================
describe("Route Model", () => {
  // -----------------------------------------------------------------------
  // Required field validation
  // -----------------------------------------------------------------------
  describe("required field validation", () => {
    test("should fail without routeId", async () => {
      const data = validRoute();
      delete data.routeId;
      const doc = new Route(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.routeId).toBeDefined();
    });

    test("should fail without optimizationRunId", async () => {
      const data = validRoute();
      delete data.optimizationRunId;
      const doc = new Route(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.optimizationRunId).toBeDefined();
    });

    test("should fail without technicianId", async () => {
      const data = validRoute();
      delete data.technicianId;
      const doc = new Route(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.technicianId).toBeDefined();
    });

    test("should fail without technicianName", async () => {
      const data = validRoute();
      delete data.technicianName;
      const doc = new Route(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.technicianName).toBeDefined();
    });

    test("should fail without routeDate", async () => {
      const data = validRoute();
      delete data.routeDate;
      const doc = new Route(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.routeDate).toBeDefined();
    });

    test("should fail without summary", async () => {
      const data = validRoute();
      delete data.summary;
      const doc = new Route(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });

    test("should fail without algorithmUsed", async () => {
      const data = validRoute();
      delete data.algorithmUsed;
      const doc = new Route(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.algorithmUsed).toBeDefined();
    });

    test("should save successfully with all required fields", async () => {
      const doc = await Route.create(validRoute());
      expect(doc._id).toBeDefined();
      expect(doc.routeId).toBe("ROUTE-001");
    });
  });

  // -----------------------------------------------------------------------
  // Enum validation
  // -----------------------------------------------------------------------
  describe("enum validation", () => {
    test("should reject invalid algorithmUsed", async () => {
      const data = validRoute();
      data.algorithmUsed = "random";
      const doc = new Route(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.algorithmUsed).toBeDefined();
    });

    test.each(["vrp", "greedy", "genetic"])(
      'should accept algorithmUsed "%s"',
      async (alg) => {
        const data = validRoute();
        data.algorithmUsed = alg;
        const doc = new Route(data);
        const err = doc.validateSync();
        expect(err).toBeUndefined();
      },
    );

    test("should reject invalid status", async () => {
      const data = validRoute();
      data.status = "paused";
      const doc = new Route(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.status).toBeDefined();
    });

    test.each(["planned", "active", "completed"])(
      'should accept status "%s"',
      async (s) => {
        const data = validRoute();
        data.status = s;
        const doc = new Route(data);
        const err = doc.validateSync();
        expect(err).toBeUndefined();
      },
    );
  });

  // -----------------------------------------------------------------------
  // Virtuals
  // -----------------------------------------------------------------------
  describe("virtuals", () => {
    test("totalDurationHours should convert minutes to hours", async () => {
      // Pre-save recalculates summary from stops, so we update summary
      // via findOneAndUpdate to bypass the pre-save hook.
      const doc = await Route.create(validRoute());
      await Route.updateOne(
        { _id: doc._id },
        { $set: { "summary.totalDurationMinutes": 120 } },
      );
      const fetched = await Route.findById(doc._id);
      expect(fetched.totalDurationHours).toBe(2);
    });

    test("avgTimePerStop should return average or 0 for no stops", async () => {
      const doc = await Route.create(validRoute());
      await Route.updateOne(
        { _id: doc._id },
        {
          $set: { "summary.totalDurationMinutes": 120, "summary.numStops": 4 },
        },
      );
      const fetched = await Route.findById(doc._id);
      expect(fetched.avgTimePerStop).toBe(30);
    });

    test("avgTimePerStop should return 0 when numStops is 0", async () => {
      const doc = await Route.create(validRoute());
      expect(doc.avgTimePerStop).toBe(0);
    });

    test("efficiencyScore should return work vs total ratio", async () => {
      const doc = await Route.create(validRoute());
      await Route.updateOne(
        { _id: doc._id },
        {
          $set: {
            "summary.totalWorkMinutes": 60,
            "summary.totalDurationMinutes": 120,
          },
        },
      );
      const fetched = await Route.findById(doc._id);
      expect(fetched.efficiencyScore).toBe(50);
    });

    test("efficiencyScore should return 0 when totalDuration is 0", async () => {
      const doc = await Route.create(validRoute());
      expect(doc.efficiencyScore).toBe(0);
    });

    test("avgDistancePerStop should return average or 0", async () => {
      const doc = await Route.create(validRoute());
      await Route.updateOne(
        { _id: doc._id },
        { $set: { "summary.totalDistanceMiles": 100, "summary.numStops": 5 } },
      );
      const fetched = await Route.findById(doc._id);
      expect(fetched.avgDistancePerStop).toBe(20);
    });

    test("avgDistancePerStop should return 0 when numStops is 0", async () => {
      const doc = await Route.create(validRoute());
      expect(doc.avgDistancePerStop).toBe(0);
    });
  });

  // -----------------------------------------------------------------------
  // Instance methods
  // -----------------------------------------------------------------------
  describe("activate()", () => {
    test("should set status to active and record startTime", async () => {
      const doc = await Route.create(validRoute());
      const saved = await doc.activate();
      expect(saved.status).toBe("active");
      expect(saved.startTime).toBeInstanceOf(Date);
    });
  });

  describe("complete()", () => {
    test("should set status to completed and record endTime", async () => {
      const doc = await Route.create(validRoute());
      const saved = await doc.complete();
      expect(saved.status).toBe("completed");
      expect(saved.endTime).toBeInstanceOf(Date);
    });
  });

  describe("addStop()", () => {
    test("should add a stop with correct sequence", async () => {
      const doc = await Route.create(validRoute());
      const stopData = {
        workOrderId: new mongoose.Types.ObjectId(),
        propertyId: new mongoose.Types.ObjectId(),
        location: { type: "Point", coordinates: [-97.74, 30.26] },
        arrivalTime: new Date("2026-03-15T09:00:00Z"),
        departureTime: new Date("2026-03-15T10:00:00Z"),
        travelDistanceMiles: 5,
        travelDurationMinutes: 10,
        workOrder: {
          title: "Fix AC",
          category: "hvac",
          priority: "medium",
          estimatedDurationMinutes: 50,
        },
      };
      doc.addStop(stopData);
      expect(doc.stops).toHaveLength(1);
      expect(doc.stops[0].sequence).toBe(1);
    });
  });

  describe("removeStop()", () => {
    test("should remove a stop and resequence", async () => {
      const doc = await Route.create(validRoute());
      const makeStop = (seq) => ({
        sequence: seq,
        workOrderId: new mongoose.Types.ObjectId(),
        propertyId: new mongoose.Types.ObjectId(),
        location: { type: "Point", coordinates: [-97.74, 30.26] },
        arrivalTime: new Date("2026-03-15T09:00:00Z"),
        departureTime: new Date("2026-03-15T10:00:00Z"),
        travelDistanceMiles: 5,
        travelDurationMinutes: 10,
        workOrder: {
          title: `Stop ${seq}`,
          category: "hvac",
          priority: "medium",
          estimatedDurationMinutes: 30,
        },
      });
      doc.stops.push(makeStop(1), makeStop(2), makeStop(3));
      doc.removeStop(2);
      expect(doc.stops).toHaveLength(2);
      expect(doc.stops[0].sequence).toBe(1);
      expect(doc.stops[1].sequence).toBe(2);
    });
  });

  // -----------------------------------------------------------------------
  // Unique constraint
  // -----------------------------------------------------------------------
  describe("unique constraint", () => {
    test("should reject duplicate routeId", async () => {
      await Route.create(validRoute());
      await expect(Route.create(validRoute())).rejects.toThrow();
    });
  });

  // -----------------------------------------------------------------------
  // Default values
  // -----------------------------------------------------------------------
  describe("default values", () => {
    test("should default status to planned", async () => {
      const data = validRoute();
      delete data.status;
      const doc = await Route.create(data);
      expect(doc.status).toBe("planned");
    });
  });
});

// =========================================================================
// OPTIMIZATION RUN MODEL TESTS
// =========================================================================
describe("OptimizationRun Model", () => {
  // -----------------------------------------------------------------------
  // Required field validation
  // -----------------------------------------------------------------------
  describe("required field validation", () => {
    test("should fail without runId", async () => {
      const data = validOptimizationRun();
      delete data.runId;
      const doc = new OptimizationRun(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.runId).toBeDefined();
    });

    test("should fail without optimizationDate", async () => {
      const data = validOptimizationRun();
      delete data.optimizationDate;
      const doc = new OptimizationRun(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.optimizationDate).toBeDefined();
    });

    test("should save successfully with all required fields", async () => {
      const doc = await OptimizationRun.create(validOptimizationRun());
      expect(doc._id).toBeDefined();
      expect(doc.runId).toBe("RUN-001");
    });
  });

  // -----------------------------------------------------------------------
  // Enum validation
  // -----------------------------------------------------------------------
  describe("enum validation", () => {
    test("should reject invalid status", async () => {
      const data = validOptimizationRun();
      data.status = "paused";
      const doc = new OptimizationRun(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.status).toBeDefined();
    });

    test.each(["pending", "running", "completed", "failed"])(
      'should accept status "%s"',
      async (s) => {
        const data = validOptimizationRun();
        data.status = s;
        const doc = new OptimizationRun(data);
        const err = doc.validateSync();
        expect(err).toBeUndefined();
      },
    );

    test("should reject invalid algorithm", async () => {
      const data = validOptimizationRun();
      data.algorithm = "brute_force";
      const doc = new OptimizationRun(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.algorithm).toBeDefined();
    });

    test.each(["vrp", "greedy", "genetic", "all"])(
      'should accept algorithm "%s"',
      async (alg) => {
        const data = validOptimizationRun();
        data.algorithm = alg;
        const doc = new OptimizationRun(data);
        const err = doc.validateSync();
        expect(err).toBeUndefined();
      },
    );
  });

  // -----------------------------------------------------------------------
  // Default values
  // -----------------------------------------------------------------------
  describe("default values", () => {
    test("should default status to pending", async () => {
      const data = validOptimizationRun();
      delete data.status;
      const doc = await OptimizationRun.create(data);
      expect(doc.status).toBe("pending");
    });

    test("should default algorithm to vrp", async () => {
      const data = validOptimizationRun();
      delete data.algorithm;
      const doc = await OptimizationRun.create(data);
      expect(doc.algorithm).toBe("vrp");
    });

    test("should default config.maxTimeSeconds to 300", async () => {
      const doc = await OptimizationRun.create(validOptimizationRun());
      expect(doc.config.maxTimeSeconds).toBe(300);
    });

    test("should default config.balanceWorkload to true", async () => {
      const doc = await OptimizationRun.create(validOptimizationRun());
      expect(doc.config.balanceWorkload).toBe(true);
    });

    test("should default input counts to 0", async () => {
      const doc = await OptimizationRun.create(validOptimizationRun());
      expect(doc.input.workOrderCount).toBe(0);
      expect(doc.input.technicianCount).toBe(0);
    });

    test("should default triggeredBy to system", async () => {
      const doc = await OptimizationRun.create(validOptimizationRun());
      expect(doc.triggeredBy).toBe("system");
    });
  });

  // -----------------------------------------------------------------------
  // Virtuals
  // -----------------------------------------------------------------------
  describe("virtuals", () => {
    test("durationSeconds should return durationMs / 1000", async () => {
      const data = validOptimizationRun();
      const doc = await OptimizationRun.create(data);
      doc.durationMs = 5000;
      expect(doc.durationSeconds).toBe(5);
    });

    test("durationSeconds should return null when durationMs is not set", async () => {
      const doc = await OptimizationRun.create(validOptimizationRun());
      expect(doc.durationSeconds).toBeNull();
    });

    test("assignmentRate should return percentage of assigned work orders", async () => {
      const data = validOptimizationRun();
      const doc = await OptimizationRun.create(data);
      doc.workOrdersAssigned = 8;
      doc.workOrdersUnassigned = 2;
      expect(doc.assignmentRate).toBe(80);
    });

    test("assignmentRate should return 0 when no work orders", async () => {
      const doc = await OptimizationRun.create(validOptimizationRun());
      expect(doc.assignmentRate).toBe(0);
    });
  });

  // -----------------------------------------------------------------------
  // Instance methods
  // -----------------------------------------------------------------------
  describe("markRunning()", () => {
    test("should set status to running and record startedAt", async () => {
      const doc = await OptimizationRun.create(validOptimizationRun());
      const saved = await doc.markRunning();
      expect(saved.status).toBe("running");
      expect(saved.startedAt).toBeInstanceOf(Date);
    });
  });

  describe("markCompleted()", () => {
    test("should set status to completed and calculate duration", async () => {
      const doc = await OptimizationRun.create(validOptimizationRun());
      doc.startedAt = new Date(Date.now() - 5000);
      await doc.save();
      const saved = await doc.markCompleted({
        routesCreated: 5,
        workOrdersAssigned: 10,
      });
      expect(saved.status).toBe("completed");
      expect(saved.completedAt).toBeInstanceOf(Date);
      expect(saved.durationMs).toBeGreaterThanOrEqual(0);
      expect(saved.routesCreated).toBe(5);
      expect(saved.workOrdersAssigned).toBe(10);
    });

    test("should set durationMs to 0 if startedAt is not set", async () => {
      const doc = await OptimizationRun.create(validOptimizationRun());
      const saved = await doc.markCompleted();
      expect(saved.status).toBe("completed");
      expect(saved.durationMs).toBe(0);
    });
  });

  describe("markFailed()", () => {
    test("should set status to failed and record error details", async () => {
      const doc = await OptimizationRun.create(validOptimizationRun());
      doc.startedAt = new Date(Date.now() - 3000);
      await doc.save();
      const err = new Error("Optimization timed out");
      const saved = await doc.markFailed(err);
      expect(saved.status).toBe("failed");
      expect(saved.completedAt).toBeInstanceOf(Date);
      expect(saved.durationMs).toBeGreaterThanOrEqual(0);
      expect(saved.error.message).toBe("Optimization timed out");
      expect(saved.error.stack).toBeDefined();
    });

    test("should handle string error", async () => {
      const doc = await OptimizationRun.create(validOptimizationRun());
      const saved = await doc.markFailed("Something went wrong");
      expect(saved.status).toBe("failed");
      expect(saved.error.message).toBe("Something went wrong");
    });
  });

  // -----------------------------------------------------------------------
  // Unique constraint
  // -----------------------------------------------------------------------
  describe("unique constraint", () => {
    test("should reject duplicate runId", async () => {
      await OptimizationRun.create(validOptimizationRun());
      await expect(
        OptimizationRun.create(validOptimizationRun()),
      ).rejects.toThrow();
    });
  });

  // -----------------------------------------------------------------------
  // Config validation
  // -----------------------------------------------------------------------
  describe("config field validation", () => {
    test("should accept custom config values", async () => {
      const data = validOptimizationRun();
      data.config = {
        maxTimeSeconds: 600,
        maxDistanceMiles: 200,
        maxStopsPerRoute: 15,
        balanceWorkload: false,
      };
      const doc = await OptimizationRun.create(data);
      expect(doc.config.maxTimeSeconds).toBe(600);
      expect(doc.config.maxDistanceMiles).toBe(200);
      expect(doc.config.maxStopsPerRoute).toBe(15);
      expect(doc.config.balanceWorkload).toBe(false);
    });
  });
});

// =========================================================================
// AUTH MIDDLEWARE TESTS
// =========================================================================
describe("Auth Middleware", () => {
  // -----------------------------------------------------------------------
  // authenticate()
  // -----------------------------------------------------------------------
  describe("authenticate()", () => {
    test("should return 401 when no Authorization header is present", async () => {
      const req = mockReq();
      const res = mockRes();
      const next = jest.fn();

      await authenticate(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.objectContaining({
            code: "UNAUTHORIZED",
            message: "Authorization header is required",
          }),
        }),
      );
      expect(next).not.toHaveBeenCalled();
    });

    test("should return 401 when Authorization header does not use Bearer scheme", async () => {
      const req = mockReq({ headers: { authorization: "Basic abc123" } });
      const res = mockRes();
      const next = jest.fn();

      await authenticate(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.objectContaining({
            code: "UNAUTHORIZED",
            message: "Authorization header must use Bearer scheme",
          }),
        }),
      );
      expect(next).not.toHaveBeenCalled();
    });

    test("should return 401 for an invalid JWT token", async () => {
      const req = mockReq({
        headers: { authorization: "Bearer invalid.token.here" },
      });
      const res = mockRes();
      const next = jest.fn();

      await authenticate(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.objectContaining({
            code: "INVALID_TOKEN",
          }),
        }),
      );
      expect(next).not.toHaveBeenCalled();
    });

    test("should return 401 for an expired JWT token", async () => {
      const expiredToken = jwt.sign(
        {
          sub: "user-1",
          email: "test@example.com",
          name: "Test",
          roles: ["admin"],
        },
        JWT_SECRET,
        { issuer: JWT_ISSUER, algorithm: "HS256", expiresIn: "-1s" },
      );
      const req = mockReq({
        headers: { authorization: `Bearer ${expiredToken}` },
      });
      const res = mockRes();
      const next = jest.fn();

      await authenticate(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.objectContaining({
            code: "TOKEN_EXPIRED",
          }),
        }),
      );
      expect(next).not.toHaveBeenCalled();
    });

    test("should return 401 for token signed with wrong secret", async () => {
      const badToken = jwt.sign(
        {
          sub: "user-1",
          email: "test@example.com",
          name: "Test",
          roles: ["admin"],
        },
        "wrong-secret",
        { issuer: JWT_ISSUER, algorithm: "HS256", expiresIn: "1h" },
      );
      const req = mockReq({ headers: { authorization: `Bearer ${badToken}` } });
      const res = mockRes();
      const next = jest.fn();

      await authenticate(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(next).not.toHaveBeenCalled();
    });

    test("should return 401 for token with wrong issuer", async () => {
      const badIssuerToken = jwt.sign(
        {
          sub: "user-1",
          email: "test@example.com",
          name: "Test",
          roles: ["admin"],
        },
        JWT_SECRET,
        { issuer: "wrong-issuer", algorithm: "HS256", expiresIn: "1h" },
      );
      const req = mockReq({
        headers: { authorization: `Bearer ${badIssuerToken}` },
      });
      const res = mockRes();
      const next = jest.fn();

      await authenticate(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(next).not.toHaveBeenCalled();
    });

    test("should attach req.user and call next() on valid token", async () => {
      const token = createToken();
      const req = mockReq({ headers: { authorization: `Bearer ${token}` } });
      const res = mockRes();
      const next = jest.fn();

      await authenticate(req, res, next);

      expect(next).toHaveBeenCalled();
      expect(req.user).toBeDefined();
      expect(req.user.id).toBe("user-1");
      expect(req.user.email).toBe("test@example.com");
      expect(req.user.name).toBe("Test User");
      expect(req.user.roles).toEqual(["admin"]);
    });

    test("should extract user id from sub claim", async () => {
      const token = createToken({ sub: "custom-id-123" });
      const req = mockReq({ headers: { authorization: `Bearer ${token}` } });
      const res = mockRes();
      const next = jest.fn();

      await authenticate(req, res, next);

      expect(next).toHaveBeenCalled();
      expect(req.user.id).toBe("custom-id-123");
    });

    test('should default roles to ["user"] when not in token', async () => {
      const tokenPayload = {
        sub: "user-1",
        email: "test@example.com",
        name: "Test",
      };
      const token = jwt.sign(tokenPayload, JWT_SECRET, {
        issuer: JWT_ISSUER,
        algorithm: "HS256",
        expiresIn: "1h",
      });
      const req = mockReq({ headers: { authorization: `Bearer ${token}` } });
      const res = mockRes();
      const next = jest.fn();

      await authenticate(req, res, next);

      expect(next).toHaveBeenCalled();
      expect(req.user.roles).toEqual(["user"]);
    });

    test("should return 401 for malformed Bearer header (missing token)", async () => {
      const req = mockReq({ headers: { authorization: "Bearer" } });
      const res = mockRes();
      const next = jest.fn();

      await authenticate(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(next).not.toHaveBeenCalled();
    });
  });

  // -----------------------------------------------------------------------
  // authorize()
  // -----------------------------------------------------------------------
  describe("authorize()", () => {
    test("should return 401 when req.user is not set", () => {
      const req = mockReq();
      const res = mockRes();
      const next = jest.fn();

      authorize(["admin"])(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.objectContaining({
            code: "UNAUTHORIZED",
          }),
        }),
      );
      expect(next).not.toHaveBeenCalled();
    });

    test("should return 403 when user does not have required role", () => {
      const req = mockReq({
        user: { id: "user-1", roles: ["user"] },
        path: "/test",
      });
      const res = mockRes();
      const next = jest.fn();

      authorize(["admin"])(req, res, next);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.objectContaining({
            code: "FORBIDDEN",
            message: "Insufficient permissions to access this resource",
          }),
        }),
      );
      expect(next).not.toHaveBeenCalled();
    });

    test("should call next() when user has the required role", () => {
      const req = mockReq({
        user: { id: "user-1", roles: ["admin"] },
        path: "/test",
      });
      const res = mockRes();
      const next = jest.fn();

      authorize(["admin"])(req, res, next);

      expect(next).toHaveBeenCalled();
    });

    test("should call next() when user has one of the required roles", () => {
      const req = mockReq({
        user: { id: "user-1", roles: ["editor"] },
        path: "/test",
      });
      const res = mockRes();
      const next = jest.fn();

      authorize(["admin", "editor"])(req, res, next);

      expect(next).toHaveBeenCalled();
    });

    test("should call next() when roles array is empty (no restriction)", () => {
      const req = mockReq({
        user: { id: "user-1", roles: ["user"] },
        path: "/test",
      });
      const res = mockRes();
      const next = jest.fn();

      authorize([])(req, res, next);

      expect(next).toHaveBeenCalled();
    });

    test("should call next() when authorize is called with no arguments", () => {
      const req = mockReq({
        user: { id: "user-1", roles: ["user"] },
        path: "/test",
      });
      const res = mockRes();
      const next = jest.fn();

      authorize()(req, res, next);

      expect(next).toHaveBeenCalled();
    });
  });
});

// =========================================================================
// ERROR HANDLER MIDDLEWARE TESTS
// =========================================================================
describe("Error Handler Middleware", () => {
  // -----------------------------------------------------------------------
  // errorHandler()
  // -----------------------------------------------------------------------
  describe("errorHandler()", () => {
    test("should handle Mongoose ValidationError (400, VALIDATION_ERROR)", () => {
      const err = new mongoose.Error.ValidationError();
      err.errors = {
        name: {
          message: "Name is required",
          value: undefined,
        },
      };

      const req = mockReq();
      const res = mockRes();
      const next = jest.fn();

      errorHandler(err, req, res, next);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.objectContaining({
            code: "VALIDATION_ERROR",
            message: "Request validation failed",
            details: expect.arrayContaining([
              expect.objectContaining({
                field: "name",
                message: "Name is required",
              }),
            ]),
          }),
        }),
      );
    });

    test("should handle Mongoose CastError (400, INVALID_ID)", () => {
      const err = new mongoose.Error.CastError("ObjectId", "bad-id", "_id");

      const req = mockReq();
      const res = mockRes();
      const next = jest.fn();

      errorHandler(err, req, res, next);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.objectContaining({
            code: "INVALID_ID",
          }),
        }),
      );
    });

    test("should handle MongoDB duplicate key error 11000 (409, DUPLICATE_KEY)", () => {
      const err = new Error(
        'E11000 duplicate key error collection: test.users index: email_1 dup key: { email: "test@example.com" }',
      );
      err.code = 11000;
      err.keyPattern = { email: 1 };

      const req = mockReq();
      const res = mockRes();
      const next = jest.fn();

      errorHandler(err, req, res, next);

      expect(res.status).toHaveBeenCalledWith(409);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.objectContaining({
            code: "DUPLICATE_KEY",
            message: "A record with the given unique field(s) already exists",
          }),
        }),
      );
    });

    test("should handle SyntaxError with status 400 (MALFORMED_JSON)", () => {
      const err = new SyntaxError("Unexpected token i in JSON at position 0");
      err.status = 400;
      err.body = "{ invalid json }";

      const req = mockReq();
      const res = mockRes();
      const next = jest.fn();

      errorHandler(err, req, res, next);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.objectContaining({
            code: "MALFORMED_JSON",
            message: "Request body contains invalid JSON",
          }),
        }),
      );
    });

    test("should handle custom errors with status < 500", () => {
      const err = new Error("Resource not found");
      err.status = 404;
      err.code = "NOT_FOUND";
      err.details = [{ id: "abc" }];

      const req = mockReq();
      const res = mockRes();
      const next = jest.fn();

      errorHandler(err, req, res, next);

      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.objectContaining({
            code: "NOT_FOUND",
            message: "Resource not found",
            details: [{ id: "abc" }],
          }),
        }),
      );
    });

    test("should default custom error code to CLIENT_ERROR when not specified", () => {
      const err = new Error("Something client-side");
      err.status = 422;

      const req = mockReq();
      const res = mockRes();
      const next = jest.fn();

      errorHandler(err, req, res, next);

      expect(res.status).toHaveBeenCalledWith(422);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.objectContaining({
            code: "CLIENT_ERROR",
            message: "Something client-side",
          }),
        }),
      );
    });

    test("should default to 500 for unknown errors", () => {
      const err = new Error("Something unexpected");

      const req = mockReq();
      const res = mockRes();
      const next = jest.fn();

      errorHandler(err, req, res, next);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.objectContaining({
            code: "INTERNAL_ERROR",
          }),
        }),
      );
    });

    test("should expose error message in non-production for 500 errors", () => {
      const err = new Error("Database connection failed");

      const req = mockReq();
      const res = mockRes();
      const next = jest.fn();

      errorHandler(err, req, res, next);

      expect(res.status).toHaveBeenCalledWith(500);
      // In test env (non-production), the actual message is exposed
      const body = res.json.mock.calls[0][0];
      expect(body.error.message).toBe("Database connection failed");
    });

    test("should handle duplicate key error with code 11001", () => {
      const err = new Error("E11001 duplicate key");
      err.code = 11001;

      const req = mockReq();
      const res = mockRes();
      const next = jest.fn();

      errorHandler(err, req, res, next);

      expect(res.status).toHaveBeenCalledWith(409);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.objectContaining({
            code: "DUPLICATE_KEY",
          }),
        }),
      );
    });

    test("should not treat regular SyntaxError without status 400 as MALFORMED_JSON", () => {
      const err = new SyntaxError("Unexpected identifier");
      // No status set - should fall through to 500

      const req = mockReq();
      const res = mockRes();
      const next = jest.fn();

      errorHandler(err, req, res, next);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.objectContaining({
            code: "INTERNAL_ERROR",
          }),
        }),
      );
    });
  });

  // -----------------------------------------------------------------------
  // notFoundHandler()
  // -----------------------------------------------------------------------
  describe("notFoundHandler()", () => {
    test("should return 404 with NOT_FOUND code", () => {
      const req = mockReq({ method: "GET", originalUrl: "/api/nonexistent" });
      const res = mockRes();

      notFoundHandler(req, res);

      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.objectContaining({
            code: "NOT_FOUND",
            message: "Route GET /api/nonexistent not found",
            details: [],
          }),
        }),
      );
    });

    test("should include the HTTP method and URL in the message", () => {
      const req = mockReq({ method: "POST", originalUrl: "/api/widgets" });
      const res = mockRes();

      notFoundHandler(req, res);

      const body = res.json.mock.calls[0][0];
      expect(body.error.message).toBe("Route POST /api/widgets not found");
    });
  });
});

// =========================================================================
// EDGE CASE TESTS
// =========================================================================
describe("Edge Cases", () => {
  describe("Property edge cases", () => {
    test("should handle squareFootage of exactly 0", async () => {
      const data = { ...validProperty(), squareFootage: 0 };
      const doc = await Property.create(data);
      expect(doc.squareFootage).toBe(0);
    });

    test("should trim whitespace from address fields", async () => {
      const data = validProperty();
      data.address = "  123 Main St  ";
      data.city = "  Austin  ";
      data.propertyId = "  PROP-TRIM  ";
      const doc = await Property.create(data);
      expect(doc.address).toBe("123 Main St");
      expect(doc.city).toBe("Austin");
      expect(doc.propertyId).toBe("PROP-TRIM");
    });
  });

  describe("Technician edge cases", () => {
    test("should handle hourlyRate of exactly 0", async () => {
      const data = validTechnician();
      data.hourlyRate = 0;
      const doc = await Technician.create(data);
      expect(doc.hourlyRate).toBe(0);
    });

    test("should default zonePreference to empty array", async () => {
      const data = validTechnician();
      delete data.zonePreference;
      const doc = await Technician.create(data);
      expect(doc.zonePreference).toEqual([]);
    });

    test("should handle boundary maxDailyHours value of 1", async () => {
      const data = validTechnician();
      data.maxDailyHours = 1;
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeUndefined();
    });

    test("should handle boundary maxDailyHours value of 24", async () => {
      const data = validTechnician();
      data.maxDailyHours = 24;
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeUndefined();
    });

    test("should handle boundary maxDailyDistanceMiles value of 500", async () => {
      const data = validTechnician();
      data.maxDailyDistanceMiles = 500;
      const doc = new Technician(data);
      const err = doc.validateSync();
      expect(err).toBeUndefined();
    });
  });

  describe("WorkOrder edge cases", () => {
    test("should reject requiredSkills with invalid values", async () => {
      const prop = await Property.create(validProperty());
      const data = validWorkOrder(prop._id);
      data.requiredSkills = ["carpentry"];
      const doc = new WorkOrder(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
      expect(err.errors.requiredSkills).toBeDefined();
    });

    test("should handle timeWindowEnd before timeWindowStart validation", async () => {
      const prop = await Property.create(validProperty());
      const data = validWorkOrder(prop._id);
      data.timeWindowStart = new Date("2026-03-15T12:00:00Z");
      data.timeWindowEnd = new Date("2026-03-15T08:00:00Z");
      const doc = new WorkOrder(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });

    test("should accept sourceSystem enum values", async () => {
      const prop = await Property.create(validProperty());

      for (const source of ["salesforce", "manual", "iot"]) {
        const data = validWorkOrder(prop._id);
        data.workOrderId = `WO-SRC-${source}`;
        data.sourceSystem = source;
        const doc = new WorkOrder(data);
        const err = doc.validateSync();
        expect(err).toBeUndefined();
      }
    });

    test("should reject invalid sourceSystem", async () => {
      const prop = await Property.create(validProperty());
      const data = validWorkOrder(prop._id);
      data.sourceSystem = "email";
      const doc = new WorkOrder(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });
  });

  describe("OptimizationRun edge cases", () => {
    test("should accept results array with valid algorithmResult entries", async () => {
      const data = validOptimizationRun();
      data.results = [
        {
          algorithm: "vrp",
          totalDistanceMiles: 120.5,
          totalDurationMinutes: 480,
          totalRoutes: 5,
          unassignedWorkOrders: 2,
          avgUtilizationPercent: 85,
          computeTimeMs: 1500,
        },
      ];
      const doc = await OptimizationRun.create(data);
      expect(doc.results).toHaveLength(1);
      expect(doc.results[0].algorithm).toBe("vrp");
      expect(doc.results[0].totalDistanceMiles).toBe(120.5);
    });

    test("should set custom triggeredBy value", async () => {
      const data = validOptimizationRun();
      data.triggeredBy = "admin-user";
      const doc = await OptimizationRun.create(data);
      expect(doc.triggeredBy).toBe("admin-user");
    });

    test("should include timestamps", async () => {
      const doc = await OptimizationRun.create(validOptimizationRun());
      expect(doc.createdAt).toBeInstanceOf(Date);
      expect(doc.updatedAt).toBeInstanceOf(Date);
    });
  });

  describe("Route edge cases", () => {
    test("should accept notes up to 1000 characters", async () => {
      const data = validRoute();
      data.notes = "A".repeat(1000);
      const doc = await Route.create(data);
      expect(doc.notes).toHaveLength(1000);
    });

    test("should reject notes exceeding 1000 characters", async () => {
      const data = validRoute();
      data.notes = "A".repeat(1001);
      const doc = new Route(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });

    test("should validate stops sequence is consecutive from 1", async () => {
      const data = validRoute();
      const makeStop = (seq) => ({
        sequence: seq,
        workOrderId: new mongoose.Types.ObjectId(),
        propertyId: new mongoose.Types.ObjectId(),
        location: { type: "Point", coordinates: [-97.74, 30.26] },
        arrivalTime: new Date("2026-03-15T09:00:00Z"),
        departureTime: new Date("2026-03-15T10:00:00Z"),
        travelDistanceMiles: 5,
        travelDurationMinutes: 10,
        workOrder: {
          title: `Stop ${seq}`,
          category: "hvac",
          priority: "medium",
          estimatedDurationMinutes: 30,
        },
      });
      data.stops = [makeStop(1), makeStop(3)]; // gap at 2
      const doc = new Route(data);
      const err = doc.validateSync();
      expect(err).toBeDefined();
    });

    test("should include timestamps on Route documents", async () => {
      const doc = await Route.create(validRoute());
      expect(doc.createdAt).toBeInstanceOf(Date);
      expect(doc.updatedAt).toBeInstanceOf(Date);
    });
  });
});
