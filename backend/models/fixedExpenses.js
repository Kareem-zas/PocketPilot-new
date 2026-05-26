const mongoose = require("mongoose");

const fixedItemSchema = new mongoose.Schema({
  title: {
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
  icon: {
    type: String,
    default: "default",
  },
  startDate: {
    type: Date,
    default: Date.now,
  },
  frequency: {
    type: String,
    enum: ["monthly", "yearly"],
    default: "monthly",
  },
  isActive: {
    type: Boolean,
    default: true,
  },
});

const fixedExpensesSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      unique: true,
    },
    items: {
      type: [fixedItemSchema],
      default: [],
    },
  },
  { timestamps: true }
);

//  Indexes (مكان واحد فقط)
fixedExpensesSchema.index({ "items.isActive": 1 });
fixedExpensesSchema.index({ "items.startDate": 1 });

module.exports = mongoose.model("FixedExpense", fixedExpensesSchema);
