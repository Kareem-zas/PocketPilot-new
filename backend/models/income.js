const mongoose = require("mongoose");

const incomeSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    source: {
      type: String,
      required: true,
      trim: true,
      lowercase: true, // salary, freelance, project
    },

    amount: {
      type: Number,
      required: true,
      min: 0,
    },

    date: {
      type: Date,
      default: Date.now,
    },

    isRecurring: {
      type: Boolean,
      default: false,
    },

    frequency: {
      type: String,
      enum: ["monthly", "quarterly", "bi-annual", "yearly"],
      required: function () {
        return this.isRecurring;
      },
    },

    // Whether this recurring income is currently active
    isActive: {
      type: Boolean,
      default: true,
    },

    // Specific months the user paused (e.g. unpaid leave)
    // Each entry: { year: 2026, month: 3 }
    pausedMonths: {
      type: [{ year: Number, month: Number }],
      default: [],
    },

    icon: {
      type: String,
      default: "income",
    },

    notes: {
      type: String,
      trim: true,
    },

    smsId: {
      type: String,
      unique: true,
      sparse: true,
    },
  },
  { timestamps: true }
);

/* =========================
   Indexes (Performance)
========================= */
incomeSchema.index({ user: 1, date: -1 });

module.exports = mongoose.model("Income", incomeSchema);
