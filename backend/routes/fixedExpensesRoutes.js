const express = require("express");
const router = express.Router();
const {auth} = require("../middleware/authMiddleware") ; 
const {
  
  getFixedExpenses,
  addFixedExpenseItem,
  updateFixedExpenseItem,
  deleteFixedExpenseItem,
} = require("../controllers/fixedExpensesController");

// -----------------------------------------
//  وثيقة Fixed Expenses (وحدة لكل مستخدم)
// -----------------------------------------


router.post("/", auth,addFixedExpenseItem);

// جلب مصاريف المستخدم
router.get("/",auth, getFixedExpenses);

// -----------------------------------------
//  عناصر داخل المصفوفة (items)
// -----------------------------------------

// إضافة عنصر
router.post("/item",  auth ,addFixedExpenseItem);

// تعديل عنصر
router.patch("/item/:itemId",auth, updateFixedExpenseItem);

// حذف عنصر
router.delete("/item/:itemId", auth, deleteFixedExpenseItem);


module.exports = router;
