const ReportService = require("../services/reportService");
const catchAsync = require("../utils/catchAsync");
const AppError = require("../utils/AppError");

/* =========================
   Get Monthly Report
========================= */
exports.getMonthlyReport = catchAsync(async (req, res, next) => {
  const { year, month } = req.query;

  if (!year || !month) {
    return next(new AppError("Year and month are required", 400));
  }

  const report = await ReportService.getMonthlyData(
    req.userId,
    Number(year),
    Number(month)
  );

  res.status(200).json({
    status: "success",
    data: report,
  });
});

/* =========================
   Get Yearly Report (Summary)
========================= */
exports.getYearlyReport = catchAsync(async (req, res, next) => {
  const { year } = req.query;

  if (!year) {
    return next(new AppError("Year is required", 400));
  }

  const report = await ReportService.getYearlyData(req.userId, Number(year));

  res.status(200).json({
    status: "success",
    data: report,
  });
});

/* =========================
   Get Yearly Breakdown (Charts Data)
========================= */
exports.getYearlyMonthlyBreakdown = catchAsync(async (req, res, next) => {
  const { year } = req.query;

  if (!year) {
    return next(new AppError("Year is required", 400));
  }

  const breakdown = await ReportService.getBreakdownData(req.userId, Number(year));

  res.status(200).json({
    status: "success",
    data: breakdown,
  });
});