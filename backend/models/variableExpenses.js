const mongoose = require("mongoose");

const variableExpenseSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true, //  أساسي
    },

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

    date: {
      type: Date,
      default: Date.now,
      index: true, // 🔥 للتقارير
    },

    category: {
      type: String,
      trim: true,
      lowercase: true,
      default: "other", //  مهم جدًا
      index: true, //  جاهز للفلترة
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
   Indexes (Production Ready)
========================= */

// للتقارير الشهرية
variableExpenseSchema.index({ user: 1, date: -1 });

// للفلترة حسب category
variableExpenseSchema.index({ user: 1, category: 1 });

// للتقارير حسب category + date
variableExpenseSchema.index({ user: 1, category: 1, date: -1 });

module.exports = mongoose.model("VariableExpense", variableExpenseSchema);
