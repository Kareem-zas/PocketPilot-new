
const mongoose = require("mongoose");

const goalSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    title: {
      type: String,
      required: [true, "Goal title is required"],
      trim: true,
    },

    category: {
      type: String,
      enum: ["Travel", "Housing", "Education", "General"],
      default: "General",
    },

    targetAmount: {
      type: Number,
      required: [true, "Target amount is required"],
      min: [1, "Target amount must be at least 1"],
    },

    savedAmount: {
      type: Number,
      default: 0,
      min: 0,
    },

    targetDate: {
      type: Date,
      required: [true, "Target date is required"],
    },

    isCompleted: {
      type: Boolean,
      default: false,
    },
    members: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],
    contributions: [
      {
        userId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
        },
        amount: {
          type: Number,
          default: 0,
        },
        createdAt: {
          type: Date,
          default: Date.now,
        },
      },
    ],
    shared: {
      type: Boolean,
      default: false,
    },
  },
  { timestamps: true }
);

// Virtual: progress percentage
goalSchema.virtual("progress").get(function () {
  if (this.targetAmount === 0) return 0;
  return Math.min((this.savedAmount / this.targetAmount) * 100, 100);
});

goalSchema.set("toJSON", { virtuals: true });
goalSchema.set("toObject", { virtuals: true });

module.exports = mongoose.model("Goal", goalSchema);
