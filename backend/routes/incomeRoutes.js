const express = require("express");
const router = express.Router();
const { auth } = require("../middleware/authMiddleware");
const {
  insertIncome,
  getIncome,
  getIncomeById,
  updateIncome,
  deleteIncome,
  getIncomeHistory,
  syncSmsIncome,
  toggleActive,
  pauseMonth,
  resumeMonth,
} = require("../controllers/incomeController");

// إضافة دخل
router.post("/", auth, insertIncome);

// مزامنة دخل من رسائل بنكية
router.post("/sms-sync", auth, syncSmsIncome);

// جلب كل الدخل
router.get("/", auth, getIncome);

// سجل الدخل مع فلترة
router.get("/history", auth, getIncomeHistory);

// تفعيل / تعطيل الدخل المتكرر كلياً
router.patch("/:id/toggle-active", auth, toggleActive);

// إيقاف شهر معين
router.patch("/:id/pause-month", auth, pauseMonth);

// استعادة شهر موقوف
router.patch("/:id/resume-month", auth, resumeMonth);

// جلب دخل واحد
router.get("/:id", auth, getIncomeById);

// تعديل
router.patch("/:id", auth, updateIncome);

// حذف
router.delete("/:id", auth, deleteIncome);

module.exports = router;
