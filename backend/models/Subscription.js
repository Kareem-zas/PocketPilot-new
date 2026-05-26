const mongoose = require("mongoose");

const subscriptionSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    vendor: {
      type: String,
      required: true,
      trim: true,
      lowercase: true,
    },

    amount: {
      type: Number,
      required: true,
      min: 0,
    },

    frequency: {
      type: String,
      default: "monthly",
      enum: ["weekly", "bi-weekly", "monthly", "yearly"],
    },

    firstDetectedDate: {
      type: Date,
      required: true,
    },

    nextExpectedDate: {
      type: Date,
      required: true,
    },

    isActive: {
      type: Boolean,
      default: true,
    },
  },
  { timestamps: true }
);

// Prevent duplicate tracking for the same user and vendor
subscriptionSchema.index({ user: 1, vendor: 1 }, { unique: true });

module.exports = mongoose.model("Subscription", subscriptionSchema);
