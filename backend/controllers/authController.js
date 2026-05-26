const User = require("../models/User");
const jwt = require("jsonwebtoken");
const catchAsync = require("../utils/catchAsync");
const AppError = require("../utils/AppError");
const { sendOTP } = require("../services/emailService");

//Helper Function
const signToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: "1h", // 
  });
};

//Helper Function
const createSendToken = (user, statusCode, res) => {
  const token = signToken(user._id);


  user.password = undefined;

  res.status(statusCode).json({
    status: "success",
    token,
    data: {
      user,
    },
  });
};

/* =========================
   REGISTER
========================= */
exports.registerUser = catchAsync(async (req, res, next) => {
  const { fullName, email, password, phone } = req.body;


  if (!fullName || !email || !password || !phone) {
    return next(new AppError("Please provide all required fields", 400));
  }


  const existingUser = await User.findOne({
    $or: [{ email: email }, { phone: phone }]
  });

  if (existingUser) {
    const msg = existingUser.email === email
      ? "Email already in use"
      : "Phone number already in use";
    return next(new AppError(msg, 400));
  }



  const newUser = await User.create({
    fullName,
    email,
    password,
    phone,
  });


  createSendToken(newUser, 201, res);
});

/* =========================
   LOGIN
========================= */
exports.loginUser = catchAsync(async (req, res, next) => {
  const { email, password } = req.body;

  // أ) التحقق من وجود البيانات
  if (!email || !password) {
    return next(new AppError("Please provide email and password", 400));
  }

  // ب) البحث عن المستخدم + جلب الباسورد
  const user = await User.findOne({ email }).select("+password");

  //  التحقق الأمني الموحد
  // نستخدم دالة matchPassword الموجودة في User Model
  if (!user || !(await user.matchPassword(password))) {
    return next(new AppError("Incorrect email or password", 401));
  }

  // د) إرسال الرد
  createSendToken(user, 200, res);
});

/* =========================
   GET USER INFO
========================= */
exports.getUserInfo = catchAsync(async (req, res, next) => {
  // req.userId قادمة من ميدل وير المصادقة (isAuth)
  const user = await User.findById(req.userId);

  if (!user) {
    return next(new AppError("User not found", 404));
  }

  res.status(200).json({
    status: "success",
    data: { user }
  });
});

/* ===========================================
   EMAIL VERIFICATION & FORGOT PASSWORD (OTP)
   =========================================== */

// 1. sendVerificationOTP — POST /api/auth/send-verification (protected route)
exports.sendVerificationOTP = catchAsync(async (req, res, next) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    if (user.emailVerified) {
      return res.status(400).json({ message: "Email is already verified" });
    }

    // Generate 6-digit OTP (100000–999999)
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes from now

    user.otp = {
      code: otpCode,
      expiresAt: expiresAt,
    };
    await user.save();

    await sendOTP(user.email, otpCode, "verify");

    res.status(200).json({
      status: "success",
      message: "Verification OTP code sent to your email",
    });
  } catch (error) {
    res.status(500).json({
      message: error.message || "An error occurred while sending verification OTP",
    });
  }
});

// 2. verifyEmail — POST /api/auth/verify-email (protected route)
exports.verifyEmail = catchAsync(async (req, res, next) => {
  try {
    const { otp } = req.body;
    if (!otp) {
      return res.status(400).json({ message: "Please provide the OTP code" });
    }

    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    if (!user.otp || !user.otp.code) {
      return res.status(400).json({ message: "No OTP was requested or found" });
    }

    if (user.otp.expiresAt < new Date()) {
      return res.status(400).json({ message: "OTP has expired" });
    }

    if (user.otp.code !== otp) {
      return res.status(400).json({ message: "Invalid OTP code" });
    }

    user.emailVerified = true;
    user.otp = undefined; // clear otp
    await user.save();

    res.status(200).json({
      status: "success",
      message: "Email verified successfully",
    });
  } catch (error) {
    res.status(500).json({
      message: error.message || "An error occurred during verification",
    });
  }
});

// 3. forgotPassword — POST /api/auth/forgot-password (public route)
exports.forgotPassword = catchAsync(async (req, res, next) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ message: "Please provide your email address" });
    }

    const user = await User.findOne({ email });

    // Generic success message to protect privacy
    const genericResponse = {
      status: "success",
      message: "If that email is registered, we have sent a password reset code.",
    };

    if (!user) {
      return res.status(200).json(genericResponse);
    }

    // Generate 6-digit OTP (100000–999999)
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes from now

    user.otp = {
      code: otpCode,
      expiresAt: expiresAt,
    };
    await user.save();

    await sendOTP(user.email, otpCode, "reset");

    res.status(200).json(genericResponse);
  } catch (error) {
    res.status(500).json({
      message: error.message || "An error occurred while processing forgot password request",
    });
  }
});

// 4. resetPassword — POST /api/auth/reset-password (public route)
exports.resetPassword = catchAsync(async (req, res, next) => {
  try {
    const { email, otp, newPassword } = req.body;
    if (!email || !otp || !newPassword) {
      return res.status(400).json({ message: "Please provide email, otp, and newPassword" });
    }

    if (newPassword.length < 8) {
      return res.status(400).json({ message: "Password must be at least 8 characters" });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    if (!user.otp || !user.otp.code) {
      return res.status(400).json({ message: "No OTP was requested or found" });
    }

    if (user.otp.expiresAt < new Date()) {
      return res.status(400).json({ message: "OTP has expired" });
    }

    if (user.otp.code !== otp) {
      return res.status(400).json({ message: "Invalid OTP code" });
    }

    user.password = newPassword;
    user.otp = undefined; // clear otp
    await user.save();

    res.status(200).json({
      status: "success",
      message: "Password reset successfully!",
    });
  } catch (error) {
    res.status(500).json({
      message: error.message || "An error occurred while resetting password",
    });
  }
});