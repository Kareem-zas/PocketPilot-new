const express = require("express");
const router = express.Router();
const { auth } = require("../middleware/authMiddleware"); // تأكد من المسار

const {
  registerUser,
  loginUser,
  getUserInfo,
  sendVerificationOTP,
  verifyEmail,
  forgotPassword,
  resetPassword,
} = require("../controllers/authController");

router.post("/register", registerUser);
router.post("/login", loginUser);

// OTP Verification & Forgot Password
router.post("/send-verification", auth, sendVerificationOTP);
router.post("/verify-email", auth, verifyEmail);
router.post("/forgot-password", forgotPassword);
router.post("/reset-password", resetPassword);

// Profile endpoints (both used by different services in Flutter)
router.get("/me", auth, getUserInfo);
router.get("/getUser", auth, getUserInfo); // alias used by user_service.dart

module.exports = router;