const mongoose = require("mongoose");
const VariableExpense = require("../models/variableExpenses");
const catchAsync = require("../utils/catchAsync");
const AppError = require("../utils/AppError");

/* =========================
   Insert Variable Expense
   (إضافة مصروف متغير)
========================= */
exports.insertVariableExpense = catchAsync(async (req, res, next) => {
  const { title, amount, date, category, notes } = req.body;

  // 1. التحقق من الحقول الإجبارية
  if (!title || amount === undefined) {
    return next(new AppError("Title and amount are required", 400));
  }

  // 2. إنشاء المستند
  const expense = await VariableExpense.create({
    user: req.userId,
    title,
    amount,
    date,
    category,
    notes,
  });

  // 3. إرسال الرد
  res.status(201).json({
    status: "success",
    message: "Variable expense added successfully",
    data: { expense },
  });
});

/* =========================
   Get All Variable Expenses
   (جلب الكل - مرتب تنازلياً)
========================= */
exports.getVariableExpenses = catchAsync(async (req, res, next) => {
  const expenses = await VariableExpense.find({ user: req.userId }).sort({
    date: -1,
  });

  res.status(200).json({
    status: "success",
    results: expenses.length,
    data: { expenses },
  });
});

/* =========================
   Get Single Expense
   (جلب مصروف واحد)
========================= */
exports.getVariableExpenseById = catchAsync(async (req, res, next) => {
  const { id } = req.params;

  if (!mongoose.Types.ObjectId.isValid(id)) {
    return next(new AppError("Invalid Expense ID", 400));
  }

  const expense = await VariableExpense.findOne({
    _id: id,
    user: req.userId,
  });

  if (!expense) {
    return next(new AppError("Expense not found", 404));
  }

  res.status(200).json({
    status: "success",
    data: { expense },
  });
});

/* =========================
   Update Variable Expense
   (تعديل مصروف - محمي)
========================= */
exports.updateVariableExpense = catchAsync(async (req, res, next) => {
  const { id } = req.params;

  if (!mongoose.Types.ObjectId.isValid(id)) {
    return next(new AppError("Invalid Expense ID", 400));
  }

  // 1. جلب المستند
  const expense = await VariableExpense.findOne({
    _id: id,
    user: req.userId,
  });

  if (!expense) {
    return next(new AppError("Expense not found", 404));
  }

  // 2. القائمة البيضاء للحقول المسموح بتعديلها (Whitelisting) 
  const allowedUpdates = ["title", "amount", "date", "category", "notes"];

  // 3. تطبيق التعديلات
  Object.keys(req.body).forEach((key) => {
    if (allowedUpdates.includes(key)) {
      expense[key] = req.body[key];
    }
  });

  await expense.save();

  res.status(200).json({
    status: "success",
    message: "Variable expense updated successfully",
    data: { expense },
  });
});

/* =========================
   Delete Variable Expense
   (حذف مصروف)
========================= */
exports.deleteVariableExpense = catchAsync(async (req, res, next) => {
  const { id } = req.params;

  if (!mongoose.Types.ObjectId.isValid(id)) {
    return next(new AppError("Invalid Expense ID", 400));
  }

  const deleted = await VariableExpense.findOneAndDelete({
    _id: id,
    user: req.userId,
  });

  if (!deleted) {
    return next(new AppError("Expense not found", 404));
  }

  res.status(200).json({
    status: "success",
    message: "Variable expense deleted successfully",
    data: null,
  });
});

/* =========================
   History / Filtering
   (سجل المصاريف مع فلترة)
========================= */
exports.getVariableExpensesHistory = catchAsync(async (req, res, next) => {
  const userId = req.userId;
  const { year, month, category, from, to } = req.query;

  // بناء الفلتر ديناميكياً
  const filter = { user: userId };

  /* ---------- Date filtering ---------- */
  if (year && month) {
    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 1);
    filter.date = { $gte: startDate, $lt: endDate };
  } else if (from || to) {
    filter.date = {};
    if (from) filter.date.$gte = new Date(from);
    if (to) filter.date.$lte = new Date(to);
  }

  /* ---------- Category filter ---------- */
  if (category) {
    filter.category = category.toLowerCase();
  }

  // استخدام lean() لتحسين الأداء لأننا نحتاج للقراءة فقط
  const expenses = await VariableExpense.find(filter)
    .sort({ date: -1 })
    .lean();

  // حساب المجموع في الذاكرة (لأن البيانات مفلترة وجاهزة)
  const totalAmount = expenses.reduce((sum, exp) => sum + exp.amount, 0);

  res.status(200).json({
    status: "success",
    count: expenses.length, // إضافة count مفيدة للفرونت إند
    totalAmount,
    data: { expenses },
  });
});

/* =========================
   Sync SMS Expenses
   (مزامنة مصروفات من رسائل البنك)
========================= */
exports.syncSmsExpenses = catchAsync(async (req, res, next) => {
  const { transactions } = req.body;
  if (!transactions || !Array.isArray(transactions)) {
    return next(new AppError("Transactions array is required", 400));
  }
  const userId = req.userId;
  let addedCount = 0;

  // Extract smsIds
  const smsIds = transactions.map((t) => t.id).filter(Boolean);

  // Find existing expenses by smsId
  const existingExpenses = await VariableExpense.find({
    user: userId,
    smsId: { $in: smsIds },
  }).select("smsId");

  const existingSmsIds = new Set(existingExpenses.map((e) => e.smsId));
  const newExpenses = [];

  for (const trx of transactions) {
    if (trx.type === "purchase" && trx.id && !existingSmsIds.has(trx.id)) {
      newExpenses.push({
        user: userId,
        title: `Bank Sync - ${trx.sender || "Unknown"}`,
        amount: trx.amount,
        date: trx.date ? new Date(trx.date) : Date.now(),
        category: "bank_sync", // Using bank_sync per user approval
        notes: trx.body || "Auto-synced via SMS",
        smsId: trx.id,
      });
      // Add to set to prevent duplicates within the same array
      existingSmsIds.add(trx.id);
    }
  }

  if (newExpenses.length > 0) {
    await VariableExpense.insertMany(newExpenses);
    addedCount = newExpenses.length;
  }

  res.status(200).json({
    status: "success",
    message: `Successfully synchronized ${addedCount} new expenses from SMS`,
    data: {
      addedCount,
    },
  });
});