const mongoose = require("mongoose");
const DashboardService = require("../services/dashboardService");
const catchAsync = require("../utils/catchAsync");

exports.getDashboard = catchAsync(async (req, res, next) => {
  // 1. استخراج وتحويل البيانات
  // ملاحظة: التحويل لـ ObjectId ضروري هنا لأن Service الداشبورد يستخدم Aggregation
  const userId = new mongoose.Types.ObjectId(req.userId);

  const { year, month, page, pageSize } = req.query;

  // 2. استدعاء الخدمة
  const dashboardData = await DashboardService.getDashboardData(
    userId,
    year ? Number(year) : undefined, // نمرر undefined ليستخدم الـ Default (السنة الحالية)
    month ? Number(month) : undefined,
    Number(page) || 1,     // Default value
    Number(pageSize) || 5  // Default value
  );

  // 3. إرسال الرد (بصيغة موحدة مع باقي المشروع)
  res.status(200).json({
    status: "success",
    data: dashboardData
  });
});