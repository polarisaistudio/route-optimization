/**
 * WorkOrder Model
 * Represents service work orders that need to be completed at properties
 */

const mongoose = require('mongoose');
const { Schema } = mongoose;

const workOrderSchema = new Schema(
  {
    workOrderId: {
      type: String,
      required: [true, 'Work order ID is required'],
      unique: true,
      trim: true,
      index: true,
    },
    propertyId: {
      type: Schema.Types.ObjectId,
      ref: 'Property',
      required: [true, 'Property reference is required'],
      index: true,
    },
    property: {
      location: {
        type: {
          type: String,
          enum: ['Point'],
          default: 'Point',
        },
        coordinates: {
          type: [Number],
          required: [true, 'Property coordinates are required for quick access'],
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
      address: {
        type: String,
        trim: true,
      },
      city: {
        type: String,
        trim: true,
      },
      state: {
        type: String,
        trim: true,
        uppercase: true,
      },
      zipCode: {
        type: String,
        trim: true,
      },
    },
    title: {
      type: String,
      required: [true, 'Title is required'],
      trim: true,
      maxlength: [200, 'Title cannot exceed 200 characters'],
    },
    description: {
      type: String,
      trim: true,
      maxlength: [2000, 'Description cannot exceed 2000 characters'],
    },
    category: {
      type: String,
      enum: {
        values: ['hvac', 'plumbing', 'electrical', 'general', 'inspection'],
        message: '{VALUE} is not a valid category',
      },
      required: [true, 'Category is required'],
      index: true,
    },
    priority: {
      type: String,
      enum: {
        values: ['emergency', 'high', 'medium', 'low'],
        message: '{VALUE} is not a valid priority level',
      },
      required: [true, 'Priority is required'],
      default: 'medium',
      index: true,
    },
    requiredSkills: {
      type: [String],
      default: [],
      validate: {
        validator: function (skills) {
          const validSkills = ['hvac', 'plumbing', 'electrical', 'general', 'inspection'];
          return skills.every((skill) => validSkills.includes(skill));
        },
        message: 'Invalid skill(s). Valid skills: hvac, plumbing, electrical, general, inspection',
      },
    },
    estimatedDurationMinutes: {
      type: Number,
      required: [true, 'Estimated duration is required'],
      min: [1, 'Duration must be at least 1 minute'],
      max: [960, 'Duration cannot exceed 16 hours (960 minutes)'],
    },
    timeWindowStart: {
      type: Date,
      index: true,
    },
    timeWindowEnd: {
      type: Date,
      validate: {
        validator: function (endTime) {
          return !this.timeWindowStart || endTime > this.timeWindowStart;
        },
        message: 'Time window end must be after time window start',
      },
    },
    status: {
      type: String,
      enum: {
        values: ['pending', 'assigned', 'in_progress', 'completed', 'cancelled'],
        message: '{VALUE} is not a valid status',
      },
      required: [true, 'Status is required'],
      default: 'pending',
      index: true,
    },
    assignedTechnicianId: {
      type: Schema.Types.ObjectId,
      ref: 'Technician',
      index: true,
    },
    assignedRouteId: {
      type: Schema.Types.ObjectId,
      ref: 'Route',
      index: true,
    },
    sourceSystem: {
      type: String,
      enum: {
        values: ['salesforce', 'manual', 'iot'],
        message: '{VALUE} is not a valid source system',
      },
      default: 'manual',
      index: true,
    },
    completedAt: {
      type: Date,
    },
    cancelledAt: {
      type: Date,
    },
    cancellationReason: {
      type: String,
      trim: true,
      maxlength: [500, 'Cancellation reason cannot exceed 500 characters'],
    },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

// Indexes
workOrderSchema.index({ 'property.location': '2dsphere' });
workOrderSchema.index({ status: 1, priority: 1 });
workOrderSchema.index({ category: 1, status: 1 });
workOrderSchema.index({ assignedTechnicianId: 1, status: 1 });
workOrderSchema.index({ timeWindowStart: 1, timeWindowEnd: 1 });
workOrderSchema.index({ createdAt: 1, status: 1 });

// Compound index for optimization queries
workOrderSchema.index({
  status: 1,
  priority: -1,
  timeWindowStart: 1,
});

// Virtual for priority weight (for optimization algorithms)
workOrderSchema.virtual('priorityWeight').get(function () {
  const weights = {
    emergency: 100,
    high: 75,
    medium: 50,
    low: 25,
  };
  return weights[this.priority] || 50;
});

// Virtual for estimated duration in hours
workOrderSchema.virtual('estimatedDurationHours').get(function () {
  return this.estimatedDurationMinutes / 60;
});

// Virtual to check if work order has time constraints
workOrderSchema.virtual('hasTimeWindow').get(function () {
  return !!(this.timeWindowStart && this.timeWindowEnd);
});

// Virtual for location coordinates (convenience accessor)
workOrderSchema.virtual('coordinates').get(function () {
  return this.property.location.coordinates;
});

// Instance method to check if work order is assignable
workOrderSchema.methods.isAssignable = function () {
  return this.status === 'pending';
};

// Instance method to check if technician can handle this work order
workOrderSchema.methods.canBeHandledBy = function (technician) {
  if (this.requiredSkills.length === 0) return true;
  return this.requiredSkills.every((skill) => technician.skills.includes(skill));
};

// Instance method to check if work order is within time window
workOrderSchema.methods.isWithinTimeWindow = function (scheduledTime) {
  if (!this.hasTimeWindow) return true;
  return scheduledTime >= this.timeWindowStart && scheduledTime <= this.timeWindowEnd;
};

// Instance method to assign to technician and route
workOrderSchema.methods.assignTo = function (technicianId, routeId) {
  this.assignedTechnicianId = technicianId;
  this.assignedRouteId = routeId;
  this.status = 'assigned';
  return this.save();
};

// Instance method to mark as completed
workOrderSchema.methods.complete = function () {
  this.status = 'completed';
  this.completedAt = new Date();
  return this.save();
};

// Instance method to cancel
workOrderSchema.methods.cancel = function (reason) {
  this.status = 'cancelled';
  this.cancelledAt = new Date();
  if (reason) {
    this.cancellationReason = reason;
  }
  return this.save();
};

// Static method to find pending work orders
workOrderSchema.statics.findPending = function () {
  return this.find({ status: 'pending' }).sort({ priority: -1, createdAt: 1 });
};

// Static method to find unassigned work orders for optimization
workOrderSchema.statics.findUnassigned = function () {
  return this.find({
    status: 'pending',
    assignedTechnicianId: null,
  }).sort({ priority: -1, timeWindowStart: 1 });
};

// Static method to find work orders by category
workOrderSchema.statics.findByCategory = function (category) {
  return this.find({ category, status: { $ne: 'cancelled' } });
};

// Static method to find work orders by priority
workOrderSchema.statics.findByPriority = function (priority) {
  return this.find({ priority, status: 'pending' });
};

// Static method to find work orders for a specific technician
workOrderSchema.statics.findByTechnician = function (technicianId) {
  return this.find({ assignedTechnicianId: technicianId, status: { $ne: 'cancelled' } });
};

// Static method to find work orders within a date range
workOrderSchema.statics.findByDateRange = function (startDate, endDate) {
  return this.find({
    $or: [
      { timeWindowStart: { $gte: startDate, $lte: endDate } },
      { createdAt: { $gte: startDate, $lte: endDate } },
    ],
    status: { $ne: 'cancelled' },
  });
};

// Static method to find nearby work orders
workOrderSchema.statics.findNearby = function (longitude, latitude, maxDistanceMiles) {
  return this.find({
    'property.location': {
      $nearSphere: {
        $geometry: {
          type: 'Point',
          coordinates: [longitude, latitude],
        },
        $maxDistance: maxDistanceMiles * 1609.34, // Convert miles to meters
      },
    },
    status: 'pending',
  });
};

// Pre-save middleware to set requiredSkills based on category if not provided
workOrderSchema.pre('save', function (next) {
  if (this.isNew && (!this.requiredSkills || this.requiredSkills.length === 0)) {
    // Auto-assign required skills based on category
    if (this.category !== 'general') {
      this.requiredSkills = [this.category];
    }
  }
  next();
});

// Pre-save middleware to validate time window
workOrderSchema.pre('save', function (next) {
  if (this.timeWindowStart && this.timeWindowEnd) {
    if (this.timeWindowEnd <= this.timeWindowStart) {
      next(new Error('Time window end must be after time window start'));
    }
  }
  next();
});

const WorkOrder = mongoose.model('WorkOrder', workOrderSchema);

module.exports = WorkOrder;
