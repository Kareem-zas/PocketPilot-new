const mongoose = require("mongoose");
const Income = require("../models/income");
const catchAsync = require("../utils/catchAsync");
const AppError = require("../utils/AppError");

/* =========================
   Insert Income
   (إضافة دخل جديد)
========================= */
exports.insertIncome = catchAsync(async (req, res, next) => {
  const { source, amount, date, isRecurring, frequency, icon, notes } = req.body;

  // 1. التحقق من الحقول الإجبارية
  if (!source || amount === undefined) {
    return next(new AppError("Source and amount are required", 400));
  }

  // 2. إنشاء المستند
  const income = await Income.create({
    user: req.userId,
    source,
    amount,
    date,
    isRecurring,
    frequency,
    icon,
    notes,
  });

  // 3. إرسال الرد
  res.status(201).json({
    status: "success",
    message: "Income added successfully",
    data: { income },
  });
});

/* =========================
   Get All Incomes
   (جلب كل الدخل - مرتباً بالأحدث)
========================= */
exports.getIncome = catchAsync(async (req, res, next) => {
  const incomes = await Income.find({ user: req.userId }).sort({ date: -1 });

  res.status(200).json({
    status: "success",
    results: incomes.length, // مفيد للفرونت إند لمعرفة العدد
    data: { incomes },
  });
});

/* =========================
   Get Single Income
   (جلب دخل واحد)
========================= */
exports.getIncomeById = catchAsync(async (req, res, next) => {
  const { id } = req.params;

  // التحقق من صحة الـ ID
  if (!mongoose.Types.ObjectId.isValid(id)) {
    return next(new AppError("Invalid Income ID", 400));
  }

  const income = await Income.findOne({ _id: id, user: req.userId });

  if (!income) {
    return next(new AppError("Income entry not found", 404));
  }

  res.status(200).json({
    status: "success",
    data: { income },
  });
});

/* =========================
   Update Income
   (تعديل دخل - محمي)
========================= */
exports.updateIncome = catchAsync(async (req, res, next) => {
  const { id } = req.params;

  if (!mongoose.Types.ObjectId.isValid(id)) {
    return next(new AppError("Invalid Income ID", 400));
  }

  // 1. جلب المستند
  const income = await Income.findOne({ _id: id, user: req.userId });
  if (!income) {
    return next(new AppError("Income entry not found", 404));
  }

  // 2. تحديد الحقول المسموح بتعديلها (Whitelisting)
  const allowedUpdates = [
    "source",
    "amount",
    "date",
    "isRecurring",
    "frequency",
    "icon",
    "notes",
  ];

  // 3. تطبيق التعديلات
  Object.keys(req.body).forEach((key) => {
    if (allowedUpdates.includes(key)) {
      income[key] = req.body[key];
    }
  });

  await income.save();

  res.status(200).json({
    status: "success",
    message: "Income updated successfully",
    data: { income },
  });
});

/* =========================
   Delete Income
   (حذف دخل)
========================= */
exports.deleteIncome = catchAsync(async (req, res, next) => {
  const { id } = req.params;

  if (!mongoose.Types.ObjectId.isValid(id)) {
    return next(new AppError("Invalid Income ID", 400));
  }

  const deleted = await Income.findOneAndDelete({
    _id: id,
    user: req.userId,
  });

  if (!deleted) {
    return next(new AppError("Income entry not found", 404));
  }

  res.status(200).json({
    status: "success",
    message: "Income deleted successfully",
    data: null, // المعيار في REST API عند الحذف إرجاع null
  });
});

/* =========================
   Income History / Filtering
   (سجل الدخل مع فلترة)
========================= */
exports.getIncomeHistory = catchAsync(async (req, res, next) => {
  const userId = req.userId;
  const { year, month, source, from, to } = req.query;

  // بناء الفلتر ديناميكياً
  const filter = { user: userId };

  /* ---------- Date filtering ---------- */
  if (year && month) {
    // فلترة حسب شهر معين في سنة معينة
    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 1);
    filter.date = { $gte: startDate, $lt: endDate };
  } else if (from || to) {
    // فلترة حسب نطاق مخصص (من - إلى)
    filter.date = {};
    if (from) filter.date.$gte = new Date(from);
    if (to) filter.date.$lte = new Date(to);
  }

  /* ---------- Source filtering ---------- */
  // مثلاً لو بده يعرف بس "الراتب" أو بس "الفريلانس"
  if (source) {
    filter.source = source.toLowerCase(); // تأكد إنك بتخزن الـ source lowercase بالداتابيز أو استخدم Regex
  }

  // جلب البيانات
  const incomes = await Income.find(filter)
    .sort({ date: -1 })
    .lean(); // للأداء السريع

  // حساب المجموع
  const totalAmount = incomes.reduce((sum, item) => sum + item.amount, 0);

  res.status(200).json({
    status: "success",
    results: incomes.length,
    totalAmount,
    data: { incomes },
  });
});

