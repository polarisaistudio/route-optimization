/**
 * Route Model
 * Represents optimized routes assigned to technicians with multiple stops
 */

const mongoose = require('mongoose');
const { Schema } = mongoose;

const stopSchema = new Schema(
  {
    sequence: {
      type: Number,
      required: [true, 'Stop sequence is required'],
      min: [1, 'Sequence must be at least 1'],
    },
    workOrderId: {
      type: Schema.Types.ObjectId,
      ref: 'WorkOrder',
      required: [true, 'Work order reference is required'],
    },
    propertyId: {
      type: Schema.Types.ObjectId,
      ref: 'Property',
      required: [true, 'Property reference is required'],
    },
    location: {
      type: {
        type: String,
        enum: ['Point'],
        default: 'Point',
      },
      coordinates: {
        type: [Number],
        required: [true, 'Stop coordinates are required'],
        validate: {
          validator: function (coords) {
            return (
              coords.length === 2 &&
              coords[0] >= -180 &&
              coords[0] <= 180 &&
              coords[1] >= -90 &&
              coords[1] <= 90
            );
          },
          message: 'Invalid coordinates. Format: [longitude, latitude]',
        },
      },
    },
    arrivalTime: {
      type: Date,
      required: [true, 'Arrival time is required'],
    },
    departureTime: {
      type: Date,
      required: [true, 'Departure time is required'],
      validate: {
        validator: function (depTime) {
          return depTime > this.arrivalTime;
        },
        message: 'Departure time must be after arrival time',
      },
    },
    travelDistanceMiles: {
      type: Number,
      required: [true, 'Travel distance is required'],
      min: [0, 'Travel distance cannot be negative'],
    },
    travelDurationMinutes: {
      type: Number,
      required: [true, 'Travel duration is required'],
      min: [0, 'Travel duration cannot be negative'],
    },
    workOrder: {
      title: {
        type: String,
        required: true,
        trim: true,
      },
      category: {
        type: String,
        enum: ['hvac', 'plumbing', 'electrical', 'general', 'inspection'],
        required: true,
      },
      priority: {
        type: String,
        enum: ['emergency', 'high', 'medium', 'low'],
        required: true,
      },
      estimatedDurationMinutes: {
        type: Number,
        required: true,
        min: 1,
      },
    },
  },
  { _id: false }
);

const summarySchema = new Schema(
  {
    totalDistanceMiles: {
      type: Number,
      required: [true, 'Total distance is required'],
      min: [0, 'Total distance cannot be negative'],
    },
    totalDurationMinutes: {
      type: Number,
      required: [true, 'Total duration is required'],
      min: [0, 'Total duration cannot be negative'],
    },
    totalWorkMinutes: {
      type: Number,
      required: [true, 'Total work time is required'],
      min: [0, 'Total work time cannot be negative'],
    },
    totalTravelMinutes: {
      type: Number,
      required: [true, 'Total travel time is required'],
      min: [0, 'Total travel time cannot be negative'],
    },
    numStops: {
      type: Number,
      required: [true, 'Number of stops is required'],
      min: [0, 'Number of stops cannot be negative'],
    },
    utilizationPercent: {
      type: Number,
      required: [true, 'Utilization percentage is required'],
      min: [0, 'Utilization cannot be negative'],
      max: [100, 'Utilization cannot exceed 100%'],
    },
  },
  { _id: false }
);

