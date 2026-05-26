const express = require("express");
const router = express.Router();
const { auth } = require("../middleware/authMiddleware"); // تأكد أن الاسم صحيح حسب ملفك
const {
  insertVariableExpense,
  getVariableExpenses,
  getVariableExpenseById,
  updateVariableExpense,
  deleteVariableExpense,
  getVariableExpensesHistory,
  syncSmsExpenses,
} = require("../controllers/variableExpensesController");

// 1. إضافة مصروف
router.post("/", auth, insertVariableExpense);

// 1.5 مزامنة مصروفات الرسائل
router.post("/sms-sync", auth, syncSmsExpenses);

// 2. جلب الكل
router.get("/", auth, getVariableExpenses);

//  3. الراوت المخصص (History) لازم يكون هون (قبل الـ ID) 
router.get("/history", auth, getVariableExpensesHistory);

// 4. جلب واحد (الراوت الديناميكي)
router.get("/:id", auth, getVariableExpenseById);

// 5. تعديل
router.patch("/:id", auth, updateVariableExpense);

// 6. حذف
router.delete("/:id", auth, deleteVariableExpense);

module.exports = router;