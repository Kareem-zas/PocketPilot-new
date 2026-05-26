const express = require("express");
const router = express.Router();
const { auth } = require("../middleware/authMiddleware"); 
const {
  insertIncome,
  getIncome,
  getIncomeById,
  updateIncome,
  deleteIncome,
  getIncomeHistory, // 1. لا تنسَ استدعاء الدالة
  syncSmsIncome,
} = require("../controllers/incomeController");

// إضافة دخل
router.post("/", auth, insertIncome);

// مزامنة دخل من رسائل بنكية
router.post("/sms-sync", auth, syncSmsIncome);

// جلب كل الدخل
router.get("/", auth, getIncome);

//  2. الـ History لازم يكون هون (قبل الـ ID) 
router.get("/history", auth, getIncomeHistory);

// جلب دخل واحد (هاد بياخد أي اشي بيجي بعد السلاش)
router.get("/:id", auth, getIncomeById);

// تعديل
router.patch("/:id", auth, updateIncome);

// حذف
router.delete("/:id", auth, deleteIncome);

module.exports = router;