const routeSchema = new Schema(
  {
    routeId: {
      type: String,
      required: [true, 'Route ID is required'],
      unique: true,
      trim: true,
      index: true,
    },
    optimizationRunId: {
      type: Schema.Types.ObjectId,
      ref: 'OptimizationRun',
      required: [true, 'Optimization run reference is required'],
      index: true,
    },
    technicianId: {
      type: Schema.Types.ObjectId,
      ref: 'Technician',
      required: [true, 'Technician reference is required'],
      index: true,
    },
    technicianName: {
      type: String,
      required: [true, 'Technician name is required (denormalized)'],
      trim: true,
    },
    routeDate: {
      type: Date,
      required: [true, 'Route date is required'],
      index: true,
    },
    stops: {
      type: [stopSchema],
      validate: {
        validator: function (stops) {
          if (stops.length === 0) return true;
          // Validate sequence numbers are consecutive starting from 1
          const sequences = stops.map((s) => s.sequence).sort((a, b) => a - b);
          return sequences.every((seq, idx) => seq === idx + 1);
        },
        message: 'Stop sequences must be consecutive starting from 1',
      },
    },
    summary: {
      type: summarySchema,
      required: [true, 'Route summary is required'],
    },
    algorithmUsed: {
      type: String,
      enum: {
        values: ['vrp', 'greedy', 'genetic'],
        message: '{VALUE} is not a valid algorithm',
      },
      required: [true, 'Algorithm is required'],
      index: true,
    },
    status: {
      type: String,
      enum: {
        values: ['planned', 'active', 'completed'],
        message: '{VALUE} is not a valid route status',
      },
      required: [true, 'Route status is required'],
      default: 'planned',
      index: true,
    },
    routeGeometry: {
      type: {
        type: String,
        enum: ['LineString'],
      },
      coordinates: {
        type: [[Number]],
        validate: {
          validator: function (coords) {
            return coords.every(
              (point) =>
                point.length === 2 &&
                point[0] >= -180 &&
                point[0] <= 180 &&
                point[1] >= -90 &&
                point[1] <= 90
            );
          },
          message: 'Invalid LineString coordinates',
        },
      },
    },
    startTime: {
      type: Date,
    },
    endTime: {
      type: Date,
    },
    notes: {
      type: String,
      trim: true,
      maxlength: [1000, 'Notes cannot exceed 1000 characters'],
    },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

// Indexes
routeSchema.index({ routeDate: 1, technicianId: 1 });
routeSchema.index({ optimizationRunId: 1, status: 1 });
routeSchema.index({ status: 1, routeDate: 1 });
routeSchema.index({ technicianId: 1, status: 1, routeDate: -1 });

// Virtual for total duration in hours
routeSchema.virtual('totalDurationHours').get(function () {
  return this.summary.totalDurationMinutes / 60;
});

// Virtual for average time per stop
routeSchema.virtual('avgTimePerStop').get(function () {
  return this.summary.numStops > 0
    ? this.summary.totalDurationMinutes / this.summary.numStops
    : 0;
});

// Virtual for efficiency score (work time vs total time)
routeSchema.virtual('efficiencyScore').get(function () {
  return this.summary.totalDurationMinutes > 0
    ? (this.summary.totalWorkMinutes / this.summary.totalDurationMinutes) * 100
    : 0;
});

// Virtual for distance per stop
routeSchema.virtual('avgDistancePerStop').get(function () {
  return this.summary.numStops > 0
    ? this.summary.totalDistanceMiles / this.summary.numStops
    : 0;
});

// Instance method to add a stop
routeSchema.methods.addStop = function (stopData) {
  const sequence = this.stops.length + 1;
  this.stops.push({ ...stopData, sequence });
  return this;
};

// Instance method to remove a stop by sequence
routeSchema.methods.removeStop = function (sequence) {
  this.stops = this.stops.filter((stop) => stop.sequence !== sequence);
  // Resequence remaining stops
  this.stops.forEach((stop, idx) => {
    stop.sequence = idx + 1;
  });
  return this;
};

// Instance method to reorder stops
routeSchema.methods.reorderStops = function (newOrder) {
  // newOrder is an array of workOrderIds in desired sequence
  const orderedStops = newOrder.map((workOrderId, idx) => {
    const stop = this.stops.find((s) => s.workOrderId.toString() === workOrderId.toString());
    if (stop) {
      stop.sequence = idx + 1;
      return stop;
    }
    return null;
  }).filter(Boolean);

  this.stops = orderedStops;
  return this;
};

// Instance method to calculate and update summary
routeSchema.methods.updateSummary = function () {
  const totalDistanceMiles = this.stops.reduce(
    (sum, stop) => sum + stop.travelDistanceMiles,
    0
  );
  const totalTravelMinutes = this.stops.reduce(
    (sum, stop) => sum + stop.travelDurationMinutes,
    0
  );
  const totalWorkMinutes = this.stops.reduce(
    (sum, stop) => sum + stop.workOrder.estimatedDurationMinutes,
    0
  );
  const totalDurationMinutes = totalTravelMinutes + totalWorkMinutes;
  const numStops = this.stops.length;

  // Calculate utilization (work time / total time * 100)
  const utilizationPercent =
    totalDurationMinutes > 0 ? (totalWorkMinutes / totalDurationMinutes) * 100 : 0;

  this.summary = {
    totalDistanceMiles,
    totalDurationMinutes,
    totalWorkMinutes,
    totalTravelMinutes,
    numStops,
    utilizationPercent,
  };

  return this;
};

// Instance method to mark route as active
routeSchema.methods.activate = function () {
  this.status = 'active';
  this.startTime = new Date();
  return this.save();
};

// Instance method to mark route as completed
routeSchema.methods.complete = function () {
  this.status = 'completed';
  this.endTime = new Date();
  return this.save();
};

// Static method to find routes by technician
routeSchema.statics.findByTechnician = function (technicianId, startDate, endDate) {
  const query = { technicianId };
  if (startDate || endDate) {
    query.routeDate = {};
    if (startDate) query.routeDate.$gte = startDate;
    if (endDate) query.routeDate.$lte = endDate;
  }
  return this.find(query).sort({ routeDate: -1 });
};

// Static method to find routes by date
routeSchema.statics.findByDate = function (date) {
  const startOfDay = new Date(date);
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date(date);
  endOfDay.setHours(23, 59, 59, 999);

  return this.find({
    routeDate: { $gte: startOfDay, $lte: endOfDay },
  });
};

// Static method to find active routes
routeSchema.statics.findActive = function () {
  return this.find({ status: 'active' });
};

// Static method to find routes by optimization run
routeSchema.statics.findByOptimizationRun = function (optimizationRunId) {
  return this.find({ optimizationRunId });
};

// Static method to get performance statistics
routeSchema.statics.getPerformanceStats = function (startDate, endDate) {
  return this.aggregate([
    {
      $match: {
        routeDate: { $gte: startDate, $lte: endDate },
        status: 'completed',
      },
    },
    {
      $group: {
        _id: null,
        avgDistance: { $avg: '$summary.totalDistanceMiles' },
        avgDuration: { $avg: '$summary.totalDurationMinutes' },
        avgUtilization: { $avg: '$summary.utilizationPercent' },
        avgStops: { $avg: '$summary.numStops' },
        totalRoutes: { $sum: 1 },
      },
    },
  ]);
};

// Pre-save middleware to auto-update summary
routeSchema.pre('save', function (next) {
  if (this.isModified('stops')) {
    this.updateSummary();
  }
  next();
});

// Pre-save middleware to validate stops sequence
routeSchema.pre('save', function (next) {
  if (this.stops.length > 0) {
    // Sort stops by sequence
    this.stops.sort((a, b) => a.sequence - b.sequence);
  }
  next();
});

const Route = mongoose.model('Route', routeSchema);

module.exports = Route;
