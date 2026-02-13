/**
 * OptimizationRun Model
 * Represents an execution of the route optimization engine
 */

const mongoose = require("mongoose");
const { Schema } = mongoose;

const algorithmResultSchema = new Schema(
  {
    algorithm: {
      type: String,
      enum: {
        values: ["vrp", "greedy", "genetic"],
        message: "{VALUE} is not a valid algorithm",
      },
      required: true,
    },
    totalDistanceMiles: {
      type: Number,
      min: 0,
    },
    totalDurationMinutes: {
      type: Number,
      min: 0,
    },
    totalRoutes: {
      type: Number,
      min: 0,
    },
    unassignedWorkOrders: {
      type: Number,
      min: 0,
      default: 0,
    },
    avgUtilizationPercent: {
      type: Number,
      min: 0,
      max: 100,
    },
    computeTimeMs: {
      type: Number,
      min: 0,
    },
  },
  { _id: false },
);

const optimizationRunSchema = new Schema(
  {
    runId: {
      type: String,
      required: [true, "Run ID is required"],
      unique: true,
      trim: true,
      index: true,
    },
    status: {
      type: String,
      enum: {
        values: ["pending", "running", "completed", "failed"],
        message: "{VALUE} is not a valid status",
      },
      required: [true, "Status is required"],
      default: "pending",
      index: true,
    },
    algorithm: {
      type: String,
      enum: {
        values: ["vrp", "greedy", "genetic", "all"],
        message: "{VALUE} is not a valid algorithm",
      },
      required: [true, "Algorithm is required"],
      default: "vrp",
    },
    optimizationDate: {
      type: Date,
      required: [true, "Optimization date is required"],
      index: true,
    },
    config: {
      maxTimeSeconds: {
        type: Number,
        min: 1,
        default: 300,
      },
      maxDistanceMiles: {
        type: Number,
        min: 1,
      },
      maxStopsPerRoute: {
        type: Number,
        min: 1,
      },
      balanceWorkload: {
        type: Boolean,
        default: true,
      },
    },
    input: {
      workOrderCount: {
        type: Number,
        min: 0,
        default: 0,
      },
      technicianCount: {
        type: Number,
        min: 0,
        default: 0,
      },
    },
    results: {
      type: [algorithmResultSchema],
      default: [],
    },
    routesCreated: {
      type: Number,
      min: 0,
      default: 0,
    },
    workOrdersAssigned: {
      type: Number,
      min: 0,
      default: 0,
    },
    workOrdersUnassigned: {
      type: Number,
      min: 0,
      default: 0,
    },
    startedAt: {
      type: Date,
    },
    completedAt: {
      type: Date,
    },
    durationMs: {
      type: Number,
      min: 0,
    },
    error: {
      message: {
        type: String,
        trim: true,
      },
      stack: {
        type: String,
        trim: true,
      },
    },
    triggeredBy: {
      type: String,
      trim: true,
      default: "system",
    },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  },
);

// Indexes
optimizationRunSchema.index({ status: 1, createdAt: -1 });
optimizationRunSchema.index({ optimizationDate: 1, algorithm: 1 });

// Virtual for duration in seconds
optimizationRunSchema.virtual("durationSeconds").get(function () {
  return this.durationMs ? this.durationMs / 1000 : null;
});

// Virtual for assignment rate
optimizationRunSchema.virtual("assignmentRate").get(function () {
  const total = this.workOrdersAssigned + this.workOrdersUnassigned;
  return total > 0 ? (this.workOrdersAssigned / total) * 100 : 0;
});

// Instance method to mark as running
optimizationRunSchema.methods.markRunning = function () {
  this.status = "running";
  this.startedAt = new Date();
  return this.save();
};

// Instance method to mark as completed
optimizationRunSchema.methods.markCompleted = function (resultData) {
  this.status = "completed";
  this.completedAt = new Date();
  this.durationMs = this.startedAt
    ? this.completedAt.getTime() - this.startedAt.getTime()
    : 0;
  if (resultData) {
    Object.assign(this, resultData);
  }
  return this.save();
};

// Instance method to mark as failed
optimizationRunSchema.methods.markFailed = function (error) {
  this.status = "failed";
  this.completedAt = new Date();
  this.durationMs = this.startedAt
    ? this.completedAt.getTime() - this.startedAt.getTime()
    : 0;
  this.error = {
    message: error.message || String(error),
    stack: error.stack || "",
  };
  return this.save();
};

// Static method to find recent runs
optimizationRunSchema.statics.findRecent = function (limit = 20) {
  return this.find().sort({ createdAt: -1 }).limit(limit);
};

// Static method to find runs by date
optimizationRunSchema.statics.findByDate = function (date) {
  const startOfDay = new Date(date);
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date(date);
  endOfDay.setHours(23, 59, 59, 999);

  return this.find({
    optimizationDate: { $gte: startOfDay, $lte: endOfDay },
  }).sort({ createdAt: -1 });
};

const OptimizationRun = mongoose.model(
  "OptimizationRun",
  optimizationRunSchema,
);

module.exports = OptimizationRun;
