/**
 * Property Model
 * Represents real estate properties that require service visits
 */

const mongoose = require("mongoose");
const { Schema } = mongoose;

const propertySchema = new Schema(
  {
    propertyId: {
      type: String,
      required: [true, "Property ID is required"],
      unique: true,
      trim: true,
      index: true,
    },
    address: {
      type: String,
      required: [true, "Address is required"],
      trim: true,
    },
    city: {
      type: String,
      required: [true, "City is required"],
      trim: true,
      index: true,
    },
    state: {
      type: String,
      required: [true, "State is required"],
      trim: true,
      uppercase: true,
      maxlength: 2,
      index: true,
    },
    zipCode: {
      type: String,
      required: [true, "ZIP code is required"],
      trim: true,
      match: [/^\d{5}(-\d{4})?$/, "Invalid ZIP code format"],
      index: true,
    },
    location: {
      type: {
        type: String,
        enum: ["Point"],
        required: true,
        default: "Point",
      },
      coordinates: {
        type: [Number],
        required: [true, "Coordinates are required"],
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
          message: "Invalid coordinates. Format: [longitude, latitude]",
        },
      },
    },
    propertyType: {
      type: String,
      enum: {
        values: ["residential", "commercial", "industrial"],
        message: "{VALUE} is not a valid property type",
      },
      required: [true, "Property type is required"],
      index: true,
    },
    zoneId: {
      type: String,
      trim: true,
      index: true,
    },
    squareFootage: {
      type: Number,
      min: [0, "Square footage cannot be negative"],
    },
    accessNotes: {
      type: String,
      trim: true,
      maxlength: 1000,
    },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  },
);

// Indexes
propertySchema.index({ location: "2dsphere" });
propertySchema.index({ city: 1, state: 1 });
propertySchema.index({ zoneId: 1, propertyType: 1 });

// Virtual for formatted address
propertySchema.virtual("fullAddress").get(function () {
  return `${this.address}, ${this.city}, ${this.state} ${this.zipCode}`;
});

// Virtual for longitude
propertySchema.virtual("longitude").get(function () {
  return this.location && this.location.coordinates
    ? this.location.coordinates[0]
    : null;
});

// Virtual for latitude
propertySchema.virtual("latitude").get(function () {
  return this.location && this.location.coordinates
    ? this.location.coordinates[1]
    : null;
});

// Instance method to calculate distance to another point
propertySchema.methods.distanceTo = function (longitude, latitude) {
  const toRad = (value) => (value * Math.PI) / 180;
  const R = 3959; // Earth's radius in miles

  const dLat = toRad(latitude - this.location.coordinates[1]);
  const dLon = toRad(longitude - this.location.coordinates[0]);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(this.location.coordinates[1])) *
      Math.cos(toRad(latitude)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c; // Distance in miles
};

// Static method to find properties within a radius
propertySchema.statics.findNearby = function (
  longitude,
  latitude,
  maxDistanceMiles,
) {
  return this.find({
    location: {
      $nearSphere: {
        $geometry: {
          type: "Point",
          coordinates: [longitude, latitude],
        },
        $maxDistance: maxDistanceMiles * 1609.34, // Convert miles to meters
      },
    },
  });
};

// Static method to find properties by zone
propertySchema.statics.findByZone = function (zoneId) {
  return this.find({ zoneId });
};

// Static method to get properties within a bounding box
propertySchema.statics.findInBoundingBox = function (
  minLng,
  minLat,
  maxLng,
  maxLat,
) {
  return this.find({
    location: {
      $geoWithin: {
        $box: [
          [minLng, minLat],
          [maxLng, maxLat],
        ],
      },
    },
  });
};

// Pre-save middleware to validate location
propertySchema.pre("save", function (next) {
  if (this.isModified("location")) {
    const [lng, lat] = this.location.coordinates;
    if (lng < -180 || lng > 180 || lat < -90 || lat > 90) {
      next(new Error("Invalid coordinates range"));
    }
  }
  next();
});

const Property = mongoose.model("Property", propertySchema);

module.exports = Property;
