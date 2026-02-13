/**
 * Technician Model
 * Represents field technicians who perform service work
 */

const mongoose = require('mongoose');
const { Schema } = mongoose;

const technicianSchema = new Schema(
  {
    technicianId: {
      type: String,
      required: [true, 'Technician ID is required'],
      unique: true,
      trim: true,
      index: true,
    },
    name: {
      type: String,
      required: [true, 'Name is required'],
      trim: true,
      minlength: [2, 'Name must be at least 2 characters'],
      maxlength: [100, 'Name cannot exceed 100 characters'],
    },
    email: {
      type: String,
      required: [true, 'Email is required'],
      unique: true,
      trim: true,
      lowercase: true,
      match: [
        /^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,3})+$/,
        'Invalid email address',
      ],
      index: true,
    },
    phone: {
      type: String,
      required: [true, 'Phone number is required'],
      trim: true,
      match: [
        /^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}$/,
        'Invalid phone number format',
      ],
    },
    homeBase: {
      type: {
        type: String,
        enum: ['Point'],
        required: true,
        default: 'Point',
      },
      coordinates: {
        type: [Number],
        required: [true, 'Home base coordinates are required'],
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
    skills: {
      type: [String],
      required: [true, 'At least one skill is required'],
      validate: {
        validator: function (skills) {
          const validSkills = ['hvac', 'plumbing', 'electrical', 'general', 'inspection'];
          return skills.length > 0 && skills.every((skill) => validSkills.includes(skill));
        },
        message: 'Invalid skill(s). Valid skills: hvac, plumbing, electrical, general, inspection',
      },
      index: true,
    },
    maxDailyHours: {
      type: Number,
      required: [true, 'Maximum daily hours is required'],
      min: [1, 'Maximum daily hours must be at least 1'],
      max: [24, 'Maximum daily hours cannot exceed 24'],
      default: 8,
    },
    maxDailyDistanceMiles: {
      type: Number,
      required: [true, 'Maximum daily distance is required'],
      min: [1, 'Maximum daily distance must be at least 1 mile'],
      max: [500, 'Maximum daily distance cannot exceed 500 miles'],
      default: 150,
    },
    hourlyRate: {
      type: Number,
      required: [true, 'Hourly rate is required'],
      min: [0, 'Hourly rate cannot be negative'],
    },
    availabilityStatus: {
      type: String,
      enum: {
        values: ['available', 'on_route', 'off_duty', 'on_leave'],
        message: '{VALUE} is not a valid availability status',
      },
      required: [true, 'Availability status is required'],
      default: 'available',
      index: true,
    },
    zonePreference: {
      type: [String],
      default: [],
      index: true,
    },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

// Indexes
technicianSchema.index({ homeBase: '2dsphere' });
technicianSchema.index({ availabilityStatus: 1, skills: 1 });
technicianSchema.index({ zonePreference: 1 });

// Virtual for home base longitude
technicianSchema.virtual('homeBaseLongitude').get(function () {
  return this.homeBase.coordinates[0];
});

// Virtual for home base latitude
technicianSchema.virtual('homeBaseLatitude').get(function () {
  return this.homeBase.coordinates[1];
});

// Virtual for full capacity info
technicianSchema.virtual('capacityInfo').get(function () {
  return {
    maxHours: this.maxDailyHours,
    maxDistance: this.maxDailyDistanceMiles,
    hourlyRate: this.hourlyRate,
  };
});

// Instance method to check if technician has required skills
technicianSchema.methods.hasSkills = function (requiredSkills) {
  if (!requiredSkills || requiredSkills.length === 0) return true;
  return requiredSkills.every((skill) => this.skills.includes(skill));
};

// Instance method to check availability
technicianSchema.methods.isAvailable = function () {
  return this.availabilityStatus === 'available';
};

// Instance method to calculate distance from home base to a point
technicianSchema.methods.distanceFromHome = function (longitude, latitude) {
  const toRad = (value) => (value * Math.PI) / 180;
  const R = 3959; // Earth's radius in miles

  const dLat = toRad(latitude - this.homeBase.coordinates[1]);
  const dLon = toRad(longitude - this.homeBase.coordinates[0]);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(this.homeBase.coordinates[1])) *
      Math.cos(toRad(latitude)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c; // Distance in miles
};

// Static method to find available technicians with specific skills
technicianSchema.statics.findAvailableWithSkills = function (requiredSkills) {
  return this.find({
    availabilityStatus: 'available',
    skills: { $all: requiredSkills },
  });
};

// Static method to find technicians near a location
technicianSchema.statics.findNearby = function (longitude, latitude, maxDistanceMiles) {
  return this.find({
    homeBase: {
      $nearSphere: {
        $geometry: {
          type: 'Point',
          coordinates: [longitude, latitude],
        },
        $maxDistance: maxDistanceMiles * 1609.34, // Convert miles to meters
      },
    },
  });
};

// Static method to find technicians by zone preference
technicianSchema.statics.findByZonePreference = function (zoneId) {
  return this.find({ zonePreference: zoneId });
};

// Static method to get all available technicians
technicianSchema.statics.getAvailable = function () {
  return this.find({ availabilityStatus: 'available' });
};

// Pre-save middleware to validate skills array
technicianSchema.pre('save', function (next) {
  if (this.skills && this.skills.length > 0) {
    // Remove duplicates
    this.skills = [...new Set(this.skills)];
  }
  next();
});

// Pre-save middleware to validate zone preferences
technicianSchema.pre('save', function (next) {
  if (this.zonePreference && this.zonePreference.length > 0) {
    // Remove duplicates
    this.zonePreference = [...new Set(this.zonePreference)];
  }
  next();
});

const Technician = mongoose.model('Technician', technicianSchema);

module.exports = Technician;