/* =========================
   Sync SMS Income
   (مزامنة الدخل من رسايل البنك)
========================= */
exports.syncSmsIncome = catchAsync(async (req, res, next) => {
  const { transactions } = req.body;
  if (!transactions || !Array.isArray(transactions)) {
    return next(new AppError("Transactions array is required", 400));
  }
  const userId = req.userId;
  let addedCount = 0;

  // Extract smsIds
  const smsIds = transactions.map((t) => t.id).filter(Boolean);

  // Find existing incomes by smsId
  const existingIncomes = await Income.find({
    user: userId,
    smsId: { $in: smsIds },
  }).select("smsId");

  const existingSmsIds = new Set(existingIncomes.map((e) => e.smsId));
  const newIncomes = [];

  for (const trx of transactions) {
    if (trx.type === "deposit" && trx.id && !existingSmsIds.has(trx.id)) {
      newIncomes.push({
        user: userId,
        source: `bank_deposit - ${trx.sender || "Unknown"}`,
        amount: trx.amount,
        date: trx.date ? new Date(trx.date) : Date.now(),
        isRecurring: false,
        notes: trx.body || "Auto-synced via SMS",
        smsId: trx.id,
      });
      existingSmsIds.add(trx.id);
    }
  }

  if (newIncomes.length > 0) {
    await Income.insertMany(newIncomes);
    addedCount = newIncomes.length;
  }

  res.status(200).json({
    status: "success",
    message: `Successfully synchronized ${addedCount} new incomes from SMS`,
    data: { addedCount },
  });
});

/* =========================
   Toggle Active
   (تفعيل / تعطيل الدخل المتكرر كلياً)
========================= */
exports.toggleActive = catchAsync(async (req, res, next) => {
  const { id } = req.params;

  if (!mongoose.Types.ObjectId.isValid(id)) {
    return next(new AppError("Invalid Income ID", 400));
  }

  const income = await Income.findOne({ _id: id, user: req.userId });
  if (!income) return next(new AppError("Income entry not found", 404));
  if (!income.isRecurring) return next(new AppError("Only recurring incomes can be toggled", 400));

  income.isActive = !income.isActive;
  await income.save();

  res.status(200).json({
    status: "success",
    message: `Recurring income ${income.isActive ? "activated" : "deactivated"}`,
    data: { income },
  });
});

/* =========================
   Pause a Specific Month
   (إيقاف شهر معين — إجازة بدون راتب)
========================= */
exports.pauseMonth = catchAsync(async (req, res, next) => {
  const { id } = req.params;
  const { year, month } = req.body;

  if (!mongoose.Types.ObjectId.isValid(id)) {
    return next(new AppError("Invalid Income ID", 400));
  }
  if (!year || !month) {
    return next(new AppError("year and month are required", 400));
  }

  const income = await Income.findOne({ _id: id, user: req.userId });
  if (!income) return next(new AppError("Income entry not found", 404));
  if (!income.isRecurring) return next(new AppError("Only recurring incomes can have paused months", 400));

  // Avoid duplicates
  const alreadyPaused = income.pausedMonths.some(
    (p) => p.year === Number(year) && p.month === Number(month)
  );

  if (!alreadyPaused) {
    income.pausedMonths.push({ year: Number(year), month: Number(month) });
    await income.save();
  }

  res.status(200).json({
    status: "success",
    message: `Month ${month}/${year} paused for this income`,
    data: { income },
  });
});

/* =========================
   Resume a Specific Month
   (استعادة شهر كان موقوفاً)
========================= */
exports.resumeMonth = catchAsync(async (req, res, next) => {
  const { id } = req.params;
  const { year, month } = req.body;

  if (!mongoose.Types.ObjectId.isValid(id)) {
    return next(new AppError("Invalid Income ID", 400));
  }
  if (!year || !month) {
    return next(new AppError("year and month are required", 400));
  }

  const income = await Income.findOne({ _id: id, user: req.userId });
  if (!income) return next(new AppError("Income entry not found", 404));

  income.pausedMonths = income.pausedMonths.filter(
    (p) => !(p.year === Number(year) && p.month === Number(month))
  );
  await income.save();

  res.status(200).json({
    status: "success",
    message: `Month ${month}/${year} resumed for this income`,
    data: { income },
  });
});