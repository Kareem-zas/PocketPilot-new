const express = require("express");
const router = express.Router();
const { auth } = require("../middleware/authMiddleware");

const {
  getMonthlyReport,
  getYearlyReport,
  getYearlyMonthlyBreakdown
} = require("../controllers/reportController");

// 1. التقرير الشهري
router.get("/monthly", auth, getMonthlyReport);

// 2. التقرير السنوي المفصل (Specific Route) - نضعه قبل العام
router.get("/yearly/breakdown", auth, getYearlyMonthlyBreakdown);

// 3. ملخص التقرير السنوي (General Route)
router.get("/yearly", auth, getYearlyReport);

module.exports = router;