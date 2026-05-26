const mongoose = require("mongoose");
const FixedExpense = require("../models/fixedExpenses");
const catchAsync = require("../utils/catchAsync");
const AppError = require("../utils/AppError");

/* =========================
   Get user's fixed expenses
   (جلب المصاريف الثابتة)
========================= */
exports.getFixedExpenses = catchAsync(async (req, res, next) => {
  const doc = await FixedExpense.findOne({ user: req.userId });

  // توحيد الـ Response سواء وجدت وثيقة أم لا
  return res.status(200).json({
    status: "success",
    items: doc ? doc.items : [],
  });
});

/* =========================
   Add Fixed Expense Item
   (إضافة مصروف ثابت - ينشئ الوثيقة تلقائياً إذا لم تكن موجودة)
========================= */
exports.addFixedExpenseItem = catchAsync(async (req, res, next) => {
  const { title, amount, icon, frequency, isActive = true, startDate } = req.body;

  // 1. التحقق من المدخلات الأساسية
  if (!title || amount === undefined) {
    return next(new AppError("Title and amount are required", 400));
  }

  // 2. البحث عن وثيقة المستخدم
  let doc = await FixedExpense.findOne({ user: req.userId });

  // 3. (Upsert Logic) إذا لم تكن الوثيقة موجودة، قم بإنشائها
  if (!doc) {
    doc = await FixedExpense.create({
      user: req.userId,
      items: [],
    });
  }

  // 4. التحقق من التكرار (Duplicate Check)
  // هل يوجد مصروف بنفس الاسم؟
  const titleLower = title.trim().toLowerCase();
  const exists = doc.items.some((item) => item.title === titleLower);

  if (exists) {
    return next(new AppError("Expense with this title already exists", 400));
  }

  // 5. إضافة العنصر الجديد
  doc.items.push({
    title: titleLower,
    amount,
    icon,
    frequency,
    isActive,
    startDate: startDate || Date.now() // تأكدنا من وجود تاريخ البدء
  });

  await doc.save();

  res.status(200).json({
    status: "success",
    message: "Item added successfully",
    items: doc.items, // نرجع القائمة المحدثة
  });
});

/* =========================
   Update Fixed Expense Item
   (تعديل مصروف)
========================= */
exports.updateFixedExpenseItem = catchAsync(async (req, res, next) => {
  const { itemId } = req.params;
  const updates = req.body;

  if (!mongoose.Types.ObjectId.isValid(itemId)) {
    return next(new AppError("Invalid Item ID", 400));
  }

  // 1. جلب الوثيقة
  const doc = await FixedExpense.findOne({ user: req.userId });
  if (!doc) return next(new AppError("Document not found", 404));

  // 2. البحث عن العنصر الفرعي (Subdocument)
  const item = doc.items.id(itemId);
  if (!item) return next(new AppError("Item not found", 404));

  // 3. التعديل الآمن (Whitelist)
  const allowedFields = ["title", "amount", "icon", "frequency", "isActive", "startDate"];

  allowedFields.forEach((field) => {
    if (updates[field] !== undefined) {
      item[field] = updates[field];
    }
  });

  await doc.save();

  res.status(200).json({
    status: "success",
    message: "Item updated successfully",
    item,
  });
});

/* =========================
   Delete Fixed Expense Item
   (حذف مصروف - Optimized)
========================= */
exports.deleteFixedExpenseItem = catchAsync(async (req, res, next) => {
  const { itemId } = req.params;

  if (!mongoose.Types.ObjectId.isValid(itemId)) {
    return next(new AppError("Invalid Item ID", 400));
  }

  // استخدام $pull للحذف المباشر والسريع من المصفوفة
  const result = await FixedExpense.findOneAndUpdate(
    { user: req.userId },
    { $pull: { items: { _id: itemId } } }, // اسحب العنصر الذي يملك هذا الـ ID
    { new: true } // أرجع الوثيقة بعد التعديل
  );

  if (!result) {
    return next(new AppError("Document not found", 404));
  }

  // ملاحظة: findOneAndUpdate لا تُرجع خطأ إذا لم تجد الـ Item داخل المصفوفة،
  // هي فقط لن تحذف شيئاً. إذا أردت التأكد من أن الحذف تم، يمكنك فحص طول المصفوفة قبل وبعد،
  // لكن للتبسيط، العملية تعتبر ناجحة.

  res.status(200).json({
    status: "success",
    message: "Item deleted successfully",
    items: result.items,
  });
});