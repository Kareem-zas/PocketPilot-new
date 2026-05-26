const User = require("../models/User");
const catchAsync = require("../utils/catchAsync");
const AppError = require("../utils/AppError");

/* =========================
   Get Pocket Balance
========================= */
exports.getPocketBalance = catchAsync(async (req, res, next) => {
  const user = await User.findById(req.userId).select("+pocketBalance");
  if (!user) {
    return next(new AppError("User not found", 404));
  }

  res.status(200).json({
    status: "success",
    data: {
      balance: user.pocketBalance || 0,
    },
  });
});

/* =========================
   Update Pocket Balance (Absolute update)
========================= */
exports.updatePocketBalance = catchAsync(async (req, res, next) => {
  const { amount } = req.body;
  if (amount === undefined || typeof amount !== "number") {
    return next(new AppError("A valid amount is required", 400));
  }

  const user = await User.findByIdAndUpdate(
    req.userId,
    { pocketBalance: amount },
    { new: true, runValidators: true }
  );

  res.status(200).json({
    status: "success",
    data: {
      balance: user.pocketBalance,
    },
  });
});

/* =========================
   Add to Pocket Balance (Increment)
========================= */
exports.addPocketCash = catchAsync(async (req, res, next) => {
  const { amount } = req.body;
  if (amount === undefined || typeof amount !== "number" || amount <= 0) {
    return next(new AppError("A valid positive amount is required", 400));
  }

  const user = await User.findByIdAndUpdate(
    req.userId,
    { $inc: { pocketBalance: amount } },
    { new: true }
  );

  res.status(200).json({
    status: "success",
    data: {
      balance: user.pocketBalance,
    },
  });
});

/* =========================
   Subtract from Pocket Balance (Decrement)
========================= */
exports.subtractPocketCash = catchAsync(async (req, res, next) => {
  const { amount } = req.body;
  if (amount === undefined || typeof amount !== "number" || amount <= 0) {
    return next(new AppError("A valid positive amount is required", 400));
  }

  const user = await User.findById(req.userId).select("+pocketBalance");
  if (!user) {
    return next(new AppError("User not found", 404));
  }

  user.pocketBalance = Math.max(0, (user.pocketBalance || 0) - amount);
  await user.save({ validateBeforeSave: false });

  res.status(200).json({
    status: "success",
    data: {
      balance: user.pocketBalance,
    },
  });
});